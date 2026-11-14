# Outpost One: Mars, master design

*Decided with the user over one long session on 3 Nov 2026, after reading Charlie Cleveland's GDC 2019 talk "The Design of Subnautica" and Jesse Schell's "The Art of Game Design" (see `Game Design Documents/`). It replaces `docs/core-loop.md` as the master design. Where any other design doc disagrees, this one wins. Nothing is sacred: any existing system can change to serve this.*


*Companion: `docs/systems-and-items.md` has every system, its numbers, the rooms, field kit, instruments, vehicles, voices, the item-by-item table and the code rebuild order.*

**Why a revamp.** The game began as a freeform habitat builder, and exploration, a starting story and survival were added on top. They don't fit together, and the player is handed nearly everything at the start (every crate, most plans, 3,000 kg of feedstock, 90 sols of stores), so it's too much and too easy. One example from the 3 Nov playtest: the site plan's ice overlay shows ice that the 7 m core rule won't let you drill.

## 1. Pillars

> **Superseded 14 Nov 2026 by `docs/pillars.md`** ("Go further. Make it home."). The pillars below are history. Where they disagree with `docs/pillars.md`, that doc wins. That includes §4 (walkers, rooms, materials collection), §5 (plans) and §7 (the clues lead outward).

**The spine · Decided 8 Nov** (the user, stepping back after the game drifted from builder to survival to story: the tagline is *design, live, work and survive on Mars*). Every feature serves at least one verb, or it waits.

| Verb | What it is in play | Systems |
|---|---|---|
| **Design** | Plan and build the base the crew will land to | build bars, modules, Print Shop, corridors |
| **Live** | Your routine at home: the lander, then the module | needs, sleep, panels, the slate |
| **Work** | The mission: the four goals, samples, surveys, GAR-Y | lab, Discoveries, Journal, GAR-Y's orders |
| **Survive** | The margin outside | suit air, the dark, storms, wear |

- **The story runs alongside the base,** on its own threads. The base is free play beside it.
- **One voice you get to know: Castellanos** in the orbiter, on the radio, both ways, with replies that shape what they say next (docs/radio.md). They react to what you design, how you live, what you find and your close calls.
- **Who speaks:** Castellanos, Notes (your own thoughts) and letters. **ARDEN is cut right back:** no voice lines, just alarm tones and the panels.
- **The first four days are a curated tutorial** (docs/opening-days.md): story time, hand-holding, each ending in sleep. Day 5 opens the game.
- **No new systems** until the guided days play end to end.

The three pillars below still hold as feelings; the spine is how they're played.

Subnautica wrote down three pillars, each tied to an emotion, but built only one of them properly. We do the same.

1. **First to see it: the wonder of the untouched.** This is the main pillar: exploring, sites, caves and discoveries. Subnautica's unknown is terror, of what's in the dark. Ours is awe, of what no one has ever seen.
2. **Mars will kill you for it: exposure.** This is the price of exploring: cold, thin air, dust, radiation, night and distance. It's never a fight, always a margin you manage.
3. **A foothold: hard-won self-reliance that becomes a home.** The base is built from what you went out and brought back.

**In the user's words:** being alone, with the chance to discover the wonders of a new planet before anyone else, at the risk of a planet whose natural elements will kill you.

## 2. The premise and the opening

