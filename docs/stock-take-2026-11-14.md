# Stock-take, 14 November 2026

*Taken before a rethink of the main gameplay pillars. Branch `survival-revamp`; everything below is committed locally and nothing is pushed.*

## 1. Built, but not playtested yet

The newest playtest build (`Builds/OutpostOne-Playtest-10Nov-d`) predates the last few of these, so none of them have been played together.

- **Radio:** a call cut off by a save plays again; calls and the far side (the relay behind Mars) no longer trip over each other; stale calls are dropped when you wake; Escape pauses voices (5dbad52, 69cf09b, 3f301da).
- **Keys and small fixes:** M and C open the slate (Base, Comms); cores taken earlier still count; a lost mark says so; Rao, who talked you down, says the touchdown line (f65e153, c4bcb2f).
- **No night lock** in the guided chapters. The hatch opens at night with a caution (8f3bf9e).
- **Finding Walker 1:** Castle marks where its tracks start, and how far away that is (3d8c311).
- **Walker 1's nav fix:** no crash. Step 2 is now one button, "send it your position", instead of picking landmarks (982c688, badd234).
- **Slate and camera:** you can walk with the slate up; a reticle, zoom, no photo limit, and your recent shots; the clock stays on screen after a load (1bef0de, 3183eaa).
- **Readable notices and thoughts:** bigger text, read-time holds, who's talking, most pressing first (e44861c).
- **Traversal phase 1:** Mars gravity, the automatic lope, momentum in the air (3624377, ef70a17, 8279b9f).

## 2. Unfinished: in the middle of something

- **Traversal phases 2–5** (`docs/traversal.md`): ground that costs speed and air, stake trails, small asks from the crew on the way, ropes then Castle's waiver. Each phase waits for a playtest of the one before.
- **Out-of-date tests:**
  - `tests/radio_test.gd` has a stale list of cues and fails 12 checks.
  - `tests/opening_days_test.gd` still tests the old v1 days.
  - The walker and playthrough tests were updated for the nav change but haven't been run.
- **The canon is behind the game:** `docs/master-design.md` still describes the four-day tutorial with story time, Mission Control's cast and Goals-era ideas. The guided chapters (`docs/opening-days.md`) and the radio (`docs/radio.md`) are newer.

## 3. Parked: come back and decide

- **Build anywhere, more than one habitat** (`docs/build-anywhere.md`). Today you can only build near the lander, because the base has a single floor height. Three options are written up and nothing is decided. It touches every pillar.
- **Camera vs journal:** shots are now unlimited, so which photos go in the journal?
- **The slate's clutter:**
  - the Log records everything (the Bed hint repeats);
  - the Comms page has little use;
  - the compass labels pile up;
  - notices overlap.
- **The walk to Walker 1** uses almost all your air. It needs a warning in the story that it's risky, or a way to top up there.
- **The 12 Nov automated playtest** (`docs/playtest-current-build-2026-11-12.md`):
  - the first minute stacks too much text;
  - the 1 km walk to Pallet 2 comes before you've learned to turn back.
- **Smaller:**
  - the long day-4 "deal" line;
  - the lost ascent vehicle and the other walkers (later content);
  - the old Mission Control button on the build screen, and the Communications Station;
  - the day-4 sunset may replay at dawn.

## 4. Where the pillars stand

The spine (8 Nov) is the tagline **design, live, work and survive on Mars**, with the story running alongside. The three feelings underneath it are: first to see it (wonder), Mars will kill you for it (exposure), a foothold (a home you earned).

- **Design (build):**
  - Built: build bars, modules, corridors, the Print Shop (feedstock only) and the site plan.
  - Open: building only works at the lander. Building should become a slate app with Plan and Look views; that isn't built. How do outposts work, and how does water get home (a pipe or an ice camp)?
- **Live:**
  - Built: the lander as your home, slow hunger, tiredness that rewards rest, sleep, the slate, the suit's drink bag and food bar.
  - Open: the hand-over from lander life to life in the module after the guided chapters has barely been played.
- **Work (science and the goals):**
  - Built: samples, the lab, Discoveries, the Journal, cores, GAR-Y, the walkers and the nav fix.
  - Open: what the day-to-day work is once the chapters end, and the materials step (ice, regolith, haematite, salvage recipes), which is designed but not built.
- **Survive:**
  - Built: suit air, cold, the dark, wear and spares, the GAR-Y rescue, blackouts that cost time rather than harm.
  - Open: survival is meant to fade as machines take over each need; whether that happens in play is untested.
- **Explore and travel** (not one of the four verbs, but the main feeling):
  - Built: the known-things map, the compass, the lope and the drivable rover. The region is "Aeolis Reach", with caves.
  - Open: traversal phases 2–5, the region reshaped with more landforms (HiRISE-based), and outposts.
- **Story:**
  - Built: the pathfinder premise, Castle on the radio, the crew in orbit, the relay windows, four guided chapters, the buried heart's first clues.
  - Open: the middle and late game, the trail of clues, the storm's return and the one ending (land the crew safely).

## 5. For the rethink

- Start from what the user came across that changed their thinking.
- Then test each pillar against it: keep, change or cut.
- The settled rules still stand unless the rethink changes them:
  - NASA-plausible and diegetic;
  - one ending (the buried heart, then the crew land);
  - Castle as the one near voice;
  - no text on models.
