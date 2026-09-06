# Omarchy Arcade • Master Game Wishlist

A comprehensive roadmap of arcade classics, retro favorites, and desktop puzzles planned for the **Omarchy Arcade** suite.

The goal of this project is to become **THE definitive default gaming suite on Omarchy / Linux desktops**, providing a diverse, cohesive catalog with something for every type of player in a single unified launcher.

---

## Suite Architecture & Design Standards

All games in the Omarchy Arcade suite adhere to strict engineering and aesthetic principles:
* **Native & Lightweight:** Pure QML / QtQuick with hardware acceleration, instantaneous sub-second launch, and low RAM footprints (<40MB).
* **100% Vector & Geometric Art:** No heavy bitmap textures or raster sprites. All visuals are procedurally rendered with scalable vector graphics (SVG), geometric shapes, smooth bezier curves, and crisp typography.
* **Omarchy Theme Synchronization:** Live dynamic palette adaptation via `~/.config/omarchy/current/theme/colors.toml` across all 22 system themes.
* **Tiling WM Friendly:** Scales seamlessly from compact side-tiles (e.g. 340×500) to full widescreen displays.
* **Keyboard-First Controls:** Full arrow, WASD, and Vim (`H/J/K/L`) keybindings, with responsive mouse/touch fallback.
* **Zero-Overhead Audio:** In-memory low-latency audio via native macOS CoreAudio and Linux PipeWire/ALSA, defaulted to muted.
* **Shared Component Architecture:** Universal reusable engines (Card System, 8×8 Board System, Sound Engine, Theme Watcher) preventing duplicated effort.
* **Legal Safety:** Public-domain mechanics and clean, trademark-safe titles.

---

## Current Suite Status

| Status | Game | Category | Description |
| :--- | :--- | :--- | :--- |
| **Complete** | **[2048](games/2048/)** | Numbers & Logic | Classic $4 \times 4$ sliding tile merge puzzle with CRT startup & harmonic chimes |
| **Complete** | **[TetraBlocks](games/tetrablocks/)** | Falling Blocks | Classic falling block puzzle with SRS wall kicks, 7-bag, hold, slam, & line FX |
| **Complete** | **[ByteSnake](games/snake/)** | Reflex & Arcade | Classic neon snake with smooth vector segments, directional eyes, speed pacing & fruit spawns |
| **Complete** | **[VectorPong](games/pong/)** | Sports & Retro | High-framerate vector tennis with rally speed acceleration, 1P CPU (Novice/Pro/Master) & 2P local |
| **Complete** | **[CyberSweeper](games/minesweeper/)** | Deduction & Logic | Tactile minesweeper with first-click safety, flood fill, chord clicking, digital counters & smiley face |
| **Complete** | **[DropFour](games/connect4/)** | Board Strategy | Vertical $7 \times 6$ connect-four cabinet with animated hover drop indicator & Minimax AI |
| **Complete** | **[BrickBash](games/brickbreaker/)** | Action Arcade | Arkanoid/Breakout with paddle bounce angles, multi-ball, laser cannons, power-up capsules & spark particles |
| **Complete** | **[VoidInvaders](games/spaceinvaders/)** | Retro Defense | Classic 1978 space defense with 55 procedural marching aliens, destructible bunkers & mystery flying UFO |
| **Complete** | **[VectorDrift](games/asteroids/)** | Retro Action | 360° vector wireframe space shooter with asteroid splitting, thrusters & lasers |
| **Complete** | **[CyberFlap](games/flappy/)** | Reflex Arcade | 1-button retro gravity hopper navigating through neon laser barrier gate pillars |
| **Complete** | **[CyberCross](games/frogger/)** | Action Traversal | Multi-lane vehicle traffic and floating river platform grid-hopping classic |
| **Complete** | **[CratePusher](games/sokoban/)** | Spatial Puzzle | Japanese warehouse crate puzzle with 50 canonical stages, smooth subpixel push easing, dust FX, undo stack & level selector |
| **Complete** | **[DinoRunner](games/runner/)** | Reflex Arcade | Authentic Chromium T-Rex endless runner with ducking, jumping, Pterodactyls, day/night invert & theme synchronization |
| **Complete** | **[WordGuess](games/wordle/)** | Word & Logic | 5-letter deduction puzzle with tile reveals, dictionary validation & on-screen keyboard |
| **Complete** | **[ByteCity](games/bytecity/)** | Simulation & City Building | Authentic 1989 Micropolis C++ simulation engine with 2.5D isometric vector visuals, RCI zoning, power, budget & disasters |
| **Complete** | **[GalacticSwarm](games/galaga/)** | Retro Space Shooter | Authentic 1981 Namco Galaga clone with choreographed flight waves, Boss escorts, tractor beam dual-fighter, stage medals & Results tally |
| **Planned** | **Arcade Launcher** | Central Hub | Unified desktop dashboard with game grid, artwork, stats, & settings |