**The story · Decided 7 Nov** (the user: "you were always sent to land after the walkers had established and built the base"; Mission Control "wouldn't let you pick your landing site … with blurry photos").
- **Cargo first, then you (timing fixed 10 Nov).** As in NASA's Design Reference Architecture 5.0, the cargo left a launch window ahead of the crew. It waited in Mars orbit, and its pallets dropped on a schedule in the months before you arrived, so the walkers could gather them and build the base fresh, ready for you. The storm went global during solar conjunction, the real two weeks or so when the sun blocks Earth's radio to Mars. Nobody could hold the drops: the last pallets came down blind into the dust, and the walkers stalled mid-task. Nobody had walked on Mars before you: you're the first human there.
- **You're the commissioner.** You were always to land after the base was built. Your pathfinder lander would touch down beside the finished base, walk in and commission it (bring each system up, check it, sign it off) with GAR-Y. **Changed 8 Nov (docs/opening-days.md):** the lander is a self-sufficient lifepod (a power cell, oxygen remade, water recycled; only food runs down). It will keep one person going about as long as they like, but it's no base: one seat, no room to grow. The pallets are the General Module's cargo.
- **The pathfinder (decided 10 Nov, replacing "two landers").** Castle tells you this in the first call (data/radio/day1.txt d1_relock).
  - **Both landers land the same way.** Cameras pick out safe ground (terrain-relative navigation, as on Perseverance), the base's beacon gives a pinpoint touchdown, and a person can take the controls for the last minute.
  - **The crew lander is lean, because Mars landings are mass-limited.** It has seats for all six and a few days of air, and is built to set down beside a finished base on its beacon. Without the beacon it could land kilometres off target, as yours did: people with days of air, far from shelter.
  - **Your lander is the pathfinder.** The plan always sent one person first, so as not to risk everyone on an unverified site. It's small and over-equipped on purpose: it recycles air and water and has a power cell, so it keeps one person alive for months wherever it lands, off target included. That's what happened.
  - **The crew wait for three reasons:**
    - no base to land beside;
    - a dead beacon;
    - flight rules: no crewed landing until someone explains why every cargo landing went wrong. That's NASA's anomaly-resolution habit, and it's the buried heart.
  - **Their ship can wait.** It's stocked for the whole mission and an abort-to-orbit stay.
  - **Radio.** A relay satellite, landed in the plan with the cargo, hangs over the Reach.
    - It carries Castle's voice and your suit's telemetry (position, air, helmet cam) all day, which is how she watches your air. The lander's mic carries night sounds too, like the walker's grinding.
    - The crew's ship is in NASA's one-sol elliptical parking orbit: high over the Reach most of the sol, in touch through the relay, and one close pass a sol, when Rao's long lens gets close-up photos. Once a sol, from an hour after sunset for two hours, it's behind the planet and there's no radio (built 10 Nov, scripts/radio.gd `los_window`):
      - Calls wait, Castle's air warnings included; your suit's own alarms still sound.
      - A call already on air is never cut off: she finishes, and the link drops when the call's over (`gone`). Of several held air warnings only the latest is said. Calls that never got through are let go when you wake, except day 4's sunset talk.
      - If you're outside, Castle gives you a heads-up beforehand (`los_soon`) and checks in when she's back (`los_back`).
      - The slate's status bar shows ORBIT BACK hh:mm, and its Comms page shows the window.
      - There's no radio in caves either.
  - **Why you landed anyway.** When the dust thinned, Houston said go: that's what a pathfinder is for (d1_relock).
  - **The way home (10 Nov).** Outpost One is a long stay: the crew came to live there for years, with later crews on later windows. The ascent vehicle was in the cargo and is out there with one of the lost walkers (d4_sunset). Finding it can be later content; "go home" is still not an ending.
  - **In game, your lander is called the Pathfinder** (scripts/crew_lander.gd, data/equipment_catalog.json; the code keeps crew_lander ids).
  - **The honest stretch.** NASA would never plan to leave one person alone. It's the pathfinder role plus the storm, and Castle on telemetry stands in for a buddy.
