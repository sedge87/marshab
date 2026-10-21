---
workflow: general-video
flow: automation
storyboard: no
message: "MARS: HABITAT — design a home on Mars, then live in it."
destination: classroom and showcase screening
aspect: "16:9"
language: en
length: 62s
---

## Intent
An atmospheric, cinematic ~60s trailer for MARS: HABITAT (Godot game), cut from
footage captured in-game: cargo lander touchdown, stepping out onto Mars, site
sweeps (plains, ridge canyon, ice fields), the base at night, interiors.
Titles and music. Output MP4. (User, 21–22 Oct 2026.)

## Assets
- Footage: captured with Godot's movie writer by `tools/trailer_capture.gd`
  (11 shots, 1080p30), converted to `assets/*.mp4`.
- Music: `assets/score.wav`, composed by `tools/trailer_score.py` from the
  game's own stems (drone, chord pads, pulse, bells, wind, hum).
- Font: Noto Sans / Noto Sans Mono, the game's UI fonts.

## Notes
Inferred (not asked; the user wanted it quick): 1920×1080, 30 fps, no
narration, letterboxed 2.39:1, quiet build to a title swell.
