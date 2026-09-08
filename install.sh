#!/usr/bin/env bash
# ==============================================================================
# Omarchy Arcade • Universal One-Command App Installer
# Supports x86_64 and ARM64 (aarch64 / Arch Linux ARM).
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

echo -e "${PINK}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PINK}║${RESET}  ${BOLD}${ORANGE}OMARCHY ARCADE${RESET} • Application Installer                    ${PINK}║${RESET}"
echo -e "${PINK}╚════════════════════════════════════════════════════════════╝${RESET}"

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
APP_DIR="$HOME/.local/share/omarchy-arcade"
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICONS_DIR" "$APP_DIR"

# 1. Install Launcher Application Files (Zero Git Cloning, No Games Bundled)
if [ -d "$PWD/launcher" ] && [ -f "$PWD/catalog.json" ]; then
    echo -e "${GREEN}==>${RESET} Installing launcher from local directory: ${BOLD}$PWD${RESET}"
    mkdir -p "$APP_DIR/launcher" "$APP_DIR/assets"
    cp "$PWD/catalog.json" "$APP_DIR/catalog.json"
    cp -r "$PWD/launcher/"* "$APP_DIR/launcher/"
    cp "$PWD/assets/omarchy_arcade_logo.svg" "$ICONS_DIR/omarchy-arcade.svg"
    cp "$PWD/assets/omarchy_arcade_logo.svg" "$APP_DIR/assets/omarchy_arcade_logo.svg"
    if [ -d "$PWD/assets/covers" ]; then
        cp -r "$PWD/assets/covers" "$APP_DIR/assets/"
    fi
else
    echo -e "${GREEN}==>${RESET} Downloading Omarchy Arcade launcher payload..."
    mkdir -p "$APP_DIR/launcher" "$APP_DIR/assets"

    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/catalog.json" -o "$APP_DIR/catalog.json"
    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/omarchy_arcade_logo.svg" -o "$ICONS_DIR/omarchy-arcade.svg"
    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/omarchy_arcade_logo.svg" -o "$APP_DIR/assets/omarchy_arcade_logo.svg"
    curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/splashscreen.png" -o "$APP_DIR/assets/splashscreen.png" 2>/dev/null || true

    for f in main.py main.qml FloppyCard.qml GameDetailSheet.qml SplashScreen.qml ViewCarousel.qml ViewDesktop.qml ViewSidebar.qml omarchy_arcade_logo.svg omarchy_arcade_text.svg; do
        curl -sSL "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/launcher/$f" -o "$APP_DIR/launcher/$f"
    done
fi

# 2. Resolve PySide6 & Qt6 Runtime (Zero Sudo Required)
PYTHON_BIN="python3"
if ! python3 -c "import PySide6" 2>/dev/null; then
    echo -e "${ORANGE}==>${RESET} PySide6 not detected in system Python."
    # Attempt pacman install if available
    INSTALLED_VIA_PACMAN=0
    if command -v pacman >/dev/null 2>&1; then
        if pacman -Si python-pyside6 >/dev/null 2>&1; then
            echo -e "${GREEN}==>${RESET} Found python-pyside6 in pacman. Installing..."
            sudo pacman -S --needed --noconfirm python-pyside6 qt6-declarative qt6-imageformats 2>/dev/null && INSTALLED_VIA_PACMAN=1 || true
        fi
    fi

    # If pacman did not provide PySide6 (e.g. on Arch ARM / aarch64), use user venv
    if [ "$INSTALLED_VIA_PACMAN" -eq 0 ] && ! python3 -c "import PySide6" 2>/dev/null; then
        echo -e "${GREEN}==>${RESET} Installing PySide6 wheel into user environment (no sudo needed)..."
        VENV_DIR="$APP_DIR/venv"
        if [ ! -d "$VENV_DIR" ]; then
            python3 -m venv "$VENV_DIR"
        fi
        "$VENV_DIR/bin/pip" install --quiet --upgrade pip
        "$VENV_DIR/bin/pip" install --quiet PySide6
        PYTHON_BIN="$VENV_DIR/bin/python"
    fi
fi

# 3. Create ~/.local/bin/arcade Runner
cat << EOF > "$BIN_DIR/arcade"
#!/usr/bin/env bash
if [ -f "$APP_DIR/venv/bin/python" ]; then
    exec "$APP_DIR/venv/bin/python" "$APP_DIR/launcher/main.py" "\$@"
else
    exec python3 "$APP_DIR/launcher/main.py" "\$@"
fi
EOF
chmod +x "$BIN_DIR/arcade"
echo -e "${GREEN}==>${RESET} Created command: ${BOLD}$BIN_DIR/arcade${RESET}"

# 4. Register Desktop Menu Entry
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

# 5. Configure Hyprland Rules & Shortcut (Super + G)
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ]; then
    if ! grep -q "omarchy-arcade" "$HYPR_CONF" && ! grep -q "exec, arcade" "$HYPR_CONF"; then
        cat << 'EOF' >> "$HYPR_CONF"

# --- Omarchy Arcade Window Rule & Keybind ---
windowrulev2 = float, title:^(Omarchy Arcade)$
windowrulev2 = size 1080 740, title:^(Omarchy Arcade)$
windowrulev2 = center, title:^(Omarchy Arcade)$
bind = $mainMod, G, exec, arcade
EOF
        echo -e "${GREEN}==>${RESET} Hyprland configuration updated."
    fi
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET}  ${BOLD}LAUNCHER INSTALLED SUCCESSFULLY!${RESET}                          ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}                                                            ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  🎮 App Launcher:  Open ${BOLD}Omarchy Arcade${RESET} in menu             ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  ⌨️ Terminal:      Type ${BOLD}arcade${RESET}                              ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  ⚡ In Hyprland:   Press ${BOLD}Super + G${RESET}                           ${GREEN}║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""
