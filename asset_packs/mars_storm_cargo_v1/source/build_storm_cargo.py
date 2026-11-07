"""Blender (5.x) build script: the storm's cargo, for the revamp's first
20 minutes (docs/systems-and-items.md §14 step 2).

Run:  blender --background --python build_storm_cargo.py -- <out_dir>
Writes <out_dir>/<id>.glb for each model, and <id>.png previews.

House style (docs/house-style.md): white shells, graphite frames, satin metal,
rubber, one orange accent per item, small status lights. No lettering
anywhere. Parts are named component_material so MHPalette maps them.

Blender is Z-up; glTF (the game) is Y-up: Blender (x, y, z) is the game's
(x, z, -y). Every model sits on its origin at ground level unless noted.

Models:
  parachute        the canopy lying deflated, 14 m across, with its lines
                   running 13 m to -Y (the game's +Z) where the backshell
                   lies. Heights are offsets above the ground: the game
                   drapes every vertex onto the terrain (storm_drop.gd).
  backshell        the conical back cover the chute came out of, 3.2 m.
  pallet           a cargo pallet's body: frame, shell, corner fittings and
                   four latch keepers. Its lid is a separate model.
  pallet_lid       the lid, hinged along its -Y edge (the game's +Z), with
                   four latch handles (the accent).
  o2_cartridge     a 20 kg oxygen cartridge: shell, end caps, carry handle,
                   valve, one orange band.
  cabin_o2_port    the cabin wall's oxygen port: a back plate, the dial (a
                   white face with tick marks; the needle is its own part,
                   dial_needle_orange, turned by the game about its pivot at
                   the dial's centre), and the cradle and socket the
                   cartridge docks in. Wall items face -Y (the game's +Z).
  debris_lid       a crate lid torn off in the storm.
  debris_strap     a length of cargo strap with its buckle.
  debris_foam      a block of packing foam.
  debris_strip     a torn strip of canopy fabric.
"""
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


# ---------- the parachute ----------

def parachute():
    random.seed(7)
    radius = 7.0
    bm = bmesh.new()
    rings_n, sectors = 44, 112
    rings = (0.28, 0.36, 0.62, 0.70, 0.86, 0.92)   # orange bands between pairs
    grid = []
    crown = bm.verts.new((0, 0, 0.16))
    for ri in range(1, rings_n + 1):
        t = ri / rings_n
        row = []
        for si in range(sectors):
            a = si / sectors * math.tau
            edge = radius * (1.0 + 0.12 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, 0.3))) + 0.06 * math.sin(a * 5))
            r = edge * t
            x, y = math.cos(a) * r, math.sin(a) * r
            # Deflated cloth: low folds radiating from the crown, a wind-held
            # billow along the +X side, flat at the hem.
            folds = 0.10 * (0.5 + 0.5 * math.sin(a * 14 + r * 0.6)) * (1 - t) ** 0.4
            crinkle = 0.06 * noise.noise(Vector((x * 0.9, y * 0.9, 1.7)))
            billow = 0.9 * max(0.0, math.cos(a)) ** 3 * math.sin(math.pi * min(1.0, t * 1.1)) * (0.7 + 0.3 * noise.noise(Vector((x * 0.3, y * 0.3, 4.0))))
            z = 0.04 + max(0.0, folds + crinkle) + billow * (1 - t * 0.35)
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    def band(t):
        return 1 if any(rings[k] <= t < rings[k + 1] for k in range(0, len(rings), 2)) else 0
    for si in range(sectors):
        f = bm.faces.new([crown, grid[0][si], grid[0][(si + 1) % sectors]])
        f.material_index = 0
    for ri in range(rings_n - 1):
        t = (ri + 1.5) / rings_n
        for si in range(sectors):
            n = (si + 1) % sectors
            f = bm.faces.new([grid[ri][si], grid[ri + 1][si], grid[ri + 1][n], grid[ri][n]])
            f.material_index = band(t)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("canopy_fabric")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("canopy_fabric", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATS["canopy_fabric"])
    obj.data.materials.append(MATS["canopy_band_orange"])
    smooth(obj)
    solid = obj.modifiers.new("thick", "SOLIDIFY")
    solid.thickness = 0.015
    # The suspension lines: from the hem on the -Y side, gathering into a
    # riser that runs to the backshell 13 m away.
    gather = Vector((0.0, -radius - 4.5, 0.06))
    end = Vector((0.4, -13.0, 0.08))
    for k in range(18):
        a = -math.pi / 2 + (k - 8.5) / 8.5 * 1.1
        hem = Vector((math.cos(a) * radius * 0.97, math.sin(a) * radius * 0.97, 0.05))
        mid = hem.lerp(gather, 0.5) + Vector((random.uniform(-0.4, 0.4), random.uniform(-0.3, 0.3), 0.03))
        tube("suspension_line_cord_fabric", "line_cord_fabric", [hem, mid, gather + Vector((random.uniform(-.05, .05), 0, 0))], 0.008, 4)
    tube("riser_strap_orange", "strap_orange", [gather, gather.lerp(end, 0.5) + Vector((0.5, 0, 0.02)), end], 0.025, 4)


