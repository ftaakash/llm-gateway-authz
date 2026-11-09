# Independent review — pilot 10 (GatewayAuthz), phase by phase

Reviewer: independent read-only review session (same role as for pilot 08, `pilots/08-dsp-authfuzz/REVIEW-phases.md`).
Scope of each review: tracked files of this folder, git history, and read-only `git show` / `git grep` on the
tag objects of the source clones under `build/src/` (lazy fetch disabled, nothing checked out, nothing run,
nothing downloaded). `private/` is not read beyond its listing. No current-release result exists yet.

Severity: **High** = fix before the step it guards runs; **Medium** = fix before the phase report;
**Low** = wording / hygiene.

---

## Review 1 — Phase 0 (scope) and the G4/G5 freeze (2026-11-08)

Commits reviewed: `0a7e427` (phase 0 scope), `2c4c9d0` (freeze R1–R6). Both authored
`ftaakash <gsaakash@outlook.com>`, no co-author line, nothing under `private/` or `build/` tracked
(`private/` ignored by the repo rule `pilots/**/private/`, `build/` by the folder `.gitignore`; checked).

**Verdict: phase 0 and the freeze are sound and on track.** The scope copies pilot 08's oracle discipline
correctly: fixed-version admission, positive control and precondition on every cell, INVALID ≠ PASS,
"unreachable after freeze = not rediscovered", and the advisory set frozen before any test exists. The
G2 deviation (one-api out of recall) is justified, recorded before any test and user-approved. Five
items should be settled **before phase 1 runs a cell**. Four more are needed before the phase report.

### Source claims re-checked (independent, on tag objects)

| Claim (VERSIONS.md ranking) | Re-check | Result |
|---|---|---|
| R4: `AccessToken` tag `json:"access_token"` at `v1.0.0-rc.6`, `json:"-"` at `rc.7` | `git show <tag>:model/user.go` | confirmed |
| R5: `GetByOnlyTaskId(taskID)` at `v0.11.4-alpha.1`, owner-scoped at `alpha.2`; the two tags differ only by the fix and one unrelated commit | `git show`, `git log alpha.1..alpha.2` | confirmed |
| R3: the `rc.17`→`rc.18` delta is exactly the two named fix commits | `git log rc.17..rc.18` | confirmed |
| R6: `upstream_path_guard.go` absent at `v0.1.168`, present at `v0.1.169`; `AccountTypeUpstream` = "Base URL + API Key"; responses `*subpath` routes | `git ls-tree`, `git show`, `git grep` | confirmed (paths are under `backend/`, see L1) |
| R2: guard string "Only proxy admins can modify user roles" absent at `v1.83.6-nightly` / `v1.83.7-stable`, present at `v1.83.8-nightly`, `v1.83.9-nightly`, `v1.83.10-stable` | `git grep` per tag | confirmed |
| R1: caller-permission / `handle_key_type` handling grows between `v1.83.13-nightly` and `v1.83.14-stable`; 14-stable strictly ahead (0 behind) | `git grep`, `rev-list` | confirmed |

### High — settle before the first recall cell runs

**H1. PASS must be fix-specific (pilot 08 Review 21, Z1), most of all for R1.** Most rung pairs span
more than the fix: R1 spans a whole release cycle, and R4 and R6 span many unrelated commits. Only R3
and R5 isolate the fix. A generic refusal on the fixed rung could therefore come from an unrelated
change, such as a renamed route, a new validation error, or a changed default role. Before the first run, write
down for each advisory the refusal signature that the fix introduces, taken from the fix diff (status
code plus error text or field). For R4, the signature is the field missing from the user record while root
still appears in the list. A refusal that does not match the signature is **INVALID**, not PASS. Mirror
the FAIL side too: FAIL is valid only when the observation shows the advisory's mechanism (for example
a role re-read as `proxy_admin`, or a journal path outside the prefix), not just "request accepted".

**H2. R2 has two sub-cells (`org_admin`, `internal_user`) but no rule for combining them.** The
advisory says the escalation works for `org_admin` "without chaining"; for `internal_user`, other
checks at `v1.83.7-stable` may refuse first. Freeze the rule now. Suggested rule: R2's recall verdict is
the `org_admin` cell, and `internal_user` is reported as supporting evidence only. Otherwise an
`internal_user` PASS on the affected rung could be read either way after the fact.

