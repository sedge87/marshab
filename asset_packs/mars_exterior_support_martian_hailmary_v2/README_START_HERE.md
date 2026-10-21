# Mars Habitat — Exterior Equipment, Part 2

Eight independent, original GLB models covering six requested outdoor asset types, with two cargo sizes and two safety markers.

Style: brighter *The Martian* / *Project Hail Mary* inspired white composites, light grey aluminium, practical teal utility and orange hazard accents.

## Contents

| Model | Intended use | Placement |
|---|---|---|
| exterior_comms_mast.glb | Rover / mission comms and survey antenna | Free ground; large tripod |
| exterior_workbench.glb | EVA repair preparation and tools | Free ground; preferably level |
| exterior_cargo_pallet.glb | Loaded supply delivery pallet | Free ground |
| exterior_cargo_crate_large.glb | Larger loose supplies | Free ground |
| exterior_cargo_crate_small.glb | Small loose supplies | Free ground |
| exterior_safety_barrier.glb | Temporary hazardous work area barrier | Free ground, rotate freely |
| exterior_hazard_bollard.glb | Hazard route marker | Free ground |
| exterior_path_beacon.glb | Low-power route illumination | Free ground |

Each model uses metres, Y up and -Z forward with its origin at the ground. Models are individual, so students can place and rotate them independently. No permanent alignment to indoor structural cells is intended.

## Basic Godot review

Open `godot_review/project.godot` in Godot 4.3+ and run the project. Use **1–8** to select an asset and **E** for an example interaction signal. The beacon and bollard examples toggle small low-power lights, not real mission/gameplay effects. The collision wrappers are approximate and may need refining in your full game.

## Performance

All eight assets are much lighter than the large interior machines. Several assets such as route beacons will appear repeatedly, so shared materials, minimal dynamic lights, no shadows for marker lights, and instancing are recommended. Actual draw-call and frame-rate behaviour must be tested in your game.

## Limitations

These are physical models, not working rover communications, repair, inventory, hazards or navigation mechanics. No running-Godot validation was possible during export. No static textual readouts have been baked into model textures. The prior Part 1 machine and light models are deliberately unchanged.

## QA performed

Export to GLB, reload mesh hierarchy/materials, render two angles per model, visually correct cargo crate shells and pallet strap heights, verify archive integrity. Integration, collision navigation, lighting and terrain placement still require in-game review.
