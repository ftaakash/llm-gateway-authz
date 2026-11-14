#!/usr/bin/env bash
# Phase-3 COUNTING RUN (single run, from the frozen-cells commit). Measures the
# current-release VERDICT for each admitted (invariant × gateway) cell and runs the
# A10 sanity-leg existence check for the rebuilt cells. Results are Phase-3 data and
# go to private/phase3/ ONLY (never tracked / mirror / cross-session). Admission is
# established elsewhere: G2 recall ladder (results/recall.csv, FAIL affected →
# PASS fixed); G6 the S2 no-op rebuild controls (private/s2-control/). Coverage here:
# LiteLLM (G2), Sub2API (G6), new-api (G1,G3,G4,G5). **new-api is measured ONLY via the
# independently written, reviewed blind cell `phase3/newapi_verdict_blind.sh`** — the
# earlier new-api cell is set aside and not counted. If the blind cell
# is ABSENT, the runner records new-api as NOT_RUN (new-api not measured) and coverage
# is LiteLLM (G2) + Sub2API (G6) = 2 gateways, so the KC3 new-violation half is
# INCOMPLETE and below the ≥3 novelty bar (A6) until the blind cell is admitted.
#
# Verdict semantics: PASS = current release ENFORCES the invariant (no new violation).
# FAIL = violated → candidate new finding → the caller must report "needs user
# attention" (no detail). INVALID = precondition / positive control not met.
set +e
D="$(cd "$(dirname "$0")" && pwd)"; PILOT="$(cd "$D/.." && pwd)"
RUNCMT="$(git -C "$PILOT" rev-parse --short HEAD)"
OUTDIR="$PILOT/private/phase3"; mkdir -p "$OUTDIR"
RES="$OUTDIR/phase3-results.txt"

# L15: every image is referenced by digest (pinned in env/pins.tsv). F6: the G6 sanity
# build is hard-coded to the G26 selection — no run-time override, so the sanity build
# cannot be swapped without a commit (A10(3)).
IMG_LITELLM="ghcr.io/berriai/litellm:v1.108.2@sha256:d8b4ac356743d647a13bb93f45b941fcd5f5354122cfd205948a1b192790389d"
IMG_SUB2API_VERDICT="weishaw/sub2api:0.2.20@sha256:ebdd50dda32e7a30c840de884d29dd7cbe52776d34fe2899733535f16a0b2813"
IMG_SUB2API_SANITY="weishaw/sub2api:0.1.178@sha256:e0f019383025679bd3b0f912c21fe7d8afdba8e42613391fa7fa208cc0762e60"
IMG_NEWAPI_SANITY="calciumion/new-api:v1.0.0-rc.23@sha256:bacbbfbed64b4579213316e0ed78415985223bb20c47fbc24572dd7be5aa1695"
IMG_NEWAPI_VERDICT="calciumion/new-api:v1.0.0-rc.48@sha256:51401a46510bf110ffafdf2cd7177e0b80bbcf02439e69b665c696f330e87ae5"

# F5: the new-api blind cell is COUNTED only at the exact reviewed blob. Record the
# reviewed git blob sha of phase3/newapi_verdict_blind.sh here at the cell's admission
# commit; it is EMPTY until then, so the blind legs record NOT_RUN. The cell runs only
# on an exact sha match — a present-but-unreviewed (or edited) blind cell is never counted.
BLIND="$D/newapi_verdict_blind.sh"
BLIND_REVIEWED_SHA=""   # set via: git hash-object phase3/newapi_verdict_blind.sh  (at admission)
blind_ok() {
  [ -n "$BLIND_REVIEWED_SHA" ] && [ -f "$BLIND" ] || return 1
  [ "$(git -C "$PILOT" hash-object "$BLIND" 2>/dev/null)" = "$BLIND_REVIEWED_SHA" ]
}
{
  echo "# Phase-3 counting run — $(date -u +%FT%TZ) — frozen commit $RUNCMT"
  echo "# PASS=current release enforces (no new violation); FAIL=candidate; INVALID=precondition/control unmet."
  echo
  echo "## A10 sanity-leg existence checks (rebuilt cells)"
  echo "### G1 sanity — new-api rc.23 (via the reviewed blind cell; F5-gated on the reviewed blob sha):"
  if blind_ok; then bash "$BLIND" "$IMG_NEWAPI_SANITY" "$RUNCMT" | grep "CELL=G1"
  else echo "VERDICT=NOT_RUN CELL=G1 REASON=\"blind cell absent or not at the reviewed blob (F5); new-api not measured\""; fi
  echo "### G6 sanity — Sub2API 0.1.178 (G26-selected expected-pass build; group-platform setting + upstream path-confinement guard present):"
  bash "$D/sub2api_verdict.sh" "$IMG_SUB2API_SANITY" "$RUNCMT"
  echo
  echo "## VERDICT legs (current releases — single execution)"
  echo "### new-api v1.0.0-rc.48 — G1,G3,G4,G5 (via the reviewed blind cell; F5-gated on the reviewed blob sha):"
  if blind_ok; then bash "$BLIND" "$IMG_NEWAPI_VERDICT" "$RUNCMT"
  else echo "VERDICT=NOT_RUN CELL=G1/G3/G4/G5 REASON=\"blind cell absent or not at the reviewed blob (F5); new-api not measured\""; fi
  echo "### LiteLLM v1.108.2 — G2:"
  bash "$D/litellm_verdict.sh" "$IMG_LITELLM" "$RUNCMT"
  echo "### Sub2API 0.2.20 — G6:"
  bash "$D/sub2api_verdict.sh" "$IMG_SUB2API_VERDICT" "$RUNCMT"
} | tee "$RES"
echo "### wrote $RES (private)"
