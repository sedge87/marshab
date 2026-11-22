# Outpost One · Walker 1

Full-scale revision for Chunk 1. Real-world metres, +Y up and −Z forward in the GLB. The asset origin is on the ground under the chassis centre. The frame is 8.4 × 11.2 m, the wheel centres are 15.4 m apart across the vehicle, and overall width is approximately 15.8 m. The General Module shell is 6.0 × 3.3 × 9.0 m and its floor starts at Y = 1.25 m.

- **Body** carries the driving deck, six hips, three ladder sections, four winches and the power berth. Use the six **Wheel_n** nodes for wheel spin. Each **Knee_n** hinges about its local X axis. **SealRing** is independent under **Wheel_1**.
- **Module** is a sibling of **Body**, with its pivot on its floor. Its full lowering travel is 1.25 m. **Cable_1…4** have pivots at their winches and contain a 1 m reference cable along local −Y. Scale the cable nodes along Y from 0.326 carried to 1.576 at touchdown. The editable Blender file opens in the carried pose with the preview-length lines.
- The perimeter frame clears the grounded module through the 3.2 m kneel. For this pose, put down the module, release the cables, retract the ladder, slide **WinchArm_1…4** 0.94 m outward, and fold **RideDeckFold** 92.7° forward about local X. The included visual script shows the transforms. **BerthStrut** telescopes so the tray can stay at its normal 0.35 m working height. **LadderShoe** folds inside the packed ladder envelope.
- **PowerSocket** is centred at (−3.60, 0.618, 0.649). Its local −Z points out of the socket. The round 1 power case seats at runner height 0.35 m when the two mating markers face one another.
- **Seat**, **Headlamp_L** and **Headlamp_R** are attach markers. **DeckScreen** is a blank 16:9 full-UV glass mesh that faces the seat. **Lamp** contains **lamp_glow_lamp_amber**.

`Walker1Visuals.gd.txt` is a reference Godot visual controller. Save it with a `.gd` extension to use it on the inner **Walker1** node of an inherited or instanced scene. Its inputs are normalized fractions and the game owns interpolation, driving, slotting the power case, lamp effects and runtime display textures.

## Editable source

The Blender scene has packed materials and independently editable hardware. The GLB groups repeated static hardware by material within its owning assembly while retaining the named moving parts and markers.

From the package root, regenerate with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy), then `blender -b -P source/build_walker.py -- --textures "$PWD/source/textures"`. To regenerate a preview, open the saved Blender file in background mode and run `source/render_asset.py` with a preview basename after `--`.
