# GAR-Y: the companion rover

**GAR-Y — Geological Analysis Rover, Y-Class.** GAR-Y is a multipurpose rover designed for geological surveys, surface sample collection, terrain mapping and identifying potential water-ice deposits.

## What it does (22 Oct revamp)
- **Follows you:** outdoors it scouts beside you. Indoors it potters between the rooms near you. In a dust storm it huddles closer and its eyes go red.
- **Surveys (outdoors, by day):** every 2½–5 minutes it drives 7–12 m off and scans the ground with its head. On buried ice (25% or richer, with no flag within 10 m) it reaches down and plants a glowing cyan flag, then a toast gives the richness. Anywhere else it scoops a regolith sample.
- **Moves clutter (indoors, very rare):** about every 20–30 minutes it picks up a small Odds & Ends item from the floor of its room. It carries the item in its gripper and puts it down at a new spot that passes the normal placement rules. The new spot is saved, and a toast owns up to it.
- **Plays with the plush:** about every 8–15 minutes indoors, it rolls up to the zero-g plush and nudges it, so it squeaks.
- **Worries:** indoors, if the power grid is down, it chirps worriedly and a toast says so.
- **Naps:** at night, once it has been still near you for a while, it naps, with sleepy blue eyes, its head drooped and its lamp off. It wakes at daylight, when you walk off, or when you ping it.
- **Docks:** if there's a **GAR-Y Dock** in its room (Vehicle Bay, Storage or Power & Engineering), it docks there instead. It lines up in front of the pad, reverses on, the plug slides into its rear bumper, and its prompt says "charging". It stays on charge while you move about the base, and unplugs and rolls off at daylight (after at least a minute) or when you ping it.
- **Ping (E):** a happy chirp and a wiggle. Ping three times quickly for a spin.
- **Look at it:** shows "GAR-Y · <what it's doing>".
- **Info (I):** the description, plus the ice deposits flagged and samples collected.
- **Mood eyes:** cyan when curious, amber when busy, green when happy, blue when sleepy, a red pulse when worried. It also blinks.
- **Voice:** five short synthesised chirp phrases (happy, curious, worried, sleepy, ta-da) in `tools/generate_audio.py`.
- **Torch:** on the head, tilted at the ground ahead, a soft warm white. It's on only in the dark (not in lit rooms or while napping), has no shadows, and is outside the world's light cap, so it never pops on and off.
- **Settings:** Graphics → GAR-Y autonomy turns off the surveys, clutter-moving, plush visits and worrying. It still follows you and naps.
- **Debug panel (Ctrl+Shift+F12):** a GAR-Y row to trigger a survey, clutter-moving, a plush nudge or a nap.
- **Saved:** its flags and tallies are saved with the base. Moved items save like any placement.

## Orders (23 Oct)
Hold **G** for a radial menu: move the mouse towards an order and let go. A quick tap of G still does an item's third action. GAR-Y must be within 30 m.

- **Inside:**
  - **Come here:** follows you closely.
  - **Stay here / Carry on:** waits until told otherwise.
  - **Go home:** goes to its dock to charge.
  - **Fetch:** brings you the small item you're looking at, or else the sample jars or the plush.
  - **Patrol:** visits every room, then reports any active alerts.
- **Outside:**
  - **Come here** and **Stay here**, as inside.
  - **Go home:** waits by the airlock.
  - **Survey there:** where you're aiming, or about 12 m ahead.
  - **Core sample:** drills a core where you're aiming. Brought inside, GAR-Y takes it to the Science Lab: research +20% for 10 sols.
- **Mission Control map:** the **Send GAR-Y** button, then a click: a room means it goes there and waits; outside means it surveys there.
- **The airlock rule** still holds: GAR-Y never cycles an airlock on its own.

Missions: GAR-Y now rolls out with the first cargo. Mission 2's step "Send GAR-Y to survey for ice (2 spots)" counts ordered surveys. Mission 6's stretch goal is a core sample for the lab. Code: `scripts/gar_y_orders.gd` (the menu) and `order()` in `scripts/companion_rover.gd`.

## Files
- `asset_packs/gar_y_v1/source/build_gar_y.py`: the Blender model (it uses the furnishings pack's materials). Pivots: `Wheel_1..6`, `Mast` › `Head` › `Eye_L` / `Eye_R` / `LampMount`, and `ArmShoulder` › `ArmElbow` › `ArmWrist` › `Grip`.
- `assets/companions/gar_y.glb`: the exported model. The old `mars_scout_rover` files in `assets/companions/` are no longer used.
- `scenes/mars_scout_rover.tscn`: the collision and model wrapper (the path is kept from the old rover).
- `scripts/companion_rover.gd`: movement, the routine, moods and saving. Its tuning constants (how often things happen, arm poses, mood colours) are at the top.
- `asset_packs/mars_rover_dock_v1/source/build_rover_dock.py`: the dock model (catalogue id `rover_charger`). Its collision is the pylon only (`pylon-colonly`), so GAR-Y can drive onto the pad.
- `BuildController.move_free_interior_equipment()` / `free_interior_move_reason()`: how it moves things legally.
- Tests: `tests/gar_y_test.gd` and `tests/build_keys_rover_test.gd`.

## Safe removal
The world spawns GAR-Y only while `SPAWN_SCOUT_ROVER` in `scripts/mars_world.gd` is true. Nothing in player movement, habitat construction, resources or saves depends on it.
