# Systems and items: every mechanic, room and piece of kit

*Started 3 Nov 2026, as a companion to `docs/master-design.md`. **Status: proposed.** Each section is settled with the user one round at a time, and marked **Decided** once it is. When a decision here disagrees with `docs/resource-model.md` or `docs/survival-systems.md`, this doc wins.*

**What this is for:** a complete design brief, so that once it's built, a single Survival run lets you try every pillar: surviving, exploring, discovering, designing and building, and the story (§13).

**Ground rules (decided 3 Nov):**
- **Clean sheet first.** Design what the player needs, then map today's items onto it (§11).
- **Numbers are real-based but tuned for play.** Start from NASA and ISS figures, round them, and bend them for pacing. All of them live in one balance source (§12), each with a "real figure" column beside the "game figure".
- **A lean core of about 30–40 working items.** Add more only when play shows a gap.
- **Connections are automatic inside the habitat and laid outside.** Outdoor machines and outposts need a cable or heated pipe that you lay once.
- **Show, don't tell.** No walls of bars and numbers. State is seen in the world and felt on your body (§2).
- **One body: yours.** While you're alone, the habitat's conditions act on you (§2).

---

## 1. The systems

Each system has stores (what's kept), flows (what goes in and out each sol), how it fails, and how you notice it. A missing part makes a system leak, not stop (survival-systems §12.1). Each one is introduced at a set point in the opening (master-design §6).

### 1.1 Power *(introduced: night 1)* · **Decided 3 Nov: tight early, eases later**
- **Stores:** the battery banks.
- **Flows:**
  - **Sources:** solar arrays (real Mars peak is about 0.5 kW per m²; dust and the sun's angle cut it); the compact reactor, late (10 kW, like NASA's Kilopower).
  - **Loads,** shed lowest priority first: life support, then heat, then lights, then everything else.
- **Inside** the habitat, everything connects automatically. **Outside,** each machine or outpost needs a laid cable (§9.1).
- **Fails as:** a slow brown-out (lights dim, fans slow) rather than a sudden cut. Life support is the last load to go.
- **Decided:** power is tight in the first nights (choose what stays on: heat, the recycler, the printer) and eases with more arrays, then the reactor.
- **Numbers:** solar array 2.5 kW at peak, about 10 kWh a sol in clear air; battery bank 25 kWh. Today's values are 10 kW and 50 kWh, which is too generous for an opening where power should be tight.

### 1.2 Heat *(night 1)* · **Decided 3 Nov: felt first, harmful if ignored**
- **Stores:** one habitat temperature, plus cold spots in rooms the heat doesn't reach.
- **Flows:** heat is lost through the hull (more through windows; shielding insulates). It's gained from your body, machines, lights, spot heaters and the Thermal Control Unit (a heat pump that warms every heated room).
- **The lander kit has a portable heater,** so the first night is survivable but uncomfortable.
- **Fails as:** a slow chill. You see frost and your breath, and feel it on your body (§2). Cold slows and blurs you first; only long, deep cold costs health.

### 1.3 Air *(hour 1)* · **Decided 3 Nov: chain as below**
- **Stores:** cabin O₂ and CO₂, and the O₂ reserve tank.
- **Flows:**
  - **You use** about 0.84 kg of O₂ a sol and breathe out about 1.0 kg of CO₂ (NASA's figures).
  - **The air recycler** scrubs CO₂.
  - **The oxygen generator** splits water to make O₂ (about 1.1 L of water per kg of O₂).
  - **Later:** the Sabatier reactor (CO₂ + H₂ → water + methane, which also fills the ascent tank) and the atmosphere processor (O₂ from Mars air, about 1.2 kg a sol for 2.5 kW).
- **The cabin's air lasts about a sol,** then the life-support pallet takes over.
- **Fails as:** CO₂ creeping up (a headache, heavy breathing), then O₂ falling (your vision greys at the edges).

### 1.4 Water *(sols 2–5)* · **Decided 3 Nov**
- **Stores:** clean water, grey water, a raw tank for melt, and the lander's tank at first.
- **Flows:**
  - **You use** about 3 L a sol to drink and cook, plus 4 L if you wash. Washing lifts wellbeing; skipping it never harms you. The lander's tank lasts until about sol 3–5.
  - **The ice extractor** melts ice into the raw tank. It needs a laid heated pipe home, or an outpost tank you visit (§9.1).
  - **The water processor** cleans grey water back (the ISS recovers about 93–98 %).
  - **The urine processor** comes later and closes most of the rest.
- **Far ice:** an outpost with its own big tank. The scout rover carries a tank home now and then, until you pipe it or build closer. The tank lasts many sols, so it's never a hauling loop.
- **Fails as:** stores running down, then thirst felt on your body.

### 1.5 Food *(weeks)* · **Decided 3 Nov**
- **Stores:** rations (found in pallets, visible on the pantry shelves) and fresh produce.
- **Flows:**
  - **You eat** about 1.8 kg a sol (packaged; real is about 1.8 kg with packaging).
  - **Crops:** greens in about 8 sols, potatoes in about 20.
  - **Nutrients** come from the compost loop later.
  - **Spoilage:** produce keeps 10 sols, 60 in a freezer.
- **Eating is by hand:** press E at the galley for a meal. Cooking is automatic, with no recipes.
- **Growing starts** once the greenhouse kit is found and regolith has been washed of perchlorate.
- **Fails as:** a slow hunger. It's never sudden.

### 1.6 Your body *(always)* · **Decided 3 Nov**
- **Five survival needs:** air, warmth, water, food and sleep. Each is felt on your body (§2). Going short of one long enough costs **health**, the one health track.
- **Sleep is yours.**
  - Sleeping in a bunk skips the night. You wake at dawn, or earlier if an alert sounds.
  - Tiredness builds through the sol: blinks, yawns, a drifting view. Very tired slows you, and you can doze off in the field.
  - Sleep is poor in the General Module (noise), good in Quarters and fair in the HabRover.
- **At zero health you collapse.** GAR-Y gets you to safety (before you've met it, you crawl back to the cabin). You wake hours later, weak, with the problem still there. It costs time, never the save.
- **Exercise is an optional boost,** never a decline you must fight: a session leaves you walking faster and carrying more for the sol.
- **Wellbeing** is lifted by washing, fresh food, comfort, personal items, a window and contact with Earth. Low wellbeing slows your work; it never harms you.
- **Injuries** are an optional challenge, treated with the medical kit.
- **The crew (finale):** there are no mid-game crew waves. The orbiter crew land only in the welcome ending (§10e), and after that they get their own simple shared track.

### 1.7 Suit and EVA *(hour 1)*
- **Keep:** the suit's O₂, power and scrubber, the wrist pad, the GAR-Y rescue, leaks and patching, and refills at the airlock, lander and rover.
- **Re-tune:** suit time has to fit real minutes (§8). Today the suit's "2 hours" is about 2 real minutes of daylight.
- **The suit protects you only while it's sealed.** Indoors with the helmet off, the habitat's air is what you breathe.

### 1.8 Radiation *(the whole run)*
- **Keep** a running dose, kept down by shelter and shielding, with solar events as the only spikes. A radiation monitor (§5) gives warning of them.
- **Simplify:** one dosimeter (yours), with the health-risk figure kept for reports.

### 1.9 Wear and spares *(later)*
- **One failure path:** wear. A machine wears while it runs, sounds and looks it, loses output past about 70 %, and fails if left fully worn.
- **Rare surprises** (a breakdown, a breach, a solar event) follow the surprises setting.
- **One generic spares kit,** made at the Engineering Bench from iron and salvage.
- **No routine upkeep (7 Nov):** no filter swaps, no topping up tanks by hand. Machines just run; wear is the only upkeep, and it's rare and heard before it's seen.

### 1.10 Storms and weather *(after sol 15)*
- **Keep** the forecast storms, dust on the panels and frost.
- **Dusting the panels** is needed only after a dust storm, as one hands-on job; the dust monitor tells you when (7 Nov). It's never a daily chore.
- **Forecasts start short and get better** once weather stations are out (§5).
- **Fixed 7 Nov:** forecast storms no longer stall during a research boost.

### 1.11 Materials and making · **Decided 3 Nov**
- **Iron-rich rock (haematite):**
  - **Early:** chipped by hand into bags at outcrops you've found, a few kilograms a trip.
  - **Later:** a small miner at a good outcrop, cabled to power, fills a hopper. GAR-Y collects from it on its own rounds, so the repeated carrying is GAR-Y's, never yours.
- **The makers:**
  - **Print Shop:** prints equipment and kit, and takes haematite directly (the smelter is merged in);
  - **Regolith Printer:** builds room shells, berms, pads and shielding from regolith, slowly, outdoors;
  - **Engineering Bench:** repairs, spares kits, studying damaged units, scrapping wrecks for salvage.
- **Salvage never runs out:**
  - pallets, and wrecks scrapped at the bench;
  - **storm debris scattered across the land:** backshell fragments, heat-shield pieces, parachute lines, broken cargo. Each dust storm uncovers and scatters fresh debris, so there's always something to find;
  - the Recycler's trickle;
  - **Earth resupplies every 20–30 sols** once the link is fixed. Each brings salvage, a few wellbeing items and sometimes a plan.

### 1.12 Recycling *(later: "closing the loop")* · **Decided 3 Nov: one Recycler**
With feedstock gone, recycling needs a new job. **Proposal:** one Recycler takes packaging and trash and gives back small amounts of iron (metals) and salvage-grade polymer, so Earth's packaging becomes a slow trickle of materials. Compost feeds the nutrient mixer. 

---

## 2. One body, and show-don't-tell

**Why the habitat's warnings never touched you:** its conditions acted on `crew_health`, an abstract crew number (`habitat_sim.gd:896-914`). Your own body only ran through the suit, which counted the habitat as breathable down to 17 % O₂ (`suit.gd:152`).

**The fix:** while you're alone, **the habitat acts on you**.

| State | What you see, hear and feel |
|---|---|
| Cold | frost creeping on windows, your breath visible indoors, shivering hands, a duller and quieter room |
| Low power | lights dimming and flickering, fans winding down, a sudden silence |
| Stale air (CO₂) | a slow headache vignette, heavier breathing |
| Low O₂ | grey edges to your vision |
| Thirst, hunger | slower hands, a lazier camera |
| Tired | blinks, yawns, a slightly drifting view |
| Store levels | sight-glasses and gauges on the tanks, rations on the pantry shelves, battery LEDs on the cabinet |
| Machine wear | its sound changes, it rattles, a lamp glows on it |
| Suit | visor fog, LEDs, breathing sounds, frost on the visor; the wrist pad shows icons, not numbers |

**The slate's Base app** becomes a picture of the base: rooms tinted by state, with icons for problems. Exact numbers are one tap deeper.

**The base at a glance · Decided 7 Nov.** A playtester liked seeing the warning icons and the old overview, because they always knew how the base was doing. So show-don't-tell never hides state:
- **The warning icon row stays on the HUD,** always on while the slate is down (N opens the most serious one). The storm pill stays too.
- **M raises the slate on Base,** the overview: the picture of the base, the stores as gauges and what to fix first. It's built properly with the new sim (§14 step 1 on). Comms keeps its own tab.
- The body cues above add to the readout; they never replace it.

---

## 3. Rooms and building · **Decided 3 Nov**

**How the habitat grows.**
- **Earth's fixed first module** (the General Module) arrives on a carrier.
- **After that, you draw rooms** in the Plan view as now. The **regolith printer**, a tracked crawler robot, rolls up and prints each shell layer by layer while you watch, in about **20–40 real seconds a cell**.
- **Equipment unfolds into place** on the spot.
- **What gates you is materials and plans, never waiting** (Schell's Lens of the Toy and Lens of Juiciness: building should be fun to play with and give feedback straight away). *In reserve, if it doesn't feel good:* instant placement with a short effect.

**More than one habitat.** You can build anywhere you've explored: at far ice, a cave mouth, the lava tube. Each habitat has its own airlock and is joined to the others by laid cables and pipes. By Schell's Lens of Elegance this serves many purposes at once: a forward base, a storm refuge, water at far ice, a bed in the field, and pride in how far your foothold spreads. It opens up gradually, because it needs the crawler, iron and salvage.

**Why specialise rooms:** each room speeds up and quietens its own work (the Lab analyses about 1.5× faster, Quarters give full sleep, the Workshop prints faster). Some kit only fits its own room (the microscope, the freezer, big planters). And noisy rooms next to Quarters spoil sleep.

| Room | Its jobs | Fed by finds | Noise |
|---|---|---|---|
| **General Module** (Earth's first) | everything basic fits; cramped: poor sleep, slow work | everything, slowly | noisy |
| **Quarters** | good sleep, personal items | personal items | quiet |
| **Day Room** (galley and hygiene) | meals, washing, comfort | rations, produce, comfort items | lively |
| **Life Support & Power** | room for more machines, away from sleep | ice and water | noisy |
| **Workshop** | Print Shop (takes haematite), Engineering Bench, regolith printer's dock | haematite, salvage, damaged kit | noisy |
| **Lab** (with comms and operations) | analysis, the comms rack, the operations desk | rocks, regolith, cores, instrument data | quiet |
| **Greenhouse** | food, O₂, a bit of home | washed regolith, compost | quiet |
| **Medical Bay** | heals injuries faster; the solar-event shelter (most shielded); a look players love. First-aid kits work anywhere. | | quiet |
| **Storage** | holds stock; shows it (piles of iron, salvage crates, rations); keeps materials and spares out of the dust | everything you bring back | quiet |
| **Airlock** | the way out; suit service | | |
| **Vehicle Bay** | the scout rover, later the HabRover | | noisy |

Each room is kept only because it does several jobs (Schell's Lens of Elegance), and the lovable ones keep their character (Lens of Character).

---

## 4. Field kit (carried) · **Decided 3 Nov: 4 slots, growing with upgrades**

You choose a **loadout from the suit rack** before going out. You start with **4 slots** (belt and pack). A better suit pack and the rover's lockers add more, so early trips mean real choices.

| Kit | Use | Today |
|---|---|---|
| Hand corer | ice and deeper samples | exists (`hand_corer.gd`) |
| Scoop | regolith | exists (`sample_tools.gd`) |
| Rock hammer | rock chips | chipping exists, without a tool |
| Sample case | six slots | exists |
| Spare O₂ bottle | more time out | new |
| Patch kit | suit leaks | exists as an action |
| Headlamp | caves | new |
| Marker beacons | your own pins in the world | new |
| Field spectrometer (like Perseverance's PIXL) | names a mineral on the spot, at the cost of a slot | new |
| A deployable instrument | §5 | new |

---

## 5. Deployable instruments (outdoor science) · **Decided 3 Nov**

Placed in the field, these gather data over sols. Each one pays back into **discovery** and into **survival**, and each gives a reason to take a risk.
- **Placement matters:** a better spot (high ground, away from the base's dust and noise, the edge of a crater) gives better data, which gives a reason to go somewhere.
- **Where they come from:** the weather station is in an early pallet (it's on the mission manifest). The others are found or printed later.
- **Reading the data:** it comes in over sols, read at the Lab, or on the slate once the link is fixed.

| Instrument | Real basis | Discovery | Survival payback | The risk it rewards |
|---|---|---|---|---|
| **Weather station** | Perseverance's MEDA | Climate | Storm forecasts get longer and more reliable | the best spots are exposed high ground |
| **Seismometer** | InSight | Geology | Hints of lava tubes and buried ice | quiet ground far from the base |
| **Radiation monitor** | Curiosity's RAD | Humans | Warning before solar events | |
| **Dust monitor** | | Climate | Tells you when the panels need cleaning | |
| **Scout helicopter** | Ingenuity | Geology, places | Flies ahead and fills in the map from the air, shows the way to pallets and landmarks | thin air and wind: it can crash far away, and you go and fetch it |
| **Methane sniffer** | Curiosity's methane readings | Life (the wonder thread) | Points to where something is breathing out methane. It only reads at night and dawn, at certain places | being out in the cold at night |
| **Ground radar sled** | Perseverance's RIMFAX | Geology | Towed behind the rover, it maps buried ice and layers along the route | long drives |
| **Heat-flow probe** | InSight's "mole" | Geology | Finds warmer ground: thinner ice, cave air | a sol of hammering in one spot |

## 6. Finds go somewhere: the processing rule

Every kind of find has a machine that turns it into something, and every working room has at least one machine fed by what you bring back.

| Find | Where it goes | What it gives |
|---|---|---|
| Rock chips, regolith | Lab bench (a microscope speeds it up) | discoveries |
| Ice core | Lab | purity and age; the first good core earns the extractor plan |
| Haematite | Workshop smelter | iron |
| Salvage, damaged kit | Engineering Bench | parts; studying a unit learns its plan |
| Instrument data | Lab and comms | forecasts, discoveries |
| Organics (the wonder thread) | Lab | the big find |
| Personal items | Quarters, Day Room | wellbeing |


## 6b. Discoveries · **Decided 3 Nov: about 45, and the big ones are earned**

Discoveries are the reason to survive. Today there are 29 (`data/discoveries.json`), mostly rocks, ice and caves. These grow to **about 45**, in five strands. Every discovery pays off with at least one of: a plan, a journal page with your photo, or a step in a story thread. Every answer raises a new question (Schell's Lens of Curiosity), so there's always another one to chase.

| Strand | Examples | Pays off with |
|---|---|---|
| **Rock and ground** (today's set, kept) | basalt, olivine, haematite, gypsum, river conglomerate, lakebed mudstone, clay, sulfur, iron meteorite, impact breccia | the smelter, shielding, glass and other plans |
| **Water and ice** | ground ice, an ice scarp, ice from an older climate, dust layers in the ice, brines in the soil | the extractor and the water processor; where outposts can go |
| **Sky and climate** (new, from instruments) | dust devils, morning CO₂ frost, water-ice clouds, Mars's real aurora, the blue sunset, a meteor, Phobos crossing the Sun | longer storm forecasts, solar event warnings |
| **Deep ground** (new) | marsquakes, buried ice, heat from below, the lava tube | outposts, the lava tube as a safe refuge |
| **The life thread** (far ring) | lakebed mudstone, then organics, then layered mats, then a strong sign of ancient microbes | the game's biggest moment (master-design §7) |

**How you earn them: the payoffs are varied, not just pick-up-and-analyse.** Of the 45, roughly:
- **About 15 are simple:** pick it up or core it, then analyse it in the Lab. These teach the loop and keep the journal growing.
- **About 15 take several steps across sols.** For example:
  - set a seismometer, feel marsquakes, then place a second one to work out where they come from, which leads you to the lava tube;
  - core an ice scarp, then core deeper with a stacked corer, to read the old climate in its layers;
  - follow the old riverbed ridges to the delta, then to the lakebed, then core the mudstone.
- **About 10 are high risk.** They need a good plan and a full suit, and they can go wrong. For example:
  - climb down a skylight into the lava tube on a winch line;
  - chip a sample from a crumbling ice cliff;
  - cross the dune sea in the rover;
  - reach an iron meteorite far out before night falls;
  - sample fresh deposits at the edge of a dust storm;
  - stay out through a solar event to read the radiation spike.
- **About 5 depend on timing or are rare:**
  - be outside, in the right place, for the aurora (at night, in the cold);
  - Phobos crossing the Sun at a forecast time;
  - a meteor;
  - the first blue sunset;
  - dawn frost before the Sun burns it off.

The biggest finds sit at the end of the hardest chains. The life thread needs multi-step and high-risk work in the far ring, so the reward matches the danger (Schell's Lens of Reward, the second pillar "Mars will kill you for it").

### 6c. All 45 discoveries · **Decided 3 Nov**

Place numbers refer to the map (§9.3). 29 are today's (kept, some reworked); 16 are new. **Tally:** 15 simple, 15 multi-step, 10 high risk, 5 timed or rare.

| Discovery | Kind | Where (place #) | How you earn it | Pays off |
|---|---|---|---|---|
| Basalt bedrock | Simple | 3 | chip it with the hammer; analyse in the Lab | the regolith printer's shell recipe (journal) |
| Dust-coated rock | Simple | 3 | scoop the dust off a boulder; analyse | journal; the dust monitor plan |
| Iron-oxide dust | Simple | 1 | scoop the plain; analyse | journal: why Mars is red |
| Olivine | Simple | 9 | scoop the dune sand's edge; analyse | journal: the rock is barely weathered, so it has been dry for ages |
| Perchlorate in the soil | Simple | 1, 5 | scoop; analyse | warning: wash soil before growing; the soil washer plan |
| Water bound in the soil | Simple | 5 | scoop; bake it in the Lab | a little water from regolith (slow) |
| Haematite concretions | Simple | 15 | pick up the 'blueberries' | the Print Shop's iron recipe; the miner plan later |
| Sandstone layers | Simple | 10 | chip at the foot of a mesa | journal; points to the mesa tops |
| Impact breccia | Simple | 4 | chip the crater's ejecta | journal: how impacts dig up the deep |
| Gypsum veins | Simple | 16 | chip a white vein | journal: water once flowed through cracks |
| Salt crust | Simple | 16 | scoop the pan's crust | warning plus the brine question (leads on to brines) |
| River conglomerate | Simple | 7 | chip pebbles from a ridge | story: a real river ran here; leads to the delta |
| Water ice in the ground | Simple | 4, 5 | core the Little Bowl wall or the hollow | the ice extractor plan |
| The air outside | Simple | 1 | take an air sample with the case | journal; leads to the atmosphere processor |
| Vesicular basalt | Simple | 20 | chip a bubbly rock at the lava plain's edge | journal: gas bubbles in old lava; leads to the tubes |
| Water from Mars ice | Multi-step | base | extract ice, then run it through the water processor | drinkable local water |
| Oxygen from Mars water | Multi-step | base | feed your water to the oxygen generator | local oxygen |
| Washed soil grows plants | Multi-step | base | wash regolith, plant it, grow a first crop | the planter's soil recipe |
| Dust layers in the ice | Multi-step | 11 | core the scarp, then study the core under the microscope | storm history; longer storm forecasts |
| Layered sediments | Multi-step | 10, 18 | sample three layers at different heights on a mesa, then on the mound | story: the climate changed over time |
| Clay-rich rock | Multi-step | 18 | radar the mound's lower slopes, then core where it points | journal: long-lasting water; the life thread's next clue |
| Lakebed mudstone | Multi-step | 7, 19 | follow the ridges to the delta, then core the lakebed | the life thread starts |
| **New:** Marsquakes | Multi-step | 12 | set a seismometer on firm ground and wait several sols | journal; quake warnings; leads on |
| **New:** The lava tube | Multi-step | 12, 20, 21 | place a second seismometer to work out where the quakes echo from | the tube's location on your map |
| **New:** Buried glacier | Multi-step | 23 | drag the radar sled across the apron | a far ice source that never runs out; outpost site |
| **New:** Heat from below | Multi-step | 22 | hammer in the heat-flow probe and read it over sols | journal: Mars is still warm inside |
| **New:** Brines | Multi-step | 16 | run the weather station by the pan, then sample at dawn when humidity peaks | journal: liquid water for minutes a day |
| **New:** Organics in the mudstone | Multi-step | 19 | core fresh mudstone and analyse with the microscope | story: the life thread's middle |
| **New:** Dust devils | Multi-step | 8 | the weather station logs pressure dips; then photograph one passing | journal; the solar panels clean themselves a little |
| **New:** Water-ice clouds | Multi-step | 1 | the weather station's sky sensor over several dawns | journal; the first frost forecast |
| Ice from an older climate | High risk | 11 | chip the crumbling scarp face; falls and slides are possible | story; the outpost's tank plan |
| Ice in the caves | High risk | 13 | go deep in a canyon cave by headlamp, in the cold | a hidden ice source |
| Mineral crust in the caves | High risk | 13 | reach the back of the deepest cave | journal; hints at the lava tube's chemistry |
| A steady climate underground | High risk | 21 | winch down a skylight into the lava tube and set a weather station inside | the lava tube refuge (storms and solar events) |
| Pure sulfur | High risk | 18 | climb the mound's steep upper slopes | journal; sulfur for the Print Shop |
| Iron meteorite | High risk | 24 | find one far out and get it home before night | metal for the Print Shop; journal |
| Unweathered basalt | High risk | 20 | drive deep into the lava plain; the rough ground wears the rover | journal: recent volcanism |
| **New:** A solar event, measured | High risk | anywhere | stay out during a solar event with the radiation monitor running | longer solar warnings; a better Medical Bay shelter |
| **New:** Leopard-spot rock | High risk | 19 | cross the crater floor to the far lakebed edge and core it | story: textures that microbes might have made (Perseverance's Cheyava Falls) |
| **New:** Signs of ancient life | High risk | 19, 21 | bring the finest mudstone core and lava tube samples together in the Lab, then send it all to Earth | the game's biggest moment; the endings open |
| **New:** Morning CO2 frost | Timed or rare | 5 | be at the hollow at dawn, before the Sun burns it off | journal photo |
| **New:** Mars's aurora | Timed or rare | any, at night | be outside, away from the base lights, on a night after a solar event | journal photo; the cast's reaction |
| **New:** The blue sunset | Timed or rare | any high point | watch a sunset from a ridge or mesa top | journal photo |
| **New:** A meteor | Timed or rare | any, at night | be outside on a clear night; rare | journal photo |
| **New:** Phobos crossing the Sun | Timed or rare | the forecast spot | be where the forecast says, at the right time | journal photo; a nod to Perseverance's film of it |

---

## 7. Vehicles and machines

- **Scout rover** (early, from a pallet): quick, one seat, little cargo, for short trips and finding pallets. Today's crew rover becomes this.
- **HabRover** (later, from a large pallet or from Earth): big, slow and pressurised. You can take the suit off, sleep, eat, run quick sample checks and recharge suits, and spend 1–3 sols in the field. It opens the far sites.
- **GAR-Y:** companion, radar survey, rescue, and the sled for small loads.
- **Walking carriers:** they bring the big pallets home once repaired.

Steep ground and caves are reached on foot, by design.

---

## 8. Time and day/night · **Decided 3 Nov**

- **A sol is 30 real minutes: about 22 of daylight and 8 of night.** Today it's 20 (15 day, 5 night). Schell's Lens of Time and Interest Curve: each sol needs room for one trip out (the peak, about 10–12 real minutes) plus base work (the rest, about 6–8).
- **The suit holds a realistic 8 game hours,** about 10 real minutes outside in daylight. More with a spare bottle or upgrades.
- **Sleeping skips the night.** You wake at dawn, or earlier for an alert.
- **Nights are for being inside:** cold and dark, no solar, so power is tight, and going out drains the suit faster. That's when you work in the Lab, the Print Shop and the journal, eat, and fit out rooms.
- **A few night lures** tempt a short, risky trip: dawn frost on ice patches, and the methane sniffer.

### 8.1 Work around the base · **Decided 3 Nov**

Nights and storms keep you inside, so there's always hands-on work. None of it is reading a menu, and most of it is fed by what you bring home (§6).
- **Inside:**
  - the Lab: analyse the day's samples;
  - the Bench: study damaged kit, repair, make spares, take salvage apart;
  - the Print Shop: pick a plan and watch it print (it draws iron from your stores, which you see on the shelves);
  - the Greenhouse: plant, tend and harvest;
  - the Galley, the shower and exercise;
  - plan new rooms and fit them out;
  - the journal: photos and finds;
  - the radio: talk to the orbiter crew.
- **Just outside, by day:**
  - after a dust storm, brush the panels clean;
  - patch a cable or thaw a pipe;
  - set up an instrument and read its data;
  - watch the printer raise a room;
  - pile up a regolith berm.
- **GAR-Y takes over some chores** as it's upgraded (§10c), so you can go further.

## 9. The outside

### 9.1 Cables, pipes and outposts
**Decided 3 Nov: you plan the route, GAR-Y lays it.**
- **Planning:** in the Build app's Look view, click the two ends and GAR-Y suggests a route (7 Nov). Add bends yourself when the path matters, as with corridors.
- **Laying:** GAR-Y drives the route and lays it over time while you get on with other things. You can lay a short run yourself by hand, for when it's urgent.
- **Cable:** laid point to point. It costs iron per metre.
- **Heated pipe:** laid point to point. It costs iron per metre and draws power per metre to keep the water from freezing, so it suits near ice.
- **Outpost:** a shelter, an extractor, a tank and solar, built at far ice or a far site. It runs itself once built: you go back for a storm, a fault or a find nearby, never to service it (7 Nov).

### 9.2 The world · **Decided 3 Nov**

**Size: grow from 6 × 6 km to about 12 × 12 km,** in three rings around the landing:

| Ring | Distance | How you get there | What's there |
|---|---|---|---|
| **Near** | within about 1.5 km | on foot | the first pallets, life support, the first parachutes |
| **Middle** | 1.5–3 km | scout rover | most pallets, ice patches, the first caves |
| **Far** | beyond 3 km | HabRover, overnight | the lava tube, the ancient lakebed, the wonder thread's sites |

**The land keeps every natural feature it has now:** caves, canyons, mesas, dunes, craters, hills, mountains, ledges. Its landmarks are **based on real places**, in keeping with the region's name, Aeolis Reach:
- **Aeolis Dorsa:** inverted river channels (old riverbeds now standing as ridges). This is the ancient-water clue that leads towards the lakebed.
- **Medusae Fossae:** yardangs, wind-carved ridges in long rows. A good landmark field.
- **Gale crater and Aeolis Mons (Mount Sharp):** a crater rim and a tall layered mound. The far landmark you can see from anywhere.
- **Elysium's lava plains:** a dark lava field with pits and skylights into lava tubes.
- **Exposed ice scarps, like those mapped by HiRISE in the mid-latitudes:** bright cliffs of buried ice. *Game licence:* real ones sit further from the equator.

**The edge:** the region sits in a basin ringed by highlands and crater walls too steep to climb or drive, with dust haze beyond. A few passes are blocked for now (a landslide, ground too steep for the rover) and can open in later updates.

**How the land pulls you outward, without telling you:**
- parachutes on ridges near the start, with the first pallet in view of your hatch;
- landmarks you can see from far away (the layered mound, a crater rim, the dark lava field);
- ground that slopes gently down towards the interesting middle ring.

**Density · Decided 3 Nov: a find every few minutes.** About 25 named places, plus small finds scattered between them. Never more than about 2 minutes on foot, or about 1 minute in the rover, without something worth stopping for.
- **Near ring (on foot):**
  - the landing plain;
  - parachutes on ridges;
  - boulder fields;
  - a small cave;
  - a fresh crater;
  - the first ice under dust.
- **Middle ring (scout rover):**
  - the old riverbed ridges;
  - the yardang field;
  - the dune sea;
  - mesas with ramps;
  - ice scarp cliffs;
  - wrinkle ridges;
  - more caves;
  - a broken-up lander wreck.
- **Far ring (HabRover):**
  - the big crater and its layered mound;
  - the dark lava plain, with skylights into the lava tube;
  - the ancient lakebed;
  - chaos terrain;
  - the highland walls.
- **Between places:**
  - haematite outcrops;
  - meteorites;
  - salvage from the storm;
  - dust-devil tracks;
  - morning frost in the hollows.
- **A living land:**
  - dust devils that move across it;
  - haze;
  - light and shadow changing over the sol.

The generator (`tools/generate_region.py`) gets a density check that flags any stretch of ground with nothing on it.

**Storm debris trails · Decided 7 Nov.** Each scattered pallet leaves a trail: a parachute strip, a crate lid, straps and packing, lying in a line along the wind. Following one leads you to the pallet. These are breadcrumbs, not markers. Some bits are salvage.

**The world changes · Decided 7 Nov.**
- **Storms re-shape the land:** dunes move, things get buried or uncovered, and new debris is scattered (§1.11).
- **Some ways open later:** a blocked pass clears after the big storm, for example.
- **Your spaces show your life:** the lander cabin and your rooms fill with your own clutter over the sols (samples, photos, mugs).

### 9.3 The map: 25 places · **Decided 3 Nov** (positions tuned when built)

The lander sits near the middle of the 12 km region. Bearings and distances are from it (N up). The landmarks you can see from afar are the Layered mound (E), the Great crater rim (E), the Lava plain (N) and the Highland walls (all round).

| # | Place | Ring | From the lander | Based on | What's there |
|---|---|---|---|---|---|
| 1 | Landing plain | Near | centre | Aeolis plains | the lander; flat, dusty, easy walking |
| 2 | Parachute ridge | Near | N 0.4 km |  | the first pallet, in view of the hatch |
| 3 | Boulder field | Near | E 0.8 km | ejecta blocks | a second pallet; salvage; basalt and dust-coated rock |
| 4 | Little Bowl | Near | E 1.1 km | the 2021 fresh impacts that exposed ice | a fresh 150 m crater; bright ice in its wall; breccia |
| 5 | Frost hollow | Near | SW 1.0 km |  | ice under a thin dust cover; dawn frost; a third pallet |
| 6 | Overhang cave | Near | W 1.3 km |  | a short cave under a low scarp; the headlamp's first use |
| 7 | Riverbed ridges | Middle | NE 1.5-3 km | Aeolis Dorsa inverted channels | old rivers standing as ridges; conglomerate; they lead to the delta |
| 8 | Yardang rows | Middle | W 2-3 km | Medusae Fossae | long wind-carved ridges; dust devils; a pallet in the lee |
| 9 | Dark dune sea | Middle | SW 2-3 km | Bagnold dunes | black basalt dunes, soft and risky to drive; olivine sand |
| 10 | Ramp mesas | Middle | S 2 km |  | layered sandstone mesas; fallen-wall ramps up to wide views |
| 11 | Ice scarp | Middle | NW 2.5 km | HiRISE mid-latitude ice scarps | bright cliffs of buried ice, crumbling; the first outpost site |
| 12 | Wrinkle ridges | Middle | E 2 km |  | long low ridges; a natural road east; seismometer ground |
| 13 | Canyon caves | Middle | N 2.5-3 km |  | a canyon wall with caves; cave ice and mineral crusts |
| 14 | Broken lander | Middle | E 2.5 km |  | a cargo lander the storm wrecked; rich salvage, damaged kit to study |
| 15 | Blueberry flats | Middle | SE 2 km | Opportunity at Meridiani | haematite concretions; the first miner site |
| 16 | Salt pan | Middle | SE 2.8 km | chloride deposits | a white salt flat; perchlorate crust, gypsum veins; brines at dawn |
| 17 | Great crater rim | Far | E 4-6 km | Gale crater | a 4 km crater; the river breaks through its rim |
| 18 | Layered mound | Far | E 5.5 km | Aeolis Mons (Mount Sharp) | a tall mound you can see from anywhere; clay and sulfate layers; sulfur |
| 19 | Delta and lakebed | Far | E 4.5 km, inside the crater | Jezero's delta, Gale's lake | lakebed mudstone; the life thread |
| 20 | Lava plain | Far | N 4-5 km | Elysium Planitia | dark rough lava, hard on the rover; vesicular and fresh basalt |
| 21 | Skylights and lava tube | Far | N 5 km, under the lava plain | Arsia Mons pit craters | pits into a long tube; a steady climate; the safe refuge |
| 22 | Chaos blocks | Far | S 4.5 km | Aram Chaos | jumbled blocks where ground ice melted away; heat-flow ground |
| 23 | Glacier apron | Far | W 5 km | lobate debris aprons | a buried glacier under rock, at the highland foot |
| 24 | Meteorite strewn field | Far | SW 4 km | Heat Shield Rock, Lebanon | iron meteorites scattered across a dark plain |
| 25 | Highland walls | Far | the edge, about 6 km |  | walls too steep to climb; dust haze; blocked passes for later |

**Pallets (about 12):** 3 near (#2, #3, #5), 6 middle (#7, #8, #10, #12, #14, #15) and 3 far (#17, #20, #22). The storm decides which carriers still walk.

**Ice:** a little near (#4, #5); the scarp in the middle ring (#11); caves (#13, #21); and the glacier far out (#23).

## 10. Failure and recovery · **Decided 3 Nov**

- **The base keeps running while you're away.** Anything that goes wrong degrades slowly, over hours to sols, never minutes.
- **You're warned:** the wrist pad pings you, and the airlock shows how long the base can manage alone.
- **At worst you come home to a cold, dark base** and restart it by hand: power first, then heat, then air. It's tense but recoverable.
- **Refuges:** if you're caught out, the lander cabin or any habitat.
- **No game over.** At zero health you collapse and wake later (§1.6). It costs time, never the save.

## 10b. Sound, music and the first five minutes · **Decided 3 Nov**

**Sound: mostly quiet, with music at moments.**
- **Outside:** the thin wind (real Mars sound is muffled; Perseverance recorded it), your breathing and the suit's hum.
- **Music** is sparse and comes only at moments: cresting a ridge to a new view, a discovery, a first sunrise. Then it fades back to silence.
- **The radio** is the human voice, rare and precious.
- **Inside,** the base's hum is comfort. Silence there means trouble (§2).
- **Mood reference** (a guide only, not used in the game): sparse ambient, slow synth pads with space around them, in the spirit of Brian Eno's *Apollo*.

**The first five minutes, taught with no checklist:**
1. **Touchdown.** The cabin is dim, and its air gauge, a physical dial, is dropping.
2. **ARDEN hands you the slate.** It shows only one thing: a blurry orbiter photo of a parachute.
3. **Through the cabin window,** you see the same parachute on a ridge.
4. **Prompts appear only** when you look at something you can use ("E Suit up").
5. **Stepping out,** the music swells for the first view.
6. **The walk to the parachute** teaches walking, the wrist pad (oxygen) and the feel of turning back in time.
7. **Opening the pallet restores the air:** the first relief.

## 10c. GAR-Y's growth · **Decided 3 Nov**

GAR-Y is found early, with its radar survey and the rescue. After that it learns, from plans you find or earn, and **each upgrade takes a chore off you** so you can explore more:
- **the sled,** for small loads;
- **laying cable and pipe** along the routes you plan (§9.1);
- **collecting from miners** on its rounds (§1.11);
- **a longer survey range;**
- **hauling bulk** (iron, ice, regolith) from early on, so you carry only samples and small finds and are never a delivery driver (7 Nov);
- **guiding a walking carrier home.**

## 10d. Accessibility · **Decided 3 Nov**

- **Assisted mode:** hands-on steps are done for you (holding the corer steady, laying a patch). You still choose what to do and where.
- **Reduce screen effects:** tone down the vignette, blur and drifting view used for show-don't-tell (§2).
- **Colour-safe cues:** every state shows by shape and sound as well as colour.
- **Numbers option:** exact readouts for players who want them. They stay one tap deeper by default.
- **Subtitles** as now: Full, Compact or Off.

## 10e. Voices, and who comes down · **Decided 3 Nov**

**You are physically alone for the whole main game.** That solitude is the feeling the game is for (master-design §1). People living at the base mid-game would water it down, and visible crew are a very large job (AI, animation, voices).

**The orbiter crew are the near voices.** They are the people who were meant to land with the cargo and now can't: they wait in orbit until there is a base to land at. They talk to you while you drive and work, telling their stories, so long rover drives aren't silent. Their passes over you set when they can talk (the Comms app shows the next pass).

**Earth is rare.** The Mission Control cast (docs/mission-control-voice.md) is still there, but with the light-minutes delay their messages are occasional and one-way, mostly through the orbiter.

**You answer with short replies only.** At some lines you pick one of two or three short replies (a word or a sentence). There is no dialogue tree, and choosing nothing is fine.

**ARDEN** (proposed) keeps to practical safety lines: the cabin air, the suit, the hatch. It isn't a story voice.

**Crew size** becomes how many wait in orbit: Small 2, Standard 5, Large 8. That sets how big a base the finale needs. In Solitary the orbiter is uncrewed, and its voice is Earth's relay only.

**Landing them is the finale:** the welcome-the-crew ending, the moment the base was built towards. After it the game carries on open-ended. This replaces Earth's crew waves (docs/survival-systems.md §12.2, commit 3417721). Visible crew at the base can come later as an expansion.

### 10e+. Fewer voices, each one meaningful · **Decided 7 Nov**
After step 2 the game had about 17 speaking characters (ARDEN, the suit, the relay, five orbiter crew, eight Mission Control people and more). The user: "we want conversation to be meaningful not just noise to fill empty space." Grounded in Firewatch (one relationship; talks fit the travel; silence allowed), Schell Lens #76 Character Function (fold characters that do the same job), #79 Character Web and #61 Interest Curve, and Cleveland's talk (story threads started by what you do):
- **ARDEN is only the habitat's voice:** heard in the cabin and the habitat, never out on the suit radio. Practical, with a little dry warmth kept but rationed.
- **The suit has no voice.** It gives alerts only (tones, the wrist dial, screen cues). The orbital relay becomes text.
- **Castellanos is the one near voice** (the Delilah role): she talks with you on walks and drives during orbiter passes, reacts to what you did, and you can answer or stay silent. The other crew exist and are heard *about* through her; they speak only in the descent and the finale.
- **Earth keeps the four CAPCOM arcs** (Ines, Theo, Sunny, Noor) **as letters:** recorded messages that wait on the slate, played when you choose, with a short reply you can send that the next shift answers. The specialists (Peg, Kwame, Ruth, Jasper, Pip) live on as things the four mention.
- **Drives:** unopened letters play on the rover radio as you set off (one a drive); **Sunny's weekend show** (a few of the game's own tracks with his stories and jokes between) plays on drives on a weekly schedule; Castellanos talks when the orbiter is overhead; and some drives are left to the music and the view on purpose. You can respond to all of them.
- **Voices are earned in layers:** at landing, ARDEN and orbiter texts only; repairing the link brings Castellanos's voice; a later goal (the high-gain dish) brings Earth's letters.
- **The meaning rule, with flavour:** a line reacts to something you did, moves a story on, or warns of real danger, or it's a rationed bit of warmth or humour that never repeats and never wears out its welcome. Pure filler goes (most of the 24 chatter lines). One voice at a time, and talks fit inside the journey.

## 10f. Reactivity and the present-tense story · **Decided 7 Nov** (from Firewatch)

Firewatch is the nearest game to ours: first person, physically alone, and the only company is a voice on the radio. Two lessons from its GDC talks (Chris Remo on its story, Jane Ng on its world) shape our voices:
- **You're a participant, not an archaeologist.** The story threads happen to you now:
  - the orbiter crew's own troubles;
  - Earth's search for the cargo;
  - GAR-Y.

  Logs, wrecks and the old landers are a side layer, never the main way the story is told.
- **Reactive voices: a "series of interesting outcomes".** The game quietly notices what you do, and the voices react later. You're never told it's a choice. For example:
  - what you carried home;
  - which pallet you opened first;
  - a risk you took (out at night, a crumbling cliff);
  - a short reply that wasn't true, which someone calls out later.

  Cheap lines in large numbers add up to a crew who feel real.
- **One record of who knows what.** The known-things registry (master-design §5) also holds what each character knows about you and what they've told you. Every line checks it, so nobody contradicts themselves.
- **Your words name the map.** When you describe a place in a short reply, it takes that name on your Map ("the Shark Fin", "Bad Idea Ridge").
- **Talks fit the drive.** A crew story starts as you set off and is written to fit the trip, checked with a stopwatch on the slice. Short replies time out, and saying nothing is an answer (§10e).
- **Music fills the quiet valleys.** As well as the big moments (§10b), a little music comes in when nothing has happened for a while and nothing is near.

## 10g. The chore check · **Decided 7 Nov** (from Firewatch)

Every job is tested: does it make you feel like the first person on Mars, at risk, or does it model the commissioner's day job? Settled:
- **Cut:** filter swaps and tank top-ups (§1.9); servicing outposts (§9.1); hygiene as a need (washing only lifts wellbeing, §1.6, and the toilet feeds the water loop by itself).
- **Simplified:** panel dusting only after storms (§1.10); exercise as an optional boost (§1.6); GAR-Y suggests cable and pipe routes (§9.1); the Print Shop draws from your stores (§8.1); GAR-Y hauls bulk (§10c).
- **Kept, because they serve the feeling:** air, warmth, water, food and sleep; repairing the carriers and the radio link; instruments, samples and the Lab; rare wear and the spares kit; building and fitting out rooms.

## 11. Today's items: keep, rework, merge or cut. **Draft, 3 Nov, for review**

This covers the 141 catalogue items (`data/equipment_catalog.json`) and the 5 site machines. The 12 surface props are among the catalogue's exterior items. **Tally:** 35 personal & comfort (found), 29 rework, 26 keep, 21 merge, 19 furnishing, 8 cut, 2 variant of exercise station, 1 variant of work desk.

"Furnishing" is basic habitat furniture, printable from the start, there to look and feel good (seating adds a little to meals together). "Variant of" means the same job in a different look, sharing one plan. "Furnishing" is basic habitat furniture you can print from the start, there to look and feel good. Seating adds a little to meals together. Schell's Lens of Elegance is about mechanics, while his Lenses of Character, Beauty and Expression say to keep the looks players love. "Variant of" means the same job in a different look, sharing one plan. "Personal & comfort (found)" means crew belongings, or wellbeing items Earth planned to send. You find each one first (in pallets, in storm debris, or in later resupplies), and after that you can print it.

| Item | Verdict | Note |
|---|---|---|
| Sleep Station | Keep | Bunk; sleep quality depends on the room |
| Personal Locker | Personal & comfort (found) | crew belongings |
| Common Table | Furnishing | seating for meals together |
| Task Light | Cut | lights are automatic |
| Privacy Divider | Furnishing | a free-standing screen |
| Exercise Station | Rework | Exercise: an optional boost (faster walking, more carried for the sol); looks: station, treadmill, bike |
| Science Workbench | Rework | Lab bench: analyses rocks, regolith and cores |
| Microscope Station | Keep | speeds up rock and regolith analysis; Lab only |
| Sample Storage Cabinet | Keep | the sample archive: your story on show |
| Grow Tray | Rework | Grow rack (greens) |
| Seedling Station | Merge into Grow rack | replanting is automatic |
| Nutrient Mixer | Keep | compost to nutrients (closing the loop) |
| Harvest Cart | Cut | you harvest by hand at the rack |
| Large Planter | Rework | Planter (potatoes); Greenhouse only |
| Air Recycler | Keep | CO2 scrubber; in the first pallet |
| Water Processor | Rework | Water processor |
| Oxygen Reserve | Keep | in the first pallet |
| Thermal Control Unit | Keep | heats every room |
| Cargo Rack | Rework | Storage rack: holds stock visibly |
| Engineering Bench | Rework | Engineering Bench: repairs, spares, studying kit, scrapping |
| GAR-Y Dock | Keep | charges the scout rover and the HabRover |
| EVA Tool Station | Merge into Suit rack |  |
| Suit Rack | Rework | Suit rack: choose your loadout (4 slots) |
| Corridor Light Strip | Cut | lights are automatic |
| Wayfinding Panel | Cut | no lettering on models |
| Fire Safety Station | Cut | no fire system |
| Utility Conduit | Cut | inside connections are automatic |
| Airlock Control Panel | Keep | cycles the airlock |
| Suit Service Panel | Keep | refills the suit |
| Dust Grate | Furnishing | airlock look |
| Emergency Supply Locker | Rework | the lander's emergency kit (the opening) |
| Power Distribution Cabinet | Keep | Power cabinet: battery LEDs, isolator |
| Battery Bank | Keep | 25 kWh |
| Galley Counter | Furnishing | galley look |
| Pantry Cabinet | Rework | Pantry: rations visible on its shelves |
| Water Dispenser | Merge into Galley | water shows on the tank gauges |
| Low-Water Shower | Keep | washing uses 4 L and lifts wellbeing |
| Vacuum Toilet | Keep | feeds the urine processor later |
| Medical Supply Cabinet | Merge into Medical Bay cot |  |
| Medical Exam Cot | Rework | Medical Bay cot: faster healing |
| Trash Compactor | Rework | the Recycler: trash into a little iron and salvage, plus compost |
| Communications Data Rack | Rework | Comms rack: the link to repair; in the Lab |
| Mess Booth | Furnishing | seating for meals together |
| First Aid Kit | Keep | treats minor injuries anywhere |
| Wall First Aid Kit | Merge into First aid kit |  |
| Portable Work Light | Cut | lights are automatic; the headlamp is field kit |
| Supply Crate (Small) | Merge into Storage rack | crates become pallet contents |
| Supply Crate (Medium) | Merge into Storage rack |  |
| Supply Crate (Large) | Merge into Storage rack |  |
| Mission Planning Console | Rework | Operations desk: Earth's requests, map table; in the Lab |
| Mars Survey Board | Merge into Operations desk |  |
| Wall Cabin Heater | Merge into Portable heater |  |
| Portable Utility Heater | Rework | Portable heater: lander kit, for the first night |
| Small Cargo Crate | Rework | pallet contents (found) |
| Large Cargo Crate | Rework | pallet contents (found) |
| Loaded Cargo Pallet | Rework | a cargo pallet on a walking carrier |
| Communications Mast | Rework | Antenna mast: part of the link repair |
| Camera Mast | Rework | kept for the Cameras view; low priority |
| Outdoor Workbench | Furnishing | outdoor look |
| Tall Light Post | Keep | the one kind of outdoor light |
| Path Beacon | Rework | marker beacon: field kit, your pins |
| Portable Floodlight | Merge into Outdoor light |  |
| Safety Barrier | Furnishing | outdoor look |
| Solar Floodlight | Merge into Outdoor light |  |
| Hazard Bollard | Furnishing | outdoor look |
| Compact Reactor | Keep | late, 10 kW |
| Ice Extractor | Rework | Ice extractor: needs a pipe or an outpost tank |
| Oxygen Generator | Keep | O2 from water |
| Crew Lander | Rework | the lander: your first refuge |
| Landing Seat | Keep | lander cabin |
| Galley Kitchenette | Rework | the Galley (working): eat by hand (E), cooking automatic |
| Galley Bench Unit | Furnishing | galley look |
| Dining Table | Furnishing | seating for meals together |
| Galley Oven | Furnishing | galley look |
| Rehydration Station | Furnishing | galley look |
| Galley Freezer | Keep | produce keeps 60 sols; Day Room only |
| Plastics Hopper | Merge into Recycler |  |
| Metals Hopper | Merge into Recycler |  |
| Compost Hopper | Merge into Recycler |  |
| IV Drip Stand | Furnishing | Medical Bay look |
| Crew Vitals Monitor | Furnishing | Medical Bay look |
| Surgery Cart | Furnishing | Medical Bay look |
| Exam Light | Furnishing | Medical Bay look |
| Work Desk | Furnishing | furniture |
| Work Desk (clear) | Variant of Work desk |  |
| Crew Chair | Furnishing | furniture |
| Open Shelving | Furnishing | furniture |
| Potted Plant | Personal & comfort (found) | a bit of home |
| Whiteboard | Cut | no lettering on models |
| Wall Screen | Personal & comfort (found) | shows photos from the journal |
| Retro Mars Poster | Personal & comfort (found) | an Earth wellbeing item |
| Regolith Printer | Rework | the printer crawler robot: shells, berms, pads |
| Print Shop | Rework | Print Shop: iron and salvage, takes haematite |
| Regolith Intake | Rework | feeds the regolith printer |
| Crew Mug | Personal & comfort (found) | crew belongings |
| Crew Tablet | Personal & comfort (found) | crew belongings |
| Laptop | Personal & comfort (found) | crew belongings |
| Paper Books | Personal & comfort (found) | crew belongings |
| Photo Frame | Personal & comfort (found) | crew belongings |
| Chess Set | Personal & comfort (found) | crew belongings |
| Zero-G Plush | Personal & comfort (found) | crew belongings |
| Herb Pot | Personal & comfort (found) | crew belongings |
| Desk Lamp | Personal & comfort (found) | crew belongings |
| Water Bottle | Personal & comfort (found) | crew belongings |
| Sample Jars | Merge into Sample storage cabinet |  |
| Toolbox | Merge into Engineering Bench |  |
| Ration Packs | Merge into Pantry | rations shown on its shelves |
| Guitar | Personal & comfort (found) | crew belongings |
| GAR-y | Personal & comfort (found) | crew belongings |
| Regolith Shield Wall | Rework | shielding, printed by the regolith printer |
| Water Wall | Keep | water storage that also shields |
| Storm Shelter Locker | Merge into Medical Bay | the Medical Bay is the solar-event shelter |
| Hull Patch Kit | Keep | for breaches; also the field kit's patch |
| Air Reserve Rack | Merge into O2 reserve tank |  |
| Spare Parts Rack | Merge into Storage rack | spares kits are kept here |
| Lounge Sofa | Personal & comfort (found) | Earth wellbeing item |
| Bean Bag | Personal & comfort (found) | Earth wellbeing item |
| Arcade Cabinet | Personal & comfort (found) | Earth wellbeing item |
| VR Station | Personal & comfort (found) | Earth wellbeing item |
| Table Football | Personal & comfort (found) | Earth wellbeing item |
| Telescope | Personal & comfort (found) | Earth wellbeing item |
| Music Corner | Personal & comfort (found) | Earth wellbeing item |
| Magnetic Dartboard | Personal & comfort (found) | Earth wellbeing item |
| Games Shelf | Personal & comfort (found) | Earth wellbeing item |
| Movie Screen | Personal & comfort (found) | Earth wellbeing item |
| Corner Sofa | Personal & comfort (found) | Earth wellbeing item |
| Coffee Bar | Personal & comfort (found) | Earth wellbeing item |
| Bar Stool | Personal & comfort (found) | Earth wellbeing item |
| Plant Wall | Personal & comfort (found) | Earth wellbeing item |
| Rug | Personal & comfort (found) | Earth wellbeing item |
| Floor Cushions | Personal & comfort (found) | Earth wellbeing item |
| Window Seat | Personal & comfort (found) | Earth wellbeing item |
| Table Tennis | Personal & comfort (found) | Earth wellbeing item |
| Climbing Wall | Personal & comfort (found) | Earth wellbeing item |
| Treadmill with Harness | Variant of Exercise station | same job, different look |
| Exercise Bike | Variant of Exercise station | same job, different look |
| Utility Rack | Rework | General Module rack: basic storage and the first stores |
| Sabatier Reactor | Keep | later: water, plus methane for the ascent tank |
| Methane Tank | Keep | the ascent tank (go-home ending) |
| Atmosphere Processor | Keep | discovery: O2 from Mars air |
| Urine Processor | Keep | later: closes the water loop |

**Site machines and new items**

| Item | Verdict | Note |
|---|---|---|
| Solar array (site) | Keep | 2.5 kW at peak; laid cable outside the hab |
| Compact reactor (site) | Keep | late, 10 kW |
| Ice extractor (site) | Rework | on a cored deposit (no 7 m rule); a pipe or an outpost tank |
| Regolith intake (site) | Rework | feeds the regolith printer |
| Atmosphere processor (site) | Keep | from a discovery |
| Smelter | Merged | the Print Shop takes haematite directly |
| **New:** Haematite miner | New | at outcrops; GAR-Y collects from it |
| **New:** Outdoor cable, heated pipe | New | planned in Look, laid by GAR-Y |
| **New:** Outpost shelter, water tank | New | far ice and far sites |
| **New:** Field kit (rock hammer, spare O2 bottle, headlamp, field spectrometer) | New | section 4 |
| **New:** Instruments (weather station, seismometer, radiation and dust monitors, scout helicopter, methane sniffer, radar sled, heat-flow probe) | New | section 5 |
| **New:** Walking carrier, scout rover, HabRover | New | section 7 (the crew rover becomes the scout) |
| **New:** General Module (fixed), printed room shell, Medical Bay and Storage rooms | New | section 3 |

## 12. One balance source
- Every number goes in the spreadsheet (`docs/MarsHabitat_Balance.xlsx` → `tools/import_balance.py` → `data/resources.json`). That includes `hazards.json` and the constants now hard-coded in the sim, suit, wear, waste, food and weather scripts.
- Unused keys are dropped.
- Each number gets a "real figure" and a source.
- **Set up 7 Nov (step 0):**
  - **Hazards sheet:** written to `hazards.json` on import; that file's lists stay hand-edited.
  - **New numbers sheet:** this brief's first figures, exported under `revamp` for step 1.
  - **Real figure and source** columns.
  - **Unused keys** no longer exported: five settings and three hazard keys.

  Constants still hard-coded in scripts move in as step 1 replaces those scripts.

## 13. The playable slice and its checklist

One Survival run should let you try every pillar:
- **Survival:** cabin air and the first pallet; the night cold; water from ice; a meal; sleep.
- **Exploration:** the map filling in; parachute landmarks; reading the land; a field loadout; a cave by headlamp.
- **Discovery:** samples to the lab; a weather station deployed; a first discovery and the plan it unlocks; one multi-step discovery and one high-risk one (§6b).
- **Design and build:** the General Module set down; a printed room drawn; equipment fitted in Look; a cable or pipe laid.
- **Story:** meeting GAR-Y; the comms repair; the orbiter crew talking on a drive, with a short reply picked.
- **Range:** the scout rover found and driven; a night in the HabRover (or a stand-in).
- **Feel:** cold, hunger and stale air felt on your body and seen in the base, without reading a number.

## 14. Rebuilding the code *(written last)*
- **A new simulation core,** separate from the builder: one model of stores and flows, one alerts engine, one runway calculation, one failure path, and every number from §12. It replaces `habitat_sim`, `habitat_chains`, the needs in `habitat_life`, `habitat_wear`, `habitat_waste` and `habitat_food`.
- **Split `build_controller.gd`** (7,000 lines) into placement, the base model, the catalogue and UI, and the rules hooks. The Missions hooks go.
- **The order runs from the opening to the slice** (master-design §10). Each step ends playable and gets a playtest:
  0. **Clear the ground:** remove Missions mode and the Classic HUD; fix the three bugs below; move the numbers into one balance source (§12).
  1. **The new sim core** with power, heat and air only, and the one body (§2) driven by it. The lander cabin is the first "base" it runs.
     - **Decided 7 Nov:**
       - **Four parts:** stores and flows, one alerts engine, one runway sum, and the body.
       - **Built beside the old sim:** it takes over power, heat and air; water and food stay on the old code until steps 5 and 7.
       - **The 30-minute sol and 8 hours of suit air start here.**
       - **The body cues are clear,** with a comfort slider to tone them down.
       - **Night one is a real choice:** the battery can't run the heater, lights and scrubber all night. Everything on runs it flat in the small hours, which are cold and dark. The heater on Low nearly lasts; Off keeps the power but is the coldest. You feel it, and nothing kills you. It's a fallback you set as you leave, because the cabin runs while you're away.
     - **The first hour, decided 7 Nov** (the user: "using the lander like the lifepod is a good idea but forcing them to stay in it is not"):
       - **Land an hour after sunrise,** so the first sunset comes about 20 real minutes in, just after pallet 1. Built in step 1.
       - **Night is walkable.** The suit drains by real minutes, so a night trip lasts about as long as a day trip; the heater works harder (×1.4) but doesn't cripple you. Built in step 1. Night gets its own finds (stars, Phobos and Deimos, dawn frost, a meteor; §6c), from step 2.
       - **Sleep is offered, never forced:** from any sealed place (the cabin, later the rover and the habitat), and offered at a pause such as after a pallet, like Firewatch's cuts "at points of closure or tension". Step 2.
       - **Night one's real fix is out in the world:** ARDEN warns that the cabin can't stay warm all night on its own battery, so you look for the power pallet before dark (master-design §6's pressure table). Step 2.
       - **Too far at night and you black out:** GAR-Y finds you, the second way to meet it (master-design §2).
  - **Step 2, decided 7 Nov:**
    - **The old chapter-one crates are removed from new games:** only the lander and pallet 1, true to the story. There's little past 20 minutes until step 3.
    - **The descent is talked down live on the radio** by the orbiter crew (about 40 s, skippable). At touchdown the link drops to static and the orbiter is texts only. No separate cutscene.
    - **Voices stay on text-to-speech** (tools/generate_voice.py), with lines written to a finished standard and timed to the walk.
    - **The orbiter crew, a working draft (7 Nov; the user will revisit the specifics later; the dialogue tone is approved):**
      - Commander Mira Castellanos: keeping five safe and choosing when to land.
      - Pilot Devan Rao: one landing's worth of fuel; practises nightly.
      - Engineer Tamsin Achterberg: the orbiter's failing water recycler mirrors your repairs.
      - Doctor Joseph Mwangi: the long wait wears the crew down, which gives the finale heart without a timer.
      - Biologist Kai Tupou: wants the life thread most.

      Castellanos and Rao talk you down in step 2. Names and roles live in one data file (`data/orbiter_crew.json`), so changes don't touch code.
    - **Notes replaces Goals** as your inner voice (master-design §5). The chapter-one checklist and tutorial are off for new games; optional hints stay.
    - **Pallet 1:** free its latches, then carry the ~20 kg oxygen cartridge back and plug it into the cabin. The cabin air is cut back to about a sol, and suit refills draw from it.
       - **Collapse:** you wake in the cabin (GAR-Y's rescue comes in step 7).
       - **Not in step 1:** splitting `build_controller.gd` (step 3).
  2. **The 20-minute opening, built close to finished quality** (art, sound, voice), to prove that walking, talking and surviving are fun before anything else is built (Firewatch's vertical slice):
     - the cabin air dial;
     - the parachute photo and window;
     - the walk;
     - the first pallet;
     - the known-things record, the map filling in and pins.

     **Built 7 Nov, ready to playtest** (commits fffa4d8 to 5c8fb5d on survival-revamp):
     - the known-things record, the Map filling in from what you've seen, pins, and the compass always on with Settings switches for its marks;
     - the old crates gone from new games;
     - Notes as your inner voice (data/notes.json): the air, the parachute, the sunset, ARDEN's afternoon power warning, night and dawn, a cold cabin, rest offered at dusk;
     - the storm drop: the 21 m parachute draped on a ridge ~400 m in front of the hatch, the backshell, a trail of eight debris pieces, pallet 1 with four latches, the 20 kg oxygen cartridge carried back to the cabin's new dial port;
     - the blue sunset, with a music moment;
     - the descent talked down live by Rao and Castellanos (data/orbiter_crew.json "radio"), cut into static at touchdown, then ARDEN's lost-lock line;
     - Rao's first text with the orbiter photo of the parachute (rendered in game, softened and grained), which the slate opens on;
     - tests: known_things, notes, storm_drop, descent_radio, opening.

     **Not yet:** food and water in pallet 1 (they come with the food and water rework); the power pallet to find (step 3).
  3. **The 40 minutes:**
     - GAR-Y (found, or finding you);
     - more pallets;
     - a carrier repaired and walked home;
     - the General Module set down;
     - the Plan view on explored ground;
     - printed shells built at watchable speed (§3).
  4. **Materials and making:**
     - the four materials;
     - the Print Shop with haematite;
     - the Engineering Bench (studying damaged kit);
     - the Recycler;
     - the field kit and suit rack loadout (§4).
  5. **Water and the outside:**
     - ice by reading the land, the radar and a core;
     - the extractor;
     - the cable and pipe planned in Look and laid by GAR-Y (§9.1);
     - the outpost tank.
  6. **Range and voices:**
     - the scout rover;
     - the comms repair;
     - the orbiter crew on drives (§10e);
     - the 12 km world in three rings (§9.2).
  7. **Food, the body and science:**
     - the galley by hand;
     - sleep;
     - collapse and GAR-Y's rescue;
     - instruments (§5);
     - the processing rule (§6);
     - the slate's Base picture.

     **The slice (§13) is complete here.**
  8. **After the slice:**
     - the HabRover;
     - wear and spares;
     - storms and their return;
     - the wonder thread;
     - Personal and comfort finds;
     - the finale and endings.
- **Bugs to fix on the way:**
  - the storm stall;
  - the vehicle bay counted as heated in one place and unheated in another;
  - stale Freedom notes in `suit.gd:24` and `resource-model.md`.

## 15. Settled questions · **Decided 3 Nov**

**Water home.** A heated pipe serves near ice; an outpost with its own tank serves far ice (§1.4, §9.1).

**Resupply.** Once the link is fixed, Earth sends a lander about every 25 sols. It lands 1–2 km away with salvage, a plan or two, and sometimes a comfort item.

**Walking carriers.** They're based on JPL's ATHLETE, a six-legged robot with a wheel on each leg that rolls on flat ground and walks on rough ground. It was built to carry cargo, even a habitat module, off a lander (NASA's Desert RATS trials). Our stretch: the real one was steered from Earth, while ours drive themselves home once fixed.
- There are **3:** the General Module, the regolith printer and the power kit (solar and battery).
- They move at a steady walking pace. One found 2 km out gets home within the sol while you do other things.
- **Each one has one fault.** You spot it by looking (a blinking lamp on the bad part) and fix it by hand:
  - a leg jammed with dust: clean it;
  - a flat battery: charge it from a solar blanket or a spare cell;
  - a blind navigation camera: GAR-Y guides it home.

**Pallets and the likely order of finds:**
- **Pallet 1, on the Parachute ridge (#2):** an air recycler and O₂ tank to plug into the lander, a portable heater, about 5 sols of food and water, and the hand corer, scoop and sample case.
- **The other near pallets:** GAR-Y (Boulder field, #3); the rock hammer, headlamp and patch kit (Frost hollow, #5).
- **The middle ring:** the 3 carriers, the scout rover, the Print Shop and the comms parts for the link repair.
- **The far ring:** the HabRover's parts, the compact reactor and spares.
- You can find them in any order, but the land makes this order likely: survive, then GAR-Y, then the base pieces and the rover, then range.

**Material numbers (a first set, tuned in playtests through §12):**
- Ice, regolith and haematite are counted in kg. Salvage is counted in pieces, and you see it as parts and scrap on the shelves.
- **What you can carry:**

  | Carried by | Load |
  |---|---|
  | your hands | about 20 kg |
  | GAR-Y's sled | 50 kg |
  | the scout rover | 150 kg |
  | the HabRover | 500 kg |

- The regolith intake makes 150 kg a sol.
- **Recipes come in three sizes:**
  - a small part: 2–5 kg of iron;
  - a machine: 20–60 kg of iron and 1–3 pieces of salvage;
  - a printed room shell: regolith only.
- 1 kg of haematite gives about 0.5 kg of iron.

**Old saves.** They don't load in the revamp. A clear message says they belong to v0.3.0, which stays tagged and playable. Creative keeps the freeform builder.