**H3. R2's FAIL rung is not an ancestor of its PASS rung.** Checked: `v1.83.7-stable` is not an ancestor
of `v1.83.8-nightly`, but `v1.83.6-nightly` is. "Flips exactly at the predicted version" is cleanest on
a linear ladder. Keep the frozen pair (7-stable → 8-nightly; this is not a swap). Also pin and run
`v1.83.6-nightly` as the mainline predecessor, which must FAIL. Record that in DECISIONS now, before
any run. Today ENV.md does not pin `v1.83.6-nightly`.

**H4. The R6 observation depends on how WireMock handles dot segments.** That is not verified. The
FAIL signal is a mock-journal entry outside the `/…/responses/` prefix. If WireMock's HTTP server
rejects ambiguous or dot-segment paths before journaling them, the affected rung would look like PASS
through a mock artefact, and R6 would be lost as "not rediscovered" for a reason unrelated to the
gateway. In phase 1, before the R6 cell, add a mock-only control: the driver sends a dot-segment path
straight to WireMock, and the journal must record it, raw or normalised. If it does not, choose a
journaling setting or observation that does, before any gateway cell runs.

**H5. The state of the docs after the freeze contradicts itself.** A reader cannot tell what is frozen:
- `SCOPE.md` status still says "Static reachability check and freeze of the six advisories pending (G4)".
- `VERSIONS.md` still has "The proposed 6", "needs the user's OK (G2/G3)", and "Alternates … unless the user swaps one in before the freeze".
- The per-advisory column says reachability is "UNVERIFIED"/"expected", while the ranking table says "yes".
- `ENV.md` labels L1/L2 as "candidate".
- `DECISIONS.md` has no row recording the freeze itself: G4 still reads "do not freeze yet".

Add a **G12** row (freeze done, date, commit `2c4c9d0`, user approval) and update the stale lines. In
the ranking table, word "mock-reachable" as **source-reachable (desk judgment; confirmed in phase 1)**,
because the claim stays unverified until a cell runs.

### Medium — before the phase-1 report

**M1. Settlement timing for R3.** new-api settles quota after the call (post-consume). Reading the
balance immediately can show the pre-consume state on both rungs. Wait on a settlement record (the log
entry for the request) before the "balance after" read, never a fixed sleep. Define FAIL as the balance
**strictly increasing**, not just "≤ fails", so that a request that is accepted but not billed cannot
count as a recall flip.

**M2. Precondition wait for R5.** A's task must reach a completed state through the gateway's polling of
the mock before B's request is meaningful. Make "A's task is complete and A can retrieve the content"
the precondition (otherwise INVALID), polled with a bound, not timed.

**M3. KC4 check at the phase boundary.** SCOPE says kill condition 4 is "checked at each phase boundary".
No phase-0 or freeze check is recorded. Log the check: date, the venues and queries used, and the
outcome, with no un-verified claims. Do this before phase 1 starts.

**M4. Driver-image reuse decision.** Decide whether pilot 08's bash+curl+jq driver image is reused, so
that the pull log has no unused pulls. A jq install via `apk` in a build step is a new download source
(the Alpine package mirror). It is not in the G9 list, so ask first or reuse pilot 08's image.

### Low

- **L1.** The Sub2API evidence paths in VERSIONS.md omit the `backend/` prefix (`backend/internal/...`).
- **L2.** The `litellm` and `ai-gateway` clone working trees show staged deletions. Evidence is (and
  should stay) read from tag objects (`git show <tag>:path`), not from the working tree. Say so in ENV.md.
- **L3.** R6 note: "Sub2API needs PostgreSQL and Redis (UNVERIFIED, … not opened today)". Close this in
  phase 1 from the compose file at `v0.1.168`.
- **L4.** The idea-file corrections listed at the end of VERSIONS.md are outside this folder.
  Committing them needs the user's OK (G10 covers only this folder).

### What phase 1 should do, in order

1. Fix H5 (docs and G12), and record the H1 signatures, H2 rule and H3 rung in DECISIONS/VERSIONS **before any pull**.
2. Do M3 (KC4 check) and M4 (driver image).
3. Pull by digest and log every pull. Build an internal network per cell. Store the egress negative probe under `env/`.
4. Run the mock-only control (H4), then the recall cells, lightest first (R4, R2, R1, then R3, R5, R6). Store each observation before its verdict.
5. Recall results on patched advisories may be tracked. Current releases are not touched until recall is ≥ 4 of 6.

