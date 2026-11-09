# llm-gateway-authz

A reproducible, **local-only regression-test suite** that checks whether open-source **LLM gateways**
enforce their own authorization and metering invariants: key/role scope, ownership of per-user resources
(tasks, channels, upstream accounts), and quota/billing accounting.

This is **half 2 of Paper A** ("authorization invariants at intermediaries nobody verifies"). Half 1 is
the Dataspace Protocol connector suite, [authz-ladder](https://github.com/ftaakash/authz-ladder). Both
halves share one method: an invariant catalogue, a CVE-ladder oracle, and a local no-egress testbed.

## The oracle

Already-patched, publicly disclosed advisories are the correctness oracle. A test is admitted only if it
**FAILs on the affected version and PASSes on the fixed version**, flipping **exactly at the fixing
version**, with a positive control on every cell. A test that cannot be made to do both — or whose code
path is not reachable with mock providers — is recorded **INVALID**, never a vacuous pass/fail. Results
are **pass/fail only**; there are no exploit payloads.

## The recall ladder (kill condition 3, recall half)

Six pre-selected 2026 advisories across three gateways, frozen before any test ran
([VERSIONS.md](VERSIONS.md)). Each must flip FAIL→PASS at its fixing version to count; the method is kept
only if **at least 4 of 6** flip.

| # | Advisory | Gateway | Affected → Fixed |
|---|---|---|---|
| R1 | CVE-2026-47101 (key route-scope escalation) | LiteLLM | v1.83.13-nightly → v1.83.14-stable |
| R2 | CVE-2026-47102 (self role change) | LiteLLM | v1.83.7-stable → v1.83.8-nightly |
| R3 | CVE-2026-71479 (image-`n` overflow → self-credit, metering) | new-api | v1.0.0-rc.17 → v1.0.0-rc.18 |
| R4 | CVE-2026-64859 (admin user-list leaks root token) | new-api | v1.0.0-rc.6 → v1.0.0-rc.7 |
| R5 | CVE-2026-30886 (video task_id IDOR) | new-api | v0.11.4-alpha.1 → v0.11.4-alpha.2 |
| R6 | CVE-2026-73079 (responses subpath splice) | Sub2API | 0.1.168 → 0.1.169 |

Per-run results, each row stamped with the image digest and the commit it ran at, are in
[results/recall.csv](results/recall.csv); the verdict write-up is in
[results/RECALL-SUMMARY.md](results/RECALL-SUMMARY.md).

## Testbed

- Docker, internal (`--internal`) network with **no egress** — verified by an egress probe before any
  cell runs ([env/net-isolation.csv](env/net-isolation.csv)).
- **Mock model providers only** (WireMock stubs + request journal). No traffic ever reaches OpenAI,
  Anthropic or any real provider or third-party gateway.
- Gateway images pinned **by digest** ([env/pins.tsv](env/pins.tsv)); an ephemeral `curl` driver
  container issues requests, and JSON is parsed on the host.

## Scope and ethics

- **Local-only, defensive** conformance-style testing. Never scans or probes any third-party or live
  system. No weaponization — assertions return pass/fail, not distributable exploits.
- Disclosure (if any) is the maintainer-decided author's call and goes only to each project's **private
  security channel** under a 90-day default embargo; it is never auto-sent.
- This public repository carries only **recall results on already-patched, public advisories**. Any new
  (undisclosed) finding on a current release is kept out of this history entirely.

See [SCOPE.md](SCOPE.md) for the full framing and [DECISIONS.md](DECISIONS.md) for the decision log.

---
Part of Paper A, half 2. Half 1: https://github.com/ftaakash/authz-ladder
