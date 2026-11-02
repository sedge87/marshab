# The core loop: build, live, work, survive on Mars

> **Replaced 3 Nov 2026 by `docs/master-design.md`.** Kept for history; where they differ, the master design wins.

*Decided with you in six short rounds, 31 Oct 2026. Where the other design docs (`gameplay-loop-brief.md`, `commissioning-and-flight-rules.md`, `mars-science-goals.md`) disagree with this one, this one wins.*

**The direction:**
- **The tagline is the loop:** build on Mars, live on Mars, work on Mars, survive on Mars.
- **Like Subnautica:** you take pride in your habitat and have things to do in it every day. You gear up for meaningful expeditions and come back to do something with what you found.
- **Nothing is sacred:** how the base works, its rooms, assets and equipment can all change to serve the loop.
- **Pressure** comes from your own body, the base surviving, and mission targets. Scarcity is not a main pressure.

## Round 1 · Why: the run and the player's goals

- **Survival is open-ended, in chapters.** There's no fixed ending. Milestones mark chapters (first ice, a self-sufficient base, a second crew), each with a short report. This replaces the 60-sol tour of duty in `mars-science-goals.md` §5.
  - **Late chapters (to settle in round 6):** preparing the base for more crew to land, then a chapter of building a sustainable base for a large crew. Or, like Subnautica's ending, working out a way home, or being sent one.
- **Two records:**
  - **The Mission Control terminal** in the base: your discoveries in four sections (Life, Climate, Geology, Humans), and what each unlocked. It gives Mission Control a real job in the game.
  - **Your personal journal:** a log of your days, what you did and found, with sketches. It's for the story and for remembering the run.
- **Mission Control's teams post a few requests at a time,** as reasons to go somewhere. You choose which to follow.
- **Discoveries unlock four kinds of thing:**
  - **new equipment** (confirmed ice brings a water extractor);
  - **kit from Earth** (science earns requisition for the next lander);
  - **better existing systems** (perchlorate studies raise hydroponic yields; weather data gives storm warnings);
  - **new places:** new sites on the map, natural caves and the lava tube. The region can grow to hold them.
- **Every goal pays back into survival:**
  - Climate gives forecasts;
  - Geology finds ice and building material;
  - Life finds water and keeps the crew safe from contamination;
  - Humans is the base itself.
  The four goals are interlinked systems, not menus or checklists.

## Round 2 · Live and work: the day inside the base

- **A few rounds a sol:** three to five meaningful jobs, each about a minute of hands-on work: swap a filter, tend the plants, run a sample, service a pump. Skipping one costs something (output, wellbeing, a slower lab), never your life on its own.
- **Machines degrade, then fail:**
  - output drops as a machine wears, and you can tell from its readout and its sound;
  - servicing it restores it;
  - ignore it too long and it fails, needing a proper repair (parts, more time).
- **GAR-Y helps, later.** As the base grows the rounds could become a chore, so GAR-Y can learn to do routine servicing while you're in the base. It isn't there from the start; it's something you gain (an upgrade or a discovery, round 5).
- **What you take pride in (all four):**
  - **comfort:** good rooms raise wellbeing (quiet sleep, a window, a proper galley, plants, a gym);
  - **a smooth-running base:** every system green, things made on Mars, little wasted;
  - **personalising it:** decor, layout, photos and posters;
  - **your story on show:** the sample archive, finds on shelves, the journal, mementos from trips.
- **Sleeping quarters become a room of their own.** Noisy rooms next to them (engineering, life support, the workshop) disturb sleep. Living quarters become the shared day room.

## Round 3 · Build: the base and how it grows

- **Precursor cargo start,** as NASA plans it: cargo landers came first and wait nearby, crated. You start in your lander's cabin and assemble the first habitat in a sensible order: power, then the airlock and a habitat module, then life support.
- **The problem to solve:** today everything is available from the start, so you can build it all and be self-sufficient almost at once. Building shouldn't be slow; what's *available* should be limited, and self-sufficiency should be earned.
- **A fabricator makes equipment from plans:**
  - some plans you brought from Earth;
  - some the teams on Earth send;
  - some you unlock through discoveries.
