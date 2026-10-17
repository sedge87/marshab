# Interior greybox replacement — first safe batch

Date: 17 October 2026  
Branch: `codex/interior-grounded-first-batch`  
Safety checkpoint: `ba79b00` (`chore: safety checkpoint before interior art replacement`)

## Safety record

Before changing any presentation path, the snapshot tool in the supplied handoff was run without modifying the handoff folder.

- Snapshot: `backups/interior_greybox_20261017_091213/`
- Manifest: `backups/interior_greybox_20261017_091213/SNAPSHOT_MANIFEST.json`
- Snapshot report: 92 files, 5,913,305 bytes; it recorded that `assets/equipment/` did not yet exist.
- Source `.blend` files have not been overwritten or deleted. The new source is a separate file.

The checkpoint commit includes pre-existing local rover/corridor/audio work that was already staged when the checkpoint was made. It is a safety point, not a claim that those changes are interior art.

## Audit

| Surface | Current source | First-batch handling |
| --- | --- | --- |
| Equipment identity, permitted rooms, footprint, cargo and resource effects | `data/equipment_catalog.json`, `scripts/equipment_catalog.gd` | Unchanged; IDs and `asset_scene` paths are retained. |
| Equipment presentation proxy | `BuildController._equipment_visual()` in `scripts/build_controller.gd` | Loads a catalogue GLB when available. The original sized proxy is now an explicit fallback only. |
| Equipment collision and removal | `StaticBody3D` / `CollisionShape3D`, `placed_equipment`, `_equipment_visuals` in `scripts/build_controller.gd` | Unchanged. Collision continues to use the catalogue footprint, independent of art. |
| Powered-state indication | `grid_powered_light` group and `_apply_grid_power()` | Generated `Light_`, `Screen_` and `Status_` meshes join the existing group; the old lamp remains only if no compatible model indicator exists. |
| Exterior hull, corridors, airlocks and terrain | `assets/showcase_modules/`, `assets/habitat_modules/`, world scripts | Not modified. |
| Save/load | No habitat-equipment persistence format was found in current code | No format or assumption changed. |
| Interior walls and doors | `data/parts_catalog.json` has no placement path for these objects | Exported as non-integrated kit art only; structural/pressure rules were not bypassed. |

## Completed source and exports

The procedural generator is [generate_interior_first_batch.py](../blender/generate_interior_first_batch.py). It is compatible with the installed Blender 5.2.2 LTS and creates isolated collection `MH_InteriorFirstBatch`.

Editable Blender source:

- `blender/interior_first_batch_source.blend`

Integrated equipment GLBs (existing catalogue `asset_scene` paths):

- `assets/equipment/crew_bunk.glb`
- `assets/equipment/grow_tray.glb`
- `assets/equipment/air_recycler.glb`
- `assets/equipment/science_workbench.glb`
- `assets/equipment/cargo_rack.glb`

Structural kit exports, intentionally not yet placeable:

- `assets/interior_kit/partition_solid_3m.glb`
- `assets/interior_kit/partition_solid_1p5m.glb`
- `assets/interior_kit/interior_window.glb`
- `assets/interior_kit/interior_sliding_door.glb`
- `assets/interior_kit/pressure_bulkhead_door.glb`

The assets use warm painted composite panels, graphite frames, aluminium service parts, restrained orange labels, filtered grilles, removable access panels, service ducts and low-key operational indicators. They do not use game-reference imagery or proprietary textures.

## Code and verification

Modified:

- `scripts/build_controller.gd` — catalogue-model loading, original safe fallback, existing collision, existing power-light binding.
- `tests/interior_asset_loading_test.gd` — validates five model paths, model loading, retained collision, power indicators and a missing-asset fallback.
- `tests/interior_asset_gallery.gd` — Godot preview capture harness for the five equipment items and three structural kit samples.
- `scripts/interior_build_controller.gd` and `docs/interior-construction-mode.md` — separate first-person, free-position interior construction. Exterior grid construction remains unchanged.

Commands attempted:

| Check | Result |
| --- | --- |
| Blender generator run | Passed; all ten GLBs and the editable `.blend` were written. |
| Blender visual inspection | Passed for `grow_tray`; it has a 2.65 × 1.72 × 2.76 m detailed rack, trays, irrigation, plants and service panel. |
| Godot headless editor/import check | Exit code 0. |
| `equipment_inventory_test.gd` | Exit code 0, but console output was truncated after Godot reported it could not write `user://logs/godot.log`; retain as a rerun requirement on a normal local launch. |
| `interior_asset_loading_test.gd` | Passed after the local Godot log directory was repaired: five GLBs, collision, grid indicators and safe fallback. |
| `construction_repair_test.gd` | Not verified in this environment after the logging issue interrupted the batch runner. |
| Runtime PNG gallery | Not produced: the headless Godot session terminated after the same `user://logs/godot.log` limitation before it wrote preview files. |

Manual verification still required: in-game placement in each valid zone, collision/player navigation, removal, save/load when a persistence implementation is present, power-off appearance in a normal render session, interaction (`E`), frame-rate profiling, and runtime screenshots. No unverified item is treated as passed.

## Interior construction mode update

Interior equipment is no longer architecturally tied to the exterior plan grid. When the player is standing inside a completed room, `B` opens a reticle-based first-person construction controller. It places the first vertical-slice equipment at exact world positions, validates the selected room/surface/cargo cost, rotates in 15-degree increments, supports targeting removal, and keeps its own `placed_interior` records. Both old and new records feed cargo and resource effects. The player-facing control and data contract are documented in `docs/interior-construction-mode.md`.

Additional verification since repairing the local Godot log directory:

| Check | Result |
| --- | --- |
| `tests/interior_free_placement_test.gd` | Passed. |
| `tests/equipment_inventory_test.gd` | Passed: 46 items, placement, refund and undo regression coverage. |
| `tests/interior_asset_loading_test.gd` | Passed: five GLBs, collision, grid indicators and fallback. |
| Mars World headless startup | Passed with no runtime errors recorded. |

## Next assets and open issues

1. Repair the local Godot `user://logs` write permission and rerun the listed tests plus the gallery harness; attach one Godot runtime screenshot for every integrated prototype.
2. Review the five assets in a normal Godot render session before expanding the batch.
3. Continue according to `CODEX_INTERIOR_HANDOFF/03_ASSET_SPECS/equipment_inventory_from_project.csv`, respecting each existing `asset_scene` filename (especially aliases such as `personal_locker.glb`).
4. Keep walls, windows and doors as art-kit objects until a separately tested interior structural-placement design is approved.
