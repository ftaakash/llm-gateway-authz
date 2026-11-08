#!/usr/bin/env bash
# Bring up one LiteLLM rung on the internal network with an in-network Postgres and
# WireMock. Fresh volumes each call. Args: <image_tag>. Exports nothing; prints readiness.
# Local only: no host ports published; the net is --internal (no egress).
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${NET:-pilot10}"
MOCKW="$(cd "/c/Users/Administrator/Desktop/Masters/pilots/10-llm-gateway-authz/testbed/mocks" && pwd -W)"
IMG="${1:?usage: up.sh <litellm_image_tag>}"
MASTER="sk-pilot10-master"
HERE="$(cd "$(dirname "$0")" && pwd -W)"   # Windows form for the Docker bind mount

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-mock p10-ll-db p10-litellm >/dev/null 2>&1 || true
docker volume rm p10_lldb >/dev/null 2>&1 || true

MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker run -d --name p10-mock --network "$NET" -v "$MOCKW:/home/wiremock" wiremock/wiremock:3.13.1 --disable-banner >/dev/null
docker run -d --name p10-ll-db --network "$NET" -v p10_lldb:/var/lib/postgresql/data \
  -e POSTGRES_USER=litellm -e POSTGRES_PASSWORD=litellm -e POSTGRES_DB=litellm \
  library/postgres:16.4-alpine >/dev/null
# wait for DB
for i in $(seq 1 30); do docker exec p10-ll-db pg_isready -U litellm >/dev/null 2>&1 && break; sleep 2; done

MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker run -d --name p10-litellm --network "$NET" \
  -v "$HERE/config.yaml:/app/config.yaml:ro" \
  -e LITELLM_MASTER_KEY="$MASTER" \
  -e DATABASE_URL="postgresql://litellm:litellm@p10-ll-db:5432/litellm" \
  -e STORE_MODEL_IN_DB="False" \
  "$IMG" --config /app/config.yaml --port 4000 >/dev/null

# wait for proxy health (in-network, via driver)
ok=FAILED
for i in $(seq 1 60); do
  code="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 5 http://p10-litellm:4000/health/liveliness 2>/dev/null || true)"
  [ "$code" = 200 ] && { ok=READY; break; }
  sleep 3
done
echo "litellm rung $IMG : $ok"
[ "$ok" = READY ] || { echo "---- last 40 log lines ----"; docker logs --tail 40 p10-litellm 2>&1; exit 1; }
