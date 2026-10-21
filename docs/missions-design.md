# Missions mode: draft design

**Built so far (phases 1 and 2):** the whole six-mission campaign is playable from the title screen, with its own saves.
- **Mission 1:** Landing Zones, in the Land step.
- **Missions 2–3:** each opens with a cargo lander touching down, and the robot rolls out of the hold.
- **Mission 4:** the crew land in their own lander and step out of the cabin.
- **Missions 5–6:** the storm season, then six crew for 100 sols.

Every mission has a short brief, a step tracker, a payload budget, its unlocks, and the Test (T) with a report and graphs. After each mission, **Start Mission N** loads the next one's arrival. After Mission 6, a copy of the base carries on into Survival, Freedom or Creative.

The data is in `data/missions.json`, and the code in `scripts/mh_missions.gd`, `scripts/mission_hud.gd` and `scripts/mars_world.gd`. `tests/missions_campaign_test.gd` checks that each mission can be won and that a weak design fails it; `tests/missions_flow_test.gd` checks the arrivals.

**Phase 2 decisions (22 Oct, built overnight; review these):**
- **Crew size per mission:** 0 for Missions 2–3, 4 for Missions 4–5, 6 for Mission 6. The simulation caps the crew at the mission's number.
- **Warm start:** tests start with the rooms already warmed, the same way they start with full batteries. Heating has to hold the temperature, not warm the rooms up from −60 °C.
- **Mission 6 resupply:** the supply lander brings 60 sols of food for all six crew. It's needed: 4 crew × 60 sols of lander food can't cover 6 crew for 100 sols, even when growing a quarter of it. "Choosing how much food to bring" as a cargo trade-off is still to do.
- **Six crew need two of each:** two oxygen generators and two air recyclers. The Mission 6 hints say so.
- **Long tests:** Mission 6's 100-sol test steps every 0.5 h, so it runs in about 2 s. Room temperature now relaxes exponentially, which stays stable at any step size; the normal 0.1 h step behaves as before.

A draft to edit before anything is built. Missions takes students through
NASA's **Understand → Design → Test → Improve** process while they build a
sustainable habitat, following the steps NASA would likely use to set up a base
on Mars: choose the site, send the cargo first, check everything works, then
land the crew. It also teaches the game step by step, so it can later
become a plain tutorial and campaign: the classroom-only parts switch off
with one setting (see *Two layers* below).

## Two layers

| Layer | What it is | Classroom features **on** (default) | Classroom features **off** (tutorial or campaign) |
| --- | --- | --- | --- |
| **Mission layer** | The missions, requirements, unlocks, hints, testing and versions | ✓ | ✓ |
| **Classroom layer** | Engineering-process framing, design-log questions, predictions and the teacher report | ✓ | Hidden |

With classroom features off:
- The phase names become **Brief → Build → Test → Improve**.
- There are no written prompts and no report export.
- Everything else plays the same.

Mission content lives in one data file (`data/missions.json`), so missions can be added, reordered or reworded without code.

## The lander: where the game begins (like Subnautica's lifepod)

The lander's only job is to be a **safe place to start**, so the first thing
students experience is a moment of wonder: stepping out onto Mars. It isn't a
resource system. It has no supplies to manage and no cargo store.

**The opening:** every new Survival or Freedom game starts this way. In Missions it's the reward at the start of Mission 4, when the crew finally land.
1. Students wake inside the lander's cabin after landing. It's quiet, dim and enclosed: seats, consoles, small windows glowing orange, dust settling outside.
2. A console (or the first tutorial hint) points to the hatch: "Open the hatch".
3. The hatch opens and the ramp lowers. Light floods in, dust drifts across the opening, and the site appears: the cliffs, the crater rim or the open plain.
4. They walk down the ramp onto Mars. The HUD and compass fade in, and the game begins.

**After that:**
- **It's always safe.** Inside, the crew are sheltered, so it's somewhere to return to, warm up and save.
- **It's a landmark** on the site map and compass, and a respawn point.
- **Where it lands:** in free play, students build wherever they choose, next to it or somewhere better. In Missions it lands next to the base the robots have already built. Either way it doesn't connect to the habitat.
- In Creative mode the opening can be skipped.

**The look:** completely different from the habitat modules. It's a real spacecraft on legs, not a box. The brief is Pack L in [furniture-pack-brief.md](furniture-pack-brief.md). **Built:** a first version and this opening are already in the game (`scripts/crew_lander.gd`) for Survival and Freedom.

## The campaign: one site, cargo first, then the crew

NASA's plans for Mars send the cargo separately from the crew, and first. Uncrewed cargo landers
arrive one launch window earlier, about 26 months, which is the gap between good Mars launch windows.
Robots set up power, water and the habitat, and everything is checked from Earth
before the crew leave. The campaign follows those steps on **one site the student
chose in class**. The site choice, the transit to Mars and EDL (entry, descent and
landing) are covered in class before the game, so the game starts on the
surface and builds on that work. Each mission is the next cargo landing, so the base grows from mission
to mission. An early decision has to be lived with, or worked around, later on,
just like real engineering.

