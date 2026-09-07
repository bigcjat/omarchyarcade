# Blackjack 21 (QML / QtQuick)

![Blackjack 21](screenshot.png)

An authentic, tactile casino Blackjack table game featuring custom Omarchy-branded playing card decks, smooth 3D card flips, realistic chip betting, and standard 3:2 payouts.

Built natively with hardware acceleration for **Omarchy Linux**.

---

## Features

* **100% True Offline Play:** Zero internet required or used. No network sockets, zero cloud dependencies, zero telemetry, and zero ads. Plays completely offline forever.
* **Dynamic Omarchy Theming:** Automatically synchronizes with all 22 Omarchy system themes by reading `~/.config/omarchy/current/theme/colors.toml`. Live hot-reloads when changing themes via `Super + Space`!
* **Standardized 2048 Arcade Layout:** Top title & stats header with Bankroll and Bet cards, subheader with sound toggle and quick action buttons, and responsive playfield.
* **Responsive Toolbar Emoji Collapse:** When windows are narrow or toolbars crowded, control buttons automatically collapse into compact icon/emoji buttons (`💡`, `?`, `🔇`, `🔄`) so controls never push off-screen or smash together.
* **Retro Console Startup Screen:** ~1.0-second arcade startup sequence with CRT scanlines, retro stripes, and vector glint sheen (skips instantly on any key/click).
* **Keyboard-First Controls:** Single-key tactile hotkeys across all actions: Space to Deal, H to Hit, S to Stand, D to Double, 1–4 for Chips, C to Clear, and X to 2x Bet.
* **Zero-Overhead Audio:** Zero-overhead native audio (CoreAudio on macOS / PipeWire & ALSA on Linux), defaulted to muted (`M` to toggle) with 0% CPU consumption when silent.
* **Responsive Tiling:** Smoothly adapts to any window geometry down to narrow tiling window manager splits without clipping.
* **Persistent Bankroll & Stats:** Automatically saves your bankroll and best records across sessions via `QSettings`.

---

## Controls

| Action | Primary Key | Secondary / Alt | Mouse / Touch |
| :--- | :--- | :--- | :--- |
| **Deal Hand** | `Space` / `Enter` | `R` | Click "Deal Hand" button |
| **Hit (Draw Card)** | `H` | `Space` (during play) | Click "HIT" button |
| **Stand (Hold Hand)** | `S` | `Enter` (during play) | Click "STAND" button |
| **Double Down** | `D` | — | Click "DOUBLE" button |
| **Bet $5 / $25 / $100 / $500** | `1` / `2` / `3` / `4` | — | Click chip in tray |
| **Clear / Double Bet** | `C` / `X` | — | Click "CLR" / "2X" |
| **Mute / Unmute** | `M` | — | Click audio button in subheader |
| **How to Play / Rules**| `?` or `Esc` | — | Click "How to Play" |

---

## Running

### From the Arcade Root:

```bash
./.venv/bin/python games/blackjack/main.py
```

### With a Specific Theme:

```bash
./.venv/bin/python games/blackjack/main.py --theme gruvbox
./.venv/bin/python games/blackjack/main.py --theme tokyonight
./.venv/bin/python games/blackjack/main.py --theme catppuccin
./.venv/bin/python games/blackjack/main.py --theme snow
```

---

## Author & Credits

Created by **Chris Thompson** ([@bigcjat](https://github.com/bigcjat) • [@bigcjat](https://x.com/bigcjat)) with assistance from **Gemini**.

---

## License & Attribution

* Released under the **MIT License**.
