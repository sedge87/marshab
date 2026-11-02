# Game modes

*Decided 2 Nov 2026, with the user. Modelled on Subnautica's modes (similar, not identical). This doc replaces docs/new-game-options.md §4 for the modes; the challenge options in that doc still apply.*

There are four free-play modes: **Survival, Freedom, Creative and Custom**. Missions is separate and will be removed later. **There's no Hardcore mode and no one-life option** (user, 2 Nov).

## 1. The modes, set against Subnautica's

| Subnautica | Outpost One |
|---|---|
| **Survival:** health, oxygen, food and water. Dying drops some items, which you can go back for. A secured inventory (in a base or vehicle) is kept. | **Survival:** suit oxygen, air, food, water, cold, pressure, radiation and health all matter.<br>• If you run out of oxygen on EVA, **GAR-Y drags you home**. You lose time, and **what you carried drops where you fell**, so you can go back for it.<br>• Things in the base or rover are safe (our secured inventory).<br>• If the crew's health hits 0, they retreat to the lander and you repair the base. |
| **Freedom:** no food or water. The fabricator's Sustenance tab is gone. | **Freedom:** **nobody needs food or water**.<br>• The food chain is optional, and its plans are hidden from the fabricator (our Sustenance tab).<br>• Water still matters if you build a shower.<br>• Air, cold, pressure, radiation and suit oxygen still matter and can hurt. GAR-Y still rescues you.<br>• Every plan is known from the start. Stores last 150 sols, and the landing is exactly on target. |
| **Hardcore:** one life, no low-O₂ warnings, Save & Quit only. | *None.* |
| **Creative:** no needs or damage; no materials, blueprints or energy needed. Story progress is still possible. | **Creative:** no simulation, unlimited cargo, every plan, and the rover's battery never runs down.<br>• Mission Control's voices, samples and Discoveries still work, so the story can still be followed. |
| **Custom** (Below Zero): configure almost everything; a save can be converted to Custom; no achievements. | **Custom:** start from Survival, Freedom or Creative and change each rule.<br>• **Pause → Rules → Convert to Custom** works at any time. It's one-way, and the save is marked Custom.<br>• Achievements are on hold anyway. |

**The same in every mode:** the landing. You pick the site on the region map, read the orbital report and watch the descent cutscene. "Skip the descent" is an option everywhere, off by default. Only the landing accuracy differs: within the ellipse, or on target.

## 2. The rules

Each mode is a preset of the same rules (`MHGame.MODE_RULES`). Custom lets you change them.

| Rule | Survival | Freedom | Creative |
|---|---|---|---|
| Life support simulated | ✓ | ✓ | ✗ |
| Food and water needed | ✓ | ✗ | ✗ |
| Suit oxygen runs down | ✓ | ✓ | ✗ |
| Shortages hurt | ✓ | ✓ | ✗ |
| Plans | earned | all known | all known |
| Starting stores | 90 sols | 150 sols | — |
| Cargo | crates | crates | unlimited |
| Landing | in the ellipse | on target | on target |
| Lab analysis | normal | fast | fast |

**The challenge options** (docs/new-game-options.md) sit on top of the rules: surprises, wear pace, radiation and injuries.
- They're one-way in every mode: switch on later, never off.
- They're offered whenever the simulation runs. In Freedom they now include radiation and injuries, because shortages hurt there too.

**Crew size** is its own choice: Solitary, Small, Standard or Large (docs/survival-systems.md §12.2).

## 3. Old saves

- A save from before the rules loads with its mode's preset.
- An **old Freedom save keeps what it had**: food and water needed, nobody hurt.
- Old Survival and Creative saves are unchanged.

## 4. The menus

- **A new game has three steps: Colony → Rules → Land.**
  - **Colony** is who you are: the names, emblem, accent, statement and the live plaque.
  - **Rules** is how you play:
    - four mode cards, each with ✓/✗ ticks;
    - the crew size;
    - the challenge rows;
    - Custom's full rules;
    - the tutorial choice;
    - a one-line summary.
  - **Land** is the landing and the descent.
- **In a game:** Pause → **Rules** shows the mode and its rules, the one-way challenge rows, and Convert to Custom.