- **The regolith printer makes bulk things only:** radiation-shielding walls, berms, pads and outer shells (as in NASA's 3D-printed habitat challenge). Equipment comes from the fabricator.
- **Lights are automatic:** rooms light up when you're in or near them and dim when empty. A base-wide night mode is on the terminal. The light switches go.
- **Rooms: a general module first.** Room types stay, but a new **general-purpose module** takes most basic equipment, at a cost: it's cramped, noisy, sleep is poor and work is slower. Early on everything goes in one or two of them, like Subnautica's multipurpose room. Specialised rooms are worth building later because they're quieter, more comfortable, faster at their job, or needed for advanced equipment, and some only arrive with their plans. You build one or two rooms at the start and want more as you grow. (Modules plus racks was considered: closer to real habitats, but a big rework of code built around room types.)
- **Self-sufficiency is earned, gently.** You start dependent on Earth, with stores of water, oxygen and food from the precursor cargo. They last long enough that self-sufficiency is a goal, not a countdown: Mars is hostile, but the start shouldn't feel frantic (Subnautica's start has little urgency). Each step to self-sufficiency is a discovery, then a plan, then a fabricator job, then fitting:
  1. ice is surveyed, drilled and tested (Geology, Life);
  2. a water extractor comes next;
  3. then electrolysis for oxygen;
  4. then treated soil for the greenhouse.
  Together the steps are the first chapter, "self-sufficient".
- **The room changes:**
  - **sleeping quarters** are added; bunks move out of living quarters, which become the **day room**;
  - **the small rooms merge:** the galley goes into the day room, and waste management into storage (changed from life support on 31 Oct; see `docs/room-changes.md`);
  - **engineering becomes the workshop:** the fabricator, repairs and the commissioning bench;
  - **communications becomes operations:** the Mission Control terminal (discoveries, requests) and the map table;
  - **the general module** is new;
  - **inner walls can take windows,** which have no effect on heat (from the playtest). The vehicle bay not warming up is a bug, fixed separately.

## Round 4 · Work outside: the expedition

- **Short walks and big expeditions.** Most sols have a short trip on foot or by rover (5–10 real minutes). Now and then you plan a multi-sol expedition: pack the rover, sleep aboard, reach somewhere new.
- **The hands-on work is short procedures:** two to four steps with the right tool, real and quick, not fiddly. You chip, bag and label a rock; set up the drill and hold while watching the torque; level a station and switch it on.
  - **Assisted mode (accessibility):** an option does the steps for you, as games offer for quick-time events. You still choose what to do and where; only the hand work is automatic.
- **Finding what's worth going for:**
  - **orbital hints:** Mission Control's maps show fuzzy areas of interest ("possible ice", "layered outcrop");
  - **GAR-Y's surveys:** it scouts ahead and marks finds;
  - **requests and leads:** the teams' requests, and one discovery pointing to the next place.
  (A handheld scanner was considered and not chosen.)
- **What you bring back is limited, so you choose:** a few sample bags in the suit, more in the rover's sample box, cores carried by hand.

## Round 5 · Grow: kit and reach

- **The walkback limit is shown and logged, never punished.** It's on the wrist and the map, and Mission Control logs breaches and comments on them. Taking risks for rewards is yours to choose: they're 200 million km away and can't do anything about it. The tone is like Alterra's running "debt" in Subnautica: a wry note in the log, not a penalty. This replaces the requisition cost in `commissioning-and-flight-rules.md` §6.5.
- **Kit comes from where it realistically would:**
  - **from Earth on landers** (paid for with requisition): pressure vessels, batteries and electronics: suit bottles, battery packs, rover battery modules, the trailer;
  - **from the fabricator:** simpler things: cache stands, tool kits, brackets, sample cases, spare parts.
- **Commissioning stays, short:** a few steps at the EVA bench (unpack, assemble, check out, fit), with the pressure or electrical test running on the clock. Assisted mode can do the steps.
- **Long-range growth includes all four:**
  - **supply caches** of oxygen and battery, placed along routes;
  - **the pressurised trailer:** sleep aboard, more air, park it as a forward shelter;
  - **forward outposts:** a small shelter module you build at a far site, a second home for the far zones;
  - **GAR-Y's upgrades:** a sled to haul crates, a longer survey range, and servicing in the base (round 2).

## Round 6 · Survive: the pressures

- **Trouble is rare and fair:**
  - most of it is foreseeable: storms are forecast and wear is visible;
  - a real surprise comes every few sols, always with time to respond;
  - bigger events come later in the game;
  - you can lessen it: forecasts from your weather stations, spares on the shelf, shielding, GAR-Y servicing;
  - how often it happens is a game setting.
- **Your body:** the suit and GAR-Y's rescue (built), plus:
  - **fatigue and sleep:** tired slows you, sleep clears it, never a lockout;
  - **radiation dose:** a running dose from time outside and solar events, kept down by shelter and shielding;
  - **injuries:** from falls, a rescue or a rough landing, treated in the medical bay.
