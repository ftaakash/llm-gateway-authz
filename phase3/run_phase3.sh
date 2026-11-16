#!/usr/bin/env bash
# Phase-3 COUNTING RUN (single run, from the frozen-cells commit). Measures the
# current-release VERDICT for each admitted (invariant × gateway) cell and runs the
# A10 sanity-leg existence check for the rebuilt cells. Results are Phase-3 data and
# go to private/phase3/ ONLY (never tracked / mirror / cross-session). Admission is
# established elsewhere: G2 recall ladder (results/recall.csv, FAIL affected →
# PASS fixed); G6 the no-op rebuild controls. Coverage here:
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
# cannot be swapped without a commit (A10(3)). new-api is measured only via the
# independently written blind cell, which manages its own pinned images and legs;
# the runner passes it invariant NAMES, not images.
IMG_LITELLM="ghcr.io/berriai/litellm:v1.108.2@sha256:d8b4ac356743d647a13bb93f45b941fcd5f5354122cfd205948a1b192790389d"
IMG_SUB2API_VERDICT="weishaw/sub2api:0.2.20@sha256:ebdd50dda32e7a30c840de884d29dd7cbe52776d34fe2899733535f16a0b2813"
IMG_SUB2API_SANITY="weishaw/sub2api:0.1.178@sha256:e0f019383025679bd3b0f912c21fe7d8afdba8e42613391fa7fa208cc0762e60"

# F5: the new-api blind cell is COUNTED only at the exact reviewed blob. Record the
# reviewed git blob sha of phase3/newapi_verdict_blind.sh here at the cell's admission
# commit; it is EMPTY until then, so the blind call records NOT_RUN. The cell runs only
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
  echo "## new-api (INV-G1,G3,G4,G5) — via the blind cell (F7: call once by invariant NAMES)"
  echo "## F5-gated on the reviewed blob sha; the blind cell runs its own sanity/verdict legs; rows PRIVATE."
  if blind_ok; then
    # G1's rebuild admission is established separately; override G1_S2_CLEARED=0 to
    # exclude G1 if ever needed.
    PHASE3_GO=1 G1_S2_CLEARED="${G1_S2_CLEARED:-1}" bash "$BLIND" G1 G3 G4 G5
    echo "### new-api admission + verdict rows -> $PILOT/private/phase3-blind/newapi_verdict_blind.csv (private)"
  else
    echo "VERDICT=NOT_RUN CELL=G1/G3/G4/G5 REASON=\"blind cell absent or not at the reviewed blob (F5); new-api not measured\""
  fi
  echo
  echo "## Sub2API G6 sanity-leg existence check (A10)"
  echo "### G6 sanity — Sub2API 0.1.178 (G26-selected expected-pass build; group-platform setting + upstream path-confinement guard present):"
  bash "$D/sub2api_verdict.sh" "$IMG_SUB2API_SANITY" "$RUNCMT"
  echo
  echo "## VERDICT legs (current releases — single execution)"
  echo "### LiteLLM v1.108.2 — G2:"
  bash "$D/litellm_verdict.sh" "$IMG_LITELLM" "$RUNCMT"
  echo "### Sub2API 0.2.20 — G6:"
  bash "$D/sub2api_verdict.sh" "$IMG_SUB2API_VERDICT" "$RUNCMT"
} | tee "$RES"
echo "### wrote $RES (private)"
