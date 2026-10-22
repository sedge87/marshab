# GAR-Y: the companion rover

**GAR-Y — Geological Analysis Rover, Y-Class.** GAR-Y is a multipurpose rover designed for geological surveys, surface sample collection, terrain mapping and identifying potential water-ice deposits.

## What it does (22 Oct revamp)
- **Follows you:** outdoors it scouts beside you. Indoors it potters between the rooms near you. In a dust storm it huddles closer and its eyes go red.
- **Surveys (outdoors, by day):** every 2½–5 minutes it drives 7–12 m off and scans the ground with its head. On buried ice (25% or richer, with no flag within 10 m) it reaches down and plants a glowing cyan flag, then a toast gives the richness. Anywhere else it scoops a regolith sample.
- **Moves clutter (indoors, very rare):** about every 20–30 minutes it picks up a small Odds & Ends item from the floor of its room. It carries the item in its gripper and puts it down at a new spot that passes the normal placement rules. The new spot is saved, and a toast owns up to it.
- **Plays with the plush:** about every 8–15 minutes indoors, it rolls up to the zero-g plush and nudges it, so it squeaks.
- **Worries:** indoors, if the power grid is down, it chirps worriedly and a toast says so.
- **Naps:** at night, once it has been still near you for a while, it naps, with sleepy blue eyes, its head drooped and its lamp off. If there's a rover charger in its room, it docks there first ("charging"). It wakes at daylight, when you walk off, or when you ping it.
- **Ping (E):** a happy chirp and a wiggle. Ping three times quickly for a spin.
- **Look at it:** shows "GAR-Y · <what it's doing>".
- **Info (I):** the description, plus the ice deposits flagged and samples collected.
- **Mood eyes:** cyan when curious, amber when busy, green when happy, blue when sleepy, a red pulse when worried. It also blinks.
- **Voice:** five short synthesised chirp phrases (happy, curious, worried, sleepy, ta-da) in `tools/generate_audio.py`.
- **Torch:** on the head, tilted at the ground ahead, a soft warm white. It's on only in the dark (not in lit rooms or while napping), has no shadows, and is outside the world's light cap, so it never pops on and off.
- **Settings:** Graphics → GAR-Y autonomy turns off the surveys, clutter-moving, plush visits and worrying. It still follows you and naps.
- **Debug panel (Ctrl+Shift+F12):** a GAR-Y row to trigger a survey, clutter-moving, a plush nudge or a nap.
- **Saved:** its flags and tallies are saved with the base. Moved items save like any placement.

## Files
- `asset_packs/gar_y_v1/source/build_gar_y.py`: the Blender model (it uses the furnishings pack's materials). Pivots: `Wheel_1..6`, `Mast` › `Head` › `Eye_L` / `Eye_R` / `LampMount`, and `ArmShoulder` › `ArmElbow` › `ArmWrist` › `Grip`.
- `assets/companions/gar_y.glb`: the exported model. The old `mars_scout_rover` files in `assets/companions/` are no longer used.
- `scenes/mars_scout_rover.tscn`: the collision and model wrapper (the path is kept from the old rover).
- `scripts/companion_rover.gd`: movement, the routine, moods and saving. Its tuning constants (how often things happen, arm poses, mood colours) are at the top.
- `BuildController.move_free_interior_equipment()` / `free_interior_move_reason()`: how it moves things legally.
- Tests: `tests/gar_y_test.gd` and `tests/build_keys_rover_test.gd`.

## Safe removal
The world spawns GAR-Y only while `SPAWN_SCOUT_ROVER` in `scripts/mars_world.gd` is true. Nothing in player movement, habitat construction, resources or saves depends on it.
