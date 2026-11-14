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

### Moving a base: once per core
- **A core can be refolded once** and walked to a new spot.
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
