# Outpost One · Chunk 2 survey stakes

Two Godot-ready models for the survey line in scenes 10–11. The GLBs use metres, +Y up and −Z forward. Materials and texture maps are embedded. The surfaces carry wear and oxide dust, with plain fabric and no printed markings. Survey-blue shafts and flags stand out against red terrain. The flag has a pale sewn border and the signal lens remains amber.

| File | Use |
| --- | --- |
| `original/Survey_Stake.glb` | A 0.90 m hand-planted stake with a hardened tip, pressure-glove grip, fabric flag and guarded amber reflector. |
| `original/Survey_Stake_Bundle.glb` | Six stowed stakes with folded flags, protective end shoes, buckle straps and a carry handle. Place its root at the floor of the stores pallet. |

In the individual asset, **Stake** has its origin at the tip. Place the model at ground level or sink its root by the desired planting depth. **GripPoint** is centred on the handle at 0.506 m. The separate **Flag** pivots at its mounting edge and **Head** is the independently addressable amber lens.

`SurveyStakeVisuals.gd.txt` is a visual controller for the inner **SurveyStake** node. Copy it as a `.gd` script to use `set_flag_angle(degrees)` and `set_signal(lit, color)`. The game controls hand placement, planting, wind animation and survey logic. The bundle is one static GLB, with its **BundleGrip** empty centred on the handle.

## Source

The Blender files have packed materials. Generate textures with `python source/surface_maps.py source/textures` (NumPy, Pillow and SciPy). Run `blender -b -P source/build_line_stakes.py -- Survey_Stake --textures "$PWD/source/textures"`, or use `Survey_Stake_Bundle` in the same command. The preview script takes one or more JPG basenames after Blender's `--`.
