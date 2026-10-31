# Gameplay loop brief: live, work, survive

*Draft for discussion, 31 Oct 2026 (updated the same day: GAR-Y's rescue, one region with four landing zones, Terrain3D), on the `implementing-gameplay-loop` branch. Nothing here is built yet. Survival mode only; Missions get revamped later, once this gameplay exists. A story comes later too, so this leaves hooks for one but doesn't write it.*

## 1. The problem

Outpost One is a strong habitat builder with a rich simulation underneath: power, heat, air, water, food, breakdowns, injuries, wellbeing, storms and radiation. But in Survival:

- **you have no body at stake.** Outside, the HUD says "suit required", but nothing about you runs down;
- **there's no reason to go out.** GAR-Y's surveys and the crew rover don't feed anything bigger. Research is a number, and a core sample gives a 20% boost;
- **a run has no direction.** Once the base is stable there's nothing to work towards, so the game becomes "build, then watch".

`docs/moment-to-moment-gameplay.md` (24 Oct) covers what to do *inside* the base, room by room. This brief is the frame around it: what you do outside, why you go, and how the two halves feed each other.

## 2. Pillars

1. **Going outside is the adventure.** Every trip is a small expedition with a purpose, a limit and a way home.
2. **The base is home and workplace.** You come back with things to process, fix and plan around.
3. **Science drives everything.** What you find and study pays for what comes next.
4. **Grounded, our own identity.** Real procedures and real Mars science, after *The Martian*, NASA analogue missions and the ISS. No crafting tree, no creatures, no hunger and thirst meters (docs: own identity).

## 3. The three loops

| Loop | Length | What you do | What it produces |
|---|---|---|---|
| **The trip** | minutes | suit up, travel, gather, get home before your reserves run out | samples, instruments placed, places surveyed |
| **The sol** | one sol (20 real minutes) | process samples, keep the base running, plan the next trip, sleep | science, discoveries, a working base |
| **The run** | many sols | spend science on new kit, grow the base, reach further out | range, capability, a bigger crew |

Together they make one cycle:

> go out → bring back samples → science → requisition → better kit and a bigger base → reach further out → rarer samples

## 4. Your body

### 4.1 The suit
Four things run down outside, shown on a compact suit HUD (wrist display style):

- **Oxygen:** about 8 game hours from full, which is roughly 8–9 real minutes by day. Sprinting and heavy work (drilling, carrying) use it faster.
- **Battery:** powers the suit's heating, radio, lights and fans. At night the cold doubles the drain, so a night trip is shorter.
- **CO₂ scrubber:** lasts longer than the oxygen in normal use. It only becomes a worry on long trips without a top-up, or when it's damaged.
- **Radiation dose:** builds slowly outside, quickly during a solar event. It's a career limit, not a countdown, and it shows on the Crew screen.

Plus one condition: **suit integrity.** A fall or a sharp rock can damage the suit, so it leaks oxygen faster until it's patched. A patch kit on the belt does a quick field fix; a proper repair happens at the suit service panel.

**Topping up:** at the airlock's suit service panel, in the rover's cabin, and at any supply cache you've set up (§5.5).

**Warnings:** calm, staged voice lines from the suit (and ARDEN): 50%, 25%, then "turn back now" based on how far you are from the nearest top-up. A "point of no return" marker on the suit HUD makes the risk readable.

### 4.2 Sleep and fatigue
- **Fatigue** builds while you're awake and is cleared by sleeping in a bunk, the lander, or the rover's cabin on a long trip.
- **It never stops you going out, at night or any time.** Tired, you work and walk a bit slower, and the view softens slightly. Very tired, you use a little more oxygen. Nothing locks you out.
- **Sleeping is how you skip the night** when you've nothing to do, and a full night gives a **well rested** bonus for the next sol (faster work, a little less oxygen use).
- **Night has its own reasons to go out:**
  - **dawn frost** on rocks and in shaded craters, for ice samples, which only lasts until mid-morning;
  - **star sightings** to fix your position when far out (a nod to navigation in *The Martian*);
  - a **comms window** that falls at night for some sites;
  - **urgent repairs** before the morning;
  - **getting home** after a long drive.

### 4.3 Passing out: GAR-Y brings you home
When oxygen, battery heat or your health runs out, you pass out. **GAR-Y comes and drags you home,** like the Palicoes in *Monster Hunter*:

- a short scene: the view fades, then GAR-Y trundles up, hooks onto your suit's drag handle and hauls you back across the ground, complaining over the radio;
- you wake **inside the base:** in the airlock, or the Medical Bay once you've built one (the lander's cabin before there's a habitat);
- **time passes** with the distance GAR-Y had to drag you: a few hours from close by, most of a sol from far out;
- **samples you were carrying are dropped where you fell,** marked on the map, so you can go back for them;
- **the suit is damaged** and needs a repair before a long trip;
- **the rover stays where you left it,** so you go and fetch it (or GAR-Y slowly tows it home);
- **a health knock** that the Medical Bay helps you recover from;
- **GAR-Y remembers it:** a rescue count on its card, and the occasional remark ("That's three times this month, Commander.").

GAR-Y is already the base's companion, so this makes it the hero of your worst trips.

**One life (new game option):** passing out ends the run with a summary of what you achieved (the dossier).

## 5. Outside

### 5.1 One region, four landing zones
Today the game has four separate sites, each based on a real place: Open Plains (Elysium Planitia), Canyon Ridge (the Valles Marineris floor), Crater Basin (Gale Crater) and Ice Fields (Utopia Planitia). They become **one region** that contains all four kinds of ground, and **where you land is your starting point.**

- **Size:** about 12 × 12 km (today's playable site is about 350 m across).
- **The four landing zones** keep today's trade-offs, now as places on one map:

  | Landing zone | Trade-off |
  |---|---|
  | **The plains** | flat and sunny, easy building and driving, but water is far away |
  | **The canyon floor** | towering cliffs, shaded mornings, ice at the cliff foot, the best layered rock |
  | **The crater floor** | a sheltering rim, mild nights, a layered mound to climb |
  | **The ice fields** | buried ice under your feet, but bitter nights cost heating power |

  The other three zones are then destinations you drive to: ice for the plains base, sunlight for the ice base, cliffs for everyone.
- **More places between them:**
  - dune fields: soft sand where the rover can get stuck;
  - a lava tube entrance: shelter from radiation, dark, a landmark for later;
  - an old landing site: a decades-old probe and its parachute, worth recovering parts from (a nod to real missions, not a copy).
- **Choosing where to land:** the landing picker that exists today (Survival lands inside an ellipse around your target) moves onto the region map. You pick a landing zone, then a spot.
- **One sun and climate** for the whole region, with local differences: cliffs and the crater rim cast shade, the ice fields lose heat faster at night, the crater floor is sheltered.
- **What changes for existing games:** each saved base keeps its site as it is today, so old saves still load. The region is how new Survival games start. Missions keep their current site until they're revamped.

### 5.1a Building the region: Terrain3D
[Terrain3D](https://github.com/TokisanGames/Terrain3D) is a free, open-source (MIT) terrain plugin for Godot 4. Version 1.1.0 (30 Oct 2026) supports Godot 4.5–4.8, so it covers our 4.7.2.

- It draws large terrain efficiently: detail drops with distance (up to 10 levels), and terrains can be up to 65 km across, so 12 km is comfortable.
- **Painting:** up to 32 ground textures, painted by hand or from code, with texture detiling, plus colour and wetness painting (dust, frost).
- **Sculpting** and **holes** (for the lava tube entrance).
- **Scattering:** its own rock and boulder scattering, with distance detail and collision near the player.
- **Heightmaps:** it imports terrain made in other tools, or any heightmap, and it can be read from GDScript (heights for building, landing and GAR-Y).

**Where the shape comes from**, two options:

1. **A composite region we design:** shape it in a terrain tool (or by script) to fit the game: the four zones exactly where we want them, and drives that are fun. The most control.
2. **Real Mars elevation data underneath:** public elevation models from orbit (for example from the CTX camera, about 20 m per pixel over large areas) give the big shapes of a real place; we add detail and rocks on top. The most authentic, but real places rarely have all four zones within 12 km, so we'd still adjust it. The data's terms of use need checking before we commit.

I'd suggest option 1, with real places as reference for each zone's look.

**Risks to check in a prototype:**
- performance on the Dell laptops' integrated graphics (Terrain3D has settings to limit what it draws);
- moving the base-building grid, landing and GAR-Y's ground checks from today's hand-written terrain code onto Terrain3D;
- precision at 12 km from the centre (should be fine at this size).

### 5.2 Getting around
- **On foot:** close to the base and around a parked rover. Walking speed should drop to a suit pace (about 2.5 m/s; today it's 5 m/s), with a short, oxygen-costly sprint.
- **The rover as a mobile base:**
  - a pressurised cabin: take your helmet off, top up the suit, eat, sleep on long trips;
  - **battery range** is the limit (today about 4 km a charge). Upgrades extend it: extra batteries, a solar panel trailer, a heater (*The Martian* rover rebuild, without copying it);
  - it can **get stuck** in sand or tip on a slope, so careful driving matters;
  - the cabin's screen shows the map, range left and the way home.
- **Travel time:** a sol is 20 real minutes, so a 6 km drive at today's top speed takes about 15 real minutes. Options: a faster rover, a **"drive to waypoint" auto-drive** that speeds up time, or both. To decide (§10).

### 5.3 Finding things: the map
- **Orbital imagery** from Mission Control: the whole region at low detail, with fuzzy **areas of interest** ("possible ice", "layered outcrop") rather than exact spots.
- **Surveying turns fuzzy into exact:** your walk-through, GAR-Y's ground scans, or a deployed instrument pins down the actual sample spots.
- **The map table** in Mission Operations, and the rover's screen, show what you know. Marked spots include dropped samples, your caches and the rover.

### 5.4 What you do out there
Each activity is a short, physical procedure, not a single button press.

| Activity | Where | How | Brings back |
|---|---|---|---|
| **Rock sample** | any outcrop | look for a promising rock, chip it with a hammer, bag and label it | a rock sample |
| **Regolith scoop** | anywhere | scoop into a sample bag | soil for the printer and for perchlorate tests |
| **Ice core** | ice fields, shaded craters | set up the core drill, drill to depth (hold, watching torque), cap the core | an ice core: water and climate history |
| **Frost sample** | shaded spots, at dawn | scrape before the sun gets to it | a frost sample (short-lived, so get it home cold) |
| **Deploy an instrument** | chosen spots | carry, set down, level and switch on: weather station, seismometer, radiation monitor, relay beacon | live data every sol (science), better forecasts, comms range |
| **Recover parts** | the old landing site | unbolt and carry | spare parts and a piece of history |
| **Set up a cache** | anywhere | drop an oxygen tank and a battery pack | a top-up point that extends your range |
| **Rescue and repair** | anywhere | dig the rover out, repair an instrument after a storm, bring GAR-Y home | the trip continues |

**Carrying:** suit pouches hold a few small samples; bigger ones (cores, parts) are carried by hand with the existing carry system, or loaded into the rover's sample box. Room is limited, so what you take is a choice.

### 5.5 What makes it hard
- **Running low:** oxygen and battery, the main tension.
- **Night cold:** shorter trips, and darkness that needs lights and markers.
- **Dust storms:** forecast a few sols ahead; visibility drops, solar charging fails, and getting caught out far from home is the classic disaster.
- **Solar particle events:** a short warning, then get to shelter (the rover, the lava tube, the base's shelter) or take a big dose.
- **Terrain:** slopes you can slide down, sand that traps the rover, cliffs.
- **Getting lost:** the map helps, but far out with no relay beacon, the comms and position fix get vague.
- **Breakdowns:** a rover wheel, a suit fan, a drill bit, fixed with kit you brought or didn't.

## 6. Inside

### 6.1 Coming home
The airlock is a procedure: cycle in, brush the dust off at the grate, suit off. Hang the suit on the rack to recharge, and drop samples in the lab's pass-through or carry them in. It's the moment of relief after a trip.

### 6.2 The lab: where samples become science
- **Analysis** is a short procedure at the workbench and microscope: prepare the sample, run it, read the result. It's quick for common rocks and longer for rare ones.
- **Each sample gives science** (rare and well-chosen samples give more) and sometimes a **discovery**:
  - about the region: "rich ice 600 m north-east of the crater";
  - about survival: "perchlorate in the soil here, filter it for the greenhouse";
  - about Mars: "these layers formed in standing water", the seed of a later story.
- **The archive** fills with labelled samples: a visible record of everywhere you've been.

### 6.3 Planning the next trip
At the map table in Mission Operations (or the rover screen):

- **the forecast:** storms and solar activity for the next few sols;
- **the target:** pick an area of interest or a directive;
- **the kit:** at the EVA tool station, choose what to take: core drill, hammer and bags, an instrument, a cache, spare oxygen. The rover's cargo space limits it.

### 6.4 Keeping the base running
The 24 Oct doc's best ideas become the rounds between trips, and they connect to the trips:

- **filters and servicing** on life support (an ice core can become drinking water, so water is something you go and get);
- **the greenhouse:** perchlorate-free soil from your scoops grows better crops;
- **meals:** a proper meal before a big trip gives a well-fed bonus;
- **the uplink window:** send your findings to Earth (that's when science turns into requisition, §7).

### 6.5 Resting
Sleep in a bunk to clear fatigue and skip the night. The crew's sim keeps running while you're out or asleep, so the base has to cope without you, and you come home to its state.

## 7. Progression: science pays for supplies
- **Science** comes from analysed samples and from deployed instruments' daily data.
- **At each uplink,** science adds to **requisition**: Mission Control's willingness to send things.
- **Each resupply,** you spend requisition choosing what comes:
  - **suit upgrades:** bigger oxygen tanks, a better battery, a hardened visor;
  - **rover upgrades:** batteries, a trailer, a winch, a better heater;
  - **field kit:** a deeper core drill, more instruments, caches;
  - **base kit:** catalogue items beyond the starting cargo;
  - **people:** more crew (later, when crew management arrives).
- **Range is the progression.** Better kit lets you reach the far zones, which hold the best samples, which earn the most science.

This replaces the flat cargo top-up that resupplies give today in Survival.

## 8. Goals without a story (yet)
- **Directives:** Mission Control posts two or three at a time, shown in a small panel (like the readiness panel). For example:
  - "Core the north ice field to 2 m";
  - "Deploy a weather station on the crater rim";
  - "Bring back a sample from the layered cliffs";
  - "Keep the crew's wellbeing above 70% for 10 sols".

  Completing one gives bonus requisition. They're templated and generated, so they keep coming.
- **Milestones** in the dossier: furthest point reached, longest trip, every zone visited, the first ice core, sols survived.
- **Story hooks for later:** discoveries, the old landing site and the lava tube are where an authored story can attach without rebuilding the loop.

## 9. An example sol and an expedition

**A sol close to home:**

1. Wake at 07:00, well rested. Overnight message: dust storm in three sols.
2. Breakfast; the air recycler's filter is due, so clean it.
3. Suit up for a short trip: scoop regolith and chip two basalt samples 400 m out. Back at 40% oxygen.
4. Analyse in the lab: one basalt has olivine (a small discovery).
5. Afternoon: harvest greens; the uplink window sends today's science.
6. Evening: plan a two-day trip to the crater rim before the storm.

**A two-day expedition:**

1. Pack the rover: core drill, a weather station, two caches, spare oxygen.
2. Drive 5 km to the crater rim, dropping a cache halfway.
3. Deploy the weather station, chip layered-rock samples, then night falls.
4. Sleep in the rover; at dawn, scrape frost in the crater's shadow.
5. Drive home racing the storm front, topping up at the cache.
6. Back at base with the storm an hour behind you: the best haul yet.

## 9a. Verticality: trenches, terraces and storeys (design, not built)

Real siting studies want flat, firm ground for landing and the first habitat (our level landing pads). But established base designs use height on purpose, mostly for **radiation shielding** and **steady temperatures**. That gives the game grounded ways to build down and up:

1. **Trenches (cut and cover), first.** Dig a trench, set rooms in it, then bury them:
   - **digging:** the regolith intake (or a rover blade, later) cuts a trench a room deep; Terrain3D can change the ground while you play, so the trench is real terrain;
   - **building in it:** rooms sit on the trench floor at a lower level; a ramp or stairs corridor leads down from ground level;
   - **burying:** backfill over the roof gives strong shielding, which plugs into today's shield points and the Mission 7 shelter rules: a buried storm shelter is the best kind;
   - **trade-offs:** digging takes time and power, buried rooms get no windows, and trenches can't be dug in bedrock (ice fields and dust only).
2. **Building against a cliff or crater wall:** the rock blocks half the sky, so rooms beside a cliff get a shielding bonus on that side. The canyon and crater landing zones make this a real choice.
3. **Split levels (terraces):** each room can sit at its own floor height, joined by stair or ramp corridors, so a base can follow sloping ground. It needs the builder to drop its one-floor-height rule; a big change, after trenches.
4. **Two-storey modules:** stacked rooms with a ladder or stairwell, like many concept habitats. Later still.
5. **Lava tubes:** a natural roof of rock, the ultimate shelter; a destination now, a base site later.

**Suggested order:** trenches, then cliff shielding, then split levels, then storeys.

**Trenches: first version built (31 Oct).** On region sites, the Structure tab has a Trench tool:
- **dig:** drag out 2 × 2 to 10 × 10 cells on the pad; R turns the ramp. It's 3.4 m deep (a room's roof ends level with the ground), with grey retaining walls, a 9 m ramp up one side, an apron of graded ground round the top and a caution stripe along the drop;
- **the ground:** the region's terrain is sunk under the trench (not cut with holes: Godot's default physics can't handle Terrain3D's hole markers), and the game's height checks see the trench, ramp and floor, so you, GAR-Y and the rover can use it;
- **rooms:** the first room in a trench puts the base floor on the trench floor, and the base stays on one level (a room up top is refused while the base is in the trench, and the other way round); nothing can be built on the ramp;
- **shielding:** each outside wall bay of a trench room with earth behind it counts as a regolith panel (8 points), for the room and the whole base; Roof Shielding buries the roof;
- **fill it in:** X on an empty trench fills it back in and the ground comes back; Ctrl+Z too. It's saved with the base;
- **tested:** `tests/trench_test.gd`.

Not yet: digging takes no time or power, windows aren't stopped on walls that face earth, and buried walls don't yet keep more heat in.

## 10. To decide
1. **Suit duration:** about 8 game hours of oxygen (8–9 real minutes by day), or longer or shorter?
2. **Walking speed:** drop to a suit pace (about 2.5 m/s), or keep today's 5 m/s?
3. **Travel time across the region:** faster rover, auto-drive to a waypoint with time sped up, or both?
4. **Region size:** about 12 × 12 km, or smaller to start (say 6 × 6 km) and grow later?
5. **The region's shape:** a composite we design, or real Mars elevation data underneath (§5.1a)?
6. **The lab procedures:** quick (a few seconds per sample) or a small hands-on routine each time?
7. **Sample carrying limits:** how many in the suit, how many in the rover?

## 11. What to build first (a suggestion)
1. **Region prototype with Terrain3D:** a 6 km test region with two landing zones, the rover and the base grid, to prove travel works and runs well on the target laptops.
2. **Suit systems and passing out:** oxygen, battery, warnings, the airlock top-up, and GAR-Y's rescue.
3. **Samples and the lab:** rock samples, regolith scoops, analysis and science.
4. **Requisition and resupply choices.**
5. **Ice cores, instruments and caches.**
6. **Directives.**
7. **Fatigue and sleep.**

## 12. Region prototype (built 31 Oct)

The first step of §11 is in place on this branch.

- **Terrain3D 1.1.0** is installed in `addons/terrain_3d` (Windows and Linux 64-bit builds only; the other platforms' builds were left out to save 31 MB). Its editor plugin is enabled, so the region can be sculpted and painted in the editor later.
- **The test region** is a 6 × 6 km composite made by `tools/generate_region.py` into `assets/terrain/test_region/`:
  - open plains with five mesas;
  - a 2.2 km crater with a terraced central mound;
  - a 170 m canyon scarp along the north edge;
  - a dune field and polygon-cracked ice fields;
  - about 900 small craters;
  - ragged hills framing the edge.

  Run the script again to change it (about 25 seconds); `preview.png` shows the layout from above.
- **Two prototype sites,** Test Region · Plains and Test Region · Crater, land on the same terrain. `scripts/region_terrain.gd` answers the game's height questions from the heightmap, and Terrain3D draws the same heightmap with full collision, so building, the lander, GAR-Y and the rover all work on it unchanged. Each pad is exactly level.
- **Looks:** the ground is textured by slope (dust on the flat, rock on the steep), with about 36,000 rocks scattered by Terrain3D across the region. Haze is thinner on regions, so far landforms read as silhouettes.
- **Performance** (Intel Arc 130V, 1920 × 1080, today's plains outside → region outside):

  | Preset | Plains | Region |
  |---|---|---|
  | Low | 141 fps | 113 fps |
  | Medium | 91 fps | 68 fps |
  | High | 63 fps | 58 fps |

  Loading takes about 3 s longer than a normal site.
- **Polish (31 Oct, later):**
  - **ground textures by zone:** a control map paints dust, dark dune sand, frost polygons on the ice fields, mud-cracked clay on the crater floor, gravel on mesa skirts and crater ejecta, and bedrock on slopes and the mound; a colour map adds gentle large-scale tint;
  - **a terraced mound** with benches and buttes, and the dune field moved clear of the crater rim;
  - **solid rocks:** the instancer's rocks have no collision of their own, so a pool of colliders follows the player, the crew rover and GAR-Y (`scripts/region_rock_collision.gd`); about 30,000 rocks are big enough to block you;
  - **the region map** (Tab while exploring a region site, `scripts/region_map.gd`): shaded relief by ground type, named places, landing zones, you, the lander, the base, the rover, GAR-Y and the distance home.
- **Not done yet:**
  - the site screen's backdrop still uses the old sites' camera framing;
  - the landing picker still works within the zone, not across the region.
