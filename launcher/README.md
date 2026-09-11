<p align="center">
  <img src="omarchy_arcade_logo.svg" alt="Omarchy Arcade" width="460"/>
</p>

<p align="center">
  <strong>The Native Offline Desktop Game Suite & Retro Arcade Launcher for Omarchy Linux.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Offline-Forever-00f0ff?style=flat-square" alt="Offline Forever"/>
  <img src="https://img.shields.io/badge/Telemetry-Zero-10b981?style=flat-square" alt="Zero Telemetry"/>
  <img src="https://img.shields.io/badge/Ads-Zero-f59e0b?style=flat-square" alt="Zero Ads"/>
  <img src="https://img.shields.io/badge/Games-39%20Included-ec4899?style=flat-square" alt="39 Games"/>
  <img src="https://img.shields.io/badge/Interface-Keyboard--Primary-8b5cf6?style=flat-square" alt="Keyboard-Primary"/>
  <img src="https://img.shields.io/badge/Platform-Omarchy%20Linux%20(Hyprland)-38bdf8?style=flat-square" alt="Omarchy Linux"/>
</p>

---

<p align="center">
  <img src="../assets/launcher_preview.png" alt="Omarchy Arcade Desktop Launcher" width="840"/>
</p>

## Meet Omarchy Arcade

**Omarchy Arcade** is a dedicated, distraction-free desktop game launcher and catalog of **39 full-featured offline arcade games** built specifically for **Omarchy Linux** and tiling window managers (Hyprland).

Modern casual gaming has been bogged down by online logins, tracking SDKs, ad networks, and multi-gigabyte bloat. Omarchy Arcade delivers instant, tactile, distraction-free retro arcade gaming right from your desktop—running with native **Qt6 / QML** hardware acceleration.

### Why You'll Love It

* 🔌 **Always Offline:** Zero accounts, zero tracking, zero ads, zero internet dependencies. Plays anywhere, anytime—on trains, planes, or off-grid.
* ⭐ **Featured Discovery Page:** Starts on a curated showcase featuring the **Sky Ace** hero video trailer, Staff Picks floppy carousel, and newest release shelf.
* 🗂️ **5 Dynamic View Modes:** Toggle effortlessly between **Featured**, **Floppy Wall Grid**, **3D Carousel**, **Retro Desktop**, and **Sidebar Library** views.
* ⚡ **Built for Keyboards & Tiling:** Instant Vim (`HJKL`) and arrow navigation, numbers `1`–`9` for category jumps, and `/` search. No mouse required.
* 🎨 **Live System Theme Syncing:** Connects directly with your Omarchy desktop theme (`colors.toml`). Switch themes on your desktop and the arcade hot-reloads its colors on the fly.
* 🪟 **Tiling-Native Flow:** Launch a game and the launcher automatically hides to keep your workspace clear. Exit the game and the launcher instantly reappears and re-focuses.
* 🎮 **39 Built-In Games:** Air combat action, blocks, puzzles, retro vector space combat, casino card games, grandmaster chess, tactical checkers, klondike solitaire, video poker terminal, backgammon, reversi, japanese tatami marbles, tactical tank combat engineering, city simulation, and classic action arcade games—ready to launch in milliseconds.

### Technology & Architecture

While the majority of Omarchy Arcade titles are built with native declarative **Qt6 / QML and JavaScript** for ultra-lightweight, 60+ FPS vector gameplay, the arcade suite accommodates specialized runtimes:

* **OmarchyBolo II (`games/omarchybolo`):** Written in **TypeScript** as a true multiplatform architecture that runs seamlessly both as a native desktop client in the launcher and directly in any modern web browser with peer-to-peer WebRTC networking.
* **Sky Ace (`games/skyace`):** Powered by a custom **Python & PySide6 / QPainter** tactical flight engine with pre-baked 3D aircraft frames, dynamic bank physics, carrier landings, and zero heavy external game library dependencies.
* **OmarchyCity (`games/bytecity`):** Integrates the legendary 1989 **C++ Micropolis** city simulation core for high-speed local urban modeling.

---

