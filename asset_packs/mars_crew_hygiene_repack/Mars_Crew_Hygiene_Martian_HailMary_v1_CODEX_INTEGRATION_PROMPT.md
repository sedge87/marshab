# Codex handoff — Crew Hygiene models

Integrate these two *new* Godot-compatible GLBs only **after** inspecting the current game's equipment catalogue and placement implementation:

- `habitat_toilet.glb` — suggested internal ID `hygiene_toilet`
- `low_water_wash_station.glb` — suggested internal ID `hygiene_shower`

**Do not** change any wall, door, window, room-building/grid or exterior habitat systems. Back up any currently installed placeholder before replacement. Existing equipment IDs, zone constraints and gameplay must take priority over the suggestions above.

Place as ordinary floor equipment with simple, non-blocking-to-player collision where practical. Check true footprint and entry clearance in the existing room size. Preserve GLB scale (1 unit = 1 metre), origin and -Z orientation. Avoid turning the tall wash-station backboard into a structural wall.

Demonstration signals and part names are in the `godot_review/` scripts. Prefer existing equipment interaction UI and resource framework. Keep gameplay modest: flushing/operating toilet may consume a little power; washing uses a small amount of water and produces greywater for the Water Reclaimer. Do not implement elaborate real plumbing or pressure simulations. Connect game status to real state rather than displaying static fake numbers.

Re-test after placement: lighting, dark side/cavity appearance, collision, player navigation, interactions, resource flow, save/load and FPS with several pieces placed. Do not claim functionality until those checks pass.
