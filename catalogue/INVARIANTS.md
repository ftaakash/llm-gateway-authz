# Gateway invariant catalogue — DESIGN FREEZE (kill condition 3, new-violation half)

**Frozen:** 2026-11-09. **Status:** design only — **no test has run against any current release.** Nothing
in this file is a result.

This file defines the authorization/metering invariants the novelty half of kill condition 3 checks on the
**current releases** of the gateways, and the oracle rules for each. It is derived **only** from (a) the six
**already-patched, publicly disclosed** 2026 advisories used as the recall oracle (R1–R6, [../VERSIONS.md](../VERSIONS.md)),
(b) the cross-gateway root-cause class in [idea 10](../../../ideas/10-llm-gateway-authz/idea.md) (delta 3: "a
caller-supplied routing or scope identifier treated as a grant"), and (c) each gateway's own documented
authorization model. It contains **no results** and encodes **no undisclosed finding** — so it is tracked and
(after coordinator clearance) pushed to the public mirror, like pilot 08's `kc2/INVARIANTS.md`.

> **Confidentiality (SCOPE.md; pilot 08 Review 15 U1).** This catalogue is the *specification* of what should
> hold. Anything produced by *running* it against a current release — scripts specialised to a discovered
> violation, observations, verdict rows, logs, notes, **and any count** — stays under `private/` (gitignored).
> **Tracked files and commit messages carry NO phase-3 number at all** — not per invariant, not per target, not
> even a total; any count can locate an undisclosed finding. Tracked text may say only "phase-3 run complete,
> results private". Disclosure is the **user's** call, to each project's **private** security channel
> (GitHub private vulnerability reporting for LiteLLM, new-api, one-api; the project's channel for Sub2API),
> under a 90-day default embargo; never auto-sent. The public mirror never carries a current-release
> new-violation result or any mention of one — only recall results on already-patched public advisories.

## Freeze rules

- Each invariant below is frozen as written. A change (new invariant, altered assertion, altered oracle)
  requires a **dated amendment** at the bottom of this file with a one-line reason, and is **reported
  separately** from the frozen set. No invariant is added or altered after a current-release result exists
  (post-hoc invariants are disallowed).
- An invariant's result against a current release **counts** only if the invariant was first **validated as a
  sound test** — the **admission rule** (pilot 08 A1): it must return **PASS on its sanity configuration**
  (where the invariant holds by construction) **and FAIL on its mutation configuration** (a deliberately
  broken setup where the invariant is violated by construction). A test that cannot be made to do both is
  **INVALID** and its current-release result is **discarded** (never a vacuous PASS).
- The **mutation configuration** is a labelled, test-only break of the sanity setup that encodes the rule's
  negation. It is **never** used for a current-release verdict and reveals no finding (it is the generic "what a
  violation looks like"). Where the recall ladder already produced a **faithful construct-FAIL** on the
  advisory's affected image (R2→INV-G2, R3→INV-G3, R4→INV-G4, R5→INV-G5), that affected image **is** the
  mutation (admission is grounded in a real run, exactly as pilot 08 used its KC1 affected builds for INV-1/2).
  Where the recall cell was **INVALID with mocks** (R1→INV-G1, R6→INV-G6), the affected image is **not** a usable
  mutation, so admission rests on a **labelled test-only configuration mutation** instead, called out per
  invariant below. INV-G7 has no recall advisory and uses a labelled config mutation.
- A current-release result is admitted **per (invariant × gateway)**: the mutation/sanity admission is checked
  on a build of **that** gateway (its recall affected/fixed image, or a labelled config build of it), not
  inferred from another gateway.

## Oracle vocabulary (same discipline as the recall half, G13)

- **Observation** (HTTP code, body predicate, mock-journal predicate, state) is recorded separately from the
  **verdict** (PASS / FAIL / INVALID). No verdict without its observation.
- **Fix-specific / rule-specific signature.** A **FAIL** must show the invariant's **own mechanism** (the
  advisory mechanism, or the rule's negation); a **PASS** refusal must match the **signature taken from the
  fixing commit** (status + error text/field) or the **mock-journal predicate**. A refusal that does not match
  the signature is **INVALID**, not PASS.
- **Positive control**: every cell must show the *legitimate* path still works (so a FAIL means "the
  illegitimate path **also** worked", not "nothing worked"). A cell whose positive control fails is **INVALID**.
- **Precondition check**: the setup the assertion needs (a second tenant exists, a token was minted, a balance
  is known, a channel is reachable) is verified *before* the assertion; if unmet the cell is **INVALID**.
- **Secrets as booleans.** Tokens, keys and canaries are recorded only as present/absent; values are never
  logged. These are detection predicates, not payloads.
- **PASS** = invariant held (illegitimate path refused with the signature, legitimate path works).
  **FAIL** = invariant violated (illegitimate path succeeded) **and** positive control + preconditions held.
  **INVALID** = preconditions or positive control not met, signature not matched, or path not reachable with
  mocks → discard, never a vacuous PASS.
- Every row carries the image digest and a clean commit (recall rows only; current-release rows live in
  `private/`).
- **No weaponization.** Assertions return pass/fail; no exploit payload is distributed. Privilege/ownership
  gains are probed with read-only calls where possible; a balance/metering check reads balance before/after a
  single benign billed call.

---

## INV-G1 — Derived-credential scope non-escalation

- **Source.** Recall R1 (LiteLLM CVE-2026-47101, GHSA-qrc4-49gv-mv9m): an `internal_user`-created key could
  name routes outside its creator's grant (`allowed_routes` / `key_type`). Delta-3 class: a caller-supplied
  **scope field** treated as a grant.
- **Invariant.** A credential (key/token) that a principal creates has an effective grant **⊆** its creator's
  grant. A child credential cannot reach a route, model, team or scope the creator's own credential cannot.
- **Applies to (current releases).** LiteLLM (key `allowed_routes`/`key_type`/`models`/`teams`), new-api (token
  scope/group/model limit), one-api (token + group), Sub2API (tenant api-key + group). Minimum 3 gateways.
- **Preconditions.** A non-admin principal P with a known, bounded grant; an admin-only or out-of-grant target
  route/model R that P's own credential is refused on (verified first).
- **Assertion.** A child credential P mints that names R in its scope **does not** reach R (the mint is refused,
  or the child credential is refused on R).
- **Positive control.** P can mint a child credential with an **in-grant** scope and use it on a permitted
  route/model (so a FAIL is "out-of-grant also worked", not "minting is broken").
- **Sanity configuration (PASS by construction).** Current build, child scope kept **within** P's grant: child
  mints and works on the permitted route, and is refused on R → consistent → PASS.
- **Mutation configuration (must FAIL — admission).** Recall R1 was **INVALID with mocks** (the minted bucket
  reached no admin route on the ladder; [../env/r1-reach-investigation.md](../env/r1-reach-investigation.md)),
  so the affected image is **not** the mutation. Admission uses a **labelled test-only configuration** of the
  same gateway that neutralises the child-scope caller-permission check (the guard added by the fixing commit),
  so a child credential naming R reaches R by construction → FAIL. The labelled config is never on a
  current-release (verdict) build; its identity (image digest + config flag/fixture sha) is recorded in the
  mutation row.
- **Oracle.** **PASS** child refused on R with the fix signature (403, caller-permission error) **and** in-grant
  child works. **FAIL** child reaches R (2xx) that P's own credential cannot. **INVALID** P's own credential is
  not actually refused on R (precondition), in-grant positive control fails, or the path is not reachable.

## INV-G2 — No self-elevation of authorization attributes

- **Source.** Recall R2 (LiteLLM CVE-2026-47102, GHSA-wpfp-gwwc-vwq6): `/user/update` let a principal set its
  own `user_role` to `proxy_admin`. **Grounded mutation** (recall flipped FAIL 1.83.7 → PASS 1.83.8).
- **Invariant.** A principal cannot write its **own** authorization attributes (role/admin flag/privileged
  group) through a self-service update path; only a higher-privileged principal may change them.
- **Applies to (current releases).** LiteLLM (`/user/update` `user_role`), new-api (`/api/user/self` role/group
  fields), one-api (user self-update role), Sub2API (user role). Minimum 3 gateways.
- **Preconditions.** A principal P holding a legitimate self-update right over a **permitted** field (e.g. its
  email/display name), and a distinct **privileged** attribute A (role) P must not be able to set on itself.
- **Assertion.** `POST <self-update>` by P setting A to a privileged value, then a **re-read** of P's record,
  shows A **unchanged**.
- **Positive control.** P's self-update of a **permitted** field succeeds (the route is reachable and P is
  authenticated).
- **Sanity configuration (PASS by construction).** Current build, P updates only a permitted field → succeeds;
  P's attempt to set A is refused and the re-read is unchanged → PASS.
- **Mutation configuration (must FAIL — admission).** The gateway's recall **affected** image (LiteLLM
  `v1.83.7-stable`) where the role guard is absent: P sets its own role and the re-read shows the elevated role
  → FAIL by construction. For a gateway with no such affected image, a labelled test-only config that removes
  the field-level role guard.
- **Oracle.** **PASS** elevation refused with the fix signature (403 "Only proxy admins can modify user roles."
  for LiteLLM; the equivalent field-guard refusal elsewhere) **and** re-read attribute unchanged **and**
  permitted-field positive control works. **FAIL** re-read shows the elevated attribute. **INVALID** attribute
  not re-read from an authoritative read endpoint, or the permitted-field positive control fails.

## INV-G3 — Metering monotonicity (a billed request never increases the caller's balance)

- **Source.** Recall R3 (new-api CVE-2026-71479, GHSA-8r8v-xf7q-rcpr): an out-of-range quantity field (image
  `n`) overflowed the quota into a self-credit. **Grounded mutation** (recall flipped FAIL rc.17 → PASS rc.18).
  Exploited in the wild 2026-07-06.
- **Invariant.** A caller-controlled quantity/size field in a billed request is bounded and overflow-safe: after
  a billed call settles, the caller's balance is **≤** its balance before (it never strictly increases), and the
  charge is non-negative.
- **Applies to (current releases).** new-api (relay quantity fields), one-api (relay quantity/price path),
  LiteLLM (budget/spend accounting), Sub2API (quota accounting). Minimum 3 gateways (where a mockable billed
  path exists).
- **Preconditions (M1).** A known starting balance, a channel whose billed path the **mock** upstream can
  satisfy, and a settlement record read **after** it exists (polled with a bound, never a fixed sleep).
- **Assertion.** One billed call carrying an **out-of-range** quantity field; the caller balance after
  settlement is **≤** before.
- **Positive control.** A normal call (e.g. n=1) **is** billed — balance drops by the expected amount — so the
  billed path is live and the FAIL is "the crafted call credited", not "nothing billed".
- **Sanity configuration (PASS by construction).** Current build, only in-range quantities: each call bills and
  the balance monotonically decreases → PASS.
- **Mutation configuration (must FAIL — admission).** The gateway's recall **affected** image (new-api
  `v1.0.0-rc.17`): the crafted quantity increases the balance → FAIL by construction. For a gateway without that
  image, a labelled test-only config removing the saturating/bounds conversion added by the fix.
- **Oracle.** **PASS** crafted call refused **or** balance-after ≤ balance-before, with the fix signature
  (bounded/5xx reject) **and** the n=1 control billed. **FAIL** balance strictly increased after settlement.
  **INVALID** no settlement record yet (must wait, not sleep), the n=1 control did not bill, or no mockable
  billed path.

## INV-G4 — Role boundary on credential exposure

- **Source.** Recall R4 (new-api CVE-2026-64859, GHSA-6x2c-phff-wx57): a non-root **admin** user-list returned
  the **root** record's `access_token`. **Grounded mutation** (recall flipped FAIL rc.6 → PASS rc.7).
- **Invariant.** A principal never obtains, through a listing/read endpoint, a **higher-privileged** principal's
  secret (access token, API key, password hash, provider key). A lower role reads no higher role's credential.
- **Applies to (current releases).** new-api (admin `/api/user/`), one-api (user/channel list), LiteLLM (key/user
  info endpoints), Sub2API (admin user/account list). Minimum 3 gateways.
- **Preconditions.** Two principals at different privilege: a lower one L (admin, non-root) and a higher one H
  (root/owner) whose secret field is actually **set** (verified first); L's listing returns H's record (so
  absence is not "nothing returned").
- **Assertion.** L's listing/read of H's record carries **no non-empty** secret field (boolean only).
- **Positive control.** L's listing returns H's record at all (the record is in scope) and H's secret is set
  (precondition) — so a PASS is "present but redacted", not "H absent".
- **Sanity configuration (PASS by construction).** Current build: L lists users, H's record present, secret
  field absent/empty → PASS.
- **Mutation configuration (must FAIL — admission).** The gateway's recall **affected** image (new-api
  `v1.0.0-rc.6`): L's list exposes H's non-empty `access_token` → FAIL by construction. For a gateway without
  that image, a labelled test-only config that restores the pre-fix serialization (drops the `json:"-"`
  redaction) on the read path.
