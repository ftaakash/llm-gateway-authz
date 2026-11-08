#!/usr/bin/env bash
# Bring up one Sub2API rung on the internal network with in-network Postgres + Redis
# + WireMock. Fresh volumes each call. Arg: <image_tag>. Local only, no host ports.
# NOTE: Sub2API's exact env keys are confirmed against the running image in phase 1
# (probe step) before the R6 cell counts; this script is adjusted there if needed.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${NET:-pilot10}"
IMG="${1:?usage: up.sh <sub2api_image_tag>}"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-mock p10-sub2api p10-sub-db p10-sub-redis >/dev/null 2>&1 || true
docker volume rm p10_subdb >/dev/null 2>&1 || true

docker run -d --name p10-mock --network "$NET" wiremock/wiremock:3.13.1 --disable-banner >/dev/null
docker run -d --name p10-sub-db --network "$NET" -v p10_subdb:/var/lib/postgresql/data \
  -e POSTGRES_USER=sub2api -e POSTGRES_PASSWORD=sub2api -e POSTGRES_DB=sub2api \
  library/postgres:16.4-alpine >/dev/null
docker run -d --name p10-sub-redis --network "$NET" library/redis:7.4.1-alpine >/dev/null
for i in $(seq 1 30); do docker exec p10-sub-db pg_isready -U sub2api >/dev/null 2>&1 && break; sleep 2; done

# env keys below are the probe-time default guess; confirmed before R6 counts.
docker run -d --name p10-sub2api --network "$NET" \
  -e DB_TYPE=postgres \
  -e DB_HOST=p10-sub-db -e DB_PORT=5432 -e DB_USER=sub2api -e DB_PASSWORD=sub2api -e DB_NAME=sub2api \
  -e REDIS_HOST=p10-sub-redis -e REDIS_PORT=6379 \
  -e TZ=UTC "$IMG" >/dev/null

ok=FAILED
for i in $(seq 1 60); do
  for pth in /healthz /api/health /health /; do
    code="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 5 "http://p10-sub2api:8080$pth" 2>/dev/null || true)"
    [ "$code" = 200 ] && { ok=READY; break 2; }
  done
  sleep 3
done
echo "sub2api rung $IMG : $ok"
[ "$ok" = READY ] || { echo "---- last 50 log lines ----"; docker logs --tail 50 p10-sub2api 2>&1; exit 1; }
