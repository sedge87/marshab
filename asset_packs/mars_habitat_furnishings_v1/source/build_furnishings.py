"""Blender (5.x) build script: Habitat Furnishings pack for MARS: HABITAT (v2).

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
    "red_cross": ((0.80, 0.18, 0.16, 1), .05, .5),
    "pouch_silver": ((0.74, 0.76, 0.78, 1), .6, .32),
    "screen_cyan": ((0.35, 0.85, 0.95, 1), .0, .3),
    "screen_green": ((0.35, 0.95, 0.55, 1), .0, .3),
    "iv_clear": ((0.86, 0.92, 0.95, 1), .0, .2),
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


# ---------- models ----------

def galley_table_set():
    """A table for four with padded chairs, for the galley."""
    box("table_top_white_painted", -0.8, 0.8, -0.45, 0.45, 0.70, 0.74, "white_painted", 0.02)
    box("table_edge_alloy", -0.79, 0.79, -0.44, 0.44, 0.68, 0.70, "alloy", 0.006)
    legs = []
    for x in (-0.68, 0.68):
        legs.append(box("l", x - 0.035, x + 0.035, -0.06, 0.06, 0.04, 0.68, "dark_alloy", 0.012))
        legs.append(box("l", x - 0.04, x + 0.04, -0.38, 0.38, 0.0, 0.05, "dark_alloy", 0.015))
        legs += [cyl("f", (x, y, 0.008), 0.03, 0.016, "black_rubber", verts=20) for y in (-0.34, 0.34)]
    legs.append(box("l", -0.68, 0.68, -0.025, 0.025, 0.32, 0.37, "dark_alloy", 0.01))
    join("table_frame_dark_alloy", legs)
    trims, seats, backs, frames, feet = [], [], [], [], []
    for x in (-0.4, 0.4):
        for side in (-1, 1):
            y = side * 0.72
            seats.append(cushion("s", x - 0.21, x + 0.21, y - 0.2, y + 0.2, 0.43, 0.5))
            trims.append(box("t", x - 0.22, x + 0.22, y - 0.21, y + 0.21, 0.41, 0.44, "warm_shell", 0.01))
            by = y + side * 0.19
            backs.append(cushion("b", x - 0.2, x + 0.2, by - 0.025, by + 0.025, 0.6, 0.86))
            for lx in (x - 0.18, x + 0.18):
                for ly in (y - 0.17, y + 0.17):
                    frames.append(rod("f", (lx, ly, 0.02), (lx, ly, 0.41), 0.013, "satin_steel", 12))
                    feet.append(cyl("fe", (lx, ly, 0.01), 0.018, 0.02, "black_rubber", verts=12))
                frames.append(rod("f", (lx, by, 0.44), (lx, by, 0.62), 0.011, "satin_steel", 12))
            frames.append(rod("f", (x - 0.18, y - 0.17, 0.18), (x - 0.18, y + 0.17, 0.18), 0.009, "satin_steel", 10))
            frames.append(rod("f", (x + 0.18, y - 0.17, 0.18), (x + 0.18, y + 0.17, 0.18), 0.009, "satin_steel", 10))
    join("chair_seats_teal_soft", seats)
    join("chair_backs_teal_soft", backs)
    join("chair_seat_shells_warm_shell", trims)
    join("chair_frames_satin_steel", frames)
    join("chair_feet_black_rubber", feet)


def galley_oven():
    """A compact convection oven with an induction hob on top."""
    cabinet("oven", -0.3, 0.3, -0.3, 0.3, 0.0, 0.92, "white_painted", "warm_shell")
    box("hob_dark_glass", -0.28, 0.28, -0.27, 0.25, 0.92, 0.93, "dark_glass", 0.006)
    join("hob_rings_slate_panel", [torus("r", (x, -0.03, 0.932), 0.085, 0.004, "slate_panel") for x in (-0.13, 0.13)])
    box("hob_indicator_amber", 0.18, 0.24, 0.17, 0.2, 0.931, 0.934, "amber", 0)
    box("oven_door_slate_panel", -0.27, 0.27, 0.3, 0.33, 0.12, 0.62, "slate_panel", 0.012)
    box("oven_window_dark_glass", -0.2, 0.2, 0.33, 0.336, 0.22, 0.52, "dark_glass", 0.006)
    handle("oven_handle_satin_steel", -0.2, 0.2, 0.575, 0.33)
    gasket("oven_seal_black_rubber", -0.275, 0.275, 0.115, 0.625, 0.296)
    box("control_panel_graphite", -0.27, 0.27, 0.3, 0.315, 0.68, 0.86, "graphite", 0.008)
    knobs = []
    for x in (-0.17, -0.08):
        knobs.append(cyl("k", (x, 0.325, 0.77), 0.028, 0.03, "satin_steel", axis="y", verts=24, bevel=0.004))
        knobs.append(box("k", x - 0.003, x + 0.003, 0.34, 0.343, 0.775, 0.795, "orange", 0))
    join("knobs_satin_steel", knobs)
    box("display_screen_cyan", 0.03, 0.22, 0.316, 0.32, 0.74, 0.8, "screen_cyan", 0)
    vent("oven_vent_dark_alloy", -0.24, 0.24, 0.07, 0.11, 0.3, slats=3)
    box("side_label_orange", 0.301, 0.305, -0.1, 0.1, 0.8, 0.84, "orange", 0)


def galley_rehydration_station():
    """Hot and cold water for freeze-dried pouches, with a pouch rack."""
    cabinet("station", -0.26, 0.26, -0.22, 0.22, 0.0, 1.05, "warm_shell", "white_painted")
    box("recess_graphite", -0.18, 0.18, 0.17, 0.226, 0.42, 0.78, "graphite", 0.012)
    gasket("recess_trim_black_rubber", -0.19, 0.19, 0.41, 0.79, 0.222, w=0.01)
    for x, mat in ((-0.06, "orange"), (0.06, "cool_blue")):
        rod(f"nozzle_{'hot' if x < 0 else 'cold'}_satin_steel", (x, 0.18, 0.76), (x, 0.18, 0.66), 0.013, "satin_steel")
        box(f"nozzle_tag_{'hot' if x < 0 else 'cold'}_{mat}", x - 0.02, x + 0.02, 0.2, 0.205, 0.74, 0.755, mat, 0)
    box("drip_tray_satin_steel", -0.16, 0.16, 0.1, 0.25, 0.42, 0.445, "satin_steel", 0.006)
    join("drip_grate_dark_alloy", [box("g", -0.15 + i * 0.03, -0.14 + i * 0.03, 0.11, 0.24, 0.445, 0.45, "dark_alloy", 0) for i in range(10)])
    box("control_panel_slate_panel", -0.22, 0.22, 0.22, 0.235, 0.84, 0.98, "slate_panel", 0.006)
    box("display_screen_cyan", -0.16, 0.0, 0.236, 0.24, 0.88, 0.95, "screen_cyan", 0)
    cyl("button_hot_orange", (0.15, 0.24, 0.91), 0.017, 0.014, "orange", axis="y", verts=20, bevel=0.003)
    cyl("button_cold_cool_blue", (0.08, 0.24, 0.91), 0.017, 0.014, "cool_blue", axis="y", verts=20, bevel=0.003)
    cyl("hot_tank_satin_steel", (0, -0.04, 1.2), 0.16, 0.28, "satin_steel", verts=40, bevel=0.02)
    join("hot_tank_bands_orange", [torus("b", (0, -0.04, z), 0.162, 0.008, "orange") for z in (1.1, 1.3)])
    rod("hot_pipe_satin_steel", (0.1, -0.04, 1.06), (0.1, 0.12, 1.06), 0.012, "satin_steel")
    box("pouch_rack_dark_alloy", 0.26, 0.3, -0.2, 0.2, 0.18, 0.92, "dark_alloy", 0.006)
    join("pouch_shelves_alloy", [box("p", 0.29, 0.36, -0.19, 0.19, z, z + 0.012, "alloy", 0.003) for z in (0.26, 0.44, 0.62)])
    pouches, labels = [], []
    for z in (0.272, 0.452, 0.632):
        for i, y in enumerate((-0.13, -0.045, 0.04, 0.125)):
            pouches.append(box("p", 0.3, 0.33, y - 0.035, y + 0.035, z, z + 0.15, "pouch_silver", 0.008))
            labels.append(box("l", 0.331, 0.334, y - 0.02, y + 0.02, z + 0.08, z + 0.11, "orange", 0))
    join("food_pouches_pouch_silver", pouches)
    join("pouch_labels_orange", labels)


def galley_freezer():
    """Fridge over freezer: food storage for months of meals."""
    cabinet("cabinet", -0.36, 0.36, -0.34, 0.34, 0.0, 1.86, "white_painted", "warm_shell")
    box("fridge_door_white_painted", -0.35, 0.35, 0.34, 0.385, 0.88, 1.8, "white_painted", 0.018)
    box("freezer_door_cool_blue", -0.35, 0.35, 0.34, 0.385, 0.1, 0.85, "cool_blue", 0.018)
    box("fridge_door_handle_satin_steel", 0.25, 0.29, 0.385, 0.43, 1.0, 1.42, "satin_steel", 0.012)
    box("freezer_door_handle_satin_steel", 0.25, 0.29, 0.385, 0.43, 0.46, 0.8, "satin_steel", 0.012)
    box("fridge_door_frame_graphite", -0.28, -0.04, 0.385, 0.388, 1.6, 1.74, "graphite", 0.003)
    box("fridge_door_screen_cyan", -0.26, -0.06, 0.388, 0.391, 1.62, 1.72, "screen_cyan", 0)
    box("freezer_door_label_white_painted", -0.25, -0.05, 0.386, 0.389, 0.72, 0.78, "white_painted", 0)
    gasket("door_seals_black_rubber", -0.355, 0.355, 0.855, 0.875, 0.338, w=0.01)
    vent("base_vent_dark_alloy", -0.3, 0.3, 0.0, 0.07, 0.33, slats=3)
    join("hinges_alloy", [box("h", -0.37, -0.35, 0.36, 0.39, z, z + 0.06, "alloy", 0.005) for z in (0.15, 0.75, 0.95, 1.7)])


def waste_sorting_unit():
    """Three chutes over a compactor: sort, squash and seal waste."""
    cabinet("unit", -0.8, 0.8, -0.34, 0.34, 0.0, 1.0, "slate_panel", "warm_shell")
    for name, mat, x in (("plastics", "cool_blue", -0.5), ("metals", "orange", 0.0), ("organics", "bright_green", 0.5)):
        cyl(f"chute_{name}_{mat}", (x, -0.02, 1.07), 0.2, 0.14, mat, verts=40, bevel=0.012, radius2=0.17)
        cyl(f"chute_rim_{name}_alloy", (x, -0.02, 1.145), 0.175, 0.02, "alloy", verts=40, bevel=0.005)
        cyl(f"chute_lid_{name}_graphite", (x - 0.02, -0.02, 1.16), 0.16, 0.02, "graphite", verts=40, bevel=0.006)
        box(f"label_{name}_{mat}", x - 0.18, x + 0.18, 0.34, 0.346, 0.86, 0.94, mat, 0.004)
        box(f"label_mark_{name}_white_painted", x - 0.05, x + 0.05, 0.346, 0.349, 0.88, 0.92, "white_painted", 0)
    box("compactor_door_warm_panel", -0.74, 0.2, 0.34, 0.375, 0.1, 0.78, "warm_panel", 0.015)
    box("compactor_window_dark_glass", -0.5, -0.04, 0.375, 0.38, 0.42, 0.66, "dark_glass", 0.006)
    handle("compactor_handle_satin_steel", -0.68, -0.56, 0.35, 0.375)
    gasket("compactor_seal_black_rubber", -0.745, 0.205, 0.095, 0.785, 0.336)
    box("control_panel_graphite", 0.28, 0.74, 0.34, 0.36, 0.48, 0.8, "graphite", 0.008)
    box("display_screen_cyan", 0.34, 0.68, 0.36, 0.364, 0.62, 0.74, "screen_cyan", 0)
    cyl("status_lamp_bright_green", (0.52, 0.365, 0.55), 0.02, 0.016, "bright_green", axis="y", verts=20)
    vent("unit_vent_dark_alloy", 0.3, 0.72, 0.1, 0.4, 0.34, slats=6)
    bolts("panel_bolts_satin_steel", [(x, z) for x in (-0.76, 0.76) for z in (0.14, 0.92)], 0.34)


def hopper(material):
    """A funnel hopper on a frame over a wheeled bin."""
    def build():
        f = cyl(f"funnel_{material}", (0, 0, 0.99), 0.44, 0.42, material, verts=4, radius2=0.12, bevel=0.01)
        f.rotation_euler = (0, 0, math.pi / 4)
        bpy.ops.object.select_all(action="DESELECT"); f.select_set(True)
        bpy.context.view_layer.objects.active = f
        bpy.ops.object.transform_apply(rotation=True)
        box("rim_alloy", -0.33, 0.33, -0.33, 0.33, 1.19, 1.23, "alloy", 0.01)
        box(f"lid_{material}", -0.32, 0.0, -0.32, 0.32, 1.23, 1.25, material, 0.01)
        box("lid_hinge_dark_alloy", -0.02, 0.02, -0.3, 0.3, 1.22, 1.26, "dark_alloy", 0.006)
        rod("lid_handle_satin_steel", (-0.28, -0.1, 1.27), (-0.28, 0.1, 1.27), 0.01, "satin_steel")
        legs = [box("l", x - 0.022, x + 0.022, y - 0.022, y + 0.022, 0.0, 1.2, "dark_alloy", 0.008) for x in (-0.3, 0.3) for y in (-0.3, 0.3)]
        legs += [box("l", -0.3, 0.3, y - 0.015, y + 0.015, 0.68, 0.72, "dark_alloy", 0.006) for y in (-0.3, 0.3)]
        legs += [box("l", x - 0.015, x + 0.015, -0.3, 0.3, 0.68, 0.72, "dark_alloy", 0.006) for x in (-0.3, 0.3)]
        legs += [cyl("f", (x, y, 0.008), 0.035, 0.016, "black_rubber", verts=16) for x in (-0.3, 0.3) for y in (-0.3, 0.3)]
        join("frame_dark_alloy", legs)
        box("bin_warm_panel", -0.24, 0.24, -0.24, 0.24, 0.06, 0.62, "warm_panel", 0.025)
        box("bin_rim_graphite", -0.25, 0.25, -0.25, 0.25, 0.6, 0.63, "graphite", 0.01)
        join("bin_wheels_black_rubber", [cyl("w", (x, y, 0.03), 0.028, 0.022, "black_rubber", axis="x", verts=16) for x in (-0.18, 0.18) for y in (-0.18, 0.18)])
        box(f"bin_label_{material}", -0.16, 0.16, 0.24, 0.246, 0.38, 0.5, material, 0.004)
        box("bin_label_mark_white_painted", -0.05, 0.05, 0.246, 0.249, 0.41, 0.47, "white_painted", 0)
        handle("bin_handle_satin_steel", -0.1, 0.1, 0.54, 0.24)
        box(f"frame_band_{material}", -0.335, 0.335, 0.31, 0.335, 1.0, 1.04, material, 0.004)
    return build


def iv_drip_stand():
    """A five-wheel IV pole with two bags and an infusion pump."""
    join("base_dark_alloy", star_base(0.11, 0.3))
    cyl("pole_satin_steel", (0, 0, 1.05), 0.015, 1.88, "satin_steel", verts=20)
    cyl("pole_collar_dark_alloy", (0, 0, 0.9), 0.024, 0.05, "dark_alloy", verts=20, bevel=0.004)
    hooks = []
    for x in (-0.16, 0.16):
        hooks.append(rod("h", (0, 0, 1.97), (x, 0, 1.99), 0.008, "satin_steel"))
        hooks.append(torus("h", (x, 0, 1.965), 0.02, 0.004, "satin_steel", axis="y"))
    join("hooks_satin_steel", hooks)
    for side, x in (("l", -0.15), ("r", 0.15)):
        box(f"iv_bag_{side}_iv_clear", x - 0.07, x + 0.07, -0.025, 0.025, 1.62, 1.92, "iv_clear", 0.02)
        box(f"iv_bag_label_{side}_white_painted", x - 0.04, x + 0.04, 0.025, 0.027, 1.72, 1.8, "white_painted", 0)
        cyl(f"iv_drip_chamber_{side}_iv_clear", (x, 0, 1.57), 0.012, 0.06, "iv_clear", verts=12)
    lines = [rod("t", (x, 0, 1.54), (0.04, 0.09, 1.3), 0.004, "iv_clear", 8) for x in (-0.15, 0.15)]
    lines.append(rod("t", (0.04, 0.09, 1.14), (0.12, 0.25, 0.85), 0.004, "iv_clear", 8))
    join("iv_lines_iv_clear", lines)
    box("pump_white_painted", -0.1, 0.1, 0.0, 0.12, 1.1, 1.33, "white_painted", 0.015)
    box("pump_clamp_dark_alloy", -0.035, 0.035, -0.03, 0.02, 1.16, 1.27, "dark_alloy", 0.006)
    box("pump_bezel_graphite", -0.08, 0.08, 0.12, 0.123, 1.2, 1.3, "graphite", 0.003)
    box("pump_screen_screen_cyan", -0.07, 0.07, 0.123, 0.126, 1.215, 1.29, "screen_cyan", 0)
    join("pump_keys_slate_panel", [box("k", x - 0.012, x + 0.012, 0.12, 0.128, 1.13, 1.16, "slate_panel", 0.003) for x in (-0.05, -0.017, 0.017)])
    cyl("pump_lamp_bright_green", (0.06, 0.124, 1.145), 0.012, 0.008, "bright_green", axis="y", verts=12)


def crew_vitals_monitor():
    """A wall screen showing each crew member's heart rate, oxygen and temperature."""
    box("bracket_dark_alloy", -0.15, 0.15, -0.06, 0.0, -0.12, 0.12, "dark_alloy", 0.01)
    box("bezel_graphite", -0.47, 0.47, 0.0, 0.045, -0.29, 0.29, "graphite", 0.015)
    box("screen_dark_glass", -0.44, 0.44, 0.045, 0.05, -0.26, 0.26, "dark_glass", 0.004)
    for mat, z in (("screen_green", 0.17), ("screen_cyan", 0.04), ("amber", -0.09)):
        segs = []
        x = -0.38
        for i in range(12):
            h = 0.04 if i % 4 == 2 else (0.02 if i % 4 == 1 else 0.008)
            segs.append(box("t", x, x + 0.042, 0.051, 0.054, z - h, z + h, mat, 0))
            x += 0.046
        join(f"trace_{mat}", segs)
    join("readouts_screen_cyan", [box("r", 0.2, 0.4, 0.051, 0.054, z - 0.025, z + 0.025, "screen_cyan", 0) for z in (0.17, 0.04, -0.09)])
    box("footer_bar_screen_cyan", -0.4, 0.4, 0.051, 0.053, -0.22, -0.2, "screen_cyan", 0)
    cyl("power_lamp_bright_green", (0.43, 0.047, -0.275), 0.006, 0.004, "bright_green", axis="y", verts=12)


