"""Blender (5.x) build script: the crew rover for OUTPOST ONE: MARS (v1).

Run:  blender --background --python build_crew_rover.py -- <out_dir>
Writes <out_dir>/models/crew_rover.glb, previews/crew_rover.png and
asset_manifest.json.

A small pressurised rover in the house style (docs/house-style.md), after
NASA's Space Exploration Vehicle and the Lunar Terrain Vehicle studies:
a white cab with a wrap-round windscreen and two suitports at the back, an
open cargo deck behind, six wheels on trailing arms, a light bar, a roof solar
panel, a mast and one orange stripe. 4.2 m long, 2.3 m wide, 2.36 m tall, so
it fits through a vehicle bay's hangar door (2.58 m).

Wheels are separate nodes named wheel_<fl|fr|ml|mr|rl|rr> with their origin
at the hub, so the game can spin and steer them; the headlights' lenses are
lamp_white (they glow) and the game adds its own lights.

Metres, ground origin at the middle of the wheelbase, front faces -Z in glTF
(Blender +Y here). Shares the furnishings pack's helpers and materials.
"""
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({
    "solar_cell": ((0.08, 0.13, 0.22, 1), 0.55, 0.25),
    "tread_rubber": ((0.07, 0.08, 0.09, 1), 0.0, 0.9),
})

WHEEL_R = 0.42
WHEEL_W = 0.34
TRACK = 1.02          # wheel centre from the middle, sideways
AXLES = {"f": 1.45, "m": 0.0, "r": -1.45}


def wheel(name, x, y):
    """A tyre with chevron treads and a satin hub, built round its own origin."""
    side = 1 if x > 0 else -1
    parts = [cyl("t", (0, 0, 0), WHEEL_R - 0.03, WHEEL_W, "tread_rubber", axis="x", verts=40, bevel=0.03, segments=3)]
    rc = WHEEL_R - 0.02
    for i in range(18):                      # chevron tread blocks round the rim
        for k, off in enumerate((-0.085, 0.085)):
            a = 2 * math.pi * (i + 0.5 * k) / 18
            tread = box("tb", -0.06, 0.06, -0.03, 0.03, -0.028, 0.028, "tread_rubber", 0.008)
            tread.location = (off, -math.sin(a) * rc, math.cos(a) * rc)
            tread.rotation_euler = (a, 0, math.radians(18 if k else -18))
            bpy.ops.object.select_all(action="DESELECT"); tread.select_set(True)
            bpy.context.view_layer.objects.active = tread
            bpy.ops.object.transform_apply(location=True, rotation=True)
            parts.append(tread)
    parts.append(cyl("hub", (side * 0.13, 0, 0), 0.24, 0.1, "satin_steel", axis="x", verts=32, bevel=0.015))
    parts.append(cyl("cap", (side * 0.19, 0, 0), 0.09, 0.04, "graphite", axis="x", verts=24, bevel=0.01))
    for i in range(6):                       # lug bolts
        a = 2 * math.pi * i / 6
        parts.append(cyl("lug", (side * 0.19, math.cos(a) * 0.15, math.sin(a) * 0.15), 0.018, 0.04, "satin_steel", axis="x", verts=10))
    obj = join(name, parts)
    obj.location = (x, y, WHEEL_R)
    return obj


def arm(name, x, y):
    """A trailing arm from the chassis to the hub, with a coil-over damper."""
    side = 1 if x > 0 else -1
    hub = Vector((x - side * 0.2, y, WHEEL_R))
    root = Vector((side * 0.62, y + 0.35, 0.62))
    parts = [rod("a", root, hub, 0.045, "dark_alloy"),
             rod("d", (side * 0.66, y - 0.05, 0.98), (x - side * 0.25, y + 0.1, WHEEL_R + 0.12), 0.035, "satin_steel"),
             cyl("spring", ((side * 0.66 + x - side * 0.25) / 2, y + 0.02, (0.98 + WHEEL_R + 0.12) / 2), 0.06, 0.26, "orange", verts=16)]
    return join(name, parts)


