#!/usr/bin/env bash
# TRACKED script; its current-release RESULTS go to private/ only (never tracked /
# mirror / cross-session). Phase-3 VERDICT cell for INV-G2 (no self-elevation of
# authorization attributes) on a given LiteLLM image (current release = v1.108.2).
# Frozen R2 signature (invariant UNCHANGED): a non-proxy-admin principal with legitimate
# /user/update access POSTs /user/update setting its own user_role=proxy_admin; a re-read of
# /user/info must show the role UNCHANGED and the attempt refused 403 "Only proxy admins can
# modify user roles." G28 re-bases the principal from org_admin (Enterprise-only on the current
# release) to a free-edition internal_user whose key carries allowed_routes=["/user/update"];
# the signature, the /user/info observable and the oracle are unchanged.
#   PASS = refused 403 w/ the signature AND role unchanged AND own-field positive control works
#   FAIL = re-read shows proxy_admin (self-elevation) -> candidate new finding
#   INVALID = own-field positive control fails (route/principal unreachable)
# Admission re-taken on the same recall pair (FAIL 1.83.7 -> PASS 1.83.8) under the redesign (G28).
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
# body + HTTP status in one call (so a failed provisioning POST is diagnosable without re-posting):
# prints "<body>\n__HTTP__<code>"; split with ${r##*__HTTP__} (code) and ${r%__HTTP__*} (body).
bodyst(){ d -s -w '\n__HTTP__%{http_code}' "$@"; }

if ! bash "$PILOT/testbed/litellm/up.sh" "$IMG" >/tmp/upll.$$ 2>&1; then
  emit INVALID "rung_not_ready: $(tail -1 /tmp/upll.$$)"; rm -f /tmp/upll.$$; exit 0
fi
rm -f /tmp/upll.$$

# --- provisioning (G28 CHECK redesign: free-edition delegated-access principal) ---
# The frozen org_admin principal is unavailable on the OSS current release (organizations are
# Enterprise-gated; org_admin needs org membership — DECISIONS G28). Re-base the principal on a
# free-edition equivalent: a non-admin internal_user whose KEY is granted legitimate delegated
# access to /user/update via allowed_routes (route_checks.py non_proxy_admin_allowed_routes_check).
# That key then attempts to self-elevate its own user_role to proxy_admin. The invariant, the frozen
# refusal signature, the /user/info observable and the PASS/FAIL/INVALID rule are UNCHANGED; only the
# principal and its provisioning change (no organization). Readiness-robust: liveliness=200 can
# precede the management-DB migration, so the master-key provisioning (create user, then mint the
# delegated key) is a BOUNDED readiness poll that surfaces the real status+detail on persistent failure.
UUSER=""; OAKEY=""; kbody=""; kst=""
for i in $(seq 1 20); do
  [ -n "$UUSER" ] || UUSER="$(body -X POST "$BASE/user/new" -H "$M" -H 'Content-Type: application/json' -d '{"user_role":"internal_user"}' | "$JQ" -r '.user_id // empty')"
  if [ -n "$UUSER" ] && [ -z "$OAKEY" ]; then
    r="$(bodyst -X POST "$BASE/key/generate" -H "$M" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"allowed_routes\":[\"/user/update\"]}")"
    kst="${r##*__HTTP__}"; kbody="${r%__HTTP__*}"
    OAKEY="$(echo "$kbody" | "$JQ" -r '.key // empty')"
  fi
  [ -n "$UUSER" ] && [ -n "$OAKEY" ] && break
  sleep 3
done
if [ -z "$UUSER" ] || [ -z "$OAKEY" ]; then
  kdet="$(echo "$kbody" | "$JQ" -r '(.error.message // .detail // .error // .)|tostring' 2>/dev/null | tr -d '\n' | cut -c1-100)"
  emit INVALID "setup failed after readiness poll (user=$UUSER key=$([ -n "$OAKEY" ] && echo yes || echo no) http=$kst detail=[$kdet])"; exit 0
fi
OA="Authorization: Bearer $OAKEY"
pc="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"user_email\":\"pc@local.test\"}")"
resp="$(body -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"user_role\":\"proxy_admin\"}")"
st="$(code -X POST "$BASE/user/update" -H "$OA" -H 'Content-Type: application/json' -d "{\"user_id\":\"$UUSER\",\"user_role\":\"proxy_admin\"}")"
detail="$(echo "$resp" | "$JQ" -r '(.error.message // .detail // .error // .)|tostring' | tr -d '\n' | cut -c1-80)"
newrole="$(body "$BASE/user/info?user_id=$UUSER" -H "$M" | "$JQ" -r '.user_info.user_role // .user_role // "unknown"')"
if [ "$pc" != 200 ]; then emit INVALID "positive control own-field update=$pc (route not reachable)"
elif [ "$newrole" = proxy_admin ]; then emit FAIL "self-elevation succeeded; role re-read=proxy_admin (http $st) — candidate"
elif [ "$st" = 403 ] && echo "$detail" | grep -qi 'proxy admins can modify user roles'; then emit PASS "refused 403 [$detail]; role stayed $newrole; posctl=$pc"
elif [ "$st" = 403 ]; then emit INVALID "403 but detail != signature [$detail]"
else emit INVALID "neither elevated nor signature-403 (http $st role $newrole)"
fi
