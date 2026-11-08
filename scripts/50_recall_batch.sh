#!/usr/bin/env bash
# Run the full recall ladder for one gateway: for each rung, bring it up fresh,
# run its cell, tear down. Results append to results/recall.csv. Local only.
# Usage: 50_recall_batch.sh litellm | newapi | sub2api
source "$(dirname "$0")/lib.sh"
NET="${NET:-pilot10}"
GW="${1:?usage: 50_recall_batch.sh <litellm|newapi|sub2api>}"
T="$PILOT/testbed"

down() { docker rm -f p10-mock p10-litellm p10-ll-db p10-newapi p10-sub2api p10-sub-db p10-sub-redis >/dev/null 2>&1 || true; }

case "$GW" in
  litellm)
    # L0 predecessor (FAIL control), L1 FAIL, L2 PASS (frozen R2 pair); L3/L4 advisory pair; L5/L6 R1 pair
    for r in v1.83.6-nightly v1.83.7-stable v1.83.8-nightly v1.83.9-nightly v1.83.10-stable v1.83.13-nightly v1.83.14-stable; do
      echo "###### litellm $r"; down
      bash "$T/litellm/up.sh" "ghcr.io/berriai/litellm:$r" || { echo "bring-up failed $r"; continue; }
      bash "$PILOT/scripts/20_litellm_cell.sh" "$r" "ghcr.io/berriai/litellm:$r"
    done; down ;;
  newapi)
    for r in v1.0.0-rc.6 v1.0.0-rc.7 v1.0.0-rc.17 v1.0.0-rc.18 v0.11.4-alpha.1 v0.11.4-alpha.2; do
      echo "###### new-api $r"; down
      bash "$T/newapi/up.sh" "calciumion/new-api:$r" || { echo "bring-up failed $r"; continue; }
      bash "$PILOT/scripts/21_newapi_cell.sh" "$r" "calciumion/new-api:$r"
    done; down ;;
  sub2api)
    for r in 0.1.168 0.1.169; do
      echo "###### sub2api $r"; down
      bash "$T/sub2api/up.sh" "weishaw/sub2api:$r" || { echo "bring-up failed $r"; continue; }
      bash "$PILOT/scripts/22_sub2api_cell.sh" "$r" "weishaw/sub2api:$r"
    done; down ;;
  *) echo "unknown gateway $GW"; exit 2 ;;
esac
echo "=== recall batch done for $GW"
