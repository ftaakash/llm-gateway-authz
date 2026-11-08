#!/usr/bin/env bash
# Sub2API R6 recall cell (CVE-2026-73079): a caller-supplied responses subpath is
# spliced into the operator upstream URL (path traversal). Fixed 0.1.169 adds
# upstream_path_guard. Rung up via testbed/sub2api/up.sh (setup install done there).
# Observation = the mock request journal (H4 control: WireMock journals dot-segment
# paths verbatim, env/r6-mockjournal-control.csv).
#
# STATUS (phase 1, this session): the testbed is fully provisioned (admin login,
# compliance accept, group, account, user balance, tenant api-key) and tenant
# traffic reaches the mock for an `apikey` passthrough account (control = 200,
# journaled). BUT the *vulnerable raw-splice variant* could not be faithfully
# exercised with mock providers: the `apikey` passthrough normalizes
# /v1/responses -> /v1/chat/completions (no raw subpath splice), and the
# `upstream` account type (the advisory's "operator-configured base URL") returns
# 502 before reaching the mock on both /v1/responses and /backend-api/codex/
# responses/*subpath. The advisory's raw-passthrough splice is tied to the
# ChatGPT/Codex OAuth passthrough (OAuth login cannot be mocked under SCOPE) or an
# upstream-URL construction not reproduced here. Per the KC1 D4/D6 rule, a vuln
# whose code path is not reachable with mocks counts as NOT REDISCOVERED, not a
# vacuous PASS/FAIL. R6 is therefore recorded INVALID (reachability-unconfirmed).
# It does NOT count toward kill condition 3's >=4-of-6 recall (which is already met
# by R1,R2,R3,R4). Revisit: a local OpenAI-compatible passthrough that preserves
# the raw subpath, or the codex upstream-URL path, before any R6 verdict counts.
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"; LABEL="${1:?rung}"; IMG="${2:?image}"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),sub2api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
B=http://p10-sub2api:8080
PHRASE='I have read, understood, and agree to the Sub2API Deployment and Operation Compliance Commitment'

# Provision + a control request to prove tenant traffic reaches the mock.
docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -X DELETE http://p10-mock:8080/__admin/requests >/dev/null 2>&1 || true
OUT=$(docker run --rm --network "$NET" --entrypoint sh "$DRIVER_IMG" -c '
B='"$B"'
TOK=$(curl -s -X POST $B/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"admin@sub2api.local\",\"password\":\"Adminpass123\"}" | sed "s/.*\"access_token\":\"//; s/\".*//")
A="Authorization: Bearer $TOK"
curl -s -X POST $B/api/v1/admin/compliance/accept -H "$A" -H "Content-Type: application/json" -d "{\"phrase\":\"'"$PHRASE"'\",\"language\":\"en\"}" >/dev/null
G=$(curl -s -X POST $B/api/v1/admin/groups -H "$A" -H "Content-Type: application/json" -d "{\"name\":\"r6g\",\"platform\":\"openai\",\"rate_multiplier\":1}")
GID=$(echo "$G" | grep -o "\"id\":[0-9]*" | head -1 | cut -d: -f2)
curl -s -X POST $B/api/v1/admin/accounts -H "$A" -H "Content-Type: application/json" -d "{\"name\":\"r6acc\",\"platform\":\"openai\",\"type\":\"apikey\",\"credentials\":{\"base_url\":\"http://p10-mock:8080\",\"api_key\":\"operator-dummy-key\"},\"group_ids\":[$GID]}" >/dev/null
curl -s -X POST $B/api/v1/admin/users/1/balance -H "$A" -H "Content-Type: application/json" -d "{\"balance\":100,\"operation\":\"add\",\"notes\":\"r6\"}" >/dev/null
K=$(curl -s -X POST $B/api/v1/keys -H "$A" -H "Content-Type: application/json" -d "{\"name\":\"r6k\",\"group_id\":$GID}")
TK=$(echo "$K" | sed "s/.*\"key\":\"//; s/\".*//")
CTRL=$(curl --path-as-is -s -o /dev/null -w "%{http_code}" -X POST "$B/v1/responses" -H "Authorization: Bearer $TK" -H "Content-Type: application/json" -d "{\"model\":\"gpt-4o\",\"input\":\"hi\"}")
TRAV=$(curl --path-as-is -s -o /dev/null -w "%{http_code}" -X POST "$B/v1/responses/..%2f..%2fbackend-escaped" -H "Authorization: Bearer $TK" -H "Content-Type: application/json" -d "{\"model\":\"gpt-4o\",\"input\":\"hi\"}")
echo "CTRL=$CTRL TRAV=$TRAV"
')
ctrl=$(echo "$OUT" | sed -n 's/.*CTRL=\([0-9]*\).*/\1/p'); trav=$(echo "$OUT" | sed -n 's/.*TRAV=\([0-9]*\).*/\1/p')
hit=$(docker run --rm --network "$NET" pilot08/curl:8.11.1 -s 'http://p10-mock:8080/__admin/requests?limit=20' | "$JQ" -r '[.requests[]?]|length' 2>/dev/null)
row CVE-2026-73079 raw_splice INVALID "reachability unconfirmed with mocks: apikey passthrough normalizes responses->chat/completions (no raw splice); upstream type 502s pre-mock. tenant control reached mock (ctrl=$ctrl trav=$trav mockReqs=$hit). NOT counted (KC1 D4/D6); recall already >=4 via R1-R4"
echo "--- $out"
