# Pilot 10 — GatewayAuthz: scope and defensive framing

**Pilot of:** Paper A second boundary (D16 in [pilot 08 DECISIONS](../08-dsp-authfuzz/DECISIONS.md)), idea [10 GatewayAuthz](../../ideas/10-llm-gateway-authz/idea.md) · kill test: [idea 10](../../ideas/10-llm-gateway-authz/kill-test.md), as amended for Paper A in [idea 08 kill test, amendment 2026-11-03](../../ideas/08-dsp-authfuzz/kill-test.md)
**Status:** Phase 0 signed off by the user 2026-11-08 (G9). Static reachability check and freeze of the six advisories pending (G4). No image pulled, no test written, no test run.
**Timebox:** 3 weeks, ending **2026-11-29** (G11). One one-week extension only if decided before any result exists.

## What this pilot is

A reproducible, **local-only regression-test suite** that checks whether open-source LLM gateways
(LiteLLM, new-api, Sub2API, one-api; see [VERSIONS.md](VERSIONS.md)) enforce their own authorization
and metering invariants: key and role scope, ownership of per-user resources (tasks, channels, upstream
accounts), and quota/billing accounting. Already-patched, publicly disclosed advisories are the
**correctness oracle**: a test is admitted only if it **FAILs on the affected version and PASSes on the
fixed version**. Results are **pass/fail** only. Model providers are **mocks**; no request ever reaches
OpenAI, Anthropic or any other real provider, and no third-party gateway deployment is ever touched.

This is defensive security work: regression and conformance-style testing of authorization behaviour,
using the same method, rules and oracle discipline as pilot 08.

## Element-by-element framing

| Pilot element | Defensive framing |
|---|---|
| Test driver (a gateway client acting as tenant / admin / root) | A **test fixture** that exercises a gateway's own authorization and metering checks with ordinary API calls. Not an exploit tool. |
| Mock model providers | A local **WireMock** stub that answers OpenAI-compatible requests with fixed bodies and records what the gateway sent (the request journal is the observation). Replaces every real provider. |
| Rediscover 6 gateway advisories | **Regression tests for already-patched public advisories**, used as a correctness oracle: each must FAIL on the affected image and PASS on the fixed image, flipping exactly at the predicted version (VERSIONS.md). |
| Invariant catalogue | **Pass/fail assertions** derived from the gateways' documented role/scope models and the public advisories (scope non-escalation, ownership, caller-supplied identifiers never select a resource outside the caller's grant, metering monotonicity). Frozen with sanity + mutation admission (pilot 08 A1) **before** any current release is tested. |
| Find new violations | Run the frozen, admitted catalogue on the **current releases** of ≥3 gateways. A violation is a candidate finding and is handled under the disclosure rules below. |
| Targets | **Local-only** containers the researcher runs: images pinned by digest from GHCR / Docker Hub ([ENV.md](ENV.md)). |
| Output | **Pass/fail rows in a CSV** (gateway, image digest, invariant/advisory ID, result, commit hash). |

## Constraints

- **Local testbed only.** Every gateway, database and mock runs in Docker on this machine, on a Docker
  `--internal` network with no egress. Egress is verified (negative probe) before the first test run and
  the evidence is stored under `env/`. Never scan or probe any third-party or live system.
- **Mock providers only.** No traffic to OpenAI, Anthropic, Azure, Google, ChatGPT/Codex or any real
  provider or third-party gateway. Provider keys in the testbed are dummy strings.
- **No weaponization.** Tests are assertions that return PASS / FAIL / INVALID. They are derived from the
  advisory text and fix commits, not from public PoC gists or bounty write-ups, and they never ship a
  reusable exploit. Secrets used as canaries are per-run random values that are never logged or stored
  (only a boolean "canary seen / not seen" is recorded).
- **Non-destructive assertions.** Where an advisory's impact is a privilege gain, the test checks the
  gain with a read-only or self-contained call on the local testbed (e.g. "a non-admin key reaches an
  admin-only read route"), never with code execution, file reads or configuration rewrites.
- **Never weaken a target's checks** to make a test pass or fail. Mutation configurations (catalogue
  admission) are labelled test-only fixtures and never produce a counted verdict.

## Oracle vocabulary (same as pilot 08 KC1/KC2)

- **Observation** (HTTP status, body predicate, mock journal entry, balance before/after) is stored
  separately from the **verdict** (PASS / FAIL / INVALID). No verdict without its observation.
- **Positive control** on every cell: the legitimate path works (e.g. the user's own task is retrievable,
  a legitimate subpath reaches the mock, a normal request is billed). Positive control fails → **INVALID**.
