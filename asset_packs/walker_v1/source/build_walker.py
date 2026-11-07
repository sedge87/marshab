"""Blender (5.x) build script: the walking carrier (step 3c, docs/systems-and-items.md §14).

Run:  blender --background --python build_walker.py -- <out_dir>
Writes <out_dir>/walker.glb.

A six-legged carrier with a wheel on each foot (after NASA's ATHLETE): it
walks on rough ground and rolls on flat. It carries the General Module slung
under its frame on four winch cables, so it can stand over the spot you chose
and lower the module straight down. Shares the furnishings pack's materials
and helpers, so it sits in the same world as everything else. No lettering.

A hierarchy of pivots the game animates (scripts/walker.gd):

  Walker
    Body                   the frame: lowers to crouch
      Hip_1..Hip_6         at each leg's root (swing about Z, Blender up)
        Knee_n             (pitch: lifts the foot)
          Wheel_n          at the axle (spins about the leg's local X)
      Module               the General Module on its cables: lowers
      Cable_1..Cable_4     winch cables (the game stretches them about Z)
      Lamp                 the fault lamp on leg 4 (the game blinks it)
    Dust                   the dust packed in leg 4's wheel fork (hidden once cleaned)

Legs 1-3 on the left (-X), 4-6 on the right (+X), front to back. Metres,
ground origin; the front faces -Z in glTF (Blender +Y here).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({
    "rover_white": ((0.92, 0.92, 0.89, 1), 0.04, 0.5),
    "lamp_amber": ((1.0, 0.62, 0.18, 1), 0.0, 0.3),
    "regolith_dust": ((0.62, 0.36, 0.22, 1), 0.0, 0.95),
    "solar_cell": ((0.08, 0.13, 0.22, 1), 0.55, 0.25),
})
GLOW.update({"lamp_amber": 2.4})

FRAME_Z = 5.3            # the frame's middle when standing
MODULE = (3.0, 4.5, 1.25, 4.55)   # half width, half length, bottom, top (6 x 9 m, as placed)
LEGS = [(-1, 5.0), (-1, 0.0), (-1, -5.0), (1, 5.0), (1, 0.0), (1, -5.0)]
HIP_X = 4.1
KNEE_OUT, KNEE_UP = 2.3, 1.5
FOOT_OUT = 3.6
WHEEL_R = 0.62


def empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.2
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def attach(objs, parent):
    bpy.context.view_layer.update()
    for obj in objs:
        if obj is None: continue
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()


def build():
    root = empty("Walker", (0, 0, 0))
    body = empty("Body", (0, 0, FRAME_Z), root)
    z0, z1 = FRAME_Z - 0.3, FRAME_Z + 0.3
    hx, hy = HIP_X - 0.2, 5.6
    frame = []
    # Two long side beams, three cross beams: a ladder frame the module hangs in.
    for s in (-1, 1):
        frame.append(box("beam", s * hx - 0.3, s * hx + 0.3, -hy, hy, z0, z1, "rover_white", 0.06))
        frame.append(box("beam_trim", s * hx - 0.31, s * hx + 0.31, -hy + 0.4, hy - 0.4, z0 + 0.22, z0 + 0.3, "orange", 0.01))
    for y in (-hy + 0.3, 0.0, hy - 0.3):
        frame.append(box("cross", -hx, hx, y - 0.25, y + 0.25, z0 + 0.08, z1 - 0.05, "warm_panel", 0.04))
    # The top deck: solar strips and the avionics box.
    for y in (-3.6, -1.2, 1.2, 3.6):
        frame.append(box("solar", -hx + 0.5, hx - 0.5, y - 0.9, y + 0.9, z1, z1 + 0.06, "solar_cell", 0.0))
        frame.append(box("solar_rim", -hx + 0.45, hx - 0.45, y - 0.95, y + 0.95, z1 - 0.02, z1 + 0.02, "alloy", 0.0))
    frame.append(box("avionics", -1.0, 1.0, hy - 1.4, hy - 0.2, z1, z1 + 0.7, "warm_shell", 0.08))
    frame.append(box("avionics_vent", -0.8, 0.8, hy - 0.21, hy - 0.18, z1 + 0.15, z1 + 0.55, "graphite", 0.01))
    # Its eyes: a stereo camera pair on a short mast at the front.
    frame.append(rod("mast", (0, hy - 0.8, z1 + 0.7), (0, hy - 0.8, z1 + 1.5), 0.06, "dark_alloy", 12))
    frame.append(box("cam_bar", -0.5, 0.5, hy - 0.95, hy - 0.65, z1 + 1.5, z1 + 1.7, "graphite", 0.03))
    for x in (-0.38, 0.38):
        frame.append(cyl("cam_lens", (x, hy - 0.63, z1 + 1.6), 0.07, 0.05, "dark_glass", axis="y", verts=16))
    # Winches at the four corners of the module.
    winch_at = [(sx * (MODULE[0] - 0.4), sy * (MODULE[1] - 0.5)) for sx in (-1, 1) for sy in (-1, 1)]
    for (x, y) in winch_at:
        frame.append(cyl("winch", (x, y, z0 - 0.15), 0.28, 0.5, "graphite", axis="x", verts=20, bevel=0.02))
    groups = {}
    for o in frame:
        groups.setdefault(o.name.split(".")[0], []).append(o)
    names = {"beam": "frame_rover_white", "beam_trim": "frame_trim_orange", "cross": "frame_cross_warm_panel", "solar": "deck_solar_cell",
             "solar_rim": "deck_rim_alloy", "avionics": "avionics_warm_shell", "avionics_vent": "avionics_vent_graphite", "mast": "mast_dark_alloy",
             "cam_bar": "cam_graphite", "cam_lens": "cam_lens_dark_glass", "winch": "winch_graphite"}
    attach([join(names[key], objs) for key, objs in groups.items()], body)

    # ---- the six legs ----
    for i, (s, y) in enumerate(LEGS):
        n = i + 1
        hip_at = (s * HIP_X, y, FRAME_Z)
        knee_at = (s * (HIP_X + KNEE_OUT), y, FRAME_Z + KNEE_UP)
        foot_at = (s * (HIP_X + FOOT_OUT), y, WHEEL_R)
        hip = empty("Hip_%d" % n, hip_at, body)
        thigh = [cyl("hip_joint", hip_at, 0.42, 0.75, "graphite", axis="y", verts=24, bevel=0.03),
                 rod("thigh", hip_at, knee_at, 0.24, "rover_white", 16),
                 rod("thigh_stripe", (hip_at[0] + s * 0.6, y, FRAME_Z + 0.42), (hip_at[0] + s * 1.7, y, FRAME_Z + 1.13), 0.25, "orange", 16)]
        attach([join("leg%d_thigh_rover_white" % n, thigh[:2]), join("leg%d_stripe_orange" % n, thigh[2:])], hip)
        knee = empty("Knee_%d" % n, knee_at, hip)
        shin = [cyl("knee_joint", knee_at, 0.34, 0.62, "graphite", axis="y", verts=24, bevel=0.03),
                rod("shin", knee_at, (foot_at[0], y, WHEEL_R + 0.55), 0.19, "alloy", 16),
                rod("strut", (knee_at[0] - s * 0.1, y, knee_at[2] - 0.3), (foot_at[0] - s * 0.35, y, WHEEL_R + 0.9), 0.08, "dark_alloy", 10),
                box("fork", foot_at[0] - 0.12, foot_at[0] + 0.12, y - 0.45, y + 0.45, WHEEL_R + 0.25, WHEEL_R + 0.6, "dark_alloy", 0.04)]
        attach([join("leg%d_shin_alloy" % n, shin)], knee)
        wheel = empty("Wheel_%d" % n, foot_at, knee)
        parts = [cyl("tyre", foot_at, WHEEL_R, 0.42, "black_rubber", axis="x", verts=32, bevel=0.04),
                 cyl("hub", (foot_at[0] + s * 0.2, y, WHEEL_R), 0.3, 0.06, "alloy", axis="x", verts=24),
                 cyl("cap", (foot_at[0] + s * 0.24, y, WHEEL_R), 0.12, 0.04, "orange", axis="x", verts=16)]
        for k in range(14):
            a = k / 14 * math.tau
            parts.append(box("tread", foot_at[0] - 0.2, foot_at[0] + 0.2, y + math.cos(a) * WHEEL_R - 0.05, y + math.cos(a) * WHEEL_R + 0.05,
                             WHEEL_R + math.sin(a) * WHEEL_R - 0.035, WHEEL_R + math.sin(a) * WHEEL_R + 0.035, "black_rubber", 0.01))
        attach([join("wheel%d_black_rubber" % n, parts[:1] + parts[3:]), join("wheel%d_hub_alloy" % n, parts[1:2]), join("wheel%d_cap_orange" % n, parts[2:3])], wheel)

    # ---- the fault: leg 4's wheel fork packed with dust, and its lamp ----
    s, y = LEGS[3]
    fork_at = Vector((s * (HIP_X + FOOT_OUT), y, WHEEL_R + 0.55))
    dust = empty("Dust", tuple(fork_at), root)
    clods = [sphere("clod", tuple(fork_at + Vector(o)), r, "regolith_dust", scale=(1.2, 1.0, 0.8), segments=10)
             for o, r in (((0.15, 0.35, 0.05), 0.26), ((-0.15, -0.3, 0.1), 0.24), ((0.2, 0.0, -0.25), 0.25), ((-0.05, 0.1, 0.25), 0.2), ((0.1, -0.5, -0.3), 0.18))]
    attach([join("dust_regolith_dust", clods)], dust)
    lamp = empty("Lamp", (s * (HIP_X + 0.2), y + 0.5, FRAME_Z + 0.45), body)
    attach([cyl("lamp_base_graphite", (s * (HIP_X + 0.2), y + 0.5, FRAME_Z + 0.36), 0.14, 0.1, "graphite", verts=16),
            sphere("lamp_glow_lamp_amber", (s * (HIP_X + 0.2), y + 0.5, FRAME_Z + 0.48), 0.13, "lamp_amber", segments=14)], lamp)

    # ---- the General Module, slung under the frame ----
    mx, my, mb, mt = MODULE
    module = empty("Module", (0, 0, mb), body)
    shell = [box("module_shell", -mx, mx, -my, my, mb + 0.1, mt, "warm_shell", 0.18),
             box("module_skirt", -mx + 0.1, mx - 0.1, -my + 0.1, my - 0.1, mb, mb + 0.12, "graphite", 0.03),
             box("module_roof", -mx + 0.25, mx - 0.25, -my + 0.25, my - 0.25, mt, mt + 0.12, "white_painted", 0.05)]
    ribs = [box("rib", -mx - 0.04, mx + 0.04, y - 0.08, y + 0.08, mb + 0.15, mt - 0.05, "slate_panel", 0.02) for y in (-3.0, -1.0, 1.0, 3.0)]
    hatch = [box("hatch_ring", mx - 0.02, mx + 0.06, -0.7, 0.7, mb + 0.5, mt - 0.6, "dark_alloy", 0.06),
             box("hatch_door", mx + 0.05, mx + 0.09, -0.55, 0.55, mb + 0.62, mt - 0.72, "warm_panel", 0.04)]
    # The airlock kit folded against the module's side (it unfolds when set down).
    kit = [box("airlock_kit", mx + 0.1, mx + 0.75, -1.2, 1.2, mb + 0.3, mt - 0.4, "orange", 0.08)]
    lugs = [cyl("lug", (sx * (mx - 0.4), sy * (my - 0.5), mt + 0.2), 0.12, 0.3, "satin_steel", axis="x", verts=12)
            for sx in (-1, 1) for sy in (-1, 1)]
    attach([join("module_warm_shell", shell[:1]), join("module_skirt_graphite", shell[1:2]), join("module_roof_white_painted", shell[2:]),
            join("module_ribs_slate_panel", ribs), join("module_hatch_dark_alloy", hatch[:1]), join("module_hatch_warm_panel", hatch[1:]),
            join("module_airlock_kit_orange", kit), join("module_lugs_satin_steel", lugs)], module)
    # Cables from each winch to its lug: unit length (1 m) down from the
    # winch, scaled about their pivot by the game as the module lowers.
    for k, (x, y) in enumerate(winch_at):
        pivot = empty("Cable_%d" % (k + 1), (x, y, z0 - 0.15), body)
        cable = rod("cable_dark_alloy", (x, y, z0 - 0.15), (x, y, z0 - 1.15), 0.035, "dark_alloy", 8)
        cable.name = "cable%d_dark_alloy" % (k + 1)
        attach([cable], pivot)


bpy.ops.wm.read_factory_settings(use_empty=True)
materials()
reset()
build()
bpy.ops.object.select_all(action="SELECT")
ARGS_OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(ARGS_OUT, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ARGS_OUT, "walker.glb"), export_format="GLB", use_selection=True, export_apply=True)
tris = 0
deps = bpy.context.evaluated_depsgraph_get()
for obj in bpy.context.scene.objects:
    if obj.type != "MESH": continue
    mesh = obj.evaluated_get(deps).to_mesh()
    mesh.calc_loop_triangles()
    tris += len(mesh.loop_triangles)
    obj.evaluated_get(deps).to_mesh_clear()
print("BUILT walker tris", tris, "objects", len(bpy.context.scene.objects))
