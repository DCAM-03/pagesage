#!/usr/bin/env bash
# Called by serialized release jobs only; never publishes a draft.
set -euo pipefail
if [[ $# -lt 2 || "$1" != v* ]]; then
  printf 'Usage: publish_draft_release.sh vVERSION asset...\n' >&2
  exit 1
fi
release_tag="$1"
shift
for asset in "$@"; do
  test -f "$asset" || { printf 'Missing asset: %s\n' "$asset" >&2; exit 1; }
done
if draft="$(gh release view "$release_tag" --json isDraft --jq .isDraft)"; then
  if [[ "$draft" != true ]]; then
    printf 'Refusing to modify published release %s\n' "$release_tag" >&2
    exit 1
  fi
else
  flags=(--draft --verify-tag --generate-notes --title "$release_tag")
  if [[ "$release_tag" == *-* ]]; then flags+=(--prerelease); fi
  gh release create "$release_tag" "${flags[@]}"
fi
gh release upload "$release_tag" --clobber "$@"
