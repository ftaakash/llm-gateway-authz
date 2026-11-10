#!/usr/bin/env bash
# new-api R5 recall cell (CVE-2026-30886): VideoProxy fetches a task by task_id only
# (GetByOnlyTaskId), so any authenticated user can read another user's video task.
# Fixed v0.11.4-alpha.2 scopes the lookup to the owner (GetByTaskId(userId,taskId)).
# Signature: FAIL = user B's GET /v1/videos/{A_task}/content does NOT return
# "Task not found" (B reached A's task — same task-specific response as A). PASS =
# B gets "Task not found" (owner-scoped). Positive control: A reaches A's own task
# (not "not found"), and A's task exists. Observation via response body/status only.
# Rung up via testbed/newapi/up.sh. Usage: 24_newapi_r5.sh <rung> <image>
#
# SETUP FIX (DECISIONS G17, re-run after review 3 B1) — mock/fixture + precondition only;
# the frozen oracle (VERSIONS.md R5 signature), the verdict block, the observable and the
# notfound() rule below are UNCHANGED. Earlier the mock only stubbed the Sora submit, so the
# 15s task poller (sora FetchTask -> GET {base}/v1/videos/{id}; ParseTaskResult maps
# "completed"->SUCCESS) hit the catchall (empty status) and A's task stayed NOT_START, and the
# cell fetched content with no wait — A's own request was refused (400 "not completed yet") on
# both rungs, so by the frozen positive control R5 was INVALID. The fix adds the two upstream
# stubs the sora adaptor actually calls (status poll + content) and an M2 bounded wait for A's
# task to reach SUCCESS before the content fetches. It only makes A's legitimate task complete.
#
# R5-J (DECISIONS G18, review 4) — align this cell to the journal half ALREADY in the frozen R5
# signature (VERSIONS.md line 28): observe the WireMock journal count of upstream content requests
# just before/after B's content request, and decide the verdict by BOTH halves (content result AND
# journal). Observation-only addition + verdict alignment to the frozen text; VERSIONS.md untouched;
# the setup from 3aea1a6 (stubs + M2 wait) is unchanged; precondition/positive-control paths unchanged.
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"; LABEL="${1:?rung}"; IMG="${2:?image}"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),new-api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
# live-add the Sora submit stub (an `id` so the adaptor creates a task)
docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -X POST http://p10-mock:8080/__admin/mappings -H 'Content-Type: application/json' -d '{"priority":2,"request":{"method":"POST","urlPathPattern":"/(v1/)?videos"},"response":{"status":200,"headers":{"Content-Type":"application/json"},"jsonBody":{"id":"video_mock123","task_id":"video_mock123","status":"completed","progress":100}}}' >/dev/null 2>&1 || true
# G17 setup fix — the two upstream endpoints the sora adaptor actually calls, so A's legitimate
# task completes: (a) status poll GET /v1/videos/{id} -> "completed" (poller maps -> SUCCESS);
# (b) content GET /v1/videos/{id}/content -> 200 bytes. Content priority (1) beats status (3).
docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -X POST http://p10-mock:8080/__admin/mappings -H 'Content-Type: application/json' -d '{"priority":1,"request":{"method":"GET","urlPathPattern":"/(v1/)?videos/[^/]+/content"},"response":{"status":200,"headers":{"Content-Type":"video/mp4"},"body":"MOCKVIDEOBYTES"}}' >/dev/null 2>&1 || true
docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -X POST http://p10-mock:8080/__admin/mappings -H 'Content-Type: application/json' -d '{"priority":3,"request":{"method":"GET","urlPathPattern":"/(v1/)?videos/[^/]+"},"response":{"status":200,"headers":{"Content-Type":"application/json"},"jsonBody":{"id":"video_mock123","task_id":"video_mock123","status":"completed","progress":100}}}' >/dev/null 2>&1 || true

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
# M2 bounded precondition wait: the 15s poller marks A task SUCCESS once the status stub answers.
# Poll /api/task/ (bounded, not a fixed sleep) until SUCCESS before any content fetch. Setup only.
i=0; AST=""
while [ $i -lt 40 ]; do
  AST=$(curl -s $RH "$B/api/task/?p=0&page_size=5" | grep -o "\"status\":\"[^\"]*\"" | head -1 | sed "s/\"status\":\"//;s/\"//")
  [ "$AST" = SUCCESS ] && break
  i=$((i+1)); sleep 3
