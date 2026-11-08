#!/usr/bin/env bash
# Bring up one new-api rung on the internal network (SQLite, single container) +
# WireMock. Fresh volume each call. Arg: <image_tag>. Local only, no host ports.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${NET:-pilot10}"
IMG="${1:?usage: up.sh <newapi_image_tag>}"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-mock p10-newapi >/dev/null 2>&1 || true
docker volume rm p10_newapi >/dev/null 2>&1 || true

docker run -d --name p10-mock --network "$NET" wiremock/wiremock:3.13.1 --disable-banner >/dev/null
# SQLite mode: no SQL_DSN. Root user root/123456 is auto-created on first boot.
docker run -d --name p10-newapi --network "$NET" -v p10_newapi:/data \
  -e TZ=UTC "$IMG" >/dev/null

ok=FAILED
for i in $(seq 1 60); do
  code="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 5 http://p10-newapi:3000/api/status 2>/dev/null || true)"
  [ "$code" = 200 ] && { ok=READY; break; }
  sleep 3
done
echo "new-api rung $IMG : $ok"
[ "$ok" = READY ] || { echo "---- last 40 log lines ----"; docker logs --tail 40 p10-newapi 2>&1; exit 1; }
