# The four Mars goals: what a tour of duty is for

> **31 Oct: `docs/core-loop.md` now decides the core loop and wins where this doc disagrees** (for example: open-ended chapters instead of a tour, walkback shown but never punished, a general module first).

*Design for discussion, 31 Oct 2026, on the `implementing-gameplay-loop` branch. Nothing here is built yet. It gives the gameplay loop brief (`docs/gameplay-loop-brief.md`) its direction: §6.2 (the lab), §7 (progression) and §8 (goals) are built around it. It fits with phase 4's commissioning and flight rules (`docs/commissioning-and-flight-rules.md`). Survival only for now; Missions may adopt it later (open question 8).*

**Decided with you (31 Oct):**
- a run is a **tour of duty**: a planned stay that ends in a mission report graded on each goal, then you can stay on;
- science is earned **per goal**, by four science teams at Mission Control, not as one pool.

## 1. The idea in one paragraph

NASA's Mars science community (MEPAG, the Mars Exploration Program Analysis Group) has organised everything Mars missions try to learn into **four goals**: did Mars ever support life, how its climate worked and changed, how the planet formed and evolved, and how to prepare for people living there. NASA doesn't rank them. In Outpost One, each goal has a **science team** at Mission Control that wants different things from different places, using different kit. Your tour is judged on all four. So every trip outside has a reason that comes from real science, the region's places each matter to a goal, and what you choose to chase decides what kit Mission Control sends next.

## 2. The four goals in plain language

| | NASA's goal | In plain words | What it looks for |
|---|---|---|---|
| **I** | **Life** | Did Mars ever support life? | places that were once **habitable** (water, energy, the right chemistry), and whether any held life; **biosignatures** preserved in rock |
| **II** | **Climate** | How did Mars' climate work, and how did it change? | today's weather and dust; the **record of the past** locked in ice and layered sediment; where the water went |
| **III** | **Geology** | How did Mars form and evolve as a planet? | the **order** in which rocks were laid down; volcanoes, impacts, water; the planet's **interior** |
| **IV** | **Prepare for humans** | What do people need to know and do to live and work there safely? | resources on site (**ISRU**: using local water, air and soil), radiation, dust, hardware that works, crews that stay healthy |

NASA's newest framework (2026) groups the three science goals as themes (life and habitability; ice, weather and climate; geology) and treats human exploration alongside them. The four-goal split is still how the science is talked about, and it maps cleanly onto play.

**Why this suits the game:** Goals I to III are what you go outside for. Goal IV is what the base already is. The habitat sim, the regolith printer, the suit and phase 4's commissioning are all "preparing for humans", so the base-builder half of the game counts for something, not just the explorer half.

## 3. Each goal as gameplay

The region's places (from `assets/terrain/test_region/region.json`: the crater, the layered mound, the canyon, the dune field, the ice fields, the mesas, the ancient river and its delta) each matter most to one or two goals.

### 3.1 Goal I · Life

**Where:** the **ancient river and delta** (clays and fine sediment, the best place to preserve signs of life, like Jezero), the **layered mound** (layers laid down in water), hydrated minerals at the canyon foot, and later the **ice fields'** buried ice.

**What you do:**
- **Sample with context, not just rarity.** A sample earns Life science by *where* it came from and how well it's recorded: which layer, photographed in place, its position marked. A clay from the delta's bottom layer, documented, is worth far more than a random pebble. You learn to read the ground.
- **Planetary protection.** You're the most contaminating thing on Mars. Life samples need:
  - **clean tools:** a sampling kit kept sealed and sterilised at the lab between trips;
  - **away from the base:** samples taken downwind of the habitat, or within a few hundred metres of it, are flagged "possibly contaminated" and worth little;
  - **special regions:** a few places where ice could support microbes today. They need the full sterile procedure (gloves over gloves, fresh tools, no rover closer than 50 m), and a careless sample there counts against you.
- **The sample cache.** The best samples are sealed in **tubes** and left at a marked depot for a future return mission to collect and bring to Earth (a nod to Mars Sample Return). What you choose to cache, out of a limited number of tubes, is the Life team's biggest score.