- **The storm hit while you were on your way.** You launched on schedule. Months into the cruise, a planet-wide dust storm swallowed Aeolis Reach (like the one that ended Opportunity in 2018). Contact with the walkers and the pallets' beacons was lost: the walkers stalled mid-task and were damaged, and pallets were strewn across the Reach. You can't turn back mid-transfer, and Earth can't send more for 26 months.
- **The storm got the blame, but it wasn't alone · Decided 7 Nov, science fixed 8 Nov** (docs/interference-options.md, option A). With the sun and stars hidden, the walkers and the pallets' guided descent fell back on fixing their position by matching the ground's magnetic field to the orbital magnetic map. The Reach's crustal field is far stronger and stranger than that coarse map, so the fixes jumped: each walker curved off and stalled lost. A solar storm the same week, funnelled down by that field, fried the base's landing beacon. Nobody knows this at the start; it's the buried heart, found late.
- **Knocked off course.** You were to home in on the base's landing beacon, but it's silent, and the dust-thickened air throws your entry long. The descent falls back on the lander's own cameras: they check the ground below in real time (like Perseverance's terrain-relative navigation) and show the safe spots within your fuel. You choose one, or the autopilot does. Where you come down is where your new base starts, and where the walkers will bring everything home. The planned site is somewhere out in the Reach: a later find.
- **What you know of the land.** Only what the cameras saw coming down is sharp. The rest is the mission's old pre-landing survey: the land's shape, coarse and blurry, with nothing on it (no ice, iron or cargo). Exploring sharpens the Map. There's no menu screen for choosing where to land (Creative keeps its map). **Opening review, 8 Nov (the user's answers):** the Map's first sol is the blurry survey with the camera patch sharp, not a dark Map; the cabin has one seat (you came alone), the bench as your bed, the locker, the water and one ration crate, with the floor left open; the descent's "Skip" box is never ticked for you; and touchdown runs in paced beats — a few seconds' silence, ARDEN's link-lost line, the slate lighting with the text, "air" once you lower it, "parachute" when you look out or open the hatch, the sunset thought at sunset.
- **The guided days · Redesigned 8 Nov, not built yet** (docs/opening-days.md). Day 1 the cargo and the sunset call; day 2 finding GAR-Y; day 3 the walker and choosing where you'll live; day 4 the module set down, commissioned and furnished, and the four goals. Story time: dusk comes when the day's beats are done. Day 5 opens the game. **Where the parts below disagree, opening-days.md wins.**
- **Landing to the first room, in three parts · Decided 8 Nov** (a working idea for us, never shown; the player sees only a "SOL 2" card at dawn; `mars_world.opening_part()`). Nothing from a later part is visible, known or on the Map before that part starts.
  1. **Down (sol 1).** Touchdown, the slate, then air (pallet 1's cartridge); power before dark (pallet 2), GAR-Y (pallet 3) and tools (pallet 4); the first sunset and night. Known: the parachutes, pallets 1–4, the near ground. Not known: the walker, which waits ~2.6 km out, hidden.
  2. **The lifepod days (sol 2 to about 4).** A "SOL 2" card at dawn and the water dial low. Ice by hand, salvage, the tiny printer, samples, GAR-Y's sled; the iron and ice threads. Ends when three of the four jobs are done and the walker moves at 03:00.
  3. **Walker 1.** Its tracks and a shed panel at dawn; photograph them for the orbiter, follow them, or see its lamp from high ground. It's lost, not broken: its magnetic map-matching was fooled by the Reach's field (option A above). Climb its ladder, sit at the front, and on its nav screen fix true north from the sun (or Phobos), then match landmarks you've been to; the screen shows how far off its position fixes were, a quiet seed for the buried heart. Set the lander as home and it walks there with its headlights on, you riding at the front if you like. Choose the spot; it sets the General Module down; the first night in a real room.
- **Why you go out on the first sol.** At touchdown (Castellanos, once the link re-locks; 8 Nov) you hear plainly what the lander is for, and that the base is in the pallets and the walkers. The slate holds the mission's cargo manifest: the 12 pallets and what each carries, each greyed out until found. It reads like paperwork, not a quest list; Notes stays your inner voice.
- **You land fine; the cargo isn't there.** The lander cabin is your lifepod: safe, but too small to live in (8 Nov).
- **The first pallet is in sight.** A cargo parachute lies draped over a nearby ridge, and that pallet holds life support. Parachutes and backshells are the game's landmarks, seen from far off (NASA photographed Curiosity's from orbit). They do the job of Subnautica's Aurora, with no crash and nobody dead.
- **Pallets hold everything:** the habitat, power, life support, the Print Shop, comms, GAR-Y, the rover. Recovering one unlocks its kit and plans. A damaged one needs repairing.
- **Big pieces ride walking carriers,** like JPL's ATHLETE (a six-limbed walker built to carry habitat modules). The storm left them stranded and damaged. You find one, repair it with a short procedure, and it walks itself to your base at walking pace, with GAR-Y leading. Bringing it home is a find-and-repair moment, not a hauling job.
- **Smaller things** are carried by hand, put in the rover, or towed by GAR-Y on its sled.

