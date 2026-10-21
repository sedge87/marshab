# Production sequence — the minimum safe path

## Stage 0: audit/snapshot — no art changes
Run audit on live repository and verify existing greyboxes, resource hooks and save/load behaviour; snapshot actual affected files. Catalogue item IDs and `asset_scene` paths are authoritative.

## Stage 1: visual kit (first)
Create grounded material system and **partition_solid_3m**, **interior_sliding_door**, **interior_window**. Integrate ONLY if these parts are currently supported by placement; otherwise put model assets in library and keep unavailable in student UI. Do not modify the exterior pressure hull, airlock mechanism or path connectivity rules. Avoid showing fake pressure-safe windows.

## Stage 2: five tangible furniture/equipment items
1. `crew_bunk`: single safe, compact bunk, locker, reading light.
2. `grow_tray`: industrial cultivation rack, reservoir, hydroponic hose, white LED strips, crops, status indicator.
3. `air_recycler`: filter cabinet, labelled duct ports, grill and service hatch.
4. `science_workbench`: stainless bench, sample tray, monitor, cabinet and task lighting.
5. `cargo_rack`: cargo tie-down webbing, crates and structural mounting bars.

For each item produce: Blender editable source, GLB, Godot wrapper/visual states as required, replacement test, screenshot. Ensure the existing item ID remains unchanged.

## Stage 3: expand catalogue by zone
Use `equipment_inventory_from_project.csv`; iterate through remaining catalogue entries. Prioritise power engineering, life support, hydroponics, accommodation, laboratory, storage, corridors, airlocks and vehicle bay. Do not invent extra effects; special behaviour needs its own validated game implementation. Distinctive silhouettes are higher priority than microscopic detail.

## Stage 4: structural environment polish
Retexture and revise interior architectural meshes **only after** compatibility checks. Existing `assets/habitat_modules/*.glb` and `assets/showcase_modules/*.glb` may be referenced by collider/snap/connectors. Treat them as protected until exact dependency audit. Back up meshes and scenes beforehand.

## Completion of each unit
- No grey box visible in runtime for replaced item; graceful fallback when asset missing.
- Player can place/rotate/remove/reload; collision and preview work; usable door/aisle clearances.
- Resource effect is identical before/after visual change unless an explicit, tested functional enhancement is requested.
- Off/fault/power indicators are consistent with actual simulation, not merely cosmetic.
- Manual screenshot and test results saved and named.
