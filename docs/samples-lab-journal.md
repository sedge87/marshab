# Samples, the lab, the terminal and the journal (core-loop step 5)

Design, 1 Nov 2026. Builds on `docs/core-loop.md` (rounds 1, 2 and 4) and `docs/start-and-chapter-one.md` (step 4, built). Nothing here is built yet. §12 has the answers to §11's questions, and they win where the text above disagrees.

## 1. What this step is for

Step 4 gave the start a shape: unpack, fabricate, become self-sufficient. Step 5 gives going outside a purpose beyond survival. You bring things back, study them in the lab, and what you learn turns into **discoveries**. Mission Control's teams answer discoveries with plans, improvements and (later) kit and places. The terminal keeps the official record; your journal keeps the story.

The loop in one line: **go out → collect a few samples → carry them home → analyse → discovery → Earth replies → something new to build or do.**

## 2. What exists today, and what changes

| Exists | What happens to it |
|---|---|
| **Research points:** lab equipment adds a passive "research" rate (`habitat_sim.gd`), shown on Mission Control. | Under chapter rules, **analysing samples replaces it.** Lab equipment sets how fast the analysis goes. (Missions mode is being removed, so nothing needs to keep research points.) |
| **GAR-Y's core order:** GAR-Y drills a core, carries it in, and gives research +20 % for 10 sols. | GAR-Y's core becomes a **sample** like yours, analysed in the lab. The boost goes. |
| **GAR-Y's rock collection:** named rocks (Gerald the basalt, Blueberry the hematite…), found on its surveys. | Each rock GAR-Y brings in becomes a sample. The names stay as GAR-Y's labels; they're its charm. |
| **The hand corer** (step 4): cores on surveyed ground, giving depth and purity. | A core can be **kept** as an ice-core sample (in the case) as well as reporting ice. |
| **The food step's regolith bag** (step 4). | That becomes the first regolith sample, with the bench washing it. Same flow, now part of the sample system. |
| **Chapter one's four steps** (ice, water, oxygen, food). | Logged as the first discoveries in the terminal (Geology, Humans, Humans, Life). |
| **Mission Control (M):** cargo, readiness, the habitat plan, the alert log. | Gains a **Discoveries** tab: the terminal (§6). |
| **The comms station** (Work crate). | E on it opens the same terminal. |
| `docs/mars-science-goals.md` (four teams, a 60-sol tour, backing). | Its tour was dropped by the core loop. This step keeps its **sample ideas** and the four sections, and leaves teams, requests and requisition to steps 6 and 8. |

## 3. Samples

