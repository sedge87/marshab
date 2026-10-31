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
| Outside | GAR-Y, the suit and its bench, the crew rover |
| Stores | water, oxygen and food (§3), fabricator feedstock and Earth parts (§4) |

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

### The fabricator

- **A new piece of equipment:** a bench-sized machine with a build chamber behind a window, a filament or powder hopper and a small working display (the one screen that shows text: the job's progress). It's in the precursor crates.
- **Where it goes:** the Workshop, or the General Module at a cost (slower, like other work there: 75 %).
- **What it uses:**
  - **feedstock:** polymer and metal powder, landed with the cargo, and topped up by recycling. The trash compactor's tiles and the plastics hopper turn waste into feedstock;
  - **Earth parts:** electronics, seals and sensors, which can't be made on Mars. A fixed stock comes with the cargo; later landers bring more.
- **A job:**
  - choose a plan at the fabricator (E opens its screen);
  - see the cost in feedstock and Earth parts, the time and the power draw;
  - start it. Jobs take game hours, so most run overnight;
  - when it's done, the item goes onto the build bar's Unpacked tab.
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
| 1. Ice | Survey an orbital "possible ice" hint and confirm it (§6) | Ice Extractor (`ice_drill`) | Place it on the ice; water flows |
| 2. Water | Water from the extractor tests clean | Water processing (into life support) | Water is self-sufficient |
| 3. Oxygen | Enough water to split | Oxygen Generator (`oxygen_generator`), electrolysis | Oxygen is self-sufficient |
| 4. Food | Regolith washed of perchlorate | Treated soil, then the greenhouse planters and grow racks | Food is self-sufficient |

When all four are running and cover the crew's needs, **chapter one ends**: Mission Control sends a short report, "Self-sufficient", with what you did and how long it took.

## 6. How ice is found before the lab exists

Samples and the lab are step 5. Step 4 needs a simple way to find ice that step 5 can replace:

- Mission Control marks **one or two orbital hints** on the map ("possible ice", about 500 to 800 m out).
- Walk or drive there and **scan with the wrist** (hold E on the frosty ground). A short progress ring, then "water ice confirmed".
- That's the discovery. Step 5 turns it into a sample you carry back and test in the lab.

GAR-Y's surveys (step 6) will find hints of their own later.

## 7. The game modes

| Mode | What step 4 changes |
|---|---|
| Survival | Everything above |
| Freedom | Precursor crates, with **all plans known**; the fabricator still makes them. Stores last longer (about 150 sols) |
| Creative | Nothing: everything available, no stores |
| Missions | Nothing: each mission keeps its own payload and unlocks |
| Tutorial | Starts from the precursor crates; teaches unpacking and one fabricator job |

## 8. Old saves

A save from before step 4 loads **as already supplied:** every plan known, no crates, its stores as saved, and the cargo budget shown as before. It's marked "older rules" on its save card. Chapter one counts as done if the base is already self-sufficient.

## 9. Building it

- **Models:**
  - the fabricator (new, HQ kit);
  - precursor crates in three sizes (rebuild of the existing cargo crates, without lettering);
  - the cargo lander is reused.
- **Data:** the manifest (`data/precursor_manifest.json`), plans (`data/plans.json`: id, source, cost, time), the stores settings in the balance sheet.
- **Code:**
  - unpacking and the Unpacked tab (`interior_build_controller.gd`, `build_controller.gd`);
  - plans gating through `item_unlocked`;
  - the fabricator's screen and jobs (a new script, saved with the game);
  - stores as sols left;
  - the ice hint and wrist scan;
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