**The Life team wants:** documented samples from habitable settings, a clean record, a well-chosen cache.

### 3.2 Goal II · Climate

**Where:** the **ice fields** and shaded crater floors (ice cores), the **layered mound** and **mesas** (banded sediment, a record of changing climate), dawn frost anywhere shaded, high and low points (the crater rim, the canyon floor) for the atmosphere.

**What you do:**
- **Ice cores** (brief §5.4): drill, watch the torque, cap it, get it home cold. The **depth** matters: deeper ice is older climate.
- **Dawn frost:** scrape it before the sun reaches it; it only lasts until mid-morning (brief §4.2).
- **Weather stations:** carry one out, level it, switch it on. Each sends data every sol. A **network** (stations far apart, at different heights) is worth much more than one, and it gives you better storm forecasts in return.
- **Storm records:** a station that keeps running through a dust storm, and is dug out afterwards, sends the most valuable data of all.
- **Sediment sections:** a column of samples up a banded slope (the same procedure as Geology's, read for climate).

**The Climate team wants:** cores, a long, unbroken weather record from a spread-out network, and storms measured, not just survived.

### 3.3 Goal III · Geology

**Where:** the **canyon** and **mesas** (cliffs that show the layers), the **crater** rim (rock thrown out by the impact, from deep below), basalt plains, the **dune field**, and the lava tube when it exists.

**What you do:**
- **Stratigraphy:** sample a cliff or mesa **bottom to top, in order**, marking each layer's height. A complete section from one place tells the story of how it formed. Out of order or with gaps, it's worth less.
- **Rock types:** basalt, olivine, impact breccia from the crater rim, sandstone, sulfates. Each type you find and analyse for the first time is a discovery (brief §6.2).
- **A seismometer network:** like NASA's InSight lander. One seismometer hears marsquakes; three far apart can locate them, and over the tour they map the planet's interior. Setting them on bedrock, levelled and shielded from wind, is the procedure.
- **Mapping:** surveying turns orbital fuzzy areas into exact geological units (brief §5.3). GAR-Y's surveys help.

**The Geology team wants:** complete sections, the rock types catalogue filled, the seismometer network running, the region mapped.

### 3.4 Goal IV · Prepare for humans

**Where:** the base itself, the landing zones, and everywhere you go.

**What you do (mostly things the game already does, now counted):**
- **Live off the land (ISRU):** the regolith printer and intake (built 22 Oct), ice cores turned into drinking water, oxygen made from the atmosphere (a MOXIE-style unit, a later item). Each kilogram made on Mars counts.
- **Prove the kit:** phase 4's commissioning and the rover's walkback shakedown are exactly this: hardware tested in the field for the crews who come next. Every item commissioned and every kilometre driven safely counts.
- **Radiation:** log your dose with a radiation monitor; measure how much a regolith wall or the lava tube shields.
- **Dust:** what it does to solar panels, seals and filters (the habitat sim already wears things down); keeping a record of it, and of the fixes.
- **Landing sites for later crews:** survey a landing zone: flat enough, hazard-free, near water. A good report on a second site is a big Goal IV score.
- **A healthy crew over a long stay:** wellbeing, fatigue, meals, the base running without alarms.

**The Humans team wants:** Mars-made resources, proven kit, measured radiation and dust, a characterised second landing site, and a crew that's still well at the end of the tour.

## 4. Four science teams

Mission Control has four teams, one per goal. They're how science turns into kit.

- **Each team posts investigations.** These are the brief's directives (§8), now drawn from a goal: "Bring back a documented section from the north mesa", "Core the ice fields to 2 m", "Get a second seismometer running at least 2 km from the first", "Characterise the plains as a landing site". Two or three per team at a time, templated, so they keep coming.
- **What you deliver earns that team's backing.** At each **uplink** (brief §6.4), analysed samples and instrument data go to the team whose goal they serve; some serve two (a sediment section helps Climate and Geology).
- **Backing pays for kit.** Each resupply's **requisition slots** (`docs/commissioning-and-flight-rules.md` §7) are filled by the teams, from their own catalogues:

  | Team | Sponsors |
  |---|---|
  | **Life** | the clean sampling kit, sample tubes for the cache, a lab instrument for organics |
  | **Climate** | the deep ice drill, weather stations, a cold box for cores |
  | **Geology** | seismometers, a rock saw and microscope for the lab, a drill for bedrock |
  | **Humans** | suit and rover kit (bottles, battery modules, the trailer), ISRU units, radiation monitors, more crew later |

  So the planned cargo (phase 4's fixed ladder) arrives regardless, and what you've done decides the extras and what comes first.
- **They can pull in different directions.** The Climate team wants you at the ice fields in the long dawn shadow; the Life team wants the delta before a dust storm buries it. You can't do everything, so choosing is part of the game. Neglecting a team doesn't stop the run, but it shows in the report.
- **They talk in short notes** on the Mission Control screen: measured, a bit human ("The Geology team is thrilled with the mesa section. They'd like the one next to it."). Voices are an open question.

## 5. The tour of duty

A Survival run becomes a **tour**: a planned stay, with a beginning and an end.

- **Length:** proposed **60 sols** (about 20 real hours at today's 20-minute sol). Open question 1.
- **The science plan.** At landing, Mission Control gives each goal a **target** for the tour (a few headline objectives each, for example Life: "a cache of 10 documented samples, at least 3 from habitable settings"). The Mission Control screen shows the four goals' progress, with the sols left.
- **Where you land sets your opening, not your limit.** Each landing zone leans to a goal:

  | Landing zone | Leans to | Why |
  |---|---|---|
  | The plains | IV Humans | easy building and driving; a strong base early |
  | The crater floor | II Climate and III Geology | the layered mound on the doorstep, a sheltering rim |
  | The old riverbed | I Life | the river valley and delta in reach; cliffs for Geology |
  | (later) the canyon floor, the ice fields | III Geology, II Climate | the best layers; ice under your feet |

  All four goals are reachable from anywhere, given the range (which is what phase 4's kit is for).
- **The end: the mission report.** On the last sol the return vehicle's window comes. The report extends the existing dossier (`scripts/mh_dossier.gd` writes the Missions dossier as an HTML page today):
  - a **grade per goal** (how much of its target you met, and how well);
  - **highlights:** your best discoveries, your furthest trip, the cache, the seismometer's biggest quake, GAR-Y's rescues;
  - **the flight-rules record** (phase 4) and the crew's health;
  - then a choice: **go home** (the run ends) or **stay on** (free play, the teams keep posting investigations, no more grading). A second tour could come later.
- **One life** (brief §4.3) ends the tour early with the same report.

## 6. How the loop changes

The brief's three loops (§3), read through the goals:

| Loop | What changes |
|---|---|
| **The trip** | each trip has a goal purpose: an investigation, a place, the kit that goal needs |
| **The sol** | the lab analysis and the uplink report to teams; the base itself earns Goal IV |
| **The run** | the tour: four targets, a deadline, a report |

**A sol, early in a riverbed tour:**
1. Wake. The Life team asks for a documented clay from the delta's lowest layer; the Climate team's first weather station has a week of data.
2. Pack the clean sampling kit (sealed since last night) and two tubes.
3. Drive out within the walkback limit (phase 4). Sample the lowest delta layer: photograph it in place, mark its height, bag it with the clean tools, upwind of the rover.
4. On the way home, chip a basalt from the valley wall for the Geology catalogue.
5. Lab: analyse. The clay holds hydrated minerals: a discovery, and a candidate for the cache.
6. Uplink: the clay goes to Life, the basalt to Geology, the weather station's data to Climate, the printer's output to Humans.

**A tour's arc (60 sols):**
- **Sols 1 to 15:** set up the base (Humans), nearby geology and the first weather station, commission the first suit kit.
- **Sols 15 to 40:** reach further: the delta for Life, the ice fields for Climate, the seismometer network for Geology. Caches and the second battery module.
- **Sols 40 to 60:** long expeditions with the trailer; finish the sections; choose and seal the cache; the landing-site survey. Then the report.

## 7. What exists, what's new

**Already there to build on:**
- GAR-Y's surveys, ice finds, rock and core samples (`scripts/companion_rover.gd`: `samples`, `rocks`, `ice_samples`, `has_core`);
- the region's features and labels, and the region map with markers (`scripts/region_map.gd`, `assets/terrain/test_region/region.json`);
- the habitat sim's stores, wear and alerts, with the alert log (`scripts/habitat_sim.gd`, `scripts/habitat_alerts.gd` `history`);
- the regolith printer's running total of Mars-made material (`printed_kg`);
- resupply landers (`scripts/mars_world.gd` `_check_resupply()`), and phase 4's manifest and requisition slots;
- the dossier's HTML page (`scripts/mh_dossier.gd`);
- How it works cards (`data/how_it_works.json`) for each new idea.

**New:**
- **sample records** with context: place, layer height, photographed, clean or not, which goals it serves;
- the **lab analysis** (brief §6.2), producing results and discoveries;
- **four teams**, their backing, and their investigations;
- **instruments** that send data every sol (weather station, seismometer, radiation monitor);
- **planetary protection:** the clean kit, contamination flags and special regions;
- the **sample cache** and its tubes;
- the **tour:** the clock, the science plan, the four goals' progress, the mission report.

## 8. Saving

Old saves load as a tour that started on their current sol, with no samples or backing; nothing is lost.

- **Tour:** `{start_sol, length_sols, landing_zone, targets: {life, climate, geology, humans}, ended, stayed_on}`.
- **Samples:** `[{id, kind, position, layer_m, photographed, clean, analysed, results, goals, cached}]`.
- **Teams:** `{life: {backing, delivered, investigations: [...]}, climate: ..., geology: ..., humans: ...}`.
- **Instruments:** `[{id, kind, position, levelled, running, data_sols}]`.
- **Cache:** `{position, tubes: [sample ids], sealed}`.

## 9. Tests

Light testing: one new file, `tests/science_goals_test.gd`, for what's new.
- a documented sample scores more than an undocumented one; one near the base is flagged as possibly contaminated;
- a sediment section scores more in order and complete;
- an uplink sends each delivery to the right team, and a two-goal sample to both;
- a second seismometer far from the first counts towards the network, one close by doesn't;
- backing fills requisition slots from that team's catalogue;
- the tour ends on its last sol with a report graded per goal, and staying on keeps playing;
- everything saves and loads, and an old save loads as a fresh tour.

## 10. Build order

It slots into the brief's suggested order (§11), after suit systems:

1. **Samples and the lab:** sample records with context, the analysis procedure, results and discoveries. Delivered to one Mission Control inbox at first.
2. **Four teams and investigations:** deliveries split by goal, backing, the teams' notes, templated investigations.
3. **Instruments:** weather station and seismometer (models in Blender, MHPalette house materials), daily data.
4. **Requisition:** teams fill phase 4's manifest slots.
5. **Planetary protection and the cache:** the clean kit, contamination flags, special regions, tubes and the depot.
6. **Goal IV counted:** Mars-made resources, commissioning, radiation, dust, the landing-site survey, crew health.
7. **The tour and the report:** the clock, the science plan, the four goals' progress on the Mission Control screen, the mission report, staying on.

## 11. Open questions

1. **Tour length.** 60 sols (about 20 real hours)? Shorter (30) for a first tour?
2. **Grading.** Letter grades per goal, a percentage, or a written assessment from each team (or both)?
3. **Ignoring a goal.** Fine (a low grade for it), or should the science plan insist on some of each?
4. **Planetary protection.** How strict: a gentle score penalty, or a contamination you can't undo in a special region?
5. **Goal IV.** Should it count partly on its own (sols with the base running well), or only through deliberate investigations?
6. **The teams' voices.** Text notes only, or radio voices (different from the suit's)?
7. **Landing zone at start.** Should choosing a zone tell you which goal it leans to, or leave that for you to discover?
8. **Missions mode.** Should the campaign be revamped around the four goals too, when it's rebuilt after this gameplay exists?