---

## Complete Wishlist Catalog

### 1. Retro Action & Classic Coin-Op

#### 🎮 Pac-Man (*"ByteMan"* / *"Neon Maze"*)
* **Concept:** Navigate a neon maze eating pellets while evading four distinct ghost AI personalities.
* **Key Mechanics:**
  * Authentic ghost behaviors: Chaser (Blinky), Ambusher (Pinky), Fickle (Inky), and Coward (Clyde).
  * Power Pellets (Energizers) that turn ghosts vulnerable for cascading combo scores.
  * Fruit bonuses, side-tunnel screen wraps, and rising level speeds.
* **Complexity:** Medium-High

#### 🚀 Galaga (*"Galactic Swarm"*)
* **Concept:** Fixed space shooter with swooping insectoid formations.
* **Key Mechanics:**
  * Dive-bombing enemy waves with distinct loop-de-loop flight paths.
  * Boss Galaga tractor beam that can capture the player's fighter.
  * Dual-Fighter mechanic: rescue your captured ship to double your firing rate!
  * Bonus "Challenging Stages" with target-hit accuracy tracking.
* **Complexity:** Medium-High

#### 👾 Space Invaders (*"Void Invaders"*)
* **Concept:** The quintessential 1978 vertical defense shooter.
* **Key Mechanics:**
  * 5 rows of advancing invaders that march and accelerate as their numbers dwindle.
  * Destructible defensive shields/bunkers.
  * Mystery flying UFO providing high-value bonus targets.
* **Complexity:** Medium

#### ☄️ Asteroids (*"Vector Drift"*)
* **Concept:** 360° space drift with inertia physics and asteroid fragmentation.
* **Key Mechanics:**
  * Newtonian thrust, rotational momentum, and full screen-edge wraparound.
  * Asteroid splitting (Large $\rightarrow$ Medium $\rightarrow$ Small).
  * Flying saucer encounters and panic hyperspace jump.
* **Complexity:** Medium

#### 🧱 Breakout (*"BrickBash"*)
* **Concept:** High-energy ball and paddle block-breaker.
* **Key Mechanics:**
  * Segmented paddle angle bounces and spin control.
  * Power-up drops: Multiball, Laser Paddle, Extended Paddle, Sticky Surface, and Slow-Mo.
  * Destructible brick varieties (armored, explosive, multi-hit).
* **Complexity:** Low-Medium

#### 🐸 Frogger (*"CyberCross"*)
* **Concept:** High-stakes arcade road and river crossing.
* **Key Mechanics:**
  * Hop through multi-lane vehicle traffic and leap across moving floating logs and turtles.
  * Time limit per frog with 5 home slots to fill.
  * Bonus fly pickups and floating hazard obstacles.
* **Complexity:** Low-Medium

#### 🦖 T-Rex Endless Runner (*"DinoRunner"*)
* **Concept:** Authentic Chromium T-Rex endless runner with 1-button jumping and ducking.
* **Key Mechanics:**
  * Exact Chromium physics, speed acceleration, jump heights, fast-fall drop, and dynamic obstacle gap formulas.
  * Cacti clusters, flying Pterodactyls with multi-altitude flight, day/night invert, and theme synchronization.
* **Complexity:** Low

#### 🖌️ Maze Paint (*"NeonRoller"*)
* **Concept:** Fast-paced maze-coloring puzzle (inspired by *Roller Splat* / *Tomb of the Mask*).
* **Key Mechanics:**
  * Swipe or use arrow/Vim keys to slide a paint roller down corridors until it hits a wall.
  * Leaves a trail of glowing neon paint matching the desktop accent color.
  * 50+ compact geometric maze stages; solve by painting 100% of the floor tiles.
