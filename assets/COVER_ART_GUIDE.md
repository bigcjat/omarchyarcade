# Omarchy Arcade • Cover Art & Floppy Disk Design System

A standardized guide for the **Omarchy Arcade Cover Art & Floppy Disk Pipeline**.

> [!IMPORTANT]
> **HOW FLOPPY DISKS WORK IN OMARCHY ARCADE:**
> 1. The launcher (`launcher/main.qml`) dynamically renders all 3.5" floppy disks using [`launcher/FloppyCard.qml`](file:///Users/christhompson/arcade/launcher/FloppyCard.qml).
> 2. Chassis colors, grid header colors, titles, and reference codes are driven from [`catalog.json`](file:///Users/christhompson/arcade/catalog.json).
> 3. `assets/covers/<game_id>.png` is the **4:3 painted retro box art** (1200×896) loaded *inside* the floppy disk label's art window.
> 4. **THERE IS ONLY ONE DISK IMAGE IN THE SYSTEM:** The small 256×256 app icon at `games/<game_id>/assets/disk_icon.png` used for the game window icon (`app.setWindowIcon()`). It is rendered via:
>    ```bash
>    .venv/bin/python tools/render_disk.py <game_id>
>    ```
>    Do NOT create any second disk in `assets/covers/`.

---

## 1. The Cover Art Specification (`assets/covers/<game_id>.png`)

All game cover images must be pure game artwork (no floppy frames, no text overlays):

1. **Dimensions & Aspect Ratio:** **1200 × 896** (standard `4:3` retro box art format).
2. **Subject Matter:** The game's hero action scene, characters, or environment painted in rich retro arcade or anime aesthetic.
3. **Typography & Borders:** **STRICTLY NO TEXT, NO LOGOS, NO FLOPPY FRAMES**. The floppy label, title, and borders are drawn automatically by `FloppyCard.qml`.
4. **Placement:** Saved directly to `assets/covers/<game_id>.png` and referenced in `catalog.json` under `"cover_image"`.

---

## 2. Category-to-Floppy Color Standard (`catalog.json`)

Every game category maps to a distinct 3.5" diskette color in `catalog.json`:

| Category | Floppy Disk Body Tone | Hex Ref | Historical Inspiration | Games in Suite |
| :--- | :--- | :--- | :--- | :--- |
| **Action Arcade** | **Matte Black / Charcoal** | `#232328` | Standard Sony / Maxell HD arcade & console disks | *ByteMan*, *GalacticSwarm*, *VoidInvaders*, *VectorDrift*, *BrickBash*, *CyberHop*, *CyberFlap*, *DinoRunner*, *KeiRacer*, *OmarchyBolo II* |
| **Puzzles & Grid Logic** | **Emerald / Forest Green** | `#059669` | Verbatim Eco & Rainbow Series | *GemSwap*, *CratePusher*, *ByteSnake*, *CyberSweeper* |
| **Blocks & Merging** | **Tangerine / Sunset Orange**| `#EA580C` | Sony Neon Floppy line | *2048*, *TetraBlocks* |
| **Board & Tabletop** | **Classic Cream / Beige** | `#E6DFD3` | Vintage 80s IBM PC, Amiga, and Atari ST diskettes | *DropFour*, *VectorPong*, *Chess*, *Checkers*, *Backgammon*, *Reversi* |
| **Word & Trivia** | **Clean Pure White** | `#F0F0F2` | 90s Shareware & encyclopedia companion disks | *WordGuess* |
| **Simulation & City** | **Neon Teal / Cyan** | `#0891B2` | Sony Color Collection & CAD / engineering disks | *ByteCity* |
| **Casual Aim & Physics**| **Vibrant Violet / Purple** | `#7C3AED` | Imation 90s Creative Series | *OrbPop*, *Bīdama* |
| **Cards & Casino** | **Ruby / Cherry Red** | `#DC2626` | 3M Performance Series (playing card suits) | *Blackjack, Solitaire, Video Poker* |
| *Action & Pinball* | *Vibrant Violet / Purple* | `#7C3AED` | 90s Space Cadet & arcade neon | *Omarchy Cadet* |

---

## 3. Box Art Prompt Formula (for `generate_image`)

When creating new cover box art for `assets/covers/<game_id>.png`:

```
A vibrant painted retro arcade box art illustration for [GAME_TITLE]. 
Depicting [GAME_HERO_ACTION_SCENE] in a rich 1980s / 1990s Japanese arcade aesthetic, 
dynamic lighting, dramatic composition, and fine detailed styling. 
STRICTLY NO TEXT, NO LETTERS, NO TYPOGRAPHY, NO LOGOS, NO PUBLISHER BADGES, NO FLOPPY DISK FRAMES. 
Pure full-bleed game scene artwork in 4:3 aspect ratio.
```

---

## 4. Exporting the App Icon (`tools/render_disk.py`)

After adding or updating a game in `catalog.json` with its cover art in `assets/covers/<game_id>.png`:

```bash
# Render the single 256x256 app icon for a game
.venv/bin/python tools/render_disk.py <game_id>

# Or render disk icons for all games in the catalog
.venv/bin/python tools/render_disk.py --all
```

This generates `games/<game_id>/assets/disk_icon.png` (256×256 RGBA transparent, ~13 KB).

### 1. `2048` (Ref: `OA-001`)
* **Category:** Blocks & Merging
* **Floppy Color:** Tangerine Orange (`#EA580C`) with flat silver shutter
* **Grid Color:** Deep Blue
* **Illustration:** $4 \times 4$ colorful numbered tiles merging with glowing 1024 and 2048 golden badges.
* **Bottom Text:** `BLOCKS & MERGING • OA-001`

### 2. `TetraBlocks` (Ref: `OA-002`)
* **Category:** Blocks & Merging
* **Floppy Color:** Tangerine Orange (`#EA580C`) with flat silver shutter
* **Grid Color:** Cyan
* **Illustration:** Iconic 7 tetromino polyomino shapes (T, I, O, L, J, S, Z) falling into a clean matrix.
* **Bottom Text:** `BLOCKS & MERGING • OA-002`

### 3. `ByteSnake` (Ref: `OA-003`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Dark Charcoal
* **Illustration:** Pixelated green neon snake weaving through a grid towards a bright red apple.
* **Bottom Text:** `PUZZLES & GRID • OA-003`

### 4. `VectorPong` (Ref: `OA-004`)
* **Category:** Board & Tabletop
* **Floppy Color:** Classic Vintage Cream (`#E6DFD3`) with flat dark gray shutter
* **Grid Color:** Dark Green
* **Illustration:** Minimalist white vector paddles deflecting a square ball with dotted centerline.
* **Bottom Text:** `BOARD & TABLETOP • OA-004`

### 5. `CyberSweeper` (Ref: `OA-005`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Slate Gray
* **Illustration:** Classic beveled gray grid cells with numbered clues 1, 2, 3, a red flag, and a retro yellow smiley face.
* **Bottom Text:** `PUZZLES & GRID • OA-005`

### 6. `DropFour` (Ref: `OA-006`)
* **Category:** Board & Tabletop
* **Floppy Color:** Classic Vintage Cream (`#E6DFD3`) with flat silver shutter
* **Grid Color:** Navy Blue
* **Illustration:** Blue vertical $7 \times 6$ cabinet grid with alternating red and yellow circular checkers falling into a winning row of 4.
* **Bottom Text:** `BOARD & TABLETOP • OA-006`

### 7. `BrickBash` (Ref: `OA-007`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Electric Cyan
* **Illustration:** Blue vector paddle deflecting glowing energy balls into multi-colored rows of shattering bricks with capsule power-ups.
* **Bottom Text:** `ACTION ARCADE • OA-007`

### 8. `VoidInvaders` (Ref: `OA-008`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Neon Green
* **Illustration:** 1978 space defense player cannon firing upwards at marching rows of pixelated aliens and green bunkers.
* **Bottom Text:** `ACTION ARCADE • OA-008`

### 9. `VectorDrift` (Ref: `OA-009`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** White Wireframe
* **Illustration:** Sharp triangular wireframe vector spacecraft drifting sideways while firing lasers at fracturing geometric asteroids.
* **Bottom Text:** `ACTION ARCADE • OA-009`

### 10. `CyberFlap` (Ref: `OA-010`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Cyan
* **Illustration:** Minimalist vector bird hopper flapping upward between two neon glowing barrier gate pillars.
* **Bottom Text:** `ACTION ARCADE • OA-010`

### 11. `CyberHop` (Ref: `OA-011`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Lime Green
* **Illustration:** Cute geometric green frog hopping across multi-lane sports car traffic and floating river logs.
* **Bottom Text:** `ACTION ARCADE • OA-011`

### 12. `CratePusher` (Ref: `OA-012`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Warm Brown
* **Illustration:** Top-down warehouse puzzle showing a worker pushing wooden crates onto red diamond target goal tiles.
* **Bottom Text:** `PUZZLES & GRID • OA-012`

### 13. `DinoRunner` (Ref: `OA-013`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Charcoal
* **Illustration:** Pixelated silhouette T-Rex sprinting across desert dunes, leaping over cacti with a Pterodactyl overhead.
* **Bottom Text:** `ACTION ARCADE • OA-013`

### 14. `WordGuess` (Ref: `OA-014`)
* **Category:** Word & Trivia
* **Floppy Color:** Clean Pure White (`#F0F0F2`) with flat silver shutter
* **Grid Color:** Olive Green
* **Illustration:** $5 \times 6$ letter deduction grid with green, yellow, and gray flipped letter tiles.
* **Bottom Text:** `WORD & TRIVIA • OA-014`

### 15. `ByteCity` (Ref: `OA-015`)
* **Category:** Simulation & City
* **Floppy Color:** Neon Teal (`#0891B2`) with flat silver shutter
* **Grid Color:** Cyan
* **Illustration:** Isometric miniature city with colorful RCI commercial towers, residential homes, power lines, and roads.
* **Bottom Text:** `SIMULATION • OA-015`

### 16. `GalacticSwarm` (Ref: `OA-016`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Crimson Red
* **Illustration:** White and red dual-fighter ship firing twin missiles at swooping Galaga alien insect formations and Boss tractor beam.
* **Bottom Text:** `ACTION ARCADE • OA-016`

### 17. `ByteMan` (Ref: `OA-017`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Royal Blue
* **Illustration:** Flat pixel art yellow chomper pursuing dots while being chased by colorful retro ghosts.
* **Bottom Text:** `ACTION ARCADE • OA-017`

### 18. `GemSwap` (Ref: `OA-018`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Purple
* **Illustration:** Flat geometric gemstones (Ruby hexagon, Sapphire square, Emerald diamond, Topaz triangle, and sparkling Hypercube).
* **Bottom Text:** `PUZZLES & GRID • OA-018`

### 19. `OrbPop` (Ref: `OA-019`)
* **Category:** Casual Aim & Physics
* **Floppy Color:** Vibrant Violet (`#7C3AED`) with flat silver shutter
* **Grid Color:** Light Blue
* **Illustration:** Angled arrow launcher aiming a colored bubble towards hanging clusters of vibrant pastel bubbles on a descending ceiling.
* **Bottom Text:** `CASUAL PHYSICS • OA-019`

### 20. `KeiRacer` (Ref: `OA-020`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Neon Magenta
* **Illustration:** White Kei truck and vintage camper bus drifting side-by-side on an 80s coastal highway beneath a glowing retro sun.
* **Bottom Text:** `ACTION ARCADE • OA-020`

### 21. `Blackjack 21` (Ref: `OA-021`)
* **Category:** Cards & Casino
* **Floppy Color:** Ruby Red (`#DC2626`) with flat silver shutter
* **Grid Color:** Casino Emerald Green (`#064E3B`)
* **Illustration:** Mystical cloaked cardmaster in ornate retro-fantasy robes dealing radiant glowing Ace of Spades with electric filigree alongside court cards and crystalline poker chips in an arched gothic hall.
* **Bottom Text:** `CARDS & CASINO • OA-021`

### 22. `Chess` (Ref: `OA-022`)
* **Category:** Board Strategy & Chess
* **Floppy Color:** Midnight Obsidian (`#1E293B`) with flat silver shutter
* **Grid Color:** Electric Cyan (`#00F0FF`)
* **Illustration:** Dual cloaked cyber-grandmasters playing on a luminous holographic chessboard overlooking an ancient citadel under a galaxy sky.
* **Bottom Text:** `BOARD STRATEGY • OA-022`

### 23. `Checkers` (Ref: `OA-023`)
* **Category:** Board Strategy & Checkers
* **Floppy Color:** Midnight Obsidian (`#1E293B`) with flat silver shutter
* **Grid Color:** Electric Cyan (`#00F0FF`)
* **Illustration:** Two cloaked tacticians playing with glowing neon discs across an 8x8 checkerboard overlooking a cosmic fantasy fortress.
* **Bottom Text:** `BOARD STRATEGY • OA-023`

### 24. `Solitaire` (Ref: `OA-024`)
* **Category:** Cards & Casino
* **Floppy Color:** Ruby Red (`#DC2626`) with flat silver shutter
* **Grid Color:** Electric Cyan (`#00F0FF`)
* **Illustration:** Cascading columns of illuminated cards with glowing Aces hovering in golden foundation pedestals, observed by a cloaked grandmaster in a grand cathedral arcade hall under a cosmic night sky.
* **Bottom Text:** `CARDS & CASINO • OA-024`

### 25. `Video Poker` (Ref: `OA-025`)
* **Category:** Cards & Casino
* **Floppy Color:** Ruby Red (`#DC2626`) with flat silver shutter
* **Grid Color:** Golden Yellow (`#F59E0B`)
* **Illustration:** Glowing retro video poker arcade cabinet displaying a Royal Flush hand on a cobalt-blue CRT screen with HELD stamps and arcade push buttons.
* **Bottom Text:** `CARDS & CASINO • OA-025`

### 26. `Backgammon` (Ref: `OA-026`)
* **Category:** Board & Tabletop
* **Floppy Color:** Classic Vintage Cream (`#E6DFD3`) with flat silver shutter
* **Grid Color:** Cyan (`#06B6D4`)
* **Illustration:** Dual point triangles with contrasting black and white checkers, pair of tumbling wooden dice, and a brass doubling cube on a polished mahogany board.
* **Bottom Text:** `BOARD & TABLETOP • OA-026`

### 27. `Reversi` (Ref: `OA-027`)
* **Category:** Board & Tabletop
* **Floppy Color:** Classic Vintage Cream (`#E6DFD3`) with flat silver shutter
* **Grid Color:** Emerald Green (`#059669`)
* **Illustration:** An 8×8 baize green game grid with circular black and white stones flipping in mid-air along glowing valid move crosshairs.
* **Bottom Text:** `BOARD & TABLETOP • OA-027`

### 28. `Bīdama` (Ref: `OA-028`)
* **Category:** Casual Aim & Physics
* **Floppy Color:** Vibrant Violet (`#7C3AED`) with flat silver shutter
* **Grid Color:** Gold (`#D4AF37`)
* **Illustration:** Serene Japanese veranda on woven tatami matting with handcrafted hinoki chutes and luminous glass bīdama marbles aligning on a black urushi lacquer pitch line with gold kintsugi trim.
* **Bottom Text:** `CASUAL PHYSICS • OA-028`

### 29. `OmarchyBolo II` (Ref: `OA-029`)
* **Category:** Action Arcade
* **Floppy Color:** Tactical Armor Slate (`#222A22`) with flat silver shutter
* **Grid Color:** Radar Green (`#22C55E`)
* **Illustration:** Island archipelago battlefield painted in classic 1980s computer box art style: M4 battle tank maneuvering through pine forests, tactical pillbox bunkers firing defensive salvos, naval aircraft carrier on ocean waterways, and tactical radar rings.
* **Bottom Text:** `ACTION ARCADE • OA-029`

### 30. `Starframe` (Ref: `OA-030`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Neon Cyan (`#00E5FF`)
* **Illustration:** High-speed vector wireframe starfighter engaging alien dreadnoughts in deep cosmos with neon shield flares.
* **Bottom Text:** `ACTION ARCADE • OA-030`

### 31. `Slime's Adventure` (Ref: `OA-031`)
* **Category:** Action Arcade
* **Floppy Color:** Matte Black (`#232328`) with flat silver shutter
* **Grid Color:** Neon Cyan (`#00E5FF`)
* **Illustration:** Vibrant Japanese dough-rolling blue slime bounding through subterranean crystal caverns and leaping over stalagmites.
* **Bottom Text:** `ACTION ARCADE • OA-031`

### 32. `Dr. Virus` (Ref: `OA-032`)
* **Category:** Blocks & Merging
* **Floppy Color:** Tangerine Orange (`#EA580C`) with flat silver shutter
* **Grid Color:** Rose Pink (`#F38BA8`)
* **Illustration:** Two-tone vitamin capsules tumbling into a glass beaker targeting mischievous animated viral microbes.
* **Bottom Text:** `BLOCKS & MERGING • OA-032`

### 33. `WordCircle` (Ref: `OA-033`)
* **Category:** Word & Trivia
* **Floppy Color:** Clean Pure White (`#F0F0F2`) with flat silver shutter
* **Grid Color:** Sky Blue (`#38BDF8`)
* **Illustration:** Circular brass compass anagram disc projecting illuminated letter tiles into an interlocking crossword grid.
* **Bottom Text:** `WORD & TRIVIA • OA-033`

### 34. `Parking Jam` (Ref: `OA-034`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Sky Blue (`#38BDF8`)
* **Illustration:** Colorful isometric retro Japanese city parking lot with mini vans, kei cars, and ambulances maneuvering out of gridlock.
* **Bottom Text:** `PUZZLES & GRID • OA-034`

### 35. `Nuts Sort` (Ref: `OA-035`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Amber Gold (`#F59E0B`) with flat silver shutter
* **Grid Color:** Sapphire Blue (`#3B82F6`)
* **Illustration:** Tactile industrial workshop bench with vertical threaded brass and steel bolts holding colorful hexagonal nuts.
* **Bottom Text:** `PUZZLES & GRID • OA-035`

### 36. `Fold` (Ref: `OA-036`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Slate Navy (`#1E293B`)
* **Illustration:** Delicate origami washi paper geometry creasing and folding in dramatic perspective on a minimalist studio surface.
* **Bottom Text:** `PUZZLES & GRID • OA-036`

### 37. `Mahjong Solitaire` (Ref: `OA-037`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Emerald Green (`#059669`) with flat silver shutter
* **Grid Color:** Slate Navy (`#1E293B`)
* **Illustration:** Intricately carved ivory and obsidian Mahjong tiles in five-tier pyramidal elevation with gold leaf engravings.
* **Bottom Text:** `PUZZLES & GRID • OA-037`

### 38. `Pipe Punk` (Ref: `OA-038`)
* **Category:** Puzzles & Grid Logic
* **Floppy Color:** Terracotta / Boiler Rust (`#C2410C`) with flat silver shutter
* **Grid Color:** Slate Navy (`#1E293B`)
* **Illustration:** Victorian steampunk boiler subterranean engine room with glowing emerald fluid pumping through polished copper and dark cast-iron piping, analog brass gauges, and steam valves.
* **Bottom Text:** `PUZZLES & GRID LOGIC • OA-038`

