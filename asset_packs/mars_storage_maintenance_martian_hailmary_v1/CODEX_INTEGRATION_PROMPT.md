# Codex handoff — Storage & Maintenance

Import ONLY the two updated equipment GLBs (`tool_bench.glb`, `cargo_rack.glb`) into the existing Godot Mars Habitat project.

1. Before editing, back up all existing `tool_bench` and `cargo_rack` model/scenes/scripts to a versioned backup directory. Do not delete or overwrite the backups.
2. Preserve the existing `tool_bench` and `cargo_rack` equipment catalogue IDs, save-game compatibility, zones, footprint definitions, and established effects. Inspect real `data/equipment_catalog.json` and project scripts first; do not invent paths or APIs.
3. Replace only the equipment visual scene subtree and adapt collisions/placement to the new GLB bounds. Models use +Y up, -Z forward and 1 unit = 1 metre.
4. Use **simple collision boxes**, but avoid preventing access to workbench interaction surfaces. Confirm room clearance and no player entrapment.
5. Keep interaction components separately identifiable (see manifests). Implement one brief, sensible interaction per item: workbench = take a spare/activate repair animation; cargo rack = retrieve a crate/release a retention bar. Show real inventory or mission feedback through the existing contextual UI; no fake persistent numeric displays.
6. Do not assume manual wiring or plumbing is needed. Use the current shared habitat simulation; connect workshop spare-parts/repair capabilities only if matching systems already exist, otherwise expose safe extension points without inventing gameplay.
7. Include a simple import + placement + collision + save/reload + interaction smoke test. Assess material appearance under actual in-game lighting, and compare to approved brighter Martian/Hail Mary rooms.
8. Do not change habitat structural walls, exterior equipment, room zones, other assets, or resource rates unless expressly requested.

Standalone reviewer is in `godot_review/` and includes demonstration cupboard/tray/retainer animations, which should not be treated as integrated gameplay.
