# Advisory oracle — selection, version pins and regression ladders (pilot 10)

**Status: FROZEN 2026-11-08** (user G4, after the static reachability ranking below). The six are
**R1–R6 as listed** (no swap needed: all six are source-reachable with mock providers and deterministic).
After the freeze no advisory is swapped, dropped or added, and an advisory that turns out unreachable
**at run time** counts as **not rediscovered** (pilot 08 D4/D6 rule). No test has been written or run.
The ranking that justified the freeze is the "Static reachability ranking" section below; it rests on
source reads only (GitHub clones, nothing executed).

**Admission rule** (SCOPE.md): a test is valid only if it **FAILs on the affected image and PASSes on the
fixed image**, with the positive control holding on both. **Kill condition 3 (recall half):** ≥ **4 of 6**
must flip FAIL→PASS exactly at the predicted version.

## Static reachability ranking (G4) — source reads only, nothing executed (2026-11-08)

Each candidate was read at its affected and fixed tags from blobless GitHub clones under `build/src/`
(pre-approved source clones; no build, no run). "Mock-reachable" = the vulnerable path can be exercised
on a local-only testbed with a WireMock upstream and dummy keys, with a positive control. "Deterministic"
= the FAIL is produced by a crafted but fixed request, not by a timing window.

| Rank | Candidate | Mock-reachable | Deterministic | Setup weight | Source evidence (what was read) |
|---|---|---|---|---|---|
| 1 | **R4** new-api CVE-2026-64859 | yes — no model call | yes | light | `model/user.go`: at `v1.0.0-rc.6` `AccessToken` has `json:"access_token"` and user-list queries use `Omit("password")` only; fix commit `0936e25` changes the tag to `json:"-"`. Checked by admin user-list read. |
| 2 | **R2** LiteLLM CVE-2026-47102 | yes — no model call | yes | light | `internal_user_endpoints.py` `_update_single_user_helper`: role guard ("Only proxy admins can modify user roles") **absent** at `v1.83.6-nightly`/`v1.83.7-stable`, **present** at `v1.83.8-nightly`+. `/user/update` reaches that helper at every tag. |
| 3 | **R1** LiteLLM CVE-2026-47101 | yes — no model call | yes | light | `key_management_endpoints.py`: `_check_allowed_routes_caller_permission` exists at `v1.83.13-nightly` but a `key_type`-derived elevated route bucket (`handle_key_type` → `["management_routes"]`) is **not** re-checked until `v1.83.14-stable` (fix `2220f30` adds the post-`handle_key_type` re-check + passthrough guard). |
| 4 | **R3** new-api CVE-2026-71479 | yes — billed call to mock channel | yes (overflow, not a race) | medium (needs a mockable billed path + balance read) | `relay/helper/price.go` at `v1.0.0-rc.17` multiplies float ratios by user-controlled quantity fields; fix `c9943d37`/`d0bd8aac` add saturating conversions and max-field bounds across relay validators. |
| 5 | **R5** new-api CVE-2026-30886 | yes — video channel base URL is channel-configurable | yes | medium (video channel + task setup via mock) | `controller/video_proxy.go` `VideoProxy` fetches by `GetByOnlyTaskId(taskID)` (no owner check) at `v0.11.4-alpha.1`; route `GET /v1/videos/:task_id/content` under `TokenOrUserAuth()`. Fix `50ec2bac` switches to owner-scoped retrieval. Task adaptors (gemini/doubao) use `info.ChannelBaseUrl` → WireMock. |
| 6 | **R6** Sub2API CVE-2026-73079 | yes — `upstream`-type account uses operator Base URL + API key (no OAuth login) | yes | heavier (PostgreSQL + Redis + account setup) | `internal/domain/constants.go` `AccountTypeUpstream` ("Base URL + API Key"); `internal/handler/endpoint.go` responses wildcard (`/responses/*subpath`, `/backend-api/codex/responses/*subpath`) splices the caller subpath into the upstream URL; fix adds `internal/service/upstream_path_guard.go` (present only at `v0.1.169`). Observed via the mock request journal. |

