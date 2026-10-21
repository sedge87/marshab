# Codex handoff — Integrate Mission Operations equipment, one room only

We are adding a **Mission Operations** zone to our Year 9 Mars habitat game. Install the three new Godot GLB assets in `models/` (or the project's established asset folder). Match our current bright The Martian / Project Hail Mary equipment style; retain the 3D model design and PBR materials. **Do not touch the interior structural building kit, walls, pressure hull, exterior meshes, or any other room zones.**

## Safe migration

1. Audit `data/equipment_catalog.json`, existing zone definitions and `mission_operations`/`communications_station` IDs first. Mission Operations was a proposed additional zone in the project brief; do not assume the original game has matching catalogue entries. Create entries only using the existing schema, and prefer the correct pre-existing ID if any already exists.
2. Back up any existing placeholders, GLBs and affected scripts/scenes. Do not delete backups or overwrite original assets.
3. Add these separate placeable assets with appropriate footprints:
   - `mission_planning_console.glb` — floor-based operations console, approximately 1.73 m wide.
   - `mars_survey_board.glb` — floor-standing 2.44 m survey board (larger than one 1.5 m equipment cell). Allow it as a larger item and keep a clearance path.
   - `communications_data_rack.glb` — floor-standing radio/data rack, approximately 1.37 m wide.
4. Ensure forward is local `-Z`, upward `+Y`, and visual/collision alignment and pivots remain correct.

## The map matters most

Use the `godot_review/scripts/mission_map_ui.gd` and `mission_ops_review.gd` as **examples** of a live `SubViewport` text/map surface. Use the game's own mission manager, rover position, world terrain data and zone/system-readiness information instead of the sample hard-coded missions. The GLB intentionally contains a dark empty `map_screen_mount`; never replace that with a fixed screenshot or fake numerical readout. Ensure the map display quad faces `-Z`, not backwards/mirrored.

A suitable result should have:
- **Mars overview:** real NASA/USGS global basemap or simplified accurate context view, credited appropriately, with a current landing-region marker.
- **Local region:** actual game terrain or 2D image registered to the real game coordinates, with the habitat, sample targets, candidate ice deposits and rover route shown at their correct locations.
- **Mission selection:** interact to select a target, see a short objective and *actual* required systems (charged rover, sample kit, science lab, drill where relevant), then accept a mission.
- **Map updates:** mission markers and requirements update with game state; save/reload preserves discovered sites and mission progress.

The current images and sites in `data/` and `godot_review/assets/` are **visually illustrative only** and should be replaced before use as educational maps in class. Never represent fictional data as actual Mars geography.

## Interactions and performance

- Console: operate the mission selector, access mission UI, optionally open card tray/drawer.
- Survey board: inspect Mars / local region and selected mission; physical map mode selector can switch map mode.
- Data rack: toggle uplink, inspect an inserted data module, transmit a completed geology/sample report to progress a mission.
- Prefer contextual UI, short interactions, subtle mechanical animation, one live map viewport, and shared ambient lighting. Avoid static fake screens, backwards baked text and per-prop dynamic real-time lights.
- Keep existing simulated power and science outputs. No added complex electrical networking or long quiz flow.

Test scene import, orientation, positioning, performance in a populated room, interactive map orientation, mission progression, collision, navigation, and saving/reloading. Report what was actually implemented and what remains a demo.
