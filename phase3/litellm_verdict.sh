#!/usr/bin/env bash
# TRACKED script; its current-release RESULTS go to private/ only (never tracked /
# mirror / cross-session). Phase-3 VERDICT cell for INV-G2 (no self-elevation of
# authorization attributes) on a given LiteLLM image (current release = v1.108.2).
# Frozen R2 org_admin signature: an org_admin POSTs /user/update setting its own
# user_role=proxy_admin; a re-read of /user/info must show the role UNCHANGED and the
# attempt refused 403 "Only proxy admins can modify user roles."
#   PASS = refused 403 w/ the signature AND role unchanged AND own-field positive control works
#   FAIL = re-read shows proxy_admin (self-elevation) -> candidate new finding
#   INVALID = own-field positive control fails (route unreachable)
# Admission established via recall (FAIL 1.83.7 -> PASS 1.83.8, results/recall.csv).
# LiteLLM master-key auth (stable across versions). Usage: litellm_verdict.sh <image> <run_commit>
set +e
PILOT="$(cd "$(dirname "$0")/.." && pwd)"
NET="${NET:-pilot10}"
IMG="${1:?usage: litellm_verdict.sh <image> <run_commit>}"
RUNCMT="${2:-$(git -C "$PILOT" rev-parse --short HEAD)}"
DRIVER_IMG="pilot08/curl:8.11.1"
JQ="${JQ:-/c/Users/Administrator/tools/jq/jq.exe}"
MASTER="sk-pilot10-master"; BASE="http://p10-litellm:4000"; M="Authorization: Bearer $MASTER"
emit(){ echo "VERDICT=$1 CELL=G2 IMG=$IMG COMMIT=$RUNCMT REASON=\"$2\""; }
d(){ docker run --rm --network "$NET" "$DRIVER_IMG" "$@"; }
code(){ d -s -o /dev/null -w '%{http_code}' "$@"; }
body(){ d -s "$@"; }

if ! bash "$PILOT/testbed/litellm/up.sh" "$IMG" >/tmp/upll.$$ 2>&1; then
  emit INVALID "rung_not_ready: $(tail -1 /tmp/upll.$$)"; rm -f /tmp/upll.$$; exit 0
fi
rm -f /tmp/upll.$$

u="$(body -X POST "$BASE/user/new" -H "$M" -H 'Content-Type: application/json' -d '{"user_role":"internal_user"}')"
UUSER="$(echo "$u" | "$JQ" -r '.user_id // empty')"
org="$(body -X POST "$BASE/organization/new" -H "$M" -H 'Content-Type: application/json' -d '{"organization_alias":"g2org"}')"
OID="$(echo "$org" | "$JQ" -r '.organization_id // empty')"
if [ -z "$UUSER" ] || [ -z "$OID" ]; then emit INVALID "setup failed (user=$UUSER org=$OID)"; exit 0; fi
body -X POST "$BASE/organization/member_add" -H "$M" -H 'Content-Type: application/json' \
  -d "{\"organization_id\":\"$OID\",\"member\":{\"user_id\":\"$UUSER\",\"role\":\"org_admin\"}}" >/dev/null
OAKEY="$(body -X POST "$BASE/key/generate" -H "$M" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\"}" | "$JQ" -r '.key // empty')"
OA="Authorization: Bearer $OAKEY"
pc="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_email\":\"pc@local.test\"}")"
resp="$(body -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_role\":\"proxy_admin\"}")"
st="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"organization_id\":\"$OID\",\"user_role\":\"proxy_admin\"}")"
detail="$(echo "$resp" | "$JQ" -r '(.error.message // .detail // .error // .)|tostring' | tr -d '\n' | cut -c1-80)"
newrole="$(body "$BASE/user/info?user_id=$UUSER" -H "$M" | "$JQ" -r '.user_info.user_role // .user_role // "unknown"')"
if [ "$pc" != 200 ]; then emit INVALID "positive control own-field update=$pc (route not reachable)"
elif [ "$newrole" = proxy_admin ]; then emit FAIL "self-elevation succeeded; role re-read=proxy_admin (http $st) — candidate"
elif [ "$st" = 403 ] && echo "$detail" | grep -qi 'proxy admins can modify user roles'; then emit PASS "refused 403 [$detail]; role stayed $newrole; posctl=$pc"
elif [ "$st" = 403 ]; then emit INVALID "403 but detail != signature [$detail]"
else emit INVALID "neither elevated nor signature-403 (http $st role $newrole)"
fi
