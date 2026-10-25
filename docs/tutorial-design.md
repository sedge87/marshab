# Tutorial and first-time hints: design (25 Oct)

Playtest feedback: new players don't know what to do first. Missions teach
the systems; nothing teaches the *game* (moving, building, the keys). This
proposes two pieces, built in this order:

1. **A guided tutorial**, offered at the start of every new game (the way
   Stellaris's advisor offers it), that walks players through getting a
   habitat started.
2. **First-time hint cards with moving pictures**, which pop up the first
   time a player opens a feature, showing *how* to do the thing.

**Built 25 Oct.** Where it lives:

- `data/tutorial.json` holds the 14 steps; `scripts/tutorial.gd` is the
  tracker (Survival, Freedom and Creative; Creative skips the systems-panel
  step).
- `scripts/guide_overlay.gd` holds the highlights, key caps and Show me, and
  works out each step's extras.
- `scripts/mission_hud.gd` puts the same guidance on mission steps, and
  `data/missions.json` gets a tutorial-only "look" step.
- `data/feature_hints.json` and `scripts/feature_hints.gd` are the
  first-time hint cards.
- The clips are made by `tools/capture_hint_clips.gd` and
  `tools/record_hint_clips.sh`, and saved to `assets/tutorial/clips/*.ogv`.
- The Land step has the Tutorial choice, and Pause → Settings has
  "Tutorial (this game)".
- Tests: `tests/tutorial_test.gd`.

Changes from the plan:

- There are 14 steps, because oxygen equipment needs a Life Support room.
- Advancing works by checking game state four times a second, not by
  signals.
- There are no clips yet for the Test (T) or GAR-Y orders; those steps just
  have no Show me button.

---

## 1. The tutorial

### Offering it

On the new-game Land step, below the mode choice, there's one new setting:

> **Tutorial** · Full · Hints only · Off

- **Full**: the step-by-step tutorial below, plus first-time hints.
- **Hints only**: no steps; the first-time hint cards (part 2) still appear.
  This is for players who know the game.
- **Off**: nothing pops up. The Field guide still has everything.

The default is **Full** until the player has finished the tutorial once
(remembered in settings, not in the save), then **Hints only**. It can be
changed at any time from Pause → Settings, and turning it back to Full
resumes from the step you were on.

The tutorial works in Survival, Freedom and Creative. Steps that need the
simulation (power, air) still make sense in Creative because the HUD readouts
still show; they just can't go wrong there. In **Missions** mode the missions
are the lessons, so only the first five steps run (movement, the lander, build
mode, placing and undoing). After that, Mission Control takes over.

### Who's talking

Stellaris uses a named advisor with a voice. Ours is **ARDEN**, the
habitat's own computer. It's already the voice that speaks the captions, and
it's named after the colony (MHGame.habitat_name). GAR-Y stays the robot
helper you meet in the world, with its own personality. (The alternative is
GAR-Y as the advisor; see the questions at the end.)

### How it looks

A compact panel at the top right (it doesn't cover the build bars), in the
house style:

```
┌ ARDEN · GETTING STARTED  4 / 12 ───────── [▶ Show me] [–] ┐
│ Put down your first room                                  │
│ Press B for build mode, pick Living Quarters from the     │
│ bar, then drag out a 2 × 2 room on the flat ground.       │
│ ☐ Build mode open   ☐ Living Quarters chosen   ☐ Placed   │
└───────────────────────────────────────────────────────────┘
```

- **Objectives tick themselves off** from what you actually do (game events),
  never "click Next". A step with no action to detect, such as a read-only
  explanation, has a single Continue button.
- **Highlights**: like Stellaris, the UI element a step needs (a build-bar
  button, the life-support readout, the Mission Control key) gets a soft
  pulsing outline and an arrow from the panel. World targets (the lander
  hatch, a spot of ice-rich ground) get a floating marker like the rover's
  home marker.
- **▶ Show me** plays the step's short clip (see part 2) in a pop-out above
  the panel.
- **[–]** collapses the panel to a one-line strip. **Skip tutorial** is in
  its menu, with a confirmation.
- Every step's text is short: two sentences, plain words, keys shown as key
  caps (the same `control_row` style as the Controls sheet).

### The steps

Each step is: what to do → how it's detected → what's explained once it's
done.

| # | Step | Done when | Then ARDEN says (one line) |
|---|------|-----------|-----------------------------|
| 1 | **Look and move**: WASD, mouse, Shift to sprint | walked 5 m and looked around | "Mars is cold, airless and bright. Your lander is home for now." |
| 2 | **Step outside**: E on the hatch | hatch open and you're outside | "Outside, the HUD shows the time of day and the weather. Dust storms cut solar power." |
| 3 | **Build mode**: B | build mode open | "This is the site plan. Blue ground has ice under it; keep clear of the landing zone." |
| 4 | **Your first room**: pick Living Quarters and drag a room out | a room is placed | "Rooms cost cargo. Ctrl+Z undoes, X removes and refunds." |
| 5 | **A way in**: add an airlock on an outside wall | an airlock is placed | "An airlock keeps the air in: one door is always shut." |
| 6 | **Power**: put a solar array on a cell (R turns it to face north) | a solar array is placed and connected | "Solar only works by day. You'll need batteries or a reactor for the night." |
| 7 | **Water**: find blue ground and place an ice drill | an ice drill is placed | "Water is for drinking, for growing food, and for splitting into oxygen." |
| 8 | **Inside**: Shift+B to Interior mode, place a bunk and the oxygen equipment | both placed | "Every room needs equipment. The catalogue (Tab) says what each item does." |
| 9 | **Check the base**: open the life-support readout and read power, air, heat and water | the readout is opened | "Green is fine; amber needs attention; red is urgent." |
| 10 | **Go in through the airlock**: walk in and cycle it | you're inside the habitat | "Inside, the doors open by themselves. Only airlock doors interlock." |
| 11 | **Time and the crew**: open the crew screen (C) | the crew screen is opened | "The crew need sleep, food and things to do. Z sleeps at a bunk." |
| 12 | **Save, and where to learn more**: Esc, Save | a save is made | "The Field guide (Esc) explains every system. Good luck." |

The exact equipment and room names come from the catalogue when it's built.
Steps whose objective is already met when they come up are skipped, so a
player who builds ahead isn't stuck.

### Under the hood (for later, in brief)

- `data/tutorial.json` holds the steps: their text, objectives (event names
  plus a count), highlight targets, world marker, clip and the line said
  after.
- `scripts/tutorial.gd` is an autoload-style node in the world. It listens
  to signals the game already has or will gain (`zone_placed(kind)`,
  `build_mode_changed`, `interior_placed(id)`, `hatch_opened`,
  `panel_opened(name)`, `saved`), advances, and saves its step in the save
  file.
- Highlights find their UI target through a `tutorial_target` meta on the
  control, so moving a button never breaks the tutorial.
- Tests: walk the 12 steps in a headless world by triggering each event.

---

## 2. First-time hint cards with moving pictures

These already half exist: `HowItWorks.first_time` shows a Field guide card
the first time you place something, and the cards have hand-drawn diagrams.
What's missing is **the first time you open a feature** (not just placing
an item) and **showing how**.

### When they appear

The first time (ever, per player profile, not per save) you:

- open build mode, the site plan, Interior mode or the catalogue;
- pick up an object, sit in the rover, open Mission Control or the crew
  screen;
- open the Site plan's shielding or insulation tools;
- see a first warning, such as low power or a storm.

When it appears, the game pauses, as the cards do now. There's one hint per
feature, with a "Don't show hints" checkbox (the existing `tutorial_cards`
setting). Hints are queued, never stacked.

### What's on them

A hint is smaller than a Field guide card:

```
┌──────────────────────────────────────────┐
│ ▶ [ 6-second looping clip, 16:9 ]        │
│                                          │
│ BUILD MODE                               │
│ Drag on the ground to lay out a room.    │
│ [R] turn  [RMB] cancel  [Ctrl][Z] undo   │
│                       [Field guide] [OK] │
└──────────────────────────────────────────┘
```

**The moving picture: recommended, real gameplay clips.**

- These are short (4–8 s) silent loops recorded **from the game itself** by a
  tool script, the same way the trailer footage was captured
  (`tools/capture_hint_clips.gd`). Each clip is a scripted few seconds, for
  example the cursor dragging a room out or E opening the hatch, with the
  key press shown as an on-screen key cap.
- They're saved as Ogg Theora `.ogv` (Godot plays it natively, with no
  plugin), at 960×540 and 24 fps. That's about 300–600 KB each, so roughly
  15–20 MB for 30 clips.
