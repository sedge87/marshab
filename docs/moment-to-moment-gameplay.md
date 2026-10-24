# Moment-to-moment gameplay: making every room and item feel alive

*Draft for discussion, 24 Oct 2026, written overnight. Nothing in this document is built; the rover is the one exception (see the morning summary).*

This is the design pass that Batch F asked for ("a real interaction for every item, no exceptions"). It covers:

- what "alive" should mean in Outpost One;
- the few shared systems the ideas rely on;
- ideas room by room, then item by item for every piece in the catalogue;
- the outside, and how a sol could flow;
- what I'd build first.

## 1. Where the game is now

There's a lot already, which helps.

- **Most items have one to three interactions.** Doors, drawers and lids open, lights switch, machines run, crops can be harvested, panels show live readouts.
- **Underneath, the simulation is rich:**
  - air, water, food, power and heat;
  - breakdowns and spares;
  - injuries and fitness;
  - wellbeing needs;
  - storms, radiation and breaches;
  - research;
  - GAR-Y's orders.

**The gap:** almost every interaction is a toggle you do once. After that the item does its job with no further input from you, so a typical sol is "build, then watch". The simulation is alive, but your hands aren't in it.

- **22 items have no interaction at all:**
  - wall strips and panels;
  - the airlock panels;
  - desks, chairs and shelving;
  - the IV stand, vitals monitor and surgery cart;
  - the waste hoppers;
  - the galley table;
  - most of the odds and ends.
- **The crew are numbers.** You never see them.

## 2. What "alive" should mean here

These are the rules every idea below follows.

1. **Every interaction changes something you care about:**
   - a resource;
   - a crew need;
   - a risk;
   - or knowledge (what's wrong, what's coming).

   "Open the drawer" is fine as a detail, but the main action on each item should matter.
2. **Short loops.** A good interaction takes 5–60 seconds of the player's attention and pays off within a sol.
3. **The base asks for your hands, but doesn't nag:**
   - most systems run fine on their own;
   - hands-on care makes them run *better* (efficiency, wear, mood);
   - neglect shows slowly and visibly, never as a sudden fail.
4. **You can see and hear the cause.** A clogged filter looks clogged, a struggling pump sounds strained, a happy room is warm and lit.
5. **Grounded, not gamey.** Everything is something a real crew would do: NASA analogue missions (HI-SEAS, MDRS, Mars-500) and ISS routines are the reference.

   It's our own identity, not Subnautica's:
   - no crafting tree;
   - no scanner-everything;
   - checklists, maintenance, science and people instead.
6. **No new screens if a diegetic one will do.** Equipment screens, labels, gauges and Mission Control are already the game's language.

## 3. Shared systems the ideas rely on

Five small systems carry most of the per-item ideas, so they're worth building once.

### 3.1 Condition (wear) on machines

Each life-critical or busy machine gets a **condition** from 0 to 100%, alongside the existing breakdown chance. It drives the rest:

- condition falls with use, faster in dust storms;
- below 60%, efficiency drops a little and the machine *sounds* rough;
- below 30%, breakdown chance rises;
- a **service** interaction brings it back.

Services are short hands-on routines, which become the heart of the base's moment-to-moment play:

- pull the filter and clean it;
- top up the coolant;
- recalibrate;
- tighten a coupling.

Each item's service is different and named for what it is, so it never feels like the same chore everywhere. Spares are used for the bigger repairs, which ties into the existing spares and printer loop.

The info card (I) shows condition and when it was last serviced. Mission Control nudges you once, not repeatedly.

### 3.2 Crew presence: see them

This is the biggest single "alive" boost, and it can be phased.

- **Phase 1, presence without people:** rooms show signs of who was there:
  - a mug left on the table;
  - a jacket over a chair;
  - a bunk curtain drawn when someone's asleep;
  - music from the living quarters;
  - a voice on the intercom;
  - a light left on in the lab at night.

  This is cheap and very effective. It's driven by the crew's existing schedule: sleep, meals, work rooms, exercise.
- **Phase 2, crew figures:**
  - simple, stylised suited or overalled figures (no faces needed; think *Firewatch* silhouettes);
  - they walk between rooms on a schedule, sit at stations, use the exercise station, sleep in bunks;
  - you can look at one for a line ("Okafor · Botanist · Tired, needs a proper meal").
