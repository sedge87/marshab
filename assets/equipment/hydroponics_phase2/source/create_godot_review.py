"""Standalone Godot 4 review scenes for the five Hydroponics Phase 2 GLBs.
Standalone by design: NEVER touches the actual Mars habitat repository.
"""
import os, json, shutil
R=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
M=json.load(open(os.path.join(R,'asset_manifest.json')))['assets']
GD=os.path.join(R,'godot_review')
os.makedirs(os.path.join(GD,'models'),exist_ok=True)
os.makedirs(os.path.join(GD,'prefabs'),exist_ok=True)
for a in M:
    shutil.copy2(os.path.join(R,'models',a['id']+'.glb'),os.path.join(GD,'models',a['id']+'.glb'))
open(os.path.join(GD,'project.godot'),'w').write('''config_version=5

[application]
config/name="Mars Habitat - Hydroponics Phase 2 Review"
run/main_scene="res://gallery.tscn"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"

[display]
window/size/viewport_width=1440
window/size/viewport_height=900
''')

for a in M:
    name=a['id'];lo,hi=a['bounds_m'];dx,dy,dz=a['dimensions_m']
    if a['placement']=='floor':
        center=[(lo[i]+hi[i])/2 for i in range(3)]
        size=[max(.12,dx-.045),max(.10,dy-.045),max(.12,dz-.045)]
    else:
        center=[0.,0.,(lo[2]+hi[2])/2]
        size=[max(.12,dx-.02),max(.1,dy-.02),max(.08,dz-.03)]
    parts=['[gd_scene load_steps=3 format=3]','',f'[ext_resource type="PackedScene" path="res://models/{name}.glb" id="1_model"]','',
           '[sub_resource type="BoxShape3D" id="BoxShape3D_1"]',
           f'size = Vector3({size[0]:.4f}, {size[1]:.4f}, {size[2]:.4f})','',
           f'[node name="{name}" type="Node3D" groups=["hydroponics", "habitat_equipment"]]','',
           '[node name="Visual" parent="." instance=ExtResource("1_model")]','',
           '[node name="StaticCollision" type="StaticBody3D" parent="."]','',
           '[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticCollision"]',
           f'position = Vector3({center[0]:.4f}, {center[1]:.4f}, {center[2]:.4f})',
           'shape = SubResource("BoxShape3D_1")']
    if name in ['grow_tray','seedling_station']:
        if name=='grow_tray':
            positions=[(-.25,.74,-.1),(.25,1.3,-.1),(0,1.87,-.1)]
        else:positions=[(0,1.4,-.05)]
        for i,p in enumerate(positions):
            parts+=['',f'[node name="GrowLED_Demo_{i+1}" type="OmniLight3D" parent="."]',
            f'position = Vector3({p[0]}, {p[1]}, {p[2]})',
            'light_color = Color(1.0, 0.94, 0.82, 1.0)',
            'light_energy = 0.25','omni_range = 0.8','shadow_enabled = false']
    open(os.path.join(GD,'prefabs',name+'.tscn'),'w').write('\n'.join(parts)+'\n')

open(os.path.join(GD,'gallery.tscn'),'w').write('''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://gallery.gd" id="1_gallery"]

[node name="HydroponicsReview" type="Node3D"]
script = ExtResource("1_gallery")
''')
open(os.path.join(GD,'gallery.gd'),'w').write('''extends Node3D

# Independent room-equipment gallery; contains no replacement of actual game systems.
# WASD move, Q/E down/up, Shift sprint, mouse look, Escape releases mouse.
var camera: Camera3D
var move_speed := 3.2

func _ready() -> void:
    _build_review_space()
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true
    camera.position = Vector3(-0.2, 1.9, 7.2)
    camera.rotation_degrees = Vector3(-7, 0, 0)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera.rotation.y -= event.relative.x * 0.0025
        camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.0025, -1.4, 1.4)

func _process(delta: float) -> void:
    var h := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var v := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
    var up := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
    var dir := camera.global_basis.x * h - camera.global_basis.z * v + Vector3.UP * up
    if dir.length() > 0.0:
        camera.global_position += dir.normalized() * move_speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0) * delta

func _build_review_space() -> void:
    var world := WorldEnvironment.new()
    add_child(world)
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color(0.16, 0.20, 0.22)
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color = Color(0.86, 0.91, 0.91)
    world.environment.ambient_light_energy = 0.6

    var sun := DirectionalLight3D.new()
    add_child(sun)
    sun.rotation_degrees = Vector3(-48, -30, 0)
    sun.light_energy = 1.1
    var fill := DirectionalLight3D.new()
    add_child(fill)
    fill.rotation_degrees = Vector3(18, 110, 0)
    fill.light_energy = 0.45

    # Neutral review floor ONLY; not a structural asset for the habitat.
    var floor := MeshInstance3D.new()
    add_child(floor)
    var plane := PlaneMesh.new()
    plane.size = Vector2(17.0, 8.0)
    floor.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.31, 0.36, 0.37)
    mat.roughness = 0.88
    floor.material_override = mat

    var models := [
        ["grow_tray", -5.1, 0.0],
        ["seedling_station", -2.65, 0.0],
        ["nutrient_mixer", -0.1, 0.0],
        ["harvest_cart", 2.2, 0.0],
        ["hydroponics_sensor_panel", 4.65, 1.55]
    ]
    for entry in models:
        var resource_path := "res://prefabs/%s.tscn" % entry[0]
        var packed := load(resource_path) as PackedScene
        if packed == null:
            push_warning("Missing or not imported: " + resource_path)
            continue
        var instance := packed.instantiate() as Node3D
        add_child(instance)
        instance.position = Vector3(entry[1], entry[2], 0)
''')
open(os.path.join(GD,'README.md'),'w').write('''# Hydroponics equipment gallery — Godot 4

Open `project.godot` in Godot 4.3+ and run the project. This standalone gallery **does not contain any of your actual habitat game files** and **never modifies the game**.

**Controls:** mouse look, WASD move, Q/E move vertically, Shift speed up, Esc free cursor.

* Five GLBs are in `models/`.
* Five standalone collision-proxy prefabs are in `prefabs/`.
* Grow-rack and seedling light prefabs contain very low-energy demonstration lights only.
* Hydroponics sensor panel uses wall-mount origin at (0,0,0); the gallery shows it in space for easy inspection. Wall construction/placement is not part of this package.
* Inspect correct colour/scale/transparency/flicker before integrating into real game. All five UI displays contain **sample readings**, not connected simulation state.
* Proxy collisions are not approved game collision or placement metadata. Actual footprints must come from the existing catalogue.
''')
print('REVIEW PROJECT DONE')