* **Complexity:** Low

#### 🕹️ Pinball (*"CyberPin"*)
* **Concept:** 2D retro arcade pinball table with glowing neon vector art.
* **Key Mechanics:**
  * Real-time 2D rigid-body ball physics (impulse solver).
  * Dual flippers, spring plunger, bumpers, drop targets, ramps, and kickers.
  * Multiball mode, lane multipliers, and table nudge (with tilt penalty).
* **Complexity:** High

---

### 2. Puzzles & Grid Logic

#### 🪵 10×10 Block Puzzle (*"PolyGrid"*)
* **Concept:** Relaxing, gravity-free polyomino block placement.
* **Key Mechanics:**
  * Place sets of 3 polyomino shapes onto a $10 \times 10$ grid.
  * Completing any horizontal row or vertical column clears it instantly.
  * No timer and no falling pieces — pure zen strategy. Reuses TetraBlocks vector block styling.
* **Complexity:** Low-Medium

#### 🧪 Water / Color Sort (*"ColorFlow"*)
* **Concept:** Visually soothing liquid/ring sorting puzzle.
* **Key Mechanics:**
  * 4–12 test tubes containing multi-colored layers of liquid.
  * Pour the top color band into an adjacent tube if colors match and space remains.
  * Smooth bezier liquid pouring animations and bubbling chimes.
* **Complexity:** Low-Medium

#### 🚗 Escape / Unblock (*"GridEscape"*)
* **Concept:** Mechanical sliding block logic puzzle (inspired by *Rush Hour*).
* **Key Mechanics:**
  * $6 \times 6$ grid packed with horizontal and vertical vehicle blocks.
  * Slide obstacles back and forth to open a clear exit channel for the primary accent block.
  * Step counter tracking optimal minimum-move solutions.
* **Complexity:** Low-Medium

#### 🔢 15-Puzzle (*"TileSlide"*)
* **Concept:** The classic 1880 sliding square number puzzle.
* **Key Mechanics:**
  * $4 \times 4$ grid with numbered tiles from 1 to 15 and one empty slot.
  * Slide tiles into the empty space to arrange them in sequential order.
  * Move counter, timer, and parity validator ensuring all generated scrambles are solvable.
* **Complexity:** Low

#### 📦 Dots & Boxes (*"BoxDraft"*)
* **Concept:** Classic pencil-and-paper territory capture game.
* **Key Mechanics:**
  * Grid of dots ($4 \times 4$ up to $8 \times 8$). Players take turns drawing single horizontal or vertical lines.
  * Completing the 4th wall of a $1 \times 1$ box claims it with the player's color and grants a bonus turn.
  * Local 2-Player or tactical AI opponent.
* **Complexity:** Low-Medium

#### 💎 Bejeweled (*"GemSwap"* / *"JewelCraft"*)
* **Concept:** The quintessential $8 \times 8$ tile-swapping match-3 puzzle.
* **Key Mechanics:**
  * Swap adjacent gems to create lines of 3 or more matching colors.
  * Cascade gravity: cleared gems cause upper tiles to drop with chain multipliers.
  * Special gems: Flame Gems (match-4, explosive radius), Star Gems (match-5 T/L shape, laser crosses), and Hypercubes (match-5 in a line, clears all gems of one color).
  * Game modes: Timed Action mode and relaxing Zen/Endless mode.
* **Complexity:** Medium

#### 🐍 Snake (*"Viper"*)
* **Concept:** Classic continuous-growth grid navigation.
* **Key Mechanics:**
  * Instant 4-way response with Vim (`H/J/K/L`), Arrows, and WASD.
  * Smooth neon glow particle trail behind the snake body.
  * Speed acceleration and bonus fruit spawns that tick down on a timer.
* **Complexity:** Low

#### 📦 Sokoban (*"CratePusher"*)
* **Concept:** Japanese warehouse crate-pushing puzzle.
* **Key Mechanics:**
  * Push crates onto designated goal tiles without trapping them against walls or corners.
  * Infinite undo/redo (`U` / `Ctrl+Z`).
  * 50+ progressive level stages with level select menu.
