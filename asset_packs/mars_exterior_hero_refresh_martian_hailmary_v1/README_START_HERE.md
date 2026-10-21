# Mars Habitat — Exterior Equipment Refresh, Part 1

Five original exterior equipment models in the brighter practical *The Martian* / *Project Hail Mary* direction, matching the recent interior rebuilds.

| Asset | Role | Suggested interaction |
|---|---|---|
| Exterior Ice/Water Drill | Extract water from subsurface ice | Start/stop extraction, inspect tank |
| Surface Reactor | Major power generation prop | Isolator on/off, status indicator |
| Portable Floodlight | Temporary outdoor EVA worksite illumination | Switch on/off |
| Tall Light Post | Illuminate base paths/work areas | Switch on/off |
| Solar Floodlight | Self-powered small-area lighting | Switch on/off |

**Five placeable GLBs:** each uses 1 unit = 1 metre, +Y up, -Z forward, origin at ground. These should be freely placed on sufficiently flat terrain (with simple grounding/foot clearance), not constrained to interior cell snapping.

## Design and performance
- Original practical research-station styling: bright white/off-white skins, aluminium, restrained teal piping, orange controls.
- Pumps, motors, mast, auger, light yokes, bracing and cooling hardware are physically attached in the geometry.
- No baked text, static readout artwork or screen textures.
- Shared logical node names for future animation and effects.
- Simple PBR material factors (no heavy texture downloads).
- Low-count geometry is intentional; silhouettes, connections and components receive priority.

## Godot
`godot_review/project.godot` is a standalone Godot 4.3+ project with all five models and simple collision boxes. Choose 1–5 and E to demonstrate interaction signals; each of the three light assets toggles a low-cost sample SpotLight3D (shadow disabled).

The example Godot project has not been executed here. Final gameplay, terrain placement, real-time light budgeting, resource effects and save/load need to be tested in the actual game.

## Scope
This is **Exterior Part 1**, prioritising the two major machines and three lighting models. Remaining exterior furnishings (outdoor workbench, cargo/pallet set, communications mast, barriers, path markers) should be revisited in a separate quality pass. Do not overwrite existing exterior files before backing them up.
