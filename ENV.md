# ENV — planned testbed pins (pilot 10)

**Status: planned only. Nothing has been pulled.** Pins read 2026-11-08 from registry manifests
(`docker-content-digest` header of the multi-arch index; Docker Hub = `registry-1.docker.io`, GHCR =
`ghcr.io`). Sizes are compressed amd64 sizes from the Docker Hub tags API where shown; GHCR sizes were
not read and are recorded at pull time. Images are always pulled **by digest** (`repo@sha256:…`),
never by tag. Each pull is logged in the pull log below (name, source, size, digest, date), as required
by the standing approval. Every single image is expected to be well under 5 GB (UNVERIFIED for the
GHCR LiteLLM images until pulled).

## Recall ladders (kill condition 3, recall half)

### LiteLLM — `ghcr.io/berriai/litellm` (GHCR)

| Rung | Tag | Used by | Digest |
|---|---|---|---|
| L0 | `v1.83.6-nightly` | R2 (mainline predecessor control; must FAIL — H3) | `sha256:2d4182e96d64df4a605cbfebd79ff8564c90bb026594feb70ab9952d7ae48f86` |
| L1 | `v1.83.7-stable` | R2 (affected, FAIL) | `sha256:af0152ca6dfb6703b35c0d4899effa9ac132bce9a4fbcbe1dc6ef145c100db26` |
| L2 | `v1.83.8-nightly` | R2 (fixed, PASS) | `sha256:085b1f79c4547f8e7abb46755e8a55ad96a8eaae5009cb74cfa37d9a0ec7f1e9` |
| L3 | `v1.83.9-nightly` | R2 (advisory: affected) | `sha256:4148c2c806d028eb8b159fbdc022916eb068a34138a5f4a45b1384a39a3ef42c` |
| L4 | `v1.83.10-stable` | R2 (advisory: fixed) | `sha256:6c82d338a60e7b273ae46bf1d8db814d2856ae010f96c44eeadde574d3893f76` |
| L5 | `v1.83.13-nightly` | R1 (affected) | `sha256:2fc41eb21c717a5d5ff72b6e3c3f13ea9c7506f2457a6a1f41454fcfedd33a8d` |
| L6 | `v1.83.14-stable` | R1 (fixed) | `sha256:c81eb79cd4333c6cfe374c0ec929110fd23f0ee5f7fd198855a6fbddc77b83ba` |

R2's pair is frozen L1 (v1.83.7-stable, FAIL) -> L2 (v1.83.8-nightly, PASS) by the G5 source read; L3/L4 are extra PASS rungs and the advisory's own pair, also run.
Tag commits: `v1.83.6-nightly` `9e4352afb42a`, `v1.83.9-nightly` `850fe595ac54`, `v1.83.10-stable` `0db4158c56f6`, `v1.83.13-nightly`
`7b47dffefd88`, `v1.83.14-stable` `3d2b8fed3281` (GitHub API, 2026-11-08).

### new-api — `calciumion/new-api` (Docker Hub)

| Rung | Tag | Used by | Digest | Size |
|---|---|---|---|---|
| N1 | `v0.11.4-alpha.1` | R5 affected | `sha256:7feb70ca2786d1236ffd1134ee6ae7413a532dd67cc5bcab9cbe15267b586f5a` | 57 MB |
| N2 | `v0.11.4-alpha.2` | R5 fixed | `sha256:137ea8bbdb6d1d8e56ac5810761a44a9d55fafeaefb7a40a402289cd37013d04` | 57 MB |
| N3 | `v1.0.0-rc.6` | R4 affected | `sha256:bb560b0f59df2d03025136320d6217e7e7c1578e31267ecca2df939317015431` | 62 MB |
| N4 | `v1.0.0-rc.7` | R4 fixed | `sha256:af1f10306055076b58acb17298e2a775a484ee3fdc1eddae35e431f243e1e950` | 63 MB |
| N5 | `v1.0.0-rc.17` | R3 affected | `sha256:108546a0e4b1fc1e097e8fc87fcdd27029799ec3e5bf0d5f50fb612427f087f1` | 76 MB |
| N6 | `v1.0.0-rc.18` | R3 fixed | `sha256:d75ca98ee8b04fcc4cbdc0aad98bb6327280c402cf919969e0055629a88799ca` | 76 MB |

Tag commits: alpha.1 `c0a0285f7429`, alpha.2 `8d7d880db5c9`, rc.6 `18282e610ddf`, rc.7 `146dd77b83a2`,
rc.17 `45f0484dc1dc`, rc.18 `c9943d37ad93`.

### Sub2API — `weishaw/sub2api` (Docker Hub)

| Rung | Tag | Used by | Digest | Size |
|---|---|---|---|---|
| S1 | `0.1.168` | R6 affected | `sha256:85d29bfc69fa7a314cd2a35420dbe2faa6251ccbb3c3d1d4c56c732270e87479` | 78 MB |
| S2 | `0.1.169` | R6 fixed | `sha256:c9ee04bc92f916c9fce269c23e01bbde4ca6aee190e99221114224e37aa91ed9` | 78 MB |

