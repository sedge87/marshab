# Outpost One · Walker 1 Remake

`original/Walker_1_Remake.glb` imports with the habitat panels stacked in travel configuration. It uses metres, a ground origin and −Z forward. The model is built from the six-wheel cargo walker reference. The original rig was unavailable for a drop-in compatibility test, so existing gameplay scripts need to reference the new hierarchy.

## Gameplay nodes

| Node | Purpose |
| --- | --- |
| `Walker1/Body/frame_rover_white` | Load-bearing chassis mesh |
| `Walker1/Body/PowerSocket` | Docking marker on the front-left cassette receiver. Local −Z faces out. Align the Power Module's `SocketFace` at the same position with opposing outward axes. |
| `Wheel_1/SealRing` | Separate front-left hub seal for frost, dust and patch effects. `Wheel_1` is beneath `Body/Leg_1/UpperLeg_1/LowerLeg_1/AxleCarrier_1`. |
| `Walker1/Body/DeckScreen` | Separate 16:9 UV surface by the ladder |
| `Walker1/Body/Lamp/lamp_glow_lamp_amber` | Amber mast beacon lens |
| `Walker1/Body/HabitatModule` | Linked floor, rising roof, wall panels, lift posts and entry hatch |

## Asset control

Copy `Walker1Visuals.gd.txt` to a Godot script and attach it to the `Walker1` node. Use `set_deployment(0.0 … 1.0)` with the game's fold timeline. The chassis settles 0.42 m, the roof lifts and the stacked panels stand upright. Wheel centres stay level and tyre spin can be applied to each `Wheel_*` beneath the non-spinning carrier. `set_entry_open()` controls the hatch when the habitat is deployed.

Call `mount_power_module()` with the actual Power Module scene root after the game completes its docking interaction. This matches both socket frames and parents the case to the chassis. The existing Power Module asset shown in the renders remains a separate game scene. Use `set_deck_display()` with a 16:9 texture, such as a game SubViewport. `set_beacon_on()` controls the mast lens. The game provides the travel movement, collisions, inventory, leak and patch effects, and the pressure and liner gameplay.

## Source

The editable Blender scene contains individually named hardware and packed maps. The GLB batches related details by articulated part and material. For a rebuild with Blender:

```sh
python source/surface_maps.py /tmp/outpost-walker-textures
blender -b --python source/build_walker.py -- --textures /tmp/outpost-walker-textures
```

For renders that show the docked case, pass the existing Power Module GLB path in `OUTPOST_WALKER_POWER_GLB`.
