# Outpost One · Landing Pad and Beacon

This prototype depicts a landing site at two points in the opening. An uncrewed supply drop surveyed the ground and left its markers and beacon hardware. The player finds bare ground, a leaning mast and damaged wiring. They prepare the surface, fabricate the pad sections from local regolith, install the recovered guides, repair the beacon and commission the site for a landing rehearsal.

The pad is about 18 m across flats. The beacon is about 1.98 m high. The pad size is provisional until it can be checked against the intended crew lander.

## Godot asset

`original/Landing_Pad_And_Beacon.glb` contains embedded PBR textures. The model uses metres and +Z faces the marked approach in Godot.

| Node | Purpose |
| --- | --- |
| `LandingSite` | Ground-level root of the prototype site |
| `LandingPad` | Surfacing, perimeter and guide light housings |
| `LandingPad/Sector_01` to `Sector_08` | Separately addressable pad sections |
| `LandingPad/TouchdownMarkings` | Solid centre dot, segmented landing ring and approach indicators |
| `LandingPad/PadGuideLenses` | Guide light optics |
| `SurveyKit` | Pre-existing survey stakes |
| `BeaconStation` | Tripod, ballast shoes and battery box |
| `BeaconStation/BeaconTilt` | Mast pivot at the collar. Carries antenna, solar panel and beacon optic. |
| `BeaconStation/OperateBeacon` | Ground-level interaction position |
| `BrokenLead`, `BrokenMastTail`, `RepairedLead` | The damaged cable ends and the full repaired lead |

Copy `LandingSitePreview.gd.txt` to a `.gd` file and attach it to `LandingSite` to preview the five phases. `AS_FOUND` shows the stakes and damaged beacon with bare ground. `PAD_BUILT` adds the landing pad. `RESEATED` stands the mast upright and swaps the lead, `POWERED` lights the beacon, and `COMMISSIONED` also lights the pad guides. The script controls visual state. The game supplies construction progression, collision, the repair interaction and the rehearsal event.

In the raw GLB the pad is assembled and the two broken leads ship at a near-zero scale. The preview script restores their normal scale and switches their visibility when the damaged phase is active. The Blender source has both lead options available at normal scale.

## Source

`source/Landing_Pad_And_Beacon.blend` has the editable geometry and packed textures. To regenerate the asset, run the texture script with NumPy, Pillow and SciPy, then pass its output to Blender.

```sh
python source/surface_maps.py /tmp/outpost-landing-site-textures
blender -b --python source/build_landing_site.py -- --textures /tmp/outpost-landing-site-textures
```