* **Complexity:** Low-Medium

#### 💣 Minesweeper (*"GridSweeper"*)
* **Concept:** Logic grid deduction with numbers revealing neighboring hazards.
* **Key Mechanics:**
  * First-click guarantee: your opening click is never a mine and always opens an expansive zero-cluster.
  * Chord clicking: clicking a satisfied number automatically reveals all unflagged neighbors.
  * Standard presets: Beginner ($9 \times 9$, 10 mines), Intermediate ($16 \times 16$, 40 mines), Expert ($30 \times 16$, 99 mines).
* **Complexity:** Low

#### 🔢 Sudoku (*"SudoQ"*)
* **Concept:** $9 \times 9$ number placement grid with zero guesswork.
* **Key Mechanics:**
  * Pencil note-taking mode for candidate numbers.
  * Row/column/box highlight aids and conflict indicators.
  * Procedural generator with unique solutions across Easy, Medium, Hard, and Expert tiers.
* **Complexity:** Medium

#### ⚡ Pipe Connect / Numberlink (*"CircuitFlow"*)
* **Concept:** Connect matching colored terminal nodes across a circuit grid.
* **Key Mechanics:**
  * Draw non-overlapping flow paths between terminal pairs to fill the entire grid.
  * Grid sizes from $5 \times 5$ (casual) to $10 \times 10$ (complex).
  * Over 100 hand-crafted and procedural puzzle stages.
* **Complexity:** Low-Medium

---

### 3. Word Games *(Daily & Casual Play)*

#### 🔤 Word Finder / Anagram Wheel (*"WordWheel"* / *"WordFlow"*)
* **Concept:** The wildly popular letter-wheel crossword puzzle (inspired by *Wordscapes*).
* **Key Mechanics:**
  * Circular wheel of 5–6 vector letters at the bottom; drag or type to connect letters into words.
  * Found valid words fly up into the crossword-style letter slots.
  * Bonus word bank rewarding extra points for valid words not on the main crossword grid.
  * Embedded offline 12,000-word dictionary.
* **Complexity:** Low-Medium

#### 🟩 Wordle / Lingo (*"ByteWord"*)
* **Concept:** Guess the secret 5-letter word in 6 attempts.
* **Key Mechanics:**
  * Tile color feedback: Green (correct spot), Yellow (in word, wrong spot), Gray (not in word).
  * On-screen virtual keyboard with matching color states + direct keyboard typing.
  * Two modes: "Daily Puzzle" (seeded by date, identical for all Omarchy users) and "Practice" (unlimited).
* **Complexity:** Low

#### 🔠 Boggle / Word Search (*"WordGrid"*)
* **Concept:** Fast-paced word-finding across a random letter grid.
* **Key Mechanics:**
  * $4 \times 4$ letter grid with 2-minute or 3-minute round timers.
  * Trace adjacent letters (horizontal, vertical, diagonal) without reusing the same tile twice.
  * Scored by word length; comprehensive dictionary validation.
* **Complexity:** Medium

---

### 4. Memory & Sound

#### 🎵 Sound Memory (*"ChromaTone"* / *Simon Says*)
* **Concept:** 4-quadrant musical memory game.
* **Key Mechanics:**
  * 4 glowing colored circular arcs (Red, Blue, Green, Yellow) that pulse to harmonic synthesizer tones.
  * Plays an ever-expanding sequence of tones that the player must repeat back.
  * Increasing speed and visual flare with local high-streak persistence.
* **Complexity:** Low

#### 🃏 Tile Match / Memory (*"PairMatch"* / *Concentration*)
* **Concept:** Classic face-down card flipping and pair matching.
* **Key Mechanics:**
  * Grids of $4 \times 4$ (16 tiles), $6 \times 6$ (36 tiles), or $8 \times 6$ (48 tiles).
  * Flip two cards to reveal matching vector icons or card ranks; matched pairs lock open.
  * Tracks fewest moves and fastest completion times.
* **Complexity:** Low

---

### 5. Casual Aim & Physics

