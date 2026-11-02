"""Blender (5.x) build script: the slate, the crew's rugged handheld
(scripts/pda.gd raises it on Tab; docs/pda.md).

Run:  blender --background --python build_slate.py -- <out_dir>
Writes <out_dir>/slate.glb and slate.png (a preview).

In the game's frame (glTF): the slate is centred on the origin, its screen
faces +Z (your eyes when it's raised) and +Y is up. The screen itself is drawn
by the game on a quad at z = +0.0085, inside the bezel (0.224 x 0.14 m, 16:10);
nothing here is a screen or carries any lettering (docs/house-style.md).

Parts (component_material, for the house palette):
  slate_case_graphite, slate_bezel_graphite   the body and the raised frame
  grip_rubber                                 side handles, back strap, buttons
  bumper_rubber                               the four corner bumpers
  tether_orange                               the lanyard tab: its one accent
  status_green_light                          the power light
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS_OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.dirname(os.path.abspath(__file__))
os.makedirs(ARGS_OUT, exist_ok=True)

# Blender is Z-up and glTF Y-up: Blender (x, y, z) is the game's (x, z, -y).
# So here the screen faces -Y (game +Z) and Z is up.
W, H, D = 0.27, 0.18, 0.022      # the case
SW, SH = 0.224, 0.14             # the screen opening
FRONT = -0.0075                  # the case's front face (Blender y)
COLORS = {
    "slate_case_graphite": ((0.3, 0.35, 0.38, 1), 0.15, 0.55),
    "slate_bezel_graphite": ((0.22, 0.26, 0.28, 1), 0.15, 0.5),
    "grip_rubber": ((0.2, 0.23, 0.25, 1), 0.0, 0.85),
    "bumper_rubber": ((0.2, 0.23, 0.25, 1), 0.0, 0.85),
    "tether_orange": ((0.91, 0.54, 0.27, 1), 0.0, 0.5),
    "status_green_light": ((0.35, 1.0, 0.5, 1), 0.0, 0.4),
}
MATS = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def materials():
    for name, (colour, metal, rough) in COLORS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if name.endswith("_light"):
            bsdf.inputs["Emission Color"].default_value = colour
            bsdf.inputs["Emission Strength"].default_value = 3.0
        MATS[name] = m


def smooth(obj):
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj


def rounded_box(name, material, size, at, bevel, segments=4):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    mod.limit_method = "NONE"
    obj.data.materials.append(MATS[material])
    smooth(obj)
    return obj


def cylinder(name, material, radius, depth, at, rotation=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=at, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(MATS[material])
    smooth(obj)
    return obj


def case():
    # The body: a thick rounded slab, a little thicker behind the screen.
    rounded_box("slate_case_graphite", "slate_case_graphite", (W, D, H), (0, FRONT + D / 2, 0), 0.008)
    rounded_box("slate_back_graphite", "slate_case_graphite", (W - 0.05, 0.008, H - 0.05), (0, FRONT + D + 0.003, 0), 0.004)
    # The raised frame round the screen opening.
    bez = 0.011
    lip = 0.004
    y = FRONT - lip / 2
    for size, at in (((SW + 2 * bez, lip, bez), (0, y, SH / 2 + bez / 2)), ((SW + 2 * bez, lip, bez), (0, y, -SH / 2 - bez / 2)),
                     ((bez, lip, SH), (SW / 2 + bez / 2, y, 0)), ((bez, lip, SH), (-SW / 2 - bez / 2, y, 0))):
        rounded_box("slate_bezel_graphite", "slate_bezel_graphite", size, at, 0.0015, 2)
    # Three buttons along the bottom of the frame, and the power light.
    for i in range(3):
        rounded_box("grip_button_rubber", "grip_rubber", (0.016, 0.004, 0.006), (-0.03 + i * 0.03, FRONT - 0.003, -H / 2 + 0.009), 0.0018, 2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0022, location=(SW / 2 + 0.002, FRONT - 0.004, SH / 2 + 0.0055))
    led = bpy.context.active_object
    led.name = "status_green_light"
    led.data.materials.append(MATS["status_green_light"])


def grips():
    # A rubber handle down each side, for a gloved hand.
    for side in (-1, 1):
        x = side * (W / 2 + 0.006)
        rounded_box("grip_rubber", "grip_rubber", (0.026, D + 0.01, H - 0.05), (x, FRONT + D / 2, 0), 0.01, 5)
    # Corner bumpers.
    for sx in (-1, 1):
        for sz in (-1, 1):
            rounded_box("bumper_rubber", "bumper_rubber", (0.04, D + 0.008, 0.04), (sx * (W / 2 - 0.012), FRONT + D / 2, sz * (H / 2 - 0.012)), 0.012, 4)
    # A hand strap across the back.
    rounded_box("strap_back_rubber", "grip_rubber", (0.16, 0.006, 0.04), (0, FRONT + D + 0.009, -0.01), 0.003, 2)


def tether():
    # The lanyard tab on the top left: an orange loop on a stub.
    rounded_box("tether_stub_graphite", "slate_case_graphite", (0.02, 0.012, 0.012), (-W / 2 + 0.035, FRONT + D / 2, H / 2 + 0.004), 0.003, 2)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.011, minor_radius=0.0028, location=(-W / 2 + 0.035, FRONT + D / 2, H / 2 + 0.018),
                                     rotation=(0, math.radians(90), 0), major_segments=24, minor_segments=10)
    loop = bpy.context.active_object
    loop.name = "tether_orange"
    loop.data.materials.append(MATS["tether_orange"])
    smooth(loop)


def preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 900, 600
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.22, 0.16, 1)
    scene.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.location = (0.16, -0.42, 0.14)
    cam.rotation_euler = (Vector((0.0, 0.0, 0.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear()
    materials()
    case()
    grips()
    tether()
    for obj in bpy.context.scene.objects: obj.select_set(obj.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ARGS_OUT, "slate.glb"), export_format="GLB", use_selection=True, export_apply=True)
    tris = 0
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH": continue
        mesh = obj.evaluated_get(deps).to_mesh()
        mesh.calc_loop_triangles()
        tris += len(mesh.loop_triangles)
    print("slate: %d triangles" % tris)
    preview(os.path.join(ARGS_OUT, "slate.png"))


main()
