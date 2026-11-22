# Outpost One · Power Module

Godot model in `original/Power_Module.glb`. The GLB carries its PBR textures. The editable Blender file and the asset-generation scripts are in `source/`.

## Model contract

The model uses metres and sits on its runners at Y = 0 in Godot. In Godot coordinates the maximum dimensions are approximately 0.60 m wide, 0.50 m high and 1.00 m long.

| Node | Purpose |
| --- | --- |
| `PowerModule` | Model root at ground centre |
| `SocketFace` | Anchor at the keyed plug's mating plane, 0.268 m above the ground |
| `TowPoint` | Empty at the centre of the tow eye, 0.146 m above the ground |
| `StatusLamp` | Separate one-surface lens mesh at the physical indicator |
| `Handles` | Left and right glove-sized grab bars |
| `Skid` | Runners, wear shoes and mounting hardware |

The tow end faces +Z in Godot, using the Scout's GLB convention as the reference. Each attachment marker's local −Z points outward. Coincide the `SocketFace` and Walker `PowerSocket` positions with parallel up axes and opposing outward normals. The GAR‑Y and Walker game files are needed to check final orientation, clearances and socket fit in situ.

Copy `PowerModuleLamp.gd.txt` to a `.gd` script to use the optional lamp controller on the model root. Call `set_status(Status.ASLEEP)`, `set_status(Status.PLUGGED_IN)` or `set_status(Status.RUNNING)` for off, steady amber or steady white. Each instance owns a separate lamp material. The project's tow and docking code drives the state transitions.

## Source

Open `source/Power_Module.blend` to edit the individual parts. The file packs its textures. To regenerate the model, run `source/surface_maps.py` with Python, NumPy, Pillow and SciPy to produce a texture directory. Pass that directory to the Blender build script.

```sh
python source/surface_maps.py /tmp/outpost-power-textures
blender -b --python source/build_power_module.py -- --textures /tmp/outpost-power-textures
```
