# Outpost One · Chunk 2 beacon forms

These three editable Blender models present the same piece of equipment as it is found at the start of the pad sequence. Each uses metres and a nominal 2.2 m upright height. In the renders the mast leans 12°, one ballast foot has sunk, the lamp is dark and the solar lead is torn at the electronics box.

| Form | Visual emphasis |
| --- | --- |
| A · Survey mast | Telescoping mast with a round protected lens and compact field case. Closest to the prototype already shown beside the finished pad. |
| B · Guarded beacon | Wide hooded light, square mast and orange protection around the electronics box. |
| C · Folding tripod | Twin mast guides, narrow solar panel and crossed leg bracing. |

The Blender source packs its textures. Each variant keeps the mast, three foot joints, camera-facing tilt screen, carry points, tow eye, lead, torn stub, and replaceable connector separately editable. The next pass finalises the selected form's Godot GLB and scene state binding.

To rebuild the Blender options using Pillow, NumPy and SciPy for the maps:

```sh
python source/surface_maps.py /tmp/outpost-beacon-textures
blender -b --python source/build_beacon_forms.py -- --form Guarded --textures /tmp/outpost-beacon-textures
```
