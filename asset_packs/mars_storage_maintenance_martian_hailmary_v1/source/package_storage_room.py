from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, shutil, zipfile
import trimesh
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'previews';OUT.mkdir(exist_ok=True)
BASE=Image.new('RGB',(1530,1480),(236,241,241))
draw=ImageDraw.Draw(BASE)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
font2='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
ft=ImageFont.truetype(font,37); fs=ImageFont.truetype(font2,22)
draw.text((36,20),'STORAGE & MAINTENANCE  |  MARTIAN / HAIL MARY',font=ft,fill=(44,70,80))
draw.text((38,76),'Actual GLB exports  •  no baked text or static readouts  •  geometry intended for simple repair and resupply interactions',font=fs,fill=(73,91,96))
for row,(fname,title) in enumerate([('tool_bench','Maintenance Tool Bench'),('cargo_rack','Secured Cargo Rack')]):
    y=118+row*665
    draw.rounded_rectangle((22,y,1508,y+645),radius=24,fill=(26,43,49))
    draw.text((50,y+16),title,font=ImageFont.truetype(font,32),fill=(232,240,237))
    for col,ang in enumerate(['main','front','right']):
        p=OUT/f'{fname}_{ang}.png'
        im=Image.open(p).convert('RGB')
        im.thumbnail((468,557))
        x=37+col*498
        yy=y+59
        BASE.paste(im,(x+(468-im.width)//2,yy))
        draw.text((x+175,y+596),ang.upper(),font=fs,fill=(205,219,225))
BASE.save(OUT/'storage_maintenance_contact_sheet.jpg',quality=91)

REVIEW=ROOT/'godot_review'
MODELS=REVIEW/'models';MODELS.mkdir(parents=True,exist_ok=True)
for f in (ROOT/'models').glob('*.glb'):shutil.copy2(f,MODELS/f.name)
(REVIEW/'project.godot').write_text('''config_version=5

[application]
config/name="Mars Habitat - Storage & Maintenance Review"
run/main_scene="res://storage_maintenance_review.tscn"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
(REVIEW/'orbit_review_camera.gd').write_text('''extends Camera3D
@export var target: Vector3 = Vector3(0, 1.0, 0)
var azimuth := 0.12
var elevation := 0.29
var distance := 5.9
func _ready() -> void:
    _set_orbit()
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        azimuth -= event.relative.x * 0.009
        elevation = clampf(elevation + event.relative.y * 0.009, -1.0, 1.15)
        _set_orbit()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = maxf(2.8, distance-0.35)
            _set_orbit()
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = minf(11.0, distance+0.35)
            _set_orbit()
func _set_orbit() -> void:
    global_position = target + Vector3(sin(azimuth)*cos(elevation),sin(elevation),-cos(azimuth)*cos(elevation))*distance
    look_at(target,Vector3.UP)
''')
(REVIEW/'review_interactions.gd').write_text('''extends Node3D
# OPTIONAL PREVIEW ANIMATIONS. These are NOT wired to any resource or inventory system.
# Number keys demonstrate possible future interactions after imported GLB nodes are available.
@onready var bench: Node3D = $MaintenanceToolBench
@onready var rack: Node3D = $CargoRack
var open_states := {}
func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo: return
    match event.keycode:
        KEY_1: _toggle_rotation(bench, "Tool_Cupboard_Left", Vector3.UP, -1.0)
        KEY_2: _toggle_rotation(bench, "Tool_Cupboard_Right", Vector3.UP, 1.0)
        KEY_3: _toggle_shift(bench, "Spares_Tray", Vector3(0.0,0.0,-0.20))
        KEY_4: _toggle_rotation(rack, "Cargo_Retainer_Bar", Vector3.UP, -0.9)
func _find_part(parent_node: Node, prefix: String) -> Node3D:
    var node: Node = parent_node.find_child(prefix + "*", true, false)
    if node is Node3D: return node as Node3D
    return null
func _toggle_rotation(model: Node3D, prefix: String, axis: Vector3, angle: float) -> void:
    var part := _find_part(model,prefix)
    if part == null:
        push_warning("Missing part: " + prefix)
        return
    var id: String = str(model.get_instance_id()) + prefix
    var active: bool = open_states.get(id,false)
    open_states[id]=not active
    var goal: Vector3 = Vector3.ZERO if active else axis*angle
    create_tween().tween_property(part, "rotation", goal,0.35)
func _toggle_shift(model: Node3D, prefix: String, offset: Vector3) -> void:
    var part := _find_part(model,prefix)
    if part == null: return
    var id: String = str(model.get_instance_id()) + prefix
    if not open_states.has(id): part.set_meta("closed_position",part.position)
    var active: bool = open_states.get(id,false)
    open_states[id]=not active
    var rest_position: Vector3 = part.get_meta("closed_position")
    create_tween().tween_property(part,"position",rest_position if active else rest_position+offset,.35)
''')
scene='''[gd_scene load_steps=10 format=3]

[ext_resource type="PackedScene" path="res://models/tool_bench.glb" id="1"]
[ext_resource type="PackedScene" path="res://models/cargo_rack.glb" id="2"]
[ext_resource type="Script" path="res://orbit_review_camera.gd" id="3"]
[ext_resource type="Script" path="res://review_interactions.gd" id="4"]
[sub_resource type="Environment" id="Env"]
background_mode = 1
background_color = Color(0.60,0.70,0.72,1)
ambient_light_source = 2
ambient_light_color = Color(0.91,0.96,0.98,1)
ambient_light_energy = 0.75
[sub_resource type="StandardMaterial3D" id="FloorMaterial"]
albedo_color = Color(0.51,0.59,0.61,1)
roughness = 0.95
[sub_resource type="BoxMesh" id="FloorMesh"]
size = Vector3(6.5,0.10,4.6)
material = SubResource("FloorMaterial")
[sub_resource type="BoxShape3D" id="BenchCollision"]
size = Vector3(1.48, 2.07, 0.89)
[sub_resource type="BoxShape3D" id="RackCollision"]
size = Vector3(1.46, 2.10, 0.96)

[node name="StorageMaintenanceReview" type="Node3D"]
script = ExtResource("4")
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")
[node name="Floor" type="MeshInstance3D" parent="."]
mesh = SubResource("FloorMesh")
position = Vector3(0,-0.055,0)
[node name="MaintenanceToolBench" parent="." instance=ExtResource("1")]
position = Vector3(-1.03,0,0)
[node name="BenchBody" type="StaticBody3D" parent="."]
position = Vector3(-1.03,1.035,0)
[node name="CollisionShape3D" type="CollisionShape3D" parent="BenchBody"]
shape = SubResource("BenchCollision")
[node name="CargoRack" parent="." instance=ExtResource("2")]
position = Vector3(1.03,0,0)
[node name="RackBody" type="StaticBody3D" parent="."]
position = Vector3(1.03,1.05,0)
[node name="CollisionShape3D" type="CollisionShape3D" parent="RackBody"]
shape = SubResource("RackCollision")
[node name="Key" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-52,-30,0)
light_energy = 1.16
shadow_enabled = true
[node name="Fill" type="OmniLight3D" parent="."]
position = Vector3(1.0,3.3,-2.2)
light_energy = 0.5
omni_range = 6.5
shadow_enabled = false
[node name="ReviewCamera" type="Camera3D" parent="."]
current = true
script = ExtResource("3")
'''
(REVIEW/'storage_maintenance_review.tscn').write_text(scene)

(ROOT/'README_START_HERE.md').write_text('''# Mars Habitat — Storage & Maintenance (The Martian / Project Hail Mary aesthetic)

Two new, original Godot-ready GLB models:

- `models/tool_bench.glb` — detailed repair workbench, mounted tools, clamping vise, cupboard doors, spares tray and overhead task light.
- `models/cargo_rack.glb` — three-tier, secured logistics shelf with separate supply cases and locking retainer.

Both models use metres, +Y up, -Z front and floor-centre origins. Each is less than 1.5 m wide; final placement clearance must be tested in your actual project.

## Files

- `models/`: individual textured PBR GLBs
- `previews/`: renders of the exported GLBs, not concept art
- `source/`: self-contained geometry generation and preview scripts (Python 3 with numpy, trimesh, Pillow, VTK for previews)
- `godot_review/`: standalone Godot 4 scene with simple collisions, orbit camera and optional demo interactions
- `asset_manifest.json` and individual manifests: names, dimensions, triangles, material counts and intended interaction nodes
- `CODEX_INTEGRATION_PROMPT.md`: integration handoff

## Review controls

Open `godot_review/project.godot` in Godot 4, run the project, right-drag to orbit and scroll to zoom. Keys **1** and **2** toggle workshop cupboard doors, **3** slides the spares tray, and **4** releases the cargo retainer. These are animation demonstrations, not inventory or repair systems.

## Limitations

Static geometry is batched by PBR material. Logical interaction parts are separate scene nodes. In-game interaction, asset inventory, save/load, zone placement rules and resource impacts still require integration and testing.
No structural wall/window assets, no baked labels and no fake data screens. Existing models have not been modified.
''')
(ROOT/'CODEX_INTEGRATION_PROMPT.md').write_text('''# Codex handoff — Storage & Maintenance

Import ONLY the two updated equipment GLBs (`tool_bench.glb`, `cargo_rack.glb`) into the existing Godot Mars Habitat project.

1. Before editing, back up all existing `tool_bench` and `cargo_rack` model/scenes/scripts to a versioned backup directory. Do not delete or overwrite the backups.
2. Preserve the existing `tool_bench` and `cargo_rack` equipment catalogue IDs, save-game compatibility, zones, footprint definitions, and established effects. Inspect real `data/equipment_catalog.json` and project scripts first; do not invent paths or APIs.
3. Replace only the equipment visual scene subtree and adapt collisions/placement to the new GLB bounds. Models use +Y up, -Z forward and 1 unit = 1 metre.
4. Use **simple collision boxes**, but avoid preventing access to workbench interaction surfaces. Confirm room clearance and no player entrapment.
5. Keep interaction components separately identifiable (see manifests). Implement one brief, sensible interaction per item: workbench = take a spare/activate repair animation; cargo rack = retrieve a crate/release a retention bar. Show real inventory or mission feedback through the existing contextual UI; no fake persistent numeric displays.
6. Do not assume manual wiring or plumbing is needed. Use the current shared habitat simulation; connect workshop spare-parts/repair capabilities only if matching systems already exist, otherwise expose safe extension points without inventing gameplay.
7. Include a simple import + placement + collision + save/reload + interaction smoke test. Assess material appearance under actual in-game lighting, and compare to approved brighter Martian/Hail Mary rooms.
8. Do not change habitat structural walls, exterior equipment, room zones, other assets, or resource rates unless expressly requested.

Standalone reviewer is in `godot_review/` and includes demonstration cupboard/tray/retainer animations, which should not be treated as integrated gameplay.
''')
(ROOT/'REVIEW_CHECKLIST.md').write_text('''# Storage & Maintenance QA checklist

- [x] GLBs exported and reopened using trimesh.
- [x] Previewed front, angled and side views of actual exported models.
- [x] Model includes supported, fitted hardware and mechanically attached controls.
- [x] Identifiable interaction mesh groups; no baked lettering or fake screens.
- [x] Fits approximately 1.5 m width; Y up and floor-centre origin.
- [x] Upper cargo cases checked for clearance under rack canopy and adjusted.
- [ ] Test imported materials and collision in actual Godot Mars habitat.
- [ ] Verify fixed placement cell vs required service clearance.
- [ ] Connect to existing resource/inventory/repair logic and test save/reload.
- [ ] Profile draw calls and performance with multiple racks in a real room.
''')

# Full independent post-export validation including opened scene transform nodes.
for a in ('tool_bench','cargo_rack'):
    src=ROOT/'models'/f'{a}.glb'
    sc=trimesh.load(src,force='scene')
    assert len(sc.graph.nodes_geometry)>15,(a,len(sc.graph.nodes_geometry))
    for geom in sc.geometry.values():
        assert geom.faces.shape[1]==3
        assert geom.visual.kind=='texture'
        assert geom.visual.material is not None
    info=json.loads((ROOT/f'{a}_manifest.json').read_text())
    assert info['triangle_count']==sum(len(g.faces) for g in sc.geometry.values())
    assert sc.bounds[0,1]>-0.01

# archive in package folder and one output at top-level
out_zip=Path('/mnt/data/Mars_Storage_Maintenance_Martian_HailMary_Complete_2_Assets.zip')
with zipfile.ZipFile(out_zip,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in sorted(ROOT.rglob('*')):
        if p.is_file() and '.godot' not in p.parts:
            archive.write(p,arcname='Mars_Storage_Maintenance_Martian_HailMary_v1/'+str(p.relative_to(ROOT)))
with zipfile.ZipFile(out_zip) as archive:
    fail=archive.testzip()
    assert fail is None,fail
print('CREATED',out_zip,'bytes',out_zip.stat().st_size)
print('CONTENTS',len(zipfile.ZipFile(out_zip).namelist()))