Tag commits: `v0.1.168` `99c8e4bf7564`, `v0.1.169` `26d894ef4f50`.

## Current releases (novelty half; pulled only after recall passes)

| Gateway | Image | Digest | Size |
|---|---|---|---|
| LiteLLM | `ghcr.io/berriai/litellm:v1.108.2` | `sha256:d8b4ac356743d647a13bb93f45b941fcd5f5354122cfd205948a1b192790389d` | not read |
| new-api | `calciumion/new-api:v1.0.0-rc.48` | `sha256:51401a46510bf110ffafdf2cd7177e0b80bbcf02439e69b665c696f330e87ae5` | 78 MB |
| Sub2API | `weishaw/sub2api:0.2.20` | `sha256:ebdd50dda32e7a30c840de884d29dd7cbe52776d34fe2899733535f16a0b2813` | 89 MB |
| one-api | `justsong/one-api:v0.6.10` | `sha256:e667221a2e197f005bdf3aba300885ac165fde37a0de9773e478678a9e04b24a` | 28 MB |

## Supporting images (Docker Hub)

| Role | Image | Digest | Size |
|---|---|---|---|
| DB for LiteLLM / Sub2API (reused pin from pilot 08) | `library/postgres:16.4-alpine` | `sha256:5660c2cbfea50c7a9127d17dc4e48543eedd3d7a41a595a2dfa572471e37e64c` | 99 MB |
| Cache for Sub2API (and new-api if needed) | `library/redis:7.4.1-alpine` | `sha256:c1e88455c85225310bbea54816e9c3f4b5295815e6dbf80c34d40afc6df28275` | 19 MB |
| Mock model provider (stubs + request journal) | `wiremock/wiremock:3.13.1` | `sha256:d61e7720f89483fdef5366843b58d1dfd06bcce5828179c9f2f54de5c28354b0` | 110 MB |
| Test driver (curl) | `curlimages/curl:8.11.1` | `sha256:c1fe1679c34d9784c1b0d1e5f62ac0a79fca01fb6377cdd33e90473c6f9f9a69` | 10 MB |
| Driver base for jq (apk from build step only) or egress probe | `library/alpine:3.20` | `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc` | 4 MB |

Whether pilot 08's existing driver image (bash + curl + jq) can be reused instead of the last two rows
is checked in phase 1; if so, those two are not pulled.

## Planned testbed shape (phase 1; nothing built yet)

- One Docker network created with `--internal` per gateway cell (no default route, no egress). An egress
  negative probe (driver tries an external name and an external IP; both must fail) is stored under
  `env/` before the first test run, as in pilot 08.
- Each cell = one gateway image (by digest) + its DB/cache + one WireMock + the driver. Fresh volumes per
  cell, so no state carries between rungs.
- Gateway settings that would otherwise reach the internet at start-up (e.g. LiteLLM's remote model-cost
  map; update checks) are switched to local mode where a documented setting exists; the internal
  network blocks the rest regardless. Provider keys are dummy strings. Upstream base URLs point at the
  WireMock container.

## Pull log

| Date | Image | Source | Size | Digest | Note |
|---|---|---|---|---|---|
| — | nothing pulled yet | | | | |

## Source-clone log (G9; blobless clones for the static reachability read — no images pulled)

| Date | Repo | Source | Size (blobless) | HEAD at clone | Note |
|---|---|---|---|---|---|
| 2026-11-08 | QuantumNous/new-api | github.com (clone `--filter=blob:none`) | 8.7 MB | `dd50ee0a567b810ea60e74dcd9ea6a5786b37b91` | source read only (R3/R4/R5) |
| 2026-11-08 | Wei-Shaw/sub2api | github.com (clone `--filter=blob:none`) | 18 MB | `6b4b37db43443b5e88e424fe3c69602cc3810dfb` | source read only (R6) |
| 2026-11-08 | envoyproxy/ai-gateway | github.com (clone `--filter=blob:none`) | 3.8 MB | `d41f08217b8d8c362f85f0d5094b2fd072fbb4c4` | source read only (backup, not selected) |
| 2026-11-08 | BerriAI/litellm | github.com (clone `--filter=blob:none`) | 126 MB | `d0c16008c8e80b992f9bdb90078e17ee59cda5b4` | source read only (R1/R2, backup CVE-2026-35029) |

**Relocated to D: 2026-11-08 (user: C: must not grow).** The clones were **moved** (not re-downloaded)
from `build/src/` to **`D:\Masters-data\pilot10\src\<project>`** (litellm 127 MB, new-api 24 MB, sub2api
81 MB, ai-gateway 3.8 MB). Scripts reference them via `$SRC_DIR` (default `/d/Masters-data/pilot10/src`,
set in `scripts/lib.sh`). Nothing was executed from them. **Docker's disk image was moved by the user to
`D:\DockerData`**, so all image pulls and the 15 gateway images already pulled now live on D:; C: is not
used for pilot-10 artefacts. Any further download (e.g. `redis:7.4.1-alpine`, still needed for R6) lands on
D: and is gated on C: free ≥ 40 GB first.
