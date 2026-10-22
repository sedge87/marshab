# Designs for backlog batches 4, 5 and 6 (for approval)

These are proposals: nothing in them is built on `main`. Each section ends with the decisions I need from you. The order is 4 → 5 → 6, because harder missions need the base to explain what is going wrong, and the dossier should record those missions too.

---

## Batch 4 · Habitat alerts that teach (item 26)

### Where it starts from
`HabitatSim.warnings()` already produces plain-language problems ("CO₂ is 0.8% and rising: there is no air recycler"). They only show as small lines in the systems panel, so students don't notice them until something has already failed.

### The idea: the habitat speaks up, like Subnautica's PDA
A calm habitat computer voice tells you about a problem when it **starts**, not after it fails. It tells you the cause and **what it connects to**, so students see the systems link up.

**Three levels, each with its own sound:**

| Level | When | What you see and hear | Repeats |
|---|---|---|---|
| **Advisory** (blue) | A trend that will become a problem, e.g. battery under 40% at sunset, or a storm forecast | Soft chime, one line at the top of the screen | Once |
| **Warning** (amber) | A value is outside the comfortable range, e.g. O₂ under 20%, CO₂ over 0.5%, a room under 12 °C | Two-tone chime, line plus cause chain | Every 90 s while it lasts |
| **Critical** (red) | Danger to the crew, e.g. O₂ under 19.5%, CO₂ over 1%, life support off, water or food at zero | Alarm tone, red edge pulse, amber strobe in that room | Every 30 s, until fixed |

When something is fixed: "Oxygen back to normal." (a green tick, no repeat).

**The cause chain** is the teaching part. Each alert carries a short chain of linked chips under its line, for example:

```
⚡ Power: batteries flat at night  →  🫧 Oxygen generator: off  →  O₂ 19.8% and falling  →  ❤ Crew health
```

The chain is built from the simulation's real state: which power tier dropped, which machine is unpowered, which store is empty. It is never a canned sentence.

**"What's happening?" card.** The first time each alert type appears, press **I** for a short explainer (3–4 sentences of real science, plus what to build or change). After that it's in the alert log.

**Alert log.** A new **Alerts** tab in Mission Control lists every alert with its time, level, cause and when it was resolved. The **test report** also lists the alerts that would have fired during the test, so students see the early warning they would have had.

**Wall screens.** In Status mode the wall screen shows the active alerts.

