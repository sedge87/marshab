# Codex — Integrate Science Laboratory Equipment (Mars Ice and Geological History)

I have three replacement GLBs for Science Laboratory. Please audit the current project first, **back up existing catalogue scenes, greybox models and scripts**, and integrate one model at a time without altering structural grid/walls/doors/windows or silently changing existing resource effects.

New GLBs:
- `science_workbench.glb`: keep existing equipment ID `science_workbench`, footprint, zone/scene path/effects where currently defined.
- `microscope_station.glb`: ID `microscope_station`, respect existing status/zone/metadata.
- `sample_storage_cabinet.glb`: ID `sample_storage_cabinet`, respect existing status/zone/metadata.

Check existing catalogue IDs/paths instead of overwriting with assumptions. If an ID has changed in the current project, report the mismatch and map explicitly. The three-model plan **consolidates** generic sample analysis into the science workbench; do not automatically delete other catalogue assets.

Visual expectations: white/off-white composite housings, mechanical aluminium supports, physically connected details, minimal amber/blue utility accents, and **no baked telemetry text**. Godot uses +Y up / -Z forward; models are floor-centred and fit nominal 1.5m half-cells.

Make each asset optionally interactable using the project's **existing** interaction/UI framework. For example:
1. Inspect a sample from a rover or EVA mission at the workbench. The core has visible layers; show one short contextual observation (possible sediment deposition). Optionally raise the ice-test hatch.
2. Bring a selected rock sample to the microscope and turn on its illumination or adjust its physical focus dial. Use a clear in-game card for a finding, rather than a fake prewritten screen texture.
3. Move examined specimens into the archive. Model has an actual transparent sample-window opening, five removable-looking core drawers and a swing door.

The educational loop should emphasize physical evidence that Mars's surface has changed: **rock layers, wind and water erosion, preserved ice and ancient water environments**. Avoid definitive claims that a single sample proves past life or conclusively proves ancient oceans. Students are not expected to answer worksheets/quizzes.

Integration controls are *suggested*, not prescriptive:
- `Ice_Chamber_Hatch`, `Core_Clamp`, `Specimen_Drawer`, `Pump_Toggle`, `Worklight_Emitter`
- `Focus_Knob`, `Magnification_Lever`, `Mineral_Sample_Tray`, `Sample_Illuminator`
- `Cold_Archive_Door`, `Core_Archive_Drawer_1` through `Core_Archive_Drawer_5`

The standalone `godot_review/` viewer has demonstration code for hatch, archive door, drawer and light. Treat this as example UI/animation behavior, **not live gameplay logic**. Preserve existing save/load, catalog asset paths, collisions and room placement. Use low-cost lighting, simple collider shapes and no unnecessary per-mesh collisions. Report any catalog changes before making them.

Test: placement, orientation, ground contact, interactions, mesh naming, actual material appearance, transparent specimen door, performance with all 3 present, and save/reload. Never delete the backups.