**Backups considered, not selected** (kept as alternates; selection is frozen without them):

| Candidate | Mock-reachable | Deterministic | Why not selected |
|---|---|---|---|
| LiteLLM CVE-2026-35029 (`/config/update` no admin check; fixed 1.83.0) | yes — management API | yes | Strongest backup. Affected rung would be a 1.82.x GHCR image, fixed `v1.83.0-nightly`. Not needed (6 primaries all reachable); its impact is config rewrite/RCE, so the assertion must stay to "non-admin reaches the route" (observe the authz gate), never the RCE — slightly more care than the 6 chosen. |
| new-api CVE-2026-64865 (quota cache overwrite; `v1.0.0-rc.15`→`rc.16`) | yes | **no** (CWE-362 race; FAIL needs a concurrent window) | Non-deterministic FAIL; a race is a weak oracle cell. |
| Envoy AI Gateway / Agent Router GHSA-w5rr-gc4v-5946 (metering, `≤1.1.0`→`1.2.0`) | unclear | yes | Needs an Envoy + Kubernetes Gateway API stack; standalone local deployability unverified; advisory package name (`theagentrouter/agent-router`) differs from the repo (`envoyproxy/ai-gateway`). Heaviest setup, lowest confidence. |

**Freeze decision (G4):** all six primaries are mock-reachable and deterministic from the source, spanning
3 gateways (LiteLLM ×2, new-api ×3, Sub2API ×1) — the idea-10 "≥2 per gateway where possible, ≥3 overall"
is met except that Sub2API contributes one (only one authorization-class advisory exists for it). The six
R1–R6 are frozen as listed. If, at run time, any of R3/R5/R6 proves unreachable, it counts as not
rediscovered and the backups are **not** substituted (post-freeze rule); the recall result is reported as is.

## How the facts below were checked (2026-11-08)

- Advisory text, affected range and fixed version: GitHub Advisory Database via `gh api advisories/<GHSA>`
  (GitHub-reviewed global advisories) and, where the project publishes its own, the repository advisory
  (`gh api repos/<owner>/<repo>/security-advisories/<GHSA>`). Both are primary sources. NVD pages were
  not opened separately.
- Fix commits: the commits named in the advisory references. **Flip point** = the first published release
  whose tag contains every named fix commit, checked by `gh api repos/<r>/compare/<commit>...<tag>`
  ("ahead"/"identical" = the tag contains the commit; "behind"/"diverged" = it does not).
- Images: digests from the registry manifest (`docker-content-digest` header, multi-arch index) of
  Docker Hub (`registry-1.docker.io`) and GHCR (`ghcr.io`). Nothing was pulled.
- **Reachability with mock providers is a desk judgment from the advisory text, not a run.** It is marked
  *expected* or *UNVERIFIED* below; it is confirmed only in phase 1.

## Why not two per gateway on LiteLLM, new-api and one-api (see G2, G3)

The idea-10 kill test asked for "≥2 per gateway on LiteLLM, new-api, one-api". **one-api cannot supply
any advisory that satisfies the oracle**: its last release is `v0.6.10` (2025-02-02), its last commit on
the default branch is 2025-02-21, and both 2026 advisories are **unpatched**:
CVE-2026-81027 / GHSA-877p-7prq-ffj6 (channel pinning via `channelid`; references issue #2410, open; no
patched version) and CVE-2026-11465 / GHSA-7v3v-cp44-vc8m (redemption race; fix PR #2399 open, unmerged).
A FAIL→PASS flip needs a fixing version, so one-api can only be a **current-release (novelty) target**.
The third recall gateway proposed instead is **Sub2API** (Wei-Shaw/sub2api; actively maintained), whose
only authorization-class advisory is GHSA-vrxq-qm4h-6hgg. Sub2API's other advisory (password-reset
poisoning) is a generic web flaw and is not used. Hence the proposed split is **2 LiteLLM / 3 new-api /
1 Sub2API**. This deviates from the idea-10 wording and needs the user's OK (G2/G3).

