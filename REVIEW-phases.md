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