- **Oracle.** **PASS** H's record present **and** its secret field absent/empty. **FAIL** the secret field is
  non-empty in L's view. **INVALID** H not in L's returned list, or H's secret not set (precondition).

## INV-G5 — Resource ownership on caller-supplied identifiers

- **Source.** Recall R5 (new-api CVE-2026-30886, GHSA-f35r-v9x5-r8mc): `VideoProxy` fetched a task by `task_id`
  only, so any tenant read another tenant's task. **Grounded mutation** (recall flipped FAIL alpha.1 → PASS
  alpha.2). Delta-3 class: a caller-supplied **resource id** selecting a resource outside the caller's grant.
- **Invariant.** A caller-supplied resource identifier (task id, channel id, log id, key id, request/batch id)
  selects **only** resources owned by (or shared with) the caller. A well-formed id belonging to another tenant
  is refused, not served.
- **Applies to (current releases).** new-api (video `task_id`, channels, logs, tokens), one-api (`channelid`,
  logs), LiteLLM (spend/key lookup by id), Sub2API (per-tenant resources). Minimum 3 gateways.
- **Preconditions.** Two tenants A and B with their own credentials; A owns a resource with id X (verified: A can
  read X). B is authenticated and does **not** own X.
- **Assertion.** B's read of X (by A's id) is refused/404; where an upstream fetch would occur, the mock journal
  shows **no** fetch issued for B.
