# Decision log (pilot 10)

Status values: **PROPOSED** = written by Claude, needs the user's yes; **RESOLVED (user)** = decided.

| # | Date | Decision | By | Reason / consequence |
|---|---|---|---|---|
| G1 | 2026-11-08 | **Start pilot 10 (LLM-gateway half of Paper A) at Phase 0**; scope modelled on pilot 08 SCOPE | coordinator (user's D16 sequencing) | D16 lets the gateway half be built after DSP kill condition 2 has a result and with the user's go. KC2 has a result: D20 (2026-11-08, recorded in `pilots/08-dsp-authfuzz/DECISIONS.md`, commit `a4bbb61`) downgrades the DSP half to a tool/workshop contribution. Phase 1 (pulls, testbed) waits for the frozen six (G4). |
| G2 | 2026-11-08 | **RESOLVED (user) — one-api is tested on its current release only (new-violation half); it is not a recall gateway. Deviation from the frozen idea-10 kill test**, which named one-api among the recall gateways ("≥2 per gateway on LiteLLM, new-api, one-api"). | user (coordinator-relayed: "yes send it") | Reason: neither 2026 one-api advisory has a fixed version (CVE-2026-81027: issue #2410 open, no patched version; CVE-2026-11465: fix PR #2399 unmerged), last release v0.6.10 (2025-02-02), last commit 2025-02-21. The admission rule needs a fixed version, so no one-api advisory can flip FAIL→PASS. **Decided before any test exists.** The Paper-A kill condition 3 (D16) is unchanged: 6 pre-selected advisories, ≥4 must flip; ≥3 gateways for the new-violation half. |
| G3 | 2026-11-08 | **RESOLVED (user) — Sub2API is the third gateway for the recall half.** Split across gateways is set at the freeze (G4) by the static reachability ranking. | user (coordinator-relayed) | Sub2API is maintained (last release 2026-11-07), multi-tenant, image on Docker Hub, and has an authorization-class advisory with a clean fix (GHSA-vrxq-qm4h-6hgg, 0.1.168→0.1.169) in idea 10's root-cause class. Its other advisory (password-reset poisoning) is a generic web flaw and is excluded. |
| G4 | 2026-11-08 | **RESOLVED (user) — do not freeze yet: first a static (source-only, nothing run) reachability check** of R3, R5, R6 and the backups (LiteLLM CVE-2026-35029, new-api CVE-2026-64865, Envoy AI Gateway GHSA-w5rr-gc4v-5946) at their affected and fixed tags; rank all candidates by mock reachability and determinism; freeze the 6 most reachable (≥2 per gateway where possible, ≥3 gateways overall). Ranking and freeze recorded in VERSIONS.md before any test runs. Swapping a backup in before the freeze is allowed; after the freeze nothing changes. | user (coordinator-relayed) | After the freeze an advisory found unreachable on its ladder counts as **not rediscovered** (pilot 08 D4/D6). Threshold unchanged: ≥4 of 6 flip FAIL→PASS exactly at the predicted version. |
| G5 | 2026-11-08 | **RESOLVED (user) — predicted flip point = first published release containing every named fix commit; R2's pair is settled by reading the `/user/update` source at the candidate tags before anything runs.** Both pairs (advisory, source) are reported with the source evidence and which one is used. | user (coordinator-relayed) | For R1, R3, R4, R5, R6 advisory and commit ancestry agree. For R2 (CVE-2026-47102) the fix commits are in `v1.83.8-nightly`/`v1.83.9-nightly` but the advisory says <1.83.10 is affected. |
| G6 | 2026-11-08 | **LiteLLM rungs come from GHCR images, not PyPI** | Claude, forced by approvals | Idea 10 named a PyPI ladder; PyPI is not an approved source (D16 e, G7-approvals). GHCR `ghcr.io/berriai/litellm` publishes every needed tag (checked 2026-11-08). |
| G7 | 2026-11-08 | **RESOLVED (user) — mock model provider = WireMock (pinned Docker Hub image `wiremock/wiremock:3.13.1`)** | user (coordinator-relayed) | Declarative stubs (no Python, no custom server) plus a request journal, which is the observation for upstream-facing tests. |
| G8 | 2026-11-08 | **Assertions are derived from advisory text and fix commits only; non-destructive; secrets recorded as booleans** | Claude (SCOPE rule) | Public PoC gists and bounty write-ups referenced by some advisories are not used as test input. Privilege gains are checked with read-only calls; tokens and canaries are never logged. |
| G9 | 2026-11-08 | **RESOLVED (user) — SCOPE.md signed off; pilot 08's standing download approval extends to pilot 10**: < 5 GB each from Docker Hub / GHCR, GitHub source clones of the projects under test, JDK/tooling installers, each logged in ENV.md. PyPI still **not** approved. Ask before any new source or any download ≥ 5 GB. | user (coordinator-relayed) | — |
| G10 | 2026-11-08 | **RESOLVED (user) — commits of `pilots/10-llm-gateway-authz/` are pre-approved** under pilot 08's rules: author `ftaakash <gsaakash@outlook.com>`, real dates, no Co-Authored-By/Claude line, never force-push, nothing under `private/` tracked, no candidate findings in commit messages. **No public mirror**: no repo is created and nothing is pushed until the user decides. | user (coordinator-relayed) | — |
| G11 | 2026-11-08 | **RESOLVED (user) — timebox 3 weeks, ending 2026-11-29.** One one-week extension is allowed only if decided before any result exists. | user (coordinator-relayed) | — |
| G12 | 2026-11-08 | **The six recall advisories R1–R6 are FROZEN** (commit `2c4c9d0`) after the static reachability ranking in VERSIONS.md; no swap. R2's flip pair resolved by source read to `v1.83.7-stable`→`v1.83.8-nightly`. | Claude under G4 (user) | All six source-reachable + deterministic across 3 gateways; backups recorded, not selected. Post-freeze: an advisory unreachable at run time counts as not rediscovered, not substituted. |
| G13 | 2026-11-08 | **Fix-specific oracle signatures frozen (review 1 H1)** — per-advisory FAIL mechanism and PASS refusal signature (status + error text/field, or mock-journal predicate) in VERSIONS.md "Oracle signatures". A non-matching refusal is INVALID, not PASS. | Claude (review 1 H1) | Prevents a vacuous PASS on R1 (rungs span many unrelated commits) and on R4/R6. |
| G14 | 2026-11-08 | **R2 combining rule frozen (review 1 H2)** — the `org_admin` sub-cell is R2's recall verdict; `internal_user` is supporting evidence only. | Claude (review 1 H2) | org_admin has legitimate `/user/update` access, so self-elevation is the pure authorization flaw. |
| G15 | 2026-11-08 | **R2 mainline predecessor pinned (review 1 H3)** — `v1.83.7-stable` is not a git ancestor of `v1.83.8-nightly`; rung **L0 `v1.83.6-nightly`** (digest in ENV; must FAIL) is pinned and run as a control so the flip is not read across a branch boundary alone. | Claude (review 1 H3) | — |

## Carried into Phase 1 (review 1 items; settle before the phase-1 report)

- **H4 — R6 mock control first.** Before the R6 cell counts, verify WireMock journals a dot-segment path
  sent straight from the driver (not normalized/rejected pre-journal). If the mock drops it, R6 would
  wrongly PASS on the affected rung. Record the control result in `env/`.
- **M1 — R3 settlement timing.** Read "balance after" only once the settlement record exists (poll with a
  bound, never a fixed sleep). FAIL = balance strictly increased.
- **M2 — R5 precondition.** "A's task complete and A retrieves it" is polled with a bound, not a sleep.
- **M3 — KC4 novelty check** logged at each phase boundary and before the report (a ≥3-gateway
  authz/metering invariant paper appearing → re-run Gate B). Phase-0 boundary check: none found 2026-11-08.
- **M4 — driver image.** Reuse pilot 08's driver image (bash+curl+jq). Installing jq via apk inside a new
  image would be a new download source → ask the user first; do not add it unasked.
- Low items L1–L4: see REVIEW-phases.md.
- Phase-boundary review requests go to the review session **through the coordinator** (as in pilot 08).
| G16 | 2026-11-09 | **RESOLVED (user) — public mirror for pilot 10 = `https://github.com/ftaakash/llm-gateway-authz.git`** (user created it, PUBLIC, initially empty). Supersedes G10's "no mirror". | user (coordinator-relayed) | Push rules (user): every commit authored+committed `ftaakash <gsaakash@outlook.com>`, pushed via the user's own GitHub creds; **no Claude contributor, no Co-Authored-By, no bot**; **never force-push**, normal pushes only. Mechanics (copy pilot 08): local mirror clone outside the Masters repo at `build/publish/llm-gateway-authz` (gitignored); replay each pilot-10 commit (incl. the review session's REVIEW-phases.md commits) with `git format-patch --relative=pilots/10-llm-gateway-authz <last>..HEAD` + `git am --committer-date-is-author-date`, stripping any Claude/Co-Authored-By trailer; marker file tracks the last replayed commit; push per phase by hand (no auto-push). **PUBLIC-repo content rules:** nothing from `private/`, no candidate/undisclosed finding, no current-release new-violation result or any mention of one, no secrets/keys from `testbed/`; recall results on already-patched public advisories (pass/fail + evidence) are fine; no exploit payloads. **Pre-push:** review the whole range (`git log -p <last>..HEAD`), send the coordinator the local range, and wait for clearance before each push. First push includes an initial README (what it is, the oracle, the recall ladder, scope/ethics, "Part of Paper A, half 2", link to https://github.com/ftaakash/authz-ladder). |
| G17 | 2026-11-10 | **RESOLVED (user) — R5 setup fix + single re-run under the UNCHANGED frozen signature** (after review 3 B1). User decision, quoted: "re-run R5 after fixing the setup". | user (coordinator-relayed) | See the detail block below. The frozen R5 signature in VERSIONS.md (assertion, observable, positive control, PASS/FAIL/INVALID rule) and the verdict block of `scripts/24_newapi_r5.sh` are **unchanged**; only the mock fixtures and an M2 bounded precondition wait are added. Re-run once, on both rungs, on one clean commit; the first (INVALID) run is kept and the re-run rows are appended flagged, citing this entry; the result counts whichever way it falls. No push, no mirror/README change, no Phase 3. |

### G17 detail — R5 setup fix (review 3 B1)

**What was wrong.** In the first R5 run, user A's own content request (`GET /v1/videos/{A_task}/content`,
the frozen **positive control**) was refused on **both** rungs with HTTP 400 "Task is not completed yet,
current status: NOT_START". By the frozen R5 rule a cell whose positive control fails is **INVALID**, so the
recorded FAIL(alpha.1)/PASS(alpha.2) were not admissible and R5 is not-rediscovered. (Recall therefore stands
at 3/6 on the first run; the re-run may or may not restore it.)

**Root cause (from pinned source, nothing run to find it).** new-api's Sora task lifecycle: submit
`POST /v1/videos` creates a task in state `NOT_START`; a background `TaskPollingLoop` (every 15 s,
`service/task_polling.go:91`) calls the sora adaptor's `FetchTask` → `GET {base}/v1/videos/{id}`
(`relay/channel/task/sora/adaptor.go`), and `ParseTaskResult` maps upstream `"completed"` → `TaskStatusSuccess`;
only then does `VideoProxy` (`controller/video_proxy.go:49`) serve `GET /v1/videos/{id}/content`
(`{base}/v1/videos/{upstreamId}/content`, type 55 OpenAI/Sora branch). The WireMock mock **only stubbed the
submit** (`POST /(v1/)?videos`); the status poll and content fetch hit the catch-all (empty `status`), so the
poller never marked the task `SUCCESS`, and the cell fetched content immediately with **no wait**. A's task
stayed `NOT_START` → A refused on both rungs.

**What changes (setup/mock only).** In `scripts/24_newapi_r5.sh`: (a) add the two upstream WireMock stubs the
sora adaptor actually calls — `GET /(v1/)?videos/[^/]+` → `{"status":"completed"}` (status poll → SUCCESS) and
`GET /(v1/)?videos/[^/]+/content` → HTTP 200 bytes (content priority 1 beats status 3); (b) add an **M2 bounded
precondition wait** that polls `/api/task/` until A's task is `SUCCESS` before any content fetch (a bounded
poll, never a fixed sleep). Nothing else.

**Why it does not touch the oracle.** The frozen R5 signature in VERSIONS.md is unchanged, and the cell's
verdict block (the `notfound()` rule, the `obs` observable, and the `INVALID`/`PASS`/`FAIL` branches) is
byte-identical. The fix only makes A's **legitimate** task complete through the mock so the positive control
can hold; it does not weaken or alter the check, change what B does, or change how B's result is judged. At
alpha.1 (vulnerable `GetByOnlyTaskId`) B still reaches A's task; at alpha.2 (owner-scoped `GetByTaskId`) B
still gets "Task not found" — the oracle decides the verdict exactly as frozen.

| G18 | 2026-11-10 | **RESOLVED (user) — R5-J: align `scripts/24_newapi_r5.sh` to the journal half ALREADY in the frozen R5 signature + one more clean re-run** (after review 4). User decision, quoted: "yes go ahead with the log check and re-run". | user (coordinator-relayed) | See the detail block below. This adds the mock-journal **observation** and aligns the verdict branches to the **existing** frozen R5 text (VERSIONS.md line 28); **VERSIONS.md is untouched**. The setup from `3aea1a6` (the two stubs + the M2 wait) is unchanged, and the precondition / A positive-control INVALID paths are unchanged. One more re-run, once on both rungs, one clean commit, egress probe first; counts whichever way it falls, no iteration. Append-only (L8); run tag kept in the rung label because adding a CSV column would break the 9-field schema (L9, noted). No push; then review 5. |

### G18 detail — R5-J journal-half alignment (review 4)

**What review 4 found.** The frozen R5 signature (VERSIONS.md line 28) decides the verdict by **two** halves:
FAIL = B's `GET /v1/videos/{A_task}/content` returns A's content **and** the mock journal shows an upstream
fetch issued for **B's** request; PASS = B refused/404 **and** no journal fetch for B. The cell implemented only
the **content** half (B's response body/status) and never read the journal, so its rows did not store the
journal half and R5 was **not yet counted**.

**What changes (observation + verdict alignment only).** In `scripts/24_newapi_r5.sh`: (a) snapshot the WireMock
journal count of upstream content requests (`POST /__admin/requests/count`,
`GET /(v1/)?videos/[^/]+/content`) **just before and just after** B's content request; the delta is the "upstream
fetch issued for B's request". (b) Decide the verdict by **both** halves exactly as the frozen text:
`FAIL` = B content reached (not not-found) **and** delta ≥ 1; `PASS` = B refused/404 **and** delta = 0;
**any disagreement** between the content result and the journal = `INVALID`. The `notfound()` rule, the
precondition (`ATASK` empty) INVALID path, and the A positive-control INVALID path are **unchanged**.

**Why this is not a signature change.** The journal clause was **already** in the frozen VERSIONS.md R5
signature; this only makes the script implement it. VERSIONS.md is not edited. The setup from `3aea1a6` (the two
Sora stubs and the M2 bounded wait) is byte-identical. The change only **strengthens** the oracle (it adds an
INVALID-on-disagreement path); it cannot manufacture a flip.

**Discipline.** One re-run, once on both rungs, from one clean commit, egress probe first; the result counts
whichever way it falls; the setup is not iterated after the verdict. Prior rows are **kept unchanged**
(append-only, L8); the new rows are appended, flagged in the rung label (`...-rerunG18J`) since adding a run
column would break the CSV's 9-field schema (L9, noted). The G17 re-run rows (content-half only) are superseded
by the G18J rows (full signature) as the admissible R5 verdict; they are left in place, not relabelled.
