# Omarchy Arcade • Universal Game Specification & Requirements

This document defines the strict engineering, aesthetic, and architectural standards for **every game** in the **Omarchy Arcade** suite. All existing games and future titles must adhere strictly to these specifications without exception.

---

## 1. System Architecture & Tech Stack

* **Host:** Python 3.11+ with PySide6 (`QGuiApplication`, `QQmlApplicationEngine`, `QFileSystemWatcher`).
* **UI & Rendering:** Pure **QtQuick / QML** with hardware acceleration.
* **Game Logic:** Pure JavaScript (`GameEngine.js`) paired with reactive QML properties.
* **Vector Graphics:** 100% vector SVG and procedural Canvas geometry. No raster bitmaps, heavy textures, or external sprite sheets.
* **Audio:** Zero-overhead synthesized `.wav` files played via memory-resident sound routines. Defaulted to muted (`🔇`).
* **Official Template:** Use [`template/`](file:///Users/christhompson/arcade/template/) as the baseline for every new game.

---

## 2. Omarchy System Theme Synchronization

1. **Automatic Detection Only:**
   - On launch, the game reads `~/.config/omarchy/current/theme/colors.toml`.
   - **NEVER** place theme selector dropdowns, theme picker pills, or color customization menus in the game UI.
2. **Live Hot-Reloading:**
   - Host `main.py` uses `QFileSystemWatcher` to monitor both `colors.toml` and its parent directory.
   - When the user switches themes in Omarchy (`Super + Space`), the game updates colors live **without restarting**.
3. **Smooth Color Animations:**
   - Visual items (`mainContainer`, buttons, modals) can declare snappy transitions:
     ```qml
     Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
     ```
   - *Note:* Do NOT declare `Behavior on ...` directly on top-level `Window` properties, as Qt 6 prohibits root window property animation drivers.
4. **WCAG Luminance Contrast for Action Buttons:**
   - Calculate background luminance dynamically to ensure buttons remain high-contrast in both dark themes (Catppuccin, Gruvbox, Tokyo Night) and light themes (Latte, Snow):
     ```qml
     function colorLuminance(col) {
         var c = Qt.color(col);
         return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
     }
     themeBtnFg = colorLuminance(themeBtnBg) > 0.5 ? "#11111b" : "#ffffff";
     ```
5. **Cross-Platform OS Theme Synchronization (macOS / General Desktops):**
   - If `colors.toml` is not present (e.g. running on macOS, Windows, or standard Linux), `main.py` inspects the user's OS appearance via `app.styleHints().colorScheme()`:
     - `Qt.ColorScheme.Dark` maps to **Catppuccin Mocha** (`#181825`).
     - `Qt.ColorScheme.Light` maps to **Catppuccin Latte** (`#eff1f5`).
   - The game listens to `app.styleHints().colorSchemeChanged` so that toggling system Dark/Light mode updates the running game in real time.

---

## 3. The 2048 Design Standard (Universal UI Hierarchy)

Every game in the suite follows the **2048 visual layout**. Never invent alternative header layouts or squash controls into cramped single-line strips.

```
┌────────────────────────────────────────────────────────┐
│  Game Title                               [STAT] [BEST]│
│  Tagline subtitle                                      │
│                                                        │
│  [? How to Play]       [🔇 Muted]          [Action (R)]│
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                   PLAYFIELD                      │  │
│  │          (Rounded themeBoardBg Container)        │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [  ↶ Undo (U)  │  ☰ Stages (L)  │  ◀ Prev │ Next ▶  ]  │ (Optional)
└────────────────────────────────────────────────────────┘
```

### Component Specifications:

### Tier 1: Top Header Row (`headerItem`)
* **Title (Left):**
  - Confident, large title: `font.pixelSize: Math.max(22, Math.min(36, width * 0.08))`, bold, `color: root.themeAccent`.
  - Subtitle / Tagline below: `font.pixelSize: Math.max(10, Math.min(13, width * 0.026))`, `color: root.themeSubtext`.
* **Stat Cards (Right):**
  - Rounded rectangular badges: `width: Math.max(64, Math.min(84, width * 0.16))`, `height: Math.max(42, Math.min(52, width * 0.10))`, `radius: 8`.
  - Background `themeCardBg`, border `themeBorder` (1px).
  - Uppercase subtext label on top (`font.pixelSize: 8–9px`, bold, `themeSubtext`).
  - Prominent bold numerical value on bottom (`font.pixelSize: 16–18px`, bold, `themeFg`).

### Tier 2: Subheader Action Bar (`subheaderItem`)
A balanced 3-button row providing instant access to essential actions:
1. **Help Pill (Left):**
   - Pill button with circular accent badge: `height: 32px`, `radius: 8px`.
   - Text: `"How to Play"` (collapses to `"Help (?)"` when width < 340px).
2. **Sound Pill (Center):**
   - Mute toggle pill: `height: 32px`, `radius: 8px`.
   - Text: `"🔇 Muted"` or `"🔊 Sound"` (icon-only when width < 300px).
3. **Primary Action Pill (Right):**
   - Accent button: `height: 32px`, `radius: 8px`, filled with `themeBtnBg` (`themeAccent`).
   - High contrast bold text: `"Restart (R)"` or `"New Game (R)"`.

### Tier 3: Playfield Container (`boardContainer`)
* The game canvas/board is enclosed in a dedicated `Rectangle`:
  - `color: root.themeBoardBg`
  - `border.color: root.themeBorder`
  - `border.width: 1`
  - `radius: 12`
  - `clip: true`
* The container anchors cleanly between the subheader and the bottom bar with balanced margins (`14–16px`).

### Tier 4: Bottom Action Bar (Optional — For Stage Navigation / Undo)
* For puzzle games requiring stage navigation (e.g. Sokoban, Sudoku):
  - Centered floating pill bar: `height: 36px`, `width: Math.min(parent.width - 32, 420)`.
  - **Responsive Proportional Partitioning:** Never use fixed-width child buttons in a row. Divide space proportionally (e.g. `28%`, `32%`, `20%`, `20%`) so controls **never overflow or clip** in narrow window splits.
  - Collapse hotkey hints (e.g. `(U)` / `(L)`) when `width < 340px`.

---

## 4. Window Sizing & Tiling Window Manager Compliance

1. **Never Programmatically Resize the Window:**
   - **STRICT PROHIBITION:** Never programmatically set `root.width = ...` or `root.height = ...` after initialization. Omarchy uses Hyprland (a tiling window manager); altering window geometry breaks the user's desktop layout.
2. **Responsive Breathing Room:**
   - The UI must scale gracefully down to `320×460` minimum window size.
   - Text and button padding must adapt dynamically using breakpoints (`width < 340px`).

---

## 5. Canonical Omarchy Arcade Splash Screen

Every game must include the exact canonical arcade startup sequence:
1. **Source File:** [`SplashScreen.qml`](file:///Users/christhompson/arcade/template/SplashScreen.qml) (MD5: `fa4a49ad9d6adbdc39c4a7a9b3e96ab6`). Never modify this component.
2. **Assets Required:** `omarchy_arcade.svg` (emblem) and `omarchy_arcade_text.svg` (retro text).
3. **Instant Skip:**
   - Must skip immediately upon any mouse click or key press (`splashScreen.dismiss()`).
   - Standard timeout: ~1.0 second auto-fadeout.

---

## 6. End-of-Game Overlay & Victory Modal

Every game must display a standardized modal overlay on Game Over or Victory:

```qml
Rectangle {
    id: gameOverOverlay
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.78)
    visible: root.gameState === "gameover" || root.gameState === "won"
    z: 100

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.startNewGame()
    }

    Column {
        anchors.centerIn: parent
        spacing: 14

        Text {
            text: root.gameState === "won" ? "VICTORY!" : "GAME OVER"
            color: root.gameState === "won" ? root.themeAccent : "#FF5555"
            font.pixelSize: 28
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Score: " + root.score
            color: root.themeFg
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            width: 140
            height: 40
            radius: 8
            color: playAgainMouse.containsMouse ? Qt.lighter(root.themeAccent, 1.15) : root.themeAccent
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "PLAY AGAIN"
                color: root.themeBtnFg
                font.bold: true
                font.pixelSize: 12
            }

            MouseArea {
                id: playAgainMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNewGame()
            }
        }

        Text {
            text: "Or press R / Space / Enter"
            color: root.themeSubtext
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
```

---

## 7. Universal Keyboard Controls

All games must implement standard multi-scheme keyboard inputs:
* **Movement / Direction:**
  * **Arrow Keys:** `←`, `↑`, `→`, `↓`
  * **WASD:** `W`, `A`, `S`, `D`
  * **Vim Keys:** `H`, `J`, `K`, `L`
* **Actions:**
  * `Space`: Action / Jump / Fire / Flap
  * `R`: Instant Restart
  * `M`: Toggle Sound Mute
  * `?` or `Esc`: Toggle Help Dialog / Pause

---

## 8. Audio Standards

* **Default to Muted:** On startup, `isMuted` is `true` by default (`🔇`).
* **Zero Overhead:** When `isMuted` is true, sound trigger functions must immediately return without loading or playing audio buffers.
* **Format:** Synthesized 16-bit 44.1kHz mono `.wav` stored locally in `games/<game>/sounds/`.

---

## 9. Standard Directory Layout

```
games/<game_name>/
├── main.py                 # PySide6 host, theme watcher, QSettings, screenshot hook
├── main.qml                # QtQuick root, 2048 layout, HUD, canvas, overlays
├── SplashScreen.qml        # Canonical arcade startup sequence (identical copy)
├── GameEngine.js           # Core physics, math, and game loop logic
├── Themes.js               # All 22 official Omarchy desktop themes
├── omarchy_arcade.svg      # Canonical vector emblem
├── omarchy_arcade_text.svg # Canonical retro text logo
├── sounds/                 # Synthesized WAV sound effects
│   ├── click.wav
│   ├── select.wav
│   └── game_over.wav
└── README.md               # Game overview, rules, and controls
```

---

## 10. The Official Master Game Template (`template/`)

The [`template/`](file:///Users/christhompson/arcade/template/) directory is the official, golden-standard starting point for all arcade titles:

1. **Instant Bootstrap:**
   - Instead of writing game scaffolding from scratch, developers and AI agents copy the `template/` folder directly:
     ```bash
     cp -r template games/<new_game>
     ```
2. **Pre-Wired Functionality:**
   - **Canonical Splash Screen:** Comes pre-packaged with `SplashScreen.qml`, `omarchy_arcade.svg`, and `omarchy_arcade_text.svg`.
   - **2048 Visual Hierarchy:** Row 1 Header, Row 2 Subheader pills (`Help`, `Sound`, `Restart`), and Tier 3 Board container ready to receive drawing logic.
   - **Full Theme Engine:** Automatic syncing with `colors.toml` on Omarchy Linux + native OS Dark/Light detection via `QStyleHints` on macOS/Windows/Linux.
   - **Audio Subsystem:** 0ms latency CoreAudio on macOS + PipeWire/PulseAudio on Linux with synthesized sound effects included.
   - **Settings Persistence:** `QSettings` hooks wired for high score and options.
3. **Public Release Ready:**
   - The template includes a comprehensive [`template/README.md`](file:///Users/christhompson/arcade/template/README.md) explaining how community members or external developers can build games that integrate into Omarchy Arcade.

