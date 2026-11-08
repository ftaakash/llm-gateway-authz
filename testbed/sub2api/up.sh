#!/usr/bin/env bash
# Bring up one Sub2API rung on the internal network with in-network Postgres + Redis
# + WireMock. Fresh volumes each call. Arg: <image_tag>. Local only, no host ports.
# NOTE: Sub2API's exact env keys are confirmed against the running image in phase 1
# (probe step) before the R6 cell counts; this script is adjusted there if needed.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${NET:-pilot10}"
MOCKW="$(cd "/c/Users/Administrator/Desktop/Masters/pilots/10-llm-gateway-authz/testbed/mocks" && pwd -W)"
IMG="${1:?usage: up.sh <sub2api_image_tag>}"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-mock p10-sub2api p10-sub-db p10-sub-redis >/dev/null 2>&1 || true
docker volume rm p10_subdb >/dev/null 2>&1 || true

MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker run -d --name p10-mock --network "$NET" -v "$MOCKW:/home/wiremock" wiremock/wiremock:3.13.1 --disable-banner >/dev/null
docker run -d --name p10-sub-db --network "$NET" -v p10_subdb:/var/lib/postgresql/data \
  -e POSTGRES_USER=sub2api -e POSTGRES_PASSWORD=sub2api -e POSTGRES_DB=sub2api \
  library/postgres:16.4-alpine >/dev/null
docker run -d --name p10-sub-redis --network "$NET" library/redis:7.4.1-alpine >/dev/null
for i in $(seq 1 30); do docker exec p10-sub-db pg_isready -U sub2api >/dev/null 2>&1 && break; sleep 2; done

# env keys confirmed from deploy/docker-compose.yml (auto-init admin on first run).
# --restart unless-stopped: the setup wizard exits(0) to apply config; Docker then
# restarts it automatically with the persisted config (full API registers).
docker run -d --name p10-sub2api --network "$NET" --restart unless-stopped \
  -e DATABASE_HOST=p10-sub-db -e DATABASE_PORT=5432 -e DATABASE_USER=sub2api \
  -e DATABASE_PASSWORD=sub2api -e DATABASE_DBNAME=sub2api -e DATABASE_SSLMODE=disable \
  -e REDIS_HOST=p10-sub-redis -e REDIS_PORT=6379 -e REDIS_DB=0 \
  -e ADMIN_EMAIL=admin@sub2api.local -e ADMIN_PASSWORD=Adminpass123 \
  -e JWT_SECRET=pilot10testjwtsecret0000000000000000 \
  -e SERVER_PORT=8080 -e TZ=UTC "$IMG" >/dev/null

# wait for the setup wizard to answer
for i in $(seq 1 60); do
  s="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 5 http://p10-sub2api:8080/setup/status 2>/dev/null || true)"
  [ "$s" = 200 ] && break; sleep 3
done
# run the setup install (fresh volume each rung); app restarts itself afterwards
INSTALL='{"database":{"host":"p10-sub-db","port":5432,"user":"sub2api","password":"sub2api","dbname":"sub2api","sslmode":"disable"},"redis":{"host":"p10-sub-redis","port":6379,"username":"","password":"","db":0,"enable_tls":false},"admin":{"email":"admin@sub2api.local","password":"Adminpass123"},"server":{"host":"0.0.0.0","port":8080,"mode":"release"},"jwt":{"secret":"pilot10testjwtsecret0000000000000000","expire_hour":24},"timezone":"UTC"}'
needs="$(drv "$NET" -s http://p10-sub2api:8080/setup/status | "$JQ" -r '.data.needs_setup')"
if [ "$needs" = true ]; then
  drv "$NET" -s -X POST http://p10-sub2api:8080/setup/install -H 'Content-Type: application/json' -d "$INSTALL" >/dev/null || true
  # the app exits(0) to apply config; Docker (--restart unless-stopped) brings it
  # back automatically. Also nudge a start in case it is momentarily 'exited'.
  for i in $(seq 1 40); do
    st="$(docker inspect p10-sub2api --format '{{.State.Status}}' 2>/dev/null)"
    [ "$st" = exited ] && docker start p10-sub2api >/dev/null 2>&1 || true
    c="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 4 -X POST http://p10-sub2api:8080/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@sub2api.local","password":"Adminpass123"}' 2>/dev/null)"
    [ "$c" = 200 ] && break; sleep 3
  done
fi
ok=FAILED
code="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST http://p10-sub2api:8080/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@sub2api.local","password":"Adminpass123"}' 2>/dev/null)"
[ "$code" = 200 ] && ok=READY
echo "sub2api rung $IMG : $ok (login=$code)"
[ "$ok" = READY ] || { echo "---- last 50 log lines ----"; docker logs --tail 50 p10-sub2api 2>&1; exit 1; }