---

## Review 2 — Phase 1 recall ladder (2026-11-09)

Commits reviewed: `f4dcf74` (review-1 High items settled), `bf30d84`, `f494f10`, `623e8d5`, `1f83b09`, `95923cd`,
`ce86924` (recall results and summary). All are authored `ftaakash`, with no co-author line and nothing under `private/` tracked.
Recall results concern already-patched public advisories, so they may be tracked (SCOPE). This review
does not restate them and adds no current-release content.

**Verdict: on track, but the KC3 recall claim is NOT CLEARED yet.** One counted advisory (R1) does not meet
its own frozen FAIL signature, and three counted cells store no positive-control observation. Without R1,
three advisories are counted; R5 is unexercised and R6 is not rediscovered, so the threshold would be missed.
Both R1 and R5 must be resolved before the summary can state that recall passes.

### What holds
- The review-1 High items were settled in `f4dcf74`, **before** the first pull or cell: G12–G15, frozen
  signatures, the R2 combining rule, and the L0 rung. The commit order confirms it.
- Every recall row carries the rung, image digest and a commit stamp. Each row's timestamp is after the commit it is stamped with.
- The pull log has digest-match evidence for every row. Each image is under the 5 GB limit.
- R2 flips at the predicted version, with the frozen fix-specific refusal text and a role re-read. The L0 mainline
  predecessor FAILs as H3 required, and `internal_user` is used as supporting evidence only (H2).
- For R4 and R3, the FAIL rung shows the advisory's mechanism and the PASS rung shows the fix's behaviour. R3's FAIL is the
  strict increase that M1 required.
- R6 is recorded as INVALID / not rediscovered and is not counted. That is the correct D4/D6 treatment, and no backup is substituted.
- The H4 mock-journal control is stored and passed before the R6 observation.

### High — before the recall summary may claim "passes"

**P1. R1's FAIL rows do not meet the frozen R1 FAIL signature.** In VERSIONS.md "Oracle signatures", the R1 FAIL
mechanism is a child key that **actually reaches** the admin-only route, with a 2xx on a route the base role is gated
from. The stored FAIL observations show only that the elevated key was **created**. No route call is recorded. Under G13,
a FAIL that does not show the advisory's mechanism is not a valid FAIL. As stored, R1 is **INVALID**, not rediscovered.
To fix it, add the read-only route call with the child key to the R1 cell, re-run the R1 rungs, and store the
observation. Do not re-label the old rows.

**P2. Positive controls are not stored for R1, R2 and R4.** RECALL-SUMMARY says each positive control held, but
`recall.csv` records none for these three cells. SCOPE requires that there be "no verdict without its observation".
Only R3's observation carries its control. Add a control observation to each row (or a sibling control row with the
same stamp), and re-run so the controls are stored. A control that is claimed but not stored is "not archived" and cannot support a verdict.

**P3. R5 is unexercised, and the KC3 outcome depends on it once P1 is applied.** The summary says R5 and R6 "do not
change this outcome". That only holds if R1 stands. Either build the R5 cell (with the M2 bounded precondition) and run
both rungs, or report R5 as not exercised. Do not state a recall result until P1 and R5 are both settled.

**P4. R1's PASS signature must match the path being tested.** The R1 cell exercises the `key_type` path, and its PASS row
shows the direct-field refusal text. The frozen signature names a separate refusal for the `key_type` path: the
post-`handle_key_type` re-check. Confirm from the `v1.83.14-stable` source that the re-check emits this same text and
that the text is absent at `v1.83.13-nightly`. Record the source evidence. If the text does not come from the re-check,
the PASS is INVALID under G13.

### Medium — before the phase-1 report

**M5. Provenance of stamps and runs.** `env/net-isolation.csv` is stamped `f4dcf74-dirty` and has no timestamp,
so it cannot be shown to precede the first cell, and it ran from a dirty tree. `ce86924` ("clean stamps") adds the
CSV in one go. State whether the rows came from one clean batch run at `1f83b09`/`95923cd` or were re-stamped, and keep
the raw batch output under `env/` or `results/`. Re-run the egress probe from a clean commit with a timestamp, before the P1/P2 re-runs.

