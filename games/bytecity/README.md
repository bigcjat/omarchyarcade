# OmarchyCity • Omarchy Arcade

An authentic, legally safe, uncompromised city builder for the Omarchy Linux desktop arcade suite, powered by Will Wright's open-source 1989 **Micropolis (GPLv3)** C++ simulation core and guided by **Dr. Wright**, paired with a responsive **2D top-down arcade viewport** adhering to the Omarchy Arcade template design.

![OmarchyCity Gameplay](screenshot.png)

---

## Key Features

1. **Authentic 1989 Simulation Engine:**
   - 100% genuine C++ simulation logic (Micropolis GPLv3) compiled natively (`libmicropolis.dylib` on macOS, `libmicropolis.so` on Linux).
   - Full cellular automaton zoning rules, power grid propagation, traffic, pollution, land value gradients, and crime rates.
   - Dynamic RCI (Residential, Commercial, Industrial) economic demand gauges.
   - Live city treasury, population count, and date calendar.

2. **2D Orthographic Arcade Viewport:**
   - High-performance `CityViewport` (`QQuickPaintedItem`) with pure mathematical 2D rendering (`QPainter`).
   - Adheres strictly to Omarchy theme tokens (Catppuccin Macchiato, Mocha, Latte, etc.).
   - Crisp pixel-art tiles, zone center markers ("R", "C", "I"), road connections, power lines, and live unpowered alerts (`⚡`).
   - Smooth pan (drag right/middle mouse or WASD / Arrows) and zoom (mouse wheel or `+` / `-`).

3. **Construction Palette:**
   - **Bulldozer ($1):** Clear terrain, demolish buildings, and clear rubble.
   - **Roads ($10):** Connect zones and conduct traffic.
   - **Power Wires ($5):** Transmit high-voltage electricity across non-zoned tiles.
   - **Railroads ($20):** High-capacity mass transit.
   - **Residential Zone ($100):** $3 \times 3$ housing plots developing as population grows.
   - **Commercial Zone ($100):** $3 \times 3$ commercial office and shop plots.
   - **Industrial Zone ($100):** $3 \times 3$ manufacturing facilities.
   - **Police Department ($500):** $3 \times 3$ precinct providing law enforcement.
   - **Fire Department ($500):** $3 \times 3$ station providing rapid fire response.
   - **Coal Power Plant ($3,000):** $4 \times 4$ heavy plant generating high electricity.
   - **Nuclear Power Plant ($5,000):** $4 \times 4$ clean high-output generator.
   - **Parks ($10):** Green open spaces boosting local land value.
   - **Stadium ($5,000):** $4 \times 4$ entertainment venue.
   - **Seaport ($3,000):** $4 \times 4$ maritime industrial port.
   - **Airport ($10,000):** $6 \times 6$ international travel hub.

4. **Floppy Disk Footprint:**
   - Slimmed down to **1.2 MB**, fitting comfortably onto a standard 1.44 MB 3.5" HD floppy disk.
   - 100% offline, zero cloud dependencies.

---

## Controls

| Action | Control |
| :--- | :--- |
| **Pan Camera** | Click & Drag (Right or Middle Mouse Button), or WASD / Arrows / Vim HJKL |
| **Zoom In / Out** | Mouse Wheel Scroll, or `+` / `-` keys |
| **Place Tool / Zone** | Left Click on Map (Road, Wire, Rail, Doze support click-and-drag) |
| **Select Tool** | Click tool in left dock |
| **Simulation Speed** | `Space` (Pause/Resume), `1` (Normal), `2` (Fast), `3` (Ultra) |
| **Audio Mute** | `M` key or click Speaker icon |
| **Help / Handbook** | `?` key or click Question icon |
| **Inaugurate New City** | Click `New City` button in header |

---

## Running ByteCity

```bash
# Launch directly with Python
python3 games/bytecity/main.py

# Launch with a specific Omarchy theme
python3 games/bytecity/main.py --theme catppuccin-latte
```
