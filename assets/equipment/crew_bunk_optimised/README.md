# Crew Bunk — built-in sleeping berth (optimised prototype v2)

**Status: ready for in-project review; not approved or verified in your habitat yet.**

This package contains **one asset only**: the Living Quarters `crew_bunk`, a grounded modular sleeping berth intended for the existing Mars habitat project in Godot 4. No other room assets are modified.

## Asset specifications

| Field | Value |
|---|---|
| Identifier | `crew_bunk` — retain the project's existing catalogue ID |
| Nominal size | 2.24 m wide along X × 1.12 m deep along Z × 1.84 m tall along Y |
| Model bounds | X ±1.11 m; Y 0.05–1.821 m; Z −0.561 to +0.555 m |
| Model origin | (0,0,0), nominal equipment floor centre |
| Godot forward | Local **−Z** is the accessible open/front face |
| Export | `.glb` (glTF 2), textured PBR materials embedded in GLB |
| Performance | **2,076 triangles**, **24 mesh nodes**, **9 shared materials** (5 core surfaces + lights, screen, decals, accent) |
| Collision | **5 primitive box shapes** in the supplied scene (no automatic concave collider) |
| Scale | Metres, 1 Godot unit = 1 metre |

Designed as an easy-to-read, low-poly, slightly lived-in crew alcove:
* Pale composite housing with brushed anodised frame and dark polymer reveals.
* Padded mattress, pillow, sage blanket and restrained bed straps.
* Three labelled under-bed drawer fronts with separate meshes for visual opening.
* Personal shelf, ventilation grille, LED reading puck and status display.
* Curtain track, parked curtain and an optional separate closed curtain panel.
* Custom 512px fabric/metal/polymer texture maps embedded in the GLB; six separate PNGs retained for edits.

For better performance, **fixed geometry is batched by material**. Named independent components are retained for drawer openings, display and light. This is not a photogrammetric/high-poly asset and tiny seams are approximated rather than individually modelled.

## Files

- `model/crew_bunk_optimised.glb` — **import this for Godot** (main visual model).
- `model/crew_bunk_privacy_closed.glb` — separate closed curtain state.
- `model/crew_bunk_optimised_geometry_only.stl` — *reference mesh only*. It has disconnected layers and is not a ready-to-3D-print watertight model. STL does not preserve materials.
- `godot/crew_bunk_optimised.tscn` — optional standalone scene with model, lamp and simple collision.
- `godot/crew_bunk_optimised.gd` — light/curtain/drawer visual interaction hooks.
- `preview/` — orthographic inspection images rendered from the actual GLB mesh, not concept art or in-engine screenshots.
- `source/build_crew_bunk.py` — procedural model source; uses numpy, trimesh and Pillow.
- `source/render_preview.py` — optional preview source; also uses numba.
- `asset_report.json` — bounds, vertices, triangles and component report.
- `reference_backup_previous_prototype/` — copy of the **earlier ChatGPT prototype**, not the original game's greybox.

## Installation in Godot

1. In the existing project, back up `data/equipment_catalog.json`, the scene currently used by `crew_bunk`, and any dependent scripts **before editing**. Do not overwrite the original in-game greybox. A copy of the earlier ChatGPT model is provided separately, but the actual game's original assets are not available in this pack.
2. Copy this **entire** `crew_bunk_optimised` folder to `res://assets/equipment/crew_bunk_optimised/`. The packaged `.tscn` uses this exact path. If placing elsewhere, adjust its three external resource paths.
3. Wait for Godot to import both GLB files. Open `godot/crew_bunk_optimised.tscn`. Inspect front face (−Z), tint, normals, lit and unlit states, collision and Godot material roughness.
4. Test visual functions on the scene root: `set_reading_light_enabled(bool)`, `set_privacy_closed(bool)`, `set_drawer_open(index: int, opened: bool)`, `toggle_drawer(index: int)`.
5. Compare the actual catalogue `footprint`, valid room zones, resources and existing `asset_scene` path before substituting in the existing placement flow. The footprint was not supplied as game data; **do not assume** that these dimensions automatically match placement grid rules.
6. Only after checking collision, placement, moving parts, light draw, simulation effects and save/reload should the greybox be replaced. Preserve backups.

## Simulation responsibilities

The existing catalogue identifies `crew_bunk` as an **active-effect** asset. Its existing resource or crew effects remain authoritative: this package does **not** invent new power, oxygen, mood or stamina values, and doesn't rewrite the simulation. The `reading_light_changed`, `privacy_curtain_changed`, `drawer_changed` signals are meant as integration hooks. Your existing equipment controller may connect to them and enforce power availability.

**Performance note:** A small omnidirectional task light without realtime shadows is provided; in a large dorm, consider enabling it only when nearby or under appropriate power state. The visual material emission itself is cheap, but active physical lights have extra rendering cost.

## Review checklist (not yet passed in your project)

- [ ] Bunk fits existing room, wall, ceiling, grid and doorway clearances.
- [ ] PBR texture colours and normal orientation render correctly under habitat lighting.
- [ ] All front-facing parts visible and collision doesn't block player movement.
- [ ] Light on/off states work; draw calls acceptable with six bunks instanced.
- [ ] Closed curtain does not obstruct scene/UI, and opened drawers don't break pathing.
- [ ] Existing `crew_bunk` simulation effects retained and save/reload round-trip passes.
- [ ] Performance checked with all six crew bunks and other Living Quarters furniture.

## Limitations

This is a procedural low-poly game mesh designed to be iterated. No in-project gameplay integration or Godot rendering test has been performed here, because the live Godot project is not part of this upload. Materials and GLB structure have been validated independently, but an in-engine test is still needed before final approval.