- **Positive control.** A reads A's own X (not-found/owner-scoping is a real check, not a blanket failure).
- **Sanity configuration (PASS by construction).** Current build: A reads X; B reads B's own resource; B's read
  of X is refused → PASS.
- **Mutation configuration (must FAIL — admission).** The gateway's recall **affected** image (new-api
  `v0.11.4-alpha.1`): B reaches A's task (same task-specific response as A) → FAIL by construction. For a gateway
  without that image, a labelled test-only config swapping the owner-scoped lookup for an id-only lookup.
- **Oracle.** **PASS** B refused/404 with the owner-scoped signature ("Task not found" / owner-scoped retrieval)
  **and** no journal fetch for B **and** A's own-resource control works. **FAIL** B receives A's resource (same
  task-specific response, not a not-found). **INVALID** A's own-resource control fails, or X not retrievable
  (precondition).

## INV-G6 — Upstream routing / path confinement

- **Source.** Recall R6 (Sub2API CVE-2026-73079, GHSA-vrxq-qm4h-6hgg): a caller-supplied subpath was spliced
  into the operator's upstream URL, so a tenant request reached a different upstream path with the **operator's**
  credentials. Delta-3 class: a caller-supplied **routing field** widening the upstream resource.
- **Invariant.** A caller-supplied routing field (subpath, path segment, base-URL override, deployment/model
  selector) never widens the **upstream** resource reached with the **operator's** credentials beyond the
  operator-configured prefix/allow-list. Dot segments and traversal in a caller subpath do not escape the prefix.