def surgery_cart():
    """A three-tier cart with drawers and an instrument tray."""
    for z in (0.12, 0.5):
        box(f"shelf_{int(z * 100)}_white_painted", -0.36, 0.36, -0.26, 0.26, z, z + 0.03, "white_painted", 0.01)
        box(f"shelf_lip_{int(z * 100)}_alloy", -0.36, 0.36, 0.25, 0.27, z + 0.02, z + 0.05, "alloy", 0.004)
    box("drawer_unit_white_painted", -0.36, 0.36, -0.26, 0.26, 0.55, 0.9, "white_painted", 0.012)
    join("drawer_fronts_warm_panel", [box("d", -0.33, 0.33, 0.26, 0.275, z0, z0 + 0.1, "warm_panel", 0.008) for z0 in (0.565, 0.675, 0.785)])
    for i, z0 in enumerate((0.565, 0.675, 0.785)):
        handle(f"drawer_pull_{i}_satin_steel", -0.08, 0.08, z0 + 0.05, 0.275)
        box(f"drawer_tag_{i}_teal", 0.18, 0.28, 0.275, 0.278, z0 + 0.035, z0 + 0.065, "teal", 0)
    box("tray_satin_steel", -0.36, 0.36, -0.26, 0.26, 0.9, 0.92, "satin_steel", 0.006)
    lips = [box("l", -0.36, 0.36, y - 0.008, y + 0.008, 0.92, 0.95, "satin_steel", 0.003) for y in (-0.26, 0.26)]
    lips += [box("l", x - 0.008, x + 0.008, -0.26, 0.26, 0.92, 0.95, "satin_steel", 0.003) for x in (-0.36, 0.36)]
    join("tray_lips_satin_steel", lips)
    tools = [rod("t", (x, -0.14, 0.93), (x + 0.03, 0.1, 0.93), 0.007, "satin_steel", 10) for x in (-0.24, -0.17, -0.1, -0.03)]
    tools.append(cyl("t", (0.2, -0.12, 0.935), 0.03, 0.02, "satin_steel", verts=20))
    join("instruments_satin_steel", tools)
    box("instrument_pack_teal_soft", 0.06, 0.3, -0.06, 0.18, 0.92, 0.955, "teal_soft", 0.012)
    join("posts_dark_alloy", [box("p", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0.1, 0.92, "dark_alloy", 0.006) for x in (-0.34, 0.34) for y in (-0.24, 0.24)])
    wheels = []
    for x in (-0.3, 0.3):
        for y in (-0.2, 0.2):
            wheels += caster(x, y)
    join("casters_black_rubber", wheels)
    handle("push_handle_satin_steel", -0.3, 0.3, 0.88, -0.32)
    join("handle_supports_satin_steel", [box("s", x - 0.012, x + 0.012, -0.32, -0.25, 0.86, 0.9, "satin_steel", 0.004) for x in (-0.28, 0.28)])
    join("red_cross_red_cross", [box("c", -0.07, 0.07, 0.29, 0.296, 0.33, 0.37, "red_cross", 0), box("c", -0.02, 0.02, 0.29, 0.296, 0.28, 0.42, "red_cross", 0)])
    box("sharps_box_amber", -0.34, -0.2, -0.24, -0.1, 0.53, 0.66, "amber", 0.01)


