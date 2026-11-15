# Build plan after the pillar rethink (14 Nov 2026)

*The order to build the design agreed on 14 Nov. The design is in five docs:*
- *`docs/pillars.md`*
- *`docs/range-ladder.md`*
- *`docs/rooms-and-equipment.md`*
- *`docs/hab-supply.md`*
- *`docs/bases-and-vehicles.md`*

*Each phase below is playable on its own and gets its own commits. Numbers in the design docs are starting points, and the builder may tune them. Anything the docs leave open is for the builder to decide sensibly and write down in the phase's doc section, without stopping to ask, unless it changes a pillar.*

## Rules for every phase

- **Keep the settled rules:**
  - NASA-plausible and diegetic;
  - no text on models;
  - MHPalette materials and the house style;
  - the compass is always on;
  - Notes are your inner voice;
  - Castle is the one near voice.
- **Never commit** `export_presets.cfg`, `project.godot`, `scenes/*.tscn`, `Builds/` or `Game Design Documents/`. Never use bare `git stash`. Push only when asked.
- **Test lightly:** test only what changed, with no full suite or renders for small fixes.
- **Make a playtest build at the marked points (▶),** so the user can play before the next big step.

## Track A: the game's systems (in order)

### A0. Housekeeping (small)
- Fix the stale tests:
  - `tests/radio_test.gd`, whose cue list is out of date;
  - `tests/opening_days_test.gd`, which still tests the v1 days.
- Run the walker and playthrough tests.
- Point `docs/master-design.md` §4, §5 and §7 at the new docs where they disagree.

### A1. Survival states and the body (`docs/hab-supply.md`)
- **Three states:**
  - in a hab, safe while it's supplied;
  - in a rover, safe while its own supplies last;
  - on foot, on the suit's own supplies.
- **Each base shows three readings:** power, air and heat.
  - When power runs out it fails slowly and loudly: heat goes in about a quarter of a sol, the air goes stale in about half a sol, and you suit up indoors.
- **The suit goes on and off at the airlock in a couple of seconds.**
- **Your body:**
  - thirst, kept as a need: the Galley or the core's tap indoors, the suit's 1-litre drink bag outside;
  - hunger: food bars outside;
  - tiredness.
- **Radiation** hurts only during solar storms. The dosimeter tracks your dose, but the background dose never harms you.
- Files: `survival_core.gd`, `habitat_sim.gd`, `habitat_life.gd`, `habitat_chains.gd`, `body.gd`, `suit.gd`, `airlock_door.gd`, `wrist_pad.gd`.

### A2. The bare suit, add-ons and found plans
- **The suit starts bare:**
  - about a 600 m round trip of air;
  - a dim lamp;
  - no heater pack.
- **Add-on slots** are fitted at the suit rack.
- **Plan cartridges** are items you find. The Print Shop prints from known plans plus materials.
- **Plans also arrive as story beats** from the orbit owners.
- **The Engineering Bench "study" step is cut.**
- Files: `suit.gd`, `fabricator.gd`, `fabricator_screen.gd`, `data/plans.json`, `salvage_piece.gd`.

▶ **Playtest build:** the new survival feel and the bare suit, inside the current opening.

### A3. Building, part 1: one base, the new room model (`docs/rooms-and-equipment.md`)
- **The walker core** (airlock, life support, power hub, a poor bunk) replaces the General Module.
- **Plan by type, place freely:**
  - the room type is chosen in Plan view and drawn in its colour;
  - the key piece arrives in a movable spot;
  - you place the rest freely;
  - the bonus works while the key piece is inside.
- **Liner rooms:** instant, with a short "watch it build" moment. The crawler's shell gives the shielding.
- **Core upgrades open room types,** with no limit.
- **The eight rooms with their key pieces.** Bonuses only.
- Files: `build_controller.gd`, `surface_build_controller.gd`, `interior_build_controller.gd`, `floor_plan.gd`, `room_identity.gd`, `habitat_piece.gd`, `equipment_catalog.gd`, `data/equipment_catalog.json`.
- **Built 14 Nov** (not playtested). What was decided is in `docs/rooms-and-equipment.md`, "As built (A3)". The opening still sets the core down as before; its rewrite is A6.

