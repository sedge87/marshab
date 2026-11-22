# Outpost One · GAR-Y Field Upgrade

Use `original/GAR_Y_Field_Upgrade.glb` for the textured rover. Its root is `GarY`, its front faces −Z, and the import is in metres. The field finish adds painted-surface wear, dusty tyres, machined hub rings, solar collector traces, and body and arm hardware.

The established wheel, rocker, mast, eye, solar panel, arm and gripper hierarchy is retained. `RearMount`, `FrontMount`, and `MastMount` are included. The previously supplied tow hitch fits beneath `GarY/Body/RearMount` with an identity transform.

The GLB contains the maps. The Blender source keeps the added hardware individually editable, and the game export groups those details by part and material. The rear render shows the previously supplied detachable hitch installed.

## Source

The editable `source/GAR_Y_Field_Upgrade.blend` opens with packed textures. The build script uses the earlier `GAR_Y_with_mounts.glb` as its input.

```sh
python source/surface_maps.py /tmp/outpost-gary-textures
blender -b --python source/build_gar_y_field_upgrade.py -- --input source/reference/GAR_Y_with_mounts.glb --textures /tmp/outpost-gary-textures
```