def medical_exam_light():
    """A bright examination lamp on a wheeled stand with a jointed arm."""
    join("base_dark_alloy", star_base(0.11, 0.28))
    cyl("pole_satin_steel", (0, 0, 0.78), 0.022, 1.3, "satin_steel", verts=20)
    cyl("pole_collar_dark_alloy", (0, 0, 0.5), 0.032, 0.06, "dark_alloy", verts=20, bevel=0.005)
    sphere("joint_dark_alloy", (0, 0, 1.44), 0.038, "dark_alloy")
    rod("arm_satin_steel", (0, 0, 1.44), (0, 0.45, 1.64), 0.017, "satin_steel")
    rod("arm_spring_dark_alloy", (0, 0.03, 1.47), (0, 0.4, 1.63), 0.006, "dark_alloy", 8)
    sphere("elbow_dark_alloy", (0, 0.45, 1.64), 0.032, "dark_alloy")
    rod("lamp_neck_dark_alloy", (0, 0.45, 1.64), (0, 0.5, 1.6), 0.015, "dark_alloy")
    cyl("lamp_head_white_painted", (0, 0.5, 1.56), 0.21, 0.09, "white_painted", verts=48, bevel=0.02)
    torus("lamp_rim_alloy", (0, 0.5, 1.515), 0.2, 0.01, "alloy")
    cyl("lamp_face_lamp_white", (0, 0.5, 1.512), 0.17, 0.006, "lamp_white", verts=48)
    join("lamp_leds_white_painted", [cyl("l", (0.1 * math.cos(a), 0.5 + 0.1 * math.sin(a), 1.507), 0.022, 0.004, "white_painted", verts=12) for a in [i * math.pi / 3 for i in range(6)]])
    rod("lamp_handle_dark_alloy", (0.21, 0.5, 1.56), (0.32, 0.5, 1.56), 0.013, "dark_alloy")


