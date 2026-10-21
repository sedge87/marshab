"""Blender (5.x) build script: Oxygen Generator for MARS: HABITAT.

Run:  blender --background --python build_oxygen_generator.py -- <out_dir>
Writes <out_dir>/models/oxygen_generator.glb and previews/*.png.

Metres, floor origin, front faces -Z in glTF (Blender +Y here). Mesh names are
component_material (e.g. service_door_white_painted) so the game's
interaction rig can find moving parts. Style and palette follow the Indoor
Heaters / Life Support packs.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(os.path.join(OUT, "models"), exist_ok=True)
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)

COLORS = {
    "white_ceramic": ((0.88, 0.91, 0.90, 1), .05, .65),
    "white_painted": ((0.94, 0.95, 0.92, 1), .03, .57),
    "warm_panel": ((0.78, 0.82, 0.80, 1), .06, .62),
    "slate_panel": ((0.36, 0.43, 0.46, 1), .12, .55),
    "alloy": ((0.59, 0.67, 0.69, 1), .76, .38),
    "satin_steel": ((0.77, 0.81, 0.79, 1), .83, .27),
    "dark_alloy": ((0.28, 0.35, 0.38, 1), .66, .5),
    "black_rubber": ((0.10, 0.14, 0.16, 1), .03, .83),
    "teal": ((0.22, 0.47, 0.51, 1), .17, .45),
    "teal_soft": ((0.42, 0.63, 0.64, 1), .06, .69),
    "cool_blue": ((0.38, 0.62, 0.76, 1), .13, .48),
    "orange": ((0.84, 0.42, 0.18, 1), .20, .51),
    "bright_green": ((0.35, 0.76, 0.48, 1), .03, .43),
}

# ---------- scene ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = {}
for name, (rgba, metal, rough) in COLORS.items():
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = rgba          # viewport / Workbench preview colour
    m.metallic = metal
    m.roughness = rough
    MATS[name] = m

PARTS = []

def _finish(obj, name, mat, bevel=0.0):
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(MATS[mat])
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = False
    PARTS.append(obj)
    return obj

def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    obj = bpy.context.active_object
    obj.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat, bevel)

def cyl(name, centre, radius, length, mat, axis="z", verts=24, bevel=0.0):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=length, location=centre, rotation=rot)
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat, bevel)

def join(name, objs):
    """Merge several parts that move or read as one component."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        PARTS.remove(o)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        for mod in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    PARTS.append(obj)
    return obj

FRONT = 0.33   # front plane of the cabinet (Blender +Y = the game's front)
T = 0.03       # panel thickness

# ---------- base ----------
box("plinth_dark_alloy", -0.6, 0.6, -0.38, 0.36, 0.04, 0.14, "dark_alloy", 0.01)
feet = [box("feet_part", x - 0.05, x + 0.05, y - 0.05, y + 0.05, 0.0, 0.04, "black_rubber", 0.006) for x in (-0.52, 0.52) for y in (-0.3, 0.28)]
join("feet_black_rubber", feet)

# ---------- main cabinet (hollow, so the open door shows the stack) ----------
x0, x1, y0, z0, z1 = -0.58, 0.12, -0.38, 0.14, 1.72
shell = [
    box("s", x0, x1, y0, y0 + T, z0, z1, "slate_panel"),
    box("s", x0, x0 + T, y0, FRONT, z0, z1, "slate_panel"),
    box("s", x1 - T, x1, y0, FRONT, z0, z1, "slate_panel"),
    box("s", x0, x1, y0, FRONT, z0, z0 + T, "slate_panel"),
    box("s", x0, x1, y0, FRONT, z1 - T, z1, "slate_panel"),
]
join("cabinet_shell_slate_panel", shell)
box("cabinet_lining_dark_alloy", x0 + T, x1 - T, y0 + T, y0 + T + 0.01, z0 + T, z1 - T, "dark_alloy", 0)
# Door frame trim (static).
trim = [
    box("t", x0, x0 + 0.04, FRONT - 0.005, FRONT + 0.012, z0, z1, "dark_alloy", 0.003),
    box("t", x1 - 0.04, x1, FRONT - 0.005, FRONT + 0.012, z0, z1, "dark_alloy", 0.003),
    box("t", x0, x1, FRONT - 0.005, FRONT + 0.012, z1 - 0.04, z1, "dark_alloy", 0.003),
    box("t", x0, x1, FRONT - 0.005, FRONT + 0.012, z0, z0 + 0.04, "dark_alloy", 0.003),
]
join("door_frame_dark_alloy", trim)

# ---------- electrolysis stack inside the cabinet ----------
plates_teal, plates_steel = [], []
sx0, sx1, sy0, sy1 = -0.42, -0.06, -0.22, 0.14
z = 0.52
for i in range(14):
    (plates_teal if i % 2 == 0 else plates_steel).append(box("p", sx0, sx1, sy0, sy1, z, z + 0.035, "teal" if i % 2 == 0 else "satin_steel", 0.003))
    z += 0.045
