# Mars Habitat — Science Laboratory: Water, Ice and Surface History

**Asset status:** modelled, previewed and exported; not yet reviewed in the live Mars Habitat game.
**Style:** bright and practical white-composite scientific machinery inspired by *The Martian* and *Project Hail Mary*. All assets are original designs. No baked words, backwards labels or static fabricated data screens.

## Why these three models?

The classroom learning loop is *collect a sample → examine its visible evidence → archive it → use the evidence in a mission*. Students should form an intuitive sense that layering, rock textures and possible ice deposits tell scientists about changes in Mars's environment. This is an approachable game interaction, not a science exam or detailed laboratory simulator.

| GLB / proposed game equipment ID | Visual purpose | Simple planned interaction |
|---|---|---|
| `science_workbench.glb` / `science_workbench` | Layered sediment core, supported core clamp, sealed ice-testing chamber, pump, examination light | Open hatch, inspect a layered core, test a sample |
| `microscope_station.glb` / `microscope_station` | Proper microscope, focused specimen tray, mineral slice holder, light, physical knobs | Adjust focus and illuminate a sample |
| `sample_storage_cabinet.glb` / `sample_storage_cabinet` | Cold specimen bay with true clear viewing window, rock-core drawers, status lamps | Open cabinet and retrieve or archive a sample |

Model units: **metres**. Godot axes: **+Y up and -Z forward**, floor-centred. Each model has a footprint under 1.5 m x 1.5 m. Animated-looking parts use individual GLB nodes grouped by action. The rest is combined by material to limit draw calls. **Baked screen data:** none.

## Technical snapshot

- Core and Ice Workbench: 13,984 triangles, 29 mesh groups, 1.49 x 0.95 m footprint, 1.68 m overall height.
- Microscope Station: 11,704 triangles, 25 mesh groups, 1.30 x 0.78 m footprint, 1.81 m overall height.
- Sample Archive: consult `sample_storage_cabinet_manifest.json` for final technical counts after the visibility revision; 1.47 x 0.84 m footprint, 1.94 m overall height.

## How to review

Open `godot_review/project.godot` in Godot 4 and run `science_lab_review.tscn`. Right-drag to orbit; scroll to zoom. Demonstration keys:

- `1`: move ice-chamber hatch on the workbench
- `2`: toggle microscope illumination light
- `3`: swing open cold-storage door
- `4`: slide out the archive's middle drawer

The demo scenes deliberately do not claim to implement research, physics, sample inventory, water generation or live educational feedback. The model files do not contain working gameplay logic.

## Production restrictions

Preserve all original versions of greybox scenes, equipment catalogue entries and resource scripts. **Do not update walls, floors, doors or windows.** Do not add fake telemetry screens; use real game-state indicators in contextual interface panels when needed.

An alternative `sample_analysis_station` exists in the original larger equipment catalogue but isn't part of the three-asset simplified room plan; its role is incorporated into `science_workbench`. Avoid assigning a duplicate new resource effect without approval.

## Files

- `models/` — finished GLB exports
- `previews/` — actual renders of exported GLBs
- `godot_review/` — standalone demo and simple collision shells
- `source/build_science.py` — editable generator; requires Python, NumPy and trimesh
- `source/render_models.py` — preview generator; requires Python, vtk and Pillow
- `*_manifest.json` — verified export metadata
- `CODEX_INTEGRATION_PROMPT.md` — game integration handoff
- `REVIEW_CHECKLIST.md` — acceptance checks