# ---------- the backshell ----------

def backshell():
    # A truncated cone lying tipped on its side, open base towards +X.
    d_base, d_top, h = 3.2, 1.1, 1.9
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=d_base / 2, radius2=d_top / 2, depth=h, location=(0, 0, 0), end_fill_type="NGON")
    cone = bpy.context.active_object
    cone.name = "backshell_shell_white"
    cone.data.materials.append(MATS["shell_white"])
    smooth(cone)
    parts = [cone]
    # The open base: a dark recess just inside the rim.
    parts.append(cylinder("inner_recess_graphite", "recess_graphite", d_base / 2 - 0.08, 0.02, (0, 0, -h / 2 - 0.005), vertices=48))
    parts.append(torus("base_ring_frame_dark_alloy", "frame_dark_alloy", d_base / 2, 0.05, (0, 0, -h / 2)))
    parts.append(cylinder("chute_cone_trim_steel", "trim_steel", d_top / 2 - 0.05, 0.25, (0, 0, h / 2 + 0.12), vertices=32))
    parts.append(cylinder("mortar_cap_recess_graphite", "recess_graphite", d_top / 2 - 0.15, 0.06, (0, 0, h / 2 + 0.27), vertices=32))
    # Tile seams round the cone, as low ribs.
    for k in range(12):
        a = k / 12 * math.tau
        p0 = Vector((math.cos(a) * d_base / 2 * 0.999, math.sin(a) * d_base / 2 * 0.999, -h / 2 + 0.05))
        p1 = Vector((math.cos(a) * d_top / 2 * 0.999, math.sin(a) * d_top / 2 * 0.999, h / 2 - 0.02))
        parts.append(tube("seam_recess_graphite", "recess_graphite", [p0, p1], 0.006, 4))
    # Four bolts where the heat shield let go.
    for k in range(4):
        a = k / 4 * math.tau + .4
        parts.append(cylinder("fitting_trim_steel", "trim_steel", 0.06, 0.12, (math.cos(a) * (d_base / 2 - .08), math.sin(a) * (d_base / 2 - .08), -h / 2 - .02), vertices=12))
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = cone
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = "backshell_shell_white"
    # Tip it over onto its side, resting on the ground.
    obj.rotation_euler = (0, math.radians(78), math.radians(15))
    bpy.ops.object.transform_apply(rotation=True)
    low = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    obj.location.z -= low + 0.25   # sunk a little into the dust
    bpy.ops.object.transform_apply(location=True)


# ---------- the pallet ----------

PW, PD, PH = 1.6, 1.2, 0.95       # pallet body: x, y, z (m)


