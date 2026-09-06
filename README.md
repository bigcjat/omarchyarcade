# Omarchy Arcade

A collection of lightweight, native desktop arcade games built with **QML**, **QtQuick**, and **JavaScript** for macOS and Linux (Omarchy / Hyprland).

## Repository Structure

```
arcade/
├── games/
│   ├── 2048/             # 2048 game with Omarchy theme auto-sync & retro audio
│   └── tetrablocks/      # Classic falling block puzzle with SRS kicks, 7-bag, & theme auto-sync
└── launcher/             # (Upcoming) Central Arcade Game Launcher
```

## Games

* **[2048](games/2048/README.md):** Dynamic tile-merging puzzle with Omarchy desktop theme auto-sync, retro console intro, and pitch-scaled audio chimes.
* **[TetraBlocks](games/tetrablocks/README.md):** Classic falling block arcade puzzle with standard Guideline mechanics (7-Bag randomizer, SRS wall kicks, lock delay, hold piece, and ghost piece).

See **[WISHLIST.md](WISHLIST.md)** for the full roadmap of upcoming games (Blackjack, Galaga, Bejeweled, Pac-Man, Pinball, and more).

## Quick Start

```bash
# Launch 2048
./.venv/bin/python games/2048/main.py

# Launch TetraBlocks
./.venv/bin/python games/tetrablocks/main.py
```