### A4. Building, part 2: several bases (`docs/bases-and-vehicles.md`)
- **The builder holds several bases,** each starting at its core's height.
- **Rooms can step ±1 storey,** joined by a ramp or ladder. This replaces the single `habitat_base_y`.
- **One shared store** for all bases.
- **The Base page gets a switcher.**
- **Walkers:** mark a spot, the walker walks there, kneels and folds in. A core can refold (as often as you like, the user said at A4), leaving traces behind.
- **You choose the main base:** the landing pad and beacon go there, and it's locked once the pad is down.
- **A save format change.**
- Files: `build_controller.gd`, `build_rules.gd`, `base_site.gd`, `walker.gd`, `saves.gd`, `pda_screen.gd`.
- **Built 14 Nov** (not playtested). New code is in `scripts/bases.gd` and `scripts/base_pieces.gd`, tested by `tests/bases_test.gd`. What was decided is in `docs/bases-and-vehicles.md`, "As built (A4)". In short:
  - steps happen through straight corridors (a ramp or a ship's ladder);
  - refolding is unlimited, except the main base;
  - building the pad picks the main base.
  - The guided opening still sets Walker 1's core down on day 4.

### A5. Room workflows
- **Station chains:**
  - Lab: saw, then microscope, then spectrometer;
  - Greenhouse: washer, then planters, then harvest;
  - Workshop: smelter, then Print Shop, then repair bench;
  - Core: melter, then water, then oxygen.
- **Each job needs the stations it needs;** with fewer, you get a partial read.
- **Hands-on the first time for each new kind of find, then automatic.**
- **The orbit owners send station plans after finds.**
- Files: `lab_screen.gd`, `samples.gd`, `habitat_food.gd`, `fabricator.gd`, the equipment interactables.
- **Built 15 Nov** (not playtested). New code is in `scripts/materials.gd`, `scripts/greenhouse.gd` and `scripts/station_model.gd`, tested by `tests/room_workflows_test.gd`. What was decided is in `docs/rooms-and-equipment.md`, "As built (A5)". In short:
  - **The four materials were added here** (the user's choice): regolith as feedstock, ice as water, metal from iron-rich rock through the smelter, and salvage from debris and pallets. Plans mix them.
  - **The Lab starts with the saw.** A partial read brings Tupou's microscope or spectrometer plan; Achterberg's smelter plan follows an iron find.
  - **Hands-on the first time:** E at each station, then the bench, the washer or the smelter runs it by itself. The first harvest of a crop is by hand.
  - **The repair bench** services kinds of machine you've serviced by hand once.
  - **Models are simple built-in ones** for now. Ore is carried by hand until A8.

### A6. The guided chapters, rewritten (`docs/opening-days.md`)
- **Built 15 Nov** (not playtested). What was decided is in `docs/opening-days.md`, "As built (A6)". In short: a briefing Land step and a steered descent in a 750 m circle round home; chapters run together after a breather; Walker 1 patched on the spot and sent home from the Map; the core brought alive (no leak) and a Quarters liner; crater-floor and riverbed sites removed.
- **15 Nov playtest, chapter 1:** you come to in the landing seat; you can land anywhere sensible; no air pack on day 1 and the lope costs air; the printer offers only story prints; the orbiter at twilight. See `docs/opening-days.md`, "After the 15 Nov playtest".
- **16 Nov playtest, the cabin:** four hands-on steps (unbuckle, slate, helmet, a vented hatch) in about a minute, and the first step on Mars as a short reveal with the first-person talk. See `docs/opening-days.md`, "After the 15 Nov playtest, part 2".
- **Chapter 5, the Print Shop (15 Nov):** after chapter 4 nothing could be made. Pallet 6 is towed home, then the intake, the Print Shop and the extractor; after that, Castle's morning "what's next" calls and inner-voice hints. See `docs/opening-days.md`, "Chapter 5".
- **The bare suit,** with the pallet distances to match.
- **Chapter 3:** fix Walker 1 and choose home.
- **Chapter 4:** Walker 1 kneels and folds into the core, you fit the first liner and watch its shell print, and you sleep in.
- **Update the robot run and tests.**
- **The 14 Nov playtest: rethink the landing and every guided day's pacing.**
  - Each day's work ran out by early afternoon:
    - day 1: all three pallets home by 13:30 from a 06:00 landing; it now lands at 09:00 as a stopgap;
    - day 2: GAR-Y's day done by about 13:30;
    - the Walker 1 seal was printed by about 12:30, but you're told to wait until morning to take it out.
    - day 4 (the module down, patched and moved into) was done by 09:00.
  - The user wants the whole intro revamped, including the General Module's part in it. That fits A3, where the walker core replaces the General Module.
  - **Rule for the rewrite:** when the work is done early, let the player carry on (take the seal out now). Don't hold the story for the clock. Size each day's work to fill it, or let days run together.
  - The opening exposition was too long to finish before pallet 1. It's now reordered, but keep calls short and walk-friendly.
  - The gates the player hits go here as they're found.
- Files: `opening_days.gd`, `data/radio/*`, `tests/guided_*`.

▶ **Playtest build:** the whole opening and the new building.

### A7. Vehicles and the drone
- **Built 15 Nov** (not playtested). What was decided is in `docs/bases-and-vehicles.md`, "As built (A7)". In short:
  - one driving script for the buggy (open, 5 m/s, 2 km) and the pressurised rover (sealed, 3 m/s, sleep and eat aboard, bogging, wheel wear, dune wheels and traction mats);
  - a cockpit dashboard plus a chase view (the user's choice: both);
  - the drone lives at a Garage's dock and you fly it from the dock's console (the user's choice); it clears the Map, logs route markers and is thrown down by dawn gusts;
  - the Garage is the rover dock and gets a drone dock outside;
  - wrecks are A7 test spawns, pinned on the Map, which C1 places for real.
  
  Test: `tests/vehicles_test.gd`.
- **The scout buggy:** today's `crew_rover.gd` reworked, about 2 km of charge, found in a ring 1 wreck.
- **The pressurised rover:**
  - about 3 m/s;
  - you can sleep, eat and refill inside;
  - add-ons;
  - it can bog down, and its wheels wear;
  - found in a big wreck at the edge of ring 2.
- **The scout drone:**
  - you fly it through the slate camera;
  - it sharpens the Map;
  - it drops route markers;
  - wind can crash it.
- **The Garage** gets its rover dock and drone dock.

### A8. Automation
- **Extractor and miner** on cored deposits, each with its own solar panel and hopper.
- **Deposits run low slowly;** richer ones sit further out.
- **Hauler carts:** one per machine; they follow your trail to the nearest base.
- **Storms pause the carts.**
- **Stuck carts:** GAR-Y frees them, or you go yourself, sometimes for a reward.

### A9. GAR-Y's upgrades and the blackout rule
- **GAR-Y's add-ons:** deeper radar (and the magnetic layer), a winch, a longer battery, a second arm.
- **The blackout:**
  - GAR-Y drags you to the nearest base or rover, with your finds dropped and marked and your suit damaged;
  - where he can't reach you, the game rewinds to the automatic save made when you last left a base or rover.
- **Mode differences** go in the modes table.

### From the land: Track A pieces (`docs/terrain-design.md` §14, added 15 Nov)
- **Terrain shadows on solar:** mesas and crater walls shade panels at dawn and dusk, so where you build matters for Power.
- **Grading and digging:** flatten ground for a base, and dig regolith for berms and shielding, with the per-save land layer. This goes with building.
- **Pale veins and layers mark resources:** looks in B5; they become readable finds with A5's materials.

### A10. Events and the radio
- **Solar storms:** the aurora warns you, and you get under shielding.
- **Dust storms**, including the storm's return later.
- **Marsquakes and rockfalls.**
- **Fresh impacts** with ice. They cut a new crater with the per-save land layer (`docs/terrain-design.md` §14).
- **Radio shadow** and relay beacons: **parked for a design talk** (15 Nov). The user fears it could get annoying. The starting idea is static, never a hard cut-off.
- **Dust devils**, which can clean the panels, and **dust drifts** that pile against buildings and parked rovers (§14).
- **Quakes leave new boulder tracks and rockfalls**, which can cut a stake trail (§14).

## Track B: the land (can run beside Track A)

### B1. Terrain design doc · Done 14 Nov: `docs/terrain-design.md`
Agreed with the user: home is the plains, the skeleton is kept and everything rebuilt, there are two far sides, the deep is 150 m down by rope pitches, and there are no straight lines (§6).

A new doc, taking over from `docs/terrain-overhaul.md` where they disagree. It covers:
- the 6 × 6 km region, deeper rather than wider;
- the four rings;
- the vertical layers (the canyon floor, caves, the lava tube, the deep);
- every obstacle from `docs/range-ladder.md`, with a HiRISE reference for each;
- the route choices in each ring.

**Explain this one to the user before building it.**

### B2. Reshape the region · Built 15 Nov, not playtested
See `docs/terrain-design.md` §11 for what was built, what the checks say and where it differs from the plan. The old map is in `docs/terrain/before-b2/`.

- `tools/generate_region.py`, the caves, the lava tube and its skylights, plus a first pass on the deep.

### B-fix. Steep walls and floating rocks (small; added 15 Nov from the landmark review)
The user's landmark review (`docs/terrain/landmarks.md`, "The user's review") grouped 21 Change notes into six problems, T1 to T6. T1 is this phase; the rest go to B3 to B6, A7 and C3 as that section says.
- **Triplanar texturing on steep faces** in the terrain shader, so cliffs, chutes, fissure walls and the chaos blocks get rock projected from the side instead of stretched from above.
- **Settle the floating rocks** in the scree gully onto the ground.
- Then the ▶ playtest build of everything since chapter 1.

### B3. Traversal phases 2 to 5 (`docs/traversal.md`)
- **Ground costs,** including the new kinds: ripple belts, boulder fields, platy lava, frost and hollow ground.
- **Stake trails,** with the drone's markers.
- **Crew asks,** folded into the goal trails.
- **Ropes,** including down skylights and across fissures; the waiver; GAR-Y's winch.
- **From `docs/terrain-design.md` §14:**
  - fading boot and wheel tracks, with worn roads that pack into faster ground;
  - slippery dawn frost on pole-facing slopes, gone by noon;
  - soft sand traps on the hidden layer, using A7's bogging.

### B4. Caves: kit, hazards and the dark (after B3 and B6; added 15 Nov)
The user (15 Nov): caves and lava tubes should be a wonder to explore, and risky, with a little fear. The maze and the plug that shuts the deep are built (`docs/terrain-design.md` §12). This section makes them dangerous and kit-gated.
- **Physical gates that need kit:** each obstacle already in the cave gets the tool that passes it (ropes for skylights and pitches, boot spikes for the ice, a ladder for pits, GAR-Y's winch for a choke).
- **Forced darkness:** a lamp battery that runs down, light stakes you leave behind, and a Map that draws only what your lamp has shown.
- **Hazards:** rockfalls when a quake comes, thin floors, the ice, the cold, falls that hurt, getting lost.
- **No radio:** relay beacons carry it down as far as the plug, and nothing past it.
- **Reveals:** the marsquake that opens the deep, and the other quake and storm reveals in `region.json`.
- **Looks:** the maze walls and the plug as broken rock, not slabs.

**Explain this one to the user before building it.** §12 ends with a starting list; none of it is agreed.

### B5. Terrain tools: layout file, map editor and sculpt layer (before C1; added 15 Nov) · Agreed 15 Nov: `docs/terrain-design.md` §13 and §14
**Built 16 Nov** (406e6a6 … 510548a): all eight steps, see `docs/terrain-design.md` §13 "As built (B5)". Playtest build `Builds/OutpostOne-Playtest-16Nov-b5`; not playtested.

**The agreed plan is §13 (with its order of work), plus from §14:**
- all the ice rethought, including the near ice wall the player chips;
- the four rules against a boring Mars (the sameness check, area colours, area sound and sky, surprises);
- the `ice_scarp`, `sinter_mound` and `monument` kinds;
- far horizon landmarks and old boulder tracks;
- a sculpt-layer format the per-save land layer can reuse.

The list below is the first sketch.
The user isn't happy with all of the land yet and wants control over it. The land is cheap to change (one script, about 2.5 minutes); the cost is in things placed on it. So this comes before C1.
- **Layout file:** every landform constant moves out of `tools/generate_region.py` into `data/region_layout.json`. The generator loads it. The heights must come out byte-identical.
- **Named anchors:** `region.json` gets `anchors` (id, position, ring) for every landform. C1 places story things by anchor, never by raw coordinates, so they follow the land.
- **Map editor:** `tools/region_editor.py` serves one page. Drag, resize, turn, delete or add a landform, then Save and Regenerate. The generator's checks show as a pass or fail list.
- **Sculpt layer:** hand brush work in the Godot editor (Terrain3D's brushes), saved as a height difference that's added last and survives regenerating. It can't reach caves.
- **Start from the user's landmark review** (`docs/terrain/landmarks.md`): what they marked Keep, Change, Move or Cut.

### B6. Cave networks (before B4 and C1; added 15 Nov)
The user wants a real underground, with lessons from The Forest, Skyrim and Subnautica. Today a cave is one swept passage and can't branch.
- **Design talk first,** with pictures:
  - many entrances that link far-apart places (skylights, fissure walls, canyon caves, the ice cave);
  - each depth with its own look, sound and danger;
  - a short cut back to the surface at the far end;
  - one set-piece room per cave;
  - getting lost as the real threat.
- **`scripts/caves.gd` rebuilt** so a cave is a network: passages joined at junction chambers, able to cross over and under each other, with several entrances.
- The braided walls, pits, gates and looks from `docs/terrain-design.md` §12 carry over.
- Cave networks live in the layout file, so the map editor can move them.

**Explain B5 and B6 to the user before building them.**

## Track C: content and story (after A4 and B2)

### C1. Laying out the range ladder
- The wrecks and their plan cartridges, ring by ring.
- Walkers 2, 3 and 4, each lost in its own way.
- The buggy, the rover and the drone.
- Deposits, with richer ones further out.
- **From `docs/terrain-design.md` §14:**
  - names for the rock monuments (Castle uses them);
  - meteorites as rare finds;
  - your lander's heat shield, back shell and parachute 1–2 km away, to salvage (with A6's landing);
  - the hot-spring sinter mounds placed as clues towards the heart (C2/C3).

### C2. The goal trails and the heart's clues, laid outward
- The nav pockets.
- The magnetometer and the magnetic Map layer.

### C3. The deep and the ending
- The last magnetometer.
- The climb out ("you make it, barely") and the storm's return.
- The crew land at the main base.

## Not in this plan (parked)
- Body and kit hazards: toxic dust indoors, dust wearing seals, the cold sapping batteries, long shadows.
- Random faults at home.
- The agency's name (Meridian leads).
- Whether a company is involved in the mission.
- From the stock-take: camera vs journal, the slate's clutter, the 12 Nov playtest notes.