**M6. Support for the R6 reachability call.** The INVALID reasoning (the passthrough normalises the path; the
`upstream` account type fails before the mock) is plausible, but the row is for **`0.1.169` only**. Store the
`0.1.168` attempt, plus a short source pointer showing that the raw splice sits behind the OAuth passthrough. That
makes "not reachable with mocks" auditable and shows it is not a setup error.

**M7. The KC4 check carries no evidence.** DECISIONS records "none found 2026-11-08" without venues or queries. Log
them (date, sources, query strings) for the phase-0 boundary and again for this phase boundary.

### Low
- **L5.** There is a stray directory `testbed/litellm/config.yaml;C` (a Windows path artefact). Remove it, and confirm the mount used the file.
- **L6.** The source clones moved (the D: relocation in `bf30d84`). Update ENV.md's source-clone log with the new path, so that the
  review-1 source re-checks stay reproducible.
- **L7.** RECALL-SUMMARY quotes the KC3 text with "KILL the method". The frozen Paper-A action for KC3 is
  "drop the gateway half to related work". Quote the frozen wording.

### What to do next, in order
1. P4 (a source read only), then fix the R1 cell (P1) and add stored positive controls (P2).
2. Re-run the egress probe from a clean commit (M5), then re-run R1, R2 and R4 in one clean batch. Append the new rows; never overwrite.
3. Build and run R5 (P3, M2), and store the R6 `0.1.168` evidence (M6).
4. Only then restate the KC3 recall outcome, from stored rows only. Current releases stay untouched until it is ≥ 4 of 6.

---

## Review 3 — Phase 2 gateway invariant catalogue (frozen `7e577e2`) and the final recall claim (2026-11-09)

Commits reviewed: `e17e006` through `7e577e2` (review-2 fixes, R5 cell, final recall rows and summary, G16 mirror,
catalogue freeze). All are authored `ftaakash`, with no co-author line and nothing from `private/` tracked. Nothing has
run against a current release.

**Verdict: NOT CLEARED for Phase 3.** The recall half does not reach 4 of 6 under its own frozen oracle (B1). SCOPE
says the catalogue and the current-release run happen only if recall passes, so Phase 3 cannot start until B1 is
resolved. Separately, the catalogue has a design flaw that would also block Phase 3 (C1).

### B1 (blocker). R5's counted flip does not meet the frozen R5 signature

The frozen R5 row (VERSIONS.md "Oracle signatures", `f4dcf74`, unchanged since) says:
- FAIL = user B's content request returns **200 with A's content**, and the mock journal shows an upstream fetch for B's request.
- INVALID if **A's own-content positive control fails, or A's task is not complete/retrievable** (precondition, polled with a bound, M2).

The stored R5 rows (`results/recall.csv`) show that **A's own request was refused on both rungs because the task was not
complete**. On the affected rung, B's request got the same not-complete refusal, not A's content. No journal fetch for B
is recorded. Under the frozen rule, both rows are therefore **INVALID**, because the precondition was not met. The cell
judged FAIL by a different criterion: "same task-specific response, not a not-found". That criterion was not frozen,
and it was applied after the observation existed. RECALL-SUMMARY also says "A's positive control holds", which the
stored observation contradicts.

The difference in the owner-scoped lookup between the two rungs is real evidence of the fix, but it is not the frozen
signature. With R5 INVALID, the counted flips are **R2, R3 and R4: 3 of 6, below the threshold**.

The way forward is the user's decision (I recommend trying (a) first):
- **(a) Re-run R5 under the unchanged frozen signature.** Complete the task lifecycle through the mock so that A
  retrieves A's content (200) as the precondition, then measure B. This fixes the setup after a precondition-INVALID,
  as the R1 re-run did; it does not change the oracle. Append the new rows and keep the INVALID ones.
- **(b) Accept 3 of 6.** KC3 recall then fires, and the frozen action applies: **drop the gateway half to related
  work; Paper A becomes DSP-only.**
- Changing the R5 signature now, after the result, is not an option under the freeze rules.

**The public mirror already says "recall half PASSES 4/6"** (pushed by replaying `acc6c96` and `a08ef26`). Once B1 is
settled, correct it with a normal follow-up commit that states R5 is INVALID under the frozen signature and gives the
resulting outcome. Never force-push.

### Catalogue questions

