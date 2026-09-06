# Omarchy Arcade • Master Game Template

Welcome to the **Omarchy Arcade Game Template**! This template provides a complete, production-ready foundation for creating games that seamlessly integrate into Omarchy Linux and cross-platform desktop environments (macOS, Linux, Windows).

Every game built with this template inherits:
- 🎨 **OS & Desktop Theme Synchronization:** Automatic live hot-reloading from Omarchy's `~/.config/omarchy/current/theme/colors.toml` as well as native macOS/Windows system Dark/Light mode detection.
- 📐 **The 2048 Design Standard:** A clean, spacious, two-tier header, responsive pill action buttons, and rounded playfield container that look stunning in any window manager.
- ⚡ **Tiling Window Manager Compliance:** Reactively scales to any window geometry without manual resizing (critical for Hyprland and tiling WMs).
- 🕹️ **Canonical Arcade Splash Screen:** Authentic CRT-glow launch sequence with instant single-click skip.
- 🔊 **Zero-Latency Audio Engine:** Native CoreAudio AudioServices on macOS (0ms delay preloaded memory sound IDs) with automatic fallback to PipeWire (`pw-play`), PulseAudio (`paplay`), or ALSA (`aplay`) on Linux.
- 💾 **Persistent Settings:** Local high-score and preference tracking powered by `QSettings`.
- ⌨️ **Universal Accessibility Controls:** Built-in support for Arrows, WASD, and Vim (`HJKL`) navigation.

---

## 📁 Directory Structure

```
template/
├── main.py                  # PySide6 host: theme watcher, sound engine, CLI tools
├── main.qml                 # QML frontend: 2048 UI layout, HUD, canvas, modals
├── GameEngine.js            # Pure JavaScript game loop & physics logic
├── Themes.js                # All 22 official Omarchy desktop themes
├── SplashScreen.qml         # Canonical Omarchy Arcade splash sequence (DO NOT MODIFY)
├── omarchy_arcade.svg       # Official retro vector emblem
├── omarchy_arcade_text.svg  # Official retro text banner
├── sounds/                  # Synthesized WAV audio effects
│   ├── click.wav
│   ├── select.wav
│   ├── move.wav
│   ├── step.wav
│   ├── push.wav
│   ├── dock.wav
│   ├── undock.wav
│   ├── target.wav
│   ├── undo.wav
│   ├── win.wav
│   └── game_over.wav
└── README.md                # Developer documentation (this file)
```

---

## 🚀 Quickstart: Building a New Game in 4 Steps

To create a new game for Omarchy Arcade, follow this simple workflow:

### Step 1: Copy the Template
Copy the entire `template/` directory to `games/<your_game_name>`:
```bash
cp -r template games/mygame
cd games/mygame
```

### Step 2: Configure Metadata
In `games/mygame/main.qml`:
1. Update window title and subtitle:
   ```qml
   title: "My Awesome Game"
   // In headerItem:
   Text { text: root.title }
   Text { text: "Fast-paced arcade challenge" }
   ```
2. Update the `helpText` string with your game's rules and controls:
   ```qml
   property string helpText: "• Move: Arrow Keys or WASD\n• Jump: Space\n• Restart: R\n• Sound: M"
   ```

In `games/mygame/main.py`:
1. Change the application name and `QSettings` identifier:
   ```python
   app.setApplicationName("My Awesome Game")
   settings_mgr = SettingsManager("MyAwesomeGame")
   ```

### Step 3: Implement Game Logic
Implement your entities, physics, and state transitions in `GameEngine.js`:
- `init(width, height)`: Called when the board geometry is ready.
- `update(dt, callbacks)`: Called every frame (~60 FPS) to advance physics and timers.
- `handleInput(action, callbacks)`: Receives `"left"`, `"right"`, `"up"`, `"down"`, `"action"`.
- `resetGame()`: Reinitializes score, entities, and states for a new round.

To play sound effects or update the score from JavaScript:
```javascript
if (callbacks && callbacks.onSound) {
    callbacks.onSound("push"); // Must match a file in sounds/<name>.wav
}
```

### Step 4: Render the Playfield
In `games/mygame/main.qml`, implement your drawing routine inside `gameCanvas.onPaint` or use declarative QML items inside `boardContainer`:
```qml
onPaint: {
    var ctx = getContext("2d");
    ctx.fillStyle = root.themeBoardBg;
    ctx.fillRect(0, 0, width, height);

    // Draw game entities using theme tokens
    ctx.fillStyle = root.themeAccent;
    ctx.fillRect(player.x, player.y, player.w, player.h);
}
```

---

## 🎨 Theme Synchronization & Design Tokens