join("electrolysis_stack_teal", plates_teal)
join("electrolysis_stack_satin_steel", plates_steel)
ends = [box("e", sx0 - 0.02, sx1 + 0.02, sy0 - 0.02, sy1 + 0.02, 0.46, 0.52, "dark_alloy", 0.005),
        box("e", sx0 - 0.02, sx1 + 0.02, sy0 - 0.02, sy1 + 0.02, z, z + 0.06, "dark_alloy", 0.005)]
join("stack_end_plates_dark_alloy", ends)
rods = [cyl("r", (x, y, (0.46 + z + 0.06) / 2), 0.008, z + 0.06 - 0.46, "satin_steel", verts=10) for x in (sx0 - 0.01, sx1 + 0.01) for y in (sy0 - 0.01, sy1 + 0.01)]
join("stack_tie_rods_satin_steel", rods)
box("stack_busbar_orange", sx1 + 0.02, sx1 + 0.05, -0.02, 0.02, 0.5, z + 0.02, "orange", 0.003)

# ---------- service door (hinged on its left edge) ----------
door_x0, door_x1 = x0 + 0.03, x1 - 0.03
door = [box("service_door_panel", door_x0, door_x1, FRONT + 0.012, FRONT + 0.035, z0 + 0.04, z1 - 0.04, "white_painted", 0.006)]
louvres = [box("l", door_x0 + 0.1, door_x1 - 0.1, FRONT + 0.035, FRONT + 0.045, zz, zz + 0.018, "dark_alloy", 0.002) for zz in [1.28 + i * 0.045 for i in range(6)]]
handle = [box("h", door_x1 - 0.07, door_x1 - 0.04, FRONT + 0.035, FRONT + 0.065, 0.82, 1.08, "satin_steel", 0.004)]
inspection = [box("w", door_x0 + 0.12, door_x1 - 0.12, FRONT + 0.035, FRONT + 0.04, 0.55, 0.95, "teal_soft", 0.003)]
join("service_door_white_painted", door)
join("service_door_louvres_dark_alloy", louvres)
join("service_door_handle_satin_steel", handle)
join("service_door_window_teal_soft", inspection)

# ---------- top cap ----------
box("top_cap_white_ceramic", -0.6, 0.6, -0.4, 0.36, 1.72, 1.8, "white_ceramic", 0.012)
corners = [box("c", x - 0.035, x + 0.035, y - 0.035, y + 0.035, 1.66, 1.84, "dark_alloy", 0.006) for x in (-0.57, 0.57) for y in (-0.37, 0.33)]
join("corner_blocks_dark_alloy", corners)

# ---------- right bay: separators, pump and controls ----------
posts = [box("q", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0.14, 1.72, "dark_alloy", 0.004) for x in (0.16, 0.57) for y in (-0.36, 0.31)]
join("bay_frame_dark_alloy", posts)
box("bay_back_panel_slate_panel", 0.14, 0.59, -0.38, -0.35, 0.14, 1.72, "slate_panel", 0.004)
# Oxygen separator (tall, white with teal bands) and hydrogen separator (steel).
cyl("o2_separator_white_ceramic", (0.29, 0.02, 1.08), 0.105, 0.98, "white_ceramic", verts=32, bevel=0.01)
bands = [cyl("b", (0.29, 0.02, zz), 0.109, 0.035, "teal", verts=32) for zz in (0.72, 1.08, 1.44)]
join("o2_separator_bands_teal", bands)
caps = [cyl("k", (0.29, 0.02, zz), 0.075, 0.05, "dark_alloy", verts=24) for zz in (0.57, 1.59)]
join("o2_separator_caps_dark_alloy", caps)
cyl("h2_separator_satin_steel", (0.48, 0.02, 0.98), 0.065, 0.78, "satin_steel", verts=24, bevel=0.008)
cyl("h2_separator_band_orange", (0.48, 0.02, 1.2), 0.068, 0.04, "orange", verts=24)
# Pipes: oxygen out to the wall, hydrogen vented up, water in from the wall.
o2 = [cyl("o", (0.29, 0.02, 1.68), 0.018, 0.14, "cool_blue", verts=12), cyl("o", (0.29, -0.17, 1.74), 0.018, 0.4, "cool_blue", axis="y", verts=12)]
join("o2_outlet_cool_blue", o2)
h2 = [cyl("v", (0.48, 0.02, 1.48), 0.016, 0.62, "dark_alloy", verts=12)]
join("h2_vent_dark_alloy", h2)
cyl("h2_vent_cap_orange", (0.48, 0.02, 1.83), 0.026, 0.05, "orange", verts=12)
water = [cyl("w", (0.0, -0.1, 0.19), 0.02, 0.56, "teal", axis="y", verts=12),
         cyl("w", (0.07, 0.17, 0.19), 0.02, 0.14, "teal", axis="x", verts=12)]
