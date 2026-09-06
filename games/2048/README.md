# 2048 (QML / QtQuick)

![2048 Gameplay](screenshot.png)

A minimalist, high-performance **2048** implementation written in **QML** and **JavaScript**, styled with a sleek dark palette.

Runs natively with hardware acceleration on both **macOS** and **Linux (Omarchy)**.

---

## Features
* **Dynamic Omarchy Theming:** Automatically synchronizes with all 22 Omarchy system themes by reading `~/.config/omarchy/current/theme/colors.toml`. Live hot-reloads when changing themes via `Super + Space`!
* **WCAG Contrast-Aware:** Automatically calculates luminance to switch tile and text colors cleanly between light themes (like **Snow**) and dark themes (**Gruvbox**, **Nord**, **Tokyo Night**, **Catppuccin**).
* **Retro Console Startup Screen:** Snappy ~1.0-second arcade startup sequence featuring an **Omarchy Arcade** vector emblem, staggered retro horizontal stripes, diagonal glint sheen, and subtle CRT scanlines (skips immediately on any key/click).
* **Fluid Animations:** Smooth tile sliding (`Easing.OutCubic`), bouncy merge pulses, pop-in spawn animations, and smooth color fades when themes switch.
* **Keyboard-First Controls:**
  * **Vim Keys:** `H` (Left), `J` (Down), `K` (Up), `L` (Right)
  * **WASD:** `W` (Up), `A` (Left), `S` (Down), `D` (Right)
  * **Arrow Keys:** `←`, `↑`, `→`, `↓`
  * **Restart / Help:** `R` (Restart), `?` / `Esc` (Help dialog)
* **Dynamic Sound Effects (Zero-Overhead & Defaulted to Mute):**
  * Pitch-scaled harmonic synth chimes that ascend pentatonically based on tile value merged ($4 \rightarrow 2048$).
  * Subtle tactile arcade tick on slide moves and retro sweep on game over.
  * **Defaulted to Muted** (`🔇 Muted`) on startup with **zero CPU/audio overhead** when muted.
  * Toggle audio anytime via the subheader button or by pressing **`M`**.
  * Ultra-efficient memory-resident playback using native CoreAudio system sound IDs on macOS and native pipewire/alsa on Linux.
* **Touch & Trackpad Gestures:** Two-finger trackpad swipes and 1-finger click/drag with single-move debouncing.
* **Tiling-Ready:** Adapts to any window geometry down to tiny 260×320 Hyprland splits without clipping.
* **Ultra Lightweight:** Sits at ~30–45 MB RAM with 0% idle CPU.

---

## Running on macOS

### Option 1: From the arcade root
```bash
./.venv/bin/python games/2048/main.py
```

### Option 2: From the game directory
```bash
cd games/2048
../../.venv/bin/python main.py
```

### Testing Themes on macOS:
The game automatically synchronizes with Omarchy desktop themes (`~/.config/omarchy/current/theme/colors.toml`). On macOS, you can preview or launch in any of the 22 Omarchy themes:
* **List all themes:**
  ```bash
  ../../.venv/bin/python main.py --list-themes
  ```
* **Launch directly in a specific theme:**
  ```bash
  ../../.venv/bin/python main.py --theme snow
  ../../.venv/bin/python main.py --theme gruvbox
  ../../.venv/bin/python main.py --theme tokyonight
  ../../.venv/bin/python main.py --theme catppuccin
  ```
* **Batch test & generate screenshots for all 22 themes:**
  ```bash
  ../../.venv/bin/python main.py --test-all-themes
  # Generated previews are saved to games/2048/theme_previews/
  ```

---

## Running on Omarchy (Arch Linux)

On Omarchy, Qt6 and QML run out of the box with zero setup.

### Option 1: Standalone QML
```bash
# If not already present: sudo pacman -S qt6-declarative
qml6 main.qml
```

### Option 2: Python + PySide6
```bash
# Install PySide6 via pacman:
sudo pacman -S python-pyside6
python main.py
```

### Option 3: Embed in Quickshell
Because Omarchy uses Quickshell, the `Item` tree in `main.qml` can be loaded directly as an interactive desktop widget or floating scratchpad tile!

---

## License & Attribution
* Original 2048 created by [Gabriele Cirulli](https://github.com/gabrielecirulli/2048), based on 1024 by Veewo Studio and conceptually similar to Threes by Asher Vollmer.
* Released under the **MIT License**. See [LICENSE](LICENSE) for details.
