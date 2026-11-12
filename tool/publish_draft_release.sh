#!/usr/bin/env bash
# Syncs release assets without publishing drafts.
set -euo pipefail
allow_published=false
if [[ "${1:-}" == --allow-published ]]; then
  allow_published=true
  shift
fi
if [[ $# -lt 2 || "$1" != v* ]]; then
  printf 'Usage: publish_draft_release.sh [--allow-published] vVERSION asset...\n' >&2
  exit 1
fi
release_tag="$1"
shift
for asset in "$@"; do
  test -f "$asset" || { printf 'Missing asset: %s\n' "$asset" >&2; exit 1; }
done
check_release_state() {
  if [[ "$1" != true && "$1" != false ]]; then
    printf 'Unexpected release state for %s\n' "$release_tag" >&2
    exit 1
  fi
  if [[ "$1" == false && "$allow_published" != true ]]; then
    printf 'Refusing to modify published release %s\n' "$release_tag" >&2
    exit 1
  fi
}
if draft="$(gh release view "$release_tag" --json isDraft --jq .isDraft)"; then
  check_release_state "$draft"
else
  flags=(--draft --verify-tag --generate-notes --title "$release_tag")
  if [[ "$release_tag" == *-* ]]; then flags+=(--prerelease); fi
  if ! gh release create "$release_tag" "${flags[@]}"; then
    draft="$(gh release view "$release_tag" --json isDraft --jq .isDraft)"
    check_release_state "$draft"
  fi
fi
gh release upload "$release_tag" --clobber "$@"
