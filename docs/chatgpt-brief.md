# Brief: Outpost One: Mars

*Background for an outside helper. Written 8 Nov 2026.*

## The game

**Outpost One: Mars** is a first-person survival and exploration game about being the first person on Mars. It's built in **Godot 4.7** (GDScript, Forward+), it runs on Windows, and Terrain3D draws the ground. One developer works on it with AI help.

**Three pillars**, in order of importance:
1. **First to see it.** The wonder of untouched ground: exploring, caves, discoveries. The feeling is awe, not terror.
2. **Mars will kill you for it.** Cold, thin air, dust, radiation, night and distance. It's never a fight, always a margin you manage.
3. **A foothold.** A base built from what you went out and brought back, so self-reliance slowly becomes a home.

**Tone:** grounded, real science only (NASA-style kit: walking cargo carriers like ATHLETE, terrain-relative navigation, haematite, water ice). You're physically alone the whole game. There's warmth and humour, but sparing. The inspirations are Firewatch's single relationship and reactive inner voice, plus Subnautica's "build a playable slice, then grow it" method. **The game must stand on its own identity: nods are fine, copies aren't.**

**Modes:** Survival (the full game), Freedom (no food or water), Creative (the original freeform habitat builder, everything unlocked) and Custom (a rules table).

## The current story

- **Cargo first, then you.** The cargo landed ahead of you, and its walking carriers were meant to gather the pallets and build the base. You're the *commissioner*: you were to land beside the finished base, walk in, and bring it up with your robot helper.
- **The storm.** Months into your cruise, a planet-wide dust storm swallowed the landing region, Aeolis Reach. The walkers stalled lost, the cargo pallets were strewn across the Reach, and the base's landing beacon went silent. You can't turn back, and Earth can't send more for 26 months.
- **Knocked off course.** With no beacon, your entry runs long. The lander's cameras pick out safe spots within your fuel, and where you touch down is where your base starts. The Map begins as a blurry old orbital survey, with only what the descent cameras saw shown sharp.
- **The lander is your lifepod.** It's self-sufficient (air and water recycle, its own power, only rations run down over about 10 sols), but it has one seat and no room to grow. It's a safe place to return to, not a base.
- **The opening days (sols 1–5), guided "baby steps":**
  1. Find the first pallets: one under a parachute in sight on a ridge, then power, GAR-Y and tools. Then your first sunset.
  2. GAR-Y's day. It went scouting overnight ("What did you find?" / "Show me"), and you print a sled hitch so it can tow the pallets home.
  3. Walker 1. You find its tracks, a photo from the orbiter or its lamp from high ground. It's lost, not broken (its compass was bent). You fix its heading from the sun, then ride it home.
  4. The General Module is set down. Your first real room.
  5. Settling in. Your first own build is an ice extractor at the ice wall, which opens up science.

  Each of these sols ends in sleep: the lander hatch won't open from inside at night. After that, the game opens up.
- **GAR-Y** is a small, expressive helper robot found in pallet 3, met in a held first-person moment ("I'm not alone out here"). If you black out before finding it, it finds you instead.
- **Voices, rationed:**
  - **ARDEN**, the habitat AI, speaks only inside.
  - **The suit** has no voice, just tones and screen cues.
  - **Castellanos**, on the orbiter, is the one close voice: she talks to you on drives and orbital passes.
  - **Earth's four CAPCOMs** send letters you can play and reply to.
  - **Sunny** hosts a weekly drive show.
  - **Replies:** you pick short answers, and silence counts as an answer.
- **Notes** is the player's written inner voice: 3–5 hedged first-person thoughts that react to what you've done. There's no quest list, no ticks and no counts. When a thought is answered, it becomes a Journal page.
- **The story threads:**
  - the storm, and Earth's apologetic search;
  - the broken comms link (orbiter texts until you repair it);
  - GAR-Y;
  - the wonder, a discovery trail from an ancient lakebed to a lava tube, ending in evidence of ancient microbial life;
  - the crew waiting in orbit;
  - the storm's return.