**C1 (High). Sanity is measured on the verdict build, so admission and verdict are not independent (pilot 08 INV-6
lesson).** For every invariant, the "sanity configuration (PASS by construction)" is the **current build**. If a current
release violates the invariant, its sanity check fails, and the cell is discarded as INVALID instead of reported as a
FAIL. That hides exactly the result the novelty half looks for. Sanity must run on a build where the invariant holds
**by construction, independent of the target**. For G2–G5 that is the same gateway's recall **fixed** image. For the
other gateways, use a pinned build whose guard is shown to be present from the source. The current-release run is the
verdict only. Amend this before any current-release cell; that is allowed now because no result exists.

**C2 (High). Are config mutations sound?** A mutation is sound when it is a **minimal, documented removal of the
specific guard on the code path the verdict exercises**, in the same gateway, pinned by a diff or fixture sha. A FAIL
then shows that the test detects the missing guard. If the mutation changes anything else (the mock, the driver, a
different route or principal setup), it tests our **fixture**, not the gateway.

For the Go gateways (new-api, Sub2API, one-api), "remove the guard" means **rebuilding the image from patched source**.
That is a code mutation, not configuration. A Go toolchain plus module downloads would be a **new download source**,
which needs the user's OK.

For INV-G1 and INV-G6, whose recall cells were INVALID with mocks, a mutation that makes the path reachable only inside
the fixture does not show that the **target's** path is reachable. The verdict cell must first show reachability on the
current build through its positive control; otherwise the result is "admission not established".

Before Phase 3, write down for each (invariant × gateway): the mutation, its exact diff or flag, how it is built, and its sha.

**C3 (Medium). INV-G7 is not grounded.** It has no CVE behind it, and the invariant is broad ("grant-preserving and
injection-safe"). Its mutation assumes there is a tool or scope filter to disable; if none exists, there is nothing to
mutate, and sanity is not "PASS by construction". Label INV-G7 **exploratory** and report it separately. Do not count it
toward KC3's new-violation half unless, before Phase 3, it names for each gateway a **documented** per-key or per-user
tool/model restriction and the code guard that enforces it.

**C4 (Medium). Per-gateway observables.** For INV-G3, "balance" on LiteLLM and Sub2API is budget/spend, not a quota
balance. For INV-G4 and INV-G5, secret fields and resource ids differ per gateway. Freeze the concrete observable,
route and signature for each (invariant × gateway) before Phase 3. A cell judged against an observable chosen after the
first run is post-hoc.

**C5 (Mostly correct; two small gaps). Targets and one-api.** It is correct to exclude one-api's two known-unpatched
advisories as "not new". Pre-register which cell each one would surface in: the channel-pinning advisory maps to
INV-G5, while the redemption race is outside the frozen set (races are excluded). A one-api hit is then classified by
its mechanism, not by judgement after the fact. Also align the disclosure channel: SCOPE says one-api's channel is the
user's decision, but the catalogue lists GitHub private reporting. One-api has no affected or fixed images, so every
one-api cell depends on C2 mutations.

**C6 (Medium). KC3 firing rule.** "At least one new violation in total across a ≥3-gateway target set" matches SCOPE.
Add SCOPE's completeness clause explicitly: "0 new" (the downgrade) may be stated only when admitted cells cover the
**full** frozen catalogue on ≥3 gateways. Otherwise the result is "incomplete", which neither fires nor passes.

**C7 (Sufficient, with additions). Confidentiality for the public mirror.** The design is right: all Phase-3
observations, verdicts, counts, KC4 frame tags and specialised scripts go to `private/`, and tracked text says only
"phase-3 run complete, results private". Add these:
- **Admission rows** that run on or touch a current-release build also go to `private/`.
- **Per-gateway G7 applicability (NA)** measured on a current release goes to `private/`.
- **Names of mutation fixtures and commit messages** must not hint at which (invariant × gateway) pair behaved how.
- The pre-push check greps the whole replay range for counts, invariant×gateway pairs and verdict words, as in pilot 08.

### Settle before the first current-release cell
1. B1, by the user's choice of (a) or (b), plus the public correction commit.
2. C1: amend sanity to run on target-independent builds.
3. C2 and C4: a table per (invariant × gateway) giving the mutation, observable, route and signature, and the user's OK for any Go build toolchain or module download.
4. C3: label G7 exploratory or ground it. C5: the one-api mapping and disclosure channel. C6: the completeness clause. Record each as a dated amendment in INVARIANTS.md.
5. The user's explicit go for Phase 3.
