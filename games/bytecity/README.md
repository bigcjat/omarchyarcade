# ByteCity • Omarchy Arcade

An authentic, legally safe, uncompromised city builder for the Omarchy Linux desktop arcade suite, powered by Will Wright's open-source 1989 **Micropolis (GPLv3)** C++ simulation core paired with a modern **2.5D dimetric isometric vector renderer** (PySide6 / QML).

![ByteCity Gameplay](screenshot.png)

---

## Key Features

1. **Authentic 1989 Simulation Engine:**
   - 100% genuine C++ simulation logic (Micropolis GPLv3) compiled natively (`libmicropolis.so` on Omarchy Linux).
   - Full cellular automaton zoning rules, power grid propagation, traffic pathfinding, pollution dissipation, land value gradients, and crime rates.
   - Dynamic RCI (Residential, Commercial, Industrial) economic demand valves driven by market simulation.
   - Live city treasury, tax policy slider (0%–20%), municipal maintenance funding, and public approval polling.

2. **2.5D Dimetric Isometric Vector Renderer:**
   - High-performance `CityViewport` (`QQuickPaintedItem`) with pure mathematical vector rendering (`QPainter`).
   - Zero raster bitmap sprite sheets; adheres strictly to the Omarchy palette (Catppuccin Macchiato tones).
   - Elevated building blocks, glowing window matrices, architectural roof geometries, power line poles with crossbars, and dynamic water ripples.
   - Smooth mouse pan (middle-click drag or right-click drag) and mouse-wheel zoom (0.5x to 2.5x).

3. **Construction Palette:**
   - **Bulldozer ($1):** Clear land and demolish structures.
   - **Roads ($10):** Connect zones and conduct light traffic.
   - **Power Wires ($5):** Transmit high-voltage electricity across non-zoned tiles.
   - **Railroads ($20):** High-capacity transit mitigating vehicular gridlock.
   - **Residential Zone ($100):** $3 \times 3$ housing plots developing from low-density to high-rise towers.
   - **Commercial Zone ($100):** $3 \times 3$ office towers and commerce centers.
   - **Industrial Zone ($100):** $3 \times 3$ manufacturing facilities with smokestacks.
   - **Police Department ($500):** $3 \times 3$ precinct providing law enforcement coverage.
   - **Fire Department ($500):** $3 \times 3$ station providing rapid fire response.
   - **Coal Power Plant ($3,000):** $4 \times 4$ heavy plant generating substantial electricity with pollution.
   - **Nuclear Power Plant ($5,000):** $4 \times 4$ clean high-output generator.
   - **Parks ($10):** Green open spaces boosting local land value.

4. **Municipal Governance & Emergency Response:**
   - **Budget Modal:** Adjust city property taxes and observe expected annual revenues.
   - **Evaluation Modal:** Poll citizens on mayor job approval and primary city grievances.
   - **Disaster Drills:** Trigger Monster attacks, Earthquakes, Tornadoes, and Fires on demand.
   - **Advisor Pill:** Live floating updates and notifications from the city advisor.

---

## Controls

| Action | Control |
| :--- | :--- |
| **Pan Camera** | Click & Drag (Middle Mouse Button or Right Mouse Button) |
| **Zoom In / Out** | Mouse Wheel Scroll |
| **Place Tool / Zone** | Left Click on Map |
| **Select Tool** | Click tool in left palette or use numeric hotkeys |
| **Simulation Speed** | Pause, 1x Normal, 2x Fast, 3x Hyper in Top Bar |
| **Open Budget** | Click `Budget` button in Top Bar |
| **Check Polls** | Click `Polls` button in Top Bar |
| **Disasters Menu** | Click `Disasters` button in Top Bar |

---

## Running ByteCity

Launch from the project root using the virtual environment:

```bash
/Users/christhompson/arcade/.venv/bin/python games/bytecity/main.py
```

To recompile the native simulation core:

```bash
make -C games/bytecity/native clean && make -C games/bytecity/native
```
