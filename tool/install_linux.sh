#!/usr/bin/env bash
# Builds PageSage for Linux and installs it for the current user.
#
# This installs the current development build. Distributable archives are
# produced separately by tool/build_linux_release.sh. The bundle goes to a
# stable directory instead of staying in build/: the launcher entry must keep
# working after a `flutter clean` or a rebuild, and a debug bundle in build/
# does not.
#
# Usage: tool/install_linux.sh
set -euo pipefail

APP_ID="dev.pagesage.pagesage"
BIN_NAME="pagesage"
INSTALL_DIR="${HOME}/.local/opt/pagesage"
APPLICATIONS="${HOME}/.local/share/applications"
ICONS="${HOME}/.local/share/icons/hicolor"
FLUTTER="${FLUTTER:-flutter}"

cd "$(dirname "$0")/.."
repo_root="$(pwd)"

echo "==> Building release bundle"
"$FLUTTER" build linux --release

echo "==> Installing to ${INSTALL_DIR}"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a build/linux/x64/release/bundle/. "$INSTALL_DIR"/

echo "==> Installing icons"
for icon in linux/icons/*.png; do
  name="$(basename "$icon")"
  size="${name#"${APP_ID}"-}"
  size="${size%.png}"
  dest="${ICONS}/${size}x${size}/apps"
  mkdir -p "$dest"
  cp "$icon" "${dest}/${APP_ID}.png"
done
gtk-update-icon-cache -f -t "$ICONS" >/dev/null 2>&1 || true

echo "==> Writing launcher entry"
mkdir -p "$APPLICATIONS"
cat > "${APPLICATIONS}/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PageSage
GenericName=Reader
Comment=Local-first EPUB and PDF reader
Exec=${INSTALL_DIR}/${BIN_NAME} %U
Icon=${APP_ID}
Terminal=false
Categories=Office;Viewer;
Keywords=epub;pdf;reader;book;
StartupNotify=true
StartupWMClass=${APP_ID}
MimeType=application/epub+zip;application/pdf;
EOF
update-desktop-database "$APPLICATIONS" >/dev/null 2>&1 || true
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

echo "==> Done. PageSage is in the application menu; the library is unchanged."
echo "    Installed: ${INSTALL_DIR}/${BIN_NAME}"
echo "    Repo:      ${repo_root}"
