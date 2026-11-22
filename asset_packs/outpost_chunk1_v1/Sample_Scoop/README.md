# Outpost One · Sample scoop

Metres, +Y up, the pan at the −Z end of the handle. Overall length is about 0.40 m, with a formed steel pan about 0.10 × 0.12 m. The GLB origin and empty **Grip** are at the hand grip. **Pan** rotates around its local X axis at the joint. **PanTip** is on the lip and follows the pan.

`SampleScoopVisuals.gd.txt` provides a visual pan-angle setter that takes degrees, positive toward the ground. Rename it to `.gd` to attach it to the inner **SampleScoop** node.

The Blender scene has packed materials. Regenerate with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy), then `blender -b -P source/build_hand_tools.py -- --tool Sample_Scoop --textures "$PWD/source/textures"`. The rendering script takes a preview basename after Blender's `--`.
