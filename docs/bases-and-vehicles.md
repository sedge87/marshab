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
