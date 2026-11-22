# Outpost One · Site Plan Terminal

Godot model in `original/Site_Plan_Terminal.glb`. The GLB carries its PBR textures. The editable Blender file and generation scripts are in `source/`.

## Placement and screen

The terminal uses metres, with the origin at floor level beneath the base. The operator side faces +Z in Godot, matching the previously supplied Outpost One assets. The physical console is approximately 1.1 m tall and 0.6 m wide.

| Node | Purpose |
| --- | --- |
| `SitePlanTerminal` | Model root at floor level |
| `Screen` | Separate flat 0.440 × 0.2475 m display mesh with a full 16:9 UV rectangle |
| `UsePoint` | Floor-level standing point 0.640 m in front of the root. Its local −Z points towards the terminal. |
| `Feet` | Split runner base and floor pads on the ground plane |

The GLB opens with dark glass. For the live display, copy `TerminalScreen.gd.txt` to a `.gd` file and attach it to the model root or set its `screen_path` in a wrapper scene. Pass a 16:9 texture, such as the layout planner's `SubViewport.get_texture()`, to `set_screen_texture()`, and call `set_powered(true)` to display it. Turning the power off returns the screen to its imported glass material. The screenshot layout is a sample for the renders. The game provides its own plan view, placement and player interaction.

## Source

Open `source/Site_Plan_Terminal.blend` for editable hardware and packed textures. To rebuild the model, generate the texture directory with Python and NumPy, Pillow and SciPy, then pass the directory to Blender.

```sh
python source/surface_maps.py /tmp/outpost-terminal-textures
blender -b --python source/build_site_plan_terminal.py -- --textures /tmp/outpost-terminal-textures
```
