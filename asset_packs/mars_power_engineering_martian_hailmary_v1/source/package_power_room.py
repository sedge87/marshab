from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json, shutil, zipfile, hashlib
import trimesh

ROOT=Path(__file__).resolve().parent.parent
GD=ROOT/'godot_review';GD.mkdir(exist_ok=True)
(GD/'models').mkdir(exist_ok=True)
M=ROOT/'models'
assets=[('Power Distribution Cabinet','power_distribution_cabinet_martian_hailmary.glb','cabinet'),('Battery Bank','battery_bank_martian_hailmary.glb','battery')]
for _,name,_ in assets:shutil.copy2(M/name,GD/'models'/name)

# Review image combines three-angle renders for each actual exported GLB.
font='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
body='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
img=Image.new('RGB',(1490,1100),(238,244,243));d=ImageDraw.Draw(img)
d.text((44,28),'MARS HABITAT  /  POWER & ENGINEERING',font=ImageFont.truetype(font,38),fill=(37,63,76))
d.text((44,82),'THE MARTIAN + PROJECT HAIL MARY   |   ORIGINAL MODELS   |   NO BAKED READOUTS',font=ImageFont.truetype(body,20),fill=(82,112,118))
for j,(label,name,prefix) in enumerate(assets):
 y=129+j*471
 for i,view in enumerate(['main','front','right']):
  im=Image.open(ROOT/'previews'/(prefix+'_'+view+'.png')).convert('RGB')
  im.thumbnail((461,377))
  x=30+i*490+(461-im.width)//2
  img.paste(im,(x,y+(377-im.height)//2))
  d.text((45+i*490,y+389),view.upper(),font=ImageFont.truetype(font,16),fill=(112,126,131))
 d.text((45,y+415),label.upper(),font=ImageFont.truetype(font,24),fill=(27,62,74))
img.save(ROOT/'previews'/'power_engineering_contact_sheet.jpg',quality=94)

(GD/'project.godot').write_text('''config_version=5

[application]
config/name="Mars Habitat - Power Engineering Asset Review"
run/main_scene="res://power_engineering_review.tscn"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
(GD/'orbit_review_camera.gd').write_text('''extends Camera3D
# Standalone preview camera: right-drag to orbit, mouse wheel to zoom.
@export var target := Vector3(0.0, 1.08, 0.0)
var azimuth := -0.48
var elevation := 0.24
var distance := 6.8
func _ready() -> void:
    _position_camera()
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        azimuth -= event.relative.x * 0.009
        elevation = clampf(elevation + event.relative.y * 0.009, -1.15, 1.25)
        _position_camera()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = maxf(3.1, distance - 0.45)
            _position_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = minf(13.0, distance + 0.45)
            _position_camera()
func _position_camera() -> void:
    global_position = target + Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation)) * distance
    look_at(target, Vector3.UP)
''')
(GD/'power_engineering_review.tscn').write_text('''[gd_scene load_steps=10 format=3]

[ext_resource type="PackedScene" path="res://models/power_distribution_cabinet_martian_hailmary.glb" id="1"]
[ext_resource type="PackedScene" path="res://models/battery_bank_martian_hailmary.glb" id="2"]
[ext_resource type="Script" path="res://orbit_review_camera.gd" id="3"]
[sub_resource type="Environment" id="Environment_review"]
background_mode = 1
background_color = Color(0.63, 0.72, 0.74, 1)
ambient_light_source = 2
ambient_light_color = Color(0.93, 0.96, 0.98, 1)
ambient_light_energy = 0.55
reflected_light_source = 1
[sub_resource type="StandardMaterial3D" id="FloorMat"]
albedo_color = Color(0.51, 0.58, 0.61, 1)
roughness = 0.91
[sub_resource type="BoxMesh" id="FloorMesh"]
size = Vector3(6.5, 0.1, 4.6)
material = SubResource("FloorMat")
[sub_resource type="BoxShape3D" id="FloorCollision"]
size = Vector3(6.5, 0.1, 4.6)
[sub_resource type="BoxShape3D" id="CabinetCollision"]
size = Vector3(1.44, 2.04, 0.83)
[sub_resource type="BoxShape3D" id="BatteryCollision"]
size = Vector3(1.45, 2.08, 0.88)

[node name="PowerEngineeringReview" type="Node3D"]
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_review")
[node name="Floor" type="MeshInstance3D" parent="."]
mesh = SubResource("FloorMesh")
position = Vector3(0, -0.055, 0)
[node name="FloorBody" type="StaticBody3D" parent="."]
[node name="FloorCollision" type="CollisionShape3D" parent="FloorBody"]
position = Vector3(0, -0.055, 0)
shape = SubResource("FloorCollision")
[node name="DistributionCabinet" parent="." instance=ExtResource("1")]
position = Vector3(-1.13, 0, 0)
[node name="DistributionCabinet_BasicCollision" type="StaticBody3D" parent="."]
position = Vector3(-1.13, 1.02, 0)
[node name="CollisionShape3D" type="CollisionShape3D" parent="DistributionCabinet_BasicCollision"]
shape = SubResource("CabinetCollision")
[node name="BatteryBank" parent="." instance=ExtResource("2")]
position = Vector3(1.13, 0, 0)
[node name="BatteryBank_BasicCollision" type="StaticBody3D" parent="."]
position = Vector3(1.13, 1.04, 0)
[node name="CollisionShape3D" type="CollisionShape3D" parent="BatteryBank_BasicCollision"]
shape = SubResource("BatteryCollision")
[node name="KeyLight" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-48, -38, 0)
light_energy = 1.18
shadow_enabled = true
[node name="FillLight" type="OmniLight3D" parent="."]
position = Vector3(1.5, 3.7, -3)
light_energy = 0.65
omni_range = 8.0
[node name="ReviewCamera" type="Camera3D" parent="."]
current = true
script = ExtResource("3")
''')
manifest=[]
for label,name,prefix in assets:
 s=trimesh.load(M/name,force='scene')
 groups=list(s.graph.nodes_geometry)
 scene_meshes=[]
 for node in groups:
  matx,k=s.graph[node]
  scene_meshes.append(s.geometry[k])
 if not scene_meshes:raise RuntimeError('empty scene')
 m={
  'name':label,'asset_id':'power_distribution_panel' if prefix=='cabinet' else 'battery_bank',
  'file':f'models/{name}',
  'triangles':sum(len(z.faces) for z in scene_meshes),
  'mesh_groups':len(groups),
  'materials':sorted({z.visual.material.name for z in scene_meshes}),
  'bounds_min_m':s.bounds[0].round(4).tolist(),
  'bounds_max_m':s.bounds[1].round(4).tolist(),
  'interaction_groups':sorted({n.split('__')[0] for n in groups if n.startswith(('BreakerBank_','Main_Isolator_','Emergency_Stop_','Battery_Cassette_','Battery_ChargeIndicator_','Battery_Main_Disconnect','Inspection_Door'))}),
  'baked_text_or_static_fake_displays':False,'gameplay_wired':False}
 manifest.append(m)
(ROOT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))

(ROOT/'README_START_HERE.md').write_text('''# Mars Habitat — Power & Engineering (The Martian + Project Hail Mary)

This is a **high-detail, room-specific asset review pack**, not a modification of your game. It replaces the old low-detail power distribution cabinet with recessed physical switchgear and adds a coherent modular battery bank.

## Asset files

- `models/power_distribution_cabinet_martian_hailmary.glb` (`power_distribution_panel` catalogue ID)
- `models/battery_bank_martian_hailmary.glb` (`battery_bank` catalogue ID)
- `previews/power_engineering_contact_sheet.jpg` and individual actual-model views
- `godot_review/` is a standalone Godot 4 project (open `project.godot` and run)
- `source/` contains the editable procedural geometry and preview generators
- `asset_manifest.json` includes geometry statistics, dimensions and sample interaction hooks

## Visual direction

Original practical Mars hardware with **white and warm-white composite cladding, light aluminium framing, graphite interior service bays, restrained orange controls, non-digital gauge faces and live-light-capable indicator strips**. No baked text, numbers or fake permanent readouts. Every component is supported by plausible rails or chassis.

## Godot / placement

Each GLB is metric, +Y up, -Z facing front; model origin at floor-centre. Widths are under 1.5 m. Height is about 2.05 m. Depth is 0.83–0.88 m. Preserve catalogue IDs, effects and scene paths already in your game. The review project contains simple example collisions, *not final integrated collision rules*.

## Suggested behaviour for Year 9 students

- Distribution cabinet: turn the orange main isolator to enable/disable electricity to room equipment; inspect a breaker if a machine stops receiving power. The large breaker panel is physically detailed but **do not simulate 15 independent electrical circuits** unless later desired.
- Battery bank: stores power supplied by generation sources and supports the habitat during low supply. Let players inspect a charge indicator or pull the one named service cartridge. No technical electrical quiz or manual cable network.
- All info should use live Godot context overlays or physical indicator colours, never fake numbers printed into the GLB.

## Asset scope

**Equipment only.** No structural partitions, windows, doors, grid changes or hull operations. These designs intentionally replace the very plain former cabinet; keep old placeholders as backups.

## Validation

Both files exported and reopened successfully as glTF scenes. Three-angle renders use the exported GLBs, not separate concept geometry. The source checks bounds and records mesh groups. **The actual models, scene, materials, performance, and interactions have not been tested inside the live habitat game yet.**
''')
(ROOT/'CODEX_INTEGRATION_PROMPT.md').write_text('''Integrate the two Power & Engineering equipment assets from this pack into my Year 9 Mars Habitat Godot project, **one room at a time**. Before replacing anything, preserve a named backup of the current `power_distribution_panel` and `battery_bank` GLBs/scenes/scripts and their placement configuration. Do not touch structural wall/door/window components or alter the rest of the habitat.

Use the GLBs from `models/`. Keep the existing catalogue IDs and asset_scene paths where possible and preserve any existing power generation, battery capacity, resource effects, save/load, place/remove, valid zones, collision and footprint contracts. The GLBs are +Y-up, -Z forward, metres and should occupy their existing 1.5 m equipment cells. Audit the footprint in-game before updating bounds.

Test the distribution cabinet alone first, then the battery bank. Build simple collisions using boxes/capsules (not complex trimesh collision). Confirm placement, removal, camera movement, reload, shadows, material appearance and performance. Do not introduce a detailed power-grid-cabling simulation.

The cabinet has named `Main_Isolator_Rotary`, `Emergency_Stop_Plunger`, breaker handle (`BreakerBank_...`), and `Inspection_Door` mesh nodes. The battery bank has one movable `Battery_Cassette_R1_L` set of nodes, six `Battery_ChargeIndicator_...` bars, and `Battery_Main_Disconnect`; other cartridges were intentionally batched into static geometry for performance. Godot can animate parts grouped by their shared node-name prefix. None of those animations is yet linked to gameplay.

Make interactions simple: inspect cabinet, toggle main power, inspect battery state; represent status with actual game data and emissive indicator materials or short contextual UI. Never bake text/telemetry into materials. Keep shaders and real-time lights minimal. Profile a normal populated room before trying to cut geometry further. Do not delete older models or alter other room packages.
''')
(ROOT/'REVIEW_CHECKLIST.md').write_text('''# Acceptance checks — Power & Engineering

- [ ] Open GLBs in Godot 4 at native scale, see full breakers and six battery cartridge fronts
- [ ] Confirm both fit allowed equipment cells and do not clip the ceiling or other machinery
- [ ] Confirm +Y-up, -Z forward, origin floor centre, and physically supported details
- [ ] Walk around each model from front and sides, check for floating or hidden parts
- [ ] Inspect materials under the habitat's direct sunlight/artificial light
- [ ] No backwards text, static fake telemetry or broken UV decals
- [ ] Basic collisions block player where needed without snagging navigation
- [ ] Existing `power_distribution_panel` and `battery_bank` gameplay effects remain functional
- [ ] Simple interactions return real game values, not placeholders
- [ ] Save, reload, rotate and remove each placed asset
- [ ] Profile frame time with multiple examples placed and room lights on
- [ ] User approval before replacing other equipment or committing the new aesthetic globally
''')

# Validate models & archives, package identical standalone folder+zip.
print('OUTPUT METRICS')
for record in manifest:
 print(record['asset_id'],record['triangles'],'triangles;',record['mesh_groups'],'meshes;',len(record['materials']),'materials;',[(round(record['bounds_max_m'][i]-record['bounds_min_m'][i],3)) for i in range(3)])
zip_path=ROOT.parent/'Mars_Power_Engineering_Martian_HailMary_Complete_2_Assets.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in ROOT.rglob('*'):
  if f.is_file() and f.suffix not in ('.pyc',):
   z.write(f,arcname='Mars_Power_Engineering_Martian_HailMary_v1/'+str(f.relative_to(ROOT)))
with zipfile.ZipFile(zip_path) as z:
 for f in z.infolist():
  if z.testzip() is not None:raise RuntimeError('zip CRC invalid')
print('PACKAGED',zip_path,zip_path.stat().st_size)
