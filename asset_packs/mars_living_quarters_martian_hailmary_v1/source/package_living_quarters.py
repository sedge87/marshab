from pathlib import Path
import shutil,zipfile,json
ROOT=Path(__file__).resolve().parent.parent
review=ROOT/'godot_review'; (review/'models').mkdir(parents=True,exist_ok=True)
assets=json.loads((ROOT/'asset_manifest.json').read_text())
for a in assets: shutil.copy2(ROOT/a['model'],review/'models'/Path(a['model']).name)
(review/'project.godot').write_text('''config_version=5

[application]
config/name="Mars Habitat | Living Quarters Art Review"
run/main_scene="res://living_quarters_review.tscn"
config/features=PackedStringArray("4.2", "GL Compatibility")

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
(review/'camera_look_at.gd').write_text('''extends Camera3D

func _ready() -> void:
    look_at(Vector3(0.0, 1.0, 0.45), Vector3.UP)
''')
external=[]
for i,a in enumerate(assets,1):
 external.append(f'[ext_resource type="PackedScene" path="res://models/{Path(a["model"]).name}" id="{i}"]')
sc=['[gd_scene load_steps=11 format=3]','',*external,'[ext_resource type="Script" path="res://camera_look_at.gd" id="cam"]','',
    '[sub_resource type="BoxMesh" id="FloorMesh"]','size = Vector3(12, 0.08, 7)','',
    '[sub_resource type="StandardMaterial3D" id="FloorMat"]','albedo_color = Color(0.66, 0.70, 0.70, 1)','roughness = 0.88','',
    '[sub_resource type="BoxMesh" id="LampWall"]','size = Vector3(1.65, 2.35, 0.10)','',
    '[sub_resource type="StandardMaterial3D" id="WallMat"]','albedo_color = Color(0.90, 0.93, 0.92, 1)','roughness = 0.78','',
    '[node name="LivingQuartersArtReview" type="Node3D"]','']
# Two rows, large furniture has enough gap not to intersect. Rear row is toward +Z.
positions={'crew_bunk':(-3.4,0,-1.4),'locker':(0,0,-1.4),'common_table':(3.4,0,-1.4),
           'task_light':(-3.4,0,2),'privacy_divider':(0,0,2),'exercise_station':(3.4,0,2)}
for i,a in enumerate(assets,1):
 id=a['id'];px,py,pz=positions[id]
 sc += [f'[node name="{id}" parent="." instance=ExtResource("{i}")]',f'position = Vector3({px}, {py}, {pz})','']
sc += ['[node name="Floor" type="MeshInstance3D" parent="."]','mesh = SubResource("FloorMesh")','material_override = SubResource("FloorMat")','position = Vector3(0, -0.065, 0)','',
       '[node name="TaskLightDemoMount_WALL_NOT_IN_MODEL" type="MeshInstance3D" parent="."]','mesh = SubResource("LampWall")','material_override = SubResource("WallMat")','position = Vector3(-3.4, 1.10, 2.17)','',
       '[node name="Sun" type="DirectionalLight3D" parent="."]','rotation = Vector3(-0.7, -0.3, -0.26)','light_energy = 1.0','',
       '[node name="Fill" type="OmniLight3D" parent="."]','position = Vector3(-2, 4.7, -0.8)','light_energy = 0.75','omni_range = 14.0','',
       '[node name="Camera3D" type="Camera3D" parent="."]','position = Vector3(4.3, 6.5, -14)','current = true','script = ExtResource("cam")','']
(review/'living_quarters_review.tscn').write_text('\n'.join(sc))
# Human-review checklist and Codex handoff
(ROOT/'README.md').write_text('''# Living Quarters — The Martian + Project Hail Mary restyle

This pack replaces the *materials* of the six higher-detail retro-industrial furniture models with light white/off-white composite housings, brushed aluminium structural hardware, and muted teal textiles. The shapes remain the detailed Living Quarters designs previously approved.

## Included equipment
- `crew_bunk` — built-in sleeping berth, drawer fronts, bedding, reading light
- `locker` — twin-door crew storage, hinges, vents and catches
- `common_table` — supported shared table, recessed inactive display surface, cup restraints
- `task_light` — articulated wall-mounted lamp (its bounding box intentionally begins above floor)
- `privacy_divider` — three free-standing panels with hinge and feet
- `exercise_station` — crew resistance trainer with handles, seat and cable gear

Each GLB uses **metres, +Y up**, as the earlier assets do. The six official game catalogue IDs are unchanged. The display surfaces are deliberately blank: game information should be supplied by actual Godot UI, not permanently baked graphics.

## Important repair to the older 3 GLB exports
When inspecting the archived original `crew_bunk`, `locker` and `common_table` GLBs, we discovered that the exporter had produced submeshes which **were present in the file but not referenced by the scene graph**, hiding important geometry (particularly locker doors). The first three were regenerated from the *original modelling source*, fixing duplicate node names by adding a material suffix. The **triangle totals remain identical to the modeller's intended geometry**, but more of the geometry is now actually visible. The repaired geometry sources are stored in `source_originals/`, and the previously distributed exports are stored in `original_glb_exports/` for comparison. The other three assets retain all of their original geometry and node names unchanged.

## Asset packs and delivery
`models/` contains the six final GLBs, while `previews/living_quarters_contact_sheet.jpg` shows all of them. Open `godot_review/project.godot` in Godot 4 and use `living_quarters_review.tscn` to view the assets together. This viewer is separate from your real game. The task light has a temporary wall *only in this review scene*.

`source/restyle_living_quarters.py` regenerates the six bright GLBs from bundled model sources. `source/generate_models_complete.py` is the original procedural modeller with the corrected material/group naming for the first three assets, included for further modelling modifications; this is not an automatic gameplay integration script.

## Integration cautions
- Keep the live `asset_scene` paths, equipment IDs, placement bounds, supported room types, and existing gameplay effects stable until deliberately changed.
- Back up the greybox/model and associated scenes/scripts before replacing anything.
- No false static screen readings, mirrored lettering, or exported permanent crew labels.
- Interactions (drawers, lamp, curtains, workout) are *candidate component groups*; this pack does not wire gameplay systems.
- The original Living Quarters assets are preserved as source files and backups. Exterior infrastructure and internal structural building pieces are excluded.
- Check direct lighting, collisions and wall-mounted lamp orientation in your actual habitat before approving.
''')
(ROOT/'CODEX_INTEGRATION_PROMPT.md').write_text('''# Codex — Integrate brighter Living Quarters models, one room at a time

The six new models are in `models/`. Visually these should match the existing bright Martian/Project Hail Mary Hydroponics and Life Support equipment: white composite panels, aluminium hardware, a little orange and muted blue/teal. They preserve the previous detailed geometries; do not replace them with simplified boxes.

1. Inspect the existing Godot `equipment_catalog.json`, relevant `asset_scene` paths and resource effects. Record the current IDs and their footprints. Do not invent new IDs.
2. Copy the existing greyboxes/models and affected `.tscn`/`.gd` files into a timestamped backup location before replacement; do not delete them.
3. Import these GLBs to `res://assets/equipment/` or the project's chosen asset folder. Keep the current scene paths/IDs stable via wrappers or deliberate path migration.
4. Important: The repaired `crew_bunk`, `locker`, and `common_table` use material-suffixed child mesh names (such as `Locker_Door_L__bone`) because a prior exporter silently dropped multiple meshes sharing the same node name. Retarget old interaction node paths safely. Do not rely on just `Locker_Door_L` still existing as a single mesh node.
5. Use simple collision primitives; preserve save/load and existing placement and zone behaviour. Do not include the demo wall behind the task lamp.
6. If an interaction needs several submeshes to move as a unit, put their shared logical prefix under an appropriate Node3D pivot instead of animating the individual materials independently.
7. The old printed labels and fake fixed screen artwork were removed intentionally. Any screen data must be read live from game state; blank dark glass is acceptable.
8. Check the room in actual Godot lighting and test duplicate placements, walking collisions, scaling, toggling existing equipment effects and persistence. Report any issue before moving to Power & Engineering.

Do not change the game's structural doors, windows or walls. Do not automatically alter electricity, food, hygiene or morale mechanics merely because these revised models contain interaction-ready parts.
''')
(ROOT/'REVIEW_CHECKLIST.md').write_text('''# Living Quarters visual and gameplay acceptance checklist

- [ ] All six show light composite housings and coherent aluminium trims under the actual habitat lights.
- [ ] Bunk drawers, curtains, mattress and reading lamp remain attached and visible.
- [ ] Both locker doors have vent grilles, handles, layered panels and hinges (fixed exporter omission).
- [ ] Common table retains its structural braces, storage and cup restraints.
- [ ] Task light is wall-mounted and illuminates the intended reading area.
- [ ] Divider panels remain individually distinct with proper feet/hinges.
- [ ] Exercise station has connected resistance and cable parts, not suspended floating grips.
- [ ] No mirrored or backward baked labels, and no frozen numbers on displays.
- [ ] Old catalogue IDs and valid room/footprint metadata still match.
- [ ] Collision shapes, object placement, interactions and save/reload work in the live project.
- [ ] Performance is acceptable with multiple items placed in one room.
''')
zip_path=ROOT.parent/'Mars_Living_Quarters_Martian_HailMary_Complete_6_Assets.zip'
# Raw retro exports generated as an intermediate by the included modeller are not part of the final models dir.
for a in assets:
 p=ROOT/'models'/f"{a['id']}_retro.glb"
 if p.is_file():p.unlink()
with zipfile.ZipFile(zip_path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=8) as z:
 for path in ROOT.rglob('*'):
  if path.is_file() and not any(s in path.parts for s in ('__pycache__','.git')):
   z.write(path,arcname=f'{ROOT.name}/{path.relative_to(ROOT)}')
with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
print('PACKAGED',zip_path,zip_path.stat().st_size,'bytes')
