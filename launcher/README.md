# Omarchy Arcade Launcher

<p align="center">
  <img src="omarchy_arcade_logo.svg" alt="Omarchy Arcade Logo" width="360"/>
</p>

A sleek, keyboard-primary native desktop arcade launcher designed specifically for **Omarchy Linux** (Hyprland). Built with **Qt6 Quick / QML** and **PySide6**, the launcher presents your offline arcade catalog as tactile retro 3.5" floppy disks that synchronize in real time with your active system desktop theme.

---

## Key Features

### 1. Retro 3.5" Floppy Disk Aesthetic
* **Physical Disk Details:** Authentic 3.5" floppy body styling complete with top-right write-protect beveled notch, metal shutter slider, drive alignment arrows, and Sega Master System procedural grid headers.
* **Illustrated Painted Box Art:** Displays rich, high-resolution illustrated box art capturing the spirit of each arcade classic, with instant procedural vector badge fallbacks.
* **Selection Halo:** Highlighted disks elevate with a neon cyan selection ring and subtle scaling so the active game is immediately obvious across all display scales and themes.

### 2. Keyboard-Primary Navigation
Built for power users and tiling window manager workflows:
* **Grid Navigation:** Arrow keys (`←`, `↑`, `→`, `↓`) or Vim keys (`H`, `J`, `K`, `L`).
* **Instant Category Jumps:** Numbers `1` through `9` switch categories immediately.
* **Category Cycling:** Bracket keys (`[` / `]`) or `Tab` / `Shift+Tab`.
* **Search & Filter:** Press `/` or `Ctrl+F` to type-filter games instantly. Press `Escape` to dismiss search and return directly to grid browsing. Press `Enter` or `↓` to jump straight to the filtered games.
* **Launch / Modal:** Press `Enter` or `Space` on any disk to inspect the detail sheet, and press `Enter` again to play.
* **Dismiss / Back:** `Escape`, `Q`, or `Backspace` closes any open modal.

### 3. Live Omarchy System Theme Synchronization
* Automatically reads `~/.config/omarchy/current/theme/colors.toml` via `QFileSystemWatcher`.
* When you switch desktop themes (`Super + Space`), the launcher updates its background, surfaces, borders, text, and accent colors on the fly without restarting.

### 4. Hide-on-Launch Process Management
* When a game launches, the launcher hides itself immediately to keep your Hyprland workspace uncluttered.
* A non-blocking thread monitors the running game process. The moment the game exits, the launcher automatically restores itself to view and reclaims active keyboard focus.

### 5. Steam-Style Presentation Modal
* **Gameplay Previews:** Displays high-resolution screenshots of actual gameplay.
* **Install Size Badges:** Shows verified local file footprints (`💾 438 KB Install`) alongside category and reference tags.
* **Instructions & Controls:** Displays complete how-to-play guidance and keyboard mappings with natural scrolling that never clips buttons off-screen.

### 6. Vintage Console Startup Sequence
* Snappy startup animation featuring CRT scanlines, retro horizontal color stripes, diagonal glint sheen, and an authentic console prompt (skips instantly on any key or click).

---

## Quick Start

### Running via Root Helper
```bash
# Run from repository root:
./arcade

# Skip startup console intro:
./arcade --no-splash
```

### Running with Python Directly
```bash
python launcher/main.py

# Launch directly into a specific Omarchy theme palette:
python launcher/main.py --theme tokyonight
python launcher/main.py --theme catppuccin
python launcher/main.py --theme gruvbox
```

---

## Architecture & Components

```
launcher/
├── main.py                  # PySide6 runtime, theme file watcher, and game process monitor
├── main.qml                 # Main window, header bar, category selector, grid, and shortcuts
├── FloppyCard.qml           # 3.5" floppy disk component, art loader, and focus glow
├── GameDetailSheet.qml      # Full presentation sheet with gameplay preview and size badge
├── SplashScreen.qml         # Vintage console startup sequence
├── omarchy_arcade_logo.svg  # Transparent retro 5-stripe brand emblem
└── omarchy_arcade_text.svg  # Vector lettering source path
```

* **`ArcadeBackend` ([main.py](main.py)):** Exposes Qt slots to QML for reading `catalog.json`, resolving screenshot URLs, tracking child process lifetimes via thread-safe Qt signals, and live-watching the active theme file.
* **`ApplicationWindow` ([main.qml](main.qml)):** Manages keyboard focus routing (`keyboardController`), responsive toolbar emoji collapsing, and search filtering.

---

## Desktop Environment Integration

### Application Menu Entry (Rofi / Walker / Fuzzel)

Create `~/.local/share/applications/omarchy-arcade.desktop`:

```ini
[Desktop Entry]
Name=Omarchy Arcade
Comment=Master Game Suite & Offline Arcade
Exec=/home/%USER%/omarchyarcade/arcade
Icon=/home/%USER%/omarchyarcade/assets/omarchy_arcade_logo.svg
Terminal=false
Type=Application
Categories=Game;Arcade;
StartupNotify=true
```
*(Replace `%USER%` with your username).*

### Hyprland Window Rules

Add to `~/.config/hypr/hyprland.conf`:

```ini
# Optional floating window rule for the launcher
windowrulev2 = float, title:^(Omarchy Arcade)$
windowrulev2 = size 1080 740, title:^(Omarchy Arcade)$
windowrulev2 = center, title:^(Omarchy Arcade)$

# Quick launch keybinding (Super + G)
bind = $mainMod, G, exec, ~/omarchyarcade/arcade
```
