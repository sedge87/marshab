# The intro, reworked (draft for review, 21 Nov 2026)

*From the 21 Nov playtest. The user's verdict: triggers fire at odd times, Castle talks about things you've left behind, Walker 1 showed up before its tracks, and the buggy lies out there with no container or parachute. Decided: **storm drop, done right**; **reactive, place-aware dialogue**; **this design first, build after.** It replaces the trigger and dialogue parts of `docs/opening-days.md`. The chapter content (cargo, GAR-Y, Walker 1, home, Print Shop) stays.*

---

## 1. What went wrong (the root causes)

1. **Calls are rung by events but heard later.** An event rings a call, which waits behind another call, the link or danger, and plays a minute later. By then you've moved on. The crate line ("Hold still, I'm on your helmet cam… what's that box beside it?") plays wherever you are.
2. **Lines don't check the world.** A line can test a flag set earlier in the call (`? flag`), but never where you are, what you're carrying or what you've already done. So she asks for things that are done and describes things that aren't in front of you.
3. **Recaps are worked out when rung, not when heard.** The `left_*` flags can be stale by the time she speaks.
4. **Things become known without being seen.** Walker 1 was "seen" from a rise through the hills (fixed 21 Nov in `1d20280`: a sighting needs a clear line over the ground).
5. **The drop doesn't explain itself.** Pallets have parachutes; the vehicle wrecks don't. There's no pallet 5. Nothing in the world says this was one delivery, scattered by one storm.

## 2. The story of the drop (why you're gathering things)

**One sentence:** the base was sent ahead uncrewed and came down in the storm off its beacon, so every piece of it is scattered across the Reach; you landed off target too, and your first days are recovering the base piece by piece.

- **The manifest.** The drop was numbered. Your slate's Base page gets a **Cargo manifest**: every piece, with what it's for, "location unknown" until someone sees it, and "recovered" once it's home. It's a list of *things*, not tasks, so it fits the "Notes are thoughts, not quests" rule. It's why you go out: *that's my air plant out there.*

  | # | What | Why you need it | How it came down |
  |---|---|---|---|
  | 1 | Life support: the core's air cartridge, rations, sample kit | air for the base | pallet, parachute, on the ridge |
  | 2 | Power: solar blanket and battery | power for the base | pallet, parachute |
  | 3 | Field tools: hammer, headlamp, patch kit | to fix and work | pallet, parachute |
  | 4 | GAR-Y, the scout rover | scouting, ice, towing | cradle pallet, parachute; it woke and left |
  | 5 | **The scout buggy (new)** | range | **its own cargo shell, split on impact, with its parachute** |
  | — | Walker 1 and the General Module | the base itself | walked down on its own legs; lost its nav in the storm |
  | 6 | Print Shop and intake | making things | arrives later, Rao spots its chute |
  | — | HabRover (heavy) | long trips | heavy lander, far out, tipped on its legs |

- **Every container tells its story.** Each pallet, shell and lander gets its parachute (or retro-rocket scorch), a skid or impact scar and a short debris trail. The buggy sits half out of its broken shell. The far rover lies on a heavy lander with a crumpled leg. The drone is in a small capsule. Nothing just *sits* on the ground.
- **Each find's beacon** (21 Nov, Phase 4) blinks on its container, so you see them before the compass needs to tell you.
- **Order of need, not order of script.** Air first (pallet 1, sol 1), then power and tools. From sol 2 anything you can reach is fair game: GAR-Y, the tracks, the buggy shell. The manifest shows what's still out there.

## 3. Reactive dialogue: the rules

**Every line checks the world just before it plays, not when the call was rung.**

1. **Live facts in conditions.** Alongside `? flag`, lines can test facts from code at the moment they play:
   - `? near:crate 30` (within 30 m), `? sees:walker`, `? has:patch_kit`, `? done:hitch`, `? outside`, `? low_air`, `? morning`, `? dark`.
   - The facts live in one table in code (`radio.facts`), so a script can't ask about something that isn't tracked.