- **Precondition check** before the assertion (e.g. the victim task exists, the admin/root roles are as
  set up). Not met → **INVALID**.
- **INVALID is never a PASS.** An advisory whose code path is not reachable on its ladder counts as
  **not rediscovered** (pilot 08 D4/D6 rule).

## Kill conditions that apply to this pilot

Frozen Paper-A wording (idea 08 kill test, amendment 2026-11-03 / D16). Thresholds are not changed here.

| # | Kill condition | Action on firing |
|---|---|---|
| 3 | **Recall:** fewer than **4 of the 6** pre-selected gateway advisories (VERSIONS.md, frozen at sign-off) flip FAIL→PASS **exactly at the predicted fixing version**, **or novelty:** **0** new invariant violations on the current releases of **≥3** gateways after the full frozen catalogue | **Drop the gateway half** to related work; Paper A becomes DSP-only. |
| 4 | A paper testing authorization or metering invariants across **≥3 LLM gateways** appears before the pilot ends | **Re-run Gate B** (novelty) for the gateway half. Checked at each phase boundary and before the report. |

Order: recall first. The catalogue and the current-release run happen only if recall passes (≥4 of 6).
If recall fails, stop the gateway half and report. "0 violations" may be reported only for a **complete**
frozen catalogue on ≥3 gateways; an incomplete set is reported as incomplete.

Idea-10 kill condition 4 (frame: if ≥80 % of found violations are generic web flaws such as XSS, SQLi or
SSRF rather than scope / ownership / metering → REWORK) is tracked as a framing check for the report; it is
not a Paper-A kill condition.

## Disclosure and confidentiality

- **Disclosure is the user's call.** Aakash decides whether and when to report. A report goes only to the
  **affected project's own private security channel** (GitHub private vulnerability reporting for
  LiteLLM, new-api, Sub2API; for one-api, which has no published advisories channel and is unmaintained,
  the channel is the user's decision). Default embargo: **90 days or until a patch ships, whichever comes
  first.** Nothing is ever auto-sent.
- **Candidate findings stay out of git history.** Anything produced by running the catalogue on a current
  release (observations, verdict rows, logs, specialised scripts, notes) lives under
  `pilots/10-llm-gateway-authz/private/` (gitignored by the repo `.gitignore` rule `pilots/**/private/`;
  checked 2026-11-08). Tracked files, commit messages and cross-session messages carry **no
  current-release number at all** (no per-invariant, per-target or total count), as in pilot 08 (Review 15 U1).
- Recall results on **already-patched** advisories are not candidate findings and may be tracked.
- Already-known **unpatched** public advisories (one-api CVE-2026-81027, CVE-2026-11465) are not new
  findings; a test that hits them on one-api is recorded as "known, public", never counted as new.

## Reproducibility and integrity

- Image pins and digests: [ENV.md](ENV.md). Advisory pins: [VERSIONS.md](VERSIONS.md).
  Deviations and decisions: [DECISIONS.md](DECISIONS.md) (G-series).
- Every number traces to a stored file under `env/` (testbed evidence) or `results/` (recall results;
  current-release results under `private/`). Observed-but-not-stored is marked "not archived".
- No advisory detail, version or result is invented. Anything not verified at primary source is marked
  **UNVERIFIED**.
- Tests and thresholds are frozen before results: the 6 advisories and their predicted flip points at
  sign-off; the catalogue before any current release is tested.

## Standing approvals

- **Downloads (user, 2026-11-08, G9; extends pilot 08's 2026-10-21 approval):** **< 5 GB each** from
  Docker Hub / GHCR, GitHub source clones of the projects under test, JDK/tooling installers. Each one is
  logged in ENV.md (name, source, size, digest or commit SHA, date).
- **Not approved:** PyPI (new source, ask first); any single download ≥ 5 GB; any other new source.
- **Commits (user, 2026-11-08, G10):** commits of files under `pilots/10-llm-gateway-authz/` are
  pre-approved. Author `ftaakash <gsaakash@outlook.com>`, real dates, no Co-Authored-By line, never
  force-push, nothing under `private/` tracked, no candidate findings in commit messages. Commits outside
  this folder still need asking. **No public mirror**: no GitHub repo is created and nothing is pushed
  until the user decides.
- Downloads happen only in a pull/build step; the runtime testbed network stays internal (no egress).
- Python is not installed and is not installed without asking. Tooling as in pilot 08: bash, curl and jq
  inside driver containers (jq is not on the host).
