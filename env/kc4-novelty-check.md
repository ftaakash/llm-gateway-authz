# Kill condition 4 (gateway race) — novelty check log

KC4 fires if a paper testing authorization/metering invariants across >=3 LLM gateways appears before
the pilot ends (idea 08 kill test, amendment 2026-11-03 / D16). Checked at each phase boundary.

## 2026-11-09 (phase-1 recall boundary) — DOES NOT FIRE
- WebSearch (standard): "authorization metering invariant testing across multiple open-source LLM
  gateways LiteLLM security 2026". Venues/sources surfaced: Obsidian Security (LiteLLM chained CVEs
  blog), Cloud Security Alliance research notes (default creds, pre-auth SQLi), osv.dev/PYSEC,
  stack.watch tracker, Cerbos/Speakeasy commentary, nhimg access-control-gap commentary.
- Result: only single-product advisories and vendor commentary; NO cross-gateway (>=3) invariant- or
  metering-testing methodology, harness, or comparison paper. KC4 does not fire.
- Earlier boundary (phase 0, 2026-11-08): none found (see DECISIONS G-series / idea 10 kill test G gate).
