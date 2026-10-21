# Hydroponics | Martian + Hail Mary restyle

**Status: visual/material revision for Godot review; NOT installed into your live game.**

## Equipment

| Catalogue/proposed ID | GLB | Triangles | Mesh groups | Approx dimensions (X/Y/Z metres) |
| --- | --- | ---: | ---: | --- |
| `grow_tray` | `grow_tray_martian_hailmary.glb` | 24,736 | 38 | [1.469, 2.066, 0.852] |
| `seedling_station` | `seedling_station_martian_hailmary.glb` | 12,700 | 37 | [1.571, 1.806, 0.877] |
| `nutrient_mixer` | `nutrient_mixer_martian_hailmary.glb` | 26,436 | 38 | [1.519, 1.745, 0.917] |
| `harvest_cart` | `harvest_cart_martian_hailmary.glb` | 19,280 | 62 | [1.416, 1.674, 0.903] |
| `large_planter` | `large_planter_martian_hailmary.glb` | 31,040 | 37 | [2.223, 1.64, 1.23] |

## Review

1. Open `godot_review/project.godot` in Godot 4 and let the GLBs import.
2. View `room_gallery.tscn` and compare equipment under your own game lighting.
3. Verify scale, +Y vertical, -Z front, placement bounds, collisions and save/load integration.
4. Verify named interactive parts and existing gameplay effects are retained when replacing old greyboxes.
5. Check materials in both daylight and nighttime illumination; emissive geometry is not actual scene lighting.

This restyle changes materials, **not the modelling geometry**. Mechanical quality improvements already built into the previous detailed models are retained, but any remaining geometric issue should be reported and fixed in the original modelling source. No functional gameplay wiring has been added here.

All original source GLBs are in `../source_originals/`. They have not been deleted or modified.
