import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else os.path.dirname(os.path.abspath(__file__))
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)

COLORS = {
    # name: (colour, metallic, roughness)
    "shell_white": ((0.89, 0.91, 0.90, 1), 0.0, 0.58),
    "body_white": ((0.95, 0.95, 0.94, 1), 0.0, 0.55),
    "frame_dark_alloy": ((0.53, 0.59, 0.63, 1), 0.3, 0.42),
    "trim_steel": ((0.76, 0.80, 0.82, 1), 0.3, 0.36),
    "recess_graphite": ((0.30, 0.35, 0.38, 1), 0.15, 0.55),
    "seal_rubber": ((0.20, 0.23, 0.25, 1), 0.0, 0.85),
    "handle_orange": ((0.91, 0.54, 0.27, 1), 0.0, 0.5),
    "canopy_fabric": ((0.90, 0.90, 0.88, 1), 0.0, 0.8),
    "canopy_band_orange": ((0.91, 0.54, 0.27, 1), 0.0, 0.75),
    "line_cord_fabric": ((0.85, 0.84, 0.80, 1), 0.0, 0.85),
    "foam_ivory": ((0.93, 0.92, 0.87, 1), 0.0, 0.9),
    "strap_orange": ((0.91, 0.54, 0.27, 1), 0.0, 0.7),
    "dial_face_ceramic": ((0.95, 0.95, 0.93, 1), 0.0, 0.5),
    "status_green_light": ((0.35, 1.0, 0.5, 1), 0.0, 0.4),
}
MATS = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
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


def box(name, material, size, at, bevel=0.01, segments=3, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "NONE"
    obj.data.materials.append(MATS[material])
    return smooth(obj)


def cylinder(name, material, radius, depth, at, rotation=(0, 0, 0), vertices=24, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=at, rotation=rotation, vertices=vertices)
    obj = bpy.context.active_object
    obj.name = name
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    obj.data.materials.append(MATS[material])
    return smooth(obj)


def torus(name, material, major, minor, at, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=at, rotation=rotation, major_segments=32, minor_segments=10)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(MATS[material])
    return smooth(obj)


def tube(name, material, points, radius, sides=6):
    """A cord or strap along a polyline of Vectors."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = max(0, sides // 4 - 1)
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for i, p in enumerate(points): spline.points[i].co = (p.x, p.y, p.z, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATS[material])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.name = name
    return smooth(obj)

# ---------- output ----------

def preview(path, distance):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 640, 420
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.22, 0.16, 1)
    scene.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    centre = Vector((0, 0, 0))
    meshes = [o for o in scene.objects if o.type == "MESH"]
    if meshes:
        pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        centre = sum(pts, Vector()) / len(pts)
    cam.location = centre + Vector((distance * 0.55, -distance, distance * 0.6))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

