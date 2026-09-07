# Omarchy Arcade • Cover Art & Floppy Disk Design System

A standardized prompt engineering and visual design guide for generating **Flat 2D Vector Floppy Disk Cover Art** for the Omarchy Arcade Launcher ("Mini Steam").

---

## 1. Visual Standard & Style Directives

All game covers must strictly follow these aesthetic guidelines to maintain complete visual cohesion across the entire arcade catalog:

1. **Format & Ratio:** **`3:4` Vertical Portrait** (Steam capsule standard).
2. **Perspective:** Perfectly flat, 2D straight-on front orthographic vector illustration.
3. **No 3D Realism:** Zero photographic textures, zero realistic lighting, zero 3D rendering, zero gloss/reflections, zero drop shadows.
4. **Background:** Pure solid black (`#000000`) surrounding the isolated floppy disk silhouette.
5. **Physical Hardware Details:**
   * 3.5" HD floppy diskette chassis with classic beveled corners, slider track, and write-protect notch.
   * Flat silver or gray metal sliding shutter at the top with clean rectangular window cutouts.
6. **Sega Master System Label Layout:**
   * **Top Banner:** Subtle vector grid pattern header with `OMARCHY ARCADE` typography.
   * **Center Title:** Bold, clean 2D retro arcade typography.
   * **Center Graphic Window:** Clean flat 2D geometric vector or pixel illustration showing the game's core action.
   * **Bottom Technical Strip:** `[CATEGORY] • OA-[REF_NUMBER]` *(Never include MB sizes to avoid user confusion and keep artwork version-independent)*.

---

## 2. Category-to-Floppy Color Standard

To give players an instant visual cue across the launcher library, every game category maps to a distinct, historically authentic 3.5" diskette color:

| Category | Floppy Disk Body Tone | Hex Ref | Historical Inspiration | Games in Suite |
| :--- | :--- | :--- | :--- | :--- |
| **Action Arcade** | **Matte Black / Charcoal** | `#232328` | Standard Sony / Maxell HD arcade & console disks | *ByteMan*, *GalacticSwarm*, *VoidInvaders*, *VectorDrift*, *BrickBash*, *CyberHop*, *CyberFlap*, *DinoRunner* |
| **Puzzles & Grid Logic** | **Emerald / Forest Green** | `#059669` | Verbatim Eco & Rainbow Series | *GemSwap*, *CratePusher*, *ByteSnake*, *CyberSweeper* |
| **Blocks & Merging** | **Tangerine / Sunset Orange**| `#EA580C` | Sony Neon Floppy line | *2048*, *TetraBlocks* |
| **Board & Tabletop** | **Classic Cream / Beige** | `#E6DFD3` | Vintage 80s IBM PC, Amiga, and Atari ST diskettes | *DropFour*, *VectorPong* *(Future: Chess, Checkers, Othello)* |
| **Word & Trivia** | **Clean Pure White** | `#F0F0F2` | 90s Shareware & encyclopedia companion disks | *WordGuess* *(Future: WordWheel, WordGrid)* |
| **Simulation & City** | **Neon Teal / Cyan** | `#0891B2` | Sony Color Collection & CAD / engineering disks | *ByteCity* |
| **Casual Aim & Physics**| **Vibrant Violet / Purple** | `#7C3AED` | Imation 90s Creative Series | *OrbPop* *(Future: NeonDrop / Peggle)* |
| *Cards & Casino (Future)*| *Ruby / Cherry Red* | `#DC2626` | 3M Performance Series (playing card suits) | *Blackjack, Spades, Solitaire* |
| *Memory & Sound (Future)*| *Canary Yellow* | `#EAB308` | Memorex High-Visibility Disks | *ChromaTone, PairMatch* |
| *Roguelite / RPG (Future)*| *Cobalt / Royal Blue* | `#1D4ED8` | 90s UNIX / PC Dungeon diskettes | *TinyCrawl* |

---

## 3. The Reusable Master Prompt Formula

```
A flat 2D vector graphic illustration of a 3.5-inch retro computer floppy disk, completely flat minimalist graphic design, no 3D lighting, no photographic realism, no drop shadows, no gradients. Centered isolated floppy disk on a pure solid white background (#FFFFFF). 
The disk body is flat [FLOPPY_COLOR] plastic with clean geometric cutouts, a high-density HD notch, and a flat [SHUTTER_COLOR] metal shutter at the top. 
On the disk is a crisp flat adhesive label in classic Sega Master System packaging style: 
a subtle [GRID_COLOR] vector grid header with 'OMARCHY ARCADE' text, 
bold clean 2D retro title '[GAME_TITLE]', 
and a flat 2D geometric vector illustration showing [GAME_HERO_ILLUSTRATION]. 
At the bottom of the label in small crisp typography: '[CATEGORY] • OA-[REF_NUMBER]'. 
Clean line art, flat vector icon aesthetic, solid vibrant colors, sticker graphic design.
```

---

## 4. Pre-Engineered Prompts for All 19 Shipped Games

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
