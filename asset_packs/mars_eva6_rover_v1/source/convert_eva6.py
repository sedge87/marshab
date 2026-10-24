"""Blender (5.x): fit the EVA-6 pressurised rover into OUTPOST ONE (25 Oct).

Run:  blender --background --python convert_eva6.py -- <pack_dir>
Reads <pack_dir>/original/models/rover_chassis.glb and rover_wheel.glb (the
user's design, built by original/build_rover.py), writes
<pack_dir>/models/crew_rover.glb and previews/crew_rover*.png.

- Scaled to 62%: 4.1 m long, 2.3 m wide, 2.4 m tall with its antennas, so it
  drives through a vehicle bay's 2.58 m hangar door like the old rover.
- The ground is the origin: the wheels' hubs sit on the suspension struts'
  ends and their tyres touch y = 0.
- Every part gets a named house material (docs/house-style.md): the original
  stored its colours per vertex under "DefaultMaterial" names, which the
  game's palette can't read. Each part is matched by its colour.
- The six wheels are separate nodes, wheel_<fl|fr|ml|mr|rl|rr>, with their
  origin at the hub, for scripts/crew_rover.gd to spin and steer. The tail
  lights are their own part (tail_light_red) so they can glow when braking.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

PACK = sys.argv[sys.argv.index("--") + 1]
SCALE = 0.62
HUB_Y = 0.89          # wheel hub height in the original (the struts' ends)
WHEEL_R = 0.59
LIFT = WHEEL_R - HUB_Y    # move the original down so the tyres touch the ground
WHEELS = {"f": 2.08, "m": 0.0, "r": -2.08}   # forward is +Y here (glTF -Z)
TRACK = 1.59

# The original's colours (build_rover.py) -> a house material name.
NAMES = {
    (55, 65, 72): "deck_graphite", (145, 155, 159): "frame_titanium_alloy", (78, 87, 91): "rail_gunmetal",
    (177, 187, 188): "fittings_satin_steel", (218, 225, 224): "body_white_ceramic", (242, 241, 229): "trim_white_painted",
    (37, 80, 98): "windows_dark_glass", (22, 30, 36): "recess_deep_graphite", (225, 107, 48): "accent_orange",
    (245, 246, 215): "searchlight_lamp_white", (186, 45, 39): "tail_light_red", (80, 144, 158): "camera_lens_screen_cyan",
    (29, 55, 90): "roof_solar_cell", (28, 31, 34): "tyre_black_rubber", (49, 53, 54): "tread_black_rubber",
    (66, 132, 173): "detail_cool_blue", (70, 179, 135): "status_bright_green", (239, 192, 79): "detail_amber",
}
GLOW = {"searchlight_lamp_white": 2.0, "camera_lens_screen_cyan": 1.2}


def material(name: str, rgb) -> bpy.types.Material:
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    colour = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
    linear = tuple(c ** 2.2 for c in colour[:3]) + (1.0,)
    bsdf.inputs["Base Color"].default_value = linear
    m.diffuse_color = colour   # for the preview renders
    metal = 0.6 if any(k in name for k in ("alloy", "steel", "gunmetal")) else 0.05
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = 0.1 if "glass" in name else (0.85 if "rubber" in name else 0.5)
    if name in GLOW:
        bsdf.inputs["Emission Color"].default_value = linear
        bsdf.inputs["Emission Strength"].default_value = GLOW[name]
    return m


def first_colour(obj) -> tuple:
    attr = obj.data.color_attributes[0] if obj.data.color_attributes else None
    if attr is None: return (204, 204, 204)
    c = attr.data[0].color   # the byte colours as stored (0-1); color_srgb converts them again
    return tuple(int(round(v * 255)) for v in c[:3])


def nearest_name(rgb) -> str:
    best = min(NAMES, key=lambda k: sum((a - b) ** 2 for a, b in zip(k, rgb)))
    return NAMES[best]


def dress(objs, prefix=""):
    """Give each imported part a house material and a component_material name."""
    for o in objs:
        rgb = first_colour(o)
        name = nearest_name(rgb)
        o.data.materials.clear()
        o.data.materials.append(material(name, [v for v in [k for k in NAMES if NAMES[k] == name][0]]))
        for attr in list(o.data.color_attributes): o.data.color_attributes.remove(attr)
        o.name = prefix + name
        o.data.name = o.name
        for poly in o.data.polygons: poly.use_smooth = False


def import_meshes(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    # Bake the importer's parent transforms in, then drop the empties.
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    for o in new:
        if o.type != "MESH": bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return meshes


bpy.ops.wm.read_factory_settings(use_empty=True)
original = os.path.join(PACK, "original", "models")
chassis = import_meshes(os.path.join(original, "rover_chassis.glb"))
dress(chassis)
for o in chassis:
    for v in o.data.vertices:
        v.co = Vector((v.co.x * SCALE, v.co.y * SCALE, (v.co.z + LIFT) * SCALE))
    o.data.update()

parts = list(chassis)
for axle, y in WHEELS.items():
    for side, x in (("l", -TRACK), ("r", TRACK)):
        wheel_parts = import_meshes(os.path.join(original, "rover_wheel.glb"))
        dress(wheel_parts, f"w{axle}{side}_")
        for o in wheel_parts:
            for v in o.data.vertices: v.co = v.co * SCALE
            o.data.update()
        bpy.ops.object.select_all(action="DESELECT")
        for o in wheel_parts: o.select_set(True)
        bpy.context.view_layer.objects.active = wheel_parts[0]
        bpy.ops.object.join()
        wheel = bpy.context.active_object
        wheel.name = f"wheel_{axle}{side}"
        wheel.data.name = wheel.name
        wheel.location = (x * SCALE, y * SCALE, WHEEL_R * SCALE)
        parts.append(wheel)

os.makedirs(os.path.join(PACK, "models"), exist_ok=True)
os.makedirs(os.path.join(PACK, "previews"), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for o in parts: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(PACK, "models", "crew_rover.glb"), export_format="GLB", use_selection=True)

lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for o in parts:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
print("BOUNDS", [round(v, 2) for v in lo], [round(v, 2) for v in hi])
print("PARTS", sorted(o.name for o in parts))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.render.resolution_x = 900
scene.render.resolution_y = 640
scene.world = bpy.data.worlds.new("bg")
centre = (lo + hi) / 2
size = max(hi - lo)
for view, direction in (("", (1.0, 1.25, 0.55)), ("_rear", (-1.1, -1.2, 0.6))):
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; scene.camera = cam
    eye = centre + Vector(direction).normalized() * (size * 1.9 + 0.6)
    cam.location = eye
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(PACK, "previews", "crew_rover" + view + ".png")
    bpy.ops.render.render(write_still=True)
print("DONE")
