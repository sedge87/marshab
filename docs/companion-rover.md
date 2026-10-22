# GAR-Y: the companion rover

**GAR-Y — Geological Analysis Rover, Y-Class.** GAR-Y is a multipurpose rover designed for geological surveys, surface sample collection, terrain mapping and identifying potential water-ice deposits.

In game, look at GAR-Y to see its name. E pings it (it chirps and sweeps its mast), and I shows the description above. It's marked "GAR-Y" on the survey map. The name and text are in `scripts/companion_rover.gd` (`NAME`, `FULL_NAME`, `ABOUT`).

It's an optional, self-contained companion for first-person exploration. (Files and code still use the old "scout rover" names.)

## Included files

- `assets/companions/mars_scout_rover.blend` — Blender source scene with named rig bones, wheels, mast, flashlight housing and animation clips.
- `assets/companions/mars_scout_rover.glb` — exported Godot model.
- `assets/companions/textures/` — painted panel, dark-metal and rubber texture maps used by the rover materials.
- `scenes/mars_scout_rover.tscn` — collision and model wrapper.
- `scripts/companion_rover.gd` — terrain-following, threshold stepping, wheel rotation and companion behaviour.

The GLB contains named `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR` nodes, `Mast_Control`, a `MarsScoutRover_Rig` armature, and clips for wheel roll, mast scan and idle suspension. Godot rotates the wheels from actual travel distance, rather than relying on a looping animation, so the rover does not appear to glide. A Godot spotlight is mounted at the physical flashlight lens. The rover chooses a forward-side scouting spot, stays there while the astronaut looks around, scans, makes a shallow idle figure-eight, and occasionally plays a quiet two-note radio chirp.

## Safe removal

The rover is controlled solely by `SPAWN_SCOUT_ROVER` in `scripts/mars_world.gd`.

- Set it to `false` to disable the companion.
- Or set `SPAWN_SCOUT_ROVER` to `false`, then remove `scenes/mars_scout_rover.tscn`, `scripts/companion_rover.gd` and the two rover files under `assets/companions`. The world loads the rover scene only when the toggle is enabled.

Nothing in player movement, habitat construction, resources or saves depends on it.
