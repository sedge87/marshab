# The guided chapters (A6 rewrite, 15 Nov 2026)

> **22 Nov: the story and chapter order here are replaced by `docs/opening-slice.md`.** Kept as history and for the systems still reused.

*Agreed with the user on 15 Nov (build plan A6). This replaces the 8 Nov redesign below, which stays as history. Every number is a starting point for playtest.*

## Why
- **The 14 Nov playtest:** every chapter's work ran out by early afternoon. A daylight sol is about 15 real minutes, and a chapter's work took about 8, so the rest of each day was waiting for the morning.
- **The bare suit** (A2) turns you back at about 600 m out on flat ground: about 5.3 real minutes of air by day, with the walk back allowed for. The old pallets were 440 to 960 m out.
- **The pillar rethink** replaced the General Module with the walker core (A3) and added walkers you send from the Map (A4).

## The landing
- **One home area: the plains round (−1400, 1000)** (`region.json` `home`; `docs/terrain-design.md` §1).
- **The Land step is a briefing, not a picker** (the user, 15 Nov). It shows one screen: the home area as a 750 m circle on the region map, the landmarks near it (the frost hollow, the dry channel, the near mesa, the sand sheet) and the orbit report for the circle's centre. Nothing on it can be dragged.
- **You steer in the descent**, anywhere inside the circle. Each choice has a trade-off: set down near the frost hollow and water is close; set down in the open and you get more sun. Skipping the descent (hold Esc) lets the autopilot take the best ground near the centre.
- **The crater-floor and riverbed sites are gone** from `data/sites.json`, the Land step and the tests (the user, 15 Nov). Their flat pads stay in the land until the next region rebuild, as ordinary ground.

