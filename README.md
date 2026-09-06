# Omarchy Arcade

<p align="center">
  <img src="assets/splashscreen.png" alt="Omarchy Arcade Startup" width="480"/>
</p>

A curated suite of 16 lightweight, native desktop arcade games built with **QML**, **QtQuick**, and **JavaScript** for **Omarchy Linux** (Hyprland).

---

## The Mission

Growing up across the golden eras of personal computing—from the Tandy 1000 and DeskMate, through DOS, Windows 3.11, and classic Mac System 7—some of the fondest memories were the games discovered along the way. In modern operating systems, built-in games devolved into ad-riddled, login-gated, telemetry-heavy bloatware.

At the same time, traditional Linux desktop games—especially older GNOME and KDE games—always suffered from a jarring aesthetic: dated 90s clip-art textures, clunky stock GTK widgets, giant menu bars, and rigid windows that violently clashed with custom desktop themes.

**Omarchy Arcade** was built to revive that lost magic with a clean, cohesive design philosophy:
* **Zero Bloat & Zero Ads:** No telemetry, no advertisements, no tracking, and no monetization.
* **No Signups or Logins:** Instant play with zero accounts or internet requirements.
* **Pure Decompression:** Quick, low-friction games to unwind for 2 minutes between compiles or terminal sessions.
* **Clean, Consistent Template:** Every game shares a unified, distraction-free layout—clean stat cards, tactile quick-action buttons, and an unobstructed playfield. No clunky menus, no stock GTK chrome.
* **Theme-Driven Visuals:** Visuals are built with clean mathematical vectors and procedural geometries that step aside and let the game mechanics and your active Omarchy system theme (`~/.config/omarchy/current/theme/colors.toml`) take care of the styling.
* **Tiling-Native:** Designed specifically for the tiling spirit of Omarchy (Hyprland), scaling smoothly from full screen down to compact window splits without clipping.

---

## The Arcade Collection

All 16 games feature dedicated manuals and controls guides:

| Game | Description | Documentation |
| :--- | :--- | :--- |
| **2048** | Sleek tile-merging puzzle with pentatonic pitch-scaled harmonic chimes. | [Read Manual](games/2048/README.md) |
| **BrickBash** | High-energy paddle breakout with segmented angle deflections & combo multipliers. | [Read Manual](games/brickbash/README.md) |
| **ByteCity** | 2.5D dimetric isometric city builder powered by the genuine 1989 Micropolis C++ core. | [Read Manual](games/bytecity/README.md) |
| **ByteSnake** | Fluid grid navigator with sub-frame input buffering and progressive speed scaling. | [Read Manual](games/bytesnake/README.md) |
| **CratePusher** | Warehouse crate-pushing puzzle featuring 100% verified solvable levels & unlimited undo. | [Read Manual](games/cratepusher/README.md) |
| **CyberFlap** | Reflex-demanding airborne runner with dynamic pitch aerodynamics & sub-ms response. | [Read Manual](games/cyberflap/README.md) |
| **CyberHop** | Traffic and river hazard navigation with grid-snapped leaps and home bays. | [Read Manual](games/cyberhop/README.md) |
| **CyberSweeper** | Deduction puzzle with guaranteed safe first click and recursive cascade reveals. | [Read Manual](games/cybersweeper/README.md) |
| **DinoRunner** | Prehistoric endless runner with dynamic Day/Night cycles & pterodactyls. | [Read Manual](games/dinorunner/README.md) |
| **DropFour** | Tactile vertical four-in-a-row strategy featuring an intelligent heuristic AI. | [Read Manual](games/dropfour/README.md) |
| **GalacticSwarm** | Insectoid alien dive formations, tractor beam ship capture, and dual fighters. | [Read Manual](games/galacticswarm/README.md) |
| **TetraBlocks** | Guideline falling block arcade puzzle with SRS wall kicks, 7-bag, & ghost projection. | [Read Manual](games/tetrablocks/README.md) |
| **VectorDrift** | Vector wireframe space combat with Newtonian inertia & 3-2-1 safe respawns. | [Read Manual](games/vectordrift/README.md) |
| **VectorPong** | The pioneer of video games rebuilt with ball spin slicing and adaptive AI paddle. | [Read Manual](games/vectorpong/README.md) |
| **VoidInvaders** | Descending alien armadas, destructible bunkers, and mystery flying saucers. | [Read Manual](games/voidinvaders/README.md) |
| **WordGuess** | 5-letter deduction word puzzle with 3D tile flips and offline dictionary verification. | [Read Manual](games/wordguess/README.md) |

---

## Architectural Highlights

* **Dynamic Omarchy Theming:** Real-time auto-synchronization with all 22 Omarchy system themes by reading `~/.config/omarchy/current/theme/colors.toml`. Live hot-reloads on theme changes (`Super + Space`).
* **Retro Console Startup Screen:** ~1.0-second vintage console startup sequence featuring the Omarchy Arcade vector emblem, CRT scanlines, and animated glint sheen (skips instantly on any key or click).
* **Keyboard-First & Vim Navigation:** Arrow keys, WASD, and Vim (`H`, `J`, `K`, `L`) navigation are supported across every game.
* **Zero-Overhead Audio:** Native, hardware-accelerated sound via PipeWire and ALSA, defaulted to muted (`M` to toggle) with 0% CPU consumption when silent.
* **Tiling Window Manager Ready:** Flexible responsive layouts that adapt smoothly to narrow splits without clipping.
* **Game Template Available:** Standardized starter template in [`template/`](template/) with a documentation template in [`template/README_TEMPLATE.md`](template/README_TEMPLATE.md) for easily creating and contributing new games.

---

## Quick Start

### Prerequisites

On Omarchy Linux:
```bash
sudo pacman -S python python-pyside6 qt6-declarative
```

### Launching Any Game

```bash
# Launch from the arcade root:
python games/2048/main.py
python games/vectordrift/main.py
python games/tetrablocks/main.py
python games/galacticswarm/main.py
```

### Previewing Specific Omarchy Themes:

All games support launching directly with any of the 22 Omarchy color palettes:

```bash
python games/dinorunner/main.py --theme tokyonight
python games/wordguess/main.py --theme gruvbox
python games/brickbash/main.py --theme catppuccin
python games/cratepusher/main.py --theme snow
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