def pallet():
    # A flat aluminium base with fork pockets, a white shell on a graphite
    # frame, corner fittings and four latch keepers on the long sides.
    box("pallet_base_frame_dark_alloy", "frame_dark_alloy", (PW + .08, PD + .08, 0.14), (0, 0, 0.07), 0.015)
    for x in (-0.45, 0.45):
        box("fork_pocket_recess_graphite", "recess_graphite", (0.3, PD + .1, 0.07), (x, 0, 0.06), 0.008)
    # An open-topped shell: four walls and a floor, so what's packed inside
    # shows once the lid is up.
    wall, wh = 0.04, PH - 0.16
    zc = 0.14 + wh / 2
    box("pallet_body_shell_white", "shell_white", (PW, wall, wh), (0, PD / 2 - wall / 2, zc), 0.012)
    box("pallet_body_shell_white", "shell_white", (PW, wall, wh), (0, -PD / 2 + wall / 2, zc), 0.012)
    box("pallet_body_shell_white", "shell_white", (wall, PD - 2 * wall, wh), (PW / 2 - wall / 2, 0, zc), 0.012)
    box("pallet_body_shell_white", "shell_white", (wall, PD - 2 * wall, wh), (-PW / 2 + wall / 2, 0, zc), 0.012)
    box("inner_floor_recess_graphite", "recess_graphite", (PW - 2 * wall, PD - 2 * wall, 0.03), (0, 0, 0.155), 0.0)
    # Packing inside: foam blocks round a cradle, and two strapped bags.
    # Two foam cradles, cut to hold the cartridge high across them (the game
    # sets it at 0.5 m, towards the front), and filler at the ends.
    for x in (-0.3, 0.3):
        box("cradle_foam_ivory", "foam_ivory", (0.16, PD - 0.12, 0.36), (x, 0, 0.35), 0.015)
    box("packing_foam_ivory", "foam_ivory", (0.22, PD - 0.1, 0.22), (-0.66, 0, 0.28), 0.015)
    box("packing_foam_ivory", "foam_ivory", (0.22, PD - 0.1, 0.22), (0.66, 0, 0.28), 0.015)
    box("kit_bag_seal_rubber", "seal_rubber", (0.42, 0.34, 0.2), (-0.2, 0.3, 0.27), 0.04)
    box("kit_bag_seal_rubber", "seal_rubber", (0.36, 0.3, 0.16), (0.24, 0.32, 0.25), 0.04)
    box("bag_strap_frame_dark_alloy", "frame_dark_alloy", (0.05, 0.36, 0.205), (-0.2, 0.3, 0.27), 0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("corner_post_frame_dark_alloy", "frame_dark_alloy", (0.07, 0.07, PH - 0.12), (sx * (PW / 2), sy * (PD / 2), 0.14 + (PH - .12) / 2), 0.01)
            box("corner_fitting_trim_steel", "trim_steel", (0.11, 0.11, 0.08), (sx * (PW / 2), sy * (PD / 2), 0.12), 0.01)
    # Ribs and a seam round the shell.
    for x in (-0.4, 0.0, 0.4):
        for sy in (-1, 1):
            box("rib_shell_white", "shell_white", (0.05, 0.02, PH - 0.3), (x, sy * (PD / 2 + 0.01), 0.14 + (PH - .16) / 2), 0.006)
    for sy in (-1, 1):
        box("seam_seal_rubber", "seal_rubber", (PW - 0.06, 0.012, 0.02), (0, sy * (PD / 2 + 0.006), PH - 0.04), 0.004)
        for x in (-0.55, 0.55):
            box("latch_keeper_trim_steel", "trim_steel", (0.1, 0.035, 0.07), (x, sy * (PD / 2 + 0.02), PH - 0.1), 0.008)
    # Lifting eyes on top corners, a blank ID plate, the status light.
    for sx in (-1, 1):
        torus("lift_eye_trim_steel", "trim_steel", 0.035, 0.01, (sx * (PW / 2 - .06), PD / 2 - .06, PH + 0.02), (math.radians(90), 0, 0))
    box("id_plate_trim_steel", "trim_steel", (0.22, 0.008, 0.12), (-0.2, -PD / 2 - 0.01, 0.45), 0.004)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=(0.25, -PD / 2 - 0.012, 0.5))
    led = bpy.context.active_object
    led.name = "beacon_status_green_light"
    led.data.materials.append(MATS["status_green_light"])