| # | Mission | NASA step | Crew | Payload | New this mission | It passes when… |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Landing Zones** | Site selection is already done in class; this is landing planning (building on their EDL work) | — | — | Pick the site chosen in class; choose the **landing target** for the landers; see the **landing ellipse** they could touch down anywhere inside | The whole landing ellipse is on flat, safe ground, and far enough from the planned base that engine blast can't damage it. *Classroom:* a short note links back to their site choice and EDL work. |
| 2 | **Cargo Landing 1: Power and Water** | Pre-deploying power and ice mining | None (robots) | 12 t | Site plan only (no walking yet); solar facing, batteries, reactor option, ice survey, drills | Power runs unattended through every night and a dust storm; the drills stockpile at least 1,500 L of water before the crew come |
| 3 | **Cargo Landing 2: The Habitat** | Checking out the habitat before the crew launch | None (robots) | 20 t | Rooms, airlock, Life Support (air recycler, oxygen generator, thermal control, water reclaimer) | The empty habitat stays above 15 °C with breathable air for 10 sols, powered by the Mission 2 system |
| 4 | **The Crew Land** | Crew arrival | 4 | 10 t + the crew | **The lander opening**, walking around, bunks, galley, hygiene, medical | The first 10 sols with people aboard: CO₂, oxygen, water, food and temperature all stay safe |
| 5 | **Dust Storm Season** | Surface operations | 4 | 6 t | Load priority, switching things off, storm planning | Life support stays powered through a 5-sol storm; crew health stays above 80% |
| 6 | **Toward Self-Sufficiency** | Expanding and sustaining the base | 6 | 14 t | Hydroponics, science, the full crew, **choosing how much food to bring** | 100 sols for 6 crew: grow at least 25% of the food, run research, and keep every system safe |

The payloads add up to about 62 t over the campaign, close to the free-play budget.
Each one is a separate delivery: students can't spend Mission 6's cargo in
Mission 2.

**Robots first (Missions 2–3).** Before the crew arrive, students work only in
the site plan, as mission planners directing robots. This is how real
pre-deployment works, and it makes a gentle tutorial for building before they
ever walk around. The first time they walk on Mars is when the crew land in
Mission 4, next to the base they designed and tested.

**Landing zones and the landing ellipse (Mission 1).** A lander can't touch down
on an exact spot. It comes down somewhere inside a **landing ellipse** around its
target, which is one of the key ideas from EDL. In the game:
- Students choose a **landing target** on the site map. An oval a few cells across shows the ellipse: everywhere the lander might come down.
- The ellipse turns green when every part of it is flat and safe, and far enough from the planned base that engine blast can't damage anything. It turns orange or red if some of it is near cliffs, mounds or buildings, and the game says which.
- Each landing then **touches down at a random point inside the ellipse**. Every cargo landing and the crew lander in Mission 4 lands there, so a target that is "mostly fine" can still go wrong.
- The lesson: plan for the whole ellipse, not just the centre. That's exactly why NASA needs large flat landing areas.

**Choosing where to land in free play.** New free-play games also let students
pick their landing target before the opening:

| Mode | Where the lander comes down |
| --- | --- |
| **Survival** | Somewhere inside the landing ellipse, as in Missions |
| **Freedom** | Exactly where they pick |
| **Creative** | Exactly where they pick |

**Stretch goals** (optional stars, for students who finish early):
- **Mission 1:** a landing zone within 40 m of the base: close enough to be handy, but still safe.
- **Mission 2:** no reactor.
- **Mission 3:** 15% of the payload to spare.
- **Mission 4:** no water reclaimer.
- **Mission 5:** no power cuts at all.
- **Mission 6:** grow 40% of the food.

Missions unlock in order. A **teacher setting unlocks all of them**, starting each
from a prepared base, for catching up or for showcase prep.

## The end of the campaign: carry on in free play

When Mission 6 is complete, students see a short wrap-up: their base, how many
versions they tested, and what they achieved. Then they choose how to carry on with
**their own base**:
- **Survival:** keep living there for real, with no mission goals.
- **Freedom:** keep expanding without risk.
- **Creative:** turn it into a dream base with unlimited cargo.

Carrying on makes a **copy of the base in the Free play saves**. The finished
campaign stays in the Missions saves, untouched, for the teacher report and the
showcase.

## The loop inside every mission

### Arrival, short brief and steps (built 21 Oct, after playtest feedback)
Playtesting showed that jumping from the menu straight into the Mission 2 brief was jarring, and that it wasn't clear what to do. Each mission now opens like this:
- **Touchdown cinematic.** Cargo Lander 1 descends with its engine burning and dust blowing out, then touches down inside the landing ellipse. Captions close Mission 1 ("Landing zone and base site chosen") and introduce the payload. It plays once per mission, and any key skips it.
- **The robot rides down in the hold.** You start inside the cargo lander (`scripts/cargo_lander.gd`, a procedural lander that looks nothing like the crew lander). Pressing E on the ramp door lowers it, and you roll out onto Mars. The landers stay on site (saved in the campaign progress), so Mission 3 adds a second one.
- **Short brief card.** It shows what's happening, your goal and the first step, with a "Full brief (J)" button for everything else.
- **Step tracker.** Each mission lists steps in `data/missions.json` (`steps`: the text, how to do it, and a check). They tick themselves off with a chime and a toast, and the mission panel shows them with the current step expanded. While building, a "Next step" pill stays on screen. Steps with a `marker` put BASE SITE or BEST ICE on the compass. The step checks are `left_lander`, `opened_plan`, `zone`, `item`, `tested` and `passed`.