**Kinds in step 5** (three; more come with step 6's places and windows):

| Kind | How you take it | Where | What it can show |
|---|---|---|---|
| **Regolith** | Hold E with the scoop: scoop, then bag (~1.5 s) | Any loose ground outside, away from the base | Perchlorate, grain size, iron oxides, water content |
| **Rock** | Aim at a rock, hold E: chip, then bag (~2 s) | Any surface rock you can see (the site's rock props) | Its rock type (basalt, olivine, hematite, gypsum, sulfur, clay…) |
| **Ice core** | The hand corer, as now (hold E) | Only on ground GAR-Y has surveyed (decided 1 Nov) | Purity, depth (deeper is older), trapped gas and dust layers |

- **Each sample is a record:** `{id, kind, site, x, z, sol, depth_m, rock_type, analysed, findings}`. Its place and sol are labelled automatically; that's the "label" step of chip–bag–label.
- **Rocks come from the land.** The site's rock props get a rock type from the site's geology (`sites.json` gains a weighted `rocks` list per site: the plains mostly basalt and dust-coated rock; the riverbed conglomerate, clay and hematite; the crater breccia and olivine). Chipping a rock leaves a small fresh scar on it, and a rock gives one sample.
- **Regolith and rock don't need a survey.** The "no hole without a reason" rule (1 Nov) is about drilling. Scooping and chipping the surface is what every rover does.
- **Assisted mode** (core-loop round 4) can do the hold for you; it doesn't exist yet and isn't part of this step.

## 4. Carrying samples: the sample case

No inventory screen (decided in step 4).

- **The sample case** has **six slots**. It hangs on the suit rack with the corer and the scoop. Walking out through the airlock with the suit on takes them with you automatically: no extra step, but the rack shows them gone.
- **Seeing what's in it:**
  - a small strip of six pips at the bottom of the visor (part of the suit HUD, not a screen), each coloured by kind: regolith tan, rock grey, ice blue;
  - **I** while outside, not looking at anything, gives the short card: "Case: 2 regolith, 1 rock, 1 ice core · 2 free".
- **A full case** means the next sample can't be taken ("The case is full. Head home or leave one."). You can drop a sample (hold I) to free a slot; it's lost.
- **GAR-Y carries its own:** one core and its rocks, as now. The crew rover (when it lands) gets a sample drawer with six more slots.
- **Unloading:** E on the lab's Sample Storage Cabinet (or the Workshop Bench before there's a lab) empties the case into the base's sample store. GAR-Y unloads itself, as it does today.

## 5. The lab

**Analysis is a job, like the fabricator's** (one screen, the same pattern):

- **E on the Science Workbench** opens the lab screen: samples in store on the left, the one you pick on the right, with **Analyse**. It runs on the clock and on power, one job at a time per bench.
- **How long:** regolith 3 h, rock 4 h, ice core 6 h of game time. A Microscope Station in the same room makes rock and regolith 40 % faster. A second workbench runs a second job.
- **What comes out:** each finished analysis gives its **findings** (the rock type, perchlorate yes/no, the core's age band and so on), written on the sample's record. A finding seen for the first time is a **discovery**.
- **Before there's a Science Lab:** samples wait in the store. Analysis is lab-only (Q3): a workshop bench would contaminate a sample, and analysis uses part of it up. The bench keeps its practical jobs, such as washing soil for the food step. The good core that finds ice is a field result, not a lab analysis, so chapter one never waits on the lab.
- **Evidence builds to a discovery** (Q3): the first matching result is a **lead** on the terminal ("Possible perchlorate in the soil"). It's **confirmed** after more matching samples from **different spots** (at least 20 m apart): common finds need 3, uncommon 2, rare 1. Each sample is also partly used up by its analysis.
- **The Sample Storage Cabinet** holds analysed samples (the archive). Its shelves fill visibly, one jar per sample up to its slots: core-loop round 2's "your story on show".

**The discoveries table** (`data/discoveries.json`), about 20 to start, each with its section and what it unlocks:

| Discovery | Section | From | Unlocks (examples) |
|---|---|---|---|
| Water ice in the ground | Geology | a good core | Ice Extractor plan (as now) |
| Ice from an older climate | Climate | a core from deeper than 2.5 m | Dust-storm forecasts a sol ahead |
| Perchlorate in the soil | Life | regolith | Hydroponics +10 % once the soil is washed; suit cleaning matters |
| Basalt, the plains bedrock | Geology | rock | Regolith shielding blocks print 20 % faster |
| Hematite concretions ("blueberries") | Geology + Life | rock | A lead: "water once stood here" (step 6 uses it) |
| Gypsum vein | Geology + Climate | rock | A lead to water history |
| Clay-rich rock | Life | rock | The Life team's first big find: a journal highlight |
| Sulfur crystals | Geology | rock | — (a famous find; journal) |
| Iron meteorite | Geology | rock | — (rare; journal) |
| Washed soil grows plants | Life + Humans | the food step | Food plans (as now) |
| … | | | |

Unlocks in this step are **plans** (through the existing `learn_after`) and **improvements** (small, named multipliers the sim already has hooks for). Kit and places wait for steps 6 and 8, but the table already has a column for them.

## 6. The terminal: Mission Control's record

- **Where:** the Mission Control screen (M) gets a **Discoveries** tab; E on the comms station opens it too. No new screen.
- **Four sections:** Life, Climate, Geology, Humans. Each discovery is a card: what it is, where and on which sol, the sample it came from, and what it unlocked. Undiscovered entries show as an outline ("Something in the rocks?") so there's a sense of what's left, Subnautica-databank style but our own: Mission Control's voice, not a scanner's.
- **Earth replies after the light delay** (the "sent 7 min ago" the radio already uses): a short note from the right team, then the unlock. "The Geology team is very pleased with the hematite. That's water, once. Plan attached: Sample Storage Cabinet, rev 2."
- **A running count per section** replaces the research number on the Mission Control front page.

## 7. The journal

- **Written for you, automatically,** one entry per sol, in the first person and kept short: what happened that sol that mattered (the first walk, a core, a room finished, a discovery, a storm, a close call with the walkback limit later). It's assembled from events the game already raises, from phrase templates with some variety.
- **Sketches:** when something journal-worthy happens outside (a discovery's sample taken, a new place reached), the game takes a quiet snapshot of the view and turns it into a **pencil sketch** (an edge-and-hatching shader over a grey paper texture, rendered once and saved next to the save file at about 480×270). Most sols have none; a good sol has one or two.
- **Reading it:** **J** opens the journal as a two-page book (your entries and sketches), anywhere except mid-EVA ("You can't write in the suit"). It's also a physical notebook on your bunk's shelf: E on it opens the same book.
- **Ending a chapter** adds a full-page sketch and the milestone report's summary (step 11 builds the reports).
- **Saved** with the game (text and sketch PNGs in the save's folder). The Tour mode can show a journal page or two.

## 8. On screen

Nothing new except: the case's six pips at the visor's bottom edge (outside only), the lab screen (the fabricator's layout), the Discoveries tab, and the journal book. Everything else is in the world: the case on the rack, the jars on the cabinet shelves, the notebook on the bunk, chip scars on rocks.

## 9. Modes, saves and what stays

- **Survival and Freedom** (chapter rules): all of this. Freedom analyses twice as fast.
- **Creative:** no samples; the terminal shows nothing to discover.
- **Missions:** being removed (user, 1 Nov), so step 5 doesn't design around it.
- **Older saves** (`older_rules`): as now. A step-4 save picks this up: chapter one's finished steps are logged as discoveries on load, and the journal starts on the sol you load it.

## 10. Build plan

1. **Data:** `data/discoveries.json`, rock lists in `sites.json`, sample record and store in a new `scripts/samples.gd` (static, saved like `MHChapterOne`).
2. **Taking samples:** the scoop and rock-chipping (holds, like the corer), the core kept as a sample, GAR-Y's core and rocks as samples, the case and its pips, I card, drop.
3. **The lab:** the lab screen (from the fabricator screen), jobs, findings, the bench's field test, the cabinet's jars, the microscope speed-up.
4. **The terminal:** the Discoveries tab, the four sections, Earth's delayed replies, the unlocks; chapter one's steps logged.
5. **The journal:** events to entries, the sketch snapshot and shader, the book (J and the bunk notebook), saving.
6. **Models (Blender, house style):** sample case, scoop, sample jars for the cabinet shelves, the notebook. Rock chip scar decal.
7. **Tests:** a step 5 test (take, carry, unload, analyse, discover, unlock, journal entry, save/load, modes); extend the playthrough script.

## 11. Questions to answer before building

1. **Sample kinds:** regolith, rock and ice core now, with frost (dawn) and air/dust filters in step 6? *Recommended.*
2. **Rock chipping:** any surface rock you can see, or only at outcrops that orbit or GAR-Y has marked? *Recommended: any visible rock* (the survey rule is for drilling).
3. **Before the Science Lab:** a slower, partial field test at the Workshop Bench, or nothing until the lab is built? *Recommended: the field test.*
4. **Research points:** replaced by sample analysis under chapter rules, or kept alongside? *Recommended: replaced* (Missions keep them).
5. **Journal sketches:** a pencil-shader snapshot of the moment, hand-made illustrations per discovery, or text only for now? *Recommended: the snapshot.*
6. **Opening the journal:** J anywhere but mid-EVA, plus the notebook on your bunk; or only the notebook? *Recommended: both.*
7. **The terminal:** a Discoveries tab on Mission Control (M) and the comms station, or a separate terminal you have to walk to? *Recommended: the tab.*
8. **Sample case size:** six slots, with dropping to free one? *Recommended.*

## 12. Answers (1 Nov 2026)

1. **Sample kinds:** regolith, rock and ice core now; frost and filters in step 6.
2. **Rocks:** any visible rock.
3. **The lab:** no science on the workshop bench (it would contaminate the sample and could waste it). Analysis is lab-only. A first result is a lead; a discovery is confirmed by matching results from different spots (common 3, uncommon 2, rare 1). Chapter one's ice and food steps are field results, so they don't need the lab.
4. **Research points:** replaced by sample analysis.
5. **Sketches:** a pencil-shader snapshot of the moment.
6. **Journal:** J anywhere except mid-EVA, plus the notebook on your bunk.
7. **Terminal:** a Discoveries tab on Mission Control (M) for now. *Follow-up (user):* clean up the M page later, deciding what it really needs to show and what can move into the world to be more immersive.
8. **Case size:** not asked yet; six slots assumed.

Also noted: **Missions mode will be removed** (it belonged to the old version), so nothing in this step keeps it working.
