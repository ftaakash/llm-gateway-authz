#!/usr/bin/env bash
# new-api recall cells. Rung must be up (testbed/newapi/up.sh <img>) and set up.
# Each flow runs in ONE driver container (session cookie in /tmp + New-Api-User
# header); final JSON is parsed host-side with jq. Rows -> results/recall.csv.
# Local only. Usage: 21_newapi_cell.sh <rung> <image>
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"
LABEL="${1:?rung}"; IMG="${2:?image}"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),new-api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
shc() { docker run --rm --network "$NET" --entrypoint sh "$DRIVER_IMG" -c "$1"; }

ROOTPW="Rootpass123"
echo "=== R4 admin user list leaks root access_token on $LABEL"
U2="na2$RANDOM"
R4=$(shc '
set -e
B=http://p10-newapi:3000
curl -s -X POST $B/api/setup -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"'"$ROOTPW"'\",\"confirmPassword\":\"'"$ROOTPW"'\",\"SelfUseModeEnabled\":true,\"DemoSiteEnabled\":false}" >/dev/null 2>&1 || true
curl -s -c /tmp/rc -o /dev/null -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"'"$ROOTPW"'\"}"
RH="-b /tmp/rc -H New-Api-User:1"
# precondition: /token returns the generated access token (sets it in DB)
TOK=$(curl -s $RH $B/api/user/token | grep -o "\"data\":\"[^\"]*\"" | head -1)
curl -s $RH -X POST $B/api/user/ -H "Content-Type: application/json" -d "{\"username\":\"'"$U2"'\",\"password\":\"Passw0rd!x\",\"display_name\":\"'"$U2"'\"}" >/dev/null
L2=$(curl -s -c /tmp/ac -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"'"$U2"'\",\"password\":\"Passw0rd!x\"}")
U2ID=$(echo "$L2" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
curl -s $RH -X POST $B/api/user/manage -H "Content-Type: application/json" -d "{\"id\":$U2ID,\"action\":\"promote\"}" >/dev/null
curl -s -c /tmp/ac -o /dev/null -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"'"$U2"'\",\"password\":\"Passw0rd!x\"}"
AH="-b /tmp/ac -H New-Api-User:$U2ID"
AROLE=$(curl -s $AH $B/api/user/self | grep -o "\"role\":[0-9]*" | head -1 | cut -d: -f2)
echo "PRECOND_TOKEN=${TOK:+yes} U2ID=$U2ID AROLE=$AROLE"
echo "===LIST==="
curl -s $AH "$B/api/user/?p=1&page_size=50"
')
hdr="$(echo "$R4" | grep '^PRECOND_TOKEN=')"
listjson="$(echo "$R4" | sed -n '/===LIST===/,$p' | tail -1)"
precond="$(echo "$hdr" | sed -n 's/.*PRECOND_TOKEN=\([a-z]*\).*/\1/p')"
arole="$(echo "$hdr" | sed -n 's/.*AROLE=\([0-9]*\).*/\1/p')"
rootn="$(echo "$listjson" | "$JQ" -r '[.data.items[]? // .data[]? | select(.role==100)] | length' 2>/dev/null)"
leak="$(echo "$listjson" | "$JQ" -r '[.data.items[]? // .data[]? | select(.role==100) | .access_token // "" | select(length>0)] | length' 2>/dev/null)"
if [ "$precond" != yes ]; then
  row CVE-2026-64859 root_token INVALID "precondition: /api/user/token returned no token"
elif [ "${arole:-0}" != 10 ]; then
  row CVE-2026-64859 root_token INVALID "admin2 not promoted (role=$arole)"
elif [ "${rootn:-0}" -lt 1 ]; then
  row CVE-2026-64859 root_token INVALID "positive control: root record not in admin2's list"
elif [ "${leak:-0}" -ge 1 ]; then
  row CVE-2026-64859 root_token FAIL "non-root admin GET /api/user/ exposes root access_token (nonempty); posctl: root record present=$rootn, precond token set=$precond"
else
  row CVE-2026-64859 root_token PASS "root present in admin2 list but access_token absent/empty; posctl: root record present=$rootn, precond token set=$precond"
fi

# R3 and R5 appended by the finalized add-on once their reachability check passes.
echo "--- rows appended to $out"