- **Applies to (current releases).** Sub2API (`responses/*subpath` + aliases), LiteLLM (pass-through routes /
  provider base-URL handling), new-api (channel routing / custom base URL). Minimum 3 gateways (where a
  pass-through/subpath feature exists).
- **Preconditions.** An operator-configured upstream account/channel pointing at the **mock**, with a fixed dummy
  operator key; a caller (tenant) credential. The mock must journal a raw dot-segment path sent straight from the
  driver (**H4** control, [../env/r6-mockjournal-control.csv](../env/r6-mockjournal-control.csv)) before the cell
  counts, or the cell is INVALID.
- **Assertion.** A caller request whose routing field contains a dot-segment/traversal is refused, **or** the
  mock journal shows **no** upstream request whose resolved path escapes the operator prefix.
- **Positive control.** A **legitimate** subpath reaches the mock **under** the prefix, carrying the dummy
  operator key (the pass-through path is live).
- **Sanity configuration (PASS by construction).** Current build, only legitimate subpaths: every journaled
  upstream path stays under the prefix → PASS.
- **Mutation configuration (must FAIL — admission).** Recall R6 was **INVALID with mocks** (the raw-splice path
  was not reproducible: the `apikey` passthrough normalises `responses`→`chat/completions`, and the `upstream`
  account type 502s pre-mock without an OAuth login; [../results/RECALL-SUMMARY.md](../results/RECALL-SUMMARY.md)),
  so the affected image is **not** the mutation. Admission uses a **labelled test-only configuration** of the
  same gateway that removes the upstream path-guard (the fix's `upstream_path_guard` or equivalent), so a
  dot-segment subpath escapes the prefix in the journal by construction → FAIL. Recorded with the config's
  image digest + fixture sha; never on a verdict build. **If no gateway admits INV-G6 with reachable mocks, it
  is recorded admission-not-established and produces no current-release verdict** (never a vacuous PASS).
- **Oracle.** **PASS** request refused with the guard signature **or** journal path stays under the prefix
  **and** the legitimate-subpath control works. **FAIL** the journal records an upstream path escaping the
  prefix carrying the operator key. **INVALID** the legitimate-subpath control fails, or the mock did not
  journal the raw dot-segment path (H4 control must pass first).

## INV-G7 — Tool-call translation integrity *(EXPLORATORY — reported separately, not counted toward KC3 unless grounded; see amendment A3)*

- **Source.** Residual from the killed C2 ParserDiff kill test (kept as "one invariant family inside C1"): a
  gateway that **translates** tool-call requests/responses between API dialects (OpenAI ↔ Anthropic ↔ Gemini,
  streaming vs non-streaming) must not let a caller **inject or widen** a tool call, or route a tool result
  outside the caller's grant, through that translation. No single CVE backs this family.
- **Invariant.** The gateway's tool-call translation is **grant-preserving and injection-safe**: a translated
  tool call carries no caller-supplied field that selects a tool, function, model or route the caller's own
  grant forbids; an echoed/assistant-supplied string is not re-parsed into a privileged tool call.
- **Applies to (current releases).** LiteLLM (multi-dialect tool-call translation), new-api (format relay),
  one-api / Sub2API (where tool-call relay exists). **Applicability measured** — NA where a gateway performs no
  cross-dialect tool-call translation.
- **Preconditions.** A mock upstream that echoes a tool-call structure the gateway translates; a caller whose
  grant forbids a specific tool/model T; the translation path is reachable with the mock.
- **Assertion.** A caller request (or a crafted echoed response) that would, after translation, invoke T or
  widen the tool scope is refused or translated without the forbidden selector; T is not invoked.
- **Positive control.** A legitimate in-grant tool call translates and reaches the mock as expected (the
  translation path is live).
- **Sanity configuration (PASS by construction).** Current build, only in-grant tool calls: each translates
  correctly and the out-of-grant selector is dropped/refused → PASS.
- **Mutation configuration (must FAIL — admission).** A **labelled test-only configuration/fixture** that
  disables the gateway's tool/scope filter in the translation path, so the forbidden selector survives
  translation and T is invoked → FAIL by construction. Never on a verdict build.
- **Oracle.** **PASS** forbidden selector dropped/refused **and** in-grant control works. **FAIL** T invoked
  (mock journal shows the forbidden tool/model) via translation. **INVALID** no cross-dialect translation on the
  target (record NA + reason), the translation path not reachable with mocks, or the in-grant control fails.

---

## Oracle signatures (rule-specific; frozen 2026-11-09)

A verdict is decided by a rule-specific signature, not by "some check is missing". A **FAIL** must show the
invariant's own mechanism; a **PASS** refusal must match the signature below; a non-matching refusal is
**INVALID**.

| Invariant | FAIL (mechanism shown) | PASS signature | INVALID if |
|---|---|---|---|
| INV-G1 | child credential reaches an out-of-grant route/model (2xx the creator cannot) | mint or route call refused with the caller-permission/scope-check signature | creator not actually refused on R, or in-grant child control fails |
| INV-G2 | re-read of the self-updated record shows the elevated authorization attribute | field-guard refusal (e.g. 403 "Only proxy admins can modify user roles.") + attribute unchanged on re-read | attribute not re-read authoritatively, or permitted-field control fails |
| INV-G3 | caller balance **strictly increased** after a billed call with an out-of-range quantity (read after settlement, M1) | request refused **or** balance-after ≤ balance-before | no settlement record yet, or n=1 control did not bill |
| INV-G4 | lower role's listing exposes a higher role's **non-empty** secret field (boolean) | higher record present **and** secret field absent/empty (redacted) | higher record not in the list, or its secret not set |
| INV-G5 | tenant B receives tenant A's resource by A's id (same resource-specific response) **and** (if upstream) a journal fetch for B | B refused/404 with the owner-scoped signature **and** no journal fetch for B | A's own-resource control fails, or A's resource not retrievable |
| INV-G6 | mock journal records an upstream path **escaping** the operator prefix, carrying the operator key | request refused with the path-guard signature **or** journal path stays under the prefix | legitimate-subpath control fails, or the raw dot-segment path not journaled (H4) |
| INV-G7 | forbidden tool/model invoked through translation (journal shows it) | forbidden selector dropped/refused in translation | no cross-dialect translation on target (NA), path unreachable, or in-grant control fails |

## Mapping to the recall half (R1–R6)

| Invariant | Recall advisory | Recall outcome ([../results/recall.csv](../results/recall.csv)) | Mutation basis for admission |
|---|---|---|---|
| INV-G1 scope non-escalation | R1 CVE-2026-47101 (LiteLLM) | **INVALID** (no admin-route reach with mocks) | labelled test-only config (not the affected image) |
| INV-G2 no self-elevation | R2 CVE-2026-47102 (LiteLLM) | FAIL 1.83.7 → PASS 1.83.8 | **affected image** (grounded) |
| INV-G3 metering monotonicity | R3 CVE-2026-71479 (new-api) | FAIL rc.17 → PASS rc.18 | **affected image** (grounded) |
| INV-G4 role boundary | R4 CVE-2026-64859 (new-api) | FAIL rc.6 → PASS rc.7 | **affected image** (grounded) |
| INV-G5 ownership | R5 CVE-2026-30886 (new-api) | FAIL alpha.1 → PASS alpha.2 | **affected image** (grounded) |
| INV-G6 routing confinement | R6 CVE-2026-73079 (Sub2API) | **INVALID** (raw-splice not reproducible with mocks) | labelled test-only config (not the affected image) |
| INV-G7 tool-call translation | *(none — killed C2 residual)* | n/a | labelled test-only config |

Delta-3 root-cause class (idea 10): INV-G1, INV-G5, INV-G6 are "a caller-supplied identifier/field selects or
widens a resource outside the caller's grant"; INV-G2, INV-G4 are role-boundary checks; INV-G3 is metering;
INV-G7 is translation integrity. The contribution is the **invariant + recall method + cross-gateway
root-cause class**, not a bug list (idea-10 failure mode to avoid; KC4 frame check below).

## Current-release targets (≥3 gateways; one-api current-only per G2/G3)

Pinned 2026-11-08 ([../VERSIONS.md](../VERSIONS.md) "Current releases"); digests in [../ENV.md](../ENV.md).
**Nothing is pulled or run against these until Phase 3** (after the review of this catalogue **and** the user's
go). Images are pinned by digest at pull time; every current-release row lands in `private/` only.

| Gateway | Current release | Image | Role |
|---|---|---|---|
| LiteLLM | `v1.108.2` (2026-11-06) | `ghcr.io/berriai/litellm:v1.108.2` | recall + novelty |
| new-api | `v1.0.0-rc.48` (2026-11-04) | `calciumion/new-api:v1.0.0-rc.48` | recall + novelty |
| Sub2API | `v0.2.20` (2026-11-07) | `weishaw/sub2api:0.2.20` | recall + novelty |
| one-api | `v0.6.10` (2025-02-02; unmaintained) | `justsong/one-api:v0.6.10` | **novelty only** (no fixed advisory exists, G2) |

**one-api known-unpatched advisories are NOT new violations.** If the suite flags **CVE-2026-81027 /
GHSA-877p-7prq-ffj6** (channel pinning via `channelid`; one-api issue #2410, open, unpatched) or
**CVE-2026-11465 / GHSA-7v3v-cp44-vc8m** (redemption race; fix PR #2399 open, unmerged), those are **public,
already-disclosed** flaws — recorded as *known-public (not a new finding)*, never counted as a new violation and
never disclosed by us. Only a violation with **no** public advisory is a candidate new finding (→ `private/`).

## How kill condition 3's new-violation half fires

> KC3 (SCOPE.md / idea 10 kill condition 2): "**0 new** invariant violations on current releases of **≥3**
> gateways → downgrade the gateway half to a tool/workshop paper."

- The novelty half **passes** (no downgrade) iff the admitted suite finds **≥1 new** (no public advisory)
  invariant violation on the current release of **≥3** gateways **in aggregate** — i.e. at least one new
  violation total, across a target set spanning ≥3 gateways. It **fires** (downgrade) iff the admitted suite
  finds **0** new violations across the ≥3-gateway target set — **but** (completeness clause, **amendment A6**)
  "0 new" may be declared only when the admitted cells cover the **full frozen catalogue on ≥3 gateways**;
  otherwise the result is **INCOMPLETE** (neither fires nor passes).
- Only **admitted** (invariant × gateway) cells contribute. An INVALID or admission-not-established cell is
  neither a PASS nor a new violation; it is reported as not-measured.
- The **count itself is a phase-3 result** → it stays in `private/`. Tracked text says only whether the phase-3
  run is complete, never the number (confidentiality block above).

## KC4 frame check (idea 10 kill condition 4 / SCOPE KC4)

> "If **≥80 %** of found violations are **generic web flaws** (XSS, SQLi, SSRF) rather than
> scope/ownership/metering → **REWORK** (the AI-gateway-specific claim fails)."

Each current-release violation is tagged with its invariant family (G1–G7, all AI-gateway-specific:
scope/ownership/metering/role/routing/translation) **or** `generic-web` if it does not map to an invariant
here. If generic-web ≥ 80 % of the found violations, the frame fails → rework. This tag and ratio are phase-3
results → `private/` only. (Also logged at each phase boundary: **M3/KC4 novelty-paper check** — a ≥3-gateway
authz/metering invariant paper appearing re-runs Gate B; none found 2026-11-08,
[../env/kc4-novelty-check.md](../env/kc4-novelty-check.md).)

## Out of this frozen set (would need a dated amendment to add)

Candidate further invariants deliberately **excluded** from the frozen baseline (adding any after results exist
risks post-hoc invariants): team/model allow-list enforcement as a standalone family (folded into INV-G1);
budget/rate-limit **window** accounting across workers (adjacent to KeyPooling/Cooldown-Landmines prior work —
race-class, weak oracle); prompt-cache tenant isolation (KeyPooling's property, **race risk**, out of scope by
idea 10); redemption/top-up races (CWE-362, non-deterministic). Each needs a dated amendment + separate report
if added.

## Amendments

All amendments below are **design-only** (dated, pre-Phase-3): **no current-release cell has run** and no
result exists. They address the review-3 catalogue questions (C1–C7) and review-5 L10. The specific
current-release guard functions and the Go mutation diffs are **not named here** (they live in `mutations/`
and DECISIONS G19, kept out of the public mirror per G20); this file stays generic.

- **A1 — 2026-11-10 — C1: sanity independence (admission ⟂ verdict).** Previously every invariant's "sanity
  configuration (PASS by construction)" was the **current build** — so a current release that *violates* the
  invariant would fail its own sanity check and be discarded INVALID, hiding the very FAIL the novelty half
  looks for (the pilot-08 INV-6 lesson). **Sanity now runs on a target-independent build where the invariant
  holds by construction, never on the target:** for **INV-G2/G3/G4/G5** that is the same gateway's recall
  **fixed** image; for every other (invariant × gateway) pair, a **pinned build whose guard is shown present
  from source**. The current release is the **verdict leg only**. Settled before any current-release cell (no
  result exists yet).

- **A2 — 2026-11-10 — C2: mutation soundness + the admission table.** A mutation is admitted only as a
  **minimal, documented removal of the specific guard on the code path the verdict exercises, in the same
  gateway, pinned by a diff/fixture sha**, changing nothing else (not the mock, driver, route or principal
  setup) — otherwise it tests the fixture, not the gateway. For the **Go** gateways (new-api, Sub2API, one-api)
  "remove the guard" means **rebuilding the image from patched source** (a code mutation; the Go toolchain +
  module downloads are the user-approved C2 source — DECISIONS G19; the concrete INV-G1/G6 builds live in
  `mutations/`, not mirrored). For **INV-G1 and INV-G6** (recall INVALID with mocks) the verdict cell must
  **first show reachability on the current build through its positive control**, or the cell is recorded
  **"admission not established"**, never a vacuous pass/fail. The per-(invariant × gateway) mutation /
  observable / route / signature table is the **A-table** below; it is frozen before the first current-release
  cell.

- **A3 — 2026-11-10 — C3: INV-G7 is exploratory.** INV-G7 (tool-call translation integrity) has no CVE and a
  broad invariant; its mutation presumes a tool/scope filter to disable, which may not exist (then sanity is
  not "PASS by construction"). **INV-G7 is relabelled EXPLORATORY and reported separately; it does NOT count
  toward KC3's new-violation half** unless, before Phase 3, it names for each gateway a **documented** per-key
  or per-user tool/model restriction **and** the code guard that enforces it.

- **A4 — 2026-11-10 — C4: per-gateway observables frozen before Phase 3.** The concrete observable, route and
  signature for each (invariant × gateway) are frozen in the A-table **before** any current-release cell (a
  cell judged against an observable chosen after the first run is post-hoc). Per-gateway differences called
  out: **INV-G3** "balance" is **budget/spend** on LiteLLM and Sub2API vs a **quota balance** on new-api and
  one-api; **INV-G4** secret fields and **INV-G5** resource ids differ per gateway.

- **A5 — 2026-11-10 — C5: one-api mapping + disclosure channel.** Pre-registered so a one-api hit is classified
  by **mechanism**, not after the fact: one-api **CVE-2026-81027** (channel pinning via `channelid`) → **INV-G5**;
  **CVE-2026-11465** (redemption race) → **outside the frozen set** (races are excluded). Both are
  known-unpatched public advisories and are **not** new violations if hit. one-api has **no** affected/fixed
  images, so **every one-api cell depends on a C2 build mutation** for admission (A2). Disclosure channel for
  one-api is **the user's decision** (SCOPE), correcting the catalogue's blanket "GitHub private reporting"
  wording for that gateway.

- **A6 — 2026-11-10 — C6: firing-rule completeness clause.** KC3's new-violation half may be declared **"0 new"
  (the downgrade)** only when the **admitted** cells cover the **full frozen catalogue on ≥3 gateways**.
  Otherwise the result is **INCOMPLETE** — it neither fires the downgrade nor passes the novelty half. (This is
  SCOPE's completeness clause made explicit; "≥1 new violation across a ≥3-gateway set passes" is unchanged.)

- **A7 — 2026-11-10 — C7: mirror-confidentiality additions.** In addition to the confidentiality block above:
  (a) **admission rows** that run on or touch a current-release build also go to `private/`; (b) per-gateway
  **INV-G7 applicability (NA)** measured on a current release goes to `private/`; (c) **mutation-fixture names
  and commit messages must not hint** which (invariant × gateway) pair behaved how; (d) the **pre-push check
  greps the whole replay range** for counts, (invariant × gateway) pairs and verdict words (pilot-08 practice);
  (e) per **G20**, `mutations/` and the guard-specific build detail are **not published** to the mirror until
  after Phase 3 and any disclosure finish.

- **A8 — 2026-11-10 — review-5 L10: empty/non-integer journal count → INVALID.** In every **journal-based**
  cell (**INV-G5**, **INV-G6**, and any cell whose observable is a mock-journal count), an **empty or
  non-integer** count maps to **INVALID** — it is never defaulted to 0 (which could turn a refused leg into a
  spurious PASS with the journal never observed). **Enforced in the shared helper** `scripts/lib.sh`
  (`jint` / `journal_delta`, review 6 M8): `journal_delta` returns the delta only when both counts are
  non-empty integers, else the cell records INVALID. Every journal-based cell uses it before deciding a verdict
  (the R5 G18J cell verified its counts by hand; this makes it structural for the Phase-3 cells).

- **A10 — 2026-11-10 — review 7: rebuild-mutation gating + sanity-leg existence check.** (1) **Rebuild-mutation
  cells are not admitted until the S2 control exists.** Any cell whose mutation is a **rebuilt** image (INV-G1 on
  new-api, INV-G6 on Sub2API, and any future rebuild) is recorded **"admission not established"** — never a
  verdict — until the **S2 no-op rebuild control** holds (an **unpatched** rebuild of the same current-release
  source matches the pristine image on the cell's positive control); S2 depends on **M10** (the user's Go-download
  confirmation) and is **not built**. Cells whose admission uses **official images only** (the **G2–G5** rows on
  their recall gateway: recall **fixed** image = sanity, recall **affected** image = mutation) are **cleared for
  Phase 3 with the user's go** and do not wait on S2. (2) **Sanity-leg existence check.** The target-independent
  sanity images (rc.23, 0.1.169) differ from the verdict release **beyond the guard**; **before each sanity leg**,
  confirm the A-table **route, principals and observable exist on that sanity build**, else the leg is **INVALID**
  (not PASS). (3) **Never swap the sanity build after a result** (that would be post-hoc). Review 7 independently
  re-verified S1 on the tag objects (G1 guard absent rc.22 / present + byte-identical rc.23 = rc.48; G6 guard
  absent 0.1.168 / present 0.1.169 & 0.2.20).

- **A9 — 2026-11-10 — review 6 S1 + M9: target-independent sanity, pinned and complete before each cell.**
  (S1) The admission **sanity** build is **target-independent** — a pinned build whose guard is shown present
  from source, never the current (verdict) build. Concrete, source-confirmed, no Go build: **INV-G1 →
  `calciumion/new-api:v1.0.0-rc.23`**, **INV-G6 → `weishaw/sub2api:0.1.169`** (the R6 fixed recall image); the
  A-table carries these and `env/sanity-build-evidence.md` the evidence + digests. (M9) **Completeness gate:**
  every **pin-before-cell** A-table row (its sanity build, mutation, observable, route and signature) must be
  **fully specified, source-pinned and committed before that (invariant × gateway) pair's first current-release
  cell**. A cell run against an A-table row that is still `pin-before-cell` is **inadmissible** (not a
  pass/fail). This holds the admission table complete per pair ahead of any Phase-3 run.

### A-table — per-(invariant × gateway) admission (frozen pre-Phase-3; **design only, no results**)

Sanity = the **target-independent** build on which the invariant holds by construction (A1). Mutation = the
**minimal single-guard removal** on the same gateway (A2); for Go gateways this is a patched-source rebuild
(G19; INV-G1/G6 concretely built in `mutations/`, not mirrored). "Observable/route/signature" is the frozen
oracle from the "Oracle signatures" table, specialised per gateway (A4). Cells marked **pin-before-cell** still
need their exact guard/observable read from that gateway's pinned source before that cell runs (a prerequisite
of A1/A2/A4); none runs until Phase 3 is cleared.

| Inv | Gateways (applies) | Sanity (target-independent) | Mutation (admission FAIL leg) | Observable / route / signature |
|---|---|---|---|---|
| G1 | new-api, LiteLLM, one-api, Sub2API | **target-independent** (S1): new-api = earlier official release **`v1.0.0-rc.23`** (scope guard present + used, source-confirmed, byte-identical to rc.48, absent ≤ rc.22; `env/sanity-build-evidence.md`); LiteLLM/one-api/Sub2API = pin-before-cell guard-present build | **Go rebuild** with the key/token scope-authorization guard removed (new-api: built, `mutations/`; LiteLLM/one-api/Sub2API: pin-before-cell) | child credential reaches an out-of-grant route/model (2xx the creator cannot); PASS = refused with the scope-check signature |
| G2 | LiteLLM, new-api, one-api, Sub2API | **recall fixed image** (R2 fixed) for LiteLLM; per-gateway fixed/guarded build elsewhere (pin-before-cell) | recall **affected** image (R2) for LiteLLM; config/build removal of the self-role field-guard elsewhere | re-read of the self-updated record shows the elevated attribute; PASS = field-guard refusal + unchanged on re-read |
| G3 | new-api, one-api, LiteLLM, Sub2API | **recall fixed image** (R3 fixed) for new-api; guarded build elsewhere (pin-before-cell) | recall **affected** image (R3) for new-api; build/config removal of the saturating bound elsewhere | billed call with out-of-range quantity → **balance** (quota on new-api/one-api; **budget/spend** on LiteLLM/Sub2API, A4) strictly increased; PASS = refused or balance-after ≤ before |
| G4 | new-api, one-api, LiteLLM, Sub2API | **recall fixed image** (R4 fixed) for new-api; guarded build elsewhere (pin-before-cell) | recall **affected** image (R4) for new-api; build removal of the serialization redaction elsewhere | lower role's listing exposes a higher role's non-empty secret field (per-gateway field, A4); PASS = present but absent/empty |
| G5 | new-api, one-api, LiteLLM, Sub2API | **recall fixed image** (R5 fixed) for new-api; guarded build elsewhere (pin-before-cell); one-api CVE-2026-81027 maps here (A5) | recall **affected** image (R5) for new-api; build removal of owner-scoping elsewhere | tenant B receives tenant A's resource by A's id (+journal fetch for B where upstream); PASS = refused/404 owner-scoped + no journal fetch (A8) |
| G6 | Sub2API, LiteLLM, new-api | **target-independent** (S1): Sub2API = the R6 **fixed** recall image **`0.1.169`** (path-confinement guard present, source-confirmed, absent at 0.1.168; NOT the current `0.2.20`); LiteLLM/new-api = pin-before-cell guard-present build | **Go rebuild** with the path-confinement guard removed (Sub2API: built, `mutations/`; LiteLLM/new-api: pin-before-cell) | mock journal records an upstream path escaping the operator prefix with operator creds; PASS = refused/under-prefix (A8) |
| G7 | *(exploratory, A3)* | n/a until grounded per gateway (A3) | n/a until a documented tool/scope guard is named (A3) | forbidden tool/model invoked via translation (journal); **not counted** unless grounded (A3) |

Reachability caveat (A2): for **G1** and **G6** the verdict cell must first show the probed path is reachable on
the **current** build via its positive control, else the cell is "admission not established" (not a FAIL/PASS).
