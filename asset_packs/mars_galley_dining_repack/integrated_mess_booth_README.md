# Integrated Mess Table Booth — Galley & Dining Add-on

One single placeable dining asset for the Year 9 Mars Habitat Godot project.

## Design

Original Mars-habitat mess unit inspired by the *communal curved booth arrangement* of the user's Alien-era reference, restyled using the bright practical design language of *The Martian* and *Project Hail Mary*.

- Two curved, three-person benches, accessible via gaps at either end
- Warm-white composite shells with aluminium framing and physical panel divisions
- Muted teal seat pads and warm-grey upholstered backrests
- Oval central table with a structurally supported pedestal
- **Actual geometric cut-outs** for six cup wells and the central serving recess
- One separately named serving tray insert for potential interaction
- Recessed accent locator lights (visual-only; zero point lights in the GLB)
- No static screens or baked text
- Static parts batched by PBR material to reduce draw calls

## Technical specifications

- Approximate bounding dimensions **3.18 m wide × 2.55 m deep × 1.13 m tall**.
- Model origin (0,0,0) is the floor centre, Y points up, -Z points forward.
- Geometry **16,608 triangles**, **13 GLB mesh nodes**, **12 distinct PBR materials**.
- Single placed asset, **not** six separate chairs and table.
- Recommended 3.5 m × 3 m usable clear area or larger; do not fit into a 1.5 m equipment slot.
- Asset catalogue ID proposal: `integrated_mess_booth` (not an existing confirmed catalogue entry).

## Files

- `models/integrated_mess_booth.glb`: Godot asset with embedded PBR factors.
- `models/integrated_mess_booth_geometry.stl`: optional geometry-only export, not tested as a printable STL.
- `previews/mess_booth_contact_sheet.jpg`: actual GLB rendered from multiple angles.
- `godot_review/`: Godot 4 review project, sample scene, basic collisions and interaction markers.
- `source/`: editable procedural model generator and rendering script.
- `CODEX_INTEGRATION_PROMPT.md`: instructions for integration into the existing game.

## Integration notes

The included `IntegratedMessBooth.tscn` contains deliberately simple approximate collision shapes, plus interaction-point markers. Their suitability must be tested in your actual habitat before finalising. A sample GDScript emits `meal_requested` and `briefing_requested` but intentionally **does not change food, wellbeing or mission progression**. Connect those signals to the game's real systems during integration.

No files from the existing habitat game or previously generated Galley pack have been overwritten.
