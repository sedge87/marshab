"""Blender (5.x) build script: the containers the vehicles came down in
(docs/intro-rework.md §2, R3). Same house style and helpers as
mars_storm_cargo_v1 (_helpers.py is its toolbox, copied).

Run:  blender --background --python build_drop_shells.py -- <out_dir> [ids]

Models (Blender Z-up; the game's (x, z, -y)); each sits on the ground at its origin:
  shell_trough   one half of the buggy's cargo shell, split along its length on
                 impact, lying open side up and rocked over (4.4 m long).
  shell_dome     the other half, lying dome up where it bounced.
  drone_capsule  the drone's small capsule on its side, its hatch sprung open.
  heavy_lander   the HabRover's heavy lander: a deck on four legs, tanks and
                 engines, one leg crumpled so it lies tipped about 18 degrees.
No lettering. One orange accent each (release handles, the hatch latch, a tank band).
"""
import math
import os
import random

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "_helpers.py")).read())

import bmesh
from mathutils import Vector, Matrix, noise

COLORS["scorch_recess_graphite"] = ((0.12, 0.12, 0.12, 1), 0.1, 0.8)


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target="MESH")   # bake bevels and solidify in
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def ground(obj, sink=0.0):
    low = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    obj.location.z -= low + sink
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ---------- the buggy's shell ----------

SL, SR = 4.4, 1.25     # shell length (X) and radius


