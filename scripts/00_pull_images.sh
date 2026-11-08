#!/usr/bin/env bash
# Pull every pinned image BY DIGEST (env/pins.tsv) and retag locally by its
# tag name for readability. Verifies the pulled RepoDigest matches the pin.
# Needs egress (pull step only; the runtime testbed network stays internal).
# Logs each pull to env/pull-log.csv (name, source digest, size, date).
source "$(dirname "$0")/lib.sh"
out="$PILOT/env/pull-log.csv"
[ -f "$out" ] || echo "date,image_tag,pinned_digest,repo_digest_after_pull,size_bytes,match" > "$out"
fail=0
while IFS=$'\t' read -r tag dig; do
  [ -z "${tag:-}" ] && continue
  repo="${tag%%:*}"
  src="${repo}@${dig}"
  echo "pulling $tag <- $src"
  docker pull -q "$src" >/dev/null
  docker tag "$src" "$tag"
  # Confirm the local image carries exactly the pinned digest.
  got="$(docker image inspect "$tag" --format '{{range .RepoDigests}}{{println .}}{{end}}' | grep -F "$dig" | head -1)"
  size="$(docker image inspect "$tag" --format '{{.Size}}')"
  match=no; [ -n "$got" ] && match=yes
  echo "$(date -u +%FT%TZ),$tag,$dig,${got:-MISSING},$size,$match" >> "$out"
  [ "$match" = yes ] || { echo "  !! digest mismatch for $tag" >&2; fail=1; }
done < <(pins)
echo "--- pull log: $out"
[ "$fail" = 0 ] && echo "all digests verified" || { echo "DIGEST MISMATCH — stop"; exit 1; }
