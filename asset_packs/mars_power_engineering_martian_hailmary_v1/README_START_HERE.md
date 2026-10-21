# Mars Habitat — Power & Engineering (The Martian + Project Hail Mary)

This is a **high-detail, room-specific asset review pack**, not a modification of your game. It replaces the old low-detail power distribution cabinet with recessed physical switchgear and adds a coherent modular battery bank.

## Asset files

- `models/power_distribution_cabinet_martian_hailmary.glb` (`power_distribution_panel` catalogue ID)
- `models/battery_bank_martian_hailmary.glb` (`battery_bank` catalogue ID)
- `previews/power_engineering_contact_sheet.jpg` and individual actual-model views
- `godot_review/` is a standalone Godot 4 project (open `project.godot` and run)
- `source/` contains the editable procedural geometry and preview generators
- `asset_manifest.json` includes geometry statistics, dimensions and sample interaction hooks

## Visual direction

Original practical Mars hardware with **white and warm-white composite cladding, light aluminium framing, graphite interior service bays, restrained orange controls, non-digital gauge faces and live-light-capable indicator strips**. No baked text, numbers or fake permanent readouts. Every component is supported by plausible rails or chassis.

## Godot / placement

Each GLB is metric, +Y up, -Z facing front; model origin at floor-centre. Widths are under 1.5 m. Height is about 2.05 m. Depth is 0.83–0.88 m. Preserve catalogue IDs, effects and scene paths already in your game. The review project contains simple example collisions, *not final integrated collision rules*.

## Suggested behaviour for Year 9 students

- Distribution cabinet: turn the orange main isolator to enable/disable electricity to room equipment; inspect a breaker if a machine stops receiving power. The large breaker panel is physically detailed but **do not simulate 15 independent electrical circuits** unless later desired.
- Battery bank: stores power supplied by generation sources and supports the habitat during low supply. Let players inspect a charge indicator or pull the one named service cartridge. No technical electrical quiz or manual cable network.
- All info should use live Godot context overlays or physical indicator colours, never fake numbers printed into the GLB.

## Asset scope

**Equipment only.** No structural partitions, windows, doors, grid changes or hull operations. These designs intentionally replace the very plain former cabinet; keep old placeholders as backups.

## Validation

Both files exported and reopened successfully as glTF scenes. Three-angle renders use the exported GLBs, not separate concept geometry. The source checks bounds and records mesh groups. **The actual models, scene, materials, performance, and interactions have not been tested inside the live habitat game yet.**
