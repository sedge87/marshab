# Imported Mars Simulator environment

This project reuses the environment assets supplied in `Mars simulator (2).zip`.

Imported runtime assets:

- `assets/original_mars/models/terrain.glb`
- `assets/original_mars/models/terrain_far.glb`
- `assets/original_mars/models/decor_rock_00.glb` through `decor_rock_07.glb`
- `data/original_mars_decor_placements.json`

The supplied simulator's `docs/CREDITS.md` states that its terrain and boulder
meshes were generated from `scripts/mars_assets/*.py` in Blender 5.2.1 LTS and
are **Project content**. It also states that no third-party art, audio, or font
files were added beyond Godot's built-in Noto Sans font (SIL OFL 1.1). Godot is
MIT licensed; Blender is GPL licensed as development tooling only.

The Habitat project imports only the terrain, distant terrain, boulder assets,
and boulder placement data. It does not include the simulator's rocket,
specimens, missions, inventory, audio, or exploration scripts.
