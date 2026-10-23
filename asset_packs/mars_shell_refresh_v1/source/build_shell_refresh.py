"""Blender (5.x) build script: the habitat shell in the house style (v1).

Run:  blender --background --python build_shell_refresh.py -- <out_dir>
Writes <out_dir>/mh_wall_bay.glb, mh_corner_post.glb, mh_corridor_bay.glb and
previews/<id>.png. Copy the GLBs over assets/showcase_modules/ (same names,
same sizes and origins as the originals, so every save still fits).

The room shell modules BuildController places (docs/house-style.md): a 3 m
wall bay, a corner post and a corridor bay. Both faces of a wall bay are
detailed, because the same module is the inside of one room and the outside
of the hull. House style: a graphite kick plate, inset white panels with
rubber seams, a slim orange rail (the one accent), a vent, and a light cove.
Material names keep the kit roles MHGame.apply_kit_materials dresses by
name: "MH pressure hull" (white), "MH pale panels" (shell), "MH seals"
(graphite), "MH safety orange" (the colony accent), "MH interior light".

Metres, z up in Blender (y up in Godot). Wall bay: x along the wall, y through
it (both faces), z up from the floor.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else os.getcwd()
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)

MATS = {}
PARTS = []
KIT = {
    "MH pressure hull": ((0.93, 0.94, 0.92, 1), .05, .5),
    "MH pale panels": ((0.85, 0.88, 0.87, 1), .05, .6),
    "MH seals": ((0.2, 0.25, 0.28, 1), .2, .55),
    "MH safety orange": ((0.86, 0.43, 0.17, 1), .1, .5),
    "MH interior light": ((1.0, 0.95, 0.85, 1), .0, .2),
}


def materials():
    for name, (rgba, metal, rough) in KIT.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if name == "MH interior light":
            bsdf.inputs["Emission Color"].default_value = rgba
            bsdf.inputs["Emission Strength"].default_value = 2.0
        MATS[name] = m


def reset():
    for obj in list(bpy.data.objects): bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes): bpy.data.meshes.remove(mesh)
    PARTS.clear()


def box(x0, x1, y0, y1, z0, z1, mat, bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(MATS[mat])
    if bevel > 0:
        mod = o.modifiers.new("b", "BEVEL"); mod.width = min(bevel, (x1 - x0) / 2.1, (y1 - y0) / 2.1, (z1 - z0) / 2.1); mod.segments = 2
        mod.limit_method = "ANGLE"
    PARTS.append(o)
    return o


def cyl(centre, r, length, mat, axis="z", verts=24):
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=length, location=centre, rotation=rot)
    o = bpy.context.active_object
    o.data.materials.append(MATS[mat])
    PARTS.append(o)
    return o


def finish(name):
    """Apply modifiers and join every part into one mesh (one draw per material)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in PARTS:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def wall_face(sgn, W, H):
    """One face of a wall bay. sgn: +1 or -1 (which side of the wall)."""
    y0 = .085 * sgn
    def ybox(x0, x1, depth0, depth1, z0, z1, mat, bevel=.008):
        a, b = y0 + depth0 * sgn, y0 + depth1 * sgn
        return box(x0, x1, min(a, b), max(a, b), z0, z1, mat, bevel)
    hw = W / 2
    # Kick plate and skirting.
    ybox(-hw, hw, 0, .045, 0, .16, "MH seals", .01)
    # Lower panel with a seam round it.
    ybox(-hw + .1, hw - .1, 0, .012, .2, .98, "MH seals", 0)
    ybox(-hw + .11, hw - .11, .012, .03, .21, .97, "MH pale panels", .012)
    # The one accent: a slim orange rail, on satin-look stand-offs.
    ybox(-hw + .06, hw - .06, .03, .06, 1.0, 1.035, "MH safety orange", .01)
    for x in (-hw + .2, 0.0, hw - .2): ybox(x - .02, x + .02, 0, .035, .995, 1.04, "MH seals", .004)
    # Two tall upper panels with a rubber seam between them.
    ybox(-hw + .1, hw - .1, 0, .01, 1.08, 2.38, "MH seals", 0)
    ybox(-hw + .11, -.015, .01, .028, 1.09, 2.37, "MH pale panels", .012)
    ybox(.015, hw - .11, .01, .028, 1.09, 2.37, "MH pale panels", .012)
    # A small vent grille on one panel.
    ybox(hw - .5, hw - .2, .028, .036, 1.2, 1.36, "MH seals", .004)
    for k in range(5):
        z = 1.225 + k * .027
        ybox(hw - .48, hw - .22, .036, .042, z, z + .01, "MH pressure hull", 0)
    # Light cove: a graphite channel with a glowing strip.
    ybox(-hw + .05, hw - .05, 0, .07, 2.44, 2.6, "MH seals", .012)
    ybox(-hw + .3, hw - .3, .07, .078, 2.48, 2.53, "MH interior light", 0)
    # Panel fixings.
    for x in (-hw + .16, hw - .16):
        for z in (1.14, 2.32):
            a = y0 + .03 * sgn
            cyl((x, a, z), .012, .012, "MH seals", axis="y", verts=12)


