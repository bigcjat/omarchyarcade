# BOLO II — The Unofficial Sequel (OA-029)
### Classic Tactical Warfare, Combined Arms & Combat Engineering

![OmarchyBolo II Gameplay](screenshot.png)

A modern, high-fidelity sequel to Stuart Cheshire's legendary 1987 Macintosh networking classic **Bolo**. Built with pure HTML5 2D Canvas vector rendering, TypeScript, Web Audio procedural synthesis, autonomous AI battlegroups, and serverless WebRTC peer-to-peer multiplayer.

Integrated into the **Omarchy Arcade** suite with local offline support and zero-overhead native/web execution.

---

## ⚔️ What's New in Bolo II (Differences from Classic 1987 Bolo)

While preserving the authentic **40 Hz deterministic heartbeat**, 256-angular-unit physics (Bradians), and Mac System 7 aesthetic, **Bolo II** expands the classic game into a full combined-arms battlefield:

| Dimension | Classic Bolo (1987) | Bolo II (1997 Sequel Vision) |
| :--- | :--- | :--- |
| **Playable Vehicles** | Single Tank class | **3 Asymmetric Classes**: M4 Battle Tank, M998 Armed Humvee, and 100,000-ton Naval Aircraft Carrier |
| **Secondary Weapons** | None | **155mm Heavy Artillery** (Tank), **SAM Anti-Air Missiles** (Humvee), **Scrambled Attack Helicopter with Railgun** (Carrier) |
| **Air Support & Logistics** | None | **Automated Cargo Supply Planes** parachuting supply crates over friendly captured bases every 6 minutes |
| **Combat Engineering** | Basic roads, walls, pillboxes | Adds **5 Military Tech Installations** (Foundries, Aegis Pylons, Barracks, Drone Dispatch Stations, Naval Shipyards) |
| **Building Controls** | Single-tile manual clicks | **SimCity-style Multi-Tile Click & Drag** for laying road and wall barricades, with safe worker order queueing |
| **Networking** | AppleTalk / Local UDP | **Serverless WebRTC P2P DataChannels** with real-time public lobby discovery via Firebase Realtime Database |
| **Host Resiliency** | Host disconnect killed game | **Deterministic Host Migration**: remaining peers elect a new host seamlessly with live state handover |
| **Visual Engine** | Fixed 16-color Mac sprites | **Dual Graphics Engine**: Toggle between authentic 1993 textures and ultra-crisp Modern HD Vector rendering |
| **Combat Mechanics** | Instant death on water | Snorkel watercraft hydro-drag, salvageable scrap metal from wrecks, EMP shock mines, and naval sea mines |
| **Platform** | Classic Mac OS 6 / 7 | Cross-play across **Web Browsers** and **Native Desktop App** (macOS, Windows, Linux via Tauri) |

---

## 🕹️ Controls & Field Manual

### Vehicles & Combat Controls
| Key / Input | Action | Vehicle Class |
| :--- | :--- | :--- |
| **W / A / S / D** or **Arrows** | Drive & Steer Chassis (Realistic momentum & hydro-drag) | All Vehicles |
| **Double-Tap Up Arrow** | Toggle Turret Lock (fixed chassis vs. independent 360° mouse aim) | Tank & Humvee |
| **Mouse Aim** | Independent 360° Turret Gunsight Direction | All Vehicles |
| **Mouse Wheel** or **[ / ]** | Adjust Gunsight Range (2 to 14 tiles) | All Vehicles |
| **Space** or **F** | Fire Primary Weapon (105mm Cannon / Naval Autocannon) | All Vehicles |
| **E** or **Q** | Fire Heavy 155mm Artillery Shell (4 carried, 2s reload, 37.5 dmg) | M4 Tank |
| **E** | Launch Heat-Seeking Surface-to-Air (SAM) Missile | M998 Humvee |
| **E** | Scramble Coastal Patrol Attack Helicopter (Door Railgun) | Aircraft Carrier |
| **R** | Launch Cargo Supply Transport Plane (Base Supply Airdrop) | Aircraft Carrier |
| **X** or **MINE Tool** | Lay / Arm Landmine directly beneath tracks | All Vehicles |
| **C Key** | Recall Combat Engineer safely inside chassis | M4 Tank |
| **Tab** | Open Standings & Real-Time Kill/Death Leaderboard | All Modes |
| **⌘A** | Open Macintosh Diplomacy & Alliances Window | All Modes |
| **Y** or **⌘M** | Open Tactical Message / Telegram Comms Window | All Modes |
| **⌘+ / ⌘- / ⌘0** | Zoom In / Zoom Out / Reset Standard 100% Tactical Zoom | All Modes |
| **Esc** | Close active dialog window | All Modes |