def pallet_lid():
    # Hinged along its -Y edge: the origin is on the hinge line.
    t = 0.07
    box("lid_panel_shell_white", "shell_white", (PW + 0.02, PD + 0.02, t), (0, PD / 2, t / 2), 0.018)
    box("lid_rim_frame_dark_alloy", "frame_dark_alloy", (PW + 0.05, 0.04, t + 0.02), (0, 0.0, t / 2), 0.008)
    box("lid_rim_frame_dark_alloy", "frame_dark_alloy", (PW + 0.05, 0.04, t + 0.02), (0, PD, t / 2), 0.008)
    for x in (-0.5, 0.0, 0.5):
        box("lid_rib_shell_white", "shell_white", (0.06, PD - 0.1, 0.025), (x, PD / 2, t + 0.012), 0.008)
    for x in (-0.6, 0.6):
        cylinder("hinge_trim_steel", "trim_steel", 0.025, 0.2, (x, -0.01, t / 2), (0, math.radians(90), 0), 12)
    # The four latch handles that hold it shut: the one accent.
    for x in (-0.55, 0.55):
        for y in (0.0, PD):
            sy = -1 if y == 0.0 else 1
            box("latch_handle_orange", "handle_orange", (0.09, 0.03, 0.14), (x, y + sy * 0.035, -0.02), 0.01)
            cylinder("latch_pin_trim_steel", "trim_steel", 0.012, 0.11, (x, y + sy * 0.02, 0.03), (0, math.radians(90), 0), 10)


# ---------- the oxygen cartridge ----------

def o2_cartridge():
    # Lying along X, 0.72 m long and 0.24 m across, on the ground.
    r, length = 0.12, 0.72
    z = r + 0.005
    cylinder("cartridge_body_white", "body_white", r, length - 0.08, (0, 0, z), (0, math.radians(90), 0), 32, 0.01)
    for sx in (-1, 1):
        cylinder("end_cap_recess_graphite", "recess_graphite", r + 0.006, 0.06, (sx * (length / 2 - 0.03), 0, z), (0, math.radians(90), 0), 32, 0.008)
        cylinder("bumper_seal_rubber", "seal_rubber", r + 0.012, 0.025, (sx * (length / 2 - 0.075), 0, z), (0, math.radians(90), 0), 32)
    cylinder("band_orange", "handle_orange", r + 0.004, 0.05, (0.12, 0, z), (0, math.radians(90), 0), 32)
    # The valve and its quick-connect on the +X end.
    cylinder("valve_body_trim_steel", "trim_steel", 0.035, 0.07, (length / 2 + 0.03, 0, z), (0, math.radians(90), 0), 16)
    cylinder("quick_connect_trim_steel", "trim_steel", 0.05, 0.03, (length / 2 + 0.075, 0, z), (0, math.radians(90), 0), 16)
    torus("valve_guard_frame_dark_alloy", "frame_dark_alloy", 0.06, 0.008, (length / 2 + 0.04, 0, z), (0, math.radians(90), 0))
    # A carry handle along the top.
    for sx in (-0.16, 0.16):
        box("handle_post_frame_dark_alloy", "frame_dark_alloy", (0.025, 0.03, 0.05), (sx, 0, z + r + 0.02), 0.005)
    box("carry_grip_seal_rubber", "seal_rubber", (0.36, 0.035, 0.03), (0, 0, z + r + 0.055), 0.012)
    box("id_plate_trim_steel", "trim_steel", (0.12, 0.004, 0.06), (-0.12, -r - 0.002, z), 0.002)


# ---------- the cabin's oxygen port ----------

