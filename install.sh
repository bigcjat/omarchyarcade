#!/usr/bin/env bash
# ==============================================================================
# Omarchy Arcade • One-Command App Installer for Omarchy Linux (Hyprland)
# Installs only the application launcher and its assets. Zero git repository cloning.
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
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICONS_DIR"

# 1. Install Launcher Binary (Zero Git Cloning)
if [ -d "$PWD/launcher" ] && [ -f "$PWD/arcade" ]; then
    # Local installation from existing directory
    echo -e "${GREEN}==>${RESET} Installing launcher from local directory: ${BOLD}$PWD${RESET}"
    ln -sf "$PWD/arcade" "$BIN_DIR/arcade"
    chmod +x "$BIN_DIR/arcade"
    cp "$PWD/assets/omarchy_arcade_logo.svg" "$ICONS_DIR/omarchy-arcade.svg"
else
    # Remote installation: Fetch standalone launcher without cloning git repository
    echo -e "${GREEN}==>${RESET} Downloading Omarchy Arcade launcher..."
    RELEASE_URL="https://github.com/bigcjat/omarchyarcade/releases/latest/download/Omarchy_Arcade-x86_64.AppImage"
    
    # Try downloading prebuilt standalone AppImage
    if curl -sSL -f -o "$BIN_DIR/arcade" "$RELEASE_URL" 2>/dev/null; then
        chmod +x "$BIN_DIR/arcade"
        echo -e "${GREEN}==>${RESET} Standalone launcher binary installed to ${BOLD}$BIN_DIR/arcade${RESET}"
    else
        # Fallback: Download and extract pure application payload (NO git clone)
        echo -e "${ORANGE}==>${RESET} Downloading application bundle..."
        APP_DIR="$HOME/.local/share/omarchy-arcade"
        mkdir -p "$APP_DIR"
        
        TEMP_TAR=$(mktemp)
        curl -sSL -o "$TEMP_TAR" "https://github.com/bigcjat/omarchyarcade/archive/refs/heads/main.tar.gz"
        tar -xz --strip-components=1 -C "$APP_DIR" -f "$TEMP_TAR"
        rm -f "$TEMP_TAR"
        
        # Clean up any non-app repository files
        rm -rf "$APP_DIR/.git" "$APP_DIR/.github" "$APP_DIR/scratch" "$APP_DIR/template" "$APP_DIR/tests"
        
        ln -sf "$APP_DIR/arcade" "$BIN_DIR/arcade"
        chmod +x "$APP_DIR/arcade"
        echo -e "${GREEN}==>${RESET} Launcher installed to ${BOLD}$APP_DIR${RESET}"
    fi

    # Install Application Icon
    curl -sSL -f -o "$ICONS_DIR/omarchy-arcade.svg" \
        "https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/assets/omarchy_arcade_logo.svg" 2>/dev/null || true
fi

# 2. Check System Runtime Dependencies via Pacman
if command -v pacman >/dev/null 2>&1; then
    echo -e "${GREEN}==>${RESET} Checking system dependencies (python, python-pyside6, qt6-declarative)..."
    MISSING_PKGS=()
    for pkg in python python-pyside6 qt6-declarative; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo -e "${ORANGE}==>${RESET} Installing missing dependencies: ${MISSING_PKGS[*]}"
        sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
    else
        echo -e "${GREEN}==>${RESET} System packages verified."
    fi
fi

# 3. Register Desktop Menu Entry (Rofi / Walker / Fuzzel)
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
echo -e "${GREEN}==>${RESET} Desktop application entry registered."

# 4. Configure Hyprland Window Rules & Shortcut (Super + G)
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ]; then
    if ! grep -q "omarchy-arcade" "$HYPR_CONF" && ! grep -q "exec, arcade" "$HYPR_CONF"; then
        echo -e "${GREEN}==>${RESET} Adding floating window rules and Super + G shortcut to hyprland.conf..."
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
