# Outpost One: Mars, the pillars (14 Nov 2026)

*Agreed with the user on 14 Nov 2026, after the stock-take (`docs/stock-take-2026-11-14.md`). This replaces the 8 Nov spine in `docs/master-design.md` §1. Where another doc disagrees about the pillars, this one wins. The details of each system (numbers, room list, plan list) are designed next, one area at a time.*

## Why a rethink

- **From playing the build:**
  - the lope works, and players liked it;
  - the open game after the guided chapters feels empty, with nothing pulling you anywhere;
  - building (how you get modules, room types, how equipment works), the habitat's systems and how the suit works inside and outside all need redoing;
  - survival has to know clearly whether you're inside or outside, and whether you're suited.
- **From real Mars and NASA material:**
  - **CHAPEA** (NASA's year-long crew analog in Mars Dune Alpha, a 3D-printed habitat): a crew of four with private quarters, workstations, a galley and food-growing stations. The crew handle maintenance, samples, rare planned EVAs, limited resources and long gaps in contact with Earth.
  - **PROMISE** (NASA's planned nuclear-powered polar rover for the Moon): a robot that maps and explores far ahead on its own.
  - **Real places, real hazards, and robots doing the heavy work.**
- **The old spine** (design, live, work, survive, plus three feelings, plus exploring) named eight things as "main", so nothing was.

## The heart

**Go further. Make it home.**

Exploring is the heart of the game. Range is your progression: each thing you find, build or fix lets you reach further, and the wonder is always at the edge of your map. The base is home, and it's also your launch pad.

Every feature serves one of the three pillars below, or it waits.

## The three pillars

### 1. Go further: first to see it (wonder)

- **Range is progression.** A worked example:
  - sol 6, about 1 km on foot;
  - better suit packs and stake trails, 2 km;
  - ropes open a cliff route;
  - the pressurised rover reaches the far side (4 km), and an outpost lets you stay there;
  - ropes through a skylight take you down into the lava tube.
  
  The ladder is in `docs/range-ladder.md`.
- **Science points further.** Analysing a find tells you where to go next: layered clay suggests an old lakebed downstream, and then you find it. Finds also unlock plans. The four goals become **four trails of places** across the map, each with its owner in orbit. The Journal records each trail.
- **The story pulls outward.** The buried heart's clues sit past your current reach, so following the story means equipping to go further. Examples:
  - a crashed lander's descent log 3 km out;
  - a magnetic anomaly beyond the dunes;
  - the aurora, seen only from high ground.
- **The lope stays** (traversal phase 1), along with the rest of `docs/traversal.md`.

### 2. Mars sets the margin: Mars will kill you for it (exposure)

Survival is strict outside, and the line between inside and outside is clear. There are three states:

| Where you are | What keeps you alive | What can go wrong |
|---|---|---|
| **In a hab** | the hab's power, then air, then heat | only what you or Mars cause, such as skimping on batteries before a dust storm or a seal you never serviced. The cabin air falls over hours with alarms, so you suit up indoors and fix it, or go to the lander. |
| **In the pressurised rover** | its own air and power | running it dry far from home |
| **On foot, suited** | the suit's air, heat and battery | terrain, the dark, dust and cold all change how fast they drain |

- **You can suffocate at home,** but never at random. The hab is only as safe as its supplies. Random faults (CHAPEA-style surprises) can be added later.
- **The suit is light touch.** It goes on and off at the airlock in a couple of seconds. No suiting-up chores.
- **Hunger, thirst and tiredness stay, as a pull home.** They set how long a trip can be: you pack food bars, and you sleep before a long trip.
- **The lander stays a lifepod** you can always fall back to.

### 3. Make it home: a foothold (a home and launch pad built from Mars)

The base is home, and it exists to send you further. Every room or machine answers one of these questions:
- How does this get me further?
- How does it help me understand what I found?
- How does it help bring the crew down?

Examples: a suit-port airlock (faster turnaround), a garage (rover charging and repair), the lab (finds that point onward), the Print Shop (stakes, ropes, packs), a greenhouse (food for longer trips), and bunks plus a landing pad (the ending).

**Walkers seed bases. One walker, one base.**
- Each walker carries a **base core**: an airlock, a life-support node and a power hub.
- At the spot you choose, the walker kneels, sets the core down and folds its legs into it. The walker *becomes* that base's heart, so nothing is left standing on the build site.
- Walker 1 seeds the main base, where the crew land.
- Each walker you find and fix later lets you start an outpost: an ice-wall camp, a cave refuge, a station at the life find.
- The number of bases depends on how many walkers you find, not on a timer.
- This is NASA-plausible: JPL's ATHLETE concept is a six-legged robot that carries habitat modules.

**Rooms come in two kinds.**
- **The only rigid Earth module is the walker's core** (airlock, life support, power hub), one per base.
- **Inflatable liners under a printed regolith shell** add living space and shielding. Real studies pair these two because printed regolith alone can't reliably hold air.
- Base size grows with what you build locally, not up to a fixed cap.

**No Earth resupply, and never stuck waiting.** Everything from Earth is already on Mars, scattered by the storm. Nothing makes you wait for a launch window or punishes you for missing one.

**Plans are things you find, then you need the materials to build them.** They come from three sources:
1. **Plan cartridges:** data modules in crashed cargo and wrecks, each holding a plan. For example, the greenhouse cartridge is in a lander's nose.
2. **The story:** a find makes Earth's engineers draw you a plan, and Castle relays it ("Achterberg's team drew you a smelter").
3. **Core upgrades:** fitting an upgrade (a found plan plus materials) to a base's core opens room types at that base, with no limit (`docs/rooms-and-equipment.md`).

What you can build always follows where you've been. The Engineering Bench "study damaged kit" step is cut.

**Materials: a range, as in `docs/master-design.md` §4.**
- Water ice, regolith, iron-rich rock and salvage.
- Each one is a reason to go somewhere.

**Collection is automated.**
- You place an extractor or a miner on a deposit you've found, and it fills its own hopper.
- Hauler carts run it home along your trail by themselves, into one shared store. The carts are simple autonomous cargo rovers, built from a found plan.
- You go out to find new deposits, not to make supply runs. Never a hauling game.

**Building is easy, not a chore.** Place a piece with the build bar. If the store has the materials, it goes up quickly, partly at once and partly finished by the robots while you carry on. You never carry parts to it.

## Robots and vehicles

The robots do the heavy work; you do the fine work (cores, photos, anchors, first footsteps).

| Robot or vehicle | Its job |
|---|---|
| **Walkers** | carry a base core to a spot and become that base |
| **GAR-Y** (he/him) | as now: companion, scout, "Show me", radar survey, cores, the blackout rescue and his personality. He **grows with upgrades** from found plans: deeper radar (and the magnetic layer for the heart), a winch, a longer battery, a second sample arm. He doesn't ferry materials. |
| **Hauler carts** | ferry materials from the machines at deposits to the store, each along one route |
| **Pressurised rover** | the big range unlock: a mobile safe pocket with its own air, where you sleep on long trips |
| **Scout drone** (Ingenuity-like) | flies ahead and drops markers to plan routes, feeding the stake trails (traversal phase 3) |

## The story (unchanged, now pulling outward)

- The buried heart is the only ending: the crew are held in orbit until it's understood, and you land them safely at the main base. The game doesn't carry on after it.
- Castle is the one near voice.
- New: the heart's clue trail is laid outward across the Reach (see pillar 1).

## The guided chapters

Keep the four chapters, rewritten to match:
- Chapter 3: you fix Walker 1 and choose home.
- Chapter 4: Walker 1 kneels and folds into the core, you fit the first liner and its shell, and that night you sleep in.

## The old spine, verb by verb

| Old (8 Nov) | Now |
|---|---|
| Design | **changed:** part of *Make it home*. Building serves range and the landing. |
| Live | **changed:** part of *Make it home*. Home is a refuge and a launch pad; needs are a pull home. |
| Work | **changed:** science is now part of *Go further*. Finds point onward, and the four goals become four trails. |
| Survive | **kept, sharpened:** *Mars sets the margin*, with three clear states. |
| Explore (a feeling, not a verb) | **promoted** to the heart. |
| The three feelings | **kept;** foothold sharpened to "a home and launch pad built from Mars". |
| Tagline "design, live, work and survive on Mars" | **replaced** by "Go further. Make it home." |

## Settled rules that still stand

- NASA-plausible and diegetic.
- One ending.
- Castle is the one near voice.
- No text on models.
- The compass is always on.
- Notes are your inner voice.

## Still to design (each its own talk, before building)

1. ~~**The range ladder**~~ done 14 Nov: `docs/range-ladder.md`.
2. ~~**The room and equipment list**~~ done 14 Nov: `docs/rooms-and-equipment.md`.
3. ~~**The hab's supply chain**~~ done 14 Nov: `docs/hab-supply.md` (it also keeps thirst as a body need and makes the mission an international agency's).
4. **The walker core:** its contents and upgrades are settled in `docs/rooms-and-equipment.md`. Still open: how outposts differ from the main base, and the walk-and-kneel moment.
5. ~~**The build feel**~~ done 14 Nov: instant, with a short "watch it build" moment (`docs/rooms-and-equipment.md`).
6. **Automation:** extractor and miner output, hauler carts, how routes are set, and what a cart does when it hits trouble.
7. **The scout drone and the pressurised rover rework.**
8. **The blackout rule** outside the chapters, now that survival is strict outside.
