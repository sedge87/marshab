"""Blender (5.x) build script: Mars rocks, v2 (realistic pass, 24 Oct).

Run:  blender --background --python build_rocks.py -- <out_dir>
Writes <out_dir>/decor_rock_00..07.glb (and previews/). Copy them over
assets/original_mars/models/ (same names and roughly the same sizes as the
48-triangle originals, so every site's scatter still fits).

Each rock starts as an icosphere, squashed to a shape (block, slab, rounded
boulder, wedge), broken up with crackle (Voronoi) displacement for fractured
faces and fine noise for grain, then flattened underneath so it sits in the
ground. The game's rock shader colours them in world space.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else os.getcwd()
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)

# id: (size x, y, z in metres, kind, seed)
ROCKS = {
    "decor_rock_00": ((2.8, 2.3, 1.15), "block", 1),
    "decor_rock_01": ((1.6, 1.2, .7), "rounded", 2),
    "decor_rock_02": ((2.2, 1.5, .55), "slab", 3),
    "decor_rock_03": ((.9, .85, .62), "block", 4),
    "decor_rock_04": ((1.3, 1.0, 1.05), "wedge", 5),
    "decor_rock_05": ((1.9, 1.7, .9), "rounded", 6),
    "decor_rock_06": ((2.1, 1.85, 1.3), "block", 7),
    "decor_rock_07": ((.7, .55, .35), "slab", 8),
}


def make_rock(name, size, kind, seed):
    """Angular, fractured rock: the convex hull of random points (broken flat
    faces), cut by a few random planes, lightly weathered."""
    import bmesh
    random.seed(seed)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bm = bmesh.new()
    count = {"block": 26, "slab": 22, "wedge": 20, "rounded": 40}[kind]
    for i in range(count):
        theta = random.uniform(0, math.tau); z = random.uniform(-1, 1); r = math.sqrt(1 - z * z)
        v = Vector((r * math.cos(theta), r * math.sin(theta), z)) * random.uniform(.82, 1.0)
        if kind == "block": v = Vector([math.copysign(abs(c) ** .55, c) for c in v])
        if kind == "slab": v.z *= .45
        if kind == "wedge": v.z = v.z * .8 + v.x * .4
        bm.verts.new(v)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    # Remove anything left over inside the hull.
    for v in [v for v in bm.verts if not v.link_faces]: bm.verts.remove(v)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    rock = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(rock)
    bpy.context.view_layer.objects.active = rock
    rock.select_set(True)
    # Enough faces for weathering, then chipped edges and grain.
    sub = rock.modifiers.new("sub", "SUBSURF"); sub.subdivision_type = "SIMPLE"; sub.levels = 3
    tex = bpy.data.textures.new(name + "_chips", "VORONOI")
    tex.noise_scale = .35
    d1 = rock.modifiers.new("chips", "DISPLACE"); d1.texture = tex; d1.strength = .07; d1.texture_coords = "LOCAL"
    fine = bpy.data.textures.new(name + "_grain", "CLOUDS")
    fine.noise_scale = .12; fine.noise_depth = 2
    d2 = rock.modifiers.new("grain", "DISPLACE"); d2.texture = fine; d2.strength = .035; d2.texture_coords = "LOCAL"
    dec = rock.modifiers.new("decimate", "DECIMATE"); dec.ratio = .12
    for mod in list(rock.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    verts = rock.data.vertices
    lo = Vector((min(v.co.x for v in verts), min(v.co.y for v in verts), min(v.co.z for v in verts)))
    hi = Vector((max(v.co.x for v in verts), max(v.co.y for v in verts), max(v.co.z for v in verts)))
    span = hi - lo
    cut = lo.z + span.z * .15
    for v in verts:
        if v.co.z < cut: v.co.z = cut
        v.co.x = (v.co.x - (lo.x + hi.x) / 2) / span.x * size[0]
        v.co.y = (v.co.y - (lo.y + hi.y) / 2) / span.y * size[1]
        v.co.z = (v.co.z - cut) / (hi.z - cut) * size[2]
    for poly in rock.data.polygons: poly.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(32))
    except Exception:
        pass
    mat = bpy.data.materials.new("rock_" + name)
    mat.diffuse_color = (.45, .3, .22, 1)
    rock.data.materials.append(mat)
    return rock


scene = bpy.context.scene
for name, (size, kind, seed) in ROCKS.items():
    rock = make_rock(name, size, kind, seed)
    bpy.ops.object.select_all(action="DESELECT")
    rock.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    print("BUILT", name, kind, "tris", sum(len(p.vertices) - 2 for p in rock.data.polygons))
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 400; scene.render.resolution_y = 400
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; scene.camera = cam
    centre = Vector((0, 0, size[2] / 2)); dist = max(size) * 2.2
    cam.location = centre + Vector((dist, -dist, dist * .6))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "previews", name + ".png")
    bpy.ops.render.render(write_still=True)
