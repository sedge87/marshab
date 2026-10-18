# Mars Habitat — Phase 2: Hydroponics

**Deliverable:** Five new hydroponics equipment models with embedded PBR materials, individual model previews, procedural source, a standalone Godot 4 review project and Codex instructions. **Room equipment only; not structure.**

**Status: Exported and visually previewed, not yet accepted in the user’s actual Godot habitat project.** Nothing has been replaced in the original game.

## Catalogue model set

| Existing catalogue ID | Triangles | Mesh groups | Exported dimensions (X × Y × Z, m) | Placement |
|---|---:|---:|---|---|
| `grow_tray` | 9,096 | 31 | 1.366 × 2.063 × 0.769 | Floor-standing |
| `seedling_station` | 3,144 | 35 | 1.28 × 1.44 × 0.713 | Floor-standing |
| `nutrient_mixer` | 3,372 | 35 | 1.15 × 1.877 × 0.767 | Floor-standing |
| `harvest_cart` | 3,030 | 23 | 1.106 × 1.133 × 0.73 | Floor-standing |
| `hydroponics_sensor_panel` | 1,352 | 17 | 0.884 × 0.791 × 0.183 | Wall-mounted |

The `grow_tray` asset is the improved three-level hydroponic grow rack. It replaces the earlier standalone grow-rack prototype as the candidate for the existing `grow_tray` catalogue entry; **do not automatically delete the original**.

## Included functional visual components

- **`grow_tray`** — three grow channels, sculpted lettuce-like crops, LED bars with emissive diffusers, recirculating fluid reservoir, pump, feed/return pipes, manual valve controls, status screen. **Existing active catalogue resource effect must be preserved.**
- **`seedling_station`** — germination bench, three independently identified plug trays, young plants, transparent humidity dome, lid catches, overhead LED and service drawer. **Future-effect item:** no new production/energy values have been introduced.
- **`nutrient_mixer`** — two dosing concentrate tanks, fill-level windows, feed hoses, valves, analog gauges, motor pumps and instrument panel. **Future-effect item.**
- **`harvest_cart`** — rolling harvest trolley, two named produce bins, plant harvest objects and caster wheels. **Cosmetic catalogue item.**
- **`hydroponics_sensor_panel`** — wall-mounted industrial environmental readout with buttons, alarm indicators and cable glands. **Future-effect item.**

**Readings on screens are illustrative visual placeholders, not telemetry from the running game.** The Godot review lights are demonstration lights, not connected to the habitat’s electrical simulation.

## File guide

- `models/*.glb` — five standalone Godot-friendly 3D models with embedded images and glTF PBR material assignments.
- `models/*.json` — exported bounds, triangle count, mesh groups and interaction name prefixes for each model.
- `textures/` — editable source images for material patterns, indicators, labels and displays. **Not required for basic GLB import.**
- `previews/*_hero.png` and `*_detail.png` — VTK off-screen renders of exported GLBs; lighting differs from Godot.
- `previews/hydroponics_phase2_contact_sheet.png` — room set comparison.
- `godot_review/` — standalone **Godot 4.3+** review gallery with proxy-collision prefabs and demonstration lights.
- `source/build_assets.py` — editable procedural modelling/material generator (Python, trimesh, PIL, numpy).
- `source/render_previews.py` — preview renderer (Python + VTK).
- `source/create_godot_review.py` — review project builder.
- `CODEX_INTEGRATION_PROMPT.md` — cautious project-level integration task.
- `REVIEW_CHECKLIST.md` — acceptance checks, including PBR and simulation validation.

## Asset design standard

- Metric world units: **1 Godot unit = 1 metre**.
- Axis and forward direction: **+Y up / −Z facing outward from model front**.
- Floor-standing models: origin at floor-centre, approximately. `hydroponics_sensor_panel` is **wall-mounted**, with origin centred on its mount plate at **(0,0,0)**.
- Palette: off-white composites, brushed aluminium, graphite polymer, restrained amber safety accents, warm-white LEDs and three tones of living foliage.
- Visual parts are merged by material and functional group to avoid excessive independent meshes while leaving important interactive pieces identifiable.
- Minor surface variation is primarily from texture maps rather than unnecessary bolts/screws.
- This is a game asset pack, **not a watertight 3D-printing pack**. The GLB is authoritative. No STL is required for Godot.

## Scope and limitations

This phase includes **only** the five hydroponics equipment catalogue types, not greenhouse equipment, structural windows, walls, doors, lighting infrastructure or placement-grid modules. No outside hull / pressure changes were attempted.

`grow_tray` is marked *Active effect* in the asset list. `seedling_station`, `nutrient_mixer` and `hydroponics_sensor_panel` are *Future*, while `harvest_cart` is *Cosmetic*. The existing `equipment_catalog.json` in the actual project remains the authority for **IDs, scene paths, footprints, valid zones and resource effects**. This pack does not supply guessed consumption/production numbers.

**Technical checks:** Each GLB was programmatically re-opened and its triangle counts, mesh bounds and material assignments inspected. The off-screen renders were also inspected. This does **not** substitute for Godot scene-level placement testing, draw call profiling, collision tests, save/load validation, light falloff or gameplay integration.

**How to review:** Extract ZIP, open `godot_review/project.godot` in Godot 4, let imports finish, run the gallery. Move using WASD, mouse look, Q/E height, Shift speed, Esc releases mouse. Check materials in your real habitat illumination before approving the set.