#### 🫧 Bubble Shooter / Bust-a-Move (*"OrbPop"*)
* **Concept:** Aim and fire colored orbs upwards to match clusters of 3+.
* **Key Mechanics:**
  * Rotatable arrow launcher with angled wall-bounce trajectories.
  * Matching 3+ identical colors pops the cluster; detached hanging orbs fall for massive bonus points.
  * Descending ceiling: roof drops down after a set number of non-clearing shots.
* **Complexity:** Medium

#### 🪙 Peggle / Pachinko (*"NeonDrop"*)
* **Concept:** Fire metal balls through a pegboard to clear target pegs.
* **Key Mechanics:**
  * Aim angle launcher at the top; ball bounces through round and brick pegs.
  * Moving bucket at the bottom for free ball catches.
  * Slow-motion dramatic zoom on the final target peg with celebratory fanfare.
* **Complexity:** Medium

---

### 6. Cards & Casino Classics

> [!IMPORTANT]
> **Shared Card Design System (`shared/cards/`):**
> All card games share a single, unified card component library (`Card.qml`) and deck engine (`Deck.js`) rather than reinventing card rendering per title.
> * **Zero Duplication:** Reusable vector suit pips, face cards (J, Q, K), 3D flip rotation, and drop shadows.
> * **Theme Consistency:** Card backs dynamically adapt their accent patterns and colors to the active Omarchy theme.
> * **Shared Deck Engine:** Fisher-Yates shuffling, shoe dealing, discard trays, and hand valuation are shared across Blackjack, Spades, Solitaire, and future card titles.

#### 🃏 Blackjack (*"Arcade 21"*)
* **Concept:** Fast-paced single-player casino blackjack against the automated dealer.
* **Card Integration:** Uses `shared/cards/Card.qml` for dealer and player hands, split hands, and deck shoe.
* **Key Mechanics:**
  * Standard Vegas rules: Dealer hits soft 17, Blackjack pays 3:2.
  * Full actions: Hit, Stand, Double Down, Split (pairs), and Insurance.
  * Persistent chip bankroll saved via `QSettings`.
  * Multi-deck shoe with realistic shuffle animation.
* **Complexity:** Low-Medium

#### ♠️ Spades (*"Arcade Spades"*)
* **Concept:** The premier 4-player trick-taking partnership card game.
* **Card Integration:** Uses `shared/cards/Card.qml` with 4 card hands around the table.
* **Key Mechanics:**
  * Bidding phase: Bid your predicted tricks (or Nil / Blind Nil).
  * Trick-taking phase: Spades are always trump; penalty bags for exceeding bids.
  * Partner AI and opponent AI with smart card tracking. First to 500 points wins.
* **Complexity:** Medium-High

#### 🂡 Klondike Solitaire (*"Arcade Solitaire"*)
* **Concept:** Classic 7-column tabletop patience solitaire.
* **Card Integration:** Uses `shared/cards/Card.qml` for tableau columns, stockpile, waste pile, and 4 foundations.
* **Key Mechanics:**
  * Draw-1 (Casual) and Draw-3 (Vegas rules) modes.
  * Auto-move to foundations on double-click/right-click.
  * Iconic victory celebration with bouncing cards cascading across the screen.
* **Complexity:** Medium