- **Phase 3, crew requests:** small asks that come from real needs (§3.3).

### 3.3 Crew requests (the task board)

A small list on the explore HUD (or a tablet) of 1–3 live requests, each tied to a real sim state. For example:

- "The lab's sample freezer is iced up. Can you defrost it?" (science work speed);
- "We're out of fresh greens. Harvest tray 2?" (food and wellbeing);
- "Battery bank 2 is running hot." (power);
- "Taylor's birthday tomorrow. Anything special in the galley?" (wellbeing).

Doing one gives a little wellbeing and trust (§3.5). Ignoring it has the natural consequence, nothing worse. This turns the simulation's numbers into moments.

### 3.4 Flow you can see

Resources should show as they move:

- conduits and pipes that pulse faintly when carrying power, water or air;
- gauges on machines that read the real values;
- a power-flow overlay;
- the hum of the base changing with load;
- solar arrays turning gently through the day (optional sun tracking for one tier).

### 3.5 Small currencies

To give hands-on care a reason, without a crafting tree:

- **Morale** already exists. Requests, meals, music, plants, windows and posters feed it.
- **Trust:** the crew's confidence in the commander. It goes up when you respond to requests, keep systems serviced and get everyone through emergencies. High trust means faster work and calmer crises. It's shown on the Crew screen.
- **Samples and data** feed research (§4.4). Research already exists as a number; this gives it physical form.

## 4. Room by room

Each room has a short loop the player can take part in, ideas for its moments, and what those moments feed. Effort: **S** is a day or less, **M** is two or three days, **L** is a week or more.

### 4.1 Living Quarters
**The loop:** rest and recover. Morale and sleep quality are the outputs.

- **Sleep quality, not just sleep.** Light, noise, temperature and privacy curtains already exist; make them add up to a sleep score the crew comment on in the morning ("Slept badly. Engineering was loud."). S
- **Personal spaces.** Each bunk belongs to a crew member. Personal items the player places (photo frame, books, plush, guitar) near someone's bunk raise *their* morale more than generic ones. Show the owner's name on the bunk label. M
- **Wind-down activities** in the evening:
  - **guitar:** strum, and there's already a strum sound; a short rhythm prompt plays a real chord progression; a crew member hums along at night;
  - **chess:** a move each sol against a crew member, finishing over several sols;
  - **books:** read a page, a two-line excerpt of a classic.

  Each gives a little morale and is optional. S each.
- **Laundry and lockers.** Locker contents change: clean suits on a fresh sol, worn ones after EVAs. It's a tiny visual cue that time passes. S
- **The privacy curtain matters.** A crew member asleep behind a drawn curtain: interrupting them (opening it) costs a little morale. S

### 4.2 Galley
**The loop:** turn stores into meals, and meals into morale. Food is the most social thing on Mars.

- **Cook a meal.** At the kitchenette:
  - choose rations only, rations plus greens, or a "proper meal" (uses fresh produce from hydroponics);
  - a 20–30 second routine: open the fridge, take a pack, rehydrate at the dispenser, heat it in the oven;
  - the plates appear on the table and the crew eat at their mealtime.

  Better meals mean more morale; skipped meals mean a hungry crew. M
