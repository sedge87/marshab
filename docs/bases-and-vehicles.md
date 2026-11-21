# Bases, automation, vehicles and the blackout (14 Nov 2026)

*Agreed with the user on 14 Nov 2026. This covers the last four "still to design" talks in `docs/pillars.md`: the walker core and outposts, automation, the drone and the rovers, and the blackout rule. It follows `docs/range-ladder.md`, `docs/rooms-and-equipment.md` and `docs/hab-supply.md`. Every number is a starting point for playtest.*

## Bases

### Placing a base
- You find and fix a walker, then **mark a spot on the Map:**
  - it must be explored ground, and flat enough;
  - a site check shows sun, ice, shelter and slope;
  - Castle weighs in on the spot.
- **The walker walks there on its own,** slowly: about a sol across the Reach, and you can follow it.
- When you arrive, it **kneels, sets the core down and folds in.** It's a big moment every time.

### Moving a base
- **A core can be refolded** and walked to a new spot, as often as you like (the user, 14 Nov, at A4: not limited to once).
- **Everything comes along:** liners, equipment and materials go back into the shared store, ready for the new site.
- **Some evidence stays behind:** the printed pad, the footprints of the rooms and the walker's tracks, as a trace of where you've been.

### The main base is yours to choose
- **Every core is the same** and can take every upgrade.
- **Eventually you decide which base is the main base,** where the crew will land. You build the crew's landing pad and beacon there.
- Once the pad is down, that base can't be moved.
- Walker 1's base, beside the lander, is the natural choice, but not the only one.

### Uneven ground: rooms can step
- Each base starts at its core's height.
- **A room can sit up to one storey higher or lower than the room it joins,** linked by a short ramp or ladder. The printer levels the pad under each room.
- So a base can climb a slope or step down into a hollow. For example, the Lab steps up onto a rise for the view.
- This replaces today's single floor height per base (`build_controller.gd` `habitat_base_y`), the thing that ties building to the lander.

### One shared store
- All bases draw on **one store.** Hauler carts keep it balanced along your trails behind the scenes, and you see them trundling past now and then.
- For example, ice mined at the ice-wall outpost is on the build bar at the main base.
- Outposts still matter because the deposits are there.

### No fast travel
- You walk or drive, so distance is real.
- Trails, the drone's markers and the rovers make known routes quicker and safer over time: the second trip is easier than the first.
- Sleeping in a bunk at any base wakes you there.