def shell_half(dented=True):
    """A trough: the lower half of a cylinder along X, open side up, axis at z = SR."""
    random.seed(11)
    bm = bmesh.new()
    seg, rings = 28, 30
    grid = []
    for i in range(rings + 1):
        x = -SL / 2 + SL * i / rings
        row = []
        for k in range(seg + 1):
            a = math.pi + math.pi * k / seg          # 180..360 degrees: the bottom half
            y, z = math.cos(a) * SR, math.sin(a) * SR
            # A dent near the +X end where it hit, and a little waviness.
            d = 0.0
            if dented:
                d = 0.22 * max(0.0, 1 - Vector((x - 1.5, y + 0.5, z + 0.6)).length / 1.1) ** 2
            d += 0.012 * noise.noise(Vector((x * 1.3, y * 1.3, z * 1.3)))
            row.append(bm.verts.new((x, y * (1 - d / SR), SR + z * (1 - d / SR))))
        grid.append(row)
    for i in range(rings):
        for k in range(seg):
            bm.faces.new([grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1]])
    # Flat bulkheads at both ends.
    for i in (0, rings):
        centre = bm.verts.new((grid[i][0].co.x, 0, SR))
        for k in range(seg):
            bm.faces.new([centre, grid[i][k], grid[i][k + 1]] if i == 0 else [centre, grid[i][k + 1], grid[i][k]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("shell_body_shell_white")
    bm.to_mesh(mesh)
    bm.free()
    body = bpy.data.objects.new("shell_body_shell_white", mesh)
    bpy.context.scene.collection.objects.link(body)
    body.data.materials.append(MATS["shell_white"])
    smooth(body)
    body.modifiers.new("thick", "SOLIDIFY").thickness = 0.05
    parts = [body]
    # The split rim: graphite frame along both long edges and over the bulkheads.
    for sy in (-1, 1):
        parts.append(box("split_rim_frame_dark_alloy", "frame_dark_alloy", (SL + 0.04, 0.08, 0.07), (0, sy * (SR - 0.02), SR), 0.01))
        for x in [(-1.8 + 0.6 * j) for j in range(7)]:
            parts.append(cylinder("separation_bolt_trim_steel", "trim_steel", 0.035, 0.05, (x, sy * (SR - 0.02), SR + 0.05), vertices=10))
    for sx in (-1, 1):
        parts.append(box("bulkhead_rim_frame_dark_alloy", "frame_dark_alloy", (0.08, 2 * SR, 0.07), (sx * SL / 2, 0, SR), 0.01))
    # Ribs round the outside.
    for x in (-1.6, -0.5, 0.6, 1.7):
        pts = [Vector((x, math.cos(math.pi + math.pi * k / 16) * (SR + 0.03), SR + math.sin(math.pi + math.pi * k / 16) * (SR + 0.03))) for k in range(17)]
        parts.append(tube("rib_frame_dark_alloy", "frame_dark_alloy", pts, 0.035, 6))
    # Inside: foam cradle blocks the buggy rode on, and a torn tie-down strap.
    for x in (-1.2, 1.0):
        parts.append(box("cradle_foam_ivory", "foam_ivory", (0.35, 1.5, 0.35), (x, 0, 0.32), 0.03, rotation=(0, 0, math.radians(random.uniform(-6, 6)))))
    parts.append(tube("tie_down_strap_orange", "strap_orange", [Vector((-0.4, -1.0, 0.25)), Vector((-0.2, -0.3, 0.12)), Vector((0.1, 0.2, 0.14)), Vector((0.5, 0.35, 0.2))], 0.02, 4))
    # The release handles, the one accent.
    for sx in (-1, 1):
        parts.append(box("release_handle_orange", "handle_orange", (0.05, 0.16, 0.07), (sx * (SL / 2 + 0.05), SR * 0.55, SR * 0.55), 0.01))
    return join(parts, "shell_body_shell_white")


def shell_trough():
    obj = shell_half(True)
    obj.rotation_euler = (math.radians(14), math.radians(-3), 0)   # rocked onto one side
    ground(obj, 0.12)


def shell_dome():
    obj = shell_half(False)
    obj.rotation_euler = (math.radians(180 - 9), math.radians(4), math.radians(8))   # dome up, one rim dug in
    ground(obj, 0.15)


# ---------- the drone's capsule ----------

def drone_capsule():
    r, h = 0.55, 1.0
    parts = []
    parts.append(cylinder("capsule_body_shell_white", "shell_white", r, h, (0, 0, 0), vertices=36, bevel=0.03))
    bpy.ops.mesh.primitive_cone_add(vertices=36, radius1=r, radius2=0.18, depth=0.5, location=(0, 0, -h / 2 - 0.25), rotation=(math.pi, 0, 0))
    nose = bpy.context.active_object
    nose.name = "heat_nose_recess_graphite"
    nose.data.materials.append(MATS["recess_graphite"])
    parts.append(smooth(nose))
    for z in (-h / 2 + 0.06, h / 2 - 0.06):
        parts.append(torus("band_frame_dark_alloy", "frame_dark_alloy", r + 0.01, 0.025, (0, 0, z)))
    parts.append(cylinder("open_rim_recess_graphite", "recess_graphite", r - 0.05, 0.03, (0, 0, h / 2 + 0.005), vertices=36))
    parts.append(box("cradle_foam_ivory", "foam_ivory", (0.5, 0.5, 0.3), (0, 0, h / 2 - 0.18), 0.03))
    # The hatch, sprung open on its hinge and hanging off the rim.
    hinge = Vector((r, 0, h / 2))
    lid = cylinder("hatch_shell_white", "shell_white", r - 0.02, 0.05, (0, 0, 0), vertices=36, bevel=0.01)
    lid.rotation_euler = (0, math.radians(-115), 0)
    lid.location = hinge + Matrix.Rotation(math.radians(-115), 3, "Y") @ Vector((-r + 0.02, 0, 0))
    parts.append(lid)
    parts.append(cylinder("latch_band_orange", "handle_orange", r + 0.012, 0.06, (0, 0, -0.1), vertices=36))
    parts.append(cylinder("hinge_trim_steel", "trim_steel", 0.03, 0.22, (r, 0, h / 2), (math.radians(90), 0, 0), 12))
    # A small chute pack and its cut riser.
    parts.append(box("chute_pack_seal_rubber", "seal_rubber", (0.2, 0.3, 0.14), (0, r - 0.05, h / 2 - 0.3), 0.03))
    obj = join(parts, "capsule_body_shell_white")
    obj.rotation_euler = (math.radians(82), 0, math.radians(10))   # lying on its side, nose dug in
    ground(obj, 0.18)


# ---------- the heavy lander ----------

DW, DD, DECK = 6.0, 4.4, 1.25     # deck width (X), depth (Y), height of its underside


def heavy_lander():
    parts = []
    parts.append(box("deck_frame_dark_alloy", "frame_dark_alloy", (DW, DD, 0.32), (0, 0, DECK + 0.16), 0.03))
    parts.append(box("deck_plate_recess_graphite", "recess_graphite", (DW - 0.3, DD - 0.3, 0.04), (0, 0, DECK + 0.33), 0.01))
    # Tanks: two spheres and a long cylinder, white, one orange band.
    for x in (-1.6, 1.6):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(x, -0.9, DECK + 0.95), segments=32, ring_count=16)
        tank = bpy.context.active_object
        tank.name = "tank_body_white"
        tank.data.materials.append(MATS["body_white"])
        parts.append(smooth(tank))
        parts.append(torus("tank_girdle_frame_dark_alloy", "frame_dark_alloy", 0.55, 0.03, (x, -0.9, DECK + 0.95)))
    parts.append(cylinder("tank_body_white", "body_white", 0.5, 3.8, (0, 1.1, DECK + 0.85), (0, math.radians(90), 0), 32, 0.02))
    parts.append(cylinder("tank_band_orange", "handle_orange", 0.51, 0.12, (0.9, 1.1, DECK + 0.85), (0, math.radians(90), 0), 32))
    for x in (-1.2, 1.2):
        parts.append(box("tank_saddle_frame_dark_alloy", "frame_dark_alloy", (0.18, 1.0, 0.5), (x, 1.1, DECK + 0.55), 0.02))
    # Handrails round the deck edge where the rover rode.
    for sy in (-1, 1):
        parts.append(tube("deck_rail_trim_steel", "trim_steel", [Vector((-DW / 2 + 0.2, sy * (DD / 2 - 0.12), DECK + 0.95)), Vector((DW / 2 - 0.2, sy * (DD / 2 - 0.12), DECK + 0.95))], 0.03, 6))
        for x in (-2.6, -0.9, 0.9, 2.6):
            parts.append(cylinder("rail_post_trim_steel", "trim_steel", 0.03, 0.6, (x, sy * (DD / 2 - 0.12), DECK + 0.65), vertices=10))
    # Engines under the deck, scorched.
    for sx in (-1, 1):
        for sy in (-1, 1):
            bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.36, radius2=0.14, depth=0.55, location=(sx * 1.3, sy * 0.9, DECK - 0.27))
            bell = bpy.context.active_object
            bell.name = "engine_bell_scorch_recess_graphite"
            bell.data.materials.append(MATS["scorch_recess_graphite"])
            parts.append(smooth(bell))
    # Four legs: a main strut from the deck corner out and down to a footpad,
    # and a brace back under the deck. Leg A (+X, +Y) is crumpled: its strut
    # kinked, the pad folded under.
    feet = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = Vector((sx * (DW / 2 - 0.3), sy * (DD / 2 - 0.3), DECK + 0.05))
            foot = Vector((sx * (DW / 2 + 0.7), sy * (DD / 2 + 0.6), 0.12))
            brace_top = Vector((sx * (DW / 2 - 1.2), sy * (DD / 2 - 0.9), DECK))
            crumpled = sx > 0 and sy > 0
            if crumpled:
                knee = top.lerp(foot, 0.45) + Vector((sx * 0.35, -sy * 0.25, -0.25))
                foot = Vector((sx * (DW / 2 + 0.2), sy * (DD / 2 + 0.05), DECK - 0.95))
                parts.append(tube("leg_strut_trim_steel", "trim_steel", [top, knee, foot], 0.07, 8))
                parts.append(tube("leg_brace_frame_dark_alloy", "frame_dark_alloy", [brace_top, knee + Vector((0, 0, 0.1))], 0.05, 8))
                parts.append(cylinder("footpad_frame_dark_alloy", "frame_dark_alloy", 0.42, 0.08, foot + Vector((0.1, 0, -0.1)), (math.radians(70), math.radians(20), 0), 24, 0.01))
            else:
                parts.append(tube("leg_strut_trim_steel", "trim_steel", [top, foot + Vector((0, 0, 0.1))], 0.07, 8))
                parts.append(tube("leg_brace_frame_dark_alloy", "frame_dark_alloy", [brace_top, top.lerp(foot, 0.6)], 0.05, 8))
                parts.append(cylinder("footpad_frame_dark_alloy", "frame_dark_alloy", 0.42, 0.08, foot, vertices=24, bevel=0.01))
                parts.append(cylinder("shock_seal_rubber", "seal_rubber", 0.1, 0.35, top.lerp(foot, 0.25), vertices=12))
            feet[(sx, sy)] = foot
    # The ramp the rover would have driven down, folded flat on the deck's -X end.
    parts.append(box("ramp_frame_dark_alloy", "frame_dark_alloy", (1.4, 2.2, 0.08), (-DW / 2 + 0.9, 0, DECK + 0.4), 0.02))
    obj = join(parts, "deck_frame_dark_alloy")
    # Tip it onto the crumpled leg: about the line through the two neighbouring
    # feet, so A's corner goes down and the opposite foot lifts.
    b, c = feet[(1, -1)], feet[(-1, 1)]
    axis = (c - b).normalized()
    pivot = (b + c) / 2
    rot = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-18), 4, axis) @ Matrix.Translation(-pivot)
    obj.data.transform(rot)
    a_corner = (rot @ Vector((DW / 2, DD / 2, DECK))).z
    d_corner = (rot @ Vector((-DW / 2, -DD / 2, DECK))).z
    if a_corner > d_corner:   # went the wrong way: tip the other way
        obj.data.transform(rot.inverted() @ rot.inverted())
    print('lander tilt: A corner %.2f, D corner %.2f (before flip check)' % (a_corner, d_corner))
    ground(obj, 0.12)


MODELS = {
    "shell_trough": (shell_trough, 9.0),
    "shell_dome": (shell_dome, 9.0),
    "drone_capsule": (drone_capsule, 3.5),
    "heavy_lander": (heavy_lander, 13.0),
}


def main():
    previews = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "previews")
    os.makedirs(previews, exist_ok=True)
    for model_id, (build, distance) in MODELS.items():
        if ONLY and model_id not in ONLY: continue
        clear()
        build()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects: obj.select_set(obj.type == "MESH")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, model_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
        deps = bpy.context.evaluated_depsgraph_get()
        tris = 0
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH": continue
            mesh = obj.evaluated_get(deps).to_mesh()
            mesh.calc_loop_triangles()
            tris += len(mesh.loop_triangles)
        print("%s: %d triangles" % (model_id, tris))
        preview(os.path.join(previews, model_id + ".png"), distance)


main()