- **You choose the challenge when you start a game.** The new-game screen lets you switch fatigue, radiation, injuries and surprises on or off. You can switch one on later but never off again (like survival or hardcore modes in Fallout and Skyrim).
- **The late game is your choice.** At a milestone you choose:
  - **go home:** build or receive an ascent vehicle and leave, with a final report (Subnautica's ending);
  - **or welcome the next crew:** ready the base for a second crew to land (a landing pad, beds, life support for six), then a chapter of growing a sustainable outpost for a large crew, open-ended.
- **Windows, not deadlines.** Requests never expire, but some things have natural windows: dawn frost, a lander's launch window for samples, the season before a storm.
- **No mission clock.** The 60-sol tour is dropped: Subnautica has no time limit, and the narrative handles the end.

## How it fits together

**Build, live, work, survive:**

| | What you do | Why |
|---|---|---|
| **Build** | set up from precursor crates; grow from one general module into specialised rooms; fabricate from plans; print shielding | comfort, efficiency, new capabilities, room for more crew |
| **Live** | sleep, eat, keep wellbeing up, personalise, keep your journal | pride, a well-rested bonus, the story of the run |
| **Work** | a few hands-on rounds a sol; trips and expeditions; the lab; reports to the terminal | discoveries, which unlock equipment, kit, improvements and new places |
| **Survive** | your suit, body and range; the base's stores and machines; storms and surprises | the pressure that makes all of it matter |

**An early sol (chapter one, not yet self-sufficient):**
1. Wake in the general module. The pump next to your bunk kept you up a bit.
2. The terminal: water stores at 70%. The Geology team wants a closer look at an orbital "possible ice" hint 600 m north.
3. Rounds: swap the air filter (it was down to 80% output) and check the batteries.
4. Suit up and walk north with GAR-Y. It surveys ahead and marks a shaded patch. You scrape a frost sample and chip two rocks; the bags are full.
5. Home. In the lab: the frost is water ice, and one rock holds perchlorate. Two discoveries for the terminal.
6. The terminal: the teams send the plan for a small ice drill. The fabricator starts it overnight.
7. The journal fills in your day, with a sketch of the frost.

**A run:**
- **Chapter one, self-sufficient:** ice found, then the water extractor, then oxygen, then the greenhouse. The base spreads out from one general module.
- **Chapter two, further out:** suit bottles and rover batteries arrive and are commissioned; caches go out; the first expedition sleeps in the rover. The delta, the mound and the ice fields open up.
- **Chapter three, a real outpost:** the trailer, a forward outpost, caves and the lava tube, GAR-Y servicing the base. Bigger events: a long storm, a solar flare.
- **Then your choice:** go home, or welcome the next crew and keep building.

## What this answers

**Phase 4, commissioning and flight rules** (`commissioning-and-flight-rules.md` §11):
1. **Hands-on:** short procedures, with an assisted mode. *Decided.*
2. **Test times:** halve them to start (1, 2, 4 and 3 game hours). *Proposed.*
3. **No EVA tool station:** a tool station is needed, but it can go in the general module. *Proposed.*
4. **Faults:** always once the first time, then rarely. *Proposed.*
5. **Walkback:** shown, logged and noticed, never punished. *Decided.*
6. **Rescue and kit:** only the seals. *Proposed.*
7. **Loose spare bottles:** yes. *Proposed.*
8. **The schedule:** landers on the mission plan, gentle; the exact sols are still open.
9. **Mission Control's voice:** open.
10. **The two-person rule:** not while there's one of you; it returns with more crew.

**The four goals** (`mars-science-goals.md`):
- open-ended chapters replace the tour and its graded report;
- the terminal and the teams' requests replace "backing";
- requisition still pays for landers;
- every goal pays back into survival (round 1).

**The gameplay loop brief** (`gameplay-loop-brief.md` §10):
- the lab and field work are short procedures (question 6);
- carrying is limited (question 7);
- suit duration, walking speed, travel time, region size and the elevation source are still open.

## Build order that follows

1. **Playtest fixes:** the vehicle bay's heat, automatic lights instead of switches, windows on inner walls, Ctrl+Z.
2. **New-game options:** fatigue, radiation, injuries and surprises, each switch-on-only once a game is running. Designed in `docs/new-game-options.md`.
3. **Rooms:** the general module, sleeping quarters (with noise), the merges (galley into the day room, waste into storage), the workshop and operations. Designed in `docs/room-changes.md`.
4. **The start and chapter one:** the precursor cargo, stores that run down gently, the fabricator with plans, and the self-sufficiency steps.
5. **Samples, the lab, the terminal and the journal.**
6. **Finding things:** orbital hints, GAR-Y's surveys, requests and leads.
7. **Machine wear and the daily rounds:** degrade, then fail, then service.
8. **Kit and range:** phase 4 (capacities, the manifest, commissioning, the walkback limit shown and logged).
9. **Long range:** caches, the trailer, forward outposts, GAR-Y's upgrades.
10. **Your body:** fatigue, radiation dose, injuries and the medical bay.
11. **Chapters and the late game:** milestones and reports, going home or the next crew.
