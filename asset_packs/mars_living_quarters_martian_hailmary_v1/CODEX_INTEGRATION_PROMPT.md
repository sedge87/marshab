# Codex — Integrate brighter Living Quarters models, one room at a time

The six new models are in `models/`. Visually these should match the existing bright Martian/Project Hail Mary Hydroponics and Life Support equipment: white composite panels, aluminium hardware, a little orange and muted blue/teal. They preserve the previous detailed geometries; do not replace them with simplified boxes.

1. Inspect the existing Godot `equipment_catalog.json`, relevant `asset_scene` paths and resource effects. Record the current IDs and their footprints. Do not invent new IDs.
2. Copy the existing greyboxes/models and affected `.tscn`/`.gd` files into a timestamped backup location before replacement; do not delete them.
3. Import these GLBs to `res://assets/equipment/` or the project's chosen asset folder. Keep the current scene paths/IDs stable via wrappers or deliberate path migration.
4. Important: The repaired `crew_bunk`, `locker`, and `common_table` use material-suffixed child mesh names (such as `Locker_Door_L__bone`) because a prior exporter silently dropped multiple meshes sharing the same node name. Retarget old interaction node paths safely. Do not rely on just `Locker_Door_L` still existing as a single mesh node.
5. Use simple collision primitives; preserve save/load and existing placement and zone behaviour. Do not include the demo wall behind the task lamp.
6. If an interaction needs several submeshes to move as a unit, put their shared logical prefix under an appropriate Node3D pivot instead of animating the individual materials independently.
7. The old printed labels and fake fixed screen artwork were removed intentionally. Any screen data must be read live from game state; blank dark glass is acceptable.
8. Check the room in actual Godot lighting and test duplicate placements, walking collisions, scaling, toggling existing equipment effects and persistence. Report any issue before moving to Power & Engineering.

Do not change the game's structural doors, windows or walls. Do not automatically alter electricity, food, hygiene or morale mechanics merely because these revised models contain interaction-ready parts.
