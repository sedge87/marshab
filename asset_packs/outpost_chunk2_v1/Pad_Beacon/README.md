# Chunk 2 · Pad beacon

Use `original/Pad_Beacon_Guarded.glb` for the portable landing-aid mast. It is about 2.2 m tall and 1.4 m across the tripod. The asset ground origin sits under the tripod centre. The front of the socket, light and blank tilt display faces −Z.

| Node | Use |
| --- | --- |
| `Mast` | Tilts about the tripod crown. The as-found example leans 12°. |
| `Foot_1`–`Foot_3` | Pivot at the tripod leg joints. Foot 1 starts sunk in the as-found example. |
| `LeverPoint_1`–`LeverPoint_3` | The placement points for working each ballast foot. |
| `HitchPoint` | Clip the existing GAR-Y winch line here. The anchor follows the mast. |
| `Lead`, `Connector`, `Socket` | Intact lead and removable plug. The connector pivot and socket empty share a mating point. |
| `LeadLoose`, `LeadTorn` | The hanging lead and small frayed piece left in the open socket. |
| `Lamp`, `TiltScreen` | Amber lens and separate 16:9 blank display with full UVs. |
| `CarryPoints` | Group containing the two handles and `CarryPoint_1`, `CarryPoint_2`. |
| `GuyAnchor_L`, `GuyAnchor_R`, `PanelUpgradeMount` | Empty mounting points reserved for the future commissioned configuration. |

The raw GLB opens upright and torn. The intact **Lead** and **Connector** are parked at reduced scale in the raw import. Restore their unit scale and switch visibility when connecting the lead. `PadBeaconVisuals.gd.txt` handles this and can be attached as a `.gd` script to the inner **LandingBeacon** model. It provides **as found**, **reseated** and **running** examples. The game controls timing, GAR-Y's cable, display content and how the player moves the feet.

The packed Blender file opens in the as-found pose. Rebuild with `python source/surface_maps.py source/textures` (NumPy, Pillow, SciPy), then `blender -b -P source/build_pad_beacon.py -- --textures "$PWD/source/textures"`. To re-render, open the Blender file in background mode and run `source/render_part_b.py` with a preview basename after `--`.