- When the UI or models change, one command re-records them all, so they
  never go stale.

The alternatives, considered:

- **Animated diagrams** (moving the current drawn pictures): small and
  always in style, but they show the *idea*, not the keys and the screen.
  These stay for the Field guide's *why* cards.
- **GIFs**: Godot can't play them without a plugin, and they're huge and
  low quality.
- **Live in-world demonstrations** (a ghost cursor in your own world): the
  most magical, but fragile and a lot of work per hint.

The tutorial's **▶ Show me** uses the same clips.

---

## 3. Afterwards: a better renderer

The game runs on **Compatibility** (OpenGL), which is behind most of the
lighting jank: no proper global illumination, limited shadows and a light
budget per object. The plan is to move to **Forward+** (Vulkan or
Direct3D 12) once the tutorial is in, which brings:

- SDFGI or VoxelGI bounce light, so rooms are lit by their light panels and
  windows rather than fill lights;
- better shadows, volumetric fog for dust storms, and SSAO;
- no per-object light limit, so the room-fill workaround can go.

The risks to check first:

- **Weaker PCs.** Forward+ needs a Vulkan or D3D12 GPU. Integrated graphics
  on older laptops will struggle. We'd add a graphics-quality setting (Low
  turns off GI and SSAO) and test on the weakest machine players will use.
- **Every light, emissive and material needs re-tuning.** Some values were
  set to look right under Compatibility (`docs/lighting.md`).
- **The movie writer and screenshot tools** must still work. They do, but
  the clips would be re-recorded after the switch.

This gets its own short design pass when we get there.

---

## Decisions (25 Oct)

1. **Advisor: ARDEN.**
2. **Missions mode gets guidance too.** Missions already have a step tracker
   with "how" text, so ARDEN adds to it rather than running a second list:
   a short controls track (look, move, use) before Mission 2's first step,
   and on every mission step the same extras as the tutorial (key caps,
   highlights, a world marker, P to Show me).
3. **Clips: real gameplay** wherever possible, recorded by
   `tools/capture_hint_clips.gd` and converted to `.ogv` (ffmpeg has
   libtheora).
4. **No carrying step.** In this game "carrying" means picking up small
   things (mugs, books, plants); cargo is a weight budget, not boxes. Instead,
   picking something up for the first time gets a hint card.
5. **Laptops: Dell i5s with integrated graphics** (probably Intel Iris Xe).
   Forward+ runs there, but bounce light (SDFGI) is too heavy, so the
   renderer pass needs quality presets with Low as the laptop default, and a
   test build to try on one of them.

**Show me** is P (the only free letter that reads well).
