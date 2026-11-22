# Outpost One · Rock hammer

Metres, +Y up, the head at the −Z end of the handle. Overall length is about 0.38 m and head width is 0.17 m. The GLB origin and empty **Grip** are both at the hand grip, suitable for the first-person tool socket. **Head** is a separate static mesh. **StrikePoint** sits on the face of the flat end, with its local −Z aligned to the outward face normal.

The Blender scene has packed materials. Regenerate with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy), then `blender -b -P source/build_hand_tools.py -- --tool Rock_Hammer --textures "$PWD/source/textures"`. The rendering script takes a preview basename after Blender's `--`.