def work_desk():
    """A crew work desk with a drawer pedestal, laptop, mug and cable tray."""
    box("desk_top_warm_panel", -0.6, 0.6, -0.3, 0.3, 0.72, 0.75, "warm_panel", 0.012)
    box("desk_edge_alloy", -0.6, 0.6, 0.29, 0.305, 0.715, 0.75, "alloy", 0.004)
    cabinet("pedestal", 0.2, 0.58, -0.28, 0.28, 0.0, 0.72, "white_painted", "warm_shell")
    for i, z0 in enumerate((0.09, 0.3, 0.5)):
        box(f"drawer_{i}_slate_panel", 0.22, 0.56, 0.28, 0.292, z0, z0 + 0.18, "slate_panel", 0.008)
        handle(f"drawer_pull_{i}_satin_steel", 0.32, 0.46, z0 + 0.15, 0.292)
    legs = [box("l", -0.58, -0.54, y - 0.025, y + 0.025, 0.0, 0.72, "dark_alloy", 0.008) for y in (-0.26, 0.26)]
    legs.append(box("l", -0.58, -0.54, -0.26, 0.26, 0.04, 0.08, "dark_alloy", 0.008))
    legs.append(box("l", -0.54, 0.2, -0.28, -0.25, 0.62, 0.68, "dark_alloy", 0.006))
    join("legs_dark_alloy", legs)
    box("cable_tray_graphite", -0.5, 0.15, -0.28, -0.2, 0.64, 0.66, "graphite", 0.004)
    box("laptop_base_slate_panel", -0.36, 0.0, -0.06, 0.2, 0.75, 0.766, "slate_panel", 0.006)
    join("laptop_keys_graphite", [box("k", -0.33 + i * 0.03, -0.31 + i * 0.03, 0.02, 0.15, 0.766, 0.768, "graphite", 0) for i in range(10)])
    box("laptop_lid_slate_panel", -0.36, 0.0, -0.075, -0.06, 0.766, 0.99, "slate_panel", 0.006)
    box("laptop_display_screen_cyan", -0.34, -0.02, -0.059, -0.056, 0.78, 0.97, "screen_cyan", 0)
    cyl("mug_orange", (0.1, 0.12, 0.8), 0.04, 0.1, "orange", verts=24, bevel=0.004)
    torus("mug_handle_orange", (0.145, 0.12, 0.8), 0.025, 0.007, "orange", axis="y")
    box("notepad_white_painted", -0.55, -0.4, 0.05, 0.24, 0.75, 0.756, "white_painted", 0.003)
    rod("pen_teal", (-0.52, 0.2, 0.758), (-0.42, 0.22, 0.758), 0.005, "teal", 8)


