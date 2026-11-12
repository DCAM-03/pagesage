#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

if [[ "${1:-}" == "--help" ]]; then
  printf 'Usage: bash tool/build_linux_release.sh [package_linux.sh options]\n'
  exit 0
fi

flutter_command="${FLUTTER:-flutter}"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-4}"

"$flutter_command" pub get --enforce-lockfile
"$flutter_command" build linux --release --no-pub
bash "$repo_root/tool/package_linux.sh" "$@"
