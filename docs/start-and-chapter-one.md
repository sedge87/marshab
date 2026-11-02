# The start and chapter one (core-loop step 4)

A design to answer before building. It follows `docs/core-loop.md` round 3 ("Build") and the build order's step 4: the precursor cargo, stores that run down gently, the fabricator with plans, and the self-sufficiency steps. The questions to answer first are in §10.

## 1. The problem

At the moment, Survival starts you with 100 t of Earth cargo and the whole build menu. You can place a full base with life support, an ice extractor, an oxygen generator and a greenhouse in the first sol, and be self-sufficient almost at once. Nothing is earned, and the expeditions in later steps have nothing to feed into.

Step 4 changes that in three ways:

- **What's available is limited,** not how fast you build. Building stays quick.
- **The things that make you self-sufficient are earned:** a discovery, then a plan, then a fabricator job, then fitting.
- **The start is calm.** The stores last long enough that self-sufficiency is a goal, not a countdown.

## 2. The start: precursor cargo

As NASA plans it, the cargo landed before you did.

- **You wake in the crew lander's cabin,** as now. Two cargo landers stand nearby (the Missions cargo lander model, `cargo_lander.gd`), their ramps down.
- **Each lander holds crates.** Walk up and press E on a crate to unpack it. Its contents go onto your **build bar**, under a new **Unpacked** tab, ready to place. Placing an unpacked item costs nothing.
- **The crates carry no lettering** (house style, 1 Nov). Their contents show on the E-inspect card, as a short manifest. Crates differ only by size: small for kit, long for frames, tall for tanks.
- **The order is suggested, not forced.** Mission Control's first messages and the tutorial point you through power, then the airlock and a General Module, then life support. A Survival player can ignore them.

### What the crates hold (proposed)

Enough to stand up one working base, and no more:

| Group | Contents |
|---|---|
| Shells | 1 General Module, 1 airlock, 2 corridor sections |
| Power | 2 solar arrays, 1 battery bank, power cabling |
| Life support | basic life support (the General Module rack's air and water), 1 CO₂ scrubber |
| Living | 2 sleep stations, the low-water shower, the trash compactor, the exercise bike |
| Work | 1 tool bench, the fabricator (§4), the comms station |
| Outside | GAR-Y, the suit and its bench (the crew rover comes with a later lander, Q2) |
| Stores | water, oxygen and food (§3), fabricator feedstock (§4, §13.8) |

Everything else comes from the fabricator, the regolith printer or a later lander.

### What happens to the 100 t budget

The Earth-cargo budget in tonnes stops being the way you pay for things in Survival. Its job is taken by the crates (what you brought) and the fabricator (what you make). The regolith printer keeps its job: room shells, corridors, partitions, shelving and other printable things, paid for in Mars-made material as now (`docs/cargo-supply.md`).

So in Survival a new room costs printed material, and new equipment costs a plan and a fabricator job. The cargo panel shows the unpacked items left, printed material, feedstock and Earth parts.

## 3. Stores that run down gently

- **The stores:** water, oxygen and food, landed with the cargo. Their tanks and racks are part of the base from the start.
- **How long they last:** about **90 sols** for one crew member at the start, before any recycling. Basic life support recycles most water and some air, so water and oxygen actually last longer; food doesn't.
  - The existing setting `start_food_sols` (60) becomes 90 and is joined by water and oxygen settings, all in the balance sheet.
- **How they're shown:** as **sols left** rather than a percentage, on the terminal and the habitat panel. Mission Control mentions them at half and at a quarter, calmly.
- **The goal they set:** be self-sufficient before they run out. A first-time player should manage it in about 30 to 50 sols, so there's plenty of slack.
- **If they run out** (question 3): a contingency reserve in the crew lander gives 10 more sols, Mission Control logs it, and an emergency lander brings another 30 sols of stores. No game over from the stores alone.

## 4. The fabricator and plans

> **Renamed 2 Nov: the Print Shop.** Players never see "fabricator" now (it read as a Subnautica copy). The name follows NASA's 3D-printed habitat work (ICON, the CHAPEA analog) and the ISS's Additive Manufacturing Facility: you *print* equipment from plans with print feedstock. The code ids stay `fabricator`. Its room, the old Workshop, is now **Power & Engineering**, and the Workshop Bench is the **Engineering Bench**. The screen: search, a **Needed now** strip (plans the chapter steps just unlocked, and spares kits while machines are worn), then cards in tabs by purpose (Water, Air, Food, Power, Outside, Crew, Safety, Work, Upkeep, Decor), each showing its cost and whether it's ready, short of stock or printed.

### The fabricator

- **A new piece of equipment:** a bench-sized machine with a build chamber behind a window, a filament or powder hopper and a small working display (the one screen that shows text: the job's progress). It's in the precursor crates.
- **Where it goes:** the Workshop, or the General Module at a cost (slower, like other work there: 75 %).
- **What it uses:**
  - **feedstock:** polymer and metal powder, landed with the cargo, and topped up by recycling. The trash compactor's tiles and the plastics hopper turn waste into feedstock;
  - ~~**Earth parts**~~: removed 2 Nov (§13.8). Feedstock is the only print input.
- **A job:**
  - choose a plan at the fabricator (E opens its screen);
  - see the cost in feedstock, the time and the power draw;
  - start it. Jobs take game hours, so most run overnight;
  - when it's done, the item goes onto the build bar's Unpacked tab.
- **The fabricator makes the plan, once** (playtest, 1 Nov). The first job makes one copy and puts the item on the Unpacked tab for good. Each extra copy takes its feedstock and Earth parts as it's placed, with no wait, and gives them back when it's removed. Crate copies are free and go first. Example: the first heater is a 6-hour job; the second, placed later in the lab, just takes 30 kg of feedstock and a part.
- **One job at a time** per fabricator. A second fabricator is itself a plan.

### Plans

Every piece of equipment that isn't in the crates needs a plan. There are three ways to get one:

1. **Brought from Earth:** known from the start. The basics you might want more of: sleep stations, shelving, lights, tool kits, spare filters, sample cases.
2. **Sent by the teams on Earth:** they arrive in Mission Control messages, usually in answer to what you've done (your first walk outside brings the cache stand, for example).
3. **Unlocked by discoveries:** the self-sufficiency steps (§5), and later the science chain (step 5).

The build bar shows equipment you have no plan for, greyed, with how to get it (`MHMissions.item_unlocked` already gates the build bar for Missions; plans use the same hook). The journal (step 5) will list plans too.

## 5. The self-sufficiency steps

Each step is a discovery, then a plan, then a fabricator job, then fitting.

| Step | Discovery | Plan | Then |
|---|---|---|---|
| 1. Ice | GAR-Y surveys an orbital zone; you take a good core (§6) | Ice Extractor (`ice_drill`) | Place it on the ice; water flows |
| 2. Water | Water from the extractor tests clean | Water processing (into life support) | Water is self-sufficient |
| 3. Oxygen | Enough water to split | Oxygen Generator (`oxygen_generator`), electrolysis | Oxygen is self-sufficient |
| 4. Food | Regolith washed of perchlorate | Treated soil, then the greenhouse planters and grow racks | Food is self-sufficient |

When all four are running and cover the crew's needs, **chapter one ends**: Mission Control sends a short report, "Self-sufficient", with what you did and how long it took.

## 6. How ice is found before the lab exists

Finding ice is a gameplay element in its own right, done with GAR-Y (decided 1 Nov, Q7). The suit and wrist only handle life support.

- **Orbit gives broad zones only.** Mission Control marks a few large, fuzzy "possible ice" zones on the map, and some of them are false.
- **GAR-Y surveys a zone.** Its "Find ice" order becomes **"Survey zone"**: GAR-Y drives transects with its radar for a few game hours. Its readings fill in a coarse grid of signal strengths on the comms station and terminal map, with some noise. GAR-Y gathers the readings and you interpret them; it doesn't pick the spot. Auto-find can come back later as an upgrade.
- **You take a core.** A **hand corer** (a tool-bench item, in the crates) is used at the cell you choose. The core shows depth and purity: shallow, clean ice makes the extractor run faster and deep ice makes it slower, and some cores come up dry.
- **Your first good core is the discovery,** and it earns the Ice Extractor plan.
- **Step 5:** cores go back to the lab for full analysis.

## 7. The game modes

| Mode | What step 4 changes |
|---|---|
| Survival | Everything above |
| Freedom | Precursor crates, with **all plans known**; the fabricator still makes the first of each. Stores last longer (about 150 sols) |
| Creative | Nothing: everything available, no stores |
| Missions | Nothing: each mission keeps its own payload and unlocks |
| Tutorial | Starts from the precursor crates; teaches unpacking and one fabricator job |

## 8. Old saves

A save from before step 4 loads **as already supplied:** every plan known, no crates, its stores as saved, and the cargo budget shown as before. It's marked "older rules" on its save card. Chapter one counts as done if the base is already self-sufficient.

## 9. Building it

- **Models:**
  - the fabricator (new, HQ kit);
  - precursor crates in three sizes (rebuild of the existing cargo crates, without lettering);
  - the hand corer (new, HQ kit);
  - the cargo lander is reused.
- **Data:** the manifest (`data/precursor_manifest.json`), plans (`data/plans.json`: id, source, cost, time), the stores settings in the balance sheet.
- **Code:**
  - unpacking and the Unpacked tab (`interior_build_controller.gd`, `build_controller.gd`);
  - plans gating through `item_unlocked`;
  - the fabricator's screen and jobs (a new script, saved with the game);
  - stores as sols left;
  - ice zones, GAR-Y's "Survey zone" grid, the hand corer and core results (depth, purity) feeding the extractor rate;
  - the chapter-one report.
- **Tests:** `tests/start_and_chapter_one_test.gd`: unpacking, plan gating, a fabricator job, the four steps, Freedom and Creative, old saves.

## 10. Questions to answer first

1. **The tonnes budget:** replace it in Survival with the crates, the fabricator and printed material (as in §2), or keep a small Earth budget for a few extra items?
2. **The crates' contents:** is the list in §2 about right? Should the crew rover be there from the start, or arrive with a later lander?
3. **Running out of stores:** the contingency reserve and emergency lander (§3), or a real game over when food or oxygen runs out?
4. **How long the stores last:** 90 sols in Survival and 150 in Freedom, or other numbers?
5. **Feedstock and Earth parts:** two inputs as in §4, or one simpler "fabricator stock"?
6. **Where the fabricator goes:** the Workshop and the General Module (as in §4), or the Workshop only, to make the Workshop worth building early?
7. **Finding ice before the lab:** the wrist scan at an orbital hint (§6), good enough as a stand-in until step 5?
8. **Freedom:** all plans known from the start (§7), or the same plans as Survival with more stores?

### Answers (1 Nov 2026)

1. **Replace it.** In Survival the tonnes budget goes; crates, the fabricator and printed material take its place.
2. **The list is right, but the crew rover comes later,** with a later lander. The first trip to the ice hint is on foot.
3. **The soft net:** the contingency reserve and the emergency lander. No game over from the stores.
4. **90 sols in Survival, 150 in Freedom.**
5. **Two inputs:** feedstock and Earth parts.
6. **The Workshop and the General Module,** with the General Module at 75 %.
7. **Not the wrist scan:** GAR-Y surveys a zone, and you read the grid and take a core with a hand corer (§6).
8. **All plans known in Freedom.**

## 11. Built (1 Nov 2026)

- **The rules:** `scripts/chapter_one.gd` (`MHChapterOne`). On for new Survival and Freedom games, off for Creative, Missions and saves from before step 4 (their cards say "older rules").
- **Crates:** two cargo landers stand beside the crew lander, with seven crates in front of their ramps (`data/precursor_manifest.json`, `scripts/precursor_crate.gd`). E unpacks a crate, I shows its manifest. Equipment and the non-printable site parts (airlock, solar, ice extractor, regolith intake, reactor) come from stock, not cargo: removing one puts it back. The Earth budget is only the shells crate's hull kit (12 t), which printable shells, windows and partitions use after any printed material. The cargo panel reads HULL KIT LEFT, with unpacked items, feedstock and Earth parts underneath.
- **Plans and the fabricator:** `data/plans.json`, `scripts/fabricator.gd` (a stand-in model in house roles until the HQ model is made) and `scripts/fabricator_screen.gd`. The build bars show NO PLAN, MAKE FIRST, or once it's made the per-copy cost, with what's missing as the tooltip; the furnishing bar's Unpacked tab holds crate copies and made items. Per-copy charges are worked out from what's placed (`MHChapterOne.settle()`), so undo and removal refund them.
- **Stores:** 90 sols (Survival) or 150 (Freedom) for two crew, in landed store tanks (balance sheet: `chapter_store_*`). Tanks made on Mars start empty. The systems panel shows sols left. Mission Control mentions them at half and a quarter; the soft net is the 10-sol reserve, then emergency landers (30 sols, 3 sols away).
- **Ice:** GAR-Y's order is now "Survey zone". Under these rules it takes noisy readings in a 3 by 3 grid and plants no flags, and two false zones join the orbital ones. The hand corer (`scripts/hand_corer.gd`): hold E outside, away from the base. Cores show on the survey map. *Decided 1 Nov after the playthrough:* you can only core within 7 m of a GAR-Y reading, because there should be no hole in Mars without a scientific reason, just as NASA wouldn't core for the sake of it. Elsewhere there is no prompt, and holding E does nothing. A good core is half the site's best ice, capped at 25 %, so the plains (peak 32 %) can be found.
- **Survey stakes (2 Nov, playtest: "no way to see where he has surveyed").** Each reading leaves a stake (`scripts/survey_stakes.gd`): a pole with a beacon, grey weak, amber faint, blue strong, blinking until cored, then steady for ice or dark for dry. Within 30 m a ground ring marks the 7 m you can core in. Wrist pad up (hold T) + F pings every stake within 400 m: they flare and show through the ground with distances for 6 s. The strongest uncored stake is on the compass. The Tab map has an ice survey layer (L): likely zones as dashed circles, readings with their rings, cores ticked or crossed, and GAR-Y's stops still to go; G there sends GAR-Y to survey the zone under the cursor (within 300 m of it). Holding E on unsurveyed ground says why, and where the nearest stake is. Stakes are built from the saved readings and cores, so nothing new is saved.
- **Steps:** a good core gives ice (and the crew rover's lander); 12 h of extractor water gives the Water Reclaimer plan; water self-sufficient gives the oxygen plan; 24 h of a regolith intake with water gives the food plans; all four end chapter one with Mission Control's report.
- **Tutorial:** under these rules it adds Unpack the crates, Place the fabricator and Start a fabricator job, and leaves out the drill, Life Support and air steps.
- **Tests:** `tests/start_and_chapter_one_test.gd`; `tests/tutorial_test.gd` follows the new steps.
- **Still to do:** the HQ Blender models (the fabricator, the hand corer, crates in three sizes; the crates use the old cargo crate model scaled for now); Mission Control voice lines (the news is shown as notices for now).

## 12. Decided after the build (1 Nov 2026)

- **The food step is hands-on** (replacing "a regolith intake runs for a day"): scoop regolith into a sample bag outside (hold E, a bag from the tool bench), carry it in, wash it at the Workshop Bench (E, about 20 L of water), then test-grow it in a pot in the General Module. A seedling after a sol is the discovery, and it gives the food plans. *Built 1 Nov, simplified:* any core taken after the oxygen step bags its top layer (no separate bag); E at the Workshop Bench washes it (20 L), then E again plants the test seed there; the seedling comes up after 24 h.
- **No inventory screen** (docs/moment-to-moment-gameplay.md: no new screens if a diegetic one will do). Proposed for step 5, samples and the lab:
  - your hands carry one thing (the carry system);
  - a **sample case** with six slots, carried out on EVA. Look down at it to see which slots are full; I gives a short card ("3 regolith, 1 ice core, 2 empty"). A full case means a trip home, so carrying is limited without extra rules;
  - GAR-Y's core shows as a tube in its rack; the crew rover gets a sample drawer with visible slots;
  - back at base, the lab bench (or the terminal until there's a lab) and the journal keep the record;
  - the suit rack shows the EVA kit hanging on it (corer, bags, case): you take what you need before going out.

## 13. Rework after the 2 Nov playtest (design: check before building)

*From a chapter-one playtest, 2 Nov 2026. Decided with the user: the TCU comes in a crate, story plans arrive printed, printing takes minutes instead of hours, each Print Shop runs its own job with a queue, and the Print Shop draws power only while printing. Where this section disagrees with §2 and §4, this section wins.*

**What went wrong.** The player couldn't heat the habitat without printing. No crate holds any heat, and the only heater that can warm a module (the Thermal Control Unit) took about 13 hours to print in the General Module. Printing felt far too slow overall (1–20 game-hours a job). Only one job ran in the whole base, so a second Print Shop added nothing. And a plan the story handed you still had to be printed in full.

### 13.1 The principle: land with enough to stay out of danger

**The landed kit keeps the crew out of critical condition until they're self-sufficient.** Agencies wouldn't land a crew who'd freeze on the first night. The landed stores are the clock: 90 sols in Survival, 150 in Freedom. Printing and the four steps (§5) are how you get **better and independent**, not how you **stay alive** in the first sols.

### 13.2 Survival audit of the crate kit

The habitat sim was run with every crate item placed in a 3×3 General Module plus an airlock and the two solar arrays. It used chapter rules, Aeolis Reach (the region), a solo first crew and 10 sols with no random storms (the audit script is kept out of the repo).

| Kit | Coldest | Battery low | O₂ / CO₂ | Crew |
|---|---|---|---|---|
| Crates as they are | **−9 °C** | 32 % | 20.5 % / 0.04 % | **Evacuated** (cold) |
| + Thermal Control Unit | 20.6 °C | **11 %** each night | 20.5 % / 0.09 % | Fine |
| + TCU and a 2nd Battery Bank | 20.6 °C | 55 % | 20.5 % / 0.09 % | Fine |
| + TCU and 2 batteries, 3-sol dust storm | **−19 °C** | 0 % | fine | Lives (health back to 100 after) |

**Air, water and food** are fine from the landed stores and the Air Recycler. O₂ reserve, water and food all last well past 10 sols. **Pressure and radiation** aren't threatened at the start.

**So the kit gains:**
- **A Thermal Control Unit** in the Life support crate. It runs as soon as it's placed.
- **A second Battery Bank** in the Power crate. With one, the TCU drains it to 11 % every night, so any extra load or a dusty day blacks the base out.

**Dust storms** still beat the starting kit. A 3-sol storm empties the batteries and the habitat freezes. That's the storm's job (forecast, shelter, shed load), but see question 1 below.

### 13.3 Story plans arrive printed

When the story hands you a plan, **its first copy is ready on the build bar at once**, free. This covers:
- sent plans: first walk, sol 10, sol 30, first job
- discovered plans: ice, water, oxygen, food
- plans from Discoveries

The notice reads "New plan: Ice Extractor. One is ready on the build bar." Plans known from the start (the "brought" ones) still print normally. **Old saves:** a plan learned but never made gets its copy when the game loads.

### 13.4 Printing takes minutes, not hours

A job is a short wait, not an overnight one. Feedstock is the real limit. The General Module still prints at 75 %.

**The rule:** every print takes **an eighth of its old time, at least 5 minutes**. That applies to the times in `data/plans.json` and to the mass formula for everything else. The longest print (the Compact Reactor) is 2½ h; most are under 1½ h.

| Item | Was | Now |
|---|---|---|
| Wall Cabin / Portable Heater | 1 h | 8 min |
| Spares kits (×2) | 2 h | 15 min |
| Sleep Station, Utility Rack | 3–4 h | 25–30 min |
| Grow Tray, Large Planter, Methane Tank | 4 h | 30 min |
| Urine Processor, Sabatier Reactor, Solar Array | 8 h | 1 h |
| Air Recycler, TCU, Water Processor, Oxygen Generator | 10 h | 1 h 15 min |
| Ice Extractor, Regolith Intake | 12 h | 1 h 30 min |
| Battery Bank, Atmosphere Processor | 16 h | 2 h |
| Regolith Printer | 18 h | 2 h 15 min |
| Airlock, Print Shop, Compact Reactor | 20 h | 2 h 30 min |

Feedstock costs don't change.

### 13.5 One job per printer, with a queue

- **Each Print Shop runs its own job.** Two Print Shops print two things at once, each at its own room's speed. A second Print Shop is a "brought" plan, so you can print one.
- **A queue of up to 5 per printer.**
  - Add a plan and it waits its turn.
  - Its feedstock is taken **when it starts**, not when queued.
  - An item that can't be paid for when its turn comes waits at the front with "Waiting for feedstock".
  - Removing an item from the queue costs nothing. Cancelling the running job refunds it in full.
  - Spares kits can be queued as often as you like.
- **Which printer:** E on a Print Shop opens *its* screen. You see its current job and its queue, and can add or remove items. The Needed now strip, the search and the tabs stay as they are.
- **The same plan on two printers** is allowed only for spares kits. A plan's first copy is made once (the plan-once rule, §4), so a plan already printing or queued anywhere shows "Printing at the other Print Shop".
- **Removing a Print Shop** refunds what it was printing and drops its queue.
- **Saving:** each printer's job and queue are saved with it. Old saves move their single job to the first Print Shop.
- **Power:** a Print Shop draws 1.2 kW **only while it's printing**. Before, it drew an average 0.4 kW whether printing or not.

### 13.6 Also

- **Heaters you print** (Wall Cabin, Portable) are placed on Low, not Off.
- **The tutorial** under chapter rules gains "Place the Thermal Control Unit", after placing the General Module.
- **Corrections to §4 above:**
  - The heater example ("a 6-hour job … 30 kg") is replaced by the table in §13.4.
  - "One job at a time per fabricator" is now what the game does.

### 13.7 Decided (user, 2 Nov)

1. **No storms before sol 15** under chapter rules. Forecasts can still mention storms building far off, but none reach the base until then.
2. **Queue:** 5 per printer.
3. **Speed:** an eighth of the old times, at least 5 minutes.

### 13.8 One print input: feedstock (decided 2 Nov)

Earth parts are gone, at the cost of some realism: with a fixed 60 and no way to get more, Survival couldn't be played or tested through. Printing takes only feedstock, from four places:

| Source | How much |
|---|---|
| The Print stock crate | 3,000 kg (was 1,500 kg and 60 parts) |
| Recycling (waste sorter and hoppers) | as before, about 90–95 % of sorted plastics and metals |
| A running regolith intake | 150 kg a sol each, while tier 4 has power (`intake_feedstock_kg_per_sol`) |
| Each crew member who lands | 400 kg in their lander (`crew_feedstock_kg`), said in the landing message |

Old saves: one saved while Earth parts existed, with the crate unpacked, gets the extra 1,500 kg on load. Plan costs in `data/plans.json` keep their feedstock; their Earth-part figures are deleted.