## The proposed 6

| ID | Gateway | Advisory | Class | Affected rung (FAIL) | Fixed rung (PASS) | Mock needed? | Reachable with mocks |
|---|---|---|---|---|---|---|---|
| R1 | LiteLLM | CVE-2026-47101 · GHSA-qrc4-49gv-mv9m | scope escalation via key `allowed_routes` | `v1.83.13-nightly` | `v1.83.14-stable` | no (management API only) | expected |
| R2 | LiteLLM | CVE-2026-47102 · GHSA-wpfp-gwwc-vwq6 | self role change via `/user/update` | `v1.83.7-stable` (source-confirmed; see note R2) | `v1.83.8-nightly` | no | reachable (source-confirmed) |
| R3 | new-api | CVE-2026-71479 · GHSA-8r8v-xf7q-rcpr | metering: quantity overflow → negative charge | `v1.0.0-rc.17` | `v1.0.0-rc.18` | yes (billed relay call) | UNVERIFIED |
| R4 | new-api | CVE-2026-64859 · GHSA-6x2c-phff-wx57 | role boundary: admin reads root access token | `v1.0.0-rc.6` | `v1.0.0-rc.7` | no | expected |
| R5 | new-api | CVE-2026-30886 · GHSA-f35r-v9x5-r8mc | ownership: task_id IDOR in VideoProxy | `v0.11.4-alpha.1` | `v0.11.4-alpha.2` | yes (video task upstream) | UNVERIFIED |
| R6 | Sub2API | CVE-2026-73079 · GHSA-vrxq-qm4h-6hgg | caller-supplied subpath spliced into operator upstream URL | `0.1.168` | `0.1.169` | yes (operator base URL → mock) | UNVERIFIED |

Root-cause class across the set (idea 10 delta 3): R1, R5, R6 are "a caller-supplied identifier or
field selects or widens a resource outside the caller's grant"; R2, R4 are role-boundary checks; R3 is
metering.

### R1 — LiteLLM CVE-2026-47101 (GHSA-qrc4-49gv-mv9m), CWE-863, published 2026-05-21
- **Source:** GitHub-reviewed global advisory (not listed among BerriAI/litellm repository advisories).
  Range `litellm < 1.83.14`, fixed `1.83.14`.
- **Mechanism (advisory):** an `internal_user` creating a key can set `allowed_routes` to routes their
  role does not permit; the key then reaches admin-only routes.
