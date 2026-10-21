"""Blender (5.x) build script: the crew lander where MARS: HABITAT begins.

Run:  blender --background --python build_lander.py -- <out_dir>
Writes <out_dir>/models/crew_lander.glb and previews/*.png.

Metres, origin on the ground under the cabin centre. The hatch faces -Z in
glTF (Blender +Y here). Mesh names are component_material; "-col" names make
Godot generate collision (the hull, floor, ramp and fittings), "-colonly" is
collision without a visual.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(os.path.join(OUT, "models"), exist_ok=True)
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)

COLORS = {
    "white_ceramic": ((0.88, 0.91, 0.90, 1), .05, .65),
    "white_painted": ((0.94, 0.95, 0.92, 1), .03, .57),
    "warm_panel": ((0.78, 0.82, 0.80, 1), .06, .62),
    "alloy": ((0.59, 0.67, 0.69, 1), .76, .38),
    "satin_steel": ((0.77, 0.81, 0.79, 1), .83, .27),
    "dark_alloy": ((0.28, 0.35, 0.38, 1), .66, .5),
    "scorched": ((0.13, 0.12, 0.12, 1), .45, .7),
    "black_rubber": ((0.10, 0.14, 0.16, 1), .03, .83),
    "thermal_gold": ((0.86, 0.66, 0.28, 1), .85, .32),
    "thermal_silver": ((0.80, 0.82, 0.84, 1), .9, .35),
    "teal": ((0.22, 0.47, 0.51, 1), .17, .45),
    "teal_soft": ((0.42, 0.63, 0.64, 1), .06, .69),
    "orange": ((0.84, 0.42, 0.18, 1), .20, .51),
    "cool_blue": ((0.20, 0.33, 0.52, 1), .3, .3),
    "black_glass": ((0.05, 0.07, 0.08, 1), .2, .15),
    "light_diffuser": ((0.99, 0.99, 0.86, 1), 0, .34),
    "glass": ((0.69, .86, .88, .3), 0, .1),
}

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
    if rgba[3] < 1:
        bsdf.inputs["Alpha"].default_value = rgba[3]
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    if name == "light_diffuser":
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 2.0
    m.diffuse_color = rgba
    m.metallic = metal
    m.roughness = rough
    MATS[name] = m

PARTS = []

def _active():
    return bpy.context.active_object

def _finish(obj, name, mat, bevel=0.0):
    obj.name = name
    obj.data.name = name
    if mat:
        obj.data.materials.clear()
        obj.data.materials.append(MATS[mat])
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    PARTS.append(obj)
    return obj

def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    obj = _active()
    obj.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat, bevel)

def cyl(name, centre, radius, length, mat, axis="z", verts=24, bevel=0.0, r2=None):
    rot = {"z": (0, 0, 0), "x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0)}[axis]
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=length, location=centre, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=r2, depth=length, location=centre, rotation=rot)
    obj = _active()
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat, bevel)

def strut(name, a, b, radius, mat, verts=12):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=(b - a).length, location=mid)
    obj = _active()
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return _finish(obj, name, mat)

def sphere(name, centre, radius, mat, scale=(1, 1, 1), segs=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=radius, location=centre)
    obj = _active()
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat)

def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)

def boolean(target, cutter, op="DIFFERENCE"):
    mod = target.modifiers.new("bool", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if cutter in PARTS: PARTS.remove(cutter)
    bpy.data.objects.remove(cutter, do_unlink=True)

def join(name, objs):
    for o in objs: apply_mods(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        PARTS.remove(o)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = _active()
    obj.name = name
    obj.data.name = name
    PARTS.append(obj)
    return obj

# ---------------- pressure hull (hollow capsule along X) ----------------
HC = 2.15          # hull centre height
R, RI = 1.75, 1.66  # outer / inner radius
HALF = 1.8          # half length of the cylinder section
FLOOR = 1.1         # cabin floor height
DOOR_Y = 1.86       # hatch hinge line (front, Blender +Y)

def capsule(name, radius, end_scale):
    body = cyl(name, (0, 0, HC), radius, HALF * 2, "white_ceramic", axis="x", verts=48)
    ends = [sphere(name + "_end", (sx * HALF, 0, HC), radius, "white_ceramic", scale=(end_scale, 1, 1), segs=48) for sx in (-1, 1)]
    for e in ends: boolean(body, e, "UNION")
    return body

hull = capsule("cabin_hull_white_ceramic", R, 0.52)
inner = capsule("inner", RI, 0.48)
boolean(hull, inner)
# Hatch opening and windows.
boolean(hull, box("cut", -0.62, 0.62, 0.6, 2.4, FLOOR, 3.05, None, 0))
for sx in (-1.35, 1.35):
    for sy in (1, -1):
        boolean(hull, cyl("cut", (sx, sy * 1.6, 2.7), 0.26, 1.0, None, axis="y", verts=24))
boolean(hull, cyl("cut", (2.5, 0, 2.6), 0.42, 1.2, None, axis="x", verts=32))   # forward window over the console
hull.name = "cabin_hull_white_ceramic-col"
# Weld the boolean seams (cylinder to end caps) so no hairline cracks let light through.
bpy.ops.object.select_all(action="DESELECT")
hull.select_set(True)
bpy.context.view_layer.objects.active = hull
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.004)
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
# Hull frames at the cylinder / end-cap joints, inside: structure, and they cover the seam.
rings = []
for sx in (-1, 1):
    ring = cyl("ring", (sx * HALF, 0, HC), RI + 0.01, 0.1, "dark_alloy", axis="x", verts=48)
    boolean(ring, cyl("cut", (sx * HALF, 0, HC), RI - 0.07, 0.4, None, axis="x", verts=48))
    boolean(ring, box("cut", -4, 4, -4, 4, -1, FLOOR, None, 0))   # stop at the floor
    rings.append(ring)
join("hull_frames_dark_alloy", rings)

# Thermal blanket bands and scorched belly (outside only).
bands = []
for x in (-1.0, 1.0):
    band = cyl("band", (x, 0, HC), R + 0.03, 0.22, "thermal_gold", axis="x", verts=48)
    boolean(band, cyl("cut", (x, 0, HC), R - 0.05, 0.5, None, axis="x", verts=48))
    bands.append(band)
join("thermal_blanket_thermal_gold", bands)
belly = cyl("belly", (0, 0, HC), R + 0.02, HALF * 2 + 0.6, "scorched", axis="x", verts=48)
boolean(belly, cyl("cut", (0, 0, HC), R - 0.06, HALF * 2 + 1.0, None, axis="x", verts=48))
boolean(belly, box("cut", -4, 4, -4, 4, HC - 0.9, 6, None, 0))
belly.name = "belly_heat_shield_scorched"

# ---------------- hatch: collar, sill and the door that becomes the ramp ----------------
collar = [box("c", -0.78, -0.62, 1.15, DOOR_Y, FLOOR - 0.05, 3.15, "dark_alloy"),
          box("c", 0.62, 0.78, 1.15, DOOR_Y, FLOOR - 0.05, 3.15, "dark_alloy"),
          box("c", -0.78, 0.78, 1.15, DOOR_Y, 3.05, 3.2, "dark_alloy")]
join("hatch_collar_dark_alloy", collar)
box("hatch_sill_satin_steel-col", -0.62, 0.62, 0.9, DOOR_Y, FLOOR - 0.1, FLOOR, "satin_steel", 0.005)
# Wider than the 1.24 m opening so it laps over the collar when shut: no light slits.
ramp = [box("r", -0.72, 0.72, DOOR_Y, DOOR_Y + 0.08, FLOOR - 0.04, FLOOR + 2.08, "white_painted", 0.01)]
treads = [box("t", -0.5, 0.5, DOOR_Y - 0.015, DOOR_Y, FLOOR + 0.15 + i * 0.22, FLOOR + 0.2 + i * 0.22, "dark_alloy", 0.003) for i in range(8)]
rails = [box("h", x - 0.03, x + 0.03, DOOR_Y + 0.08, DOOR_Y + 0.14, FLOOR + 0.1, FLOOR + 1.9, "orange", 0.01) for x in (-0.55, 0.55)]
window = [box("w", -0.2, 0.2, DOOR_Y + 0.08, DOOR_Y + 0.09, FLOOR + 1.45, FLOOR + 1.8, "black_glass", 0.005)]
join("hatch_ramp_white_painted-col", ramp)
join("hatch_ramp_treads_dark_alloy", treads)
join("hatch_ramp_rails_orange", rails)
join("hatch_ramp_window_black_glass", window)

# Window glass.
# Glass plugs fill each hole through the whole curved wall (the hull is
# 1.55-1.75 m from the axis across a side window's height).
panes = [cyl("g", (sx, sy * 1.62, 2.7), 0.27, 0.34, "glass", axis="y", verts=24) for sx in (-1.35, 1.35) for sy in (1, -1)]
panes.append(cyl("g", (2.5, 0, 2.6), 0.43, 0.5, "glass", axis="x", verts=32))
join("window_glass", panes)
# Frame collars, also through the wall, so the edge of every hole is covered.
frames = []
for sx in (-1.35, 1.35):
    for sy in (1, -1):
        f = cyl("f", (sx, sy * 1.64, 2.7), 0.34, 0.36, "dark_alloy", axis="y", verts=24)
        boolean(f, cyl("cut", (sx, sy * 1.64, 2.7), 0.255, 0.5, None, axis="y", verts=24))
        frames.append(f)
f = cyl("f", (2.52, 0, 2.6), 0.5, 0.5, "dark_alloy", axis="x", verts=32)
boolean(f, cyl("cut", (2.52, 0, 2.6), 0.415, 0.8, None, axis="x", verts=32))
frames.append(f)
join("window_frames_dark_alloy", frames)
# Keep the frame collars from showing inside the cabin: trim to the hull.
frame_obj = PARTS[-1]
boolean(frame_obj, capsule("trim_inner", RI - 0.01, 0.47))

# ---------------- cabin interior ----------------
cabin_floor = box("cabin_floor_warm_panel-col", -2.05, 2.05, -1.3, 1.3, FLOOR - 0.12, FLOOR, "warm_panel", 0.005)
apply_mods(cabin_floor)
boolean(cabin_floor, capsule("floor_trim", RI + 0.02, 0.49), "INTERSECT")   # corners stay inside the hull
grates = [box("gr", x - 0.02, x + 0.02, -1.0, 1.0, FLOOR, FLOOR + 0.005, "dark_alloy", 0) for x in [-1.6 + i * 0.4 for i in range(9)]]
join("floor_strips_dark_alloy", grates)
# Seats facing the forward window.
seat_parts, cushions = [], []
for y in (-0.75, 0.0, 0.75):
    seat_parts += [box("s", 1.05, 1.55, y - 0.25, y + 0.25, FLOOR, FLOOR + 0.45, "white_ceramic", 0.03),
                   box("s", 0.95, 1.08, y - 0.25, y + 0.25, FLOOR + 0.45, FLOOR + 1.35, "white_ceramic", 0.03)]
    cushions += [box("c", 1.08, 1.52, y - 0.22, y + 0.22, FLOOR + 0.45, FLOOR + 0.52, "teal_soft", 0.02),
                 box("c", 1.08, 1.12, y - 0.22, y + 0.22, FLOOR + 0.55, FLOOR + 1.3, "teal_soft", 0.01)]
join("crew_seats_white_ceramic-col", seat_parts)
join("crew_seats_cushions_teal_soft", cushions)
box("main_console_white_painted-col", 1.75, 2.15, -0.9, 0.9, FLOOR, FLOOR + 0.95, "white_painted", 0.02)
box("console_screen_black_glass", 1.74, 1.76, -0.75, 0.75, FLOOR + 0.5, FLOOR + 0.9, "black_glass", 0.004)
buttons = [box("b", 1.6, 1.75, y - 0.06, y + 0.06, FLOOR + 0.95, FLOOR + 0.98, "orange" if i % 2 else "teal", 0.004) for i, y in enumerate([-0.6, -0.3, 0.3, 0.6])]
join("console_controls_orange", buttons)
# Lockers along the back wall.
lockers = [box("l", x - 0.3, x + 0.3, -1.3, -0.95, FLOOR, FLOOR + 1.55, "white_painted", 0.015) for x in (-1.4, -0.7, 0.0, 0.7)]
join("storage_lockers_white_painted-col", lockers)
handles = [box("h", x - 0.02, x + 0.02, -0.95, -0.92, FLOOR + 0.6, FLOOR + 0.95, "satin_steel", 0.005) for x in (-1.2, -0.5, 0.2, 0.9)]
join("storage_lockers_handles_satin_steel", handles)
# Suit station at the back end: a suit hung on its frame.
box("suit_station_frame_dark_alloy-col", -2.15, -1.95, -0.5, 0.5, FLOOR, FLOOR + 2.1, "dark_alloy", 0.01)
suit = [sphere("su", (-1.82, 0, FLOOR + 1.3), 0.3, "white_ceramic", scale=(0.6, 1, 1.25)),
        sphere("su", (-1.8, 0, FLOOR + 1.85), 0.19, "white_ceramic"),
        strut("su", (-1.82, -0.18, FLOOR + 1.0), (-1.82, -0.2, FLOOR + 0.15), 0.08, "white_ceramic"),
        strut("su", (-1.82, 0.18, FLOOR + 1.0), (-1.82, 0.2, FLOOR + 0.15), 0.08, "white_ceramic"),
        strut("su", (-1.82, -0.36, FLOOR + 1.55), (-1.8, -0.42, FLOOR + 0.95), 0.06, "white_ceramic"),
        strut("su", (-1.82, 0.36, FLOOR + 1.55), (-1.8, 0.42, FLOOR + 0.95), 0.06, "white_ceramic")]
join("eva_suit_white_ceramic", suit)
sphere("eva_suit_visor_thermal_gold", (-1.66, 0, FLOOR + 1.86), 0.12, "thermal_gold", scale=(0.5, 1, 0.8))
box("eva_suit_pack_orange", -2.0, -1.92, -0.2, 0.2, FLOOR + 1.1, FLOOR + 1.6, "orange", 0.02)
# Ceiling lights, cable runs and handholds.
lights = [box("cl", -1.6, 1.4, y - 0.12, y + 0.12, 3.62, 3.66, "light_diffuser", 0.005) for y in (-0.45, 0.45)]
join("cabin_lights_light_diffuser", lights)
cables = [box("cr", -1.9, 1.9, y - 0.04, y + 0.04, 3.5, 3.58, "dark_alloy", 0.01) for y in (-1.0, 1.0)]
join("cable_runs_dark_alloy", cables)
holds = [strut("hh", (x - 0.25, 1.15, 2.9), (x + 0.25, 1.15, 2.9), 0.025, "orange") for x in (-1.4, 1.4)]
holds += [strut("hh", (x - 0.25, -1.15, 2.9), (x + 0.25, -1.15, 2.9), 0.025, "orange") for x in (-1.4, 1.4)]
join("handholds_orange", holds)

# ---------------- landing legs ----------------
legs, pads, dampers = [], [], []
for sx in (-1, 1):
    for sy in (-1, 1):
        top = (sx * 1.5, sy * 1.25, 1.35)
        foot = (sx * 3.4, sy * 3.0, 0.16)
        knee = (sx * 2.6, sy * 2.2, 0.75)
        legs += [strut("lg", top, knee, 0.07, "alloy"), strut("lg", (sx * 1.0, sy * 1.45, 0.8), knee, 0.05, "alloy")]
        dampers.append(strut("dm", knee, foot, 0.1, "dark_alloy"))
        pads.append(cyl("pd", foot, 0.42, 0.1, "scorched", verts=24, r2=0.3))
join("landing_legs_alloy", legs)
join("landing_dampers_dark_alloy", dampers)
join("footpads_scorched", pads)

# ---------------- engines, tanks, antenna, solar wing ----------------
pods, bells, rcs = [], [], []
for sx in (-1, 1):
    pods.append(cyl("pod", (sx * 2.85, 0, 1.25), 0.5, 1.1, "white_ceramic", verts=32, r2=0.36))
    pods.append(cyl("pod", (sx * 2.85, 0, 0.66), 0.5, 0.12, "white_ceramic", verts=32))
    pods.append(strut("pod", (sx * 2.3, 0, 1.6), (sx * 2.6, 0, 1.5), 0.12, "dark_alloy"))
    bells.append(cyl("bell", (sx * 2.85, 0, 0.36), 0.44, 0.5, "scorched", verts=32, r2=0.24))
    bells.append(cyl("bell", (sx * 2.85, 0, 0.64), 0.3, 0.08, "dark_alloy", verts=32))
    for sy in (-1, 1):
        rcs.append(box("rcs", sx * 2.85 - 0.08, sx * 2.85 + 0.08, sy * 0.5, sy * 0.5 + sy * 0.12, 1.55, 1.7, "dark_alloy", 0.01))
join("engine_pods_white_ceramic", pods)
join("engine_bells_scorched", bells)
join("rcs_thrusters_dark_alloy", rcs)
tanks = [sphere("tk", (x, -1.55, 0.72), 0.52, "thermal_silver") for x in (-1.15, 1.15)]
join("propellant_tanks_thermal_silver", tanks)
strut("antenna_mast_satin_steel", (-1.2, -0.7, 3.8), (-1.2, -0.7, 4.6), 0.04, "satin_steel")
sphere("antenna_dish_white_painted", (-1.2, -0.7, 4.65), 0.38, "white_painted", scale=(1, 1, 0.25))
box("solar_wing_frame_dark_alloy", -0.1, 1.9, -1.15, -0.25, 3.82, 3.9, "dark_alloy", 0.01)
box("solar_wing_cells_cool_blue", -0.05, 1.85, -1.1, -0.3, 3.9, 3.98, "cool_blue", 0.005)

# ---------------- hull hardware ----------------
seams = []
for x in (-1.6, -0.35, 0.35, 1.6):
    seam = cyl("sm", (x, 0, HC), R + 0.012, 0.035, "dark_alloy", axis="x", verts=48)
    boolean(seam, cyl("cut", (x, 0, HC), R - 0.05, 0.2, None, axis="x", verts=48))
    boolean(seam, box("cut", -0.7, 0.7, 0.8, 2.5, FLOOR - 0.2, 3.3, None, 0))
    seams.append(seam)
join("hull_seams_dark_alloy", seams)
radiators = []
for x in (-1.0, 0.2, 1.0):
    radiators.append(box("rd", x - 0.32, x + 0.32, -R - 0.18, -R + 0.05, 2.0, 3.1, "thermal_silver", 0.01))
    for i in range(6):
        radiators.append(box("rd", x - 0.3, x + 0.3, -R - 0.2, -R - 0.17, 2.05 + i * 0.18, 2.1 + i * 0.18, "dark_alloy", 0))
join("radiator_panels_thermal_silver", radiators)
quads = []
for sx in (-1, 1):
    for sy in (-1, 1):
        cx, cy, cz = sx * 1.75, sy * 1.05, 3.45
        quads.append(box("q", cx - 0.12, cx + 0.12, cy - 0.12, cy + 0.12, cz - 0.1, cz + 0.1, "dark_alloy", 0.01))
        for d in ((1, 0, 0), (0, 1, 0), (0, 0, 1)):
            quads.append(cyl("q", (cx + d[0] * sx * 0.15, cy + d[1] * sy * 0.15, cz + d[2] * 0.15), 0.04, 0.1, "scorched", axis="xyz"[d.index(1)], verts=10, r2=0.025))
join("hull_thrusters_dark_alloy", quads)
stripes = [box("hz", x - 0.05, x + 0.05, DOOR_Y - 0.02, DOOR_Y + 0.005, FLOOR - 0.05, FLOOR + 0.02, "orange", 0) for x in [-0.55 + i * 0.22 for i in range(6)]]
stripes += [box("hz", -0.86, -0.8, 1.2, 1.8, 1.4 + i * 0.4, 1.6 + i * 0.4, "orange", 0) for i in range(4)]
stripes += [box("hz", 0.8, 0.86, 1.2, 1.8, 1.4 + i * 0.4, 1.6 + i * 0.4, "orange", 0) for i in range(4)]
join("hatch_markings_orange", stripes)
box("hatch_light_light_diffuser", -0.25, 0.25, 1.6, DOOR_Y + 0.02, 3.2, 3.27, "light_diffuser", 0.01)

# Smooth shading on curved parts (sharp edges kept by angle).
for obj in PARTS:
    if any(key in obj.name for key in ("hull", "belly", "engine", "propellant", "antenna_dish", "eva_suit", "thermal_blanket", "footpads", "landing_dampers", "landing_legs", "window_frames")):
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        apply_mods(obj)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# ---------------- export ----------------
for obj in PARTS: apply_mods(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in PARTS: obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "models", "crew_lander.glb"), export_format="GLB", use_selection=True, export_apply=True)
lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
tris = 0
for obj in PARTS:
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, world)); hi = Vector(map(max, hi, world))
    obj.data.calc_loop_triangles()
    tris += len(obj.data.loop_triangles)
bounds = [[round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]]
with open(os.path.join(OUT, "bounds.txt"), "w") as f: f.write(repr(bounds))
print("BOUNDS", bounds, "PARTS", len(PARTS), "TRIS", tris)

# ---------------- previews ----------------
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 750
world = bpy.data.worlds.new("bg"); scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.2, 0.14, 1)
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = _active()
gm = bpy.data.materials.new("ground"); gm.diffuse_color = (0.55, 0.32, 0.2, 1); ground.data.materials.append(gm)
bpy.ops.object.camera_add()
cam = _active(); scene.camera = cam

def shoot(name, location, target, lens=35):
    cam.data.lens = lens
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "previews", name + ".png")
    bpy.ops.render.render(write_still=True)

shoot("lander_three_quarter", (8.5, 10.5, 4.5), (0, 0, 1.8))
shoot("lander_side", (-12, 2, 3), (0, 0, 1.8))
# Ramp down: rotate the hatch door about its hinge (bottom edge).
hinge = Vector((0, DOOR_Y, FLOOR))
for obj in PARTS:
    if obj.name.startswith("hatch_ramp"):
        obj.data.transform(Matrix.Translation(-hinge))
        obj.location = hinge
        obj.rotation_euler = (math.radians(-123), 0, 0)
shoot("lander_ramp_down", (4.5, 9.5, 2.6), (0, 1.5, 1.6))
shoot("lander_interior_to_window", (-1.5, 0.3, 2.75), (2.2, 0, 2.2), lens=18)
shoot("lander_interior_to_hatch", (0.2, -0.9, 2.75), (0, 3.5, 1.6), lens=18)
