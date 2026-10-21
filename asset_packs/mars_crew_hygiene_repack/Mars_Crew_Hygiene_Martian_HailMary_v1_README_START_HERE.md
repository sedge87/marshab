# Mars Habitat — Crew Hygiene equipment | Martian / Hail Mary v1

Two **original, standalone equipment assets** (NOT room walls, not bathroom construction geometry).

## Included

| Model file | Purpose | Provisional catalogue id | Size W×H×D |
|---|---|---|---|
| `models/habitat_toilet.glb` | Compact vacuum-style toilet with service cartridge | `hygiene_toilet` | 0.86 × 1.25 × 1.03 m |
| `models/low_water_wash_station.glb` | Wash basin, metered tap, hand sprayer, greywater cartridge | `hygiene_shower` | 1.42 × 2.08 × 0.82 m |

Coordinate system is Godot metres, **Y up, forward -Z, origin at floor centre**.

## Visual details

White/off-white composite housings, pale aluminium, teal service accents, modest orange controls and physically supported mechanisms. Both basin openings are **actual modelled recesses**, not painted circles; no text or static digital screen textures.

## Installation

1. Open `godot_review/project.godot` in Godot 4.3+ to inspect both models together; no game project is modified.
2. In the review project: left-mouse drag to orbit, scroll to zoom. **F** toggles the toilet lid, **G** signals a flush, **H** signals washing, **J** slides the wash filter.
3. For integration: copy each GLB into your game assets folder and follow `CODEX_INTEGRATION_PROMPT.md`. Use collision wrappers from the review project as a starting point, not unquestioned final collision geometry.

## Intended learning interaction (lightweight)

- Toilet: tap to open lid, use flush, occasional filter/service prompt. Suggest that enclosed habitats must manage waste and air.
- Wash Station: tap to wash, open greywater cartridge, show a simple game-level notice that used water is sent to Life Support for recycling. **No literal pipe placement required.**

The two future equipment IDs above are *suggestions*, not existing verified catalogue entries. The source/game's current zone and footprint rules must be confirmed on integration.

## Validation scope

Actual GLBs exported, reopened in `trimesh`, off-screen rendered from three views, and checked for dimensions. The standalone Godot scene has **not** been run in a Godot executable in this environment. Interaction scripts are simple example signals, not a complete hygiene/water simulation.

All earlier models are left untouched.