def cabin_o2_port():
    # A wall item facing -Y (the game's +Z), 0.6 m wide, centred on the
    # origin at its back plate. The dial is at (0.14, 0.32 up); the cradle
    # below holds a cartridge lying along X.
    box("back_plate_recess_graphite", "recess_graphite", (0.62, 0.02, 0.62), (0, 0, 0.12), 0.01)
    box("panel_shell_white", "shell_white", (0.56, 0.03, 0.56), (0, -0.025, 0.12), 0.012)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cylinder("bolt_trim_steel", "trim_steel", 0.012, 0.012, (sx * 0.25, -0.045, 0.12 + sz * 0.25), (math.radians(90), 0, 0), 10)
    # The dial: a bezel, a white face, tick marks round 270 degrees, and the needle.
    dx, dz = 0.14, 0.27
    cylinder("dial_bezel_frame_dark_alloy", "frame_dark_alloy", 0.085, 0.025, (dx, -0.05, dz), (math.radians(90), 0, 0), 40, 0.004)
    cylinder("dial_face_ceramic", "dial_face_ceramic", 0.072, 0.006, (dx, -0.064, dz), (math.radians(90), 0, 0), 40)
    for k in range(11):
        a = math.radians(225 - k * 27)
        long_tick = k % 5 == 0
        length = 0.016 if long_tick else 0.009
        rr = 0.062 - length / 2
        box("dial_tick_recess_graphite", "recess_graphite", (0.003 if not long_tick else 0.0045, 0.002, length),
            (dx + math.cos(a) * rr, -0.068, dz + math.sin(a) * rr), 0, rotation=(0, -(a - math.pi / 2), 0))
    # A green arc for "full" and an amber one for "low" as small blocks.
    for k, mat in ((0, "seal_rubber"), (10, "status_green_light")):
        a = math.radians(225 - k * 27)
        box("dial_zone_" + mat, mat, (0.008, 0.002, 0.008), (dx + math.cos(a) * 0.045, -0.068, dz + math.sin(a) * 0.045), 0)
    # The needle: pivot at the dial centre, pointing straight up (rotate about Y).
    bpy.ops.object.empty_add(location=(dx, -0.072, dz))
    pivot = bpy.context.active_object
    pivot.name = "dial_needle_pivot"
    needle = box("dial_needle_orange", "handle_orange", (0.005, 0.003, 0.055), (dx, -0.072, dz + 0.022), 0)
    cap = cylinder("needle_cap_recess_graphite", "recess_graphite", 0.008, 0.006, (dx, -0.074, dz), (math.radians(90), 0, 0), 16)
    needle.parent = pivot
    needle.matrix_parent_inverse = pivot.matrix_world.inverted()
    # The supply light beside the dial.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.01, location=(-0.05, -0.05, 0.33))
    led = bpy.context.active_object
    led.name = "supply_status_green_light"
    led.data.materials.append(MATS["status_green_light"])
    # The socket: a steel ring the cartridge's quick-connect pushes into.
    cylinder("socket_ring_trim_steel", "trim_steel", 0.06, 0.05, (0.31, -0.18, -0.02), (0, math.radians(90), 0), 24)
    cylinder("socket_seal_rubber", "seal_rubber", 0.045, 0.055, (0.31, -0.18, -0.02), (0, math.radians(90), 0), 24)
    box("socket_arm_frame_dark_alloy", "frame_dark_alloy", (0.05, 0.16, 0.05), (0.31, -0.1, -0.02), 0.008)
    # The cradle: two curved arms under where the cartridge lies.
    for x in (-0.22, 0.12):
        box("cradle_arm_frame_dark_alloy", "frame_dark_alloy", (0.04, 0.2, 0.03), (x, -0.13, -0.15), 0.008)
        box("cradle_pad_seal_rubber", "seal_rubber", (0.05, 0.08, 0.015), (x, -0.18, -0.13), 0.005)


# ---------- debris ----------

