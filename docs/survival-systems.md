# Survival systems rework: air, water, food, heat, radiation and the equipment behind them

A design written 1 Nov 2026, after step 5. Nothing here is built yet. §10 has the questions; §11 has the answers, which win where the text above disagrees (question 4 is still open). This plan makes the equipment matter, so the models get remade to match it, in the batches in §9.

## 1. Why

The user asked for food, water, heat and radiation to be reworked, along with "how all the equipment actually works and feeds into the survival mechanics". What's wrong today:

- **Half the equipment does nothing.** Of about 75 interior items, roughly 35 only draw power or only store something. That covers the whole galley except the stores, the toilet and shower, the seedling station, the nutrient mixer, the harvest cart, the waste sorter, the recycling and compost hoppers, the medical kit, the dust grate and the suit service panel.
- **Each resource is one pool.**
  - Water is one tank, and the reclaimer gives back 93 % of whatever the crew use.
  - Food is one pile of kilograms, whether it's an Earth ration or a lettuce.
  - Air is oxygen and CO₂.
  - Nothing is lost or gets dirty along the way, so there's no chain to follow and nothing to improve.
- **Radiation only exists during a solar storm.** There's a tiny background rate (0.3 mSv a sol), but your own dose outside isn't built (step 10).
- **Heat works, and is the model for the rest.** Each room has to get enough heat, and a cold spot shows where and why. This rework keeps it and adds insulation (§6).

## 2. Principles

1. **Every machine is one step in a chain you can see.** Each one has an input, an output and where the output goes. If a machine does nothing, either it gets a job or it becomes decor (odds and ends stay decor).
2. **Five chains, each three to five steps:** air, water, food, waste (which joins the others) and heat. Radiation is about protection, not a chain (§7). Power feeds them all (unchanged, §8).
3. **No pipes.** Resources flow through the whole base, as in Subnautica. Rooms matter only where the physics says so: heat, noise, radiation shelter, and the plants' light.
4. **Earth stores first, Mars chains later.** Chapter one already runs from stores, to ice, to water, to oxygen, to food. The rework gives each chain a **closure**: how much of what the crew use comes back. Every new machine raises closure, which is why you build it. It's also a Mission Control readout.
5. **Real numbers, rounded,** from ISS and NASA Mars planning, like the rest of the sim. The balance spreadsheet stays the source (`docs/MarsHabitat_Balance.xlsx` → `data/resources.json`).
6. **Every machine has one hands-on job** (a filter, a brine bag, harvesting a tray). That's the groundwork for step 7's wear and daily rounds, and it tells the models where the service hatch goes.
7. **Failure is gentle and named.** When a link is missing or full, the alert names it: "Grey water tank full: no water processor", not just "Water low".

## 3. Air

| Step | Machine | In → out | Hands-on job |
|---|---|---|---|
| Breathe | crew | 0.84 kg O₂ → 1.0 kg CO₂, 1.5 L water vapour each a sol | — |
| Scrub | **CO₂ scrubber** (the air recycler) | CO₂ out of the air, vented or **kept for the Sabatier**; humidity → **condensate** (to the water chain) | swap the filter bed |
| Make oxygen | **Oxygen generator** (electrolysis) | 1.1 L water → 1 kg O₂ + 0.13 kg hydrogen | — |
| Close the loop | **Sabatier reactor** (new) | CO₂ + hydrogen → water (about half what electrolysis used) + **methane** (stored as fuel) | drain the methane to the tank |
| Mars oxygen | **Atmosphere processor** (new, outside; MOXIE scaled up) | Mars air + 2.5 kW → about 1.2 kg O₂ a sol, **no water** | clear its dust intake |
| Buffer | oxygen tanks, the air reserve rack | store O₂; refill air lost to the airlock and breaches | — |

- **What changes:** the oxygen generator's hydrogen goes somewhere, the CO₂ is a resource, and the condensate carries the crew's breath back to the water chain.
- **The two ways to make oxygen** tie into the landing trade-offs. A base with ice can afford electrolysis. A dry base (the open plains) gets the atmosphere processor, at a cost in power. That makes a "thin ice" landing a different game, not just a slower one.
- **Methane** fills a tank: rover range now, and the "go home" ascent vehicle in the late game (core loop round 6).
- **Air closure** = oxygen made on Mars ÷ oxygen breathed.

## 4. Water