### Meeting GAR-Y

GAR-Y is in one of the pallets. You meet it one of two ways, and both should be a big moment:
- **you find it** in or near its pallet; or
- **you black out on an EVA before finding it, and GAR-Y finds you.** It had been out there all along, searching for the crew lander. You wake with it beside you.

After that, its usual rescue applies.

**How the big moment plays · Decided 7 Nov** (the user: finding it was "very anti-climactic, but it should be a wonderful moment for the player to learn that they're not alone on Mars").
- **Through your own eyes, held.** No camera cut and no third person. The HUD fades and you can't walk, while your view is drawn gently to GAR-Y. It lasts about 25 s.
- **At pallet 3:**
  1. The lid comes off on a folded, dust-caked shape.
  2. A lamp flickers. The mast lifts and the body unfolds.
  3. The head scans the dunes, finds you and stops.
  4. A questioning chirp, then it rolls out, circles you once, does a happy spin and parks at your side.
  5. The music swells, "GAR-Y" fades up for a moment, and the Notes thought becomes "I'm not alone out here."
- **If it finds you first:** you wake in the cabin (the wake-up below), and a strange little robot is sitting at the hatch watching you, its lamp blinking. It chirps, rolls closer and nudges you, and the same thought and title follow. Its pallet is then empty.

**Waking up · Decided 7 Nov.** Every blackout ends somewhere sealed: the hatch is always shut behind you. Waking is a short scene of its own:
1. Muffled sound in the dark: fans, the latches clamping, air hissing back.
2. Your eyes open blurred, lying down.
3. You sit up slowly and breathe hard.
4. Then GAR-Y's remark, or its introduction if this is how you meet.

## 3. Finding things

