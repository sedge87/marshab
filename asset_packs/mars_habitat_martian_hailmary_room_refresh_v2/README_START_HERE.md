# Mars Habitat — Bright Science Habitat Restyle (Two Rooms)

This revision applies the user-approved visual direction: **The Martian** and **Project Hail Mary** (practical, bright, welcoming spacecraft equipment). It supersedes the darker retro-industrial material versions for visual review, not for live game replacement.

- **Hydroponics:** 5 GLBs in `hydroponics/models/`, with `hydroponics/room_contact_sheet.jpg`.
- **Life Support:** 4 GLBs in `life_support/models/`, with `life_support/room_contact_sheet.jpg`.
- **Backups:** all nine input GLBs in `source_originals/`.
- **Editable restyling method:** `recolor_and_validate.py` (requires Python, trimesh, numpy; uses local `source_originals/` copies). Geometry is not regenerated; this is a PBR material conversion on the existing models.
- **Render instructions:** `render_room_previews.py` optionally uses VTK and PIL for previews.
- **Model metadata:** `asset_manifest.json`.
- **Review viewers:** `hydroponics/godot_review/` and `life_support/godot_review/` are standalone Godot 4 projects. Open `project.godot`, then `room_gallery.tscn`.

## Visual rules
White and near-white housing panels; aluminium frames; graphite mechanical recesses; limited safety orange and blue/green utility pipework; real switches and valves; no static fake data screens. **Do not add baked text.**

## Scope and caution
- The `grow_tray` and `air_recycler` GLBs come directly from the previously approved Martian/Hail Mary A/B prototypes.
- The other seven are **material-only** restyles of the previously detailed high-geometry versions; original triangles, node names and bounds are preserved exactly.
- This doesn't implement interactive Godot scripts, physics, dynamic labels, gameplay logic or resource connections. Those remain integration tasks.
- Keep catalogue IDs, valid zones, resource effects, footprints and placed-instance persistence compatible. `large_planter` is an optional/proposed item and should not be registered automatically.
- The former Glass Greenhouse zone remains **removed**; its large planter is under Hydroponics.
- Interior structural walls, doors, windows, and exterior equipment are outside this pack.

## Recommended in-game review order
1. Hydroponics: grow rack beside seedling station and mixer; check the white/grey palette with crops in the same lighting.
2. Life Support: air recycler beside reclaimer, thermal control and oxygen reserve; inspect piping and access clearances.
3. Test functional and performance behaviour before replacing original scenes.