### Combat Engineering & LGM Tools
| Number Key / Tool | Action | Cost / Requirements |
| :--- | :--- | :--- |
| **1:WOOD** | Select **Chop Trees** | Yields 4 Wood logs per tree chopped |
| **2:ROAD** | Select **Build Road** (Click or drag up to 6 tiles) | Costs 1 Wood per road tile |
| **3:WALL** | Select **Build Wall** (Defensive brick barrier) | Costs 2 Wood per wall tile |
| **4:PILL** | Select **Deploy Pillbox** | Requires 1 carried pillbox (or repairs neutral/dead pillboxes) |
| **5:MINE** | Select **Lay Mine** | Drops a mine under your tracks (costs 1 mine) |
| **6:UAV** or **U Key** | Launch / Recall **Recon Drone** | Deploys trailing drone with infrared mine detection |
| **7:BLDG** | Open **Military Tech Structure Flyout** | Displays tech building selection menu |
| **Click on Map** | Dispatch Engineer to target coordinates | Deploys worker on foot; queues orders if already working |
| **Click & Drag** | SimCity-style Multi-Tile Construction | Automatically builds lines or rectangles of roads/walls |
| **C Key** | Recall Engineer back inside Tank | Safely embarks engineer into the chassis |

---

## 🎖️ Authentic 1993 Bolo Mechanics & Forensic Physics

1. **Gunsight Artillery Airburst Fuse Detonation**: Calibrating gunsight distance sets an explosive airburst flight fuse. Detonates on target with splash damage, terrain erosion, timber ignition, and mine triggering.
2. **Craters & Canal Floodfill Chains**: Mine blasts create craters. Water breaches craters and cascades sequentially in 100ms staggered domino chains to carve custom navigable canals for boats and carriers.
3. **Mine Domino-Chain Wave Reactions**: 4-tick delay (`MINE_CHAIN_DELAY_TICKS = 4`) creates rolling shockwave cascades across minefields.
4. **Living Forest Regeneration & Ecology**: Living forests seed new saplings onto adjacent open grass and swamp every 4 seconds (`TREE_GROWTH_INTERVAL_TICKS = 160`).
5. **Wall Degradation, Rubble Drag & Weathering Decay**: Walls take 5 hits to collapse into `RUBBLE` (50% speed penalty), weathering into `GRASS` after 2 minutes.
6. **"Angry Pillboxes"**: Pillboxes enraged by gunfire accelerate reload rate down to 12 ticks (0.3s) with a 4s cooldown timer, then step back up to baseline.
7. **Dual-Tier Spatial Acoustic Distancing**: Crisp transients $\le 15$ tiles; dynamic linear attenuation and low-pass filtering (800Hz $\rightarrow$ 300Hz) for muffled subterranean artillery rumbles $15 - 40$ tiles.

---

## 🏭 Military Tech Structures & Salvage (Key 7:BLDG)

| Structure | Cost | Tactical Benefit / Effect |
| :--- | :--- | :--- |
| **Munitions Foundry** | 4 Wood, 10 Scrap | +25% cannon shell velocity and shell penetration |
| **Shield Aegis Pylon** | 4 Wood, 12 Scrap | +25 maximum tank armour & doubles pillbox fire rate |
| **Engineering Barracks** | 3 Wood, 8 Scrap | 2x engineer speed & instant tree chopping |
| **Drone Dispatch Station** | 4 Wood, 10 Scrap | Auto-launches autonomous recon drones to all team vehicles |
| **Naval Shipyard** | 4 Wood, 10 Scrap | Built on coast; constructs and docks high-speed patrol boats |

- **Salvage**: Destroyed vehicles leave scorched wrecks with up to 30 scrap metal, shells, and mines.

---

## 🤝 Macintosh Diplomacy & Alliances (`⌘A`)

- **Dynamic Treaties**: Propose, accept, or break non-aggression pacts mid-battle via the System 7 diplomacy window.
- **Shared Logistics**: Allied bases provide mutual refueling, armor repair, and ammo restocking.
- **Traitor Alerts**: Breaking a treaty or attacking an ally announces an immediate island-wide traitor alert.

---

## 🎨 Dual Graphics Modes

Toggle on the fly (**View → Graphics**):
- **Classic 1993 Graphics**: Authentic 16-color pixel-art terrain tiles, original chassis/turret sprites, and crossed-paddle cursor.
- **Modern HD Vector Graphics**: Procedural vector rendering, ambient light pulses around bases, CRT phosphor glow, and directional debris.

---

## Running

### From the Arcade Root:

```bash
python3 games/omarchybolo/main.py
```

### Standalone Web App Mode:

```bash
python3 games/omarchybolo/main.py --web
```

### Native Binary (if compiled):

```bash
python3 games/omarchybolo/main.py --native
```
