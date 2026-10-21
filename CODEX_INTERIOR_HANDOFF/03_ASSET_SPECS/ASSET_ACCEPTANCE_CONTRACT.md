# Per-asset contract

Every generated asset should have:
- `source/blender/<id>.blend` (authoring source) and `assets/equipment/<filename>.glb` (runtime; use live catalogue's existing `asset_scene` path unless deliberately migrated).
- Named collections for frame, service panels, latches, wiring/pipes, display/emissives, pivots and optional interaction marker.
- Real scale and floor-centred origin (Godot +Y, -Z front), applied transforms and simple Godot-compatible collision.
- Distinct active/inactive/warning states if functionality supports these; do not imply a working system where none exists.
- Physically identifiable purpose, sensible maintenance access and no decorative technobabble.
- At least one first-person close-up and one in-room scale screenshot (capture from game, not just Blender render).
- Record catalogue ID, GLB location, blend location, dimensions, poly count, textures, interaction, behaviour, reference URLs, integration status and test results in `assets/interior/asset_production_manifest.json`.
- No assumptions that the original grey boxes are standalone GLBs; some may be *procedurally generated* in `scripts/build_controller.gd`. Audit before replacement.
- Keep current gameplay consequences: catalogue effects, capacity, cargo mass, resource power/water/food rules, zone validity and serialization.
- For functional toggling, avoid changing catalogue entries globally when switching an individual instance off. Add per-instance state only if properly serialized and reflected in aggregate resource calculations.