- **Shared meals.** A table with enough chairs, and everyone at it at dinner, gives a bonus. It's a reason to furnish the galley properly. S
- **Pantry inventory.** Ration packs are physical, as the carry system already allows. Restocking the pantry from cargo crates (carry boxes in) is a short, satisfying chore. When it's low, the galley says so. M
- **Special days.** Birthdays and mission anniversaries (from the dossier's start date) ask for a special meal: herbs from the herb pot, a crate of "Earth treats" from a resupply. S
- **The water dispenser** draws from the habitat's water; filling a cup gives the player-character a small fitness or morale tick. It's already animated, so just wire it up. S

### 4.3 Hydroponics
**The loop:** plant, tend, harvest, eat. It's the most hands-on room.

- **Crop cycle with stages.** Seedling station, then transplant to a grow tray, then grow (visibly larger each sol), then harvest:
  - planting and transplanting are one interaction each;
  - growing reacts to light hours, nutrients and temperature.

  M (crops and harvest exist; add stages and transplanting).
- **Tending.** The nutrient mixer has a pH/EC balance that drifts; nudge it back (a dial interaction) for faster growth. Ignore it and the leaves visibly yellow. S–M
- **Crop choice.** Lettuce is fast and light on calories; potatoes are slow and heavy; tomatoes are morale-rich; herbs are a galley bonus. A choice per tray. M
- **Pollination and pruning** as optional small boosts for the patient player (tomatoes self-pollinate better if you tap the flowers, as on the ISS). S
- **Plants as morale.** Time spent in hydroponics recovers stress, a documented effect. The room's light and green already look good; let it count. S

### 4.4 Science Lab
**The loop:** samples come in from outside; analysis produces knowledge; knowledge unlocks improvements and Mission Control goodwill.

- **Physical samples.** GAR-Y cores and EVA rock samples become carryable sample jars. Bring them in, put one in the workbench, and analyse it:
  - a short routine: grind it, put it on a slide, look under the microscope;
  - the screen shows a stylised spectrum;
  - each analysis yields research and a fact about the site (water content, perchlorate, a buried ice depth).

  M
- **Research projects.** A short list on the lab screen, each needing samples and crew hours:
  - "Perchlorate filter for the water reclaimer: +5% water";
  - "Hardier lettuce strain";
  - "Better regolith bricks: printing 10% faster";
  - "Dust-shedding panel coating".

  This makes research matter mechanically without a tech tree. M
- **The cold archive.** The sample storage cabinet keeps samples cold; a full archive is a dossier highlight. The cabinet's drawers fill with jars as you collect. S
- **The night owl.** A lit lab at night with a crew member hunched over the microscope is a Phase 2 crew moment. S once crew exist.

### 4.5 Life Support
**The loop:** keep the air and water clean. Maintenance is the gameplay here.

- **Filter swaps** (air recycler, water reclaimer):
  - the "Pull filter" interaction already exists; make the filter a real consumable with condition;
  - pull it, see it's clogged and brown, fit a clean one from spares (or clean and refit it at the tool bench);
  - air quality (CO₂) and water output respond.

  S–M
- **Listening for trouble.** Each machine's sound changes with condition. A rattle means a service is due. Ear-driven maintenance is very grounded. S
- **Oxygen generator electrolysis.** The cell stacks degrade; swap a cell module (heavy, use the carry system). M
- **Thermal loop balance.** The thermal control unit's loop valves set which rooms get heat first. Choose by turning the valves (the interaction exists): the lab or the bunks during a cold night. S
- **Leak hunting.** A slow leak (from a micrometeorite or a worn seal) drops pressure a little each hour. Find it by listening (a hiss gets louder as you get close), then patch it with the hull patch kit. M; the breach system already exists.

### 4.6 Power & Engineering
**The loop:** balance supply, storage and load, especially at night and in storms.

- **Battery health.** Cells age with deep discharge. A battery bank's "Check charge" shows its health; swapping a degraded module restores capacity. S
- **Load shedding.** In a storm, choose what to switch off at the distribution panel: greenhouse lights, the lab, heaters in empty rooms. Each breaker is a real switch on the panel, a real decision with visible effects (lights go out room by room). M
- **The isolator ritual.** The main isolator already exists. Before a repair, isolate it, then lock out and tag out with your name on the panel; forgetting is a safety story beat. S
- **Regolith printer jobs.** Choose what to print:
  - spares;
  - shielding bricks;
  - a replacement filter housing;
  - a chess piece the crew lost.

  The print shows layer by layer on the bed over minutes. M

### 4.7 Medical Bay
**The loop:** keep the crew fit and treat injuries.

- **Daily check-ups.** The exam cot already has "Run a health check". Make it the crew's weekly medical: a crew member sits on the cot, and the vitals monitor shows their heart rate, sleep debt and radiation dose. It catches problems early. S
- **Treating injuries.** Injuries exist. Treating one is a short routine:
  - clean and dress at the cot;
  - IV fluids from the drip stand (it finally does something);
  - the surgery cart for anything serious.

  Recovery is faster with care. M
- **Radiation dose tracking.** Each crew member's dosimeter reading; read it at the vitals monitor after a solar event. The dose matters to Mission Control. S
- **Medical supplies** are a consumable restocked by resupply, shown on the cabinet's drawers. S

### 4.8 Hygiene
**The loop:** clean crew are happy crew, and water is precious.

- **Shower minutes.** Showers use real water. A short shower is fine; long ones use the reserve. A crew "shower rota" on the panel lets you trade morale for water. S
- **Greywater.** The shower's greywater filter (exists) feeds the reclaimer; a clean filter means better reclamation. S
- **The toilet** has a urine processor (real ISS hardware) that recovers water; servicing it is the least glamorous and most authentic job on Mars. S

### 4.9 Waste Management
**The loop:** nothing is thrown away on Mars.

- **Sort the waste.** The sorting unit's compactor fills over sols. Sort it into the three hoppers:
  - plastics go to the regolith printer as binder;
  - metals become spare-part stock;
  - organics go to compost, then fertiliser for hydroponics.

  Each bin is a carry interaction. This turns the three hoppers (no interaction today) into a closed loop. M
- **A full compactor smells.** Morale drops nearby. A small, real consequence. S

### 4.10 Storage
**The loop:** know what you have and find it fast in a crisis.

- **Manifests and cases.** The cargo rack's cases are physical: pull one out and carry it to where it's needed (filter case to life support, rations to the galley). Restocking from a resupply lander is a satisfying end to a mission. M
- **Inventory** at the rack's screen: counts of spares, filters, rations and medical supplies. It's the one place the base's consumables are shown. S
- **The tool bench** is where you clean filters and repair small parts (§3.1). S

### 4.11 Mission Operations
**The loop:** stay in touch with Earth, and plan the day.

- **The daily uplink window.** Earth is only in view for part of the sol, so the comms station uplinks at a set time:
  - send the sol report (written from what happened);
  - receive messages: family news for a crew member (morale), a weather forecast, a task from Mission Control.

  Missing the window has a mild cost. S–M
- **The communication delay** is real (4–24 minutes). Messages arrive a while after you send them; the radio already plays them with delay. Lean into it: ask a question and get the answer later. S
- **Mission planning.** The console's mission selector chooses tomorrow's focus (science, maintenance, construction, rest), shifting crew time across rooms. It's a light, meaningful daily decision. M
- **The survey board** shows GAR-Y's ice surveys and the rover's drives (§5.2). It's where you plan an expedition. S

### 4.12 Airlock
**The loop:** going outside is a procedure, not a door.

- **Suit up.** At the suit service panel:
  - check suit oxygen and battery;
  - top them up (a short hold);
  - a pre-breathe timer for the realism-inclined.

  Suit oxygen and battery then count down outside, and the HUD shows them. M
- **Dust.** Coming back in, the dust grate cleans boots; skipping it brings dust inside (hull and window wear already exists; floors could get dusty too). S
- **The airlock control panel** shows pressure through the cycle (it has no interaction today): pressurise and depressurise with a gauge. S

### 4.13 Corridors
- **Wayfinding** already exists. Add a "Where's everyone?" view on wayfinding panels (Phase 2 crew). S
- **Utility conduits** pulse with the flow they carry (§3.4); one opens for a quick inspection when power is lost. S

### 4.14 Vehicle Bay
**The loop:** maintain and charge the rover, plan and come back from drives.

- **The crew rover** (built tonight, §5.2) parks here, charges and gets serviced. M after tonight.
- **The rover charger** extends its plug to the rover, not just GAR-Y. S
- **The EVA tool station** packs a tool kit for an expedition: core drill, sample bags, flags. What you pack decides what you can do out there. M
- **The suit rack** prepares suits before a drive (§4.12). S

## 5. Outside

### 5.1 Site machines
- **Solar arrays.** Brushing dust exists. Add:
  - panel tilt for the season (optional);
  - checking cable connectors after a storm.

  S
- **Reactor.** Very reliable, but needs its radiation shield checked and coolant topped up every few weeks. Heavy and serious: a two-step procedure with a lockout. S
- **Ice drill.** The drill bit wears; swap it. The drill moves from depleted ice to a fresh spot that GAR-Y found (a reason to keep surveying). M
- **Regolith intake.** Clear jams after dust storms. S
- **Comms mast.** Realign it after storms (a short dish-alignment interaction with a signal-strength meter). S
- **Light posts and beacons.** They mark safe paths at night; a dead beacon after a storm is a small job. S

### 5.2 The crew rover (built tonight)
- **Drive it now:** out of the vehicle bay, across the site, and back to charge (see the morning summary).
- **Next:**
  - **expeditions:** drive to a marked site (a survey flag, a likely-ice zone), get out, take a core sample, bring it back to the lab (§4.4);
  - **the rover's battery and range** as the limit, with a "point of no return" readout;
  - **towing:** move a cargo crate or a solar array with the rover;
  - **rescue:** a stranded GAR-Y after a dust storm.

  M–L
- **Rover upkeep:** dust in the wheel bearings and battery health in the bay. S

### 5.3 GAR-Y
GAR-Y already has orders, ice-finding and a rock collection. He could also:

- ride on the rover's rear deck;
- carry a sample back to the lab himself;
- fetch a spare part from storage;
- sit beside a crew member at night in Phase 2.

S each.

### 5.4 The lander and cargo
- **Unloading a resupply** is a short event: open the crates, carry or drive the contents to storage, and the manifest ticks off. M

## 6. How a sol could flow

An example sol once some of this exists. Nothing is mandatory; every step pays off.

1. **Morning (07:00):**
   - the crew wake, and the sleep reports come in;
   - Mission Control's overnight message arrives: dust storm in 3 sols;
   - you read it at the comms station.
2. **Breakfast:** cook in the galley; the crew eat together; morale ticks up.
3. **Rounds (09:00):**
   - the air recycler sounds rough, so pull and clean its filter at the tool bench;
   - the nutrient mixer has drifted, so dial it back.
4. **Midday:**
   - drive the rover to the ice zone GAR-Y flagged yesterday;
   - core sample, back before the battery's half gone.
5. **Afternoon:**
   - analyse the core in the lab: 42% ice, enough for a second drill;
   - research progresses on the dust-shedding coating.
6. **Evening:**
   - harvest lettuce for a proper dinner;
   - Okafor plays the guitar in the living quarters.
7. **Night:**
   - load shedding is ready for the storm;
   - the base hums quietly, and one lab light is still on.

## 7. Every item: from today to proposed

| Item | Today | Proposed main interaction (purpose) |
|---|---|---|
| **Living** | | |
| crew_bunk | curtain, reading light, drawers, sleep | Owner's name; personal items nearby raise their morale; sleep quality report |
| locker | doors | Suits and clothes change with EVAs and sols; stash personal items |
| common_table | habitat stats | Board games and shared meals here give a morale bonus |
| task_light | light | Desk work speed in the lab and ops; it stays on at night if someone's working |
| privacy_divider | fold | Folded out, bunks behind it count as private (sleep quality) |
| exercise_station | workout | Daily exercise logged per crew member (fitness exists); a short rhythm interaction for the player |
| integrated_mess_booth | sit for a meal, tray | Eat a meal there (food and morale); it's the "quiet meal" option |
| **Science** | | |
| science_workbench | core, ice chamber, drawer | Analyse a physical sample: grind, slide, spectrum (research and site knowledge) |
| microscope_station | look, light, drawer | The analysis step; daily discoveries become dossier highlights |
| sample_storage_cabinet | cold archive, drawers, log | Store analysed samples; the archive fills visibly; defrost when iced |
| **Hydroponics** | | |
| grow_tray | harvest, lights | Crop choice and growth stages; transplant from the seedling station |
| seedling_station | lid, light | Start seeds (the first step of each crop cycle) |
| nutrient_mixer | pump, door, valves | pH/EC dial: keep it balanced for faster growth |
| harvest_cart | drawer, unload | Carry produce to the galley (fresh food for proper meals) |
| greenhouse_planter | harvest, lights, hatch | Long crops (potatoes, tomatoes); pollinate for a boost |
| **Life support** | | |
| air_recycler | run, filter, door | Filter condition: pull, clean or replace (CO₂ and condition) |
| water_reclaimer | run, filter, hatch | Filter and perchlorate cartridge (water output) |
| oxygen_reserve_tank | valves | Emergency O₂ during a breach; refill from the generator |
| thermal_control_unit | pump, valves | Heat priority by room via the valves |
| oxygen_generator | run, door, how | Cell stack condition; swap a module |
| air_reserve_rack | valve, gauges | Refill a breached section (exists); check the pressure gauges |
| **Power** | | |
| power_distribution_panel | isolator, door, check | Breakers per room for load shedding; lockout and tag-out |
| battery_bank | charge, cell, disconnect | Battery health; swap a degraded module |
| **Storage and fabrication** | | |
| cargo_rack | retainer, case, manifest | Physical cases with contents (filters, rations); inventory |
| tool_bench | cupboards, tray, light | Clean filters and repair small parts here |
| regolith_printer | print, look | Choose a print job; layer-by-layer progress |
| spare_parts_rack | drawer, inventory | Spares stock shown on its shelves |
| **Galley** | | |
| galley_kitchenette | oven, fridge, tap | Cook a meal (a 20–30 s routine; meal quality and morale) |
| galley_bench_unit | cupboards | Utensils; set the table for a shared meal |
| galley_table_set | — | **New:** shared meals: everyone seated gives a bonus |
| galley_freezer | fridge, freezer | Frozen and fresh stores; fresh produce lasts longer when chilled |
| pantry_cabinet | open, stores | Restock rations from cargo cases (carry) |
| potable_water_dispenser | cup, filter, service | Water use is real; filter condition |
| **Hygiene** | | |
| hygiene_shower | wash, filter, hatch | Shower rota (water against morale); greywater filter |
| hygiene_toilet | lid, flush, filter | Urine processor service (water recovery) |
| **Medical** | | |
| medical_cabinet | door, drawers, supplies | Supplies as a consumable; restock from resupply |
| medical_exam_cot | light, backrest, check | Weekly medical; treat injuries here |
| iv_drip_stand | — | **New:** fluids during treatment (faster recovery) |
| crew_vitals_monitor | — | **New:** per-crew vitals, sleep debt and radiation dose |
| surgery_cart | — | **New:** serious injuries need it (open the tray, use the kit) |
| medical_exam_light | light | Exam quality (check-ups catch issues earlier) |
| **Waste** | | |
| waste_sorting_unit | compactor | Fills over sols; sort it into the hoppers |
| recycling_hopper_plastics | — | **New:** binder for the printer (print cost down) |
| recycling_hopper_metals | — | **New:** spare-part stock |
| compost_hopper | — | **New:** fertiliser for hydroponics (growth up) |
| **Mission Operations** | | |
| communications_station | uplink, module, log | Daily uplink window: sol report, messages, forecast |
| mission_planning_console | monitor, selector, drawer | Tomorrow's focus (crew time across rooms) |
| mars_survey_board | globe, map | Expedition planning: ice surveys, drive routes |
| **Airlock and corridor** | | |
| airlock_control_panel | — | **New:** cycle pressure with a gauge |
| suit_service_panel | — | **New:** suit O₂ and battery top-up before EVA |
| dust_grate | — | **New:** clean boots (less dust inside) |
| corridor_light_strip | — | Dims at night; flickers when power is low (a visual cue) |
| wayfinding_panel | screen, sign | "Where's everyone" (Phase 2) |
| utility_conduit | — | **New:** shows flow; open for inspection on a fault |
| **Vehicle bay** | | |
| rover_charger | plug, hatch, power | Charges the crew rover too |
| eva_tool_station | cabinet, case, plan | Pack the expedition kit |
| suit_rack | prepare suits, checklist | Suit readiness for EVA |
| **General** | | |
| fire_safety_station | extinguisher, first aid, checklist | A fire (from an electrical fault) needs the extinguisher |
| emergency_supply_lockbox | locker, check | Used in a breach or shelter event |
| first_aid_kit, first_aid_kit_wall | open, — | Quick treatment for minor injuries (anywhere) |
| portable_interior_work_light | light | Light a dark room during a power loss |
| supply_crate_small/medium/large | open, label | Physical contents to carry to where they belong |
| work_desk, work_desk_blank | — | **New:** paperwork (sol reports and research write-ups) |
| crew_chair | — | **New:** sit (camera lowers; rest a moment) |
| open_shelving | — | **New:** displays the rock collection, books and samples |
| plant_pot | — | **New:** water it weekly (a small morale bonus) |
| wall_whiteboard | — | **New:** write a note (like the wayfinding sign); the crew's plans appear on it |
| wall_screen | screen | Shows the comms window, the forecast and crew messages |
| retro_mars_poster | — | Morale nearby (exists); flavour text on look |
| storm_shelter_locker | doors, plan | Shelter drill: the crew move in on the warning |
| hull_patch_kit | case, drill | Find and patch a leak (§4.5) |
| wall_cabin_heater, portable_utility_heater | levels, test or filter | Heat a cold room on a bad night |
| **Odds and ends** | | |
| crew_mug | — | Appears where a crew member last sat (presence) |
| crew_tablet | — | Read the latest message from Earth |
| crew_laptop | — | Write the sol report |
| paper_books | — | Read a page (morale) |
| photo_frame | — | A crew member's family photo (their morale when near their bunk) |
| chess_set | — | A move each sol against the crew |
| zero_g_plush | squeeze | Mascot; a crew member's favourite |
| herb_pot | — | Herbs for special meals |
| desk_lamp | — | A light for late work |
| water_bottle | — | Drink (a small player tick) |
| sample_jars | — | Carry samples to the lab |
| toolbox | — | Needed for services away from the tool bench |
| ration_packs | — | Food you can carry and stock |
| guitar | strum | Play a progression; a crew member hums along at night |
| mini_gar_y | pat | GAR-Y's reaction over the radio |
| **Outside** | | |
| solar arrays | brush | Brush, check connectors after storms |
| surface_reactor | connect, hatch, log | Coolant and shield checks with a lockout |
| ice_drill | start, check | Bit wear; move to fresh ice GAR-Y found |
| regolith_intake | start | Clear jams after storms |
| comms_antenna | track, check | Realign after storms (signal meter) |
| camera_mast | look | Watch a storm come in; spot GAR-Y |
| exterior_workbench | drawer, light, box | Field repairs without coming in |
| high_light_post, path_beacon, solar_floodlight, portable_work_light | lights | Mark safe paths; fix after storms |
| safety_barrier, hazard_bollard | lamps, read | Cordon a hazard (a leak or a drill site) |
| cargo crates, equipment_pallet | open, read | Unload resupplies; carry contents |
| crew_lander | hatch, log | The lander's log tells the arrival story; emergency shelter |

## 8. What I'd build first

Ranked by aliveness per hour of work:

1. **Crew presence, Phase 1** (§3.2): mugs, curtains drawn, music, lab lights at night, intercom lines. It's cheap and the base instantly feels inhabited.
2. **Condition and services for the four life-support machines** (§3.1, §4.5): filter swaps, rough sounds, the tool bench. It creates the daily rounds.
3. **Cooking and shared meals** (§4.2), with the harvest cart carrying produce: a full loop from hydroponics to galley to morale.
4. **The daily uplink window** (§4.11): a reason to visit Mission Operations every sol.
5. **Samples to the lab** (§4.4), with the rover's expeditions (§5.2): it gives the rover and GAR-Y purpose.
6. **Waste sorting** (§4.9): it closes the loops and turns three dead items into a system.
7. **Crew figures, Phase 2:** the big one. Best done after the loops above exist, so the crew have something to *do*.

## 9. Questions for you

1. **Crew figures:** do you want visible crew at all, or keep them off-screen (presence only)? It changes the tone a lot.
2. **Maintenance pressure:** gentle (services make things better) or survival-hard (skip them and things fail)? I'd suggest gentle by default, harder in Survival.
3. **Suit oxygen outside:** a real limit, or not? It makes the rover and airlock procedures matter, but is a big change to free exploring.
4. **Missions:** should some of these become mission steps? For example, "Cook a proper meal" in Mission 8, or "Analyse a core" in Mission 2.