### The voice
- **Option A (recommended):** a synthetic voice (generated offline with Windows' built-in speech engine and saved as audio files) says a short, fixed line, e.g. "Warning. Oxygen level falling." The exact numbers are shown as text only, so about 40 short clips cover every alert. It sounds like a calm computer, which suits a habitat.
- **Option B:** chimes only, no voice.
- **Settings:** an alert voice volume slider, an "Alerts: all / warnings and critical / critical only" choice, and no alerts in Creative.

### How it's built
`data/alerts.json` lists each alert type:
- the condition and the thresholds for each level, read from the balance sheet;
- the text template and the voice clip;
- the cause resolver (a function name in `scripts/habitat_alerts.gd`);
- the explainer text.

`scripts/habitat_alerts.gd` checks the sim twice per game-hour, tracks which alerts are active and how long they have lasted, and raises, escalates and clears them.

About 12 alert types cover the current sim: power, battery-at-sunset, storm, O₂, CO₂, cold, water, food, crew health, berths, unpowered life support, and an airlock left open.

### Decided (23 Oct) and built
1. **Voice:** like Subnautica, a calm synthetic voice saying short fixed lines (Windows "Hazel", en-GB, generated offline by `tools/generate_voice.py`; 28 lines in `assets/audio/voice`).
2. **No name,** as in Subnautica: it's the habitat speaking. It says "Welcome aboard" the first time you come in, and "Welcome home" after that.
3. **Alerts don't pause** fast-forward or the Test. The Test report lists "What the habitat would have told you".
4. **Freedom mode:** alerts are on, and the crew can't come to harm.

Settings: a **Habitat voice** volume slider (Audio), and a **Habitat advisories** toggle (warnings and critical alerts always sound). Mission Control has an **Alert log** button.

---

## Batch 5 · The mission dossier (item 27)

### Where it starts from
Every Test already saves a **version**: its design summary, the result of each check, pass or fail, the time, and what changed since the last test.

### What the dossier adds
- **Before a test:** an optional one-line **prediction** ("What do you think will happen?"). Students can skip it.
- **After a test:** an optional **note** ("What will you change, and why?").
- **Per version:**
  - a top-down plan image and a ¾ exterior render (captured automatically when testing);
  - the graphs, downsampled;
  - the failure reasons and tips.
- **What fixed it:** for each check that went from fail to pass, the dossier names the change between those two versions, e.g. "+2 batteries, +1 thermal control unit".
- **Stretch goals,** met or not.

### Where you read it
- **Mission Control → Dossier tab.** A timeline of each mission's versions (✓ and ✗ per check). Click a version to see its graphs, images and notes. Compare any two versions side by side.

### Export (for the portfolio and the showcase)
**Export dossier** writes one self-contained HTML file to `Documents/MARS HABITAT/` with images and charts embedded. It opens in any browser, and *Print → Save as PDF* gives a clean A4 PDF. It contains:
- a cover with the student's name, the colony name, the site and the colony accent;
- a contents page;
- one section per mission: the goal, the NASA step, every version, the final design, what failed and what fixed it, the stretch goals, the predictions and notes;
- an appendix with the final base's systems summary.

### Decided (23 Oct)
1. **Student name:** asked when Missions starts, and editable on the export screen.
2. **Prediction and note prompts:** optional, with a Skip button.
3. **Export:** both. One file for the whole campaign, plus a per-mission export from each mission's dossier page.
4. **CAT headings:** none needed. Use the plain headings above.

---

## Batch 6 · Bigger features

### 28 · Outside cameras and a habitat monitoring station (revised 23 Oct)
You'd rather not have cameras in every room. The revised idea is two things.

**Outside observation cameras (optional).**
- A camera mast you place outside (an outdoor item, up to 4), pointing wherever you aim it when you place it, e.g. at the solar field, the drills or the landing pad.
- Its feed shows in Mission Control and on wall screens (a "Camera" mode).
- Only one feed renders live at a time (480×270), so it's cheap.

**Habitat monitoring station (Mission Control).**
- A new **Monitor** tab that shows the base working in real time. It's built from data, not cameras, so it costs almost nothing.
- **The habitat map, live:** each room is tinted by its state (green fine, amber warning, red critical) and labelled with its temperature, lights on, dim or off, and crew present.
- **Click a room** to see its machines: on or off, powered or not, and what each one is doing (e.g. "Air recycler: scrubbing 1.2 kg CO₂ a sol").
- **Whole-base flows:**
  - a power bar (made vs used, battery %, time to empty);
  - air (O₂ and CO₂ with arrows);
  - water and food (made vs used, sols left);
  - the active alerts from batch 4.
- **A 24-hour strip** of the last sol for power and battery, so students can watch the day/night cycle play out.
- **Optional:** a physical "Monitoring Station" console item. Using it opens the same view, so it fits the habitat fiction.

### 29 · GAR-Y orders
- **Radial menu:** hold **G** while looking at GAR-Y, or from anywhere if it's within 30 m. The orders are:
  - **Come here**;
  - **Stay**;
  - **Go home** (to its dock);
  - **Survey there** (aim at the ground, or click the Mission Control map);
  - **Fetch** (sample jars, the plush or a named item, brought to you);
  - **Patrol** (loops the base at night, checking doors).
- **From Mission Control:** click GAR-Y on the map, then click a destination.
- Its eyes and toasts say what it's doing ("Off to survey: 34 m"). Orders respect its rules: no airlocks on its own, interior doors only.

### 30 · Missions that use GAR-Y
- **Mission 2** gets a first step: "Survey for ice before you drill." Order GAR-Y to survey three spots. Drills on flagged ice get their real richness, and unflagged ground shows as "unknown" until surveyed. This teaches prospecting before investing.
- **Mission 6** gets a stretch goal: "Send GAR-Y for a core sample." It brings a sample to the Science Lab for +20% research for 10 sols.

### 31 · Ten missions, built on NASA's five hazards (radiation, isolation, distance, gravity, hostile and closed environments)
Missions 1–6 stay as they are (with the GAR-Y additions above). There are four new ones, and each one needs a new simulation mechanic:

| # | Mission | Hazard | What students must build or do | New mechanic |
|---|---|---|---|---|
| 7 | **Solar Storm Shelter** | Radiation | A shielded shelter (water walls, storage stacked around a small room) big enough for the whole crew. Get everyone in within 15 minutes of the warning. | Radiation dose per room (shielding value per wall from what's around it); a solar particle event in the Test |
| 8 | **Medical Emergency** | Distance from Earth (no evacuation) | A Medical Bay with an exam cot, a medical cabinet and its own power. Treat an injured crew member while keeping the other systems running. | An injury event; treatment needs medical kit plus power for N hours; recovery affects crew health |
| 9 | **Hull Breach** | Hostile/closed environment | Compartments: pressure doors between rooms, spare patch kits, an emergency O₂ reserve. A micrometeoroid hit vents one room, and the rest must hold air. | Pressure per room; doors seal automatically on a breach; repair with a patch kit |
| 10 | **The Long Silence** | Isolation and distance | A 200-sol run through solar conjunction (14 sols without contact from Earth): spares for each critical system, redundancy (two of anything life-critical), and crew morale (privacy, exercise, plants, windows, the odds and ends). | Random equipment failures (repaired with spares); a morale score feeding crew health |

Water contamination fits into Mission 9 or 10 as a failure event. Gravity (bone and muscle loss) becomes the exercise requirement in Mission 10.

Each new mission is roughly one lesson. Missions 7–10 also put the **alerts** (batch 4) to work, which is why alerts come first.

### 32 · Showcase mode
- **Starting it:** Main menu → Showcase. Choose any save; the colony name and student name show on a plaque.
- **The camera:**
  - a cinematic orbit of the base;
  - then a slow walkthrough of every room, using the observation cameras where there are any;
  - then a "sol in 60 seconds" time-lapse with the lights and sun moving.
- **On screen:** large live stats (crew, power, O₂, water, food, research), plus the dossier's headline facts, e.g. "Passed Mission 6 on version 4".
- **No build interface.** Esc returns to the menu. An attract loop runs unattended for the showcase night.

### Decided (23 Oct)
1. **Cameras:** none inside rooms. Outside cameras are optional, and there's a habitat **monitoring station** in Mission Control (see 28).
2. **GAR-Y orders:** hold **G**. Approved.
3. **Missions 7–10:** parked. We'll work out what each one asks students to do before building any. The four above are only candidates.
4. **Showcase:** the student's name is optional.

---

## Build order
1. ~~**Alerts** (batch 4).~~ Done 23 Oct.
2. ~~**Dossier and export** (batch 5).~~ Done 23 Oct.
3. ~~**GAR-Y orders**, then the Mission 2 and 6 additions (batch 6, items 29–30).~~ Done 23 Oct.
4. ~~**Monitoring station**~~ (done 23 Oct: Mission Control → Monitor, or E on the Mission Planning Console), then ~~the outside cameras~~ (done 23 Oct: a 6 m Camera Mast outdoors, up to 4, with a pan-tilt head; Mission Control → Cameras, E on a mast, or a wall screen's Camera mode), then ~~**Showcase**~~ (done 23 Oct: the Present button beside any save on the title screen). Showcase can use the monitoring view and the cameras.
5. **Missions 7–10:** design them together first (item 31).
