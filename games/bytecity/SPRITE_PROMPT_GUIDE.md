# Studio Ghibli / Japanese Retro City Builder: Sprite Generation Formula

This guide documents the exact prompt formula and structuring technique used to generate consistent, aligned, top-down Japanese / Studio Ghibli building sprite sheets that match the classic SimCity / Micropolis tile grid.

---

## The 5-Component Prompt Formula

The core formula breaks down into five key components that enforce the layout, perspective, art style, and thematic substitutions:

### 1. Structural Grid & Layout Anchoring
- **The Directive:** Specify the exact grid dimensions, borders, and tile count directly matching the reference (e.g., *"A 2x4 sprite sheet grid laid out exactly like the input image, preserving each cell's position, scale, and border formatting"*).
- **Progression Mapping:** Explicitly describe the columns and rows (e.g., *"Columns progress from left to right: Stage 1 (Storage) to Stage 4 (Heavy Smelter); Rows split into Standard Value top and High Value bottom"*).

### 2. Art Style & Rendering Technique
- **Vector Aesthetic:** *"Clean 2D vector art style, crisp fine outlines, flat shading with subtle gradients, clear geometric edges, clean lineart, avoiding raster pixelation or noisy textures."*
- **Palette Guidance:** *"Studio Ghibli-inspired color palette: soft celadon and sage greens, warm cedar and aged wood browns, terracotta, pale cream, muted slate blues, warm yellow ambient tones."*

### 3. Perspective & Projection
- **Camera Angle:** *"Top-down bird's-eye view with a steep orthographic tilt, matching the classic SimCity building projection."*
- *Note for industrial/technical sets:* Shift slightly toward *"orthographic isometric cutaway projection with visible rooftops and interior machinery"*.

### 4. Cultural & Architectural Replacements
Explicitly name specific Japanese architectural tropes rather than just saying "Japan":
- **Residential:** Japanese *kawara* clay tile hipped roofs, modern Tokyo micro-apartments, sliding screen balconies, small Shinto shrine (*jinja*) with torii gate replacing the church, Japanese medical clinic replacing the hospital.
- **Commercial:** *Konbini* (Japanese convenience store) with glowing kanji awnings, *shōtengai* shopping street fronts, red torii symbols replacing zone letters, traditional merchant *machiya*, and multi-tiered modern Tokyo corporate headquarters.
- **Industrial:** *Kura* (traditional mud-wall storehouses), wooden brewery barrels, high-tech automated robotics bays, pagodas repurposed with smelting kilns, Zen rock gardens around modern storage vaults.
- **Civics & Specials:** Traditional walled estate (*engawa* veranda, black pine, koi pond) for Mayor's manor, *Otera* Buddhist temple with *shōrō* bell tower, Shinto *sandō* walkway, sumo *dohyō* / martial arts pavilion, and stone *tsukubai* water basin parks.

### 5. Zone Indicators & Framing
- **UI/HUD Retainers:** *"Keep the zone indicator branding intact within each tile cell (e.g., yellow 'I' for Industrial, red Torii gate for Commercial, green 'R' for Residential), framed in crisp individual tile boxes with dark borders."*
