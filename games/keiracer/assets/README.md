# KeiRacer Sprites & Assets

KeiRacer uses high-efficiency WebP assets for its 6 slow-car icons, achieving an arcade-wide 1.44 MB Floppy Disk budget.

- **Dynamic Mirroring**: To keep asset footprints as lean as possible, right-turn angles are dynamically mirrored at runtime from the left-turn sprites via HTML5/QML 2D Canvas matrix scaling (`ctx.scale(-1, 1)`).
- **WebP Encoding**: Vehicle bodies are encoded as high-fidelity WebP (90% quality) and brake overlays as lossless WebP, cutting sprite sizes by ~87.5% while preserving full 32-bit color fidelity, smooth alpha blending, and crisp Retina scaling.

## Vehicles Included

1. **Suzuki Carry Kei Truck** (`kei_straight.webp`, `kei_l10.webp`, `kei_l20.webp`, `kei_l30.webp` + `_brakes.webp`)
2. **Smart Fortwo** (`smart_straight.webp`, `smart_l10.webp`, `smart_l20.webp`, `smart_l30.webp` + `_brakes.webp`)
3. **Fiat Panda 4x4** (`panda_straight.webp`, `panda_l10.webp`, `panda_l20.webp`, `panda_l30.webp` + `_brakes.webp`)
4. **Suzuki Sidekick** (`sidekick_straight.webp`, `sidekick_l10.webp`, `sidekick_l20.webp`, `sidekick_l30.webp` + `_brakes.webp`)
5. **Jeep Wrangler YJ** (`wrangler_straight.webp`, `wrangler_l10.webp`, `wrangler_l20.webp`, `wrangler_l30.webp` + `_brakes.webp`)
6. **Volkswagen Type 2 Bus** (`vwbus_straight.webp`, `vwbus_l10.webp`, `vwbus_l20.webp`, `vwbus_l30.webp` + `_brakes.webp`)

All cars feature dedicated hand-calibrated glowing brake-light overlays that dynamically mirror alongside the chassis.


