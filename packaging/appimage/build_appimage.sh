#!/usr/bin/env bash
# ==============================================================================
# Script to assemble and build Omarchy_Arcade-x86_64.AppImage
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/appimage"
APPDIR="$BUILD_DIR/AppDir"

echo "==> Preparing AppDir at $APPDIR..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/omarchy-arcade"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"

# 1. Copy Application payload
echo "==> Copying application payload..."
cp -r "$ROOT_DIR/assets" "$ROOT_DIR/catalog.json" "$ROOT_DIR/games" "$ROOT_DIR/launcher" "$APPDIR/usr/share/omarchy-arcade/"

# 2. Copy AppRun, Desktop entry, and Icons
cp "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

cp "$SCRIPT_DIR/omarchy-arcade.desktop" "$APPDIR/omarchy-arcade.desktop"
cp "$SCRIPT_DIR/omarchy-arcade.desktop" "$APPDIR/usr/share/applications/omarchy-arcade.desktop"

cp "$ROOT_DIR/assets/omarchy_arcade_logo.svg" "$APPDIR/omarchy-arcade.svg"
cp "$ROOT_DIR/assets/omarchy_arcade_logo.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/omarchy-arcade.svg"

# 3. Check for appimagetool
if ! command -v appimagetool >/dev/null 2>&1; then
    echo "==> appimagetool not found. Downloading standalone appimagetool..."
    TOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    curl -sSL -o "$BUILD_DIR/appimagetool" "$TOOL_URL"
    chmod +x "$BUILD_DIR/appimagetool"
    APPIMAGETOOL="$BUILD_DIR/appimagetool"
else
    APPIMAGETOOL="appimagetool"
fi

# 4. Generate AppImage
echo "==> Generating Omarchy_Arcade-x86_64.AppImage..."
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$ROOT_DIR/Omarchy_Arcade-x86_64.AppImage"

echo "==> AppImage created successfully: $ROOT_DIR/Omarchy_Arcade-x86_64.AppImage"
