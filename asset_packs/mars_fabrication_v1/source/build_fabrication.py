"""Blender (5.x) build script: Fabrication pack for MARS: HABITAT (regolith printer and intake).

Run:  blender --background --python build_furnishings.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.
With ids, only those models are rebuilt.

Metres, floor origin, front faces -Z in glTF (Blender +Y here). Mesh names are
component_material so the game's interaction rig can find parts.

v2 (22 Oct): detail pass to match the Martian/Hail Mary packs — rounded
three-segment bevels, overhanging caps over recessed plinths, inset doors
with gasket seams, slatted vents, fasteners, labels and cable runs. The mess
booth is no longer built here (the original pack booth was restored).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else os.getcwd()
ONLY = set(ARGS[1:])
os.makedirs(os.path.join(OUT, "models"), exist_ok=True)
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)

COLORS = {
    "white_painted": ((0.93, 0.94, 0.91, 1), .03, .55),
    "warm_shell": ((0.86, 0.85, 0.80, 1), .04, .6),
    "warm_panel": ((0.76, 0.79, 0.77, 1), .06, .62),
    "slate_panel": ((0.34, 0.41, 0.44, 1), .12, .55),
    "alloy": ((0.60, 0.67, 0.69, 1), .78, .36),
    "satin_steel": ((0.77, 0.81, 0.79, 1), .85, .26),
    "dark_alloy": ((0.26, 0.32, 0.35, 1), .66, .48),
    "graphite": ((0.16, 0.19, 0.21, 1), .3, .6),
    "black_rubber": ((0.09, 0.11, 0.12, 1), .02, .85),
    "dark_glass": ((0.05, 0.08, 0.10, 1), .25, .1),
    "teal": ((0.22, 0.47, 0.51, 1), .17, .45),
    "teal_soft": ((0.42, 0.63, 0.64, 1), .04, .75),
    "cool_blue": ((0.30, 0.55, 0.78, 1), .13, .48),
    "orange": ((0.86, 0.43, 0.17, 1), .18, .5),
    "amber": ((0.94, 0.66, 0.22, 1), .10, .5),
    "bright_green": ((0.35, 0.76, 0.48, 1), .03, .43),
    "leaf_green": ((0.24, 0.52, 0.27, 1), .0, .7),
    "leaf_light": ((0.42, 0.66, 0.33, 1), .0, .65),
    "soil": ((0.25, 0.17, 0.12, 1), .0, .95),
    "regolith": ((0.66, 0.36, 0.22, 1), .0, .9),
    "regolith_dark": ((0.5, 0.26, 0.16, 1), .0, .92),
    "red_cross": ((0.80, 0.18, 0.16, 1), .05, .5),
    "pouch_silver": ((0.74, 0.76, 0.78, 1), .6, .32),
    "screen_cyan": ((0.35, 0.85, 0.95, 1), .0, .3),
    "screen_green": ((0.35, 0.95, 0.55, 1), .0, .3),
    "iv_clear": ((0.86, 0.92, 0.95, 0.35), .0, .1),
    "lamp_white": ((1.0, 0.98, 0.92, 1), .0, .2),
}
GLOW = {"screen_cyan": 1.6, "screen_green": 1.6, "lamp_white": 2.0}

MATS = {}
PARTS = []
MANIFEST = []


def reset():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    PARTS.clear()


def materials():
    for name, (rgba, metal, rough) in COLORS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if rgba[3] < 1.0:   # see-through (clear plastic, glass): exported as glTF alpha blend
            bsdf.inputs["Alpha"].default_value = rgba[3]
            if hasattr(m, "surface_render_method"): m.surface_render_method = "BLENDED"
        if GLOW.get(name, 0) > 0:
            bsdf.inputs["Emission Color"].default_value = rgba
            bsdf.inputs["Emission Strength"].default_value = GLOW[name]
        m.diffuse_color = rgba
        m.metallic = metal
        m.roughness = rough
        MATS[name] = m


def _finish(obj, name, mat, bevel=0.0, segments=3):
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(MATS[mat])
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if hasattr(obj.data, "set_sharp_from_angle"):
        obj.data.set_sharp_from_angle(angle=math.radians(40))
    PARTS.append(obj)
    return obj


def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.012, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    obj = bpy.context.active_object
    obj.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    bevel = min(bevel, (x1 - x0) * .45, (y1 - y0) * .45, (z1 - z0) * .45)
    return _finish(obj, name, mat, bevel, segments)


def cyl(name, centre, radius, length, mat, axis="z", verts=32, bevel=0.0, radius2=None, segments=2):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=length, location=centre, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=length, location=centre, rotation=rot)
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat, bevel, segments)


def sphere(name, centre, radius, mat, scale=(1, 1, 1), segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=max(8, segments // 2), radius=radius, location=centre)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat)


def rod(name, a, b, radius, mat, verts=16):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=(b - a).length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat)


def torus(name, centre, major, minor, mat, axis="z"):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=12, location=centre, rotation=rot)
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat)


def join(name, objs):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        PARTS.remove(o)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    PARTS.append(obj)
    return obj


# ---------- shared details ----------

def cabinet(prefix, x0, x1, y0, y1, z0, z1, body="warm_shell", cap="white_painted", plinth=True):
    """Pack-style cabinet: body, overhanging rounded cap, recessed dark plinth, corner rails."""
    pz = z0 + (0.07 if plinth else 0)
    box(f"{prefix}_body_{body}", x0, x1, y0, y1, pz, z1 - 0.04, body, 0.018)
    box(f"{prefix}_cap_{cap}", x0 - 0.015, x1 + 0.015, y0 - 0.015, y1 + 0.02, z1 - 0.05, z1, cap, 0.02)
    if plinth:
        box(f"{prefix}_plinth_graphite", x0 + 0.03, x1 - 0.03, y0 + 0.03, y1 - 0.03, z0, pz + 0.01, "graphite", 0.008)
    rails = [box("r", x - 0.012, x + 0.012, y1 - 0.004, y1 + 0.012, pz + 0.02, z1 - 0.06, "alloy", 0.005) for x in (x0 + 0.02, x1 - 0.02)]
    join(f"{prefix}_rails_alloy", rails)


def gasket(name, x0, x1, z0, z1, y, w=0.008):
    """A thin dark seam round a door or panel, on the front face at y."""
    parts = [box("g", x0, x1, y, y + 0.004, z0, z0 + w, "black_rubber", 0), box("g", x0, x1, y, y + 0.004, z1 - w, z1, "black_rubber", 0),
             box("g", x0, x0 + w, y, y + 0.004, z0, z1, "black_rubber", 0), box("g", x1 - w, x1, y, y + 0.004, z0, z1, "black_rubber", 0)]
    return join(name, parts)


def vent(name, x0, x1, z0, z1, y, slats=7, mat="dark_alloy"):
    parts = [box("vf", x0, x1, y, y + 0.012, z0, z1, "graphite", 0.004)]
    step = (z1 - z0) / (slats + 1)
    for i in range(slats):
        z = z0 + step * (i + 1)
        parts.append(box("vs", x0 + 0.01, x1 - 0.01, y + 0.012, y + 0.02, z - 0.005, z + 0.005, mat, 0.002))
    return join(name, parts)


def bolts(name, points, y, mat="satin_steel", r=0.008):
    return join(name, [cyl("b", (x, y + 0.004, z), r, 0.008, mat, axis="y", verts=12) for x, z in points])


def handle(name, x0, x1, z, y, mat="satin_steel"):
    parts = [rod("h", (x0, y + 0.035, z), (x1, y + 0.035, z), 0.011, mat)]
    parts += [rod("s", (xx, y, z), (xx, y + 0.04, z), 0.008, mat) for xx in (x0 + 0.02, x1 - 0.02)]
    return join(name, parts)


def cushion(name, x0, x1, y0, y1, z0, z1, mat="teal_soft"):
    return box(name, x0, x1, y0, y1, z0, z1, mat, bevel=min(0.035, (z1 - z0) * 0.45), segments=4)


def caster(x, y):
    return [cyl("c", (x, y, 0.035), 0.035, 0.028, "black_rubber", axis="x", verts=20, bevel=0.004),
            box("c", x - 0.022, x + 0.022, y - 0.022, y + 0.022, 0.055, 0.105, "dark_alloy", 0.006),
            cyl("c", (x, y, 0.11), 0.014, 0.02, "satin_steel", verts=12)]


def star_base(z, radius, legs=5):
    parts = []
    for i in range(legs):
        a = 2 * math.pi * i / legs
        end = (math.cos(a) * radius, math.sin(a) * radius, z - 0.015)
        parts.append(rod("leg", (0, 0, z + 0.01), end, 0.02, "dark_alloy"))
        parts += caster(end[0], end[1])
    parts.append(cyl("hub", (0, 0, z + 0.01), 0.05, 0.06, "dark_alloy", bevel=0.01))
    return parts



def hollow(prefix, x0, x1, y0, y1, z0, z1, t, outer, liner):
    """An open-fronted box (the opening faces +Y): outer walls plus an inner
    liner, so a door that swings open shows a real compartment."""
    join(f"{prefix}_shell_{outer}", [
        box("w", x0, x1, y0, y0 + t, z0, z1, outer, 0.01),            # back
        box("w", x0, x0 + t, y0, y1, z0, z1, outer, 0.01),            # left
        box("w", x1 - t, x1, y0, y1, z0, z1, outer, 0.01),            # right
        box("w", x0, x1, y0, y1, z0, z0 + t, outer, 0.01),            # floor
        box("w", x0, x1, y0, y1, z1 - t, z1, outer, 0.01)])           # roof
    i = 0.006
    join(f"{prefix}_liner_{liner}", [
        box("l", x0 + t, x1 - t, y0 + t, y0 + t + i, z0 + t, z1 - t, liner, 0),
        box("l", x0 + t, x0 + t + i, y0 + t, y1, z0 + t, z1 - t, liner, 0),
        box("l", x1 - t - i, x1 - t, y0 + t, y1, z0 + t, z1 - t, liner, 0),
        box("l", x0 + t, x1 - t, y0 + t, y1, z0 + t, z0 + t + i, liner, 0),
        box("l", x0 + t, x1 - t, y0 + t, y1, z1 - t - i, z1 - t, liner, 0)])
    # A soft rubber lip round the opening (the door seals against it).
    gasket(f"{prefix}_lip_black_rubber", x0 + 0.004, x1 - 0.004, z0 + 0.004, z1 - 0.004, y1 - 0.002, w=0.012)

# ---------- models (Fabrication pack) ----------
# Regolith printer: a gantry 3D printer in the style of NASA's 3D-printed
# habitat prototypes. About 3.0 x 1.5 m, 2.2 m tall. Front (-Z in game) is
# Blender +Y. A half-printed curved wall panel sits on the bed.
# Regolith intake: the outdoor scoop, sieve and conveyor that feed it.

def regolith_printer():
    W, D = 1.5, 0.75          # half width (x), half depth (y)
    # Base platform: a dark plinth under a steel deck with drainage slots.
    box("plinth_graphite", -W + 0.04, W - 0.04, -D + 0.04, D - 0.04, 0.0, 0.08, "graphite", 0.01)
    box("deck_slate_panel", -W, W, -D, D, 0.08, 0.16, "slate_panel", 0.015)
    join("deck_slots_graphite", [box("s", -1.3 + i * 0.26, -1.2 + i * 0.26, D - 0.002, D + 0.002, 0.1, 0.14, "graphite", 0) for i in range(11)])
    # Print bed (heated plate) with a raised alloy rim.
    box("print_bed_slate_panel", -1.15, 1.15, -0.55, 0.45, 0.16, 0.22, "slate_panel", 0.01)
    join("bed_rim_alloy", [box("r", -1.17, 1.17, y - 0.015, y + 0.015, 0.16, 0.245, "alloy", 0.004) for y in (-0.56, 0.46)]
         + [box("r", x - 0.015, x + 0.015, -0.56, 0.46, 0.16, 0.245, "alloy", 0.004) for x in (-1.17, 1.17)])
    # The half-printed panel: a curved wall built up in ridged layers.
    layers = []
    for i in range(16):
        z = 0.22 + i * 0.035
        span = 0.95 if i < 12 else 0.95 - (i - 11) * 0.18      # the top layers are still being laid
        segs = 14
        for j in range(segs):
            a0 = -0.6 + 1.2 * j / segs
            a1 = -0.6 + 1.2 * (j + 1) / segs
            if abs((a0 + a1) / 2) / 0.6 > span: continue
            x0, y0 = math.sin(a0) * 1.6, math.cos(a0) * 1.6 - 1.75
            x1, y1 = math.sin(a1) * 1.6, math.cos(a1) * 1.6 - 1.75
            layers.append(rod("l", (x0, y0, z + 0.017), (x1, y1, z + 0.017), 0.022, "regolith_dark" if i % 2 else "regolith", 8))
    join("printed_panel_regolith", layers)
    # Gantry: four columns, two side beams on rails, a cross beam with the head.
    cols = [box("c", x - 0.06, x + 0.06, y - 0.06, y + 0.06, 0.16, 2.12, "white_painted", 0.012) for x in (-1.42, 1.42) for y in (-0.67, 0.67)]
    cols += [box("c", x - 0.09, x + 0.09, y - 0.09, y + 0.09, 0.16, 0.24, "dark_alloy", 0.01) for x in (-1.42, 1.42) for y in (-0.67, 0.67)]
    join("gantry_columns_white_painted", cols)
    join("gantry_top_frame_warm_shell", [box("t", -1.48, 1.48, y - 0.06, y + 0.06, 2.06, 2.18, "warm_shell", 0.012) for y in (-0.67, 0.67)]
         + [box("t", x - 0.06, x + 0.06, -0.73, 0.73, 2.06, 2.18, "warm_shell", 0.012) for x in (-1.42, 1.42)])
    join("y_rails_satin_steel", [box("r", -1.44, 1.44, y - 0.02, y + 0.02, 2.18, 2.21, "satin_steel", 0.004) for y in (-0.67, 0.67)])
    box("cross_beam_orange", -0.06, 0.06, -0.72, 0.72, 1.86, 2.02, "orange", 0.015)
    join("cross_beam_carriages_dark_alloy", [box("c", -0.11, 0.11, y - 0.08, y + 0.08, 1.98, 2.24, "dark_alloy", 0.01) for y in (-0.67, 0.67)])
    box("x_rail_satin_steel", -0.08, 0.08, -0.6, 0.6, 1.83, 1.86, "satin_steel", 0.004)
    # Print head: carriage, Z column, extruder barrel and nozzle.
    box("head_carriage_white_painted", -0.16, 0.16, -0.24, -0.02, 1.62, 1.88, "white_painted", 0.02)
    box("head_badge_orange", -0.1, 0.1, -0.245, -0.24, 1.75, 1.8, "orange", 0)
    cyl("head_barrel_satin_steel", (0, -0.13, 1.26), 0.07, 0.62, "satin_steel", verts=32, bevel=0.01)
    join("head_heater_bands_amber", [torus("h", (0, -0.13, z), 0.072, 0.012, "amber") for z in (1.05, 1.15, 1.25)])
    cyl("head_nozzle_dark_alloy", (0, -0.13, 0.9), 0.07, 0.12, "dark_alloy", verts=24, radius2=0.025)
    cyl("head_glow_amber", (0, -0.13, 0.83), 0.022, 0.03, "amber", verts=16)
    box("head_laser_lamp_white", -0.03, 0.03, -0.215, -0.205, 1.58, 1.6, "lamp_white", 0)
    # Feed: a hopper on the frame and a flexible hose to the head.
    cyl("feed_hopper_white_painted", (1.15, 0.45, 2.45), 0.3, 0.42, "white_painted", verts=4, radius2=0.12, bevel=0.01)
    box("feed_hopper_rim_alloy", 0.92, 1.38, 0.22, 0.68, 2.65, 2.69, "alloy", 0.006)
    box("feed_hopper_lid_graphite", 0.94, 1.36, 0.24, 0.66, 2.69, 2.71, "graphite", 0.006)
    hose = []
    pts = [(1.15, 0.45, 2.22), (0.9, 0.35, 2.32), (0.5, 0.15, 2.34), (0.2, -0.05, 2.18), (0.05, -0.12, 1.95)]
    for a, b in zip(pts, pts[1:]):
        hose.append(rod("h", a, b, 0.035, "black_rubber", 12))
        hose.append(sphere("j", b, 0.036, "black_rubber", segments=12))
    join("feed_hose_black_rubber", hose)
    join("hose_clamps_satin_steel", [torus("c", p, 0.04, 0.008, "satin_steel") for p in pts[1:-1]])
    # Control console on the right, out to the front.
    box("console_post_dark_alloy", 1.52, 1.6, 0.5, 0.6, 0.16, 1.1, "dark_alloy", 0.01)
    box("console_body_white_painted", 1.48, 1.72, 0.48, 0.74, 1.0, 1.35, "white_painted", 0.015)
    box("console_screen_screen_cyan", 1.5, 1.7, 0.741, 0.744, 1.12, 1.31, "screen_cyan", 0)
    box("console_progress_screen_green", 1.52, 1.62, 0.745, 0.747, 1.14, 1.16, "screen_green", 0)
    join("console_buttons_orange", [cyl("b", (x, 0.745, 1.06), 0.014, 0.012, "orange", axis="y", verts=16) for x in (1.53, 1.58)])
    cyl("estop_red_cross", (1.67, 0.745, 1.05), 0.024, 0.02, "red_cross", axis="y", verts=20, bevel=0.004)
    # Safety: corner guard posts with hazard bands, a beacon on top.
    for x in (-1.42, 1.42):
        for y in (-0.67, 0.67):
            box(f"hazard_band_{'l' if x < 0 else 'r'}{'f' if y > 0 else 'b'}_amber", x - 0.065, x + 0.065, y - 0.065, y + 0.065, 0.5, 0.56, "amber", 0.006)
    cyl("beacon_base_graphite", (-1.42, 0.67, 2.22), 0.05, 0.04, "graphite", verts=20)
    sphere("beacon_amber", (-1.42, 0.67, 2.28), 0.045, "amber", scale=(1, 1, 1.2))
    # Power and dust extraction at the back.
    box("power_cabinet_slate_panel", -1.3, -0.7, -0.74, -0.58, 0.16, 0.9, "slate_panel", 0.012)
    vent("power_cabinet_vent_dark_alloy", -1.25, -0.75, 0.6, 0.85, -0.74 - 0.012, slats=5)
    cyl("extractor_duct_alloy", (0.6, -0.7, 1.2), 0.11, 1.9, "alloy", verts=24)
    join("extractor_bands_dark_alloy", [torus("d", (0.6, -0.7, z), 0.112, 0.012, "dark_alloy") for z in (0.5, 1.0, 1.5, 2.0)])
    bolts("deck_bolts_satin_steel", [(x, 0.12) for x in (-1.2, -0.6, 0.0, 0.6, 1.2)], D)


def regolith_intake():
    """Outdoor: a scoop wheel digs regolith, a sieve drum grades it, and a
    covered conveyor feeds a buried pipe to the printer."""
    box("skid_slate_panel", -1.0, 1.0, -0.7, 0.7, 0.0, 0.18, "slate_panel", 0.02)
    join("skid_feet_graphite", [box("f", x - 0.12, x + 0.12, y - 0.12, y + 0.12, -0.02, 0.04, "graphite", 0.01) for x in (-0.85, 0.85) for y in (-0.55, 0.55)])
    # Scoop wheel at the front (+Y), half sunk in a trench.
    box("trench_regolith_dark", -0.55, 0.55, 0.45, 1.25, -0.05, 0.02, "regolith_dark", 0.02)
    wheel = [torus("w", (0, 0.85, 0.5), 0.45, 0.04, "orange", axis="x")]
    for i in range(8):
        a = i * math.pi / 4
        wheel.append(rod("s", (0, 0.85, 0.5), (0, 0.85 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45), 0.02, "orange", 8))
        wheel.append(box("b", -0.18, 0.18, 0.85 + math.cos(a) * 0.47 - 0.07, 0.85 + math.cos(a) * 0.47 + 0.07, 0.5 + math.sin(a) * 0.47 - 0.07, 0.5 + math.sin(a) * 0.47 + 0.07, "dark_alloy", 0.01))
    join("scoop_wheel_orange", wheel)
    cyl("scoop_hub_dark_alloy", (0, 0.85, 0.5), 0.09, 0.42, "dark_alloy", axis="x", verts=24, bevel=0.01)
    join("scoop_arms_alloy", [rod("a", (x, 0.3, 0.25), (x, 0.85, 0.5), 0.045, "alloy", 12) for x in (-0.24, 0.24)])
    # Sieve drum, on cradles.
    cyl("sieve_drum_white_painted", (0, -0.05, 0.75), 0.36, 1.2, "white_painted", axis="x", verts=32, bevel=0.01)
    join("sieve_drum_hoops_dark_alloy", [torus("h", (x, -0.05, 0.75), 0.365, 0.02, "dark_alloy", axis="x") for x in (-0.5, -0.17, 0.17, 0.5)])
    join("sieve_mesh_graphite", [box("m", x - 0.1, x + 0.1, 0.3, 0.32, 0.6, 0.9, "graphite", 0.004) for x in (-0.33, 0.0, 0.33)])
    join("drum_cradles_dark_alloy", [box("c", x - 0.05, x + 0.05, -0.35, 0.25, 0.18, 0.5, "dark_alloy", 0.01) for x in (-0.65, 0.65)])
    # Covered conveyor running back and down to the pipe.
    conveyor = [box("c", -0.18, 0.18, -0.7, -0.3, 0.55, 0.65, "white_painted", 0.015)]
    join("conveyor_cover_white_painted", conveyor)
    join("conveyor_load_regolith", [sphere("r", (x, -0.5, 0.67), 0.05, "regolith", scale=(1, 1.4, 0.6), segments=10) for x in (-0.08, 0.06)])
    join("conveyor_legs_alloy", [rod("l", (x, -0.6, 0.18), (x, -0.6, 0.55), 0.025, "alloy", 10) for x in (-0.14, 0.14)])
    cyl("feed_pipe_alloy", (0, -0.9, 0.35), 0.1, 0.5, "alloy", axis="y", verts=24, bevel=0.01)
    torus("feed_pipe_flange_dark_alloy", (0, -0.68, 0.35), 0.11, 0.02, "dark_alloy", axis="y")
    cyl("feed_pipe_ground_collar_graphite", (0, -1.12, 0.12), 0.16, 0.24, "graphite", verts=24, bevel=0.01)
    # Motor housing, switch box and status lamp (the rig switches it on and off).
    box("motor_housing_slate_panel", 0.62, 0.95, -0.55, -0.1, 0.18, 0.62, "slate_panel", 0.02)
    vent("motor_vent_dark_alloy", 0.66, 0.91, 0.25, 0.5, -0.55 - 0.012, slats=4)
    box("switch_box_white_painted", -0.95, -0.7, -0.6, -0.4, 0.3, 0.6, "white_painted", 0.012)
    box("physical_switches_orange", -0.86, -0.79, -0.62, -0.6, 0.42, 0.5, "orange", 0.004)
    cyl("state_light_bright_green", (-0.82, -0.605, 0.55), 0.02, 0.012, "bright_green", axis="y", verts=16)
    box("intake_label_orange", -0.3, 0.3, 0.7, 0.704, 0.05, 0.14, "orange", 0)
    bolts("skid_bolts_satin_steel", [(x, 0.09) for x in (-0.8, -0.4, 0.0, 0.4, 0.8)], 0.7)


MODELS = [
    ("regolith_printer", regolith_printer, "floor"),
    ("regolith_intake", regolith_intake, "floor"),
]

# ---------- build, export, preview ----------

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials()
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 640
scene.render.resolution_y = 640
world = bpy.data.worlds.new("bg"); scene.world = world

for item_id, build, placement in MODELS:
    if ONLY and item_id not in ONLY: continue
    reset()
    build()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PARTS: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "models", item_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    tris = 0
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in PARTS:
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        tris += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    bounds = [[round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]]
    MANIFEST.append({"id": item_id, "file": item_id + ".glb", "placement": placement, "bounds_m": bounds, "triangles": tris,
                     "named_components": sorted({o.name.rsplit("_", 1)[0] for o in PARTS})})
    size = max(hi - lo)
    centre = (lo + hi) / 2
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; scene.camera = cam
    cam.data.lens = 50
    eye = centre + Vector((1.0, 1.4, 0.8)).normalized() * (size * 2.6 + 0.6)
    cam.location = eye
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "previews", item_id + ".png")
    bpy.ops.render.render(write_still=True)
    print("BUILT", item_id, bounds, "tris", tris)

manifest_path = os.path.join(OUT, "asset_manifest.json")
existing = []
if ONLY and os.path.exists(manifest_path):
    existing = [m for m in json.load(open(manifest_path))["assets"] if m["id"] not in ONLY]
with open(manifest_path, "w") as f:
    json.dump({"style": "Fabrication: regolith printer and intake (matches the Martian/Hail Mary packs)",
               "units": "metres; Y up; -Z forward; floor origin", "assets": existing + MANIFEST}, f, indent=2)