Two tanks instead of one: **clean water** and **grey water** (used, waiting to be cleaned). Urine is kept apart because it needs its own processor, as on the ISS.

| Step | Machine | In → out | Hands-on job |
|---|---|---|---|
| Ice | **Ice extractor** (chapter one) | ground ice → **raw meltwater** (dust and perchlorate in it) | clear the auger |
| Treat | **Water processor** (the water reclaimer, renamed) | raw meltwater, grey water and condensate → clean water (93 %, later 98 %) | change the filter |
| Urine | **Urine processor** (new; on the ISS it's the UPA) | urine → clean water (85 %) + **brine** | swap the brine bag |
| Store | potable dispenser, the General Module's rack, **water wall panels** | clean water; water walls are also radiation shielding (§7) | — |
| Use | **galley** (drinking, food), **shower and basin** (hygiene), the **toilet** | 3 L drinking and food, 5 L hygiene → grey water; 1.5 L → urine | — |
| Plants | trays | water → mostly vapour → condensate back through the scrubber | — |

- **What changes:**
  - Without a water processor, grey water piles up and clean water runs down. The tank shows it.
  - The toilet and shower are where water is used and where hygiene comes from. Without them, the crew's wellbeing drops (round 2's comfort).
  - Ice needs treating, so the chapter one ice step becomes extractor plus processor.
- **Water closure** = water coming back ÷ water used. It starts near 0 % (Earth stores only), about 75 % with a processor, 90 % with the urine processor, and 98 % with the Life team's improved filter (a discovery).

## 5. Food

Three kinds instead of one: **rations** (from Earth, dehydrated, they keep), **produce** (grown, spoils) and **meals** (cooked in the galley).

| Step | Machine | In → out | Hands-on job |
|---|---|---|---|
| Start plants | **Seedling station** | seeds + water → seedlings for the trays (without one, a tray replants itself at half speed) | thin the seedlings |
| Grow | **Grow tray**, **greenhouse planter** | light (power), water, CO₂, nutrients → a crop, ready at harvest | **harvest** (E), or the harvest cart does it |
| Feed | **Nutrient mixer** | compost + washed regolith → nutrients (without it, the Earth nutrients run out and trays grow at half rate) | top up |
| Keep | pantry, cargo racks (rations); **freezer** (produce keeps 60 sols, not 10) | — | — |
| Cook | **galley**: kitchenette or counter, oven, rehydration station | rations + water → meals; produce → meals | — |
| Eat | crew | 1.8 kg a sol each | — |

- **Crops** (each tray grows one; you pick it when you plant):
  - **greens:** fast (8 sols), few calories, big for wellbeing;
  - **potatoes:** slow (20 sols), the calories;
  - **beans or soy:** later, from the Life team.
- **Variety matters.** Eating only rations for weeks lowers wellbeing ("menu fatigue", a real NASA worry). Fresh food and cooked meals raise it.
- **Without a galley,** the crew eat rations cold. They still eat, but wellbeing suffers.
- **Rehydrating** a ration uses water: about 0.5 L per kg, from the clean tank.
- **Food closure** = produce eaten ÷ food eaten.

## 6. Waste, heat and comfort

**Waste joins the chains:**

| Machine | In → out |
|---|---|
| **Waste sorter** | everything thrown away, sorted into plastics, metals, food and plant waste, and solid waste |
| **Recycling hoppers** (plastics, metals) | packaging → **fabricator feedstock** (as the ISS Refabricator does). The ration packets help pay for chapter one's fabrication |
| **Compost hopper** | food and inedible plant waste (+ treated solids) → compost → the nutrient mixer |

**Heat** stays as it is (a habitat temperature, and enough heat reaching each room), with two changes:
- **Shielding insulates.** Regolith blocks, water walls and burying the base (the trench) cut a room's heat loss as well as its radiation. One choice now serves two needs.
- **The thermal control unit's job is its dust filter.** Spot heaters stay the backup.

**Comfort** (wellbeing, round 2) gets its inputs from the chains:
- hygiene: shower and toilet;
- variety: food;
- quiet sleep: sleeping quarters away from noisy rooms (built);
- exercise: the treadmill and the cycle ergometer, against bone and muscle loss in 0.38 g;
- plants and windows.

## 7. Radiation