2. **Place-bound lines.** A line about something in front of you is written `@ near:crate 30`. If you're not there when it comes up, its `@else` version plays ("There was a crate by GAR-Y's spot, did you see it?"), or the line is skipped.
3. **Done is acknowledged, never asked again.** Every line that asks you to do something carries the check for it. If you've already done it, the line switches to "You've already printed the hitch. Good." or drops.
4. **Freshness.** An event call can wait at most about 20 s for its turn. After that it changes to its catch-up form (shorter, past tense) or is dropped if it no longer applies. A newer event about the same thing replaces it.
5. **Banter can be dropped.** Lines marked as chat (jokes, the crew's asides) are skipped if you've moved away, got busy, or another call is waiting. Information lines come first in every call; chat comes last.
6. **On the move: three lines, information first.** Long talks only indoors or at dusk (kept from A6).
7. **Time words are live.** "This morning", "last night", "dawn pass" and "yesterday" come from facts, not the script's assumptions.
8. **Recaps read the world at play time.** `dN_still` is built from live facts, not from flags set when it was rung.
9. **What she can't know, Notes says.** Castle sees only via your helmet camera, your slate photos and Rao's passes. Anything else you notice is your inner voice in Notes.

## 4. The beats and what triggers them

*Every trigger is something the player did or saw, never a timer, except the sunset.*

**Sol 1 (guided, as now):**
- **Wake, slate, helmet, hatch, first step:** unchanged (16 Nov).
- **The ridge (pallet 1):** triggered by reaching it.
  - The manifest opens with pallet 1 "on the ridge, seen from the cabin".
  - From the top you see pallets 2 and 3's chutes, and they become "located".
- **Pallets 2 and 3:** each call is triggered by opening it, and is place-bound to it.
- **Cargo home:** triggered by the third thing staged by the lander.
- **The sunset talk:** at dusk, indoors or on the rise.

**Sol 2 onward (open; any order; the manifest drives it):**
- **Rao's movement report** (GAR-Y): triggered by the first morning call, and only if GAR-Y isn't met yet.
- **GAR-Y met:** triggered by meeting it. The crate lines are place-bound to the crate (the bug above).
- **Walker tracks:** Rao's report comes once you're back near the lander after the morning call, or after GAR-Y's call ends, whichever is first. It needs a clear link and comes as a short call.
- **The buggy shell (pallet 5):** its chute is visible from the near ring. Finding it adds it to the manifest. Its fix stays as planned (C1), and Castle says only that it's "for later" if you can't fix it yet.
- **Walker 1:** chain unchanged (tracks → nav → photos → patch → ride → choose home). Each call is place-bound to the walker.
- **Home and the core:** unchanged triggers, with live facts on the "plug in the cartridge" lines (are the cartridge and blanket already staged?).
- **Print Shop (pallet 6):** opens when the base is alive and GAR-Y is found. Rao's sighting wording follows the time of day.

## 5. Known broken lines (first pass; the build does all ~270)

| Call | Problem | Fix |
|---|---|---|
| `d2_found` 09 to 14 | crate described wherever you are | `@ near:crate 40`, with an `@else` version |
| `d3_wake` a6_03 | "Top your air up first" regardless of air | `? low_air` |
| `d2_wake` | "past your pallets" assumes you've seen them | `? located:pallet2` |
| `d5_wake` | "dawn pass" at any hour | a time word from facts |
| `dN_still`, `dN_dusk` | recap flags stale | worked out at play time |
| `d4_down` | "plug in the cartridge" when it's already plugged in | `? done:cartridge` |
| `d1_pallet1` | asks what's in it after you've unpacked it all | `? done:pallet1_carried` acknowledges |

The line pass checks every line against four questions:
1. Does it assume where I am?
2. Does it assume what I've done?
3. Does it assume the time?
4. Does it assume what order things happened in?

## 6. Build order

1. **R1, the radio engine:** live facts, `@ near` with `@else`, freshness and catch-up forms, chat lines, recaps at play time. Tests in `tests/radio_test.gd`.
   - *Built 21 Nov.* Syntax as written in `docs/radio.md` ("Lines that check the world"); facts are one token, `near:crate:40`. `d2_found` now uses `@ near:gary:30` / `@ near:crate:40` (the hand-made `by_gary`/`by_crate` flags are gone). Recaps at play time come in R2: the engine already tests every condition as the line plays, so `dN_still` only needs its lines rewritten onto facts.
2. **R2, the line pass:** every call in `data/radio/day1-5.txt` audited with the four questions and rewritten where needed. New voices via `python tools/generate_voice.py --missing`, and rewritten IDs renamed so they regenerate.
   - *Built 21 Nov.*
     - **Recaps and time words are live facts now** (`opening_days.gd _radio_facts`). They're worked out as each line plays, so a recap can't be stale:
       - all the `left_*` recaps, read for the chapter of the call on air;
       - `morning`, `dawn`, `indoors`;
       - `on_the_rise`, `missed_rise`;
       - `has_scrap`, `cargo_early/mid/late`;
       - `has_slate`, `helmet`, `cartridge_home`, `core_air`, `core_power`;
       - `knows:<id>`.
     - **New places:** `pallet1`, `gary_pallet`, `walker`, `lander`.
     - **Lines rewritten (20 new voices, IDs `*_r2_*`):**
       - d1_relock: "grab your slate" only if it's not in your hands yet;
       - d1_slate: "seal your helmet" only if it isn't sealed;
       - d1_pallet1: the opener is place-bound, the answers no longer say "carry it down", and the last line checks whether the cartridge is home;
       - d1_ridge: "look at you, up there" only if you are;
       - d2_wake: "past your pallets" only if you've seen them;
       - d2_cradle: place-bound;
       - d2_found: "bring it back out here" only by the crate;
       - d3_wake: "top your air up" only on low air;
       - d4_arrived: a version for when you're already at the walker;
       - d4_down: asks only for what isn't plugged in;
       - d4_sunset: a version for outdoors;
       - d5_wake: the bed question only in the morning, and "dawn pass" only at dawn.
     - The remaining lines passed the four questions as written.
     - `tools/generate_voice.py` now reads `@` / `@else` / `chat` lines.
3. **R3, staging the drop:**
   - pallet 5, the buggy's shell (model: split shell, parachute, scar), at the buggy's spot;
   - the rover's heavy lander;
   - the drone's capsule;
   - an impact scar and debris on every container;
   - the manifest on the slate's Base page.
   - *Built 21 Nov.* `scripts/drop_shell.gd` stages each one from the models in `assets/models/storm_cargo/` (built by `asset_packs/mars_storm_cargo_v2/source/build_drop_shells.py`):
     - the buggy's split shell, with a skid strip, its chute and debris;
     - the drone's sprung capsule, with its small chute;
     - the HabRover's heavy lander, tipped on a crumpled leg, with a retro-rocket scorch.
   - Wrecks go on the Map only once you've been within sight (buggy 350 m, rover 260 m, drone 160 m), as "Buggy's shell", "HabRover's lander" and "Drone capsule".
   - **The glint.** The HabRover's lander is placed 1.6–2.6 km out, somewhere the lander can see (`mars_world.gd _rover_wreck_spot`). From more than 300 m away, while the sun is under 25°, it twinkles. Seeing it with a clear line learns `glint:habrover`.
   - **The manifest:**
     - pallet 5 is the scout buggy, 8 the instruments with the drone, 9 the HabRover on its lander, 10 its stores;
     - a new state, **GLINT**, sits between "no signal" and "seen";
     - seen lines say what state the thing is in.
   - Check with `tools/drop_shell_look.gd`.
4. **R4, the trigger pass:** every `ring()` in code (about 40, listed in `opening_days.gd`, `walker.gd`, `drop_field.gd`, `drop_site.gd`, `spares_crate.gd`, `suit.gd`, `module_life.gd`, `first_step.gd`, `wake_up.gd`, `lifepod.gd`) moved onto a player fact, with freshness.
   - *Built 21 Nov.*
     - **Every `ring()` checked.** All but the dawn and dusk calls fire on something you did or reached: opening a pallet, the ridge, meeting GAR-Y, the tracks, a photo, a fix, the core down, the crate home.
     - **Walker tracks (d3_wake):** Rao's report now waits until you're within 150 m of the lander, or GAR-Y's call is over, and never lands on top of the GAR-Y morning call.
     - **d3_tracks** is marked `fresh`: dropped if it comes late.
     - **Morning calls stay on the clock:** d2_wake (only while GAR-Y's unmet) and d5_wake (Rao's pass).
5. **R5, check:** the robot run (`guided_playthrough`) gets a "Castle talked about X while I was more than 100 m from X" checker, then a playtest build.

Phase 6 (the three new models) waits until this is done. The buggy model from the zip goes into its shell in R3.

## 6b. Second playtest round (21 Nov, afternoon)

**Fixed now, ahead of the rework:**
- **Buggy and drone wrecks on the compass from sol 1.** The wreck check ran before the opening had loaded, and read "no opening" as "chapters over". It now waits (`mars_world.gd _sync_region_vehicles`).
- **"Morning, sleep okay?" at 1:30 pm on sol 1.** The new idle and Ask Castle offers used the morning recap calls. `dN_still` now opens with "Morning…" only after a night's sleep, in the morning (the `morning` flag). Otherwise it uses a neutral opener (`dN_still_n01`).
- **"Goodnight, Castle" offered after waking.** Falling asleep now ends the call in progress, replies included (`radio.gd _cut`).
- **GAR-Y named in the walker-tracks call before you'd met him.** The lines that name GAR-Y now depend on `gary_met`, and `d3_home`'s ice line on `ask_gary`.
- **Walker 1's thought without seeing it.** A sighting needs it on screen and a clear line over the ground.
- **The GAR-Y meeting call waited till you were home.** Calls were held while you were past turn-back, and GAR-Y sits at the edge of your air. Now only real danger holds a call: air under a quarter, a leak, no power, a storm (`danger_level(false)`).
- **The crate line away from the crate.** The `d2_found` openers and the crate line check `by_gary` and `by_crate` while they play, with a version for when you've walked off. This is the first use of the R1 idea, by hand.
- **The pyramids.** Single height samples 3–5 m above all eight neighbours, drawn by Terrain3D as four-sided spikes; 187 on the current map. `tools/despike_heights.py` flattened them, and `generate_region.py` now de-spikes before saving. Which generator step makes them is still unknown.

**Still for R1 and R2:** the same kind of problem is in other calls (for example `d2_found_14` "bring it back out here", and `d4_still` "press B to set the core down"). The line pass covers them.

## 7. Decided (21 Nov)
- **The manifest is on the slate:** Base page → Cargo manifest, with you outside as well as home.
- **The buggy stays a later find (C1).** You find its shell early; Castle says it's "for later". It's fixed once the Print Shop and parts are there, so the first days stay on foot.
- **The far rover's heavy lander glints on the horizon from home** at low sun, a pull outward long before you can reach it.
