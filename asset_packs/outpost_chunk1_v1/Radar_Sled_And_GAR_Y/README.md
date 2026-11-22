# Outpost One · Radar Sled and GAR-Y Tow Hitch

The pack contains the radar sled, the matching detachable hitch and a copy of the supplied GAR-Y with the fitting points already installed.

| File | What it contains |
| --- | --- |
| `original/Radar_Sled.glb` | Ground-facing antenna housing, scuffed skid runners, tow bridle, status lens and embedded textures |
| `original/GAR_Y_Tow_Hitch.glb` | Fitted mounting plate, independently pivoted cable reel, exit guide and stowed quick-release clip |
| `original/GAR_Y_with_mounts.glb` | The supplied GAR-Y with the rear backing plate, `RearMount`, `FrontMount` and `MastMount` added |

## Fitting points

- The radar sled faces −Z in Godot, like GAR-Y. It measures about 1.18 m long, 0.70 m wide and 0.43 m high, with grounded skids. `TowPoint` is at the centre of the forward eye. `ScanOrigin` is 0.079 m above the ground under the radome, with local −Z pointing down.
- Attach `GAR_Y_TowHitch` beneath `GarY/Body/RearMount` with an identity local transform. The marker is at `(0, 0.446, 0.450)` m in Body coordinates. Its local −Z points towards the rear.
- Attach the cable to the hitch's `CableOut` and the sled's `TowPoint`. The earlier Power Module faces +Z when dropped in unrotated. Turn it 180° to point towards GAR-Y before towing, or align it using its `TowPoint`.
- The straight fit preview uses a 0.68 m horizontal gap between the fairlead and the tow eye. Both payloads were checked against the wheels, chassis and fitted hitch at 0°, ±20°, ±40° and ±55° on level ground. The game determines handling on uneven ground and the final payout limits.

## Visual hooks

Copy the included `.gd.txt` files to `.gd` scripts if using the optional visual controllers. Attach `TowHitchVisuals` to the hitch root and pass paid-out line length to `set_paid_out_length()`. The game draws the deployed line and can instance its clip at the payload end. Attach `RadarSledVisuals` to the sled root and call `set_scanning()` to drive the amber lens.

The game's tow behaviour, scan results and Site Plan Terminal survey display connect to these markers. The supplied GAR-Y binary meshes and original animation pivots are preserved in the revised copy.

## Editable source

`source/` contains the sled and hitch Blender files with packed maps, the build and render scripts, and a patch script that adds the fittings to a copy of the supplied GAR-Y GLB. To reproduce the assets:

```sh
python source/surface_maps.py /tmp/outpost-radar-textures
blender -b --python source/build_radar_and_hitch.py -- --asset Sled --textures /tmp/outpost-radar-textures
blender -b --python source/build_radar_and_hitch.py -- --asset Hitch --textures /tmp/outpost-radar-textures
python source/add_gar_y_mounts.py /path/to/GAR-Y.glb original/GAR_Y_with_mounts.glb
```
