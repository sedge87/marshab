# Overnight report: 24 Oct 2026

Everything below is committed locally on `codex/interior-grounded-first-batch`. Nothing is pushed.

## 1. The gameplay ideas document

**`docs/moment-to-moment-gameplay.md`** is the design pass Batch F asked for. Nothing in it is built.

- **What "alive" should mean:** every interaction changes something you care about, in short loops, and the base asks for your hands without nagging.
- **Five shared systems** that most ideas rest on:
  - machine condition and services;
  - crew presence, in three phases from "signs of life" to visible crew;
  - crew requests;
  - flow you can see;
  - two small currencies, trust and physical samples.
- **Room-by-room ideas** for all 14 room types, each with its loop and an effort size.
- **The outside:** site machines, the rover, GAR-Y and resupply.
- **An example sol** showing how it could all flow.
- **A table for every catalogue item:** what it does today and its proposed main interaction. The 22 items with no interaction today are marked **New**.
- **What I'd build first,** and **four questions for you** at the end: visible crew, how hard maintenance should bite, suit oxygen, and mission steps.

## 2. The crew rover: built and drivable

Build a **vehicle bay** and the rover is parked inside it, facing the hangar door.

- **Get in:** look at it and press **E**. The prompt shows its battery.
- **Driving keys:**
  - **W/S:** drive and reverse;
  - **A/D:** steer;
  - **Space:** brake;
  - **F:** headlights;
  - **V:** chase view or bonnet view;
  - mouse to look round;
  - **E:** get out.
- **Getting out:** you're put on the driver's side, or wherever there's room.
- **The hangar door:**
  - it opens as you drive up to it, inside or out, sealing the bay's other doors through the interlock first;
  - it shuts once you're about 10 m clear.
- **Ramp:** a new plated ramp with orange edges runs from the hangar door down to the ground.
- **Handling:**
  - about 23 km/h top speed, with lighter steering at speed;
  - the body follows the ground with pitch and roll, and each wheel has a little suspension travel;
  - all six wheels spin, and the front and back pairs steer;
  - small rocks don't stop it, but walls and machines do, and bumping into them takes the speed off.
- **Battery:**
  - about 4 km to a charge;
  - it charges while parked in the bay;
  - when flat it limps home at walking pace.
- **Effects:** dust trails, a motor hum that rises with speed, headlights and a light bar, and a small driving HUD in the lower left.
- **Saving:** the rover is saved with the base: where it is, its battery and its lights.
- **The model:** `asset_packs/mars_crew_rover_v1`, built in Blender in the house style.
  - A white pressurised cab with a wrap-round windscreen and two suitports at the back, after NASA's Space Exploration Vehicle.
  - An open cargo deck with a tool chest and sample cases.
  - Six wheels on trailing arms with orange coil-overs.
  - A roof solar panel, a light bar, a beacon, a mast, and one orange stripe.
- **Test:** `tests/crew_rover_test.gd` drives it out of the bay, steers, checks the battery, gets out and saves. It passes. I also drove it back in from outside in a real window.

**Things to know:**
- **Bonnet view:** V gives a view over the nose. The cab is a closed shell, so a true seat view would need the cab modelled hollow inside.
- **GAR-Y** follows you while you drive, because your position rides with the rover, so he chases it at his own pace.
- **No cost:** the rover comes with the vehicle bay and doesn't cost cargo. In Missions it arrives whenever the vehicle bay does.

## 3. Models: the janky ones fixed

I wrote **`tools/model_lab.gd`** to review the models. It photographs any item, or every interior item, closed and after each of its E, F and G actions:

`godot --path . --script res://tools/model_lab.gd -- <out_dir> [id ...]`

I went through all 92 interior items with it. Most hold up well. The fixes:

- **Galley bench unit:** the doors used to open onto a solid block. It's now two real cupboards (back, sides, floor, liner) with a shelf, a stack of plates, bowls, pouches and mugs.
- **Galley kitchenette:** every bay behind a door is now a real compartment:
  - **fridge:** a white liner, a lamp, two shelves, cartons, pouches, greens and tubs;
  - **oven:** a dark cavity with a wire rack, a glowing element and a tray with a meal;
  - **sink cupboard:** the trap, supply pipes, two bottles and cloths.

  The drawer bay stays solid, since those drawers don't open.
- **Guitar:** rebuilt.
  - A proper acoustic body outline in spruce and walnut with binding, a rosette, a pickguard, a bridge and pins.
  - A fretted ebony neck with dot inlays, and a tilted headstock with six tuners.
  - It leans back on a real A-frame stand: padded cradle, neck yoke, and legs that go round the body rather than in front of it.
- **Drawers:** the tool bench's spares tray and the spare-parts rack's tool drawer now pull out as trays with sides and a back, not bare fronts.

**Not changed, and why:**
- **Bunks and the regolith printer** didn't frame well in the lab because they're too big for its camera. They're not broken.
- **Locker, pantry, freezer, medical cabinet, storm shelter locker and the rest:** they already open onto shelves and contents.
- **Survey board, greenhouse planter and kitchenette** seemed to vanish in my first lab run. That was the lab's fault, not the game's: it hadn't registered the items properly, so the base's rebuild cleared them. A real placed kitchenette stays put.

## 4. Waiting on you

- **Push:** say "push it" when you're ready.
- **The ideas document:** read `docs/moment-to-moment-gameplay.md` and answer the four questions at the end. Then I can start on the first batch.
- **Playtest the rover:** build a vehicle bay (Site plan → Structure) and drive it. It needs a real feel test with a keyboard: steering weight, top speed and the camera distance are all one-line tweaks at the top of `scripts/crew_rover.gd`.
- **`project.godot`:** it shows a one-line reorder that the Godot editor made. I left it alone.
