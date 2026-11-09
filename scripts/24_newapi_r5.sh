#!/usr/bin/env bash
# new-api R5 recall cell (CVE-2026-30886): VideoProxy fetches a task by task_id only
# (GetByOnlyTaskId), so any authenticated user can read another user's video task.
# Fixed v0.11.4-alpha.2 scopes the lookup to the owner (GetByTaskId(userId,taskId)).
# Signature: FAIL = user B's GET /v1/videos/{A_task}/content does NOT return
# "Task not found" (B reached A's task — same task-specific response as A). PASS =
# B gets "Task not found" (owner-scoped). Positive control: A reaches A's own task
# (not "not found"), and A's task exists. Observation via response body/status only.
# Rung up via testbed/newapi/up.sh. Usage: 24_newapi_r5.sh <rung> <image>
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"; LABEL="${1:?rung}"; IMG="${2:?image}"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),new-api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
# live-add the Sora submit stub (an `id` so the adaptor creates a task)
docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -X POST http://p10-mock:8080/__admin/mappings -H 'Content-Type: application/json' -d '{"priority":2,"request":{"method":"POST","urlPathPattern":"/(v1/)?videos"},"response":{"status":200,"headers":{"Content-Type":"application/json"},"jsonBody":{"id":"video_mock123","task_id":"video_mock123","status":"completed","progress":100}}}' >/dev/null 2>&1 || true

OUT=$(docker run --rm --network "$NET" --entrypoint sh "$DRIVER_IMG" -c '
set -e; B=http://p10-newapi:3000
curl -s -X POST $B/api/setup -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"Rootpass123\",\"confirmPassword\":\"Rootpass123\",\"SelfUseModeEnabled\":true,\"DemoSiteEnabled\":false}" >/dev/null 2>&1 || true
curl -s -c /tmp/rc -o /dev/null -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"root\",\"password\":\"Rootpass123\"}"
RH="-b /tmp/rc -H New-Api-User:1"
curl -s $RH -X POST $B/api/channel/ -H "Content-Type: application/json" -d "{\"mode\":\"single\",\"channel\":{\"name\":\"sora\",\"type\":55,\"key\":\"op-dummy\",\"base_url\":\"http://p10-mock:8080\",\"models\":\"sora-2,sora\",\"group\":\"default\",\"groups\":[\"default\"],\"status\":1}}" >/dev/null 2>&1 || true
curl -s $RH -X POST $B/api/token/ -H "Content-Type: application/json" -d "{\"name\":\"ta\",\"unlimited_quota\":true,\"expired_time\":-1}" >/dev/null
AKEY=$(curl -s $RH "$B/api/token/?p=0&size=10" | sed "s/.*\"key\":\"//; s/\".*//")
curl -s -X POST $B/v1/video/generations -H "Authorization: Bearer sk-$AKEY" -H "Content-Type: application/json" -d "{\"model\":\"sora-2\",\"prompt\":\"a cat\"}" >/dev/null
ATASK=$(curl -s $RH "$B/api/task/?p=0&page_size=5" | grep -o "\"task_id\":\"[^\"]*\"" | head -1 | sed "s/\"task_id\":\"//;s/\"//")
# user B + its own token
curl -s $RH -X POST $B/api/user/ -H "Content-Type: application/json" -d "{\"username\":\"userb\",\"password\":\"Passw0rd!x\",\"display_name\":\"userb\"}" >/dev/null 2>&1 || true
LB=$(curl -s -c /tmp/bc -X POST $B/api/user/login -H "Content-Type: application/json" -d "{\"username\":\"userb\",\"password\":\"Passw0rd!x\"}")
BID=$(echo "$LB" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
BH="-b /tmp/bc -H New-Api-User:$BID"
curl -s $BH -X POST $B/api/token/ -H "Content-Type: application/json" -d "{\"name\":\"tb\",\"unlimited_quota\":true,\"expired_time\":-1}" >/dev/null
BKEY=$(curl -s $BH "$B/api/token/?p=0&size=10" | sed "s/.*\"key\":\"//; s/\".*//")
echo "ATASK=$ATASK BID=$BID"
echo "A_CODE=$(curl -s -o /dev/null -w %{http_code} "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$AKEY")"
echo "A_BODY=$(curl -s "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$AKEY" | tr -d "\n" | head -c 160)"
echo "B_CODE=$(curl -s -o /dev/null -w %{http_code} "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$BKEY")"
echo "B_BODY=$(curl -s "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$BKEY" | tr -d "\n" | head -c 160)"
')
g(){ echo "$OUT" | sed -n "s/^$1=//p" | head -1; }
ATASK=$(g ATASK); acode=$(g A_CODE); abody=$(g A_BODY); bcode=$(g B_CODE); bbody=$(g B_BODY)
notfound(){ echo "$2" | grep -qiE 'task not found|not found' || [ "$1" = 404 ]; }
obs="A($acode)=[$abody] B($bcode)=[$bbody] task=$ATASK"
if [ -z "$ATASK" ]; then
  row CVE-2026-30886 ownership INVALID "setup: A's video task not created ($obs)"
elif notfound "$acode" "$abody"; then
  row CVE-2026-30886 ownership INVALID "positive control: A cannot see A's own task ($obs)"
elif notfound "$bcode" "$bbody"; then
  row CVE-2026-30886 ownership PASS "B gets Task-not-found (owner-scoped) ($obs)"
else
  row CVE-2026-30886 ownership FAIL "B reached A's task (same task-specific response, not not-found) ($obs)"
fi
echo "--- $out"