- **The buried heart (the one ending).** The storm wasn't the whole cause. With the sun and stars hidden, the walkers and the pallets' guided descents fell back on magnetic map-matching (the local field against the orbital magnetic map), and the Reach's field, far stronger than that map, fooled it. A solar storm the same week fried the beacon. Under the Reach lies an ancient, cold, magnetised intrusion; a much younger, deeper magma pocket below it fed the hot springs behind the life find (science fixed 8 Nov: hot rock can't hold magnetism).
  - **Clues:** Walker 1's nav log with jumping position fixes, its curving tracks, a rare green aurora, Castellanos's jokes about radio noise. Later come the walker nav logs, a magnetometer and a magnetic Map layer.
  - **Why it matters:** flight rules hold the crew in orbit until someone on the ground explains what went wrong.
  - **The ending:** understand the heart, make the way down safe, survive the storm's return, and land the crew by your magnetic map. It becomes the main goal only late in the game. There's no "go home" and no open-ended carry-on after the ending.

## Where the build stands

- **Branch `survival-revamp`.** This is a rebuild of an older freeform-builder version, which is tagged v0.3.0.
- **Built:**
  - the descent and landing;
  - a single "known things" record that feeds the Map and the always-on compass;
  - pallets 1–4, GAR-Y's meeting and wake-up scenes;
  - the lifepod days (ice by hand, a tiny printer, salvage, GAR-Y's sled);
  - Walker 1 and the General Module;
  - the opening-days structure;
  - hunger, tiredness and suit food and drink.
- **Next:** the four materials (ice, regolith, iron-rich rock, salvage), studying damaged kit at a bench to unlock plans, the comms repair, the water link home, food, wear, storms, and the wonder and heart threads.
- **Code:** about 280 scripts and 51k lines of GDScript.
  - **Biggest files:** `build_controller.gd` (about 7,000 lines), `companion_rover.gd` (GAR-Y), `main_menu.gd`, `mars_world.gd`, `interior_build_controller.gd`, `habitat_sim.gd`, `pda_screen.gd` (the handheld "slate" that holds the HUD apps).
  - **Design docs:** `docs/master-design.md` (canon), `docs/systems-and-items.md`, `docs/opening-days.md`.

## Issues we'd like help with

**Design contradictions in the docs:**
- **Sleep.** One rule says sleep is never forced and night is always walkable. Another says it's forced every night of the opening days. The current reading is "forced only while you live in the lander", but the docs haven't been brought into line.
- **The survival table** (master-design §6) still says "Hour 1: cabin air lasts about a sol". The lander is now self-sufficient, so the early pressure is suit air and the dark. Without the air clock, what makes sol 1 tense?
- **Story order.** The commissioner premise, the self-sufficient lander, the "the pallets belong to the module" change and the buried heart were each decided separately. Do they tell one clean story, and does each opening day hit the morning pull / midday high / dusk closure shape?

**Code health:**
- **Layers.** The revamp was layered onto an older builder game: `build_controller.gd` is about 7,000 lines, and Creative mode must keep working alongside Survival.
- **Failing tests.** Three tests were already failing before the revamp: habitat_alerts (voice lines for bunks and worn kit), weather ("card for every save slot") and build_bar_context (catalogue zones). There's also a suit "Freedom blackout" test.
- **Unfinished pieces:**
  - ARDEN still speaks outside, and the suit still talks;
  - the walker's walk home is slow (about 17 real minutes) and has no pathing;
  - the module's airlock doesn't unfold;
  - GAR-Y doesn't physically lead the way;
  - several pieces are still primitive placeholder shapes.

**House rules for any suggestion:**
- no text or lettering on 3D models (only on working screens);
- no quest lists or objective markers;
- no new speaking characters or filler dialogue;
- moving things is never a repeated hauling chore;
- real science only.

*[Add the specific issues you want ChatGPT to look at here.]*
