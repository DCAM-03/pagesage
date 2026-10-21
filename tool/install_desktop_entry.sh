#!/usr/bin/env bash
# Installs the Linux desktop entry and icons for the current user.
#
# Without this, the app runs but the shell has nothing to identify it by:
# under Wayland there is no window icon property to read, and the binary path
# is not an icon name, so the taskbar shows the icon theme's generic fallback.
# The entry and the hicolor files are what close that gap.
#
#   ./tool/install_desktop_entry.sh              # from the built bundle
#   ./tool/install_desktop_entry.sh --uninstall
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="dev.pagesage.pagesage"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_ROOT="$DATA_HOME/icons/hicolor"
ENTRY="$DATA_HOME/applications/$APP_ID.desktop"
BUNDLE="$ROOT/build/linux/x64/debug/bundle"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$ENTRY"
  for size in 16 24 32 48 64 128 256 512; do
    rm -f "$ICON_ROOT/${size}x${size}/apps/$APP_ID.png"
  done
  command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_HOME/applications" || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
  echo "removed $ENTRY and its icons"
  exit 0
fi

ICONS_SRC=""
if [[ -d "$BUNDLE/data/icons" ]]; then
  ICONS_SRC="$BUNDLE/data/icons"
else
  ICONS_SRC="$ROOT/linux/icons"
fi

if [[ ! -d "$ICONS_SRC" ]]; then
  echo "no icons at $ICONS_SRC — run python3 tool/generate_app_icons.py first" >&2
  exit 1
fi

mkdir -p "$DATA_HOME/applications"
for size in 16 24 32 48 64 128 256 512; do
  src="$ICONS_SRC/$APP_ID-$size.png"
  [[ -f "$src" ]] || continue
  dst="$ICON_ROOT/${size}x${size}/apps"
  mkdir -p "$dst"
  cp "$src" "$dst/$APP_ID.png"
done

# The Exec line points at the binary that is actually on this machine, so a
# debug bundle and a release bundle can each install without fighting.
EXEC=""
for candidate in "$ROOT/build/linux/x64/release/bundle/pagesage" \
                 "$ROOT/build/linux/x64/debug/bundle/pagesage"; do
  [[ -x "$candidate" ]] && EXEC="$candidate" && break
done
[[ -n "$EXEC" ]] || EXEC="pagesage"

sed "s|^Exec=.*|Exec=$EXEC %U|" "$ROOT/linux/$APP_ID.desktop" > "$ENTRY"
chmod 644 "$ENTRY"

command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_HOME/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true

echo "installed $ENTRY"
echo "icons -> $ICON_ROOT/*/apps/$APP_ID.png"
echo "exec   -> $EXEC"
