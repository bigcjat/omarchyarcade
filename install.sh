#!/usr/bin/env bash
# ==============================================================================
# Omarchy Arcade • Universal One-Command App Installer
# Supports Linux (x86_64 / ARM64 / Arch / Omarchy) and macOS (Apple Silicon / Intel).
# Installs only the application launcher. Zero git repository cloning.
# Usage:
#   curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[38;2;23;183;210m"
ORANGE="\033[38;2;225;107;39m"
PINK="\033[38;2;206;73;124m"
RESET="\033[0m"

OS_TYPE="$(uname -s)"

echo -e "${PINK}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PINK}║${RESET}  ${BOLD}${ORANGE}OMARCHY ARCADE${RESET} • Universal Application Installer          ${PINK}║${RESET}"
echo -e "${PINK}╚════════════════════════════════════════════════════════════╝${RESET}"

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/omarchy-arcade"
mkdir -p "$BIN_DIR" "$APP_DIR"

# 1. Install Launcher Application Files (Zero Git Cloning, No Games Bundled)
if [ -d "$PWD/launcher" ] && [ -f "$PWD/catalog.json" ]; then
    echo -e "${GREEN}==>${RESET} Installing launcher from local directory: ${BOLD}$PWD${RESET}"
    mkdir -p "$APP_DIR/launcher" "$APP_DIR/assets"
    cp "$PWD/catalog.json" "$APP_DIR/catalog.json"
    cp -r "$PWD/launcher/"* "$APP_DIR/launcher/"
    cp "$PWD/assets/omarchy_arcade_logo.svg" "$APP_DIR/assets/omarchy_arcade_logo.svg"
    if [ -d "$PWD/assets/covers" ]; then
        cp -r "$PWD/assets/covers" "$APP_DIR/assets/"
    fi
else
    echo -e "${GREEN}==>${RESET} Downloading Omarchy Arcade launcher payload..."
    mkdir -p "$APP_DIR/launcher" "$APP_DIR/assets"

    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/catalog.json" -o "$APP_DIR/catalog.json"
    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/omarchy_arcade_logo.svg" -o "$APP_DIR/assets/omarchy_arcade_logo.svg"
    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/splashscreen.png" -o "$APP_DIR/assets/splashscreen.png" 2>/dev/null || true

    for f in main.py main.qml FloppyCard.qml GameDetailSheet.qml SplashScreen.qml ViewFeatured.qml ViewCarousel.qml ViewDesktop.qml ViewSidebar.qml omarchy_arcade_logo.svg omarchy_arcade_text.svg; do
        curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/launcher/$f" -o "$APP_DIR/launcher/$f"
    done
fi

# 2. Resolve PySide6 & Qt6 Runtime (Zero Sudo Required)
PYTHON_BIN="python3"
if ! python3 -c "import PySide6" 2>/dev/null; then
    echo -e "${ORANGE}==>${RESET} PySide6 not detected in system Python."

    INSTALLED_VIA_PACMAN=0
    if [ "$OS_TYPE" = "Linux" ] && command -v pacman >/dev/null 2>&1; then
        if pacman -Si python-pyside6 >/dev/null 2>&1; then
            echo -e "${GREEN}==>${RESET} Found python-pyside6 in pacman. Installing..."
            sudo pacman -S --needed --noconfirm python-pyside6 qt6-declarative qt6-svg qt6-multimedia 2>/dev/null && INSTALLED_VIA_PACMAN=1 || true
        fi
    fi

    VENV_DIR="$APP_DIR/venv"
    if [ -x "$VENV_DIR/bin/python" ] && "$VENV_DIR/bin/python" -c "import PySide6" 2>/dev/null; then
        echo -e "${GREEN}==>${RESET} Using existing user runtime at: ${BOLD}$VENV_DIR${RESET}"
        PYTHON_BIN="$VENV_DIR/bin/python"
    elif [ "$INSTALLED_VIA_PACMAN" -eq 0 ]; then
        echo -e "${GREEN}==>${RESET} Setting up PySide6 runtime in user environment (no sudo needed)..."
        rm -rf "$VENV_DIR"
        if command -v python3 >/dev/null 2>&1 && python3 -m venv "$VENV_DIR" 2>/dev/null && [ -x "$VENV_DIR/bin/pip" ]; then
            "$VENV_DIR/bin/pip" install --quiet --upgrade pip 2>/dev/null || true
            "$VENV_DIR/bin/pip" install --quiet PySide6 2>/dev/null || {
                # In case pip fails (e.g. Python 3.14 without wheels)
                rm -rf "$VENV_DIR"
            }
        fi

        if [ ! -x "$VENV_DIR/bin/python" ]; then
            echo -e "${ORANGE}==>${RESET} Provisioning standalone runtime tool..."
            if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            UV_BIN="$(command -v uv 2>/dev/null || echo "$HOME/.local/bin/uv")"
            "$UV_BIN" venv --clear --python 3.12 --seed "$VENV_DIR"
            "$UV_BIN" pip install --python "$VENV_DIR/bin/python" PySide6
        fi
        PYTHON_BIN="$VENV_DIR/bin/python"
    fi