- **Everyone takes a dose all the time.** It's about 0.6 mSv a sol on open ground, as Curiosity's RAD measured. Inside, the dose is cut by the room's shield rating (built: hull 5 points, regolith 8, water walls 10). It's cut to almost nothing in a cave, which is what the "steady climate underground" discovery was about.
- **You outside:** the full surface rate. The rover's cabin cuts it a little. A dosimeter on the suit HUD shows today's dose and the running total (diegetic, round 4).
- **Solar storms** (built) are the dangerous part: hours of a high rate, survived in the storm shelter.
- **What the dose does:** it adds up against a **career limit** (NASA's is 600 mSv). It doesn't hurt you on the day; it raises a health-risk figure that shows in the chapter reports and the ending (step 11).
  - Only a storm caught outside, or with no shelter, does harm on the spot, as now.
  - With the **Radiation** challenge option off, the dose is still shown but never counts.
- **Where the crew sleep matters most:** a third of the day is in bed, so shielding the sleeping quarters (water walls, regolith, or burying them) is the best use of shielding. The game says so in the Field guide and in the crew screen's dose line.

## 8. Power and the player-facing side

- **Power is unchanged** (solar following the base's skyline, batteries, the reactor, storms, load shedding by priority). The new machines take their place in the priority list:
  - life support last to switch off: scrubber, oxygen, water;
  - then heating;
  - then food: trays at night are first to go;
  - then the rest.
- **On the machines:** each machine's readout (a screen on the model, the only place text goes) shows what goes in and out now: "Water processor · 4.2 L/h · filter 63 %".
- **Mission Control** gets a **Chains** view in place of today's separate flow lines: one row per chain with its closure, its stores and the missing or overloaded link. It goes on the Monitor, as part of the M page clean-up the user asked for in step 5.
- **The Field guide** gets one card per chain, drawn as the chain.

## 9. Build order, and model batches

**Code, in phases (each playable on its own):**
1. **Stores:**
   - water into clean, grey, raw meltwater and urine;
   - food into rations, produce and meals;
   - CO₂ kept, hydrogen and methane;
   - compost and nutrients.

   Old saves load with everything in the main store.
2. **Air:** the scrubber's condensate, the Sabatier, the methane tank, the atmosphere processor.
3. **Water:** the processor and urine processor, hygiene use, the chapter one ice step needing treatment.
4. **Food:** crops, harvest, seedlings, nutrients, spoilage and the freezer, the galley's meals, variety.
5. **Waste:** the sorter, recycling into feedstock, compost.
6. **Radiation:** the background dose, your own dose outside, the career limit, the dosimeter, shielding insulating.
7. **The Chains view,** machine readouts and Field guide cards. Rebalance in the spreadsheet; the chapter one and samples tests extended.

**Models, in batches** (once the mechanics are settled; house style, MHPalette, no lettering). Each machine model shows its **inputs and outputs** (ports, tanks, a window on the tank), a **readout screen**, and its **service hatch**:
- **Air:** CO₂ scrubber, oxygen generator (built: check it has the ports), Sabatier reactor, methane tank, atmosphere processor (outside), oxygen tanks.
- **Water:**
  - indoors: water processor, urine processor, clean and grey tanks, potable dispenser, water wall panel;
  - outside: the ice extractor.
- **Food:** grow tray with crop variants (greens, potatoes; growth stages), seedling station, nutrient mixer, harvest cart, freezer, pantry, galley set.
- **Waste and hygiene:** toilet, shower and basin, waste sorter, the three hoppers.
- **Heat and radiation:** thermal control unit (with a filter hatch), heaters, storm shelter, shield blocks, the suit's dosimeter.
- **Step 5's kit:** sample case, scoop, cabinet jars, notebook, chip scar.

**Duplicates to settle when modelling:**
- grow tray vs greenhouse planter: small and large;
- galley counter vs kitchenette: one is the General Module's;
- the supply crates and cargo crates: one set.

## 10. Questions to answer before building

1. **Depth:** is three to five steps a chain, with no pipes, right? *Recommended.* The alternatives are lighter (give every item an effect but keep one pool each) or deeper (pipes or ducts between rooms).
2. **Crops:** two crops now (greens and potatoes), with more from discoveries, and variety counting? *Recommended.* The alternative is one generic "produce".
3. **Sabatier and methane:** include them, with the methane as rover fuel now and ascent fuel later? *Recommended.*
4. **The atmosphere processor** as the oxygen path for dry bases? *Recommended.* It ties into the landing trade-offs.
5. **Radiation:** a running dose against a career limit that affects health risk and the ending, rather than direct harm? *Recommended.* Only storms harm on the spot.
6. **Food spoilage:** produce keeps 10 sols, or 60 in a freezer? *Recommended, mild.* Or no spoilage.
7. **Hygiene as a need:** the toilet and shower matter for wellbeing and use water? *Recommended.*
8. **Where it shows:** a Chains view on the Monitor, plus readouts on the machines? *Recommended.* This is also the first step of the M page clean-up.

## 11. Answers (1 Nov 2026)

1. **Depth:** three to five steps a chain, no pipes.
2. **Crops:** greens and potatoes now, more from discoveries; variety counts.
3. **Sabatier and methane:** methane goes with Mars oxygen into an **ascent propellant tank** that fills towards "go home". The rover stays on batteries, as in NASA's Mars studies, where crew rovers are electric. A methane–oxygen **fuel-cell range extender** may come later as a long-range upgrade (core loop step 9), not in this rework.
4. **The atmosphere processor:** unlocked by a discovery; **still to discuss** (user) whether its oxygen is breathed or is ascent propellant only.
   - **Background:** MOXIE on Perseverance made about 122 g of oxygen in 2021–23 at over 98 % purity. A scaled-up version is NASA's plan for ascent oxygen.
   - **Radiation:** the gas isn't made radioactive (oxygen-16 is stable).
   - **Purity:** the real concern is the carbon monoxide the process also makes.
5. **Radiation:** a running dose against a 600 mSv career limit, raising a health-risk figure for the reports and the ending; only solar storms harm on the spot.
6. **Spoilage:** produce keeps 10 sols, 60 in a freezer; rations keep.
7. **Hygiene** is a need: the toilet and shower use water and keep wellbeing up.
8. **Display:** a Chains view on the Monitor and a readout on each machine. This is the first step of the M page clean-up.

## 12. Three more decisions (1 Nov 2026)

### 12.1 A chain with missing parts leaks; it doesn't stop

*Overrides anything above that says a chain stops without a part.* Like rain that never evaporates: the water doesn't vanish, it pools somewhere you can see.

- **One core part per chain does the whole job by itself, wastefully.**
  - **Water:** the ice extractor alone gives clean water. Used water goes to the grey tank, and when that's full it is **vented outside and lost**.
  - **Air:** the oxygen maker alone keeps the crew breathing, using stored water and dumping carbon dioxide outside.
  - **Food:** rations alone keep the crew fed.
- **Each extra part closes some of the leak.**
  - **Water:** the water processor recovers most grey water, and the urine processor most of the rest, so less ice is needed each sol.
  - **Every chain** shows a **closure %** on the Chains view. The ISS's water loop reaches about 98 % with every part fitted.
- **A missing part always shows as a store filling or emptying, with a named alert** ("Grey water venting: no water processor"). It also offers a stopgap: a job done by hand, or Earth's stores to fall back on.
- **Only a missing core part is an emergency,** with warning before it bites.

One part means you get by on reserves and a lot of ice; every part means you could live there indefinitely.

### 12.2 Getting ready for more crew

- **Load per person:** each person adds a fixed daily load to every chain. Machines have a top rate, so a base sized for one won't carry six; that needs second units or bigger models.
- **Ready for N:** the Chains view gives each chain's crew capacity ("Water: enough for 2"). The base is ready for as many crew as its weakest chain can support. That number is the goal for the next-crew chapter (core loop round 1).
- **A test run:** before the next lander, Mission Control asks you to run the base at the larger crew's load for a few sols. It's simulated, so weak links show before people depend on them.
- **The arrival checklist:**
  - beds;
  - a landing pad;
  - stores to cover the trip.

  The new crew bring jobs you can hand out. The two-person rule for EVAs returns (core loop round 6, item 10).

### 12.3 Whose goals: NASA's, on purpose

- **Discoveries:** the four sections (Life, Climate, Geology, Humans) are the four science goals of NASA's Mars Exploration Program, as set by its science advisory group (MEPAG).
- **The Humans goal** ("prepare for human exploration") is mostly this rework:
  - oxygen and water from Mars;
  - power;
  - radiation;
  - crew health.
- **NASA's Moon-to-Mars objectives:** several are already in the plan:
  - local resources;
  - storing ascent fuel (the Sabatier ascent tank);
  - crew health;
  - more crew later.
- **Left out:** the transport engineering (launch and landing systems), which doesn't make gameplay.
