# Game Name (QML / QtQuick)

![Game Name](screenshot.png)

A brief, engaging 1-2 sentence description of the game, its mechanics, and its modern arcade styling.

Built natively with hardware acceleration for **Omarchy Linux**.

---

## Features

* **Dynamic Omarchy Theming:** Automatically synchronizes with all 22 Omarchy system themes by reading `~/.config/omarchy/current/theme/colors.toml`. Live hot-reloads when changing themes via `Super + Space`!
* **Standardized 2048 Arcade Layout:** Top title & stats header, subheader with sound toggle and quick action buttons, and responsive play matrix.
* **Retro Console Startup Screen:** ~1.0-second arcade startup sequence with CRT scanlines, retro stripes, and vector glint sheen (skips instantly on any key/click).
* **Keyboard-First Controls:** Arrow keys, WASD, and Vim (`H`, `J`, `K`, `L`) navigation supported across all interactions.
* **Zero-Overhead Audio:** Zero-overhead native audio (PipeWire / ALSA), defaulted to muted (`M` to toggle) with 0% CPU consumption when silent.
* **Responsive Tiling:** Smoothly adapts to any window geometry down to narrow tiling window manager splits without clipping.
* **Persistent High Scores:** Saves best scores and stats across sessions via `QSettings`.

---

## Controls

| Action | Primary Key | Secondary / Vim | Mouse / Touch |
| :--- | :--- | :--- | :--- |
| **Move / Steer** | `W` / `A` / `S` / `D` | `H` / `J` / `K` / `L` or Arrow Keys | Click / Drag |
| **Primary Action** | `Space` / `Enter` | — | Click button |
| **Mute / Unmute** | `M` | — | Click audio button in subheader |
| **Restart Game** | `R` | — | Click "Restart" in subheader |
| **How to Play / Help**| `?` or `Esc` | — | Click "How to Play" |

---

## Running

### From the Arcade Root:

```bash
./.venv/bin/python games/<gamename>/main.py
```

### With a Specific Theme:

```bash
./.venv/bin/python games/<gamename>/main.py --theme gruvbox
./.venv/bin/python games/<gamename>/main.py --theme tokyonight
./.venv/bin/python games/<gamename>/main.py --theme catppuccin
./.venv/bin/python games/<gamename>/main.py --theme snow
```

---

## License & Attribution

* Released under the **MIT License**.