fi

# 3. Create ~/.local/bin/arcade Runner (With Self-Update Support)
cat << EOF > "$BIN_DIR/arcade"
#!/usr/bin/env bash
if [ "\$1" = "update" ]; then
    echo "==> Updating Omarchy Arcade..."
    curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash
    exit 0
fi

if [ -f "$APP_DIR/venv/bin/python" ]; then
    exec "$APP_DIR/venv/bin/python" "$APP_DIR/launcher/main.py" "\$@"
else
    exec python3 "$APP_DIR/launcher/main.py" "\$@"
fi
EOF
chmod +x "$BIN_DIR/arcade"
echo -e "${GREEN}==>${RESET} Created command: ${BOLD}$BIN_DIR/arcade${RESET}"

# 4. Platform-Specific Application Registration
if [ "$OS_TYPE" = "Darwin" ]; then
    # --- macOS Registration ---
    MAC_APP_DIR="$HOME/Applications/Omarchy Arcade.app"
    mkdir -p "$MAC_APP_DIR/Contents/MacOS" "$MAC_APP_DIR/Contents/Resources"

    cat << 'EOF' > "$MAC_APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Omarchy Arcade</string>
    <key>CFBundleExecutable</key>
    <string>Omarchy Arcade</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>org.omarchy.arcade</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

    cat << EOF > "$MAC_APP_DIR/Contents/MacOS/Omarchy Arcade"
#!/usr/bin/env bash
exec "$BIN_DIR/arcade" "\$@"
EOF
    chmod +x "$MAC_APP_DIR/Contents/MacOS/Omarchy Arcade"

    # Copy or download AppIcon.icns
    if [ -f "$PWD/packaging/macos/AppIcon.icns" ]; then
        cp "$PWD/packaging/macos/AppIcon.icns" "$MAC_APP_DIR/Contents/Resources/AppIcon.icns"
    else
        curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/packaging/macos/AppIcon.icns" -o "$MAC_APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    fi

    echo -e "${GREEN}==>${RESET} Registered macOS App: ${BOLD}$MAC_APP_DIR${RESET}"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}  ${BOLD}OMARCHY ARCADE INSTALLED ON MACOS!${RESET}                        ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}                                                            ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  🍎 Applications:  Open ${BOLD}Omarchy Arcade${RESET} via Spotlight / Finder ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  ⌨️ Terminal:      Type ${BOLD}arcade${RESET} (or ${BOLD}arcade update${RESET})           ${GREEN}║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

else
    # --- Linux / Omarchy Registration ---
    APPS_DIR="$HOME/.local/share/applications"
    ICONS_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
    mkdir -p "$APPS_DIR" "$ICONS_DIR"

    cp "$APP_DIR/assets/omarchy_arcade_logo.svg" "$ICONS_DIR/omarchy-arcade.svg" 2>/dev/null || true

    cat << EOF > "$APPS_DIR/omarchy-arcade.desktop"
[Desktop Entry]
Name=Omarchy Arcade
Comment=Master Game Suite & Offline Arcade
Exec=$BIN_DIR/arcade
Icon=omarchy-arcade
Terminal=false
Type=Application
Categories=Game;Arcade;
Keywords=arcade;game;omarchy;retro;floppy;
StartupNotify=true
EOF
    chmod +x "$APPS_DIR/omarchy-arcade.desktop"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" 2>/dev/null || true
    fi

    echo -e "${GREEN}==>${RESET} Desktop application registered."
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}  ${BOLD}LAUNCHER INSTALLED SUCCESSFULLY!${RESET}                          ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}                                                            ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  🎮 App Launcher:  Open ${BOLD}Omarchy Arcade${RESET} via Super / App Menu  ${GREEN}║${RESET}"
    echo -e "${GREEN}║${RESET}  ⌨️ Terminal:      Type ${BOLD}arcade${RESET} (or ${BOLD}arcade update${RESET})           ${GREEN}║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
fi
