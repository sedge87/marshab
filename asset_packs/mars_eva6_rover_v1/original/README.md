# OUTPOST ONE: MARS — EVA-6 Pressurised Exploration Rover

A grounded NASA-inspired six-wheel, pressurised, drivable exploration vehicle, with white ceramic body, dark panoramic glazing, forward searchlights, roof solar module, redundant antennas, six rugged treaded wheels, rear docking airlock, equipment boxes and exposed suspension.

**Godot:** 4.x, Compatibility renderer friendly. **Format:** glTF 2.0 binary (.glb). **Units:** metres; X right, Y up, -Z forward. Approx. dimensions 3.5 m wide incl. wheels × 6.5 m long × 4.2 m tall incl. antennas.

## Add to your game

1. Copy the entire `Outpost_One_Rover` folder into the **root** of your Godot project (so the path is `res://Outpost_One_Rover/`).
2. Let Godot import both GLB meshes.
3. Drag `res://Outpost_One_Rover/scenes/PressurisedRover.tscn` into your vehicle bay. Place the rover root slightly above the floor (usually Y +0.5 to +1.0). The six wheel physics nodes need a physical floor to rest on.
4. Press play and drive: **W/S** forward/reverse, **A/D** steer, **Space** brake, **C** switch cockpit/chase camera, **R** upright when stationary.
5. Your game likely already has a player camera: when the player enters the rover, disable or hide the player's camera/controller, and activate the rover camera and inputs; when they exit, reverse that process. The rover scene currently assumes it has input focus whenever in the level.

For instant testing, open `scenes/RoverDemo.tscn` and select **Run Current Scene** (F6).

## Included
- `models/rover_chassis.glb`: the full, textured-by-material body geometry (no wheels).
- `models/rover_wheel.glb`: one detailed, separate wheel, instantiated 6×.
- `scenes/PressurisedRover.tscn`: six-wheel `VehicleBody3D` setup with collision, suspension, cameras, HUD.
- `scenes/RoverDemo.tscn`: quick test scene with terrain, lighting and rover.
- `scripts/rover_controller.gd`: usable keyboard driving and camera controls.
- `build_rover.py`: reproducible procedural geometry source, uses `trimesh` and `numpy` (Blender is **not** required).

## Notes
- The cabin windows are tinted opaque-glass material, **not actual transparent glass**, to keep the Compatibility renderer robust. The cockpit camera looks forward from inside but the interior is **not furnished**. A walkable fully modelled cabin or dockable airlock can be added separately.
- For integrated game controls you should gate keyboard input behind an `is_occupied` boolean; the delivered standalone controller always processes controls.
- `VehicleBody3D` is arcade-oriented. Expect to tune engine force, friction, suspension, brake and mass for your scene scale and terrain.
- This is original procedural geometry, no third-party asset licensing dependencies.
- No real-life drive testing or in-engine validation has been performed on this system; physics behavior may require tuning in your Godot build.
