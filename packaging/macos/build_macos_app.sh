#!/usr/bin/env bash
# ==============================================================================
# Omarchy Arcade • macOS Application Bundle & DMG Assembler
# Generates a standalone "Omarchy Arcade.app" and "Omarchy_Arcade-macOS.dmg"
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/macos"
APP_DIR="$BUILD_DIR/Omarchy Arcade.app"
DMG_ROOT="$BUILD_DIR/dmg_root"
DMG_OUTPUT="$ROOT_DIR/Omarchy_Arcade-macOS.dmg"

echo "==> Assembling Omarchy Arcade.app at $APP_DIR..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/assets"
mkdir -p "$APP_DIR/Contents/Resources/launcher"

# 1. Bundle Metadata & Icons
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# 2. Copy Application Payload (Launcher, catalog, assets)
echo "==> Copying launcher payload..."
cp "$ROOT_DIR/catalog.json" "$APP_DIR/Contents/Resources/catalog.json"
cp -r "$ROOT_DIR/launcher/"* "$APP_DIR/Contents/Resources/launcher/"
cp -r "$ROOT_DIR/assets/"* "$APP_DIR/Contents/Resources/assets/"

# 3. Create macOS Executable Runner
cat << 'EOF' > "$APP_DIR/Contents/MacOS/Omarchy Arcade"
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export OMARCHY_ARCADE_BUNDLE="1"

# 1. Embedded venv inside app bundle
if [ -x "$DIR/Resources/venv/bin/python3" ]; then
    PYTHON_EXEC="$DIR/Resources/venv/bin/python3"
# 2. User application venv (~/.local/share/omarchy-arcade/venv)
elif [ -x "$HOME/.local/share/omarchy-arcade/venv/bin/python" ]; then
    PYTHON_EXEC="$HOME/.local/share/omarchy-arcade/venv/bin/python"
# 3. Active virtualenv or system Python with PySide6
elif python3 -c "import PySide6" 2>/dev/null; then
    PYTHON_EXEC="python3"
else
    # Automatically provision PySide6 into user environment if missing
    USER_VENV="$HOME/.local/share/omarchy-arcade/venv"
    mkdir -p "$HOME/.local/share/omarchy-arcade"
    if python3 -m venv "$USER_VENV" 2>/dev/null; then
        "$USER_VENV/bin/pip" install --quiet --upgrade pip
        "$USER_VENV/bin/pip" install --quiet PySide6
        PYTHON_EXEC="$USER_VENV/bin/python"
    else
        osascript -e 'display dialog "Omarchy Arcade requires Python 3 with PySide6.\n\nPlease install via curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash" buttons {"OK"} default button "OK" with icon caution'
        exit 1
    fi
fi

exec "$PYTHON_EXEC" "$DIR/Resources/launcher/main.py" "$@"
EOF

chmod +x "$APP_DIR/Contents/MacOS/Omarchy Arcade"

# 4. Optional: Bundle venv if requested or in CI
if [ "$1" = "--bundle-venv" ] && [ -d "$ROOT_DIR/.venv" ]; then
    echo "==> Bundling portable Python virtual environment..."
    mkdir -p "$APP_DIR/Contents/Resources/venv"
    cp -R "$ROOT_DIR/.venv/"* "$APP_DIR/Contents/Resources/venv/"
fi

# 5. Assemble DMG Disk Image
echo "==> Preparing DMG staging root at $DMG_ROOT..."
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "==> Building DMG: $DMG_OUTPUT..."
rm -f "$DMG_OUTPUT"
hdiutil create -volname "Omarchy Arcade" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_OUTPUT"

echo "==> macOS build complete!"
echo "    App Bundle: $APP_DIR"
echo "    DMG File:   $DMG_OUTPUT"
