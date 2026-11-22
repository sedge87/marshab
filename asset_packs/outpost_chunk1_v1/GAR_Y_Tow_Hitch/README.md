# GAR-Y Tow Hitch

`original/GAR_Y_Tow_Hitch.glb` is the fitted hitch for the supplied GAR-Y. The GLB has embedded textures. The Blender file in `source/` keeps the hardware editable.

The hitch root mates with `GarY/Body/RearMount` at an identity local transform. `MountPlate` seats against the backing plate. `Reel`, `Clip` and `CableOut` identify the reel, stowed clip and cable exit. The included visual controller uses the game's paid-out cable length to turn the reel.

Rebuild with Blender by generating the surface textures with `source/surface_maps.py` and running `source/build_radar_and_hitch.py` with `--asset Hitch` and the texture directory.