### 1. Automatic OS & Omarchy Theme Detection
Games automatically detect their theme in this order:
1. **CLI Flag Override:** `python main.py --theme <name>`
2. **Omarchy Desktop Theme:** If running on Omarchy Linux, reads `~/.config/omarchy/current/theme/colors.toml` and establishes a live `QFileSystemWatcher` to hot-reload themes on the fly.
3. **macOS / General OS Appearance:** Detects system Dark Mode vs Light Mode via Qt's `QStyleHints` and automatically maps to **Catppuccin Mocha** (Dark) or **Catppuccin Latte** (Light), with live reactivity when the OS theme changes.

### 2. Available QML Color Tokens
All components should reference these reactive color properties on `root`:

| Token | Purpose | Typical Dark Value | Typical Light Value |
| :--- | :--- | :--- | :--- |
| `root.themeBg` | Outer window background | `#181825` (Mocha) | `#eff1f5` (Latte) |
| `root.themeBoardBg` | Playfield board background | `#11111b` (Crust) | `#e6e9ef` (Mantle) |
| `root.themeCardBg` | Stat badges & modal cards | `#313244` (Surface0) | `#e6e9ef` (Surface0) |
| `root.themeBorder` | Card & container borders | `#45475a` (Surface1) | `#ccd0da` (Surface1) |
| `root.themeFg` | Primary text and headings | `#cdd6f4` (Text) | `#4c4f69` (Text) |
| `root.themeSubtext` | Secondary text & labels | `#a6adc8` (Subtext) | `#6c6f85` (Subtext) |
| `root.themeAccent` | Primary brand accent color | `#89b4fa` (Blue) | `#1e66f5` (Blue) |
| `root.themeBtnBg` | Primary action button fill | `themeAccent` | `themeAccent` |
| `root.themeBtnFg` | Button label contrast text | Dynamically computed via WCAG luminance |

### 3. WCAG Luminance Contrast Formula
To ensure button text is always legible across all 22 light and dark themes:
```qml
function colorLuminance(col) {
    var c = Qt.color(col);
    return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
}
themeBtnFg: colorLuminance(themeAccent) > 0.5 ? "#11111b" : "#ffffff"
```

---

## 📐 The 2048 Layout Standard

Never invent custom header layouts or squash controls into cramped single-strip toolbars. All arcade games share the **2048 Visual Hierarchy**:

```
┌────────────────────────────────────────────────────────┐
│  Game Title                               [STAT] [BEST]│  Row 1: Header Item
│  Tagline subtitle                                      │
│                                                        │
│  [? How to Play]       [🔇 Muted]          [Action (R)]│  Row 2: Action Bar
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                   PLAYFIELD                      │  │  Tier 3: Board Container
│  │          (Rounded themeBoardBg Container)        │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [  ↶ Undo (U)  │  ☰ Stages (L)  │  ◀ Prev │ Next ▶  ]  │  Tier 4: Optional Bottom Nav
└────────────────────────────────────────────────────────┘
```

### Responsive Narrow-Window Rules
- On narrow tiling splits (`width < 340px`), buttons automatically collapse extra labels (`"How to Play"` → `"Help"`).
- If your game includes a bottom navigation bar, **always use proportional width partitioning** (`28%`, `32%`, `20%`, `20%`) inside `anchors.fill: parent; anchors.margins: 4`. Never use fixed-width child items inside an centered `Row`, as this causes horizontal overflow on compact screens.

---

## 🔊 Audio Guidelines

1. **Default to Muted:** Every game launches with `isMuted: true` by default (`🔇`).
2. **Zero Runtime Overhead:** Sound triggers immediately exit when muted without decoding or allocating memory.
3. **Format:** 16-bit 44.1kHz mono `.wav` files located in the `sounds/` subfolder.
4. **Triggering Audio:**
   - In QML: `root.playSound("click")`
   - In JS Engine: `callbacks.onSound("win")`

---

## 💻 CLI & Developer Tools

The template includes built-in CLI flags for development, testing, and CI screenshots:

```bash
# List all 22 supported Omarchy themes
python main.py --list-themes

# Launch with a specific theme preview
python main.py --theme tokyonight
python main.py --theme catppuccin-latte
python main.py --theme gruvbox

# Launch directly into gameplay without splash screen
python main.py --no-splash

# Capture automated screenshots for documentation or PRs
python main.py --screenshot gameplay.png
python main.py --screenshot-help
python main.py --screenshot-splash
```

---

## ⚖️ Contributing to Omarchy Arcade

When submitting a game for inclusion in the arcade suite:
1. Ensure the canonical `SplashScreen.qml` (MD5: `fa4a49ad9d6adbdc39c4a7a9b3e96ab6`) is preserved.
2. Confirm that the game conforms to the 2048 header hierarchy.
3. Test under both light mode (`--theme catppuccin-latte`) and dark mode (`--theme catppuccin`).
4. Never invoke `root.width = ...` or `root.height = ...` programmatically after launch.
5. Provide a helpful `README.md` and screenshot in your game's directory.