## The Future of Lean Software: 438 KB vs 231 MB

Why should simple casual games require 200+ MB of ad mediation libraries and tracking telemetry? Omarchy Arcade strips away the monetization machinery and delivers pure, joyful software:

| Feature / Metric | Typical Mobile App Store Release | Omarchy Arcade |
| :--- | :--- | :--- |
| **Download / Install Size** | **231.3 MB** | **438 KB** (~0.4 MB) |
| **Ad Networks & SDKs** | AppLovin, AdMob, Mintegral, Unity Ads | **Zero** |
| **Telemetry & Trackers** | Attribution SDKs, crash logging, user tracking | **Zero** |
| **Network Traffic** | Constant ad auctions & video buffering | **Zero network sockets** (Offline forever) |

---

## 5 Presentation View Modes

The launcher adapts to your personal style and screen space:

1. **⭐ Featured Discovery:** Cinematic hero video spotlight (Sky Ace), curated 6-game Staff Picks row, and newest release shelf sorted by release date.
2. **💾 Floppy Wall Grid:** Auto-reflowing responsive grid of authentic 3.5" diskettes with custom painted cover art and tactile labels.
3. **🎡 3D Carousel:** Smooth horizontal rotating carousel with ambient perspective spotlights, live disk physics, and instant presentation sheets.
4. **🖥️ Retro Desktop:** Classic 90s graphical workstation icon desktop with clean grid alignment and custom desktop background.
5. **📑 Sidebar Library:** Split-pane workflow with a scrollable vertical game directory on the left and full game detail panel with screenshots on the right.

---

## The 39 Games Included

Every game includes full offline documentation, keyboard controls mappings, and standalone launch capabilities:

