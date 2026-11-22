# Outpost One · Walker 1 Fit-Out Crates

All three Godot GLBs in `original/` contain moulded shells, arced hinge lids, protective inserts and removable cargo. The models import closed and loaded, with metres as the unit, an origin on the ground and the latch side facing +Z in Godot.

| Model | Closed width, height and depth, including hardware | Cargo nodes under `Contents` |
| --- | --- | --- |
| `Fitout_Crate_Small.glb` | 0.584 × 0.242 × 0.393 m | `WorkLight`, `CoiledPowerLead` |
| `Fitout_Crate_Medium.glb` | 0.888 × 0.329 × 0.609 m | `FoldedChair`, `RackRails` |
| `Fitout_Crate_Large.glb` | 1.299 × 0.711 × 0.789 m | `PackedSitePlanTerminal` |

The small and medium crates carry transport-state equipment meshes. The large crate contains the actual Site Plan Terminal geometry laid on its back, with padding to protect its feet, pedestal and display housing. For placement, use the existing upright terminal scene with its working screen. The packed copy represents the terminal before it is taken from its case.

The `Lid` pivot is centred on the rear hinge pins. It opens 103° around local −X. For the optional `FitoutCrateController.gd.txt`, copy it to a `.gd` file and attach it to the crate root. The opening and closing helper emits `lid_state_changed` on arrival. Once the lid is open and the game has awarded the item, call `remove_packed_item()` with its cargo node name. This leaves the fitted inserts visible. Collection, inventory and placement are driven by the game. The game can persist the closed or open state and collected cargo IDs with its existing save data.

## Source and previews

`source/` contains one editable Blender file per size with packed textures, plus the mesh, texture and render scripts. The matching terminal Blender file is the input for a clean rebuild of the large model.

```sh
python source/surface_maps.py /tmp/outpost-crate-textures
blender -b --python source/build_fitout_crate.py -- --textures /tmp/outpost-crate-textures --size Small
blender -b --python source/build_fitout_crate.py -- --textures /tmp/outpost-crate-textures --size Medium
blender -b --python source/build_fitout_crate.py -- --textures /tmp/outpost-crate-textures --size Large --terminal /path/to/Site_Plan_Terminal.blend
```
