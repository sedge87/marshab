# New-game options (core-loop build order, step 2)

A design for the challenge options, written 31 Oct 2026. It follows `docs/core-loop.md` round 6: you choose fatigue, radiation, injuries and surprises when you start a game; later you can switch one on, never off. Nothing here is built yet. The decisions are in §8.

## 1. What the player sees

- **On the Colony step**, under Game mode, a **Challenge** block appears for Survival (and a smaller one for Freedom, §4):
  - four rows, each a name, a one-line note and a switch;
  - surprises have a level instead of a switch: Off, Rare, Usual, Often.
- **During a game:** Pause → **Challenge** shows the same four rows.
  - Anything that's off can be switched on; anything that's on shows a lock icon and "On for the rest of this game".
  - Switching one on asks once: *"Turn on Radiation? You can't turn it off again in this game."* Confirm or Cancel.
- **The save card** shows the options that are on as small icons beside the game mode, so a hardcore save is easy to spot.
- **Notes in plain language,** for example:
  - **Fatigue:** "Long days slow you down. Sleep clears it. Never locks you out."
  - **Radiation:** "Time outside and solar storms add up to a dose. Shelter and shielding keep it down."
  - **Injuries:** "Falls, rescues and rough landings can hurt you or the crew. The medical bay treats them."
  - **Surprises:** "How often something unexpected goes wrong. Always with time to respond."

## 2. The one-way rule

- At the start, every option is free to set either way.
- Once the game has started (the lander has touched down):
  - **off → on** is allowed, at any time, from the pause menu;
  - **on → off** is never allowed, not even by loading an older save of the same game (each save keeps the options it was made with);
  - **surprises can go up a level, not down** (Rare → Usual → Often).
- **The debug panel** (Ctrl+Shift+F12) can still flip anything, for playtests. A save that was changed this way is marked "debug" in its header, so it's clear in bug reports.
- **Assisted procedures are not a challenge option.** They're accessibility (round 4) and live in Settings, free to change either way at any time.

## 3. What each option controls

What exists now is wired up in step 2. The rest is built in step 10 ("Your body") and switches on automatically there, because the option already exists in saves.

| Option | Now (step 2) | Later (step 10) |
|---|---|---|
| **Fatigue** | nothing yet: the row is hidden until it does something (§8 Q3) | your tiredness, slower suit work, sleep in the sleeping quarters |
| **Radiation** | the crew's dose during solar particle events (exists, `habitat_life.gd`) | your own running dose outside; the suit and rover add shielding |
| **Injuries** | crew injuries from hazards and the medical bay's recovery (exists) | your injuries from falls and GAR-Y's rescue (the health knock in the backlog) |
| **Surprises** | solar particle events, breaches, breakdowns and random dust storms, at the chosen rate (exists, now behind the global `live_hazards` setting) | later surprise kinds (core-loop round 6) join the same dial |

**Surprise levels** multiply the base rates in `data/hazards.json` (`live`) and, from Rare up, the site's `dust_storms_per_100_sols`:
- **Off:** no solar events, breaches or breakdowns. Dust storms are weather, so they still come at the site's usual rate (§8 Q1);
- **Rare:** ×0.5;
- **Usual:** ×1 (today's rates);
- **Often:** ×2.

Every event keeps its warning (storms forecast 10 h ahead, solar events 30 min ahead), whatever the level.

## 4. Modes

- **Survival:** all four options.
- **Freedom:** surprises only (the crew never come to harm, so radiation and injuries would do nothing). Things go wrong and warn you; nothing hurts.
- **Creative:** no options; the simulation is off.
- **Missions:** no options. Each mission sets its own hazards, as now. Once the campaign is done and you play on, the Survival rules apply with the options you choose then.

## 5. Defaults

- A new Survival game starts with **surprises on Rare, and fatigue, radiation and injuries off.** That's gentle, as round 3 asks ("Yes, but gentler"), and a player who wants more turns them on.
- The menu remembers what you chose last time and offers it again.
- **Older saves** have no options. They load as what they effectively had: Survival with surprises on Usual if `live_hazards` was on (or Off if it wasn't), radiation and injuries on (crew harm already happened), fatigue off. Freedom loads with surprises on Usual.

## 6. How it's built

- **`MHGame.challenge`:** a static dictionary `{fatigue, radiation, injuries, surprises}`, set on the Colony step, saved in the game state and save header, and restored on load.
- **`MHGame.challenge_on(name) -> bool`** and **`MHGame.surprise_scale() -> float`:** the only things the rest of the game asks.
- **`MHGame.raise_challenge(name, value) -> bool`:** the one-way rule in one place. It refuses anything that lowers a value once the game has started; the debug panel calls a separate `debug_set_challenge` that sets the debug mark.
- **`mars_world.configure_life()`:** uses `surprise_scale()` instead of `live_hazards` for `live_kinds` and the breakdown and event rates. `habitat_sim` multiplies its random-storm chance by it. Crew injuries and solar-event doses check `challenge_on("injuries")` and `challenge_on("radiation")`.
- **The global `live_hazards` setting is removed** (it is replaced per game).
- **UI:** a Challenge block in `main_menu.gd`'s Colony step, a Challenge sheet in `pause_menu.gd`, and icons on save cards (`saves.gd` header). All of it uses MHStyle and MHWidgets, as the rest of the menus do.
- **Tests:**
  - a new `tests/challenge_options_test.gd`: the one-way rule, saving and loading, the old-save mapping, Freedom and Missions limits, and surprise scaling of the rates;
  - the existing hazard tests still pass with surprises on Usual.

## 7. Not in this step

- Fatigue, your own radiation dose and your own injuries (step 10).
- New kinds of surprise (with machine wear in step 7, and later).
- Achievements for hardcore runs (on hold).

## 8. Decided (31 Oct)

1. **Surprises on Off:** dust storms still come; they're weather. Off stops only solar events, breaches and breakdowns. More realistic weather, both looks and mechanics, is welcome (backlog).
2. **The surprise level** can go up after the start, never down.
3. **Options that do nothing yet:** fatigue is hidden until step 10; radiation and injuries show, since they already affect the crew.
4. **Defaults:** surprises on Rare; fatigue, radiation and injuries off.
5. **No presets:** just the four rows.
6. **Old saves** load as they played (§5).