def debris_lid():
    box("lid_panel_shell_white", "shell_white", (1.1, 0.75, 0.05), (0, 0, 0.03), 0.012, rotation=(math.radians(6), math.radians(-4), 0))
    box("lid_rim_frame_dark_alloy", "frame_dark_alloy", (1.12, 0.04, 0.06), (0, 0.37, 0.05), 0.006, rotation=(math.radians(6), math.radians(-4), 0))
    box("lid_rib_shell_white", "shell_white", (0.05, 0.68, 0.02), (0.3, 0, 0.065), 0.006, rotation=(math.radians(6), math.radians(-4), 0))
    box("latch_handle_orange", "handle_orange", (0.08, 0.03, 0.12), (-0.48, -0.39, 0.03), 0.008, rotation=(math.radians(80), 0, 0))
    box("torn_bracket_trim_steel", "trim_steel", (0.12, 0.03, 0.04), (0.5, -0.36, 0.04), 0.005, rotation=(0, 0, math.radians(30)))


def debris_strap():
    random.seed(3)
    pts = [Vector((-1.1 + i * 0.18, 0.25 * math.sin(i * 0.9) + random.uniform(-.03, .03), 0.012)) for i in range(13)]
    obj = tube("strap_webbing_strap_orange", "strap_orange", pts, 0.022, 4)
    obj.scale = (1, 1, 0.25)
    bpy.ops.object.transform_apply(scale=True)
    box("buckle_trim_steel", "trim_steel", (0.07, 0.06, 0.015), (pts[-1].x + 0.03, pts[-1].y, 0.01), 0.005)
    box("hook_frame_dark_alloy", "frame_dark_alloy", (0.06, 0.04, 0.02), (pts[0].x - 0.04, pts[0].y, 0.012), 0.006)


def debris_foam():
    box("packing_foam_ivory", "foam_ivory", (0.55, 0.38, 0.22), (0, 0, 0.1), 0.02, rotation=(0, math.radians(8), math.radians(20)))
    box("cut_recess_foam_ivory", "foam_ivory", (0.3, 0.2, 0.05), (0.05, 0, 0.21), 0.01, rotation=(0, math.radians(8), math.radians(20)))


def debris_strip():
    bm = bmesh.new()
    rows = []
    for i in range(16):
        x = -1.2 + i * 0.16
        w = 0.22 + 0.06 * math.sin(i * 1.3)
        z = 0.02 + 0.05 * max(0, math.sin(i * 0.8))
        twist = math.sin(i * 0.45) * 0.4
        rows.append((bm.verts.new((x, -w / 2, z + twist * w / 2 * 0.3)), bm.verts.new((x, w / 2, z - twist * w / 2 * 0.3))))
    for i in range(len(rows) - 1):
        f = bm.faces.new([rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1]])
        f.material_index = 1 if 5 <= i <= 7 else 0
    mesh = bpy.data.meshes.new("strip_canopy_fabric")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("strip_canopy_fabric", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATS["canopy_fabric"])
    obj.data.materials.append(MATS["canopy_band_orange"])
    obj.modifiers.new("thick", "SOLIDIFY").thickness = 0.01
    smooth(obj)


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


MODELS = {
    "parachute": (parachute, 22.0),
    "backshell": (backshell, 6.0),
    "pallet": (pallet, 3.5),
    "pallet_lid": (pallet_lid, 3.0),
    "o2_cartridge": (o2_cartridge, 1.4),
    "cabin_o2_port": (cabin_o2_port, 1.2),
    "debris_lid": (debris_lid, 2.2),
    "debris_strap": (debris_strap, 2.6),
    "debris_foam": (debris_foam, 1.4),
    "debris_strip": (debris_strip, 2.6),
}


def main():
    for model_id, (build, distance) in MODELS.items():
        if ONLY and model_id not in ONLY: continue
        clear()
        build()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects: obj.select_set(obj.type in ("MESH", "EMPTY"))
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, model_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
        tris = 0
        deps = bpy.context.evaluated_depsgraph_get()
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH": continue
            mesh = obj.evaluated_get(deps).to_mesh()
            mesh.calc_loop_triangles()
            tris += len(mesh.loop_triangles)
        print("%s: %d triangles" % (model_id, tris))
        preview(os.path.join(OUT, model_id + ".png"), distance)


main()
