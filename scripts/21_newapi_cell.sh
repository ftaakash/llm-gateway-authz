#!/usr/bin/env bash
# new-api recall cells. A rung must already be up (testbed/newapi/up.sh <img>).
# R4 (CVE-2026-64859, admin user list leaks root access_token) is implemented and
# validated. R3 (CVE-2026-71479) and R5 (CVE-2026-30886) are finalized against the
# running container in phase 1 and gated behind their own reachability checks.
# Rows -> results/recall.csv. Local only. Usage: 21_newapi_cell.sh <rung> <image>
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"
LABEL="${1:?rung}"; IMG="${2:?image}"
BASE="http://p10-newapi:3000"
RUN="/d/Masters-data/pilot10/run"; RUNW="$(cd "$RUN" && pwd -W)"
DIG="$(docker image inspect "$IMG" --format '{{range .RepoDigests}}{{.}}{{end}}' | sed 's/.*@//')"
out="$PILOT/results/recall.csv"
[ -f "$out" ] || echo "ts,gateway,rung,image_digest,advisory,subcell,verdict,observation,commit" > "$out"
row() { echo "$(date -u +%FT%TZ),new-api,$LABEL,$DIG,$1,$2,$3,\"$4\",$COMMIT" >> "$out"; printf '[%s/%s] %s — %s\n' "$1" "$2" "$3" "$4"; }
# curl in a driver container with a mounted cookie-jar dir (sessions persist across calls)
na() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker run --rm --network "$NET" -v "$RUNW:/work" "$DRIVER_IMG" "$@"; }

login() { # login <jar> <user> <pass> -> http code; sets session cookie in $jar
  na -s -o /dev/null -w '%{http_code}' -c "/work/$1" -X POST "$BASE/api/user/login" \
     -H 'Content-Type: application/json' -d "{\"username\":\"$2\",\"password\":\"$3\"}"
}
sess() { # sess <jar> METHOD PATH [body] -> body (authenticated by cookie)
  local j="$1" m="$2" p="$3" b="${4:-}"
  if [ -n "$b" ]; then na -s -b "/work/$j" -X "$m" "$BASE$p" -H 'Content-Type: application/json' -d "$b"
  else na -s -b "/work/$j" -X "$m" "$BASE$p"; fi
}

echo "=== R4 admin user list leaks root access_token on $LABEL"
rm -f "$RUN"/cj_* 2>/dev/null
lc="$(login cj_root root 123456)"
if [ "$lc" != 200 ]; then
  row CVE-2026-64859 root_token INVALID "root login failed http=$lc"
else
  # precondition: give root an access_token so there is something to leak
  sess cj_root GET /api/user/token >/dev/null
  rootat_present_self="$(sess cj_root GET /api/user/self | "$JQ" -r '(.data.access_token // "")|length>0')"
  # create a second admin (role 10=admin,1=common,100=root) and promote
  u2="na2_$RANDOM"
  cr="$(sess cj_root POST /api/user/ "{\"username\":\"$u2\",\"password\":\"Passw0rd!x\",\"display_name\":\"$u2\"}")"
  u2id="$(sess cj_root GET "/api/user/search?keyword=$u2" | "$JQ" -r '.data.items[0].id // .data[0].id // empty')"
  sess cj_root POST /api/user/manage "{\"id\":$u2id,\"action\":\"promote\"}" >/dev/null
  l2="$(login cj_u2 "$u2" 'Passw0rd!x')"
  dump="$(sess cj_u2 GET '/api/user/?p=1&page_size=100')"
  # find root record (role 100) and whether its access_token field is present+nonempty
  rootrec_present="$(echo "$dump" | "$JQ" -r '[.data.items[]? // .data[]? | select(.role==100)] | length')"
  root_at_leaked="$(echo "$dump" | "$JQ" -r '[.data.items[]? // .data[]? | select(.role==100) | .access_token // "" | select(length>0)] | length')"
  if [ "$l2" != 200 ] || [ -z "$u2id" ]; then
    row CVE-2026-64859 root_token INVALID "admin2 setup failed (login=$l2 id=$u2id create=$(echo "$cr"|"$JQ" -r '.success'))"
  elif [ "$rootat_present_self" != true ]; then
    row CVE-2026-64859 root_token INVALID "precondition: root has no access_token after /token"
  elif [ "${rootrec_present:-0}" -lt 1 ]; then
    row CVE-2026-64859 root_token INVALID "positive control: root record not in admin2's list view"
  elif [ "${root_at_leaked:-0}" -ge 1 ]; then
    row CVE-2026-64859 root_token FAIL "non-root admin's GET /api/user/ exposes root access_token (nonempty)"
  else
    row CVE-2026-64859 root_token PASS "root record present but access_token absent/empty in admin2's list"
  fi
fi
rm -f "$RUN"/cj_* 2>/dev/null

# R3 and R5 are appended by the finalized functions once their reachability check passes.
[ -f "$(dirname "$0")/21b_newapi_r3r5.sh" ] && source "$(dirname "$0")/21b_newapi_r3r5.sh"
echo "--- rows appended to $out"