def crew_chair():
    """A swivel work chair with castors, padded seat and arm rests."""
    join("base_dark_alloy", star_base(0.11, 0.3))
    cyl("column_satin_steel", (0, 0, 0.29), 0.03, 0.34, "satin_steel", verts=20)
    cyl("column_boot_graphite", (0, 0, 0.2), 0.036, 0.14, "graphite", verts=20)
    box("seat_pan_dark_alloy", -0.2, 0.2, -0.2, 0.2, 0.44, 0.46, "dark_alloy", 0.01)
    cushion("seat_teal_soft", -0.24, 0.24, -0.22, 0.25, 0.46, 0.53)
    cushion("back_teal_soft", -0.22, 0.22, -0.29, -0.22, 0.62, 1.0)
    box("back_shell_warm_shell", -0.21, 0.21, -0.31, -0.28, 0.64, 0.98, "warm_shell", 0.015)
    rod("back_post_dark_alloy", (0, -0.27, 0.46), (0, -0.3, 0.66), 0.022, "dark_alloy")
    arms = [cushion("a", x - 0.03, x + 0.03, -0.14, 0.16, 0.66, 0.69, "graphite") for x in (-0.27, 0.27)]
    arms += [rod("a", (x, 0.0, 0.47), (x, 0.0, 0.66), 0.012, "dark_alloy") for x in (-0.27, 0.27)]
    arms += [rod("a", (x * 0.75, 0.0, 0.465), (x, 0.0, 0.465), 0.011, "dark_alloy") for x in (-0.27, 0.27)]
    join("arm_rests_dark_alloy", arms)
    rod("height_lever_orange", (0.18, 0.05, 0.43), (0.28, 0.08, 0.42), 0.007, "orange", 8)