def crew_rover():
    # Chassis: graphite spine and side rails, low between the wheels.
    box("chassis_spine_graphite", -0.55, 0.55, -2.05, 2.05, 0.48, 0.66, "graphite", 0.03)
    box("chassis_rail_left_dark_alloy", -0.72, -0.6, -1.95, 1.95, 0.56, 0.72, "dark_alloy", 0.02)
    box("chassis_rail_right_dark_alloy", 0.6, 0.72, -1.95, 1.95, 0.56, 0.72, "dark_alloy", 0.02)
    box("chassis_skidplate_satin_steel", -0.5, 0.5, -1.2, 1.9, 0.44, 0.5, "satin_steel", 0.02)
    # Deck: a white tub over the whole length, with fenders over the wheels.
    box("deck_tub_white_painted", -1.05, 1.05, -2.1, 2.05, 0.7, 1.0, "white_painted", 0.05)
    box("deck_kick_graphite", -1.07, 1.07, -2.12, 2.07, 0.66, 0.74, "graphite", 0.02)
    for name, y in AXLES.items():
        for side, s in (("left", -1), ("right", 1)):
            fender = box(f"fender_{name}_{side}_white_painted", s * 0.98 - 0.0 if s > 0 else -1.22, s * 1.22 if s > 0 else -0.98,
                         y - 0.55, y + 0.55, 0.9, 1.0, "white_painted", 0.03)
            box(f"fender_lip_{name}_{side}_black_rubber", s * 1.2 - 0.02 if s > 0 else -1.24, s * 1.24 if s > 0 else -1.2,
                y - 0.56, y + 0.56, 0.86, 0.92, "black_rubber", 0.01)
    # The cab: rounded, with a sloped nose and a wrap-round windscreen.
    box("cab_body_white_painted", -1.0, 1.0, -0.35, 1.45, 1.0, 2.22, "white_painted", 0.12)
    box("cab_roof_shell", -0.92, 0.92, -0.3, 1.35, 2.18, 2.3, "white_painted", 0.06)
    nose = box("cab_nose_white_painted", -0.98, 0.98, 1.4, 2.02, 1.0, 1.55, "white_painted", 0.1)
    # Windscreen: a dark glass band across the cab front, wrapping round the
    # corners, under a graphite visor.
    box("windscreen_dark_glass", -0.86, 0.86, 1.44, 1.47, 1.56, 2.1, "dark_glass", 0.02)
    for s in (-1, 1):
        box(f"windscreen_corner_{'l' if s < 0 else 'r'}_dark_glass", s * 0.86 if s > 0 else -1.0, s * 1.0 if s > 0 else -0.86, 1.2, 1.46, 1.56, 2.1, "dark_glass", 0.02)
    box("windscreen_frame_graphite", -0.92, 0.92, 1.43, 1.49, 1.52, 1.57, "graphite", 0.01)
    box("visor_graphite", -0.96, 0.96, 1.38, 1.6, 2.1, 2.16, "graphite", 0.02)
    for s, side in ((-1, "left"), (1, "right")):
        box(f"side_window_{side}_dark_glass", s * 1.0 - 0.02 if s > 0 else -1.02, s * 1.02 if s > 0 else -0.98, 0.55, 1.3, 1.62, 2.05, "dark_glass", 0.02)
        box(f"side_window_frame_{side}_graphite", s * 1.0 - 0.025 if s > 0 else -1.03, s * 1.03 if s > 0 else -0.975, 0.5, 1.35, 1.58, 1.62, "graphite", 0.01)
    # Driver's door (left), inset with a rubber seam and a satin handle.
    box("door_left_shell", -1.035, -1.0, -0.2, 0.45, 1.08, 2.08, "white_painted", 0.02)
    box("door_left_seam_black_rubber", -1.045, -1.03, -0.22, 0.47, 1.06, 1.08, "black_rubber", 0)
    box("door_left_handle_satin_steel", -1.07, -1.035, 0.28, 0.4, 1.5, 1.54, "satin_steel", 0.008)
    # One orange stripe down each side (the house accent rule).
    for s, side in ((-1, "left"), (1, "right")):
        box(f"stripe_{side}_orange", s * 1.005 - 0.0 if s > 0 else -1.035, s * 1.035 if s > 0 else -1.005, -2.05, 1.95, 1.05, 1.11, "orange", 0.005)
    # Rear wall of the cab: two suitports with their hatches.
    box("cab_rear_bulkhead_shell", -0.98, 0.98, -0.42, -0.34, 1.0, 2.18, "warm_shell", 0.03)
    for x in (-0.48, 0.48):
        cyl(f"suitport_ring_{'l' if x < 0 else 'r'}_dark_alloy", (x, -0.43, 1.62), 0.36, 0.06, "dark_alloy", axis="y", verts=40, bevel=0.012)
        cyl(f"suitport_hatch_{'l' if x < 0 else 'r'}_white_painted", (x, -0.47, 1.62), 0.3, 0.04, "white_painted", axis="y", verts=40, bevel=0.01)
        cyl(f"suitport_backpack_{'l' if x < 0 else 'r'}_warm_panel", (x, -0.52, 1.58), 0.22, 0.08, "warm_panel", axis="y", verts=32, bevel=0.02)
    # Cargo deck: grated floor, rails, a tool chest and two sample cases.
    box("cargo_floor_dark_alloy", -0.98, 0.98, -2.05, -0.42, 1.0, 1.04, "dark_alloy", 0.01)
    for i in range(7):
        y = -2.0 + i * 0.25
        box(f"cargo_slat_{i}_graphite", -0.96, 0.96, y, y + 0.05, 1.04, 1.055, "graphite", 0.004)
    for s in (-1, 1):
        rod(f"cargo_rail_{'l' if s < 0 else 'r'}_satin_steel", (s * 0.97, -2.0, 1.45), (s * 0.97, -0.5, 1.45), 0.025, "satin_steel")
        for y in (-2.0, -1.25, -0.5):
            rod("post", (s * 0.97, y, 1.04), (s * 0.97, y, 1.45), 0.02, "satin_steel")
    join("cargo_posts_satin_steel", [o for o in PARTS if o.name.startswith("post")])
    rod("cargo_rail_back_satin_steel", (-0.97, -2.0, 1.45), (0.97, -2.0, 1.45), 0.025, "satin_steel")
    box("tool_chest_body_warm_shell", -0.85, -0.15, -0.95, -0.5, 1.05, 1.42, "warm_shell", 0.03)
    box("tool_chest_lid_white_painted", -0.87, -0.13, -0.97, -0.48, 1.42, 1.47, "white_painted", 0.02)
    for i, x in enumerate((0.2, 0.62)):
        box(f"sample_case_{i}_slate_panel", x - 0.18, x + 0.18, -1.85, -1.4, 1.05, 1.3, "slate_panel", 0.02)
        box(f"sample_case_{i}_latch_amber", x - 0.04, x + 0.04, -1.42, -1.39, 1.2, 1.25, "amber", 0.004)
    # Roof: solar panel, light bar, beacon, mast and a handrail.
    box("roof_solar_frame_dark_alloy", -0.8, 0.8, -0.2, 1.2, 2.3, 2.33, "dark_alloy", 0.01)
    box("roof_solar_cells_solar_cell", -0.76, 0.76, -0.16, 1.16, 2.33, 2.345, "solar_cell", 0.005)
    box("light_bar_housing_graphite", -0.75, 0.75, 1.24, 1.36, 2.2, 2.31, "graphite", 0.02)
    for i in range(6):
        x = -0.6 + i * 0.24
        box(f"light_bar_lens_{i}_lamp_white", x - 0.09, x + 0.09, 1.355, 1.37, 2.22, 2.29, "lamp_white", 0.004)
    cyl("beacon_amber", (0.55, -0.1, 2.38), 0.06, 0.1, "amber", verts=20, bevel=0.01)
    rod("mast_satin_steel", (-0.6, -0.2, 2.3), (-0.6, -0.2, 2.44), 0.022, "satin_steel")
    rod("mast_whip_dark_alloy", (-0.6, -0.2, 2.44), (-0.6, -0.2, 2.54), 0.008, "dark_alloy")
    for s in (-1, 1):
        rod(f"roof_rail_{'l' if s < 0 else 'r'}_satin_steel", (s * 0.88, -0.25, 2.24), (s * 0.88, 1.2, 2.24), 0.018, "satin_steel")
    # Headlights in the nose, with a grille and a bumper.
    for s in (-1, 1):
        box(f"headlight_housing_{'l' if s < 0 else 'r'}_graphite", s * 0.72 - 0.15, s * 0.72 + 0.15, 1.98, 2.06, 1.12, 1.3, "graphite", 0.02)
        box(f"headlight_lens_{'l' if s < 0 else 'r'}_lamp_white", s * 0.72 - 0.12, s * 0.72 + 0.12, 2.05, 2.07, 1.15, 1.27, "lamp_white", 0.01)
    vent("nose_grille_dark_alloy", -0.42, 0.42, 1.12, 1.32, 2.0, slats=5)
    box("bumper_front_dark_alloy", -1.0, 1.0, 2.05, 2.16, 0.72, 0.88, "dark_alloy", 0.03)
    box("bumper_rear_dark_alloy", -1.0, 1.0, -2.2, -2.08, 0.72, 0.88, "dark_alloy", 0.03)
    for s in (-1, 1):
        box(f"tail_light_{'l' if s < 0 else 'r'}_red_cross", s * 0.85 - 0.08, s * 0.85 + 0.08, -2.13, -2.11, 0.9, 0.98, "red_cross", 0.005)
    # Name badge on the nose and a hull number on the doors.
    box("badge_satin_steel", -0.18, 0.18, 2.015, 2.02, 1.42, 1.5, "satin_steel", 0.003)
    # Wheels and their arms.
    for name, y in AXLES.items():
        for side, x in (("l", -TRACK), ("r", TRACK)):
            arm(f"arm_{name}{side}_dark_alloy", x, y)
            wheel(f"wheel_{name}{side}", x, y)


MODELS = [("crew_rover", crew_rover, "ground")]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials()
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 900
scene.render.resolution_y = 640
world = bpy.data.worlds.new("bg"); scene.world = world

for item_id, build, placement in MODELS:
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
    for view, direction in (("", (1.0, 1.25, 0.55)), ("_rear", (-1.1, -1.2, 0.6))):
        bpy.ops.object.camera_add()
        cam = bpy.context.active_object; scene.camera = cam
        cam.data.lens = 50
        eye = centre + Vector(direction).normalized() * (size * 1.9 + 0.6)
        cam.location = eye
        cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, "previews", item_id + view + ".png")
        bpy.ops.render.render(write_still=True)
    print("BUILT", item_id, bounds, "tris", tris)

with open(os.path.join(OUT, "asset_manifest.json"), "w") as f:
    json.dump({"style": "Crew rover, house style (white cab, graphite chassis, one orange stripe)",
               "units": "metres; Y up; -Z forward; ground origin at the middle of the wheelbase", "assets": MANIFEST}, f, indent=2)