**The one rule:** every "what's out there" view (the site plan overlay, the slate's Map, the compass) shows only what you, GAR-Y or Earth have actually found, from one shared record of what's known. Creative sees everything. This fixes the ice overlay at its root. (Built 7 Nov, scripts/known_things.gd: the Map starts as the blurry survey (8 Nov: was dark) and sharpens round where you've been, further from high ground; a named place joins the record once it's within sight. GAR-Y's and Earth's finds reach your Map when they report them to you, so each view stays "what you know".)

- **The map starts blank.** Its data was lost in the storm, and it fills in as you explore.
- **You can pin hints and set your own goals** as markers on the Map and the compass.

How knowledge grows:
1. **Your eyes.** This is a main layer. The land gives real clues: bright scarps where buried ice is exposed, cracked polygon ground, frost in shaded crater walls at dawn, parachutes on ridges. The art must carry these clues, and learning to read them is progress in itself (the Outer Wilds idea).
2. **The radio link.**
   - **At first:** the storm damaged the lander's antenna, so you only get short text when an orbiter passes over, a couple of times a sol. Real rovers work this way.
   - **Once repaired:** fixing the link from the comms pallet brings back Earth's voices, Mission Control's fuzzy cargo areas and orbital hints, and the cast's story threads.
3. **GAR-Y's radar.** It surveys a zone, and the results show as a coarse map on the slate. It also wakes the carriers' short-range beacons when it gets close.
4. **The core.** It confirms depth and purity. The extractor goes on a deposit you've cored, which replaces the 7 m rule.

**Ice comes in a few patches** of different depth and purity, and they may be far from the base.

## 4. Materials and building

> **14 Nov:** where this section disagrees, `docs/rooms-and-equipment.md` (rooms, the walker core, building) and `docs/bases-and-vehicles.md` (several bases, automation, getting materials home) win.


### Materials

| Material | Where from | What it's for |
|---|---|---|
| **Water ice** | a few patches, found | water, oxygen, fuel |
| **Regolith** | everywhere, via the regolith intake | bulk print stock, shielding, shells |
| **Iron-rich rock** (haematite) | outcrops, found | metal parts, frames, tanks |
| **Salvage** (Earth-made electronics and parts) | cargo pallets, later resupplies | batteries, electronics, advanced machines |

Recipes mix them (a battery needs salvage and metal), so each material gives a different reason to go somewhere. Amounts stay modest: tens of kilograms in a suit, a few hundred in the rover.

**Never a hauling game:** moving things is a one-off build or event, never a repeated chore.

### Getting water home

Two options, still open: **a heated pipe** you lay point to point (it costs per metre and needs power to keep the water from freezing), or **an outpost at the ice** (extractor, tank, solar panel and shelter, a second home you service). To decide once the materials have numbers.

### Building

- **Building becomes a slate app, Build,** with two views:
  - **Plan:** the overhead floor plan, using today's drawing tools (rooms by cell, click-to-click corridors, windows). It only covers ground you've explored, because the slate draws it from your own survey.
  - **Look:** first-person AR through the slate's camera, for placing equipment and outdoor pieces exactly. Tablet AR exists today, so it's grounded.
- **Drawing is planning.** Placing a piece stakes it out. The work happens in the world: carriers set modules down, you fit printed equipment with a short procedure, and GAR-Y does groundwork later.
- **Building can happen anywhere you've explored,** including outposts away from the base.

## 5. Progression

> **14 Nov:** plans now come from found cartridges, the story and core upgrades (`docs/pillars.md`, `docs/rooms-and-equipment.md`). The Engineering Bench study step is cut, and there's no Earth resupply.


**Plans come from four places:**
1. **Pallets:** each one brings the plans for its kit (the mission's manifest, piece by piece).
2. **Discoveries:** finding and analysing Mars materials unlocks the things made from them (ice gives the extractor, haematite the smelter).
3. **Earth's teams,** once the link is fixed: plans and requests in answer to what you've found.
4. **Studying damaged kit:** bring a broken unit from a wrecked pallet to the Engineering Bench and work out how to print your own. This is our grounded take on Subnautica's fragments.

**The Print Shop starts tiny,** with the lander's tool kit (a repair kit, sample bags, a spare O₂ bottle), and grows from those four sources.

**Steer, don't tell.**
- The Goals checklist and the step-by-step tutorial go. Early direction comes from the situation: air running low, a parachute in view, orbiter texts.
- The slate's Goals app becomes **Notes, your inner voice** (decided 7 Nov). It's a notebook page of your own written thoughts and the threads that guide you, never a quest list:
  - **3 to 5 open thoughts at a time,** in the first person and hedged: "Parachute on the ridge north of the hatch. Life support, I hope."
  - **No ticks, counts or markers.** Pins are your own, on the Map and compass.
  - **Reactive:** a thought changes when you act, even out of order ("Found it. Cartridge is heavy."). It reads the who-knows-what record (systems-and-items §10f).
  - **An answered thought becomes a Journal page.** Every answer raises a new question (Schell's Lens of Curiosity).
  - **Earth's requests appear as your reaction to them:** "Earth wants a crater-wall sample. If I'm passing."
  - **Written, never spoken:** you're silent apart from short replies (systems-and-items §10e).
- Optional hints, in Settings, are the only remaining help.

**Chapters are no longer visible.** Milestones become story beats: radio reports and events.

## 6. Survival as training wheels

The pressures change in kind as you go, and each fades once a machine takes it over:

| When | Pressure | What fades it |
|---|---|---|
| Hour 1 | **Air:** the cabin lasts about a sol | the life-support pallet |
| Night 1 | **Cold and power** | the power pallet: solar and batteries |
| Sols 2–5 | **Water:** the lander's tank runs low | the first ice and the extractor |
| Weeks | **Food:** rations from pallets | the greenhouse |
| Later | **Wear, spares, storms** | servicing, the Print Shop, forecasts |
| The whole run | **Radiation** | shielding, and choosing when to go out |

- **Five survival needs:** air, warmth, water, food and sleep. Washing, fresh food and comfort only lift wellbeing; they never hurt you.
- **The deep chains stay in the sim** (urine processor, waste sorter and so on), as "closing the loop" upgrades unlocked later, not day-one chores.

## 7. The story

> **14 Nov:** the heart's clues are laid outward across the Reach, and the ending happens in the deep: you make it out, barely (`docs/range-ladder.md`).


The story is several separate threads, each started by something you do or by a timer, so every run gets its own slice through them:
1. **The storm:** what happened to the cargo, and Earth's apologetic search. Starts at landing.
2. **The link:** orbiter texts, then the cast's voices once the comms are repaired (docs/mission-control-voice.md).
3. **GAR-Y:** found or finding you, and its personality.
4. **The wonder:** discoveries that lead from an ancient lakebed to a lava tube and end in strong evidence of ancient microbial life. Real science only.
   - **The buried heart · Decided 7 Nov** (docs/interference-options.md, A): the interference that wrecked the landing is a huge, ancient, cold, magnetised intrusion under the Reach, with a much younger, deeper magma pocket beneath it (science fixed 8 Nov). Clues from sol 1 (Walker 1's nav log with jumping fixes, its curving tracks, a rare green aurora, Castellanos's radio-noise jokes), a trail through the walkers' nav logs, a placed magnetometer and a magnetic Map layer, then the reveal: the young pocket's heat, rising through the old body's cracks, fed the hot springs behind the life find. In the storm's return the aurora warns of a solar storm; in the ending the crew land by your magnetic map.
5. **The crew:** the people who were meant to land wait in the orbiter and talk to you while you work and drive. They come down only in the ending, once the heart is understood and the way down is safe (docs/systems-and-items.md §10e).
6. **The storm returns:** the next dust season, the big late test.

**One ending · Decided 7 Nov** (replaces the two endings; the user: make the buried heart "the only ending and really something that would become the player's goal"):
- **The goal is to bring the crew down safely.** You were always the commissioner, sent first on a small lander. After every cargo landing went wrong in a way the storm doesn't explain, the flight rules hold the crew in orbit until someone on the ground works out why. The mystery is the blocker.
- **It becomes the main goal late,** not after the first clues. First you set up, build the base, work the other goals and live and work on Mars; the early clues stay small and deniable, and Notes doesn't sum them up until the late game.
- **The end avoids a catastrophe rather than escaping one:** solve the heart, make the way down safe, survive the storm's return, and the crew land. "Go home" is cut.
- **The game doesn't carry on open-ended after it.** How the final act plays is designed when we get there.
- Grounded in Schell's "Multiple Endings Disappoint", Lens #25 Goals, #66 Obstacle and #9 Unification, and the design talks' "the story is the goal".

## 8. Modes and the screen

| Mode | What it is |
|---|---|
| **Survival** | Everything in this doc. |
| **Freedom** | Like Subnautica's: the same game as Survival (scattered cargo, plans earned, materials gathered), just no food or water. |
| **Creative** | The original freeform habitat builder, kept intact: choose your landing site, the full map, every plan, the overhead plan anywhere, no sim, optional story. |
| **Custom** | The rules table, with new rows: cargo scattered or delivered; map hidden or revealed; start harsh or gentle. |

**Missions mode is removed.**

**The slate's apps:**
- **Notes** (was Goals);
- **Map:** fills in as you explore, with pins;
- **Comms:** orbiter text until the link is fixed; the status bar shows the next relay pass;
- **Build:** Plan and Look;
- **Base, Site, Log:** as now.

**On screen:** the crosshair and prompt, captions, the compass strip at the top (always on, even in the lander, so you can always orient yourself; Settings → On screen → Compass chooses what it marks: the lander and airlocks, your pins, things you've found, places you know, distances), the notice line, and **the warning icon row and storm pill** (7 Nov: the base at a glance, systems-and-items §2). **M** raises the slate on Base, the overview. **The Classic HUD setting is dropped.** The wrist pad stays life support only.

## 9. Existing systems: keep, rebuild, cut

**Keep, with light changes:**
- the slate (device, notice bus, Base, Site, Comms, Log);
- the wrist pad, suit O₂ and GAR-Y's rescue;
- the habitat sim (power, heat, air, water, food), wear and spares kits;
- each Print Shop's queue;
- the room and corridor drawing tools and windows, which become the Plan view;
- the Mission Control cast;
- samples, the lab, Discoveries and the journal;
- the crew plan (no size choice since 7 Nov: the story's five wait in the orbiter until the ending; older saves keep their waves);
- the terrain, caves, rover and descent cutscene;
- the mode rules table (`MHGame.MODE_RULES`).

**Rebuild:**
1. **The start:** scattered pallets on walking carriers; the lander cabin as lifepod; knocked off course on the way down (the cameras find a safe spot; no landing menu).
2. **One record of what's known,** feeding the overlay, the Map and the compass; the map filling in as you explore; player pins; ice in a few patches; the 7 m core rule removed.
3. **GAR-Y:** found in a pallet, or it finds you.
4. **Materials:** four materials replace feedstock-only; the regolith intake stays.
5. **Plans:** a tiny start, then pallets, discoveries, Earth and studying damaged kit at the bench.
6. **Building:** the Build app (Plan on explored ground, Look in AR), with assembly by carriers or short fitting procedures.
7. **Comms:** the link starts broken; orbiter passes; the repair starts the threads.
8. **Needs:** five survival needs; wellbeing bonuses; the deep chains as later upgrades.
9. **The tutorial:** the Goals checklist becomes the situation plus Notes, with optional hints.
10. **Modes:** Freedom's rules and Custom's new rows.
11. **Water to the base:** a pipe and/or an outpost.

**Cut:**
- Missions mode and what's left of the M page;
- the Classic HUD;
- the landing map and site choice outside Creative;
- visible chapters and their report screens;
- the 7 m core rule and the full-truth ice overlay in Survival;
- the precursor-crate start, the 3,000 kg crate and the 400 kg of feedstock per landed crew member.

**Tests:** the three already-failing tests (suit "Freedom blackout", weather "card for every save slot", habitat_alerts "voice lines for bunks and worn") get triaged as their systems are rebuilt.

## 10. Build order: minutes of fun

From Subnautica: build a rough playable version first with placeholder art and goals, then grow it in steps of playtime, playtesting each step.

1. **20 minutes:** landing, the cabin air running down, the parachute on the ridge, the walk, opening the first pallet, air restored. Plus the record of what's known, the map filling in, and pins.
2. **40 minutes, the first night:** meeting GAR-Y (both ways); three more pallets; night power from the solar blanket; the sunset with GAR-Y.
3. **1 to 1.5 hours, the lifepod days (sols 2 to about 4):** you live out of the lander and get to know the land round it. You find the things a habitat will need but can't use yet (iron, ice in bulk, a cave), and each one becomes a thread in Notes. Water by hand, the tiny Print Shop in the lander, first samples, and GAR-Y learning its jobs.
4. **About 2 hours, the first room:** the walker found (its tracks, a photo from the orbiter, then its lamp from high ground), repaired and walked home; the Plan view on explored ground; the General Module set down. Its plans open your threads: "now I can get that iron".
5. **Then:** the four materials in full; studying damaged kit at the bench; the comms repair (orbiter text, then the cast's threads); the water link home; food, wear, storms, the wonder thread, the storm's return and the endings.

**Why building waits (decided 7 Nov).** Subnautica's team found building "got in the way of the exploration", because the game is about discovery. The lander is your lifepod, so you lean on it for a while first. Building arrives as the answer to threads you found yourself, not as the first job.

**The shape of a sol (decided 7 Nov).** By Schell's Lens #61, the Interest Curve, which repeats at every scale ("fractal"): each sol has its own small curve inside the game's big one.
- **Morning, a pull:** a pressure or an open thread in Notes at dawn.
- **Midday, a high point:** a find, a repair or a moment.
- **Dusk, closure:** back to shelter, the sunset, and sleep as a cut. Firewatch places its cuts "at points of closure or tension".
- **Checked against it:** every new step is checked against this shape, and no sol should be flat.
- **The big peaks:** pallet 1 and air; meeting GAR-Y; night one survived; the walker coming home; the first room.

**Throughout:** Creative stays playable (it's mode rules), and Missions mode and the Classic HUD are removed early, so there's less to maintain.

## 11. Open questions · **All settled 3 Nov** (details in docs/systems-and-items.md §15)

1. **Water home:** a heated pipe for near ice, an outpost with its own tank for far ice.
2. **Carriers:** 3 walking carriers (General Module, regolith printer, power kit), each with one fault you fix by hand. Once fixed, it walks home within the sol.
3. **The authored map:** 25 places and about 12 pallets (systems-and-items §9.3). The first pallet holds life support for the lander, food and water, and the sampling tools.
4. **Material numbers:** a first set of carry limits and recipe sizes, tuned in playtests.
5. **Resupplies:** Earth sends a lander about every 25 sols once the link is fixed.
6. **Old saves:** they don't carry over. They belong to v0.3.0, which stays tagged and playable.

## Sources

- Charlie Cleveland, "The Design of Subnautica", GDC 2019 (transcript and slides in `Game Design Documents/`).
- Chris Remo, "Interactive Story Without Challenge Mechanics: The Design of Firewatch", and Jane Ng, "Making the World of Firewatch" (GDC; transcripts in `Game Design Documents/`). Lessons used: the player as a participant, not an archaeologist; reactivity; one record of who knows what; talks timed to travel; landmarks first; evidence trails; a world that changes; a full-quality slice first (docs/systems-and-items.md §10f, §9.2, §14).
- Jesse Schell, "The Art of Game Design: A Book of Lenses". Lenses used here: #1 Essential Experience, #7 Tetrad, #9 Unification, #4 Curiosity, #5 Endogenous Value, #71 Freedom, #72 Indirect Control, #61 Interest Curve, #32 Meaningful Choices, #33 Triangularity, #46 Economy.
- Further viewing:
  - "'Subnautica' Postmortem" (Jonas Boetel, GDC 2019);
  - "Curiosity-Driven Exploration: The Design of 'Outer Wilds'" (GDC 2020);
  - "A Long Dark Road" (Raphael van Lierop, GDC 2018);
  - "'Pacific Drive' Under the Hood" (Seth Rosen);
  - Astroneer's crafting talk (GDC);
  - Breath of the Wild's GDC 2017 talk;
  - Unknown Worlds' "How We Approach Story".
- Mars background: NASA's Design Reference Architecture 5.0 (cargo landed ahead of the crew); JPL's ATHLETE; the 2018 global dust storm.
