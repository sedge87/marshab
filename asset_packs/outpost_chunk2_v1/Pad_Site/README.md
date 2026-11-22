# Chunk 2 · Pad site set

Use four copies of **PadCornerMarker** to identify the intended landing area. The tip is at the origin. Sink the spike by about 0.12 m so the stop plate sits near grade. The amber **Lamp** on each marker can be lit independently. As a reference, copy `PadMarkerVisuals.gd.txt` to a `.gd` file and attach it to the inner **PadCornerMarker** model. The four markers in the overview are a staging example.

- **CrackedSlabA** and **CrackedSlabB** show two fracture profiles.
- **CrackedSlabStep** has independent **Half_A** and **Half_B** nodes. Lower **Half_B** to match the sculpted step. The close-up illustrates an 85 mm drop.
- **PadCrackEdgeStrip** can dress roughly 3 m of the broken edge. Its fractured face is on +X. Rotate it around Y to align with the terrain.

The slabs are about 2.4–2.7 m across and 0.11–0.13 m deep. Their GLBs open with the underside at Y = 0. For a flush set, sink them to align the top surface with the terrain.

The Blender file contains a packed display layout. Generate maps with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy) and build the originals with `blender -b -P source/build_site_kits.py -- Pad_Site --textures "$PWD/source/textures"`. The preview script takes a JPG basename after Blender's `--`.
