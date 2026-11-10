# The guided days (redesign, 8 Nov — days 1–4 built; not playtested)

The user, 8 Nov, stepping back: the first days are a **curated tutorial** that introduces nearly everything the game will be. It's hand-holdy on purpose, with moment-to-moment control over how things happen. On day 5 the game opens up: the four goals, base building, and later the buried heart.

This replaces the first version below (built in 7cbce6e). That one was day 1 the cargo and GAR-Y, day 2 towing, day 3 the walker and the module.

## Rules for the guided days
- **Chapters on the real sun (9 Nov, replacing story time).** The sun never waits. The "days" below are four chapters (scripts/opening_days.gd `chapter`).
  - Why: playtest. The held sun made a cage, and the day never ended unless you followed the script.
  - The chapter's beats are done: its sunset call comes at dusk, and the next chapter starts the morning after. The nights carry the story: GAR-Y's night out, Walker 1 crawling home.
  - Done early (2.5 h of light left): `dN_done` says the rest of the day's yours.
  - Not done by dusk: `dN_dusk` says pick it up tomorrow. That morning `dN_still` recaps what's left (`left_*` flags). A chapter can take several sols.
  - Nothing forces you; you just can't progress without the beats.
- **Each chapter ends in sleep.** Chapters 1–3 in the lander (its hatch stays shut at night), chapter 4 in the module once it holds air.
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
1. **The descent** and touchdown. Castellanos's "First one d-" cuts into static.
2. **The link re-locks.** Castellanos is back: what the lander is for, and that the base is out in the pallets and walkers.
3. **Castellanos guides you** from the orbiter's camera to pallets 1, 2 and 4 (life support, power, field tools). One at a time: the suit won't stretch to all of them.
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
2. **Fix its nav.** Fix your position from the sun and landmarks; its magnetic map-matching was fooled (the buried heart's first seed).
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
