# Chunk 2 · Collapse pit lip

Four individually exportable pieces of broken crust, sized from about 0.3 to 1 m. Each rubble GLB is centred at the volume centroid so it can rotate naturally as it falls. Place at the appropriate resting height and add the game-side collision and trigger.

**PitLipUndercut** provides a layered overhang. Its forward edge faces −Z and the back embeds into the bank along +Z. Set its origin at the intended rim height and blend the back into the terrain. The deep ground and cliff you see in the preview are staging to show where the overhang sits.

The Blender file contains a packed inspection layout. Generate maps with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy) and build the originals with `blender -b -P source/build_site_kits.py -- Pit_Lip --textures "$PWD/source/textures"`. The preview script takes a JPG basename after Blender's `--`.