### As built (A4, 14 Nov)
*Built, not playtested. Decided with the user at A4: steps go through corridors, the Map picks the spot and the plan fits the core there, refolding is unlimited, and building the pad is the main-base choice. The rest below was left open by this doc and settled in the build. Code: `scripts/bases.gd`, `scripts/base_pieces.gd`, `walker.gd`, `build_controller.gd`; test `tests/bases_test.gd`.*
- **Bases.** The builder keeps one record per base, keyed by its walker (`w1` is Walker 1's, beside the lander), and every room records its base and its floor height.
  - **Build area:** you build within 60 m of a base's core. Walker 1's base keeps the landing-site pad rules.
  - **Spacing:** base centres are at least 150 m apart.
  - **Which base you're at:** the base whose area you stand in, else the nearest. The build plan, the grid and the core panel follow it.
- **Levels.**
  - Rooms that touch share a floor.
  - A room on its own takes an existing level if the ground allows, else its own ground height. The ground may sit up to 0.12 m above a floor or 1.85 m below it.
  - A room that would touch two levels is refused: "link them with a corridor".
  - **Steps happen only in corridors.** A corridor between two levels climbs up to one storey (3 m) and must run straight.
    - Up to 1.1 m of rise per 3 m cell, it's a ramp.
    - Steeper than that, it's a ship's ladder: steep printed steps with rails that you walk up. A ladder you climb with a key is not built.
- **Walkers.**
  - **Marking a spot:** a free walker (state "ready") is sent from the Map. The first W checks the spot under the cursor: sun %, night shelter, ice nearby and slope, with a line from Castle. W again on the same spot sends it.
  - **Spot rules:** the spot must be explored, flat, and away from other bases.
  - **The walk:** the walker walks there on game time, about a sol across the Reach, and shows on the Map.
  - **Setting down:** there, the plan offers its core and airlock, as Walker 1's does. When the core is down, the walker kneels and folds into it.
  - **While it sets down,** only that base's pieces are hidden ("arriving"), so other bases stay in place.
- **Refolding.**
  - **Where:** the core's upgrade panel has a "Refold this core" row (press twice).
  - **What happens:** the base's rooms pack away and the walker stands up ready.
  - **Kept:** the core's upgrades go with it. The room footprints stay on the ground as traces.
  - **Limits:** you can refold as often as you like, but never the main base.
- **The landing pad** is a 6 × 6-cell (18 m) printed pad with edge lights and a beacon mast.
  - It costs 20 kg a cell of printed regolith, and you can build only one.
  - **Main base:** the base you build it at becomes the main base. A new game has none until you build the pad.
  - **Locked:** once the plan closes, the pad is down. It can't be removed, and its base can't refold.
- **Per-base cores.** Each core runs its own life support. The world keeps `cores[id]`, and `module_life` stays Walker 1's.
  - Body, suit and power read the core of the base you're at.
  - Upgrades are fitted per base.
  - With more than one core, alerts carry the base's name.
- **The Base page** has a chip per base, marked ★ for the main base and "here" for the one you're at, and shows the chosen base's readings.
- **One shared store:** the existing global stock and feedstock serve every base. Hauler carts are not built yet (A8).
- **Saves:** version 3. Older saves load as one base, Walker 1's, with every room at the old single floor height.
- **Not yet:** Walkers 2–4 out in the land (C1), hauler carts (A8), and Creative mode starting a second base without a walker.

## Automation

### Deposits and machines
- Place an **ice extractor** or a **rock miner** on a deposit you've cored. It fills its own hopper.
- **Each machine has its own small solar panel and battery,** so there are no cables.
- **Deposits run low slowly,** over many sols: the machine slows, the hopper fills more slowly, and GAR-Y mentions it.
- **Richer, longer-lasting deposits sit further out,** so mining also pushes you outward.
- **Regolith never runs out.**

### Hauler carts
- Carts are built at the Garage. **Each cart serves one machine automatically** and follows your trail to the nearest base. You don't draw routes.
- More carts mean more throughput.
- **A dust storm pauses them.**
- **A cart can get stuck,** bogged in a ripple belt or hit by a rockfall. When it does:
  - **GAR-Y fixes it for you** if you leave it to him. It takes him a while, and the haul stops meanwhile.
  - **Or you go yourself, if you want.** Sometimes that's rewarded: a find near the stuck cart, a faster recovery, or a bonus load.
  - It's never a forced chore.

## Vehicles and the drone

### The scout buggy (early)
- **What it is:** an open buggy, today's drivable rover reworked.
- **How it works:** you stay suited. It's quick, has a small locker and about 2 km of charge. Good for ring 2.
- **Where it comes from:** a cargo wreck in ring 1, with a dead battery and a part to print. You fix it on the spot.

### The pressurised rover (later)
- **What it is:** the big step up in range, for ring 3.
- **How it works:**
  - It's slow, about 3 m/s.
  - Inside, you take your suit off, sleep, eat and refill.
  - It has its own air and power, and takes rover add-ons (wheels, traction mats).
  - It can bog down, and its wheels wear on sharp boulders.
- **Where it comes from:** a big cargo lander that came down hard at the edge of ring 2. You fix it on the spot with printed parts and spares, then drive it home to a Garage.
- **Finding it is a story moment:** Castle knew it was on the manifest.

### The scout drone (ring 2)
- **What it is:** an Ingenuity-like drone, found in a wreck beside the first yardang maze (range ladder).
- **How it works:**
  - **You fly it yourself** through the slate's camera view, launched from your hand or a base. It's a fun toy with short flights, a few minutes of battery each.
  - **Wherever it flies sharpens your Map.**
  - **You can drop route markers** that join your stake trails.
  - **High wind can bring it down** far away, and you go and fetch it.
  - **A later add-on** lets it fly a marked route by itself.

### GAR-Y
- He's unchanged from `docs/pillars.md`: companion, scout, survey, cores, the rescue, and upgrades over the game.
- New: he frees stuck carts.

### As built (A7, 15 Nov)
*Built, not playtested. Decided with the user at A7:*
- *the drone lives at a dock and you fly it from there, not from your pocket ("a small pocket drone would be impacted by the weather too much");*
- *vehicles get both views: a diegetic cockpit and a chase camera;*
- *bases charge vehicles slowly and the Garage charges them fast.*

*The rest below was left open by this doc and settled in the build.*

*Code:*
- *`scripts/crew_rover.gd` (both vehicles), `scripts/scout_drone.gd`, `scripts/drone_dock.gd`;*
- *`scripts/vehicle_model.gd` (code-built models), `scripts/vehicle_dash.gd` (the dashboard screen), `scripts/ground.gd` (ground kinds from `ground.png`);*
- *`mars_world.gd` (spawns, docks, saves).*

*Test: `tests/vehicles_test.gd`.*

- **One driving script, two kinds.** `crew_rover.gd` drives both vehicles. The world keeps `crew_rover` (the pressurised rover, so the suit, radio and Mission Control code still find it) and `buggy`.
- **Both views.** V switches between them.
  - **Cockpit view (the default):** you look at the dashboard, a working screen in the cab. It shows speed, battery and range, home distance and bearing, and, in the rover, cab air, water, meals, wheels and add-ons. Warnings show in amber or red.
  - **Chase view:** shows the same screen small in the lower left (the dashboard's echo, not a separate readout).
  - The old floating readout panel is gone. The compass strip and key hints stay in both views.
  - *To revisit when the vehicle models change* (the user): the cockpits should become more like a real cab, perhaps one you can walk round inside the rover.
- **The scout buggy.**
  - **Driving:** 5 m/s, 2 km to a charge plus a 300 m reserve. It's open, so you breathe your suit's air. G beside it charges your suit from its battery (it carries no air).
  - **Model:** code-built, Apollo LRV-like: four mesh wheels, two seats, a roll hoop, a rear locker, a solar mast and a dashboard on the control column.
  - **The wreck:** a flat battery and a sheared steering link.
    - E with a spares kit fits a new link.
    - E again bridges its battery from your suit (30% of your suit power), which wakes it at 30%.
- **The pressurised rover** (the EVA-6 model).
  - **Driving:** 3 m/s, 6 km to a charge plus a 600 m reserve.
  - **Its stores:** an oxygen tank of 36 suit-hours (a night out and two days), 20 L of water and 6 meals.
  - **The sealed cab** counts as "rover" for the suit while the tank has air. Your suit tops up from it.
  - **Parked:** Z sleeps (the sleep panel, as at a bunk), and X eats a meal, fills the suit's drink bag and packs a food bar.
  - **The wreck:** E with 2 spares kits, 20 kg metal and 10 kg salvage repairs it. It comes back with 40% charge, a near-empty tank, worn wheels (60%) and the dune-wheel plan from its manifest.
- **Bogging (the rover).**
  - **How it bogs:** on sand and ripple ground (`ground.png`), driving faster than 1 m/s builds slip. Over half, the dashboard warns "WHEELS SLIPPING". Full slip: bogged, and it sinks a little.
  - **Getting free:** L lays a traction mat (it's free at once), or you get out and press G beside it five times to dig. Digging costs 0.4 hours of suit air.
  - **Not R:** R and a recall refuse while it's bogged.
- **Wheel wear (the rover).**
  - **Where:** sharp boulders and platy lava cut the tread, at up to 0.05% a metre at full speed and less when you go slowly. A little wear comes everywhere.
  - **What it costs:** below 40% it's three-quarters speed, and below 15% just under half.
  - **Fixing it:** G beside it with a spares kit gives back 50%. The Garage's wheel bench (3) refits the wheels fully for a kit.
- **Add-ons (the rover).** These are fitted in a Garage, from the cab:
  - **1, dune wheels:** 30 kg metal and 10 kg salvage; the plan comes from the wreck. No bogging on dune sand, and 30% of the slip on ripples. This is the dune sea's gate (landmark 24).
  - **2, traction mats:** 20 kg feedstock and 4 kg salvage for a rack of 3. Press 2 again to refill the rack.
- **Charging.**
  - **The Garage's rover dock** (parked in a Garage): 150% an hour, about 40 minutes. It also refills the rover's air from the base, its water, and its meals from your rations.
  - **Parked within 30 m of the lander or a base's core:** 30% an hour.
  - **Solar, anywhere by day:** 6% an hour for the rover, 4% for the buggy.
  - All rates are in game time. Creative never runs down.
- **The scout drone.**
  - **Model:** code-built, Ingenuity's layout: a cube body, four legs, counter-rotating rotors and a solar panel.
  - **Flying it:** at a Garage's drone dock, E at the console. Your view becomes the drone's feed, framed as the console's screen (battery, link, height, distance, a windsock gauge, marker count), with the compass on. W/S/A/D move, Space and Shift climb and descend, the mouse turns, F logs a route marker, and E, R or Esc hand it to the autopilot, which flies it home.
  - **Limits:**
    - 3 real minutes of battery; it turns home itself at 15%.
    - 800 m of link from the dock: past 650 m the feed breaks up, and at 800 m it turns home.
    - A ceiling of 60 m above the ground.
  - **The Map:** it clears the fog in a 110 m circle, plus 2 m for every metre of height.
  - **Route markers** are known things of kind "marker": teal triangles on the Map and marks on the compass within 600 m. **B3 joins them to the stake trails.** They aren't objects on the ground.
  - **Wind:**
    - Gusts rise from 05:00 to 09:00 and peak at 07:00 (InSight), and are stronger higher up.
    - A dust storm grounds it on the cradle.
    - "GUSTING" warns at 0.55. Above 0.82 and over 3 m up, it's thrown down after 2 seconds.
    - Down, it's pinned on the Map ("Drone down"). E there with a spares kit fixes it, and it flies itself home.
  - **Flat away from the dock:** it lands, and its solar panel brings it back to 40%, then it flies home.
  - **The wreck:** a spares kit fixes it. It then flies to the nearest dock, or waits ("waiting for a dock") until a Garage is built.
- **The Garage.**
  - **Rover dock:** parking inside it is the dock (charging, restocking, the wheel bench and the add-on bench).
  - **Drone dock:** every Garage gets one automatically, outside, 6 m beside the hangar door. It's a printed pad with a charging cradle, a windsock and a pilot's console (code-built).
  - Its build-bar card now says what it does. The charger's recall sends both vehicles home.
- **Where they're found (test spawns; C1 places them for real):**
  - **When:** on a region site, once the guided chapters are over.
  - **Placement:**
    - the buggy's wreck 600 m from the lander;
    - the rover's wreck 2.4 km out (the edge of ring 2), towards the region's middle;
    - the drone at `region.json` "drone_wreck" (by the yardang maze);
    - each on the nearest flat ground, with scattered wreck debris beside the two vehicles.
  - **On the Map:** all three are pinned so a playtest can find them. The pins come off once each is fixed.
  - **C1:** put the buggy into a ring 1 cargo wreck that you find by sight. Put the rover into the big hard-landed cargo lander, with Castle's manifest line. Give the drone its wreck by the maze. Make the pins come from seeing them or from Castle.
- **Other sites and Creative.** Off the region, the old rule stands: the rover appears in the Garage, already working. On a region in Creative, the buggy and rover start parked by the lander, and the drone flies to a dock or waits.
- **Saves:** `buggy` and `drone` sit beside `crew_rover`. A vehicle saves its kind, wreck state, stores, wheels, add-ons, mats and bogging. The drone saves its state, battery and marker count.
- **Not yet:**
  - a printable rover dock away from a Garage;
  - the drone's auto-route add-on and its range add-ons;
  - GAR-Y's winch for bogging (A9);
  - Blender models for the buggy, the drone and the dock;
  - a walk-round rover interior;
  - the buggy's locker holding things;
  - Settings switches for marker compass marks;
  - remote switching from the rover terminal (survival-systems §12.5).

### As built (Phase 6, 21 Nov): the field models

The user's three field models (`asset_packs/outpost_field_assets_v1`, cleaned of all lettering by `source/clean_field_assets.py`; in game as `assets/models/field/*.glb`) replace the code-built buggy, the EVA-6 and the old corer.

- **Scout 02 (the scout buggy).** The wheels, the steering and the yoke are driven from the model's own empties. There are two working screens, drawn like the wrist (`scripts/vehicle_screens.gd`):
  - **Drive:** a speed arc, a battery ring with the reserve in amber, the range, and lit icons for lights, cruise, slipping and worn wheels.
  - **Return to hab:** an arrow home and the distance. Your suit's air shows in minutes, with the drive home marked on the ring. The edge goes red when the air won't cover the drive: the turn-back on a working screen, never a voice.
  - **The glove box:** parked, look at it and click to open it. It holds two food bars and 1.5 L of water pouches, and a Garage restocks it (the bars come from the ration crate).
  - **The suit charge lead:** click to plug in, and the buggy's battery charges your suit while you sit. There's no air in it.
- **Traverse 06 (the HabRover).** It has six wheels, front and rear steering, and three screens:
  - **Drive:** as on the buggy.
  - **Nav:** the breadcrumb route you drove (a mark every 25 m), north up, with home and you on it. It clears at the dock.
  - **Cabin:** pressure, cab O₂ and warmth as three rings, with water and meals underneath. Below 20% O₂ the screen flashes and an alarm sounds every 4 s.
  - **The galley:** three drawers (meals, water, food bars) open by clicking. Parked, turn right round and you're up in the aisle beside them. X still eats and drinks in one go.
- **The HabRover docks outside.** It's 3.8 m tall and 6.7 m long, too big for the hangar. Its pad is beside the Garage's big door, on the side away from the drone dock. It backs on to the wall, with an umbilical from the wall to its rear airlock. That pad counts as "in the Garage" for charging, restocking, add-ons, the wheel bench and recall. A recall drives to just off the pad and reverses on. It never opens the hangar. The buggy and the drone still go inside.
- **The MC-01 hand corer** (`scripts/hand_corer.gd`) is worked by hand:
  - E plants it.
  - Each press of E is a stroke: the collar drops and the ratchet clicks round. Six strokes take it to depth.
  - Strokes quicker than 0.45 s are rushed, and two rushed strokes smear the layers. That gives a partial read, which doesn't count as the ice find.
  - The regolith shoe skids on ice halfway down. R swaps in the ice shoe by hand.
  - Then E opens the head, hold E draws the liner up (the core shows ice or regolith), and E caps it.
  - Walk off more than 3 m and it's left.
- Tools: `tools/vehicle_cab_look.gd` (the cockpits, screens and cab parts), `tools/corer_look.gd` (the corer's stages) and `tools/field_model_look.gd`. Tests: `vehicles_test`, `crew_rover_test`, `rover_route_test` and the new `hand_corer_test`.
- **Not done yet:** the buggy's dash knobs and other switches as clickable controls; walking about inside the HabRover (you reach the galley from the seat); and the sample case, kit and charge-lead hatches on Scout 02 as working parts.

### Decided 21 Nov (built the same day, see below): the sealed dock, and vehicles that break

- **A docking port for the HabRover.** It's a new piece you build on the outside wall of any pressurised room, the way you build an airlock.
  - The HabRover reverses on to it, and its back hatch mates with the port.
  - You walk from the cab straight into the base with no suit, and back out the same way.
  - While docked it shares the base's power and air, and restocks water and food.
  - A recall drives it to the port.
  - The Garage stays the home of the buggy and the drone. The pad by the Garage door is only a fallback for when there's no port.
  - The Garage itself isn't pressurised (its doors into the base are sealed hatches that only open one side at a time), which is why the port goes on a room.
- **Vehicles can be wrecked, but never lost for good** (every limit is beatable).
  - A hard fall, a roll or a crash turns a vehicle into a wreck where it lies, and you fix it there with spares, as when you first found it.
  - If it ends up somewhere you can't reach (down in the deep, for example), GAR-Y tows it back to the last safe spot over a sol or two.
- **Far wrecks wait for you.** A wreck stays where it lies, pinned on the Map with its own beacon. You can:
  - go and fix it with spares, by buggy, on foot or in the other vehicle;
  - or ask GAR-Y to tow it home, at about a sol per 3 km (an 8 km tow takes nearly three sols).
  - While towing, GAR-Y can't survey, but it always breaks off to rescue you. Distance costs time, never the vehicle.
- **The HabRover's cabin is a shelter.** A wreck breaks the wheels or the drive, never the hull, so the cabin keeps its air, water and food. Stranded far out, you can:
  - sleep;
  - fix it with spares you carried;
  - or radio GAR-Y to come to you.
  - If the cabin's supplies run out, the blackout rule applies: GAR-Y drags you home and you lose that trip's progress, not your game.

### As built (21 Nov): the docking port, wrecks and the tow
- **Docking port** (`docking_port`, airlock group, in the build list after the rover charger). It's a wall piece for any pressurised room: a framed hatch with a round window, an orange handle and status LEDs, and outside a short collar with a rubber seal. Model `asset_packs/mars_docking_port_v1`.
  - It only works with open ground beyond the wall ("Needs an outside wall").
  - A valid port becomes the HabRover's home, ahead of the Garage pad. It backs on with its rear airlock to the collar, and there's no umbilical: the seal is the link.
  - E on the port, docked: through the hatch into the cab, looking down the aisle. Not docked: it calls the HabRover over (the usual recall).
  - E in the cab while docked: out the back, into the room.
- **Wrecks** (`crew_rover.gd` `_wreck_here`). A vehicle is wrecked where it lies, with a hazard-orange beacon strobe and a Map pin, when it:
  - hits something above 4.2 m/s (in practice only the buggy is that fast);
  - drops more than 3.5 m in one go;
  - tips past about 46° for 0.6 s.
- **What happens to you:**
  - The buggy throws you clear, on suit air.
  - The HabRover keeps you aboard: the cab still holds air, and the screens, galley and sleep still work. G radios GAR-Y for a tow. From outside, "Get in" works while the cabin is sealed.
- **Fixing:** the buggy takes 1 spares kit and the HabRover takes 2, fixed where it lies.
- **The tow:** recall a wreck (or press G aboard) and GAR-Y tows it home at about a sol per 3 km, with a 2-hour minimum, on game time.
  - It arrives still damaged; you fix it there.
  - A drop of more than 15 m means GAR-Y winches it back to the last spot it sat level (1–2 sols).
  - While towing, GAR-Y refuses survey, go-to, core and ice orders. "Come" still works.
- **Saved:** `crash`, `tow`, `safe`.
- **Test:** `tests/dock_wreck_test.gd`. **Render:** `tools/dock_look.gd`.
- **Not yet:**
  - a towing animation (the wreck just appears at home when the time is up);
  - rescuing you from a wrecked cab during a blackout.

### As built (21 Nov): the HabRover's power + hull
The cab follows the same rule as the bases (systems-and-items §1.3): one life-support core, power and hull, no oxygen tank.
- **Power:** while you're aboard, life support takes about 1.2% of the battery an hour (main first, then the reserve). Suit top-ups make their oxygen from the battery too.
- **No power:** the cab air goes from fresh to unbreathable in about 3.5 hours, with a "no power" cause in the warning.
- **Hull %**, shown on the dash line, the prompt and the Cabin screen (its first ring, red while leaking):
  - a hard knock between 2.6 m/s and the 4.2 m/s crash takes 9% per m/s over;
  - a quake about 10% and a dust storm about 5% (it joins the `hull_events` group), except when it's parked in the Garage.
  - A wreck still never breaches it: the cab stays a shelter.
- **Leaks:** below 65% a seam leaks, faster the lower it goes. Life support works harder (more battery) and the air falls once the leak beats it. The dash reads "HULL LEAK", the cab alarm sounds, and a warning names the cause.
- **Fixes:**
  - G outside with Pallet 3's patch kit: "Patch the hull" seals the leak (+25%, up to 85%).
  - The Garage mends it fully and freshens the air.
- **Saved:** `hull`. Older saves load at 100%. The buggy has no air or hull.
- **Not yet:** the improvised scrap patch, the emergency pack, and a findable hiss spot inside the cab.

## The blackout rule (outside the guided chapters)

At zero health outside:
- **Where GAR-Y can reach you, he drags you to the nearest base or rover.**
  - You wake hours later, weak.
  - **Your carried finds are dropped where you fell,** marked on the Map so you can go and get them.
  - Your suit is damaged and needs repair.
- **Where he can't reach you,** the game goes back to the moment you last left a base or the rover, because it saves automatically there.
  - Places he can't reach: down a rope, deep in the lava tube, across a fissure.
  - You lose that trip's progress, honestly, as a rewind.
  - **That keeps the deep frightening.**
- In the guided chapters, the existing rule stands: a blackout costs time, not harm.
- How this varies by game mode (Survival, Freedom, Creative, Custom) is set in the modes table when this is built.
