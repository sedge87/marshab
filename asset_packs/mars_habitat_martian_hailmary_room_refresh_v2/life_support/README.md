# Life Support | Martian + Hail Mary restyle

**Status: visual/material revision for Godot review; NOT installed into your live game.**

## Equipment

| Catalogue/proposed ID | GLB | Triangles | Mesh groups | Approx dimensions (X/Y/Z metres) |
| --- | --- | ---: | ---: | --- |
| `air_recycler` | `air_recycler_martian_hailmary.glb` | 24,296 | 48 | [1.478, 1.891, 0.897] |
| `water_reclaimer` | `water_reclaimer_martian_hailmary.glb` | 7,952 | 33 | [1.415, 1.875, 1.307] |
| `thermal_control_unit` | `thermal_control_unit_martian_hailmary.glb` | 9,104 | 25 | [1.488, 1.901, 1.213] |
| `oxygen_reserve` | `oxygen_reserve_martian_hailmary.glb` | 11,628 | 37 | [1.449, 1.865, 1.004] |

## Review

1. Open `godot_review/project.godot` in Godot 4 and let the GLBs import.
2. View `room_gallery.tscn` and compare equipment under your own game lighting.
3. Verify scale, +Y vertical, -Z front, placement bounds, collisions and save/load integration.
4. Verify named interactive parts and existing gameplay effects are retained when replacing old greyboxes.
5. Check materials in both daylight and nighttime illumination; emissive geometry is not actual scene lighting.

This restyle changes materials, **not the modelling geometry**. Mechanical quality improvements already built into the previous detailed models are retained, but any remaining geometric issue should be reported and fixed in the original modelling source. No functional gameplay wiring has been added here.

All original source GLBs are in `../source_originals/`. They have not been deleted or modified.
