#!/usr/bin/env bash
# ==============================================================================
# Omarchy Arcade • One-Command Automated Installer for Omarchy Linux (Hyprland)
# Usage:
#   curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash
#   - OR -
#   ./install.sh
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[38;2;23;183;210m"
ORANGE="\033[38;2;225;107;39m"
PINK="\033[38;2;206;73;124m"
RESET="\033[0m"

echo -e "${PINK}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PINK}║${RESET}  ${BOLD}${ORANGE}OMARCHY ARCADE${RESET} • Automated Linux Installer               ${PINK}║${RESET}"
echo -e "${PINK}╚════════════════════════════════════════════════════════════╝${RESET}"

# 1. Determine Repository Directory
if [ -d "$PWD/launcher" ] && [ -f "$PWD/catalog.json" ]; then
    INSTALL_DIR="$PWD"
    echo -e "${GREEN}==>${RESET} Installing from current directory: ${BOLD}$INSTALL_DIR${RESET}"
else
    INSTALL_DIR="$HOME/.local/share/omarchyarcade"
    echo -e "${GREEN}==>${RESET} Setting up arcade at: ${BOLD}$INSTALL_DIR${RESET}"
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo -e "${GREEN}==>${RESET} Updating existing repository..."
        git -C "$INSTALL_DIR" pull --ff-only
    else
        echo -e "${GREEN}==>${RESET} Cloning repository..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone https://github.com/bigcjat/omarchyarcade.git "$INSTALL_DIR"
    fi
fi

# 2. Ensure Dependencies via Pacman
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
        echo -e "${GREEN}==>${RESET} All system packages are installed."
    fi
fi

# 3. Install CLI Binary into ~/.local/bin/arcade
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/arcade" "$BIN_DIR/arcade"
chmod +x "$INSTALL_DIR/arcade"
echo -e "${GREEN}==>${RESET} Symlinked command: ${BOLD}$BIN_DIR/arcade${RESET}"

# 4. Install Desktop Application Entry (Rofi / Walker / Fuzzel)
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"
cat << EOF > "$APPS_DIR/omarchy-arcade.desktop"
[Desktop Entry]
Name=Omarchy Arcade
Comment=Master Game Suite & Offline Arcade
Exec=$BIN_DIR/arcade
Icon=$INSTALL_DIR/assets/omarchy_arcade_logo.svg
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

# 5. Configure Hyprland Shortcut (Super + G) & Window Rules
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
    else
        echo -e "${GREEN}==>${RESET} Hyprland configuration already has arcade rules."
    fi
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET}  ${BOLD}INSTALLATION COMPLETE!${RESET}                                    ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}                                                            ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  🎮 From Application Menu: Open ${BOLD}Omarchy Arcade${RESET}              ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  ⌨️ From Terminal:         Type ${BOLD}arcade${RESET}                      ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET}  ⚡ In Hyprland:           Press ${BOLD}Super + G${RESET}                   ${GREEN}║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""