def open_shelving():
    """Open shelving with labelled storage tubs."""
    join("uprights_dark_alloy", [box("p", x - 0.022, x + 0.022, y - 0.022, y + 0.022, 0.0, 1.8, "dark_alloy", 0.006) for x in (-0.5, 0.5) for y in (-0.19, 0.19)])
    join("upright_slots_graphite", [box("h", x - 0.006, x + 0.006, 0.212, 0.214, 0.15 + i * 0.1, 0.17 + i * 0.1, "graphite", 0) for x in (-0.5, 0.5) for i in range(16)])
    braces = [rod("x", (x, -0.19, 0.1), (x, 0.19, 1.7), 0.006, "alloy", 8) for x in (-0.5, 0.5)]
    braces.append(rod("x", (-0.5, -0.19, 0.1), (0.5, -0.19, 1.7), 0.006, "alloy", 8))
    join("cross_braces_alloy", braces)
    join("shelves_alloy", [box("s", -0.5, 0.5, -0.2, 0.2, z, z + 0.025, "alloy", 0.006) for z in (0.08, 0.5, 0.92, 1.34, 1.76)])
    join("shelf_lips_alloy", [box("l", -0.5, 0.5, 0.195, 0.21, z + 0.02, z + 0.05, "alloy", 0.003) for z in (0.08, 0.5, 0.92, 1.34)])
    tubs = {"cool_blue": [], "orange": [], "warm_panel": [], "teal_soft": []}
    lids, labels = [], []
    layout = [(0.105, [("cool_blue", -0.25), ("cool_blue", 0.2)]), (0.525, [("warm_panel", -0.28), ("orange", 0.05), ("warm_panel", 0.32)]),
              (0.945, [("teal_soft", -0.22), ("teal_soft", 0.22)]), (1.365, [("orange", -0.3), ("warm_panel", 0.0), ("cool_blue", 0.3)])]
    for z, items in layout:
        for mat, x in items:
            tubs[mat].append(box("t", x - 0.13, x + 0.13, -0.16, 0.16, z, z + 0.2, mat, 0.015))
            lids.append(box("l", x - 0.135, x + 0.135, -0.165, 0.165, z + 0.2, z + 0.225, "graphite", 0.008))
            labels.append(box("l", x - 0.06, x + 0.06, 0.16, 0.163, z + 0.08, z + 0.13, "white_painted", 0))
    for mat, objs in tubs.items():
        if objs: join(f"storage_tubs_{mat}", objs)
    join("tub_lids_graphite", lids)
    join("tub_labels_white_painted", labels)
    join("feet_black_rubber", [cyl("f", (x, y, 0.006), 0.03, 0.012, "black_rubber", verts=16) for x in (-0.5, 0.5) for y in (-0.19, 0.19)])


