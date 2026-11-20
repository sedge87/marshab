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
2. **R2, the line pass:** every call in `data/radio/day1-5.txt` audited with the four questions and rewritten where needed. New voices via `python tools/generate_voice.py --missing`, and rewritten IDs renamed so they regenerate.
3. **R3, staging the drop:**
   - pallet 5, the buggy's shell (model: split shell, parachute, scar), at the buggy's spot;
   - the rover's heavy lander;
   - the drone's capsule;
   - an impact scar and debris on every container;
   - the manifest on the slate's Base page.
4. **R4, the trigger pass:** every `ring()` in code (about 40, listed in `opening_days.gd`, `walker.gd`, `drop_field.gd`, `drop_site.gd`, `spares_crate.gd`, `suit.gd`, `module_life.gd`, `first_step.gd`, `wake_up.gd`, `lifepod.gd`) moved onto a player fact, with freshness.
5. **R5, check:** the robot run (`guided_playthrough`) gets a "Castle talked about X while I was more than 100 m from X" checker, then a playtest build.

Phase 6 (the three new models) waits until this is done. The buggy model from the zip goes into its shell in R3.

## 7. Open questions for the user
- Should the manifest be on the slate (Base page → Cargo), or only on a physical clipboard or console in the lander?
- Should the buggy be fixable early (sol 2–3, with pallet 3's kit and scrap) or stay a later find (C1)?
- Should the far rover's heavy lander be visible from home, as a distant glint on the horizon, to pull you out later?
