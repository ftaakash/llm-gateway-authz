<div align="center">

# llm-gateway-authz

**Regression-testing authorization & metering invariants in open-source LLM gateways,<br>using already-patched CVEs as a correctness oracle.**

![recall](https://img.shields.io/badge/recall%20(kill%20condition%203)-4%2F6%20passed-success)
![phase2](https://img.shields.io/badge/phase%202%20invariant%20catalogue-in%20progress-yellow)
![scope](https://img.shields.io/badge/scope-local%20testbed%20only-blue)
![output](https://img.shields.io/badge/output-pass%2Ffail%20only-lightgrey)
![providers](https://img.shields.io/badge/model%20providers-mocked%2C%20no%20egress-blue)
![SUT](https://img.shields.io/badge/SUT-LiteLLM%20%7C%20new--api%20%7C%20Sub2API%20%7C%20one--api-6f42c1)

</div>

---

## What this is

An **LLM gateway** (LiteLLM, new-api, one-api, Sub2API, …) holds every provider key, meters every
tenant, and routes every request. It is an unverified intermediary whose authorization logic — key/role
scope, ownership of per-tenant resources, quota/billing accounting — nobody tests systematically, in the
same way nobody systematically tests a Dataspace Protocol connector's authorization rules.

**llm-gateway-authz** is a reproducible, **local-only regression-test suite** for those rules. Each test is
a pass/fail assertion about one invariant, and a test is admitted only once it is shown to measure
something real:

> A test is valid only if it **FAILs on the affected release** and **PASSes on the fixed release**, flipping
> at **exactly** the version that shipped the fix, with a positive control on every cell.

A test that cannot be made to do both — or whose code path is not reachable with mock providers — is
recorded **INVALID**, never a vacuous pass/fail. Results are **pass/fail only**; there are no exploit
payloads. Admitted tests are then run against **current releases** to look for new violations (that half is
in progress; see Status).

This is **half 2 of Paper A** ("authorization invariants at intermediaries nobody verifies"). Half 1 is the
Dataspace Protocol connector suite, [authz-ladder](https://github.com/ftaakash/authz-ladder). Both halves
share one method: an invariant catalogue, a CVE-ladder oracle, and a local no-egress testbed.

## Results so far

### Recall (kill condition 3, recall half): ✅ PASSES 4/6

Six pre-selected 2026 advisories across three gateways, frozen before any test ran
([VERSIONS.md](VERSIONS.md)). Each must flip FAIL→PASS **at its fixing version** to count; the method is kept
only if **at least 4 of 6** flip. **Four flip faithfully — the method is not killed.**

| # | Advisory | Gateway | Affected → Fixed | Rediscovered? |
|---|---|---|---|---|
| R1 | CVE-2026-47101 (key route-scope escalation) | LiteLLM | v1.83.13-nightly → v1.83.14-stable | **INVALID** ¹ |
| R2 | CVE-2026-47102 (self role change) | LiteLLM | v1.83.7-stable → **v1.83.8-nightly** | ✅ yes |
| R3 | CVE-2026-71479 (image-`n` overflow → self-credit, metering) | new-api | v1.0.0-rc.17 → **v1.0.0-rc.18** | ✅ yes |
| R4 | CVE-2026-64859 (admin user-list leaks root token) | new-api | v1.0.0-rc.6 → **v1.0.0-rc.7** | ✅ yes |
| R5 | CVE-2026-30886 (video task_id IDOR) | new-api | v0.11.4-alpha.1 → **v0.11.4-alpha.2** | ✅ yes ³ |
| R6 | CVE-2026-73079 (responses subpath splice) | Sub2API | 0.1.168 → 0.1.169 | **INVALID** ² |

¹ **R1 INVALID (not rediscovered):** the escalation primitive flips at the fixing version, but on this ladder
the escalated key reaches **no admin-only route** on either version, so the frozen reach signature is not met —
not a vacuous mint-only FAIL. ² **R6 INVALID (not rediscovered):** the testbed stands up and tenant traffic
reaches the mock, but the advisory's raw subpath-splice path is **not reproducible with mock providers**. Each
counts as not-rediscovered (never a vacuous pass/fail); no exploit detail is published here.

³ **R5 history:** the first R5 run was recorded **INVALID** — A's own-content fetch (the positive control) was
refused on both rungs because the mock did not let A's legitimate video task complete (review 3, B1). After a
**setup fix** (the mock now lets A's task complete; the frozen signature is unchanged — G17) and **aligning the
cell to the journal half already in the frozen signature** (G18), the counted re-run flips under both halves:
alpha.1 **FAIL** (B reaches A's task **and** the journal shows an upstream fetch for B) → alpha.2 **PASS** (B
"Task not found" **and** no journal fetch), with A's positive control holding on both rungs (reviews 4–5). See
[DECISIONS.md](DECISIONS.md) G17/G18 and [results/RECALL-SUMMARY.md](results/RECALL-SUMMARY.md).

The 4 counted flips span 2 gateways (LiteLLM ×1, new-api ×3). Per-run results — each row stamped with the
image digest and the commit it ran at — are in [results/recall.csv](results/recall.csv); the full verdict
write-up is in [results/RECALL-SUMMARY.md](results/RECALL-SUMMARY.md).

### Novelty-paper check (kill condition 4): does not fire

No paper testing authorization/metering invariants across ≥3 LLM gateways was found at the phase boundary, so
the novelty gate is not re-opened (logged in [env/kc4-novelty-check.md](env/kc4-novelty-check.md)).

## Status

- **Recall half — complete, PASSES 4/6** (above).
- **Phase 2 — invariant catalogue freeze: in progress.** A gateway-general catalogue of authorization/metering
  invariants (scope non-escalation, no self-elevation, metering monotonicity, role-boundary credential
  exposure, resource ownership, upstream-routing confinement, tool-call translation integrity), each admitted
  only when it PASSes a sanity configuration and FAILs a mutation configuration — the same admission rule as the
  recall oracle.
- **New-violation half — not started.** The run against **current releases** is pending the catalogue re-review
  and the author's go. Any new (undisclosed) finding on a current release is kept **out of this
  repository entirely**, under coordinated disclosure; this public repo carries only recall results on
  already-patched, public advisories.

## Testbed

- Docker, internal (`--internal`) network with **no egress** — verified by an egress probe before any cell runs
  ([env/net-isolation.csv](env/net-isolation.csv)).
- **Mock model providers only** (WireMock stubs + request journal). No traffic ever reaches OpenAI, Anthropic,
  or any real provider or third-party gateway.
- Gateway images pinned **by digest** ([env/pins.tsv](env/pins.tsv)); an ephemeral `curl` driver container
  issues requests, and JSON is parsed on the host.
- Any credentials in `testbed/` and the scripts (the local master key, admin/root passwords, the JWT secret,
  dummy upstream keys) are **throwaway local test-only values** for disposable mock containers on the internal
  no-egress network — **not real secrets**.

## Scope and ethics

- **Local-only, defensive** conformance-style testing. Never scans or probes any third-party or live system. No
  weaponization — assertions return pass/fail, not distributable exploits.
- Disclosure (if any) is the maintainer-decided author's call and goes only to each project's **private security
  channel** under a 90-day default embargo; it is never auto-sent.
- This public repository carries only **recall results on already-patched, public advisories**. Any new
  (undisclosed) finding on a current release is kept out of this history entirely.

See [SCOPE.md](SCOPE.md) for the full framing and [DECISIONS.md](DECISIONS.md) for the decision log.

---
Part of Paper A, half 2. Half 1: https://github.com/ftaakash/authz-ladder
