# Codex integration — Mars Habitat exterior supporting props (Part 2)

Integrate **only** these eight exterior equipment GLBs from this pack. Do not change the habitat shell, terrain, door/window or interior grid systems. Do not overwrite existing exterior props without first making timestamped backups of the GLBs/scenes/scripts/catalogue entries.

1. Import the `.glb` files into the appropriate exterior asset directory, ideally alongside the prior exterior Part 1 pack. Preserve current naming/IDs where a similar catalogue asset exists; map the new filenames explicitly rather than silently renaming catalog entries.
2. Add each asset as its own placeable prop (world = metres, +Y up, local -Z forward). Use **free terrain placement**, optional 15-degree rotation snapping, terrain-normal alignment only on suitably gentle slopes, and footprint/collision checks. Avoid indoor 1.5 m grid snapping.
3. Proposed categories: comms mast (operations), workbench (maintenance), cargo pallet and crates (supply/decor), barrier and bollard (safety), path beacon (navigation/light). Existing resource effects remain unchanged; add new effects only as approved.
4. Proposed simple interactions: mast inspect/antenna status; bench prepare repairs; crate inspect/store supplies; pallet inspect cargo; barrier/bollard inspect; beacon on/off. These should reuse the existing shared interaction framework. Don't invent elaborate minigames, wiring, networks, or new UI systems.
5. Allow lightweight beacon lighting without shadows, distance culling and limited simultaneous dynamic lights. Repeated outdoor props should reuse GLB resources instead of duplicating geometry.
6. Keep the exterior solar and floodlight / reactor / ice drill models in the earlier Part 1 package. They are NOT replaced by these files.
7. Inspect every asset in-engine for visual quality, terrain contact, collision, scale, camera clipping and frame-rate on student hardware. Verify placed assets survive save/load and can be removed.

The `godot_review` folder is only a standalone visual / signal demonstration, not an implementation of the game's simulation. The included collision boxes are starting approximations.