join("water_inlet_teal", water)
cross = [cyl("x", (0.14, 0.17, 0.19), 0.02, 0.18, "teal", axis="x", verts=12), cyl("x", (0.23, 0.17, 0.33), 0.02, 0.3, "teal", verts=12)]
join("water_feed_teal", cross)
# Circulation pump with a visible rotor behind an orange guard ring.
cyl("pump_housing_dark_alloy", (0.37, 0.1, 0.42), 0.085, 0.2, "dark_alloy", axis="y", verts=28, bevel=0.006)
bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.01, location=(0.37, 0.205, 0.42), rotation=(math.pi / 2, 0, 0))
ring = bpy.context.active_object
bpy.ops.object.transform_apply(rotation=True)
_finish(ring, "pump_guard_orange", "orange")
blades = [box("pr", 0.37 - 0.06, 0.37 + 0.06, 0.196, 0.202, 0.42 - 0.012, 0.42 + 0.012, "alloy", 0.002)]
blades[0].rotation_euler = (0, 0, 0)
b2 = box("pr", 0.37 - 0.012, 0.37 + 0.012, 0.196, 0.202, 0.42 - 0.06, 0.42 + 0.06, "alloy", 0.002)
hub = cyl("pr", (0.37, 0.2, 0.42), 0.02, 0.016, "alloy", axis="y", verts=16)
join("pump_rotor_alloy", blades + [b2, hub])
# Control panel: run switch, status lamp and oxygen output gauge.
box("control_panel_white_ceramic", 0.17, 0.56, FRONT - 0.02, FRONT + 0.015, 0.16, 0.3, "white_ceramic", 0.006)
box("run_switch_base_dark_alloy", 0.3, 0.36, FRONT + 0.015, FRONT + 0.025, 0.2, 0.26, "dark_alloy", 0.003)
box("run_switch_orange", 0.318, 0.342, FRONT + 0.02, FRONT + 0.06, 0.215, 0.245, "orange", 0.003)
cyl("status_lamp_bright_green", (0.5, FRONT + 0.022, 0.23), 0.018, 0.016, "bright_green", axis="y", verts=16)
cyl("o2_gauge_face_white_painted", (0.22, FRONT + 0.02, 0.23), 0.045, 0.012, "white_painted", axis="y", verts=28)
cyl("o2_gauge_rim_dark_alloy", (0.22, FRONT + 0.016, 0.23), 0.05, 0.01, "dark_alloy", axis="y", verts=28)
box("o2_gauge_needle_orange", 0.218, 0.222, FRONT + 0.027, FRONT + 0.031, 0.23, 0.265, "orange", 0)

# ---------- export ----------
for obj in PARTS:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "models", "oxygen_generator.glb"), export_format="GLB", use_selection=True, export_apply=True)

# Bounds for the manifest.
lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
for obj in PARTS:
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, world)); hi = Vector(map(max, hi, world))
tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) if False else 0 for o in PARTS)
# glTF axes: x, y=z(up), z=-y(front is -z).
bounds = [[round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]]
with open(os.path.join(OUT, "bounds.txt"), "w") as f:
    f.write(repr(bounds))
print("BOUNDS", bounds, "PARTS", len(PARTS))

# ---------- previews ----------
# Workbench: fast, material colours with studio lighting and shadows.
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
world = bpy.data.worlds.new("bg"); scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.17, 0.19, 0.2, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.22, 0.23, 1)
floor.data.materials.append(fm)
for loc, energy in [((2.5, 3.5, 3.5), 500), ((-3, 2, 2.5), 250), ((0, -3, 3), 200)]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    light = bpy.context.active_object
    light.data.energy = energy; light.data.size = 3
    direction = Vector((0, 0, 0.9)) - light.location
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add()
cam = bpy.context.active_object; scene.camera = cam
cam.data.lens = 50

def shoot(name, location, target=(0, 0, 0.92)):
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "previews", name + ".png")
    bpy.ops.render.render(write_still=True)

shoot("oxygen_generator_three_quarter", (2.3, 3.4, 2.0))
shoot("oxygen_generator_front", (0.0, 4.0, 1.1))
# Door open (rotate the door parts about the hinge on their left edge).
pivot = Vector((x0 + 0.03, FRONT + 0.02, 0))
for obj in PARTS:
    if obj.name.startswith("service_door_"):
        obj.data.transform(__import__("mathutils").Matrix.Translation(-pivot))
        obj.location = pivot
        obj.rotation_euler = (0, 0, math.radians(100))
shoot("oxygen_generator_door_open", (1.6, 3.6, 1.6))
