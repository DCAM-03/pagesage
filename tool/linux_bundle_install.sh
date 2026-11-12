#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
install_prefix="${HOME}/.local/opt/pagesage"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
app_id="dev.pagesage.pagesage"

fail() {
  printf 'Installation failed: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      [[ $# -ge 2 && -n "$2" ]] || fail "Missing value for --prefix"
      install_prefix="$2"
      shift 2
      ;;
    --help)
      printf 'Usage: bash install.sh [--prefix ABSOLUTE_DIRECTORY]\n'
      exit 0
      ;;
    *) fail "Unknown option: $1" ;;
  esac
done

[[ "$install_prefix" == /* && "$data_home" == /* ]] || fail "Absolute paths are required"
[[ "$install_prefix" != *$'\n'* && "$data_home" != *$'\n'* ]] || fail "Paths must not contain newlines"
install_prefix="$(realpath -ms -- "$install_prefix")"
[[ ! -L "$install_prefix" ]] || fail "The install target must not be a symbolic link"
install_prefix="$(realpath -m -- "$install_prefix")"
home_dir="$(realpath -m -- "$HOME")"
[[ "$install_prefix" != / && "$install_prefix" != "$home_dir" &&
   "$install_prefix" != "$home_dir/.local" && "$install_prefix" != "$home_dir/.local/opt" ]] ||
  fail "Refusing to replace a user or system root directory"
[[ "$bundle_dir" != "$install_prefix" && "$bundle_dir" != "$install_prefix/"* ]] ||
  fail "The install target must not contain the source bundle"
[[ ! -e "$install_prefix" || -d "$install_prefix" ]] || fail "The install target is not a directory"
if [[ -d "$install_prefix" && -n "$(find "$install_prefix" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  [[ -x "$install_prefix/pagesage" && -d "$install_prefix/data/flutter_assets" ]] ||
    fail "Refusing to replace a directory that is not a PageSage installation"
fi

for required in pagesage run-pagesage lib/libapp.so lib/libflutter_linux_gtk.so data/icudtl.dat data/flutter_assets/NOTICES.Z; do
  [[ -s "$bundle_dir/$required" ]] || fail "Incomplete package: $required"
done
[[ -n "$(find "$bundle_dir/lib" -type f -name '*sqlite3*.so' -print -quit)" ]] ||
  fail "Bundled SQLite native asset is missing"
[[ -x "$bundle_dir/pagesage" && -x "$bundle_dir/run-pagesage" ]] || fail "Package executables are not executable"
[[ -s "$bundle_dir/data/icons/$app_id-256.png" ]] || fail "Application icon is missing"

applications_dir="$data_home/applications"
icons_dir="$data_home/icons/hicolor"
desktop_file="$applications_dir/$app_id.desktop"
[[ ! -d "$desktop_file" ]] || fail "The desktop entry target is a directory"
mkdir -p -- "$(dirname -- "$install_prefix")" "$applications_dir" "$icons_dir"

staging="$(mktemp -d "$(dirname -- "$install_prefix")/.pagesage-install.XXXXXX")"
desktop_temp=""
backup_dir=""
previous_moved=false
new_installed=false
install_complete=false
cleanup() {
  local status=$?
  if [[ "$install_complete" != true ]]; then
    if [[ "$new_installed" == true ]]; then
      rm -rf -- "$install_prefix"
    fi
    if [[ "$previous_moved" == true ]]; then
      if ! mv -- "$backup_dir/bundle" "$install_prefix"; then
        printf 'Previous installation is preserved at %s/bundle\n' "$backup_dir" >&2
        backup_dir=""
      fi
    fi
  fi
  rm -rf -- "$staging"
  [[ -z "$desktop_temp" ]] || rm -f -- "$desktop_temp"
  [[ -z "$backup_dir" ]] || rm -rf -- "$backup_dir"
  return "$status"
}
trap cleanup EXIT

cp -a -- "$bundle_dir/." "$staging/"
desktop_temp="$(mktemp "$applications_dir/.pagesage-desktop.XXXXXX")"
exec_path="$install_prefix/run-pagesage"
exec_path="${exec_path//\\/\\\\}"
exec_path="${exec_path//\"/\\\"}"
exec_path="${exec_path//\`/\\\`}"
exec_path="${exec_path//\$/\\\$}"
exec_path="${exec_path//%/%%}"
{
  printf '[Desktop Entry]\nType=Application\nName=PageSage\nGenericName=Reader\n'
  printf 'Comment=Local-first EPUB, PDF and Markdown reader\n'
  printf 'Exec="%s" %%U\n' "$exec_path"
  printf 'Icon=%s\nTerminal=false\nCategories=Office;Viewer;\n' "$app_id"
  printf 'Keywords=epub;pdf;markdown;reader;book;\nStartupNotify=true\n'
  printf 'StartupWMClass=%s\nMimeType=application/epub+zip;application/pdf;\n' "$app_id"
} > "$desktop_temp"
chmod 644 "$desktop_temp"

if [[ -d "$install_prefix" ]]; then
  backup_dir="$(mktemp -d "$(dirname -- "$install_prefix")/.pagesage-previous.XXXXXX")"
  mv -- "$install_prefix" "$backup_dir/bundle"
  previous_moved=true
fi
mv -- "$staging" "$install_prefix"
new_installed=true

for icon in "$install_prefix/data/icons/$app_id-"*.png; do
  icon_name="$(basename -- "$icon")"
  size="${icon_name#"$app_id-"}"
  size="${size%.png}"
  [[ "$size" =~ ^[0-9]+$ ]] || fail "Invalid icon size: $size"
  mkdir -p -- "$icons_dir/${size}x${size}/apps"
  cp -- "$icon" "$icons_dir/${size}x${size}/apps/$app_id.png"
done
mv -f -- "$desktop_temp" "$desktop_file"
desktop_temp=""
install_complete=true

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$icons_dir" >/dev/null 2>&1 || true
fi
printf 'Installed: %s\nDesktop entry: %s\nNo application process was started or stopped.\n' \
  "$install_prefix" "$desktop_file"
