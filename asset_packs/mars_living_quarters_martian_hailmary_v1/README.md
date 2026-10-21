# Living Quarters — The Martian + Project Hail Mary restyle

This pack replaces the *materials* of the six higher-detail retro-industrial furniture models with light white/off-white composite housings, brushed aluminium structural hardware, and muted teal textiles. The shapes remain the detailed Living Quarters designs previously approved.

## Included equipment
- `crew_bunk` — built-in sleeping berth, drawer fronts, bedding, reading light
- `locker` — twin-door crew storage, hinges, vents and catches
- `common_table` — supported shared table, recessed inactive display surface, cup restraints
- `task_light` — articulated wall-mounted lamp (its bounding box intentionally begins above floor)
- `privacy_divider` — three free-standing panels with hinge and feet
- `exercise_station` — crew resistance trainer with handles, seat and cable gear

Each GLB uses **metres, +Y up**, as the earlier assets do. The six official game catalogue IDs are unchanged. The display surfaces are deliberately blank: game information should be supplied by actual Godot UI, not permanently baked graphics.

## Important repair to the older 3 GLB exports
When inspecting the archived original `crew_bunk`, `locker` and `common_table` GLBs, we discovered that the exporter had produced submeshes which **were present in the file but not referenced by the scene graph**, hiding important geometry (particularly locker doors). The first three were regenerated from the *original modelling source*, fixing duplicate node names by adding a material suffix. The **triangle totals remain identical to the modeller's intended geometry**, but more of the geometry is now actually visible. The repaired geometry sources are stored in `source_originals/`, and the previously distributed exports are stored in `original_glb_exports/` for comparison. The other three assets retain all of their original geometry and node names unchanged.

## Asset packs and delivery
`models/` contains the six final GLBs, while `previews/living_quarters_contact_sheet.jpg` shows all of them. Open `godot_review/project.godot` in Godot 4 and use `living_quarters_review.tscn` to view the assets together. This viewer is separate from your real game. The task light has a temporary wall *only in this review scene*.

`source/restyle_living_quarters.py` regenerates the six bright GLBs from bundled model sources. `source/generate_models_complete.py` is the original procedural modeller with the corrected material/group naming for the first three assets, included for further modelling modifications; this is not an automatic gameplay integration script.

## Integration cautions
- Keep the live `asset_scene` paths, equipment IDs, placement bounds, supported room types, and existing gameplay effects stable until deliberately changed.
- Back up the greybox/model and associated scenes/scripts before replacing anything.
- No false static screen readings, mirrored lettering, or exported permanent crew labels.
- Interactions (drawers, lamp, curtains, workout) are *candidate component groups*; this pack does not wire gameplay systems.
- The original Living Quarters assets are preserved as source files and backups. Exterior infrastructure and internal structural building pieces are excluded.
- Check direct lighting, collisions and wall-mounted lamp orientation in your actual habitat before approving.