def mh_wall_bay():
    W, H = 2.96, 2.9
    box(-W / 2, W / 2, -.085, .085, 0, H, "MH pressure hull", .02)
    for sgn in (1, -1): wall_face(sgn, W, H)
    # Top cap.
    box(-W / 2, W / 2, -.12, .12, H - .14, H, "MH pressure hull", .02)
    return finish("mh_wall_bay")


def mh_corner_post():
    # Same footprint as before: a post at the corner with flanges along both walls.
    box(-.19, .19, -.19, .19, 0, 2.9, "MH pressure hull", .05)
    box(-.21, .21, -.21, .21, 0, .16, "MH seals", .02)
    box(-.255, .19, -.03, .03, 0, 2.9, "MH pressure hull", .015)
    box(-.03, .03, -.19, .255, 0, 2.9, "MH pressure hull", .015)
    # The orange rail wraps the post at the same height as the walls.
    box(-.2, .2, -.2, .2, 1.0, 1.035, "MH safety orange", .015)
    box(-.2, .2, -.2, .2, 2.44, 2.6, "MH seals", .02)
    # Vertical seam lines on the faces.
    for x, y in ((.19, 0), (-.19, 0), (0, .19), (0, -.19)):
        box(x - .006 if x else -.006, x + .006 if x else .006, y - .006 if y else -.006, y + .006 if y else .006, .2, 2.4, "MH seals", 0)
    return finish("mh_corner_post")


def mh_corridor_bay():
    W, L, H = 2.92, 3.0, 2.96
    hw, hl = W / 2, L / 2
    # Deck: graphite grating plates over a frame.
    box(-hw, hw, -hl, hl, 0, .1, "MH seals", .01)
    for k in range(6):
        x0 = -hw + .16 + k * ((W - .32) / 6)
        box(x0 + .02, x0 + (W - .32) / 6 - .02, -hl + .06, hl - .06, .1, .14, "MH pale panels" if k in (0, 5) else "MH seals", .006)
    # Side walls (inside faces detailed) and the ceiling.
    for sgn in (1, -1):
        x_in = sgn * (hw - .16)
        box(min(x_in, sgn * hw), max(x_in, sgn * hw), -hl, hl, 0, H - .1, "MH pressure hull", .02)
        face = x_in - sgn * .02
        box(min(face, x_in), max(face, x_in), -hl + .12, hl - .12, .16, 1.0, "MH pale panels", .01)
        box(min(face, x_in), max(face, x_in), -hl + .12, hl - .12, 1.08, 2.3, "MH pale panels", .01)
        rail = x_in - sgn * .05
        box(min(rail, x_in), max(rail, x_in), -hl + .08, hl - .08, 1.0, 1.035, "MH safety orange", .01)
        box(min(face - sgn * .02, x_in), max(face - sgn * .02, x_in), -hl, hl, 0, .16, "MH seals", .01)
        # Chamfer between wall and ceiling, with the light strip.
        box(min(x_in - sgn * .3, x_in), max(x_in - sgn * .3, x_in), -hl, hl, H - .36, H - .1, "MH pressure hull", .03)
        strip = x_in - sgn * .3
        box(min(strip, strip - sgn * .02), max(strip, strip - sgn * .02), -hl + .3, hl - .3, H - .34, H - .3, "MH interior light", 0)
    box(-hw, hw, -hl, hl, H - .12, H, "MH pressure hull", .02)
    # Frame rings at each end of the bay.
    for y in (-hl + .04, hl - .04):
        box(-hw + .14, -hw + .24, y - .04, y + .04, .1, H - .1, "MH seals", .01)
        box(hw - .24, hw - .14, y - .04, y + .04, .1, H - .1, "MH seals", .01)
        box(-hw + .14, hw - .14, y - .04, y + .04, H - .22, H - .12, "MH seals", .01)
    return finish("mh_corridor_bay")


materials()
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 640
scene.render.resolution_y = 640
for name, build in (("mh_wall_bay", mh_wall_bay), ("mh_corner_post", mh_corner_post), ("mh_corridor_bay", mh_corridor_bay)):
    reset()
    obj = build()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for c in obj.bound_box:
        w = obj.matrix_world @ Vector(c); lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    size = max(hi - lo); centre = (lo + hi) / 2
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; scene.camera = cam
    eye = centre + Vector((1.0, -1.6, 0.6)).normalized() * (size * 1.9 + .5)
    cam.location = eye
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "previews", name + ".png")
    bpy.ops.render.render(write_still=True)
    print("BUILT", name, [round(v, 3) for v in lo], [round(v, 3) for v in hi], "tris", sum(len(p.vertices) - 2 for p in obj.data.polygons))
