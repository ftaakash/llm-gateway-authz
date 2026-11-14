#!/usr/bin/env bash
# Start the raw request-line observer on the internal (no-egress) network as
# p10-observer, listening :8080. Runs observer.go via `go run` in the pinned
# golang image (stdlib only, GOTOOLCHAIN=local, no modules, no network). Local
# only, no host ports. The network must already exist (a gateway up.sh creates it)
# or is created here.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${NET:-pilot10}"
OBSDIR="$(cd "$(dirname "$0")" && pwd -W)"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-observer >/dev/null 2>&1 || true
# OBSDIR is Windows-form (pwd -W); MSYS_NO_PATHCONV keeps the /obs mount target and
# -w /obs from being rewritten to a Windows path by the MSYS shell.
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker run -d --name p10-observer --network "$NET" \
  -v "$OBSDIR:/obs:ro" -e GOTOOLCHAIN=local -e GOCACHE=/tmp/gocache -e GO111MODULE=off \
  -w /obs golang:1.27.3-alpine go run observer.go >/dev/null
ok=FAILED
for i in $(seq 1 40); do
  c="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 3 http://p10-observer:8080/__journal 2>/dev/null || true)"
  [ "$c" = 200 ] && { ok=READY; break; }
  sleep 2
done
echo "observer $ok"
[ "$ok" = READY ] || { echo "---- observer logs ----"; docker logs --tail 20 p10-observer 2>&1; exit 1; }
