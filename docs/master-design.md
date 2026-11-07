# Outpost One: Mars, master design

*Decided with the user over one long session on 3 Nov 2026, after reading Charlie Cleveland's GDC 2019 talk "The Design of Subnautica" and Jesse Schell's "The Art of Game Design" (see `Game Design Documents/`). It replaces `docs/core-loop.md` as the master design. Where any other design doc disagrees, this one wins. Nothing is sacred: any existing system can change to serve this.*


*Companion: `docs/systems-and-items.md` has every system, its numbers, the rooms, field kit, instruments, vehicles, voices, the item-by-item table and the code rebuild order.*

**Why a revamp.** The game began as a freeform habitat builder, and exploration, a starting story and survival were added on top. They don't fit together, and the player is handed nearly everything at the start (every crate, most plans, 3,000 kg of feedstock, 90 sols of stores), so it's too much and too easy. One example from the 3 Nov playtest: the site plan's ice overlay shows ice that the 7 m core rule won't let you drill.

## 1. Pillars

Subnautica wrote down three pillars, each tied to an emotion, but built only one of them properly. We do the same.

1. **First to see it: the wonder of the untouched.** This is the main pillar: exploring, sites, caves and discoveries. Subnautica's unknown is terror, of what's in the dark. Ours is awe, of what no one has ever seen.
2. **Mars will kill you for it: exposure.** This is the price of exploring: cold, thin air, dust, radiation, night and distance. It's never a fight, always a margin you manage.
3. **A foothold: hard-won self-reliance that becomes a home.** The base is built from what you went out and brought back.

**In the user's words:** being alone, with the chance to discover the wonders of a new planet before anyone else, at the risk of a planet whose natural elements will kill you.

## 2. The premise and the opening

**The story · Decided 7 Nov** (the user: "you were always sent to land after the walkers had established and built the base"; Mission Control "wouldn't let you pick your landing site … with blurry photos").
- **Cargo first, then you.** As in NASA's Design Reference Architecture 5.0, the cargo landed ahead of the crew. Its walking carriers were to gather the pallets and assemble the base at the planned site, ready for you.
- **You're the commissioner.** You were always to land after the base was built. The crew lander only had to keep you alive for a few hours: touch down beside the finished base, walk in and commission it (bring each system up, check it, sign it off) with GAR-Y. Its air, water and battery are sized for that, about a sol.
- **The storm hit while you were on your way.** You launched on schedule. Months into the cruise, a planet-wide dust storm swallowed Aeolis Reach (like the one that ended Opportunity in 2018). Contact with the walkers and the pallets' beacons was lost: the walkers stalled mid-task and were damaged, and pallets were strewn across the Reach. You can't turn back mid-transfer, and Earth can't send more for 26 months.
- **Knocked off course.** You were to home in on the base's landing beacon, but it's silent, and the dust-thickened air throws your entry long. The descent falls back on the lander's own cameras: they check the ground below in real time (like Perseverance's terrain-relative navigation) and show the safe spots within your fuel. You choose one, or the autopilot does. Where you come down is where your new base starts, and where the walkers will bring everything home. The planned site is somewhere out in the Reach: a later find.
- **What you know of the land.** Only what the cameras saw coming down is sharp. The rest is the mission's old pre-landing survey: the land's shape, coarse and blurry, with nothing on it (no ice, iron or cargo). Exploring sharpens the Map. There's no menu screen for choosing where to land.
- **Why you go out on the first sol.** At touchdown ARDEN says plainly what the lander is for, and that the base is in the pallets and the walkers. The slate holds the mission's cargo manifest: the 12 pallets and what each carries, each greyed out until found. It reads like paperwork, not a quest list; Notes stays your inner voice.
- **You land fine; the cargo isn't there.** The lander cabin is your lifepod, and its air lasts about a sol.
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

**The one rule:** every "what's out there" view (the site plan overlay, the slate's Map, the compass) shows only what you, GAR-Y or Earth have actually found, from one shared record of what's known. Creative sees everything. This fixes the ice overlay at its root. (Built 7 Nov, scripts/known_things.gd: the Map starts dark and clears round where you've been, further from high ground; a named place joins the record once it's within sight. GAR-Y's and Earth's finds reach your Map when they report them to you, so each view stays "what you know".)

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

The story is several separate threads, each started by something you do or by a timer, so every run gets its own slice through them:
1. **The storm:** what happened to the cargo, and Earth's apologetic search. Starts at landing.
2. **The link:** orbiter texts, then the cast's voices once the comms are repaired (docs/mission-control-voice.md).
3. **GAR-Y:** found or finding you, and its personality.
4. **The wonder:** discoveries that lead from an ancient lakebed to a lava tube and end in strong evidence of ancient microbial life. Real science only.
5. **The crew:** the people who were meant to land wait in the orbiter and talk to you while you work and drive. They come down only in the welcome ending (docs/systems-and-items.md §10e).
6. **The storm returns:** the next dust season, the big late test.

**Endings:** survive the storm's return, then choose:
- **welcome the crew** and carry on, open-ended; or
- **go home:** fuel the ascent vehicle from the Sabatier tank and leave with a final report.

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
- Crew size (now how many wait in the orbiter; the mid-game crew waves are replaced by the welcome ending, see docs/systems-and-items.md §10e);
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
