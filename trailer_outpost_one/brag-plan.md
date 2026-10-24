# OUTPOST ONE: MARS — reveal trailer plan and storyboard

Made with /brag (brag-slim, on Opus 5.5). The run was stretched to 60 seconds at
the user's request, and the tone is cinematic.

## The game, in one sentence

A grounded Mars survival builder: you design a habitat on a site plan, furnish
it room by room, keep air, water, food and power running, and live through
storms and radiation on four real-world sites.

## Rubric

- **What it is:** a survival and habitat-building simulation on Mars, built in Godot.
- **Who it's for:** players who like Subnautica-style base building, The Martian
  and Project Hail Mary, who want the problem-solving to feel real.
- **What sets it apart:** everything in it is interconnected and real:
  - a cargo budget;
  - real Mars weather on four NASA-based sites (canyon morning cloud, ice-field
    frost and fog, dust devils, dust storms);
  - an architectural site plan;
  - furnishing in first person;
  - power, ice, food and research loops.
- **Most impressive claim:** you build it, then you live in it. Every room you
  draw on the plan is a room you can walk into and furnish.
- **Visual hook:** a silent, misty Martian canyon at dawn. Then a lander falls
  out of the sky.
- **Real UI shown:**
  - the Site plan (drawing Life Support and Power & Engineering onto the floor plan);
  - the interior builder (placing a crew bunk and the Retro Mars Poster);
  - the ice extractor over the subsurface ice survey.
- **Tone:** cinematic and restrained. Isolation turns into warmth, then ingenuity, then hope.
- **Share caption:** see `share-copy.txt`.

## Angle

Mars is enormous and silent and doesn't care. Then people arrive with
everything they need packed into a lander, and they make a home. The tagline
**Design. Live. Work. Survive.** appears one word at a time in Act 3 over the
gameplay that matches each word, and then returns complete under the title.

## Visual identity

- **Footage:** captured in-engine with Godot's movie writer at 1920×1080, 30 fps,
  using a separate camera director (`capture/director.gd`). It flies slow
  Catmull-Rom camera moves, eased only at the ends.
- **Grade:** light. A touch of contrast and warmth, a soft vignette and fine
  grain. The gameplay UI shots are left ungraded.
- **Type:** the game's own fonts, set small and widely spaced.
  - Noto Sans Light for lines and the title.
  - Noto Sans Mono for the tagline tags.
  - The game's Safety Orange (#ED7C35) as the only accent.
- **No** lens flares, glitch effects, HUD frames or big animated text.

## Music: 80 BPM, D minor (a bar is 3.0 s; every cut is on a beat)

`score/score.py` synthesises strings, a felt piano, sub bass, low hits and a
ticking clock at 48 kHz. It weaves in the game's own sounds: wind, drone, hum,
the glass bell, the landing burn, the airlock door, the placement click,
GAR-Y's chirp and the storm.

- **Act 1:** drone, wind and sparse bells.
- **Act 2:** warm chords and the four-note piano motif.
- **Act 3:** the clock ticks every beat, then every half-beat, with hits on the downbeats.
- **Act 4:** a riser, the big hit on bar 16 (48 s), the piano answer, the title hit on bar 18 (54 s), then it settles.

**Music cue guidance:** chords change on every bar from bar 5. The hits are on
bars 10–16. The title lands on bar 18.

## Storyboard (60.0 s)

| # | Time (s) | Shot | What we see | Type | Sound |
|---|---|---|---|---|---|
| **ACT 1 — THE FRONTIER** | | | | | |
| 1 | 0.00–5.25 | canyon_dawn | Canyon Ridge at dawn; morning cloud lies in the canyon; a slow drift. Fades up from black. | "225 MILLION KILOMETRES FROM HOME" (1.6–4.6) | Wind, drone, first bell |
| 2 | 5.25–9.00 | ice_fog | Ice Fields: frost and low fog at dawn, the glacier wall in haze. | — | Bell |
| 3 | 9.00–15.00 | touchdown | A cargo lander falls on its burn against the mesa; dust kicks up. | "EVERYTHING WE NEED, WE BRING WITH US" (10.5–14.2) | Landing burn |
| **ACT 2 — THE OUTPOST** | | | | | |
| 4 | 15.00–18.75 | reveal | Golden hour: past the crew lander to the habitat, solar field, a dust devil far behind. | — | Chords enter, piano motif |
| 5 | 18.75–21.00 | hull_glide | Along the south hull: windows, the roof rail, GAR-Y parked by the mast. | — | GAR-Y chirp |
| 6 | 21.00–24.00 | airlock_in | The outer airlock door opens; we step into the airlock. | — | Door (22.1) |
| 7 | 24.00–27.00 | galley | The galley at evening: kitchenette, table, warm light. | — | Habitat hum |
| 8 | 27.00–30.00 | hydro | Hydroponics: grow racks under the lamps. | — | Motif again |
| **ACT 3 — BUILDING A FUTURE** | | | | | |
| 9 | 30.00–33.00 | siteplan | Site plan (real UI): Life Support and Power & Engineering dragged onto the floor plan. | 01 DESIGN | Ticks begin, placement clicks |
| 10 | 33.00–36.00 | furnish | First person, interior builder: a crew bunk placed, then the poster. | 02 LIVE | Clicks |
| 11 | 36.00–37.50 | science | Science Lab workbench by the window. | 03 WORK | Ticks |
| 12 | 37.50–39.75 | power | Ice extractor over the subsurface ice survey (29% ice); placed. | (WORK) | Click |
| 13 | 39.75–42.00 | solar_field | Low past the solar field to the habitat. | (WORK) | Half-beat ticks |
| 14 | 42.00–48.00 | storm | The dust storm front rolls in behind the base. | 04 SURVIVE | Storm wind, building hits, riser |
| **ACT 4 — OUTPOST ONE** | | | | | |
| 15 | 48.00–60.00 | finale | Dusk, lights on: a slow crane from the ground up over the whole outpost. | Title 54.0–60.0: OUTPOST ONE / MARS / DESIGN. LIVE. WORK. SURVIVE. | Big hit (48), piano answer, title hit (54), settle |

Every feature shown exists in the current build: the sites and weather, the
cargo lander, airlock doors, rooms and equipment, the Site plan and interior
builder, the ice survey and extractor, the solar arrays, dust storms and GAR-Y.
The base was built for the trailer by the capture tool from the game's own
building rules. Nothing in the game was changed.

## Files

- `capture/director.gd`: the shot director (builds the base, hides the HUD, flies the camera, drives the real UI for the gameplay shots).
- `capture/capture_all.sh`: records the takes; `capture/scout.sh` makes scouting stills.
- `score/score.py`: the score.
- `edit/edit.py`: the cut, grade, type and master.
- `outpost-one-mars-trailer.mp4`, `poster.jpg` and `share-copy.txt`: the deliverables.
- `work/`: takes, stills, titles and the score render. Not committed.
