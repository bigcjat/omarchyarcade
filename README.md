# Omarchy Arcade

<p align="center">
  <img src="assets/splashscreen.png" alt="Omarchy Arcade Startup" width="480"/>
</p>

A curated suite of lightweight, native desktop arcade games built with **QML**, **QtQuick**, and **JavaScript** for macOS and Linux (Omarchy / Hyprland).

Every game adheres to a unified **2048 Design Standard**, featuring live desktop theme synchronization, vintage console startup sequences, zero-overhead hardware-accelerated audio, and responsive tiling window manager geometry.

---

## The Arcade Collection

All 16 games feature dedicated documentation and controls guides:

| Game | Description | Documentation |
| :--- | :--- | :--- |
| **2048** | Sleek tile-merging puzzle with pentatonic pitch-scaled harmonic chimes. | [Read Manual](games/2048/README.md) |
| **VectorDrift (Asteroids)** | Vector wireframe space combat with Newtonian inertia & 3-2-1 safe respawns. | [Read Manual](games/asteroids/README.md) |
| **BrickBreaker** | High-energy paddle breakout with segmented angle deflections & combo multipliers. | [Read Manual](games/brickbreaker/README.md) |
| **ByteCity** | 2.5D dimetric isometric city builder powered by the genuine 1989 Micropolis C++ core. | [Read Manual](games/bytecity/README.md) |
| **Connect 4** | Tactile vertical four-in-a-row strategy featuring an intelligent heuristic AI. | [Read Manual](games/connect4/README.md) |
| **CyberDash (Runner)** | Chrome Dino-inspired endless runner with dynamic Day/Night cycles & pterodactyls. | [Read Manual](games/runner/README.md) |
| **CyberFlap** | Reflex-demanding airborne runner with dynamic pitch aerodynamics & sub-ms response. | [Read Manual](games/flappy/README.md) |
| **Frogger** | Traffic and river hazard navigation with grid-snapped leaps and home bays. | [Read Manual](games/frogger/README.md) |
| **Galaga** | Insectoid alien dive formations, tractor beam ship capture, and dual fighters. | [Read Manual](games/galaga/README.md) |
| **Minesweeper** | Deduction puzzle with guaranteed safe first click and recursive cascade reveals. | [Read Manual](games/minesweeper/README.md) |
| **Pong** | The pioneer of video games rebuilt with ball spin slicing and adaptive AI paddle. | [Read Manual](games/pong/README.md) |
| **Snake** | Fluid grid navigator with sub-frame input buffering and progressive speed scaling. | [Read Manual](games/snake/README.md) |
| **CratePusher (Sokoban)** | Warehouse crate-pushing puzzle featuring 100% verified solvable levels & unlimited undo. | [Read Manual](games/sokoban/README.md) |
| **Space Invaders** | Descending alien armadas, destructible bunkers, and mystery flying saucers. | [Read Manual](games/spaceinvaders/README.md) |
| **TetraBlocks** | Guideline falling block arcade puzzle with SRS wall kicks, 7-bag, & ghost projection. | [Read Manual](games/tetrablocks/README.md) |
| **Wordle** | 5-letter deduction word puzzle with 3D tile flips and offline dictionary verification. | [Read Manual](games/wordle/README.md) |

---

## Architectural Highlights

* **Dynamic Omarchy Theming:** Real-time auto-synchronization with all 22 Omarchy system themes by reading `~/.config/omarchy/current/theme/colors.toml`. Live hot-reloads on theme changes (`Super + Space`).
* **Retro Console Startup Screen:** ~1.0-second vintage console startup sequence featuring the Omarchy Arcade vector emblem, CRT scanlines, and animated glint sheen (skips instantly on any key or click).
* **Keyboard-First & Vim Navigation:** Arrow keys, WASD, and Vim (`H`, `J`, `K`, `L`) navigation are supported across every game.
* **Zero-Overhead Audio:** Native, hardware-accelerated sound (CoreAudio on macOS, PipeWire/ALSA on Linux), defaulted to muted (`M` to toggle) with 0% CPU consumption when silent.
* **Tiling Window Manager Ready:** Flexible responsive layouts that adapt smoothly to narrow splits without clipping.
* **Game Template Available:** Standardized starter template in [`template/`](template/) with a documentation template in [`template/README_TEMPLATE.md`](template/README_TEMPLATE.md) for easily creating and contributing new games.

---

## Quick Start

### Prerequisites

* Python 3.10+
* PySide6 (`pip install -r requirements.txt` or system package `python-pyside6`)

### Launching Any Game

```bash
# Launch from the arcade root:
./.venv/bin/python games/2048/main.py
./.venv/bin/python games/asteroids/main.py
./.venv/bin/python games/tetrablocks/main.py
./.venv/bin/python games/galaga/main.py
```

### Launching with a Specific Theme (macOS / Testing):

All games support launching with any of the 22 Omarchy color palettes:

```bash
./.venv/bin/python games/runner/main.py --theme tokyonight
./.venv/bin/python games/wordle/main.py --theme gruvbox
./.venv/bin/python games/brickbreaker/main.py --theme catppuccin
./.venv/bin/python games/sokoban/main.py --theme snow
```

---

## Contributing New Games

To build and contribute a new arcade game, copy the starter scaffold from [`template/`](template/):

```bash
cp -r template games/mygame
cp template/README_TEMPLATE.md games/mygame/README.md
```

Refer to [`template/README.md`](template/README.md) and [`REQUIREMENTS.md`](REQUIREMENTS.md) for full layout standards and guidelines.

---

## License

Released under the **MIT License**. See individual game manuals for third-party attributions and public domain mechanics.