done
echo "AWAIT=$AST"
echo "ATASK=$ATASK BID=$BID"
echo "A_CODE=$(curl -s -o /dev/null -w %{http_code} "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$AKEY")"
echo "A_BODY=$(curl -s "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$AKEY" | tr -d "\n" | head -c 160)"
# G18 R5-J: frozen-signature journal half — count upstream content requests in the WireMock
# journal just before and just after B request; delta = upstream fetch issued for B request.
CB=$(curl -s -X POST http://p10-mock:8080/__admin/requests/count -H "Content-Type: application/json" -d "{\"method\":\"GET\",\"urlPathPattern\":\"/(v1/)?videos/[^/]+/content\"}" | tr -dc "0-9")
echo "CB=$CB"
echo "B_CODE=$(curl -s -o /dev/null -w %{http_code} "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$BKEY")"
echo "B_BODY=$(curl -s "$B/v1/videos/$ATASK/content" -H "Authorization: Bearer sk-$BKEY" | tr -d "\n" | head -c 160)"
CA=$(curl -s -X POST http://p10-mock:8080/__admin/requests/count -H "Content-Type: application/json" -d "{\"method\":\"GET\",\"urlPathPattern\":\"/(v1/)?videos/[^/]+/content\"}" | tr -dc "0-9")
echo "CA=$CA"
')
g(){ echo "$OUT" | sed -n "s/^$1=//p" | head -1; }
ATASK=$(g ATASK); acode=$(g A_CODE); abody=$(g A_BODY); bcode=$(g B_CODE); bbody=$(g B_BODY)
cb=$(g CB); ca=$(g CA); deltaB=$(( ${ca:-0} - ${cb:-0} ))   # G18 R5-J: journal fetches for B request
notfound(){ echo "$2" | grep -qiE 'task not found|not found' || [ "$1" = 404 ]; }
bnf=0; notfound "$bcode" "$bbody" && bnf=1                   # B refused/404 ?
obs="A($acode)=[$abody] B($bcode)=[$bbody] journalFetchForB=$deltaB (cb=$cb ca=$ca) task=$ATASK"
# Verdict = frozen R5 signature (VERSIONS.md line 28), both halves:
#   FAIL = B gets A content (not not-found) AND journal shows an upstream fetch for B request
#   PASS = B refused/404 AND no journal fetch for B
#   disagreement between content result and journal = INVALID
# Precondition (ATASK) and A positive-control INVALID paths unchanged.
if [ -z "$ATASK" ]; then
  row CVE-2026-30886 ownership INVALID "setup: A's video task not created ($obs)"
elif notfound "$acode" "$abody"; then
  row CVE-2026-30886 ownership INVALID "positive control: A cannot see A's own task ($obs)"
elif [ "$bnf" = 0 ] && [ "${deltaB:-0}" -ge 1 ]; then
  row CVE-2026-30886 ownership FAIL "B reached A's task (content, not not-found) AND journal shows upstream fetch for B ($obs)"
elif [ "$bnf" = 1 ] && [ "${deltaB:-0}" -eq 0 ]; then
  row CVE-2026-30886 ownership PASS "B gets Task-not-found (owner-scoped) and no journal fetch for B ($obs)"
else
  row CVE-2026-30886 ownership INVALID "content result and journal disagree (Bnotfound=$bnf journalFetchForB=$deltaB) ($obs)"
fi
echo "--- $out"