def plant_pot():
    """A potted plant: a little green, good for morale."""
    cyl("pot_white_painted", (0, 0, 0.21), 0.2, 0.42, "white_painted", verts=48, bevel=0.015, radius2=0.24)
    torus("pot_rim_white_painted", (0, 0, 0.42), 0.235, 0.012, "white_painted")
    cyl("pot_band_teal", (0, 0, 0.33), 0.233, 0.03, "teal", verts=48)
    cyl("pot_foot_graphite", (0, 0, 0.012), 0.19, 0.024, "graphite", verts=48, bevel=0.005)
    cyl("soil_soil", (0, 0, 0.405), 0.215, 0.02, "soil", verts=48)
    join("pebbles_warm_panel", [sphere("p", (0.15 * math.cos(a), 0.15 * math.sin(a), 0.415), 0.018, "warm_panel", segments=10) for a in [i * 0.9 for i in range(7)]])
    stems, dark, light = [], [], []
    clusters = [(0, 0, 0.8, 0.2), (0.16, 0.06, 0.68, 0.15), (-0.15, 0.08, 0.7, 0.15), (0.04, -0.16, 0.68, 0.15),
                (-0.08, -0.1, 0.94, 0.14), (0.1, 0.12, 0.92, 0.13), (0.2, -0.1, 0.82, 0.12), (-0.2, -0.04, 0.86, 0.12),
                (0.02, 0.18, 0.78, 0.12), (-0.12, 0.17, 0.9, 0.11)]
    for i, (x, y, z, r) in enumerate(clusters):
        stems.append(rod("stem", (x * 0.3, y * 0.3, 0.41), (x, y, z - r * 0.5), 0.01, "leaf_green", 8))
        (dark if i % 2 == 0 else light).append(sphere("leaf", (x, y, z), r, "leaf_green" if i % 2 == 0 else "leaf_light", scale=(1.0, 1.0, 0.75), segments=16))
    join("plant_stems_leaf_green", stems)
    join("plant_leaves_leaf_green", dark)
    join("plant_leaves_leaf_light", light)


