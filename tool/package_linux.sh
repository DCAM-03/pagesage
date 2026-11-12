#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
bundle="$repo_root/build/linux/x64/release/bundle"
output_dir="$repo_root/dist"
version="$(awk '/^version:/ { print $2; exit }' "$repo_root/pubspec.yaml")"

fail() {
  printf 'Packaging failed: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle|--output-dir|--version)
      [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for $1"
      case "$1" in
        --bundle) bundle="$2" ;;
        --output-dir) output_dir="$2" ;;
        --version) version="$2" ;;
      esac
      shift 2
      ;;
    --help)
      printf 'Usage: bash tool/package_linux.sh [--bundle DIR] [--output-dir DIR] [--version VERSION]\n'
      exit 0
      ;;
    *) fail "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || fail "A Linux host is required"
[[ "$(uname -m)" == x86_64 ]] || fail "Only Linux x86_64 packages are supported"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?(\+[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]] ||
  fail "Invalid version: $version"
[[ -d "$bundle" ]] || fail "Release bundle not found: $bundle"
bundle="$(cd -- "$bundle" && pwd -P)"

for required in pagesage lib/libapp.so lib/libflutter_linux_gtk.so data/icudtl.dat data/flutter_assets/NOTICES.Z; do
  [[ -s "$bundle/$required" ]] || fail "Incomplete release bundle: $required"
done
[[ -x "$bundle/pagesage" ]] || fail "pagesage is not executable"
[[ -s "$bundle/data/icons/dev.pagesage.pagesage-256.png" ]] ||
  fail "Application icon is missing"

[[ -n "$(find "$bundle/lib" -type f -name '*sqlite3*.so' -print -quit)" ]] ||
  fail "Bundled SQLite native asset is missing; rebuild with the current pubspec"

mkdir -p -- "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd -P)"
[[ "$output_dir" != "$bundle" && "$output_dir" != "$bundle/"* ]] ||
  fail "Output directory must be outside the release bundle"

source_epoch="${SOURCE_DATE_EPOCH:-$(git -C "$repo_root" log -1 --format=%ct)}"
[[ "$source_epoch" =~ ^[0-9]+$ ]] || fail "SOURCE_DATE_EPOCH must be an integer"
source_revision="$(git -C "$repo_root" rev-parse HEAD)"
source_dirty=false
if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
  source_dirty=true
fi

staging="$(mktemp -d "${TMPDIR:-/tmp}/pagesage-package.XXXXXX")"
archive_temp=""
checksum_temp=""
cleanup() {
  rm -rf -- "$staging"
  [[ -z "$archive_temp" ]] || rm -f -- "$archive_temp"
  [[ -z "$checksum_temp" ]] || rm -f -- "$checksum_temp"
}
trap cleanup EXIT

package_name="pagesage-${version}-linux-x86_64"
package_dir="$staging/$package_name"
mkdir -p -- "$package_dir"
cp -a -- "$bundle/." "$package_dir/"
cp -- "$repo_root/tool/linux_launcher.sh" "$package_dir/run-pagesage"
cp -- "$repo_root/tool/linux_bundle_install.sh" "$package_dir/install.sh"
cp -- "$repo_root/docs/linux-distribution.md" "$package_dir/README.md"
cp -- "$repo_root/docs/privacy.md" "$package_dir/PRIVACY.md"
cp -- "$repo_root/docs/generated/third-party-licenses.md" "$package_dir/THIRD_PARTY_LICENSES.md"
cp -- "$repo_root/LICENSE" "$repo_root/NOTICE" "$package_dir/"
mkdir -p -- "$package_dir/LICENSES"
cp -- "$repo_root/assets/fonts/licenses/"*.txt "$package_dir/LICENSES/"
cp -- "$repo_root/assets/licenses/archive-LICENSE-other.txt" "$package_dir/LICENSES/"
chmod +x "$package_dir/run-pagesage" "$package_dir/install.sh"
printf 'version=%s\narchitecture=x86_64\nsource_revision=%s\nsource_dirty=%s\nbuild_libc=%s\n' \
  "$version" "$source_revision" "$source_dirty" "$(getconf GNU_LIBC_VERSION)" \
  > "$package_dir/BUILD_INFO.txt"

archive="$output_dir/$package_name.tar.gz"
archive_temp="$(mktemp "$output_dir/.pagesage-archive.XXXXXX")"
tar --sort=name --mtime="@$source_epoch" --owner=0 --group=0 --numeric-owner \
  -C "$staging" -cf - "$package_name" | gzip -n > "$archive_temp"
archive_hash="$(sha256sum "$archive_temp" | cut -d ' ' -f 1)"
checksum_temp="$(mktemp "$output_dir/.pagesage-checksum.XXXXXX")"
printf '%s  %s\n' "$archive_hash" "$package_name.tar.gz" > "$checksum_temp"
mv -f -- "$archive_temp" "$archive"
archive_temp=""
mv -f -- "$checksum_temp" "$output_dir/$package_name.tar.gz.sha256"
checksum_temp=""
printf 'Package: %s\nChecksum: %s.sha256\n' "$archive" "$archive"
