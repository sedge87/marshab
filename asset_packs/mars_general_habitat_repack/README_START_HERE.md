# Mars Habitat — General Habitat Equipment, v1

**Original game-ready GLB models**, styled to accompany the bright *The Martian* / *Project Hail Mary* inspired room equipment. This is an original design set, not a reproduction of film props.

This pack contains **five equipment categories / seven placeable models**:

| Model | Use | Placement | Potential interaction |
|---|---|---|---|
| Fire Safety Station | Shared safety cabinet with mounted extinguisher, emergency blanket and first-aid drawer | Freestanding / wall-adjacent in any interior room | Retrieve extinguisher or open drawer |
| Emergency Supply Locker | Emergency oxygen, kits and thermal packs | Freestanding, any appropriate interior room | Open locker / retrieve supplies |
| First Aid Kit | Portable supplies | Free placement on counter, floor or optional surface mount | Open kit |
| Portable Interior Work Light | Battery-powered maintenance illumination | Free floor placement, any suitable room | Toggle lamp |
| Supply Crate (small) | Spare supplies | Free floor placement | Open / inspect |
| Supply Crate (medium) | Spare supplies | Free floor placement | Open / inspect |
| Supply Crate (large) | Spare supplies | Free floor placement | Open / inspect |

## Design conventions
- 1 Godot unit = 1 metre, +Y up, -Z forward, model origin near floor centre.
- PBR coloured materials embedded in each GLB; no baked words, simulated readouts or map screens.
- Geometry uses physically attached hardware, supported lighting, gaskets, hinged-looking hatches, rails, brackets, handles and restraints.
- Static meshes are batched within material and logical node groups. Independently useful parts have names such as `lid`, `latches`, `on_off_switch`, `extinguisher`, `drawer` and `lamp_housing`.
- Crates are available in three distinct sizes and can be mixed throughout the habitat.

## Godot standalone preview
Open `godot_review/project.godot` with Godot 4.3+ and run the scene. Press **1–7** to select an asset and **E** to call its demonstration interaction. The work light also toggles a low-cost sample spotlight. No inventory, door, or resource simulation is installed.

### Important limitation
The scripts and Godot scenes are integration examples only. They have **not** been run in the real habitat project. The real game still needs placement, physics, interaction/animation, saving, lighting and gameplay wiring. The asset meshes have been exported, reimported and rendered using an offline renderer.

## Keep the structure separate
These are furniture / equipment props. No interior wall, window, door or pressure-shell editing is included or required. Do not constrain their placement to the Corridors zone.

## Contents
- `models/` — seven GLB files
- `previews/` — rendered GLB contact sheet and angles
- `asset_manifest.json` — measured model dimensions, triangle counts and mesh/component lists
- `godot_review/` — standalone Godot 4 review project with example colliders and signals
- `source/` — editable generator and offline renderer
- `CODEX_INTEGRATION_PROMPT.md` — instructions for integrating later without modifying existing scenes unexpectedly