| Game | Category | Install Size | Highlight | Documentation |
| :--- | :--- | :--- | :--- | :--- |
| **2048** | Blocks & Merging | **455 KB** | Classic 4×4 Sliding Number Tile Merge Puzzle | [Manual](../games/2048/README.md) |
| **TetraBlocks** | Blocks & Merging | **287 KB** | Competitive Guideline Falling Blocks Puzzle | [Manual](../games/tetrablocks/README.md) |
| **ByteSnake** | Puzzles & Grid Logic | **203 KB** | Neon Trail Classic Continuous-Growth Snake | [Manual](../games/bytesnake/README.md) |
| **VectorPong** | Board & Tabletop | **209 KB** | High-Framerate Vector Table Tennis Classic | [Manual](../games/vectorpong/README.md) |
| **CyberSweeper** | Puzzles & Grid Logic | **250 KB** | Tactile Logic Grid Deduction Minesweeper | [Manual](../games/cybersweeper/README.md) |
| **DropFour** | Board & Tabletop | **220 KB** | Vertical 7×6 Drop Checker Cabinet with Minimax AI | [Manual](../games/dropfour/README.md) |
| **BrickBash** | Action Arcade | **238 KB** | Arkanoid / Breakout Action with Multi-Ball & Lasers | [Manual](../games/brickbash/README.md) |
| **VoidInvaders** | Action Arcade | **304 KB** | Classic 1978 Space Defense with 55 Marching Aliens | [Manual](../games/voidinvaders/README.md) |
| **VectorDrift** | Action Arcade | **457 KB** | 360° Newtonian Inertia Drift Space Shooter | [Manual](../games/vectordrift/README.md) |
| **CyberFlap** | Action Arcade | **224 KB** | One-Button Retro Gravity Hopper Through Neon Laser Gates | [Manual](../games/cyberflap/README.md) |
| **CyberHop** | Action Arcade | **393 KB** | Multi-Lane Highway Traffic & Floating River Traversal | [Manual](../games/cyberhop/README.md) |
| **CratePusher** | Puzzles & Grid Logic | **363 KB** | Sokoban Spatial Warehouse Puzzle with 50 Stages | [Manual](../games/cratepusher/README.md) |
| **DinoRunner** | Action Arcade | **380 KB** | Authentic Chromium T-Rex Runner with Ducking & Jumping | [Manual](../games/dinorunner/README.md) |
| **WordGuess** | Word & Trivia | **291 KB** | 5-Letter Word Deduction Puzzle with Flip Reveals | [Manual](../games/wordguess/README.md) |
| **OmarchyCity** | Simulation & City | **4.9 MB** | Classic 1989 Metropolis Simulation Homage | [Manual](../games/bytecity/README.md) |
| **GalacticSwarm** | Action Arcade | **1.3 MB** | Authentic 1981 Space Shooter with Boss Tractor Beam | [Manual](../games/galacticswarm/README.md) |
| **ByteMan** | Action Arcade | **488 KB** | Authentic 28×31 Labyrinth with 4 Ghost AI Routines | [Manual](../games/byteman/README.md) |
| **GemSwap** | Puzzles & Grid Logic | **561 KB** | Tactile 8×8 Match-3 Cascading Gem Puzzle | [Manual](../games/gemswap/README.md) |
| **OrbPop** | Casual Aim & Physics | **522 KB** | Hexagonal Bubble Shooter with Ricochet Wall Bounce | [Manual](../games/orbpop/README.md) |
| **KeiRacer** | Action Arcade | **1.2 MB** | Slow Car Racing League • OutRun-Style Pseudo-3D Arcade | [Manual](../games/keiracer/README.md) |
| **Blackjack 21** | Cards & Casino | **659 KB** | Authentic Casino 21 • Omarchy Vector Decks | [Manual](../games/blackjack/README.md) |
| **Chess** | Board Strategy & Chess | **588 KB** | Grandmaster AI • Dual-Contour Vector Pieces | [Manual](../games/chess/README.md) |
| **Checkers** | Board Strategy & Checkers | **511 KB** | Tactical Draughts AI • Dual-Contour Vector Discs | [Manual](../games/checkers/README.md) |
| **Solitaire** | Cards & Casino | **602 KB** | Klondike Solitaire • 3D Cards & Vector Decks | [Manual](../games/solitaire/README.md) |
| **Video Poker** | Cards & Casino | **721 KB** | 8-Game Video Terminal • 1984 CRT & Cyber Glass | [Manual](../games/videopoker/README.md) |
| **Backgammon** | Board & Tabletop | **355 KB** | Classic 2-Player Point-To-Point Board Strategy | [Manual](../games/backgammon/README.md) |
| **Reversi** | Board & Tabletop | **427 KB** | Timeless 8×8 Territorial Disc-Flipping Strategy | [Manual](../games/reversi/README.md) |
| **Bīdama** | Casual Aim & Physics | **492 KB** | Artisanal Japanese Tatami Glass Marbles & Pitch Line Cascades | [Manual](../games/bidama/README.md) |
| **OmarchyBolo II** | Action Arcade | **1.0 MB** | Classic tactical armored tank warfare inspired by Stuart Cheshire's Bolo (*TypeScript multiplatform: native desktop & direct browser via WebRTC*). | [Manual](../games/omarchybolo/README.md) |
| **Starframe** | Action Arcade | **1.0 MB** | Tactical Neon Vector Starfighter Combat & Kinetic Ramming | [Manual](../games/starframe/README.md) |
| **Slime's Adventure** | Action Arcade | **1.1 MB** | Subterranean Cavern Slime Gravity Runner | [Manual](../games/slimesadventure/README.md) |
| **Dr. Virus** | Blocks & Merging | **544 KB** | Retro Medical Virus Elimination Puzzle | [Manual](../games/drvirus/README.md) |
| **WordCircle** | Word & Trivia | **571 KB** | Circular Anagram Crossword Puzzle Adventure | [Manual](../games/wordcircle/README.md) |
| **Parking Jam** | Puzzles & Grid Logic | **1.3 MB** | Tactile Sliding Vehicle Gridlock Escape Puzzle | [Manual](../games/parkingjam/README.md) |
| **Nuts Sort** | Puzzles & Grid Logic | **1.0 MB** | Tactile Isometric Nut & Bolt Color Sorting Puzzle | [Manual](../games/nutssort/README.md) |
| **Fold** | Puzzles & Grid Logic | **1.2 MB** | Tactile Japanese Origami Crease & Geometric Fold Puzzle | [Manual](../games/fold/README.md) |
| **Mahjong Solitaire** | Puzzles & Grid Logic | **1.0 MB** | True 3D Hardware-Accelerated Obsidian Tile Matching Solitaire | [Manual](../games/mahjongsolitaire/README.md) |
| **Pipe Punk** | Puzzles & Grid Logic | **1.1 MB** | Steampunk Victorian Municipal Boiler Pipe Routing Puzzle | [Manual](../games/pipepunk/README.md) |
| **Sky Ace** | Action Arcade | **40.6 MB** | 194X Global Air War • 10 Theaters & 3D Warbirds (*Python / PySide6 QPainter engine with 3D pre-baked warbirds, bank physics & carrier landings*). | [Manual](../games/skyace/README.md) |