#### 🂠 FreeCell (*"Arcade FreeCell"*)
* **Concept:** 100% open-information patience solitaire.
* **Card Integration:** Uses `shared/cards/Card.qml` with 4 free cells, 4 foundation piles, and 8 tableau cascades.
* **Key Mechanics:**
  * All 52 cards are dealt face up at the start (99.9% of deals are mathematically winnable).
  * Temporary storage in 4 free cells; multi-card supermoves based on available free cells.
  * Classic numbered seed deals (#1 to #32000).
* **Complexity:** Medium

#### 🕷️ Spider Solitaire (*"Arcade Spider"*)
* **Concept:** 2-deck column building patience game.
* **Card Integration:** Uses `shared/cards/Card.qml` across 10 tableau columns and stock deals.
* **Key Mechanics:**
  * Three difficulty tiers: 1-Suit (Spades only - Relaxed), 2-Suits (Spades & Hearts - Medium), and 4-Suits (Master).
  * Build complete descending King-to-Ace sequences of the same suit to clear them from the board.
* **Complexity:** Medium

#### 🏗️ Stacker (*"Skyline"*)
* **Concept:** Classic arcade reflex stacking machine.
* **Key Mechanics:**
  * Horizontal row of blocks sweeps back and forth. Press Space to lock each row.
  * Overhanging blocks get sheared off, narrowing the tower as it climbs.
  * Escalating speed up to Minor and Major prize tiers.
* **Complexity:** Low

---

### 7. Board Strategy & Tabletop Classics

> [!IMPORTANT]
> **Shared 8×8 Board System (`shared/board/Board8x8.qml`):**
> Chess, Checkers, and Othello share the exact same underlying $8 \times 8$ grid component:
> * Alternating square rendering adapting to light/dark Omarchy palette tones.
> * Coordinate labels (A–H, 1–8).
> * Reusable square highlight overlays for legal moves, captures, previous move indicators, and king checks.
> * Universal click-to-move and drag-and-drop interaction handling.

#### ♟️ Chess (*"Omarchy Chess"*)
* **Concept:** The timeless $8 \times 8$ strategy game.
* **Board Integration:** Built atop `shared/board/Board8x8.qml` with scalable vector piece sets.
* **Key Mechanics:**
  * Complete FIDE rules: Castling, En Passant, Pawn Promotion modal, Check/Checkmate, Stalemate, and 50-move / Threefold repetition draw detection.
  * Move notation log (SAN / PGN export).
  * Game modes: Local Pass-and-Play or Play vs. AI (configurable difficulty tiers).
* **Complexity:** High

#### 🔴 Checkers (*"Omarchy Checkers"*)
* **Concept:** Classic American/English draughts with crown promotions and mandatory jumps.
* **Board Integration:** Built atop `shared/board/Board8x8.qml` using smooth circular checker pieces with crown badges.
* **Key Mechanics:**
  * Diagonal pawn movement, forced capture/jump chains, and kinging.
  * Animated jump arcs and piece capture removal.
  * Game modes: Local Pass-and-Play or Play vs. AI.
* **Complexity:** Medium

#### ⚪ Othello / Reversi (*"FlipGrid"*)
* **Concept:** Fast-paced territorial disc flipping game ("a minute to learn, a lifetime to master").
* **Board Integration:** Reuses `shared/board/Board8x8.qml` directly with two-tone flip discs.
* **Key Mechanics:**
  * Outflank opponent discs horizontally, vertically, or diagonally to flip them to your color.
  * 3D coin-flip rotation animations when discs change sides.
  * Valid move ghost indicators (shows legal placements and flip counts).
  * Auto-pass when no legal moves exist; game ends when board is full.
  * Game modes: Local 2-Player or AI (positional corner/edge weight heuristic).
* **Complexity:** Low-Medium

#### 🔴 Connect 4 (*"QuadLine"*)
* **Concept:** The iconic vertical 4-in-a-row drop-checker game.
* **Key Mechanics:**
  * $7 \times 6$ vertical acrylic grid with circular cutouts.
  * Click a column or use numbers 1–7 to drop colored checkers with gravity bounce animations.
  * Win detection across horizontal, vertical, and both diagonals.
  * Local 2-Player or AI with minimax lookahead.
* **Complexity:** Low

#### 🚢 Sea Battle / Battleship (*"GridFleet"*)
* **Concept:** $10 \times 10$ naval grid deduction with fog-of-war.
* **Key Mechanics:**
  * Tactical radar aesthetic with 5 geometric ships (Carrier, Battleship, Cruiser, Sub, Destroyer).
  * Ship deployment phase (click to place, `R` to rotate).
  * Firing phase: Sonar ping sounds on miss, fiery vector burst on hit, ship sunk notification.
  * Smart AI that uses random hunting until a hit, then follows targeted parity search.
* **Complexity:** Medium

#### 🏺 Mancala (*"Kalaha"*)
* **Concept:** Ancient pit-and-pebble sowing game with deep strategy.
* **Key Mechanics:**
  * Wooden board with 12 player pits (6 per side) and 2 large end-store kalahas.
  * Pick up all stones from a pit and sow one counter-clockwise into each subsequent pit.
  * Free turn bonus when the last stone lands in your store; capture opposite stones when landing in an empty pit.
  * Satisfying marble-dropping sound effects.
* **Complexity:** Low-Medium

#### 🎲 Backgammon (*"CyberGammon"*)
* **Concept:** The ancient 5,000-year-old race and capture board game.
* **Shared Synergy:** Reuses the circular checker disc renderer from Checkers on a custom 24-point triangular board.
* **Key Mechanics:**
  * 24 triangular points across inner and outer home boards, central bar, and bearing-off tray.
  * Animated 2-dice roller (doubles grant 4 moves).
  * Hitting blots to the bar and re-entering into the opponent's home board.
  * Bearing off checkers once all 15 pieces reach home board.
  * Optional doubling cube.
* **Complexity:** High

#### 🁉 Dominoes (*"Double-Six"*)
* **Concept:** Traditional tile-matching table game.
* **Key Mechanics:**
  * 28 double-six domino tiles with crisp black/white pip rendering.
  * Draw Game and Block Game rules: match numbers end-to-end along the winding chain.
  * Auto-pass / boneyard draw when no matching ends are held.
* **Complexity:** Low-Medium

#### 🎲 Yahtzee (*"RollFive"*)
* **Concept:** Classic 5-dice poker-style scorecard game.
* **Key Mechanics:**
  * 5 vector dice with 3 rolls per turn. Click dice to "keep" them between rolls.
  * Standard 13-category scorecard: Aces through Sixes, 3 of a Kind, 4 of a Kind, Full House, Small Straight, Large Straight, Yahtzee (50 pts), and Chance.
  * High-score tracking and scorecard validation.
* **Complexity:** Low-Medium

#### 💊 Block Pill (*"CapsuleMatch"* / *Dr. Mario homage*)
* **Concept:** Falling two-tone medicine capsules to eliminate colorful viruses.
* **Key Mechanics:**
  * 2-block capsules fall down a test-tube jar; rotate and drop them onto stationary virus cells.
  * Match 4 consecutive segments of the same color (horizontally or vertically) to vaporize viruses and blocks.
  * Clear all viruses to advance to higher fever-pitch stages.
* **Complexity:** Medium

---

### 8. Roguelite & Dungeon Crawler *(Linux / UNIX Heritage)*

#### ⚔️ Micro-Rogue (*"TinyCrawl"* / *"RogueGrid"*)
* **Concept:** Minimalist, turn-based single-screen dungeon crawler paying homage to classic UNIX *Rogue*, *NetHack*, and *Brogue*.
* **Key Mechanics:**
  * Turn-based grid movement using Vim keys (`H/J/K/L`), arrows, or numpad.
  * Procedural room generation with monsters, potions, scrolls, weapons, and gold.
  * Fog-of-war line of sight.
  * Permadeath with high score leaderboard and run summaries.
  * 10 progressive dungeon floors culminating in a final boss encounter.
* **Complexity:** Medium-High

---

### 9. Simulation & City Building

#### 🏙️ City Builder (*"ByteCity"* / *"MetroGrid"* — *SimCity 1989 homage*)
* **Concept:** Classic 2D top-down grid city simulator inspired by Will Wright's open-source *Micropolis* (GPLv3) simulation engine.
* **Legal Safety:** 100% legally clean. The underlying RCI simulation algorithm is public domain/GPLv3. Uses original vector tiles and Omarchy theme color mapping.
* **Key Mechanics:**
  * **RCI Zoning:** Residential (green), Commercial (blue), and Industrial (yellow). Zones develop autonomously from empty plots to thriving high-rises based on land value, crime, and economic demand.
  * **Infrastructure:** Roads, rail, power lines, and power plants (Coal vs. Nuclear vs. Clean Wind/Solar).
  * **Municipal Services:** Police precincts and Fire stations projecting safety radiuses.
  * **City Budget & Policy:** Adjust tax rates, transportation maintenance, and police/fire funding.
  * **Evaluation & Analytics:** Population growth counter, treasury funds, RCI demand bar gauges, and public approval ratings.
  * **Disaster Events (Optional Toggle):** Fires, floods, tornadoes, and power blackouts.
* **Complexity:** Medium-High

---

## Complete Category Overview

| Category | Planned Titles |
| :--- | :--- |
| **Blocks & Merging** | 2048, TetraBlocks, 10×10 BlockGrid, Stacker, CapsuleMatch |
| **Action Arcade** | Pac-Man, Galaga, Space Invaders, Asteroids, Breakout, Frogger, DinoRunner, NeonRoller, Pinball |
| **Puzzles & Grid Logic** | Minesweeper, Sudoku, Snake, Sokoban, CircuitFlow, Bejeweled, ColorFlow, GridEscape, 15-Puzzle, Dots & Boxes |
| **Word Games** | Word Finder (WordWheel), Wordle (ByteWord), Boggle (WordGrid) |
| **Memory & Sound** | Simon Says (ChromaTone), Concentration (PairMatch) |
| **Cards & Casino (Shared Deck)** | Blackjack, Spades, Klondike Solitaire, FreeCell, Spider Solitaire |
| **Board Strategy (Shared 8×8)** | Chess, Checkers, Othello, Connect 4, Battleship, Mancala, Backgammon, Dominoes, Yahtzee |
| **Casual & Physics** | Bubble Shooter (OrbPop), Peggle (NeonDrop) |
| **Simulation & Management** | ByteCity (SimCity classic homage) |
| **Roguelite / RPG** | TinyCrawl (Micro-Rogue) |

---

## Development Prioritization Matrix

```
Tier 1 — High Value / Instant Momentum (Fast, Highly Replayable):
  ★ Word Finder ("WordWheel") [Crossword word-wheel puzzle]
  ★ Connect 4 ("QuadLine") [Fast 2-minute drop game]
  ★ Snake ("Viper") [Vim-controlled neon trail]
  ★ Minesweeper ("GridSweeper") [Classic desktop essential]
  ★ 10×10 Block Puzzle ("PolyGrid") [Zen block placement]
  ★ Sound Memory ("ChromaTone") [Simon Says audio-visual chimes]
  ★ 15-Puzzle ("TileSlide") [Clean number slide]

Tier 2 — Tabletop & Card System Foundations:
  ★ Blackjack ("Arcade 21") [Launches shared/cards/ engine]
  ★ Battleship ("GridFleet") [Tactical radar deduction]
  ★ Othello ("FlipGrid") [Launches shared/board/ 8x8 engine]
  ★ Color / Water Sort ("ColorFlow") [Relaxing vial sort]
  ★ Dots & Boxes ("BoxDraft") [Territory capture]
  ★ Wordle ("ByteWord") [Daily 5-letter deduction]
  ★ Checkers ("Omarchy Checkers") [Leverages shared/board/]
  ★ Klondike Solitaire ("Arcade Solitaire") [Leverages shared/cards/]

Tier 3 — Action Staples & Core Strategy:
  ★ Breakout ("BrickBash") [Shattering bricks & power-ups]
  ★ Bubble Shooter ("OrbPop") [Angle launcher & roof cascade]
  ★ Spades ("Arcade Spades") [Trick-taking card classic]
  ★ Galaga ("Galactic Swarm") [Dive-bombing formations]
  ★ Pac-Man ("ByteMan") [4-ghost maze AI]
  ★ Mancala ("Kalaha") [Ancient pebble sowing]
  ★ Yahtzee ("RollFive") [Dice poker scorecard]
  ★ Block Pill ("CapsuleMatch") [Dr. Mario match-4]
  ★ GridEscape ("Rush Hour") [Sliding traffic puzzle]

Tier 4 — Deep Strategy, Sim & UNIX Heritage:
  ★ ByteCity ("MetroGrid") [SimCity classic RCI zoning & budget simulation]
  ★ Chess ("Omarchy Chess") [Full FIDE rules + AI engine]
  ★ TinyCrawl (Micro-Rogue) [Vim turn-based procedural dungeon]
  ★ FreeCell & Spider Solitaire [Full patience suite]
  ★ Backgammon ("CyberGammon") [24-point race & dice]
  ★ Dominoes ("Double-Six") [Table chain matching]
  ★ Bejeweled ("GemSwap") [Match-3 special gems]
  ★ Sokoban ("CratePusher") [50+ warehouse stages]

Tier 5 — Advanced Physics:
  ★ Pinball ("CyberPin") [Flippers, bumpers, ramps, multiball]
  ★ Peggle ("NeonDrop") [Pachinko peg bounces]
```
