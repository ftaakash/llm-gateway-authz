#!/usr/bin/env bash
# Shared helpers for pilot 10 scripts. Local testbed only (SCOPE.md).
# Mirrors pilot 08's lib.sh: an ephemeral driver container on an internal
# (no-egress) network issues curl; JSON is parsed host-side with jq.exe.
set -euo pipefail
PILOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JQ="${JQ:-/c/Users/Administrator/tools/jq/jq.exe}"
# All downloaded artefacts live on D: (C: must not grow). Source clones, tool
# binaries and any archive go under $DATA; never under the repo's build/ on C:.
DATA="${DATA:-/d/Masters-data/pilot10}"
SRC_DIR="${SRC_DIR:-$DATA/src}"
PINS="$PILOT/env/pins.tsv"
COMMIT="$(git -C "$PILOT" rev-parse --short HEAD)"

# Dirty-tree marker so results never claim a clean commit they did not run on.
# Evidence/result outputs are excluded (writing them is not a code change).
_dirty=no
git -C "$PILOT" diff --quiet HEAD -- . ':(exclude)env/*.csv' ':(exclude)results' ':(exclude)private' || _dirty=yes
[ -n "$(git -C "$PILOT" ls-files --others --exclude-standard -- . ':(exclude)env/*.csv' ':(exclude)results' ':(exclude)private' 2>/dev/null)" ] && _dirty=yes
[ "$_dirty" = yes ] && COMMIT="${COMMIT}-dirty"

DRIVER_IMG="${DRIVER_IMG:-pilot08/curl:8.11.1}"   # reused from pilot 08 (M4)

require_docker() {
  docker info >/dev/null 2>&1 || { echo "docker engine not available; run kc preflight and re-run" >&2; exit 3; }
}

# pins.tsv: image<TAB>digest  (one per line, '#'-comments allowed)
pins() { grep -v '^#' "$PINS"; }
digest_of() { pins | awk -F'\t' -v k="$1" '$1==k{print $2}'; }

# Run curl in an ephemeral driver container joined to network $1 (reach services by name).
# Usage: drv <net> <curl-args...>   -> curl stdout on host stdout
drv() { local net="$1"; shift; docker run --rm --network "$net" "$DRIVER_IMG" "$@"; }

# --- A8 (review 5 L10 / review 6 M8): mock-journal counts must be non-empty integers ---
# A journal observable (e.g. INV-G5/INV-G6 before/after upstream-fetch counts) maps the cell to
# INVALID when a count is empty or non-integer — it is NEVER defaulted to 0, which could turn a
# refused leg into a spurious PASS with the journal never actually observed. Every journal-based
# cell must use these before deciding a verdict.
# jint: succeed iff $1 is a non-empty string of digits.
jint() { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }
# journal_delta <before> <after>: echo (after-before) iff both are non-empty integers; else return 1
# (the cell must then record INVALID, not compute a delta from a defaulted 0).
journal_delta() { jint "$1" && jint "$2" || return 1; echo $(( $2 - $1 )); }

require_docker
