#!/usr/bin/env bash
# Verify the testbed network is local-only: no container egress to the internet,
# in-network traffic + embedded DNS still work. Brings up a throwaway WireMock as
# the in-network positive-control service. Evidence (not a result): env/net-isolation.csv.
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"
out="$PILOT/env/net-isolation.csv"
[ -f "$out" ] || echo "net,check,expected,got,ok,commit" > "$out"
row() { local ok=no; [ "$2" = "$3" ] && ok=yes; echo "$NET,$1,$2,$3,$ok,$COMMIT" >> "$out"; printf '%-26s expected=%-8s got=%-8s %s\n' "$1" "$2" "$3" "$ok"; }

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f p10-mock >/dev/null 2>&1 || true
docker run -d --name p10-mock --network "$NET" wiremock/wiremock:3.13.1 --disable-banner >/dev/null
# wait for mock admin to answer, in-network
for i in $(seq 1 30); do
  up="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 4 http://p10-mock:8080/__admin/health 2>/dev/null || true)"
  [ "$up" = 200 ] && break; sleep 2
done

row network_internal_flag true "$(docker network inspect "$NET" --format '{{.Internal}}')"

# Positive control: the SAME wget binary reaches an in-network service.
ctl="$(docker run --rm --network "$NET" wiremock/wiremock:3.13.1 --version >/dev/null 2>&1; echo probe)"
ctl="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 6 http://p10-mock:8080/__admin/health 2>/dev/null || echo FAILED)"
row egress_probe_control 200 "$ctl"

# Egress by IP (bypasses DNS): internal network has no route out.
eg_ip="$(drv "$NET" -s -o /dev/null --max-time 6 http://1.1.1.1 2>/dev/null && echo REACHED || echo BLOCKED)"
row egress_ip_1.1.1.1 BLOCKED "$eg_ip"
# Egress by name (DNS + route out).
eg_dns="$(drv "$NET" -s -o /dev/null --max-time 6 https://example.com 2>/dev/null && echo REACHED || echo BLOCKED)"
row egress_dns_example.com BLOCKED "$eg_dns"
# Embedded DNS resolves an in-network service name.
dns_local="$(drv "$NET" -s -o /dev/null -w '%{http_code}' --max-time 6 http://p10-mock:8080/__admin/health 2>/dev/null)"
row driver_to_mock_health 200 "$dns_local"
# No container port published to host.
row host_published_ports 0 "$(docker port p10-mock 2>/dev/null | wc -l | tr -d ' ')"

docker rm -f p10-mock >/dev/null 2>&1 || true
echo "--- $out"