### 1. Understand (Brief)
The full brief (J):
- **The situation:** two or three sentences of story, for example "The first cargo lander is on its way. Its robots must have power and water running before the crew even leave Earth."
- **Requirements:** plain language, each one measurable, with an icon. These are the checks the Test phase uses.
- **Constraints:** crew, length, cargo budget, and what's unlocked.
- **Know your site:** cards for the sun, day and night temperatures, ice and dust storms, reusing the site data and the survey board.
- *Classroom:* "Ask yourself" questions, and one **prediction**: "Which requirement do you think will be hardest?" The answer is saved for the report.

### 2. Design (Build)
Normal building on the mission site, plus:
- **A mission panel** listing the requirements, each with a live hint from the simulation, for example "Power through the night: probably short, about 40 kWh."
- **Tutorial hints:** short, step-triggered tips such as "Press B to open the site plan", "Drag to place Living Quarters" and "Solar arrays catch more sun facing the equator". Each one closes when the step is done. These are what make Missions double as the game's tutorial.
- **Cargo manifest** (in Mission 6): sliders for food, spare oxygen and starting water, each counted against that payload.
- *Classroom:* a short "Why did I choose this?" note box that is always available, never forced.

### 3. Test
A **Test** button runs the mission in fast-forward on a copy of the habitat, so the student's build is never changed:
- The whole mission length runs in a few seconds, with a progress bar.
- The mission's **events** play out: nights, a scripted dust storm, or a failure such as "the air recycler breaks for 6 hours on sol 2".
- A **test report** shows each requirement as pass or fail with the reason, taken from the simulation's warnings. For example: "Failed on sol 1 at 03:10. The batteries ran empty, so heating switched off, and Living Quarters fell to 4 °C."
- **Graphs** over the mission show battery, water, food, oxygen and CO₂, the coldest room and crew health, with the moment of failure marked.
- **Watch it live (optional):** replay the test in first person at high speed, with day and night passing. This is good for the showcase.

### 4. Improve
- Each test saves a **version** of the design: what was built (rooms, key equipment, cargo used), the results, and the notes.
- **Compare** any two versions side by side, for example "Version 2 → 3: +2 batteries, night power now passes".
- *Classroom:* after a failed test, three short prompts. They're optional, but the report shows which were answered:
  1. What went wrong?
  2. What will you change?
  3. Why should that fix it?
- Passing every requirement completes the mission. The goal is improvement, so **more versions are never penalised**.

## Saving

- **Separate saves:** Missions use their own save set (already built), so free-play saves never touch mission progress.
- **Autosave:** the campaign's base saves automatically, with no manual slots to manage. A snapshot is kept at the end of each mission, so the teacher setting can start any mission from a prepared base. Progress also records the chosen site, completed missions, stars, versions, notes and predictions.

## Teacher report (classroom layer)

**Export report** writes a printable HTML file to the computer's Documents
folder. It opens in any browser and can be saved as a PDF. For each mission it includes:
- the prediction
- every version, with its design summary, test results, graphs, notes and a screenshot
- what changed between versions
- the final result

This is ready-made evidence of the engineering process for the CAT.

## Showcase mode

Showcase is launched from the main menu with any mission or free-play save:
- **Camera:** a cinematic orbit of the habitat, then a slow walkthrough of its rooms.
- **On screen:** large live stats.
- **Run a sol:** a button that plays a full day and night at visible speed.
- **No build interface**, so it's ready for the arts and tech showcase.

## How it fits the code (for later)

- `data/missions.json` holds each mission's site, crew, length, budget, unlocks, requirements, events, hints, brief text and classroom prompts.
- **Mission controller:** runs the phases and checks requirements against simulation samples.
- **Test runs** use a copy of the habitat simulation, plus two small additions: scheduled storms and temporary equipment failures.
- **Unlocks** filter the existing build and equipment menus.

## Questions for you

1. **Student names for the report:** should students type their name when they start Missions? Or leave it out and let them add it to the exported report?
2. **The campaign:** are these six steps right? Is anything missing that your CAT needs, such as getting to Mars, radiation or EVA?
3. **Landing ellipse (Mission 1):** decided. Students choose a landing target in Missions and free play. Survival and Missions land somewhere in the ellipse; Freedom and Creative land exactly on target.
4. **Lesson length:** is about one lesson per mission right, or should missions be shorter or longer?
5. **Report format:** is a printable HTML/PDF report good for marking, or do you need something else?
6. **Payload sizes:** are the per-mission payloads (12, 20, 10, 6 and 14 t) about right? I'll check them against the simulation as I build each mission.