---

## How to Install

Install Omarchy Arcade however you prefer—as a fast one-command setup, an official native package, a portable executable, or a flatpak container.

### 1. One-Line Automated Installer (Fastest for Omarchy)

Run this single command in your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash
```

**What this sets up automatically:**
- Installs Qt6 dependencies (`python-pyside6`, `qt6-declarative`, `qt6-svg`, `qt6-multimedia`) via `pacman`.
- Symlinks the `arcade` CLI command into `~/.local/bin/arcade`.
- Adds the application icon to your system menu (Walker / Rofi / Fuzzel / App Menu).
- Enables terminal launch via `arcade`.

---

### 2. Native Arch / Omarchy Package (`makepkg` / `pacman`)

Build and install a native package managed directly by your system package manager:

```bash
git clone https://github.com/bigcjat/omarchyarcade.git
cd omarchyarcade
makepkg -si
```

*Uninstall cleanly at any time with `sudo pacman -R omarchy-arcade`.*

---

### 3. Portable AppImage (Zero-Install Executable)

Download the standalone `Omarchy_Arcade-x86_64.AppImage` from [GitHub Releases](https://github.com/bigcjat/omarchyarcade/releases), make it executable, and run:

```bash
chmod +x Omarchy_Arcade-x86_64.AppImage
./Omarchy_Arcade-x86_64.AppImage
```

*(You can also build the AppImage locally anytime with `./packaging/appimage/build_appimage.sh`).*

---

### 4. Flatpak (Sandboxed KDE Qt6 Runtime)

Build and install locally using Flatpak:

```bash
cd packaging/flatpak
flatpak-builder --user --install --force-clean build-dir org.omarchy.Arcade.yml
flatpak run org.omarchy.Arcade
```

---

## Keyboard Controls Cheatsheet

| Key | Action |
| :--- | :--- |
| **`←` `↑` `→` `↓`** / **`H` `J` `K` `L`** | Navigate through games across the grid or list |
| **`1` – `9`** | Jump directly to category tab (*1: Featured, 2: Library/All, 3: Action, 4: Puzzles...*) |
| **`[` / `]`** or **`Tab` / `Shift+Tab`** | Cycle through categories forward / backward |
| **`/`** or **`Ctrl+F`** | Instant search filter (*type to find any title or tag*) |
| **`Escape`** | Close search / close game detail modal / back to grid |
| **`Enter` / `Space`** | Open game presentation sheet (*press Enter again to play*) |
| **`?` / `F1`** | Open About & Credits dialog |
| **`M`** | Toggle audio mute across all games |

---

## Running Standalone Games

Every game can also be run independently from the command line:

```bash
python games/skyace/main.py
python games/2048/main.py
python games/vectordrift/main.py
python games/bytecity/main.py
```

You can also preview games directly in any of Omarchy's 22 color themes:

```bash
python games/dinorunner/main.py --theme tokyonight
python games/wordguess/main.py --theme gruvbox
```

---

## Contributing

* **Adding New Games:** Check out the starter template in [`template/`](../template/).
* **Artwork Prompts:** See [`assets/COVER_ART_GUIDE.md`](../assets/COVER_ART_GUIDE.md) for illustrated box art generation instructions.