## The pacing rule: chapters aren't days
- **Done early, carry on.** When a chapter's beats are done, the next chapter's first call comes after a short breather (`BREATHER`, about one game hour, or as soon as you're back at the lander), on the same sol if there's light.
- **Nights are just nights.** At dusk Castle calls from wherever the story is (`dusk_N` for the chapter you're in) and suggests bed. The hatch never locks and sleep is never forced. A sol ends whenever you sleep.
- **Nothing waits for a morning, and nothing needs the dark.** GAR-Y and Walker 1 are found in daylight, and Walker 1 rides home with you. No beat is held for the clock ("don't hold the story for the clock", the A6 rule).
- **A morning recap** comes only if you slept with a chapter half done: `dN_still` says what's left, from the `left_*` flags.
- **Time budget:** about 40 to 45 minutes over roughly 3 sols. "Skip the guided days" stays in Custom rules.

## Castle's calls
- **On the move: three lines at most,** then a reply that never blocks you. The replies change her next line, never whether the story goes on.
- **Long talks happen only at dusk or in the cabin.** "Why the crew can't land yet" moves from the first call to the first dusk talk.
- She still watches your air (`data/radio/air.txt`), and a blackout still costs time, not harm.

## Chapter 1: the cargo (about 12 minutes)
1. **The descent.** Rao gets as far as "We've got you on the-" before the link drops.
2. **The re-lock.** You answer Castle's "do you read me?" (the hatch waits for that). She says two lines, and pallet 1's photo goes on your slate.
3. **The pallets, one at a time.** They're placed for the bare suit, each with one piece of ring 1 ground on the way:
   - **Pallet 1, life support:** about 250 m out, on a rise. From it you see the next two. It holds the core's air cartridge (heavy).
   - **Pallet 2, power:** about 400 m out, over a crack or a low ledge. It holds the solar blanket and battery (heavy).
   - **Pallet 3, field tools:** about 500 m out, on the far side of a low crossing or past the sand sheet. It holds the hammer, the headlamp, the patch kit and two plan cartridges. This trip usually brings the first turn-back call.
4. **Carry the cargo home** to the staging spot by the lander. Within 30 m counts.
5. **Done:** with light left, the breather and then chapter 2. At dusk: the first sunset, Rao's rise and the long talk.

## Chapter 2: GAR-Y (about 10 minutes)
1. **Rao's pass sees something moving** out by the boulders (`d2_wake`, which can come mid-sol).
2. **Pallet 4's cradle** is about 450 m out in the boulders, open and empty, with tracks leading away. GAR-Y is at work about 150 m further on, near the edge of your air. Let down (it isn't a walker), then won over.
3. **His jobs:** Show me, a survey and a core at the nearest shallow ice, printing the sled hitch on the lander's printer, and towing the spares crate home. The bench sample is optional.
4. **GAR-Y leads you home.** That's why you come to trust him.

## Chapter 3: Walker 1, and choosing home (about 12 minutes)
1. **Rao spots fresh tracks** (`d3_wake`, no 03:00 wait). They start about 200 m from the lander and are marked on the compass.
2. **Walker 1 is stalled about 550 m out,** past a ledge line, within the bare suit's reach.
3. **Fix its nav:** the sun sight, then send it your position.
4. **Fix its fault on the spot** with pallet 3's patch kit: a dust-packed wheel seal (the user, 15 Nov). The printed seal is cut.
5. **Ride its deck home.** It walks to the lander at its own pace, about 3 minutes, and Castle talks on the way.
6. **Choose home on the Map.** W checks a spot: sun, night shelter, ice nearby, slope, and Castle's word. W again on the same spot sends Walker 1. This is the same move you'll use for Walkers 2 to 4 (`docs/bases-and-vehicles.md`).
   - Home must be in ring 1, on ground you've explored. Next to the lander is the natural choice.
   - GAR-Y's ice stakes from chapter 2 show where the water is.

## Chapter 4: making it home (about 10 minutes)
1. **Walker 1 walks there,** picking up your staged cargo at the lander on the way. Castle tells you to meet it.
2. **It kneels and folds into the core.** You watch it happen.
3. **Bring it alive:** plug the air cartridge into the core's socket and lay the solar blanket. The lights come on and the heat starts. The core's leak is cut (the user, 15 Nov).
4. **The first liner, with Castle:** Quarters, in Plan view. Its bunk is the key piece. Watch the liner inflate and the crawler print its shell.
5. **Bed in Quarters.** The three-horizons talk (`d4_sunset`: tomorrow, this season and the mission's four goals with their owners' notes) comes when you go to bed, or at dusk if that's sooner. **The first night in Quarters ends the guided chapters,** whenever it is.

Chapter 4 is done when Walker 1's core is down and alive and a Quarters liner with its bunk stands at that base. The ice spot moves out of the chapters: it's part of choosing home in chapter 3.

## After
- The open game: free nights, free building and the range ladder.
- The radio carries on on Castle's own timeline.

## After the 15 Nov playtest (chapter 1)
*The user's notes on chapter 1 of the 15 Nov build, and what changed (agreed 15 Nov). Not playtested yet.*

- **You come to in the landing seat** (`scripts/wake_up.gd`): black, your breathing and the suit's alarm, then Castle's voice ("do you read me?"). Your eyes open blurred and the cabin swims into focus. You can turn your head but not move. Answering her unbuckles you.
  - Her first call (`d1_relock`) says you were out cold, then has a moment for **the first person on Mars**, in the main line now, not one reply branch.
  - She asks you to take the slate. It lights up when she asks (`do slate_light`), not on a timer.
  - The slate's first look rings `d1_slate`: the parachute photo, then your wrist (hold T: air, power, turn-back), a word on how small the suit is, and "first job, the ridge".
  - **The hatch stays shut** until the slate is in your hands and she's finished (`opening_days.gd` `hatch_refusal`). An older save with the slate already taken gets `d1_slate` in the cabin, or skips it if you're already outside.
  - The lines may mention a window; the lander model is being redone.
- **Landing anywhere sensible** (`descent.gd` `LANDER_HALF` 20 m): the descent checks the lander's own footprint, not a 120 m base pad. The pad check failed 91% of the home circle, so every landing snapped to a safe spot. Now about 40% of the circle is good ground; the rest is boulder fields and steep slopes. The green spots are tips only. A story game's founded site levels just that footprint (`main_menu.gd` `_found_base`).
- **Air matters:**
  - **No air pack on day 1.** Pallet 1 holds the cartridge, rations and sample kit. The bigger air pack is in GAR-Y's spares crate (chapter 2) and goes on at the next refill.
  - **The lope costs air** (`suit.gd` `LOPE` 1.6 with no rhythm, `LOPE_FLOW` 1.3 in full flow; it was 1.3 easing to a walk's 1.0). At about twice a walk's speed it's still the better way to travel per breath. The bare suit stays 5 h, about 5.3 real minutes by day.
  - The robot run lopes now (8 m/s, full flow) and refills only below half air, like a player.
  - If air still never bites, the next lever is the bare suit's hours, not the pallet distances.
- **The tiny printer offers only what the story needs.** Pallet 3 has no plan cartridges now. The pick, bladder, battery, heater and air pack plans all need their cartridge found first (`lifepod.gd` `FOUND_PLANS`). In the chapters that leaves the sled hitch. Placing those cartridges in wrecks is C1's job.
- **Castle notices scrap you've already stripped** before pallet 1: `has_scrap` picks her other line.
- **The ship in the sky** (`scripts/orbiter_sky.gd`), as it really would be seen. The crew's ship is in the one-sol elliptical parking orbit (`docs/master-design.md`). It's only ever seen as reflected sunlight against a dark sky:
  - **Every dusk, the dive:** from about 0.5 h after sunset, a bright point high in the south-west falls fast towards the east horizon as it drops to its close pass. It fades into the planet's shadow just before Castle goes behind Mars (`radio.gd` `los_window`).
  - **Back round:** from about 0.3 h after she's back, a faint, nearly still star climbs from the east to high in the south, until the dawn sky washes it out.
  - Never by day, and not while the ship is behind the planet.
  - The first dive you see from outside, Castle says "look up, that's us, diving down for our close pass" (`orbit_pass`, `data/radio/radio.txt`).
  - The user's notes (15 Nov): a low orbiter would circle 12 to 13 times a sol but pass over one spot only once or twice. A crewed ship would more likely use a one-sol elliptical orbit, which the game already uses.
- **Not done here:** survival from the elements as a whole (cold, suit power, dust, water, wear and storms) needs its own design talk after the rest of this playtest.

## As built (A6)
*Built 15 Nov (not playtested). Tests: `tests/guided_days_test.gd`, `tests/walker_test.gd`, `tests/radio_test.gd`; the robot run is `tests/guided_playthrough.gd` (log in `.claude_tmp/guided_playthrough_log.txt`).*

- **The Land step** (`scripts/main_menu.gd`, `scripts/region_landing_picker.gd` `home_view`): one fixed map of the 750 m circle round `region.json` `home.centre`, with the dry channel and its crossings, the frost hollow, the sand sheet, the cargo target, north and a 500 m scale bar, plus the orbit report. The descent (`scripts/descent.gd`, `HOME_RADIUS` 750) steers inside that circle; skipping it lands at the nearest good ground to the centre.
- **Old sites:** `region_crater` and `region_riverbed` are gone from `data/sites.json` and the tests. An old save at either loads as the plains (`MHGame.GONE_SITES`). `region.json` and the region generator still have their zones and pads; they go at the next region rebuild.
- **Distances** (`scripts/storm_drop.gd`, `scripts/drop_field.gd`): pallet 1 at about 260 m (220 to 300), power 360 to 440 m on flat ground, GAR-Y's cradle 420 to 480 m in the rough, field tools 460 to 540 m low down, each aimed at 400, 450 and 500 m. GAR-Y works about 130 m past its cradle.
- **The pacing** (`scripts/opening_days.gd`): `BREATHER` is 0, 1, 1, 0 game hours after chapters 1 to 4 (a quarter of that if you're in the cabin). A new chapter never starts within 3 game hours of sunset (`LATE_START`, about 5 real minutes of light; the robot run showed 1.5 let chapter 2 start just before the first sunset talk) or before an hour before sunrise, and never while Castle is on air. `done_at` is saved. Chapter 3 is done when Walker 1 is sent home; chapter 4 straight after. The morning recap plays only if the chapter is still open.
- **Dusk:** once a sol. Chapter 4 done: `d4_sunset`. Otherwise the first sunset after chapter 1 is `d1_sunset` (with the "why the crew can't land" lines, moved out of the first call), and any later dusk is `dN_dusk` from the `left_*` flags.
- **Walker 1** (`scripts/walker.gd`): stalls 500 to 580 m out; its tracks run to 35 m short of it; you see it from 250 m (it was 700 m, which let you skip the tracks). The front-left wheel seal is patched on the spot ("Patch it", within 3.5 m of `fault_spot()`, with pallet 3's kit), and it walks home to "ready" by the lander (`d3_home`). Map W, W sends it (`d3_sent`); during the chapters home must be within 1 km of the lander. At the spot: `d4_arrived`; after the set-down it carries any cartridge or pack staged within 40 m of the lander to the core's socket (`d4_down`).
- **Cut:** the printed seal (`lifepod.gd` `_seal_wanted` false), Walker 1's overnight walk (`walker_night` is version 1 only) and the core's leak (`module_life.gd` `pressurise_try` goes straight to alive). The old `mark()` and overnight paths stay for version 1 saves.
- **Chapter 4 done** when the core is down and alive and a Quarters zone with a `crew_bunk` stands at base w1 (`quarters_built`). That first liner is free (`build_rules.gd` `first_quarters`, the zone marked `kit`): it came in Walker 1's kit, because nothing has been printed yet to pay for a shell. Then `d4_quarters`, `d4_sunset` at dusk, and waking from the first night after ends the guided chapters.
- **Radio:** `data/radio/day1.txt` to `day4.txt` rewritten to match; removed sections include `d2_sunset`, `d2_done`, `d3_seal`, `d3_choose`, `d3_marked`, `d3_sunset`, `d3_done`, `d4_wake`, `d4_leak`, `d4_home`, `d4_survey`, `d4_cored` and `d4_ice`. 50 new voice lines (`orb_*_a6_*` and the new sections).

---

# The guided days (redesign, 8 Nov; superseded by the A6 rewrite above)

The user, 8 Nov, stepping back: the first days are a **curated tutorial** that introduces nearly everything the game will be. It's hand-holdy on purpose, with moment-to-moment control over how things happen. On day 5 the game opens up: the four goals, base building, and later the buried heart.

This replaces the first version below (built in 7cbce6e). That one was day 1 the cargo and GAR-Y, day 2 towing, day 3 the walker and the module.

## Rules for the guided days
- **Chapters on the real sun (9 Nov, replacing story time).** The sun never waits. The "days" below are four chapters (scripts/opening_days.gd `chapter`).
  - Why: playtest. The held sun made a cage, and the day never ended unless you followed the script.
  - The chapter's beats are done: its sunset call comes at dusk, and the next chapter starts the morning after. The nights carry the story: GAR-Y's night out, Walker 1 crawling home.
  - Done early (2.5 h of light left): `dN_done` says the rest of the day's yours.
  - Not done by dusk: `dN_dusk` says pick it up tomorrow. That morning `dN_still` recaps what's left (`left_*` flags). A chapter can take several sols.
  - Nothing forces you; you just can't progress without the beats.
- **Each chapter ends in sleep.** Chapters 1–3 in the lander, chapter 4 in the module once it holds air.
  - **No night lock (10 Nov playtest).** The hatch always opens. At night in chapters 1–3 a caution notice says keep it short and mind your air (`night_caution`). The night's events run on the clock either way, and Walker 1 only arrives at dawn.
- **The first call:** the hatch stays shut until you answer Castle's "do you read me?". The reply has no timer and she keeps calling (`hold` / `nudge` in docs/radio.md's format, scripts/radio.gd).
- **The blue sunset is optional.** Castle invites you to Rao's rise; it isn't required. In the cabin at dusk, she talks anyway, and the photo ask waits for another time.
- **Survival still counts.** Suit air runs as normal, and Castle watches it from orbit (data/radio/air.txt):
  - half an hour before your turn-back;
  - at the turn-back;
  - near empty.
- **A blackout costs time, not harm.** You're dragged home and the hours pass, often the day, but there's no suit leak during the chapters.
  - Before you've met GAR-Y, the rescuer is unseen: dark, beeping, dragging, drag scuffs from the ramp. Castle (`d1_blackout`): "Something brought you in." It's paid off when you find GAR-Y.
- **The lander stays self-sufficient.** Only food runs down (see the first version below).
- **Who talks:** Castellanos on the radio (docs/radio.md) and your Notes thoughts. ARDEN: alarm tones and panels only.
- **Nothing early.** No GAR-Y anywhere before day 2: no pallet, no Notes, no slate page, no lines. No walker before day 3.
- **Time budget:** about 15 minutes a day, under an hour in total. "Skip the guided days" is in Custom rules.

## Day 1: the cargo
1. **The descent** and touchdown. Rao, who talked you down, gets as far as "We've got you on the-" and the link drops into static (10 Nov: it was Castle's "First one d-", which read as a glitch).
2. **The link re-locks.** Castellanos is back: what the lander is for, and that the base is out in the pallets and walkers.
3. **Castellanos guides you** from the orbiter's camera to pallets 1, 2 and 3 (life support, power, field tools; renumbered 14 Nov, GAR-Y is pallet 4). One at a time: the suit won't stretch to all of them.
4. **You carry the module's cargo home** to the staging spot by the lander. The air cartridge and the power pack are heavy and slow, but they can be carried.
5. **Dusk: the blue sunset** and a long radio chat. Sign off, say goodnight, and sleep in the lander.

## Day 2: GAR-Y
1. **Castellanos wakes you.** Something's moving out there, maybe one of the walkers. Their hope is the base.
2. **You follow the signs:** tracks, a scrape, dropped debris, odd little marker flags. You find GAR-Y at work, alone.
   - It isn't a walker: let down, then won over.
   - It's been doing its job all along: scouting.
3. **GAR-Y gets you to follow it.** Castellanos reads its manifest to you: what GAR-Y does.
4. **GAR-Y leads you through its jobs,** for you:
   - Show me (its finds on your Map);
   - the ice survey;
   - a core;
   - printing the sled hitch on the lander's printer;
   - a sample on the bench.
5. **Home together.** Still no habitat. A radio chat, then sleep.

## Day 3: the walker, and choosing home
1. **The 03:00 grinding,** then Castellanos's morning call. You and GAR-Y follow the tracks to Walker 1, stalled and lost.
   - Finding it (10 Nov playtest): Rao's dawn pass saw fresh scuffing, so Castle marks where the tracks start on the compass ("Fresh tracks"), and warns it's near the edge of the suit's air: top up, turn back when told. At the tracks (`d3_tracks`) she says they fade on hard ground: keep the same heading, or photograph them and send them up for Rao to follow.
2. **Fix its nav.** Its magnetic map-matching was fooled (the buried heart's first seed). On its nav screen: hold the crosshair on the sun for true north (it shows how far off its compass was), then "Send it your position" from your suit, and its amber guess-circle closes on where it really is. Then set home: the lander. (10 Nov playtest: the old step, matching landmarks by name, was hard to follow.)
   - It's slow and kilometres out, so it says it'll walk home overnight. Robot run 5's ride took about 8 game hours.
   - You head home with GAR-Y.
3. **The afternoon: choose where you'll live.** This is the first design choice.
   - Water first (10 Nov): Castle has you ask GAR-Y for a Survey zone round the lander (`d3_fixed_06b`, `d3_choose`). Its blue stakes show the ice, and Castle notices if you build by them (the `surveyed` flag, set from stakes within 600 m). It's advice; marking the footprint is still the gate.
   - You walk the spots. Castellanos weighs in on sun, ice, shelter and room to grow.
   - **Mark the module's footprint** with the build ghost. This is a new mechanic: the placement is saved, and the walker reads it on arrival.
   - **Print the footing anchors** on the lander's printer. This teaches the printer.
4. **Dusk.** A chat about tomorrow, then the last night in the lander.

## Day 4: making it home
1. **Dawn.** Walker 1 is parked beside the lander. It sets the General Module down on your marks; you watch.
2. **Cold and dark (rethought 9 Nov).**
   - It comes down unpressurised, about −30 °C inside, with its lights off. Its alerts stay quiet until it's commissioned.
   - Castle: plug the air cartridge into the outside socket and lay the solar blanket.
3. **The leak.**
   - With both in, it tries to fill and won't hold (`d4_leak`).
   - A seam on an inside wall, away from the airlock, hisses and puffs frost (scripts/module_leak.gd).
   - Pallet 4's patch kit seals it. Then it repressurises, the heater goes to warm and the lights come on (`d4_patched`).
4. **Moving in** with the fit-out kit.
   - Castle reacts to where the bunk went: by the airlock, or in the quiet corner.
   - Food stays in the lander's crate for now.
5. **The afternoon: water.**
   - Achterberg, through Castle, wants the module's ice in a tube: core the best of GAR-Y's stakes near the module. If you skipped the survey in chapter 3, she asks for the Survey zone first.
   - Any good core within 400 m counts. After three cores with no good ice, the best of them "will do to start".
   - A good core you'd already taken there before she asked counts too: Castle says you're ahead of them (`d4_cored`).
   - The spot is marked "Ice extractor spot".
6. **Dusk: the three horizons** (`d4_sunset`):
   - tomorrow, the extractor;
   - this season, the other walkers, which Rao watches for;
   - the mission, the four goals, each with an owner in orbit:
     - Tupou: Life;
     - Rao: Climate;
     - Achterberg: Geology, "what can we build with it";
     - Mwangi: Humans;
     - Castle: the base and the landing, "the deal".
   - Each goal's lines sit in its own `goal_*` section, so an owner can get their own voice later.
   - Afterwards each owner sends a slate note.
7. **The first night in the module.** The guided days end.

Day 4 is done when the module is down, the leak is patched, the fit-out is placed and the ice spot is found.

## Day 5: open
- The normal clock, free nights, free building.
- **Suggested first build:** the ice extractor near GAR-Y's ice radar. It opens science.
- The radio carries on alongside, on Castellanos's own timeline.

## To build, in order
1. **The machinery:**
   - enable Dialogue Manager;
   - `scripts/beats.gd` (cues);
   - story time in `scripts/opening_days.gd`;
   - the radio on the slate;
   - saving.
2. **Day 1 → day 4,** one day at a time, each playable before the next.
3. **Day-specific code:**
   - pallet 3 removed from the drop field;
   - GAR-Y spawned working on day 2, with a trail of clues;
   - the walker parks overnight;
   - the footprint mark;
   - the printed anchors;
   - an audit removing early GAR-Y mentions from notes, replies, voice lines and slate pages;
   - ARDEN's voice lines retired.
4. **Tests and the robot run** over four days, checking the time budget.

---

# The first version (8 Nov, built in 7cbce6e; superseded above)


The user, 8 Nov: the first days are "baby steps", the game at a small scale. Each day ends with sleep. The lander is a self-sufficient lifepod, too small to be a base. The pallets are cargo for the General Module.

### The lander: a safe home, too small to live in
- **Self-sufficient.** It recycles its water and remakes oxygen from it. A small radioisotope unit (about 0.6 kW, day and night) plus its own panels keep it powered and warm.
  - The panel stays green.
  - Only the rations run down: 10 in the crate plus pallet 1's 10, two a sol.
- **Why it's no base.** One seat, no room to grow, no workshop or lab. The crew in orbit can't land to a closet.
  - ARDEN's brief becomes: "This lander will keep one person alive about as long as you like. It won't keep a crew. The base is in those pallets."
- **This replaces the old premise**, where the lander was sized for "about a sol".
- **Gone from the opening:**
  - the cabin air countdown;
  - the night-one battery choice and its warning;
  - "the tank's low, find ice";
  - the cartridge plugged into the cabin;
  - pallet 2's blanket powering the lander.
- **Pressure on sol 1 comes from outside:** your suit's air (about 10 real minutes a trip, refilled in the cabin) and the coming dark.

### Day 1: the cargo
- **Touchdown.** ARDEN's brief, then the orbiter's photo of parachute 1 on the ridge.
- **Pallet 1, "Life support".** It's the General Module's air plant: too heavy to move by hand, so it stays put for now. It also holds the sample kit and ten rations.
  - Thought: "Not for the lander. It's the module's air plant. The base really is in these pallets."
- **From the ridge,** two more parachutes. One at a time: the suit won't stretch to both.
- **Pallet 2:** the module's solar blanket and battery. It stays packed until the module is down.
- **Pallet 3: GAR-Y.** The big moment, as built.
- **Pallet 4:** GAR-Y points the way. Field tools: hammer, headlamp, patch kit.
- **Sunset with GAR-Y.** It leads you home. "That's the day. Back to the lander and sleep." The hatch stays shut till dawn.

### Day 2: GAR-Y's day
- **Dawn.** GAR-Y is waiting at the ramp. "What did you find?" puts frost, "something big and cold" and "something metal" on your map.
- **What you learn GAR-Y does, by doing it:**
  - **Show me:** it leads you to each find.
  - **Survey there:** its radar reads the frost hollow for buried ice.
  - **Core sample:** at the ice wall or the iron.
  - **Tow:** print the sled hitch from storm debris on the lander's little printer. Then GAR-Y tows the pallets, one at a time, to a staging spot by the lander, ready for the module.
- **Jobs:** the hitch, pallets 1 and 2 staged, one survey or core, and a sample on the bench. Three of the four is enough.
- **Night.** Bed. At 03:00, a long grinding out on the flats.

### Day 3: Walker 1 and the module
- **The walker.** Tracks at dawn, the photo up to the orbiter, Castellanos's text. Follow it, set its compass right, walk it home.
- **The module.** Choose its ground and watch the walker lower it.
- **Unpacking the staged pallets** is where the module comes alive: the air plant goes in, and the solar blanket goes on its socket.
- **Fit-out.** Unpack the kit and place the pieces. The first night under a real roof.
- **A slow player spills into day 4.** That's fine: unfinished jobs carry over.
- **Forced sleep ends here.** Nights are yours from now on.

### Then it opens up
- **The four main goals arrive** (Life, Climate, Geology, Humans) with the module's plans.
- **The first real build is the ice extractor.** That opens science, and Castellanos's text names the four goals.
  - **Changed in building:** the build area is about 60 m round the base, so the extractor can't stand at the ice wall 1–1.5 km out.
  - The module's plans send you to GAR-Y's ice radar near the module instead: survey, core, drill.
  - The ice wall stays a thread for later.
- **Free building and exploring** until the real story thread, the interference, starts.

### Built (8 Nov)
- **The lander (`survival_core.gd` `self_sufficient`, cabin only):**
  - a 0.7 kW power cell;
  - oxygen remade into the tank, 0.06 kg/h while powered;
  - water recycled.
  - These are code fallbacks (`cabin_rtg_kw`, `cabin_o2_make_kg_per_h`, `cabin_self_sufficient`), not yet in the balance sheet.
- **Gone:** ARDEN's night warning, the low-air and low-water thoughts, and the cabin port taking the cartridge. The power pack can't be laid at the lander.
- **The cargo:**
  - The air cartridge plugs into the module's outside socket (`module_life.gd`).
  - Carrying it or the power pack, E on a hitched GAR-Y loads it on the sled (`lifepod.gd` `load_on_sled`). E on GAR-Y by the lander unloads it.
  - Cargo within 30 m of the lander counts as staged.
- **Day 2's jobs:** print, tow (both items staged), scout (a GAR-Y survey or core) and sample. Three of four.
- **Science** opens on an ice extractor (`mars_world._science_build`). Castellanos's "science_open" text names the four goals.
- **Tests:** `tests/opening_days_test.gd`. The robot run (`tests/opening_playthrough.gd`) follows this route.

## Chapter 5: the Print Shop (15 Nov)
After chapter 4 the game was stuck, and nothing said so:
- there was no Print Shop and no feedstock;
- the extractor, intake and solar all said "print the first one at the Print Shop";
- the Workshop needs heavy power, and its plan only came after a print job.

Chapter 5 fixes that. It's lighter than chapters 1–4: there's no forced bed, and the night is yours.
- **Morning** (`d5_wake`): Rao spots pallet 6's parachute, 380–520 m from the core, and it goes on the map (`drop_field.add_print_shop`).
- **Pallet 6 opened** (`d5_pallet`): its crate is too heavy to carry. GAR-Y tows it on the sled, and it comes off by the core (`spares_crate.gd`, kind `print_shop`).
- **The crate opened at home** (`d5_unpacked`): the Print Shop, a regolith intake and 250 kg of feedstock go into the store.
- **Both placed** (`d5_printing`): the intake goes outside and the Print Shop in any room. Its first job is the ice extractor. That first job also sends the heavy power plan.
- **Extractor printed** (`d5_extractor`): set it on GAR-Y's ice spot.
- **Extractor down** (`d5_water`): chapter 5 is over and the chapter becomes 6. The Lab services plan follows, as before.
- **Missed a beat:** the next morning `d5_still` recaps what's left.

After the chapters:
- **Castle's morning call** (`next_*` in `data/radio/day5.txt`): one short "what I'd do next" each morning. She picks the first that fits: water loop, water test, heavy power, metal, feedstock, then explore. Each is said only once.
- **Inner voice** (`next_feedstock`, `next_metal`, `next_rack`): open while true, answered when it stops being true.
- **Locked rooms** now say where their upgrade's plan comes from, not "no plan yet".
- Castle's sunset talk now says "Tomorrow, the Print Shop… then water".

## After the 15 Nov playtest, part 2: the cabin and the first step (16 Nov)
**What the user found:** the cabin took about 2 minutes of listening, and "first person on Mars" belonged at the first step. They wanted a moment of awe for player and character alike.

**The cabin is now four hands-on steps, about a minute.** Castle talks over them, and nothing waits on her.
1. **Unbuckle:** E, once your eyes are open (`wake_up.gd`). There's a hint, and it unbuckles itself after 60 s. The slate lights up as you stand.
2. **The slate:** take it from the console. Castle shows Rao's photo of the parachute (`d1_slate`, trimmed).
3. **Seal the helmet:** K (`suit.gd suit_up`). The first seal is the suit's check: the wrist pad lifts and Castle gives one line (`d1_helmet`). This replaces "hold T".
4. **The hatch:** the lock is only the slate and the sealed helmet (`opening_days.gd hatch_refusal`). The first opening vents the cabin for about 3 s, with a hiss, an amber lamp and dust lifting (`crew_lander.gd _vent_then_open`). Then the ramp swings down, and the view whites out into daylight.

**The first step** (`scripts/first_step.gd`) comes the first time your boot is on the regolith, off the ramp:
- You stop, and the HUD goes, compass included, for this moment only.
- The view eases down to your boot print, then lifts and pans slowly towards the sun (or pallet 1's ridge).
- Music swells, and "I'm standing on Mars." fades in.
- About 8 s later control is back. After 3 s of quiet comes Castle's `d1_first_step`: "Are you on the ground?", then the first-person-on-Mars talk and Houston standing up. Then the ridge, and the parachute thought.

The boot print stays (saved) and is "First step" on the Map.

**The lander, same day:**
- You come to in the seat facing the console and the slate. The waking now turns you from the lander's own layout, since the furniture isn't placed yet when you wake. You sit in the seat, not behind it.
- A small sealed porthole is on the wall to your right, within a strapped-in look (`crew_lander.gd _build_porthole`). The hull model has no opening, so the glass shows a small camera's view from just outside it, and it renders only while it's on screen. It's "the size of a dinner plate", as Castle says on day 4.
