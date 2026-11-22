# Outpost One · GAR-Y canopy snag

A torn, dust-stained canopy remnant and three separate suspension lines. The GLB origin is on the ground below GAR-Y’s centre, with +Y up and −Z forward. Set the canopy asset at GAR-Y’s model origin. The GAR-Y visible in the JPGs is the existing Field Upgrade asset used to check the fit.

| Node | Role |
| --- | --- |
| `Cloth` | Torn gores, separated skirt remnant, tapes and frayed edges. Remains visible after the release. |
| `Line_1`, `Snag_1` | Front-left wheel line and target. |
| `Line_2`, `Snag_2` | Rear-right wheel line and target. |
| `Line_3`, `Snag_3` | Mast line and target. |

Each line includes its wrap. `CanopySnagVisuals.gd.txt` provides visual toggles for an individual line or a three-bit release mask (front wheel, rear wheel, mast). Rename it to `.gd` to attach it to the inner **CanopySnag** node. The interaction and trigger handling live in the game.

The Blender scene has packed materials. Regenerate the maps with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy). Build with `blender -b -P source/build_canopy.py -- --textures "$PWD/source/textures"`. To render the fit, run `source/render_asset.py` from the saved Blender scene, supplying the preview basename and `--gary /path/to/GAR_Y_Field_Upgrade.glb` after Blender's `--`.
