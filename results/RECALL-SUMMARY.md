# Recall ladder results — kill condition 3 (recall half)

**Phase 1, this session.** Source: `results/recall.csv` (every row carries the image digest and the
commit it ran at). These are **already-patched, public advisories** used as a correctness oracle, so the
pass/fail counts here are not candidate findings and may be reported. The admission rule is the frozen one
(SCOPE.md / VERSIONS.md): a test counts as *rediscovered* only if it flips **FAIL on the affected image →
PASS on the fixed image, exactly at the predicted fixing version**, with the positive control holding.

## Verdict per advisory

| # | Advisory | Gateway | Affected → Fixed (predicted) | Observed flip | Rediscovered? |
|---|---|---|---|---|---|
| R1 | CVE-2026-47101 (key `allowed_routes`/`key_type` scope escalation) | LiteLLM | v1.83.13-nightly → **v1.83.14-stable** | FAIL through 1.83.13; **PASS at 1.83.14-stable** | **YES** |
| R2 | CVE-2026-47102 (self `user_role` change) | LiteLLM | v1.83.7-stable → **v1.83.8-nightly** | FAIL 1.83.6/1.83.7; **PASS from 1.83.8-nightly** (L0 predecessor 1.83.6 also FAIL, H3) | **YES** |
| R3 | CVE-2026-71479 (image-`n` overflow → self-credit, metering) | new-api | v1.0.0-rc.17 → **v1.0.0-rc.18** | FAIL rc.17 (balance increased); **PASS rc.18** (crafted n rejected, balance unchanged) | **YES** |
| R4 | CVE-2026-64859 (admin user-list leaks root `access_token`) | new-api | v1.0.0-rc.6 → **v1.0.0-rc.7** | FAIL rc.6; **PASS rc.7** (`json:"-"`) | **YES** |
| R5 | CVE-2026-30886 (video `task_id` IDOR) | new-api | v0.11.4-alpha.1 → alpha.2 | **not exercised this session** (video task lifecycle through the mock not built) | pending |
| R6 | CVE-2026-73079 (responses subpath splice) | Sub2API | 0.1.168 → 0.1.169 | testbed provisioned; tenant traffic reaches the mock, but the **vulnerable raw-splice variant not faithfully reproducible with mocks** | **INVALID / not-rediscovered** (D4/D6) |

## Kill condition 3 — recall half

> "of 6 pre-selected advisories, **fewer than 4** flip FAIL→PASS exactly at the fixing version → KILL the method."

**4 of 6 flip exactly at their fixing version (R1, R2, R3, R4). 4 ≥ 4 → recall PASSES; the method is NOT killed.**

R5 and R6 do not change this outcome (4 already meets the threshold), but for completeness:
- **R6** was marked UNVERIFIED for mock-reachability at freeze time (VERSIONS.md). At run time the Sub2API
  testbed stands up fully (install, compliance, group, upstream/apikey account, user balance, tenant
  api-key) and tenant traffic reaches the mock (an `apikey` passthrough control request is journaled), but
  the advisory's **raw subpath-splice** path is not reachable with mock providers: the `apikey` passthrough
  normalizes `/v1/responses` → `/v1/chat/completions` (no raw splice), and the `upstream` account type (the
  advisory's "operator-configured base URL") returns 502 before the mock on both `/v1/responses` and
  `/backend-api/codex/responses/*subpath`. The raw passthrough that the advisory describes is tied to the
  ChatGPT/Codex **OAuth** passthrough, whose login cannot be mocked under SCOPE. Per the KC1 D4/D6 rule a
  path not reachable with mocks counts as **not rediscovered**, never a vacuous PASS/FAIL.
- **R5** (video IDOR) needs a video channel + mock upstream task lifecycle (submit → task_id → content
  proxy) comparable to R3's build; not completed this session. To finish next.

## Oracle discipline applied (per cell)
- Fix-specific signatures (review-1 H1) in VERSIONS.md "Oracle signatures"; a non-matching refusal is
  INVALID, not PASS.
- Positive control on every counted cell (R1 safe-preset key mints+works; R2 own-field update 200; R3 the
  n=1 call bills; R4 root record present in the admin-2 list).
- R2 recall verdict = `org_admin` sub-cell; `internal_user` is supporting only (H2).
- R2 mainline predecessor L0 `v1.83.6-nightly` pinned and run as a control, must FAIL (H3) — it does.
- H4 WireMock dot-segment journaling control passed before any R6 observation
  (`env/r6-mockjournal-control.csv`).

## Evidence
- `results/recall.csv` — every row: timestamp, gateway, rung, image digest, advisory, sub-cell, verdict,
  observation, commit.
- `env/net-isolation.csv` — egress probe (internal network, IP+DNS egress BLOCKED) run before any cell.
- `env/pins.tsv`, `env/pull-log.csv` — digest pins and pull log (all images on D:).