def wall_whiteboard():
    """A wall whiteboard for plans, with marker tray and mission patch."""
    box("frame_alloy", -0.62, 0.62, 0.0, 0.03, -0.42, 0.42, "alloy", 0.01)
    box("board_white_painted", -0.59, 0.59, 0.03, 0.035, -0.39, 0.39, "white_painted", 0)
    bolts("corner_caps_graphite", [(x, z) for x in (-0.6, 0.6) for z in (-0.4, 0.4)], 0.03, "graphite", r=0.015)
    join("writing_slate_panel", [box("w", -0.52, x, 0.035, 0.037, z, z + 0.01, "slate_panel", 0) for x, z in ((-0.05, 0.28), (0.12, 0.21), (-0.2, 0.14), (0.05, 0.02), (-0.15, -0.05), (-0.25, -0.12))])
    join("ticks_orange", [box("t", -0.55, -0.535, 0.035, 0.037, z, z + 0.015, "orange", 0) for z in (0.28, 0.21, 0.14)])
    box("diagram_cool_blue", 0.2, 0.52, 0.035, 0.037, -0.06, 0.3, "cool_blue", 0)
    box("diagram_inner_white_painted", 0.22, 0.5, 0.037, 0.039, -0.04, 0.28, "white_painted", 0)
    join("diagram_rooms_teal", [box("r", x0, x1, 0.039, 0.041, z0, z1, "teal", 0) for x0, x1, z0, z1 in ((0.24, 0.34, 0.16, 0.26), (0.36, 0.48, 0.16, 0.26), (0.3, 0.42, 0.0, 0.12))])
    box("marker_tray_alloy", -0.42, 0.42, 0.03, 0.095, -0.45, -0.42, "alloy", 0.006)
    join("markers_cool_blue", [cyl("m", (x, 0.065, -0.405), 0.011, 0.13, m, axis="x", verts=12) for x, m in ((-0.25, "red_cross"), (-0.08, "cool_blue"), (0.1, "graphite"))])
    box("eraser_graphite", 0.22, 0.34, 0.04, 0.09, -0.42, -0.39, "graphite", 0.008)
    cyl("mission_patch_orange", (0.45, 0.037, -0.27), 0.07, 0.004, "orange", axis="y", verts=32)
    cyl("mission_patch_inner_graphite", (0.45, 0.039, -0.27), 0.05, 0.004, "graphite", axis="y", verts=32)


MODELS = [
    ("galley_table_set", galley_table_set, "floor"),
    ("galley_oven", galley_oven, "floor"),
    ("galley_rehydration_station", galley_rehydration_station, "floor"),
    ("galley_freezer", galley_freezer, "floor"),
    ("waste_sorting_unit", waste_sorting_unit, "floor"),
    ("recycling_hopper_plastics", hopper("cool_blue"), "floor"),
    ("recycling_hopper_metals", hopper("orange"), "floor"),
    ("compost_hopper", hopper("bright_green"), "floor"),
    ("iv_drip_stand", iv_drip_stand, "floor"),
    ("crew_vitals_monitor", crew_vitals_monitor, "wall"),
    ("surgery_cart", surgery_cart, "floor"),
    ("medical_exam_light", medical_exam_light, "floor"),
    ("work_desk", work_desk, "floor"),
    ("crew_chair", crew_chair, "floor"),
    ("open_shelving", open_shelving, "floor"),
    ("plant_pot", plant_pot, "floor"),
    ("wall_whiteboard", wall_whiteboard, "wall"),
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
    json.dump({"style": "Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)",
               "units": "metres; Y up; -Z forward; floor origin", "assets": existing + MANIFEST}, f, indent=2)
