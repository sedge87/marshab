"""Blender (5.x) build script: your left forearm in first person, with the
suit's wrist pad strapped on (scripts/wrist_pad.gd raises it on T).

Run:  blender --background --python build_wrist_arm.py -- <out_dir>
Writes <out_dir>/wrist_arm.glb and wrist_arm.png (a preview).

In the game's frame (glTF): the arm runs along +X (the wrist at x = 0, the
elbow off at -0.36), the pad's screen faces +Y (your eyes), and the thumb is
at -Z. The screen itself is drawn by the game on a quad 9.5 mm above the
case's centre, inside the bezel; nothing here is called display_screen_glass.

Parts (component_material, for the house palette):
  sleeve_suit_fabric_white    the suit's outer layer, creased at the wrist
  wrist_ring_satin_metal      the wrist disconnect bearing
  wrist_band_orange           its locking ring: the arm's one accent
  glove_fabric                one smooth glove (a metaball hand: palm,
                              fingers in three joints, the thumb)
  glove_grip_rubber           fingertip caps and the palm pad
  pad_case_graphite, pad_bezel_graphite, pad_button_rubber, strap_rubber
  status_green_light          the pad's power light
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ARGS_OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.dirname(os.path.abspath(__file__))
os.makedirs(ARGS_OUT, exist_ok=True)

# Blender is Z-up and glTF Y-up: Blender (x, y, z) is the game's (x, z, -y).
# So here X runs along the arm, Z is toward your eyes (game +Y) and +Y is the
# thumb's side (game -Z).
SLEEVE_Z = -0.045          # the forearm's axis, below the pad
COLORS = {
    "sleeve_suit_fabric_white": ((0.92, 0.92, 0.89, 1), 0.0, 0.8),
    "wrist_ring_satin_metal": ((0.76, 0.8, 0.82, 1), 0.6, 0.32),
    "wrist_band_orange": ((0.91, 0.54, 0.27, 1), 0.0, 0.5),
    "glove_fabric": ((0.86, 0.87, 0.85, 1), 0.0, 0.75),
    "glove_grip_rubber": ((0.2, 0.23, 0.25, 1), 0.0, 0.85),
    "pad_case_graphite": ((0.3, 0.35, 0.38, 1), 0.15, 0.55),
    "pad_bezel_graphite": ((0.22, 0.26, 0.28, 1), 0.15, 0.5),
    "pad_button_rubber": ((0.2, 0.23, 0.25, 1), 0.0, 0.85),
    "strap_rubber": ((0.2, 0.23, 0.25, 1), 0.0, 0.85),
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


def link(obj, material):
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATS[material])
    return obj


def smooth(obj):
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj


def tube(name, material, x0, x1, radius, rings=40, segments=36, squash=0.86, crease=None, z=SLEEVE_Z):
    """A tube along X; radius(t) and crease(t, angle) shape it (t: 0 at x0, 1 at x1)."""
    bm = bmesh.new()
    grid = []
    for i in range(rings + 1):
        t = i / rings
        x = x0 + (x1 - x0) * t
        row = []
        for j in range(segments):
            a = j / segments * math.tau
            r = radius(t)
            if crease is not None: r *= 1.0 + crease(t, a)
            row.append(bm.verts.new((x, math.cos(a) * r, z + math.sin(a) * r * squash)))
        grid.append(row)
    for i in range(rings):
        for j in range(segments):
            bm.faces.new((grid[i][j], grid[i][(j + 1) % segments], grid[i + 1][(j + 1) % segments], grid[i + 1][j]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    link(obj, material)
    smooth(obj)
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


def sleeve():
    # Tapering to the wrist, with soft creases where the fabric bunches above
    # the ring and a few long folds down the forearm.
    def radius(t):
        return 0.051 - 0.007 * t

    def crease(t, a):
        bunch = 0.035 * max(0.0, math.sin((t - 0.86) / 0.14 * math.pi * 2.0)) if t > 0.86 else 0.0
        folds = 0.012 * math.sin(a * 3.0 + t * 9.0) * math.sin(t * math.pi) + 0.008 * math.sin(a * 5.0 - t * 14.0)
        return bunch + folds

    return tube("sleeve_suit_fabric_white", "sleeve_suit_fabric_white", -0.36, -0.004, radius, rings=60, segments=40, crease=crease)


def wrist_ring():
    tube("wrist_ring_satin_metal", "wrist_ring_satin_metal", -0.006, 0.019, lambda t: 0.0475 + 0.0025 * math.sin(t * math.pi), rings=8, squash=0.9)
    tube("wrist_band_orange", "wrist_band_orange", 0.002, 0.011, lambda t: 0.0505, rings=4, squash=0.9)


def glove():
    """One smooth glove: metaball palm, cuff, fingers and thumb, meshed."""
    mb = bpy.data.metaballs.new("glove")
    mb.resolution = 0.0035
    mb.render_resolution = 0.0035
    mb.threshold = 0.6
    obj = bpy.data.objects.new("glove_fabric", mb)
    bpy.context.scene.collection.objects.link(obj)

    def capsule(a, b, r):
        a, b = Vector(a), Vector(b)
        e = mb.elements.new(type="CAPSULE")
        e.co = (a + b) / 2
        e.radius = r
        e.size_x = (b - a).length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
        e.stiffness = 2.0
        return e

    def ellipsoid(at, half, r):
        # Half-extents in metres; the element's size scales its radius.
        e = mb.elements.new(type="ELLIPSOID")
        e.co = at
        e.radius = r
        e.size_x, e.size_y, e.size_z = (h / r for h in half)
        e.stiffness = 2.0
        return e

    z = SLEEVE_Z
    # The gauntlet over the wrist ring, then the hand.
    capsule((0.03, 0, z), (0.066, 0, z - 0.002), 0.07)
    ellipsoid((0.09, 0.0, z - 0.003), (0.052, 0.056, 0.028), 0.05)
    ellipsoid((0.072, 0.03, z - 0.008), (0.034, 0.024, 0.02), 0.034)  # the thumb's mound
    tips = []
    # Fingers (index nearest the thumb), relaxed: each joint curls a little
    # more toward the palm (down, -Z).
    for y, length, r in ((0.032, 0.08, 0.0145), (0.011, 0.086, 0.015), (-0.011, 0.08, 0.0143), (-0.031, 0.064, 0.013)):
        base = Vector((0.124 - 0.012 * abs(y) / 0.03, y, z + 0.001))
        direction = Vector((1, -y * 0.5, 0)).normalized()
        point = base
        for k, (share, bend) in enumerate(((0.45, 18), (0.3, 34), (0.25, 30))):
            direction = Quaternion(direction.cross(Vector((0, 0, -1))).normalized(), math.radians(bend)) @ direction
            nxt = point + direction * length * share
            capsule(point, nxt, r * (1.0 - 0.07 * k))
            point = nxt
        tips.append(point)
    # The thumb: out from the side of the palm, forward and a little down.
    t0 = Vector((0.066, 0.046, z - 0.008))
    t1 = t0 + Vector((0.03, 0.022, -0.008))
    t2 = t1 + Vector((0.028, 0.006, -0.012))
    capsule(t0, t1, 0.0165)
    capsule(t1, t2, 0.015)
    tips.append(t2)
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    hand = bpy.context.active_object
    hand.name = "glove_fabric"
    dec = hand.modifiers.new("decimate", "DECIMATE")
    dec.ratio = 0.5
    bpy.ops.object.modifier_apply(modifier="decimate")
    hand.data.materials.clear()
    hand.data.materials.append(MATS["glove_fabric"])
    hand.data.materials.append(MATS["glove_grip_rubber"])
    # Rubber grip: the fingertips and the palm pad (underneath, -Z).
    for poly in hand.data.polygons:
        c = poly.center
        near_tip = any((c - tip).length < 0.016 for tip in tips)
        palm = 0.06 < c.x < 0.13 and abs(c.y) < 0.042 and c.z < z - 0.012
        poly.material_index = 1 if (near_tip or palm) else 0
        poly.use_smooth = True
    hand.select_set(False)
    # The gauntlet: a stiff fabric cuff from the ring, flaring a touch, that
    # the hand grows out of.
    tube("glove_fabric", "glove_fabric", 0.012, 0.062, lambda t: 0.0455 - 0.006 * t * t, rings=10, squash=0.84,
         crease=lambda t, a: 0.03 * max(0.0, math.sin(t * math.pi * 2.0)) * (0.6 + 0.4 * math.sin(a * 4.0)))
    return hand


def pad():
    # The case, its raised bezel around the screen, a saddle onto the
    # forearm, three buttons on the near edge and the power light.
    rounded_box("pad_case_graphite", "pad_case_graphite", (0.135, 0.094, 0.016), (-0.08, 0.0, 0.001), 0.004)
    rounded_box("pad_saddle_graphite", "pad_case_graphite", (0.12, 0.07, 0.014), (-0.08, 0.0, -0.01), 0.005)
    w, d = 0.135, 0.094
    bez = 0.007
    for size, at in (((w, bez, 0.004), (-0.08, d / 2 - bez / 2, 0.0095)), ((w, bez, 0.004), (-0.08, -d / 2 + bez / 2, 0.0095)),
                     ((bez, d, 0.004), (-0.08 + w / 2 - bez / 2, 0.0, 0.0095)), ((bez, d, 0.004), (-0.08 - w / 2 + bez / 2, 0.0, 0.0095))):
        rounded_box("pad_bezel_graphite", "pad_bezel_graphite", size, at, 0.0012, 2)
    for i in range(3):
        rounded_box("pad_button_rubber", "pad_button_rubber", (0.012, 0.006, 0.006), (-0.115 + i * 0.02, d / 2 + 0.002, 0.002), 0.002, 2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0018, location=(-0.016, d / 2 - 0.0035, 0.0118))
    led = bpy.context.active_object
    led.name = "status_green_light"
    led.data.materials.append(MATS["status_green_light"])
    # Straps round the sleeve, either side of the case.
    for x in (-0.142, -0.02):
        tube("strap_rubber", "strap_rubber", x - 0.008, x + 0.008, lambda t, x=x: 0.051 - 0.007 * ((x + 0.36) / 0.356) + 0.0035, rings=3, squash=0.86)


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
    cam.location = (-0.12, 0.22, 0.26)
    cam.rotation_euler = (Vector((0.0, 0.0, -0.03)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 35
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(40), math.radians(20), math.radians(30))
    scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    clear()
    materials()
    sleeve()
    wrist_ring()
    glove()
    pad()
    for obj in bpy.context.scene.objects: obj.select_set(obj.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ARGS_OUT, "wrist_arm.glb"), export_format="GLB", use_selection=True, export_apply=True)
    tris = 0
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH": continue
        mesh = obj.evaluated_get(deps).to_mesh()
        mesh.calc_loop_triangles()
        tris += len(mesh.loop_triangles)
    print("wrist_arm: %d triangles" % tris)
    preview(os.path.join(ARGS_OUT, "wrist_arm.png"))


main()
