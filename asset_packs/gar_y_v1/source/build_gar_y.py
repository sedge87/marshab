"""Blender (5.x) build script: GAR-Y, the Geological Analysis Rover, Y-Class.

Run:  blender --background --python build_gar_y.py -- <out_dir>
Writes <out_dir>/gar_y.glb and gar_y.png (a preview).

Shares the furnishings pack's materials and bevel helpers (loaded from
../../mars_habitat_furnishings_v1/source/build_furnishings.py), so GAR-Y sits
in the same habitat as everything else.

Unlike the furniture, GAR-Y is a hierarchy of pivots the game animates:

  GarY
    body (chassis, deck, solar panel, rocker-bogie legs, bumpers)
    Wheel_1..Wheel_6     pivots at each axle (spin about local X)
    Mast                 pivot at the deck (pans about Y)
      Head               pivot at the head (tilts about X)
        Eye_L, Eye_R     the face light: two glowing eyes the game tints,
                         squints and blinks to show GAR-Y's mood
        LampMount        where the torch spotlight goes (points forward)
    ArmShoulder          pivot (pitches about X), modelled pointing straight up
      ArmElbow
        ArmWrist
          Grip           where a carried item is held

Metres, ground origin; the front faces -Z in glTF (Blender +Y here).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({
    "eye_glow": ((0.75, 0.95, 1.0, 1), 0.0, 0.3),
    "rover_white": ((0.92, 0.92, 0.89, 1), 0.04, 0.5),
    "solar_cell": ((0.08, 0.13, 0.22, 1), 0.55, 0.25),
})
GLOW.update({"eye_glow": 2.2})

ROOT = None


def empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.05
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def attach(objs, parent):
    """Parents meshes to a pivot, keeping where they are."""
    bpy.context.view_layer.update()
    for obj in objs:
        if obj is None: continue
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()


def build():
    global ROOT
    ROOT = empty("GarY", (0, 0, 0))
    body = []
    # ---- chassis: a rounded white shell on a dark belly, orange trim ----
    body.append(box("chassis_rover_white", -0.32, 0.32, -0.42, 0.42, 0.30, 0.49, "rover_white", 0.045))
    body.append(box("deck_white_painted", -0.345, 0.345, -0.445, 0.445, 0.47, 0.525, "white_painted", 0.022))
    body.append(box("belly_graphite", -0.28, 0.28, -0.38, 0.38, 0.25, 0.31, "graphite", 0.015))
    body.append(join("trim_orange", [box("t", s * 0.323, s * 0.329, -0.36, 0.36, 0.395, 0.425, "orange", 0.004) for s in (-1, 1)]))
    body.append(box("bumper_front_graphite", -0.26, 0.26, 0.42, 0.465, 0.30, 0.39, "graphite", 0.02))
    body.append(box("bumper_rear_graphite", -0.26, 0.26, -0.465, -0.42, 0.30, 0.39, "graphite", 0.02))
    body.append(join("headlights_lamp_white", [box("h", x - 0.035, x + 0.035, 0.464, 0.468, 0.33, 0.36, "lamp_white", 0.006) for x in (-0.17, 0.17)]))
    # Solar panel on the rear deck, with cell lines.
    body.append(box("solar_frame_alloy", -0.29, 0.29, -0.42, -0.02, 0.525, 0.545, "alloy", 0.008))
    body.append(box("solar_cells_solar_cell", -0.275, 0.275, -0.405, -0.035, 0.545, 0.55, "solar_cell", 0))
    body.append(join("solar_lines_slate_panel", [box("l", -0.275, 0.275, y, y + 0.004, 0.55, 0.552, "slate_panel", 0) for y in (-0.32, -0.22, -0.12)]
                     + [box("l", x, x + 0.004, -0.405, -0.035, 0.55, 0.552, "slate_panel", 0) for x in (-0.09, 0.09)]))
    # Sample drawer on the side and a little badge (GAR-Y's orange "Y").
    body.append(box("sample_drawer_warm_panel", 0.322, 0.335, -0.2, 0.08, 0.32, 0.385, "warm_panel", 0.006))
    body.append(box("drawer_handle_graphite", 0.334, 0.342, -0.1, 0.0, 0.345, 0.36, "graphite", 0.003))
    body.append(join("badge_orange", [rod("y", (-0.329, 0.18, 0.44), (-0.329, 0.21, 0.47), 0.006, "orange", 8), rod("y", (-0.329, 0.24, 0.44), (-0.329, 0.21, 0.47), 0.006, "orange", 8),
                                      rod("y", (-0.329, 0.21, 0.47), (-0.329, 0.21, 0.5), 0.006, "orange", 8)]))
    # Comms whip antenna at the back.
    body.append(rod("antenna_dark_alloy", (-0.24, -0.38, 0.52), (-0.24, -0.38, 0.86), 0.006, "dark_alloy", 8))
    body.append(sphere("antenna_tip_orange", (-0.24, -0.38, 0.87), 0.014, "orange", segments=12))
    # Rocker-bogie legs: a rocker from the body pivot to the front wheel and a
    # bogie carrying the middle and rear wheels.
    legs = []
    for s in (-1, 1):
        pivot = (s * 0.39, 0.02, 0.36)
        bogie = (s * 0.42, -0.2, 0.25)
        legs += [rod("r", pivot, (s * 0.43, 0.36, 0.17), 0.018, "dark_alloy"), rod("r", pivot, bogie, 0.018, "dark_alloy"),
                 rod("b", bogie, (s * 0.43, -0.02, 0.17), 0.016, "dark_alloy"), rod("b", bogie, (s * 0.43, -0.38, 0.17), 0.016, "dark_alloy")]
        legs.append(cyl("p", pivot, 0.03, 0.05, "graphite", axis="x", verts=16))
        legs.append(cyl("p", bogie, 0.024, 0.045, "graphite", axis="x", verts=16))
    body.append(join("legs_dark_alloy", legs))
    attach(body, ROOT)

    # ---- six wheels, each on a pivot at its axle ----
    for i, (y) in enumerate((0.36, -0.02, -0.38)):
        for s in (-1, 1):
            centre = (s * 0.45, y, 0.165)
            pivot = empty("Wheel_%d" % (i * 2 + (0 if s < 0 else 1) + 1), centre, ROOT)
            parts = [cyl("t", centre, 0.165, 0.11, "black_rubber", axis="x", verts=32, bevel=0.012)]
            parts.append(cyl("h", (centre[0] + s * 0.056, y, 0.165), 0.085, 0.012, "alloy", axis="x", verts=24))
            parts.append(cyl("c", (centre[0] + s * 0.064, y, 0.165), 0.035, 0.01, "orange", axis="x", verts=16))
            for k in range(12):
                a = k / 12 * math.tau
                parts.append(box("tr", centre[0] - 0.058, centre[0] + 0.058, y + math.cos(a) * 0.162 - 0.018, y + math.cos(a) * 0.162 + 0.018,
                                 0.165 + math.sin(a) * 0.162 - 0.012, 0.165 + math.sin(a) * 0.162 + 0.012, "black_rubber", 0.004))
            wheel = join("wheel_%d_black_rubber" % (i * 2 + (0 if s < 0 else 1) + 1), parts)
            attach([wheel], pivot)

    # ---- the mast and head: GAR-Y's face ----
    mast = empty("Mast", (0.0, 0.2, 0.53), ROOT)
    pole = [cyl("collar_graphite", (0.0, 0.2, 0.55), 0.05, 0.05, "graphite", verts=24, bevel=0.008),
            cyl("pole_alloy", (0.0, 0.2, 0.71), 0.024, 0.3, "alloy", verts=16)]
    attach(pole, mast)
    head = empty("Head", (0.0, 0.2, 0.88), mast)
    shell = [box("head_rover_white", -0.14, 0.14, 0.12, 0.29, 0.81, 0.97, "rover_white", 0.04),
             box("visor_dark_glass", -0.12, 0.12, 0.288, 0.296, 0.83, 0.955, "dark_glass", 0.012),
             box("brow_orange", -0.1, 0.1, 0.27, 0.292, 0.962, 0.975, "orange", 0.005),
             cyl("cheek_cam_graphite", (-0.155, 0.22, 0.89), 0.03, 0.04, "graphite", axis="x", verts=16),
             cyl("cheek_cam_graphite", (0.155, 0.22, 0.89), 0.03, 0.04, "graphite", axis="x", verts=16),
             cyl("cheek_lens_dark_glass", (-0.177, 0.22, 0.89), 0.018, 0.006, "dark_glass", axis="x", verts=16),
             cyl("cheek_lens_dark_glass", (0.177, 0.22, 0.89), 0.018, 0.006, "dark_glass", axis="x", verts=16),
             cyl("lamp_housing_graphite", (0.0, 0.29, 0.79), 0.03, 0.05, "graphite", axis="y", verts=20, bevel=0.005),
             cyl("lamp_lens_lamp_white", (0.0, 0.317, 0.79), 0.022, 0.006, "lamp_white", axis="y", verts=20)]
    attach(shell, head)
    for name, x in (("Eye_L", -0.055), ("Eye_R", 0.055)):
        eye_pivot = empty(name, (x, 0.297, 0.895), head)
        eye = box(name.lower() + "_eye_glow", x - 0.028, x + 0.028, 0.296, 0.302, 0.865, 0.925, "eye_glow", 0.012)
        attach([eye], eye_pivot)
    empty("LampMount", (0.0, 0.32, 0.79), head)

    # ---- the arm: shoulder, upper arm, elbow, forearm, wrist, gripper ----
    # Modelled pointing straight up from the shoulder; the game folds it.
    shoulder = empty("ArmShoulder", (0.2, 0.43, 0.42), ROOT)
    attach([cyl("shoulder_joint_graphite", (0.2, 0.43, 0.42), 0.04, 0.07, "graphite", axis="x", verts=20, bevel=0.006),
            box("upper_arm_rover_white", 0.18, 0.22, 0.41, 0.45, 0.42, 0.66, "rover_white", 0.012),
            box("upper_arm_stripe_orange", 0.221, 0.224, 0.415, 0.445, 0.5, 0.58, "orange", 0)], shoulder)
    elbow = empty("ArmElbow", (0.2, 0.43, 0.66), shoulder)
    attach([cyl("elbow_joint_graphite", (0.2, 0.43, 0.66), 0.032, 0.06, "graphite", axis="x", verts=20, bevel=0.005),
            box("forearm_alloy", 0.185, 0.215, 0.415, 0.445, 0.66, 0.86, "alloy", 0.01)], elbow)
    wrist = empty("ArmWrist", (0.2, 0.43, 0.86), elbow)
    attach([cyl("wrist_joint_graphite", (0.2, 0.43, 0.86), 0.026, 0.05, "graphite", axis="x", verts=16, bevel=0.004),
            box("palm_dark_alloy", 0.165, 0.235, 0.405, 0.455, 0.86, 0.9, "dark_alloy", 0.008),
            box("finger_l_orange", 0.168, 0.182, 0.415, 0.445, 0.9, 0.96, "orange", 0.005),
            box("finger_r_orange", 0.218, 0.232, 0.415, 0.445, 0.9, 0.96, "orange", 0.005)], wrist)
    empty("Grip", (0.2, 0.43, 0.95), wrist)


# ---------- build, export, preview ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials()
reset()
build()
bpy.ops.object.select_all(action="SELECT")
ARGS_OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(ARGS_OUT, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ARGS_OUT, "gar_y.glb"), export_format="GLB", use_selection=True, export_apply=True)
tris = 0
deps = bpy.context.evaluated_depsgraph_get()
for obj in bpy.context.scene.objects:
    if obj.type != "MESH": continue
    mesh = obj.evaluated_get(deps).to_mesh()
    mesh.calc_loop_triangles()
    tris += len(mesh.loop_triangles)
    obj.evaluated_get(deps).to_mesh_clear()
print("BUILT gar_y tris", tris, "objects", len(bpy.context.scene.objects))