- **Fix commits:** `2220f3076ac89bd2a2e3439acf57dcfbec2434c9` ("tighten caller-permission checks on key
  route fields", 2026-04-25), `5190bd07eb23a037745d86328096f54378f1614a`,
  `d910a95661fce3cdd36f3b06c03ecf9c46c6457c` (2026-04-09, "improve input validation on management
  endpoints").
- **Ancestry:** `2220f30`, `5190bd0` are **not** in `v1.83.13-nightly` and **are** in `v1.83.14-stable`;
  `d910a95` is already in `v1.83.7-stable` and later tags (a partial hardening, not the route check).
  `v1.83.14-stable` is 263 commits ahead of `v1.83.13-nightly`, 0 behind. Advisory and ancestry agree.
- **Ladder:** `v1.83.13-nightly` (FAIL) → `v1.83.14-stable` (PASS).
- **Assertion (sketch):** an `internal_user` key creates a child key whose `allowed_routes` names an
  admin-only **read** route; PASS = creation refused, or the child key is refused on that route.
  Positive control: the same user can create a key with a permitted route and use it.
- **Invariant:** scope non-escalation (a derived credential's grant ⊆ its creator's grant).

### R2 — LiteLLM CVE-2026-47102 (GHSA-wpfp-gwwc-vwq6), CWE-863, published 2026-05-21
- **Source:** GitHub-reviewed global advisory. Range `litellm < 1.83.10`, fixed `1.83.10`.
- **Mechanism (advisory):** `/user/update` lets a user change their own `user_role`, e.g. to
  `proxy_admin`; `org_admin` can do so without chaining any other flaw.
- **Fix commits:** `e6f18ce75b111c9b93dc15c72894cbdeb53177ce` (2026-04-10, "align field-level checks in
  user and key update endpoints"), `128d32d2494b759c5d15da3452452af4c6a34c01` (2026-04-11, "extend
  field-level checks to bulk user update path"); PR #25541 (merged 2026-04-12 into branch `litellm_yj_apr_11`).
- **⚠ Advisory and ancestry disagree on the flip point.** Both fix commits are **absent** from
  `v1.83.6-nightly` and `v1.83.7-stable` and **present** in `v1.83.8-nightly`, `v1.83.9-nightly` and
  `v1.83.10-stable`. So by ancestry the fix ships at **1.83.8-nightly**, while the advisory says
  1.83.9 is still affected and 1.83.10 is the fix. (Possible reasons: the advisory names the first
  *stable* release; or more code was needed than the two named commits. Not resolved.)
- **Resolved (G5, source read 2026-11-08):** the `/user/update` route reaches `_update_single_user_helper`
  at every candidate tag; the role guard ("Only proxy admins can modify user roles", from fix commit
  `e6f18ce`) is **absent** at `v1.83.6-nightly` and `v1.83.7-stable` and **present** at `v1.83.8-nightly`,
  `v1.83.9-nightly`, `v1.83.10-stable` and later. So the fix ships at **`v1.83.8-nightly`**, two releases
  before the advisory's stated 1.83.10. **Frozen pair: `v1.83.7-stable` (FAIL) → `v1.83.8-nightly` (PASS).**
  `v1.83.9-nightly` and `v1.83.10-stable` are run as extra rungs and must also PASS (they contain the
  guard). The **advisory's own pair** (`v1.83.9-nightly` → `v1.83.10-stable`) is also run and reported, so
  a reader sees both; by the frozen oracle the measured flip is at 1.83.8-nightly. `v1.83.7-stable` is on
  the stable branch (diverged from the nightly line); the mainline rung just before `v1.83.8-nightly` is
  `v1.83.6-nightly`, which also lacks the guard.
- **Assertion (sketch):** an `org_admin` (and separately an `internal_user`) updates their own record
  with `user_role=proxy_admin`; PASS = refused or role unchanged when re-read. Positive control: the
  same user can update a permitted own field. Role is re-read from `/user/info`, not inferred.
- **Invariant:** no self-elevation (a principal cannot write its own authorization attributes).

### R3 — new-api CVE-2026-71479 (GHSA-8r8v-xf7q-rcpr), CWE-190/682, published 2026-07-09
- **Source:** QuantumNous/new-api repository advisory + GitHub global advisory. Range `<= 1.0.0-rc.17`,
  fixed `1.0.0-rc.18`. The advisory states in-the-wild exploitation on 2026-07-06 and the fix ~2 h later.
- **Mechanism (advisory):** billing paths multiply user-controlled quantity fields (e.g. image `n`) into
  the quota without bound or overflow-safe conversion; an extreme value wraps to a negative quota that
  credits the balance at settlement. Precondition: positive balance covering the normal pre-consume.
- **Fix commits:** `c9943d37ad93477dd937fc4901cc3c4e0fd8aaab` (= the `v1.0.0-rc.18` tag commit),
  `d0bd8aac742d1e160a5ca61743fe35f4fff880e8`. Both absent from `v1.0.0-rc.17`, present in `v1.0.0-rc.18`.
- **Ladder:** `v1.0.0-rc.17` (FAIL) → `v1.0.0-rc.18` (PASS).
- **Assertion (sketch):** with a known small balance, one billed image-generation call to a mock channel
  with an out-of-range quantity; PASS = request refused or balance after ≤ balance before. Positive
  control: a normal call (n=1) is billed (balance decreases by the expected amount).
- **Reachability: UNVERIFIED.** Needs a channel type whose image path the mock can satisfy and that
  reaches the vulnerable settlement path. If only non-mockable paths are affected, R3 = not rediscovered.
- **Invariant:** metering monotonicity (a billed request never increases the caller's balance).

### R4 — new-api CVE-2026-64859 (GHSA-6x2c-phff-wx57), CWE-200, published 2026-07-03 (repo) / 2026-08-17 (global)
- **Source:** repository advisory + global advisory. Range `< 1.0.0-rc.7`, fixed `1.0.0-rc.7`, fixed
  commit `0936e2504655a5cbf7bc3c388f6d3e2bb24916d3`, PR #4929; confirmed by the reporter on `v0.12.14`.
- **Ancestry:** fix commit absent from `v0.12.15` and `v1.0.0-rc.6`, present in `v1.0.0-rc.7`.
- **Ladder:** `v1.0.0-rc.6` (FAIL) → `v1.0.0-rc.7` (PASS).
- **Assertion (sketch):** an `admin` (non-root) lists users; PASS = no root record carries a non-empty
  `access_token`. Only a boolean is recorded; the token value is never logged. Positive control: the
  admin's user list returns the root record (so absence is not "nothing returned"), and root has an
  access token set (precondition).
- **Invariant:** role boundary (a lower role never obtains a higher role's credential).

### R5 — new-api CVE-2026-30886 (GHSA-f35r-v9x5-r8mc), CWE-639, published 2026-03-23
- **Source:** repository advisory + global advisory. Range `< 0.11.4-alpha.2`, fixed `0.11.4-alpha.2`,
  fix commit `50ec2bac6b341e651fc9ac4344e3bd2cdaeafdbd` ("update task retrieval to include …").
- **Ancestry:** fix absent from `v0.11.4-alpha.1`, present in `v0.11.4-alpha.2`. The two tags differ by
  **2 commits** (the fix and an unrelated pricing-label change), so the flip isolates the fix well.
- **Ladder:** `v0.11.4-alpha.1` (FAIL) → `v0.11.4-alpha.2` (PASS).
- **Assertion (sketch):** user A creates a video task through a channel pointed at the mock; user B
  requests `GET /v1/videos/<A's task_id>/content`; PASS = refused/404 and the mock journal shows no
  fetch for B. Positive control: A retrieves A's own content.
- **Reachability: UNVERIFIED.** Needs a video channel type whose submit/poll/content calls the mock can
  satisfy. If no mockable video channel reaches `VideoProxy`, R5 = not rediscovered.
- **Invariant:** ownership (a caller-supplied task id never selects another tenant's task).

### R6 — Sub2API CVE-2026-73079 (GHSA-vrxq-qm4h-6hgg), CWE-22/441, published 2026-07-31
- **Source:** Wei-Shaw/sub2api repository advisory. Range `>= 0.1.135, <= 0.1.168`, fixed `0.1.169`.
  Introduced by commit `3403909`. Fix commit `017f6bbd5edffea0639ef3c84c0391161983f1f3`, merged as
  `26d894ef4f50645a4bf1030e378ac892f17d0223` (= the `v0.1.169` tag commit), PR #5137.
- **Ancestry:** both absent from `v0.1.168`, present in `v0.1.169`.
- **Ladder:** `0.1.168` (FAIL) → `0.1.169` (PASS).
- **Mechanism (advisory):** `POST /responses/*subpath` (and two aliases) splice a client-supplied,
  already-decoded subpath into the upstream URL; dot segments are emitted on the wire, so a tenant's
  request reaches a different upstream path carrying the **operator's** upstream credentials.
- **Assertion (sketch):** a tenant key sends a responses request whose subpath contains an encoded
  dot segment; PASS = request refused, and the mock journal shows no request outside the
  `/…/responses/` prefix. Positive control: a legitimate subpath reaches the mock under the prefix with
  the operator's dummy key. The mock records the path only; the dummy key is a fixed test string.
- **Reachability: UNVERIFIED.** The advisory lists "an operator-configured base URL" as one upstream
  kind; whether a local account of that kind can be created without a ChatGPT/OpenAI login is checked in
  phase 1. Sub2API needs PostgreSQL and Redis (UNVERIFIED, from the project README, not opened today).
- **Invariant:** caller-supplied routing fields never widen the upstream resource reached with
  operator credentials.

## Alternates (not part of the set unless the user swaps one in **before** the freeze)

| Gateway | Advisory | Why not in the set | Ladder (unchecked unless noted) |
|---|---|---|---|
| LiteLLM | CVE-2026-35029 · GHSA-53mr-6c8q-9789 — `/config/update` lacks admin check | Impact is config rewrite/RCE; a non-destructive assertion is possible but riskier to keep harmless. Would give a 3/2/1 split | fixed `1.83.0` per advisory; fix commit and last-affected image **not checked** |
| new-api | CVE-2026-64865 · GHSA-j6gc-4893-qwmp — quota cache overwrite (metering) | CWE-362 race: FAIL may be timing-dependent; needs Redis | `v1.0.0-rc.15` → `v1.0.0-rc.16`, fix `dfc0d6324b40c1d6c2972e524409f933541bfb0f` (ancestry ✅) |
| Envoy AI Gateway / Agent Router | GHSA-w5rr-gc4v-5946 — duplicated `stream_options` suppresses usage accounting (metering) | Would add a 4th gateway, but the stack is Envoy + Kubernetes Gateway API; standalone deployability and the package name (`envoyproxy/ai-gateway` vs `theagentrouter/agent-router` in the advisory) are UNVERIFIED; no CVE | `<= 1.1.0` → `1.2.0` per advisory; not checked |

## Current releases for the novelty half (pinned 2026-11-08; may be re-pinned at catalogue freeze)

| Gateway | Release | Tag commit | Image |
|---|---|---|---|
| LiteLLM | `v1.108.2` (2026-11-06) | `831a14c8f48e189e24a85b47da1b31b44e0718b6` | `ghcr.io/berriai/litellm:v1.108.2` |
| new-api | `v1.0.0-rc.48` (2026-11-04) | `706144769e5bed5a47b78721e3bb11da3cf4c0b9` | `calciumion/new-api:v1.0.0-rc.48` |
| Sub2API | `v0.2.20` (2026-11-07) | `dab829a4e9b7d1cc307189aea8b0319eb29e29d0` | `weishaw/sub2api:0.2.20` |
| one-api | `v0.6.10` (2025-02-02; unmaintained) | `3915ce9814b8261a1ab13ed93adec58b463cd75c` | `justsong/one-api:v0.6.10` |

Digests are in [ENV.md](ENV.md). Known **public, unpatched** one-api advisories (CVE-2026-81027,
CVE-2026-11465) are not new violations if hit.

## Corrections to idea 10 found while pinning (for the idea file, not changed here)
- CVE-2026-81027's GHSA (GHSA-877p-7prq-ffj6) references one-api issue **#2410**; #2423 is a second,
  separate report of the same bug. Neither is fixed.
- GHSA-7hp6-4w63-5g45 (LiteLLM salt-key reuse) has CVE-2026-114612.
- The idea's LiteLLM ladder came from PyPI; PyPI is not approved, so all LiteLLM rungs are GHCR images.
