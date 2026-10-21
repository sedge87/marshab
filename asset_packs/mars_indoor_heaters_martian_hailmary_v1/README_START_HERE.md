# Mars Habitat — Indoor Heaters (The Martian / Project Hail Mary style)

Two **actual lightweight GLB models** for General Habitat Equipment, plus example Godot 4 scenes and simple interaction logic. Inspired by practical, predominantly white research-habitat hardware. No exterior heaters.

## Deliverables

- `models/wall_cabin_heater.glb` — wall-mounted convection-style heating panel; mount pivot at back wall centre; **0.836 × 0.479 × 0.238 m**, approx. **1,700 triangles**, **14 mesh groups**.
- `models/portable_utility_heater.glb` — moveable forced-air-style unit with handle, grille, filter and feet; floor pivot; **0.593 × 0.744 × 0.416 m**, approx. **1,652 triangles**, **17 mesh groups**.
- `godot_review/` — Godot 4 demonstration scenes, simplified collisions, and `heater_controller.gd` showing the interaction and power-request API.
- `previews/` — real off-screen renders of GLB geometry from three camera angles each.
- `source/build_heaters.py` — editable Python/trimesh source. Requires `numpy` and `trimesh`. `source/render_heaters.py` additionally needs `vtk` and `Pillow`.
- `HEATER_GAMEPLAY_RULES.md` — practical connected-system interaction and balancing rules.
- `CLAUDE_INTEGRATION_PROMPT.md` — ready to provide to Claude with your actual game project.
- `asset_manifest.json` — dimensions, geometry metrics, named parts.

## Demo controls

Open `godot_review/project.godot` in Godot 4 and press Play:

- `1`: change wall heater OFF → LOW → HIGH → OFF.
- `2`: change portable heater OFF → LOW → HIGH → OFF.
- `0`: cut power to both heaters.
- `9`: restore demo power.

The demo calculates requested electricity and effective heat, but does **not** modify a real habitat's resources. It has not been executed with the Godot editor in this modelling environment.

## Quality / integration notes

These models intentionally contain **no fake data screens or baked readable labels**. They use separate named static and interactive mesh groups, not excessively high geometry density. Status indicators are hidden/displayed by the supplied GDScript based on actual electrical availability. All equipment should remain subject to the game's existing placement, collisions, interaction, electric supply, resource effects and save systems.

**Important:** Only modify the game after checking current project code with Claude. The supplied scenes are demonstrators, not substitutes for existing equipment integration.
