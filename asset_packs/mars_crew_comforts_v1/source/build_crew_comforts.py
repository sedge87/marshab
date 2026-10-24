"""Blender (5.x) build script: Crew Comforts pack for MARS: HABITAT (v1).

Run:  blender --background --python build_crew_comforts.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

From the 23 Oct playtest (backlog batch 3): a blank desk (no built-in laptop,
so crew put their own things on it), a one-piece galley kitchenette and
matching bench units (replacing the separate counter, oven and rehydration
station), a wall screen the game draws live pictures on, and a toy GAR-Y.
Shares the furnishings pack's materials, bevels and export (its helpers are
loaded from ../../mars_habitat_furnishings_v1/source/build_furnishings.py).

Metres, floor origin, front faces -Z in glTF (Blender +Y here).
"""
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({
    "rover_white": ((0.92, 0.92, 0.89, 1), 0.04, 0.5),
    "eye_glow": ((0.75, 0.95, 1.0, 1), 0.0, 0.3),
    "solar_cell": ((0.08, 0.13, 0.22, 1), 0.55, 0.25),
    "worktop": ((0.80, 0.82, 0.80, 1), 0.10, 0.35),
})
GLOW.update({"eye_glow": 1.4})


def desk_frame():
    """The work desk's top, drawer pedestal and legs (shared with the blank desk)."""
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


def work_desk_blank():
    """A clear work desk: the same desk without the laptop, mug and notepad,
    with a cable grommet and a small power strip under the back edge."""
    desk_frame()
    cyl("grommet_graphite", (-0.42, -0.2, 0.752), 0.03, 0.006, "graphite", verts=24)
    box("power_strip_dark_alloy", -0.3, 0.0, -0.3, -0.26, 0.68, 0.71, "dark_alloy", 0.004)
    join("sockets_orange", [box("s", x - 0.012, x + 0.012, -0.262, -0.258, 0.688, 0.702, "orange", 0) for x in (-0.24, -0.15, -0.06)])


def base_units(x0, x1, y0=-0.32, y1=0.32, top=0.92, bays=None):
    """A run of galley base cupboards with a continuous worktop and upstand.
    bays: [(prefix, bx0, bx1, kind)]: each bay behind a door is a real
    compartment (back, sides, floor, roof and liner) with things inside;
    kind "solid" is a closed block (behind drawers). (Fixed 24 Oct: doors
    used to open onto a solid carcass.)"""
    box("plinth_graphite", x0 + 0.03, x1 - 0.03, y0 + 0.05, y1 - 0.05, 0.0, 0.1, "graphite", 0.008)
    if bays is None:
        box("carcass_warm_shell", x0, x1, y0, y1 - 0.02, 0.09, top - 0.04, "warm_shell", 0.014)
    else:
        for prefix, bx0, bx1, kind in bays:
            if kind == "solid":
                box(f"{prefix}_block_warm_shell", bx0, bx1, y0, y1 - 0.02, 0.09, top - 0.04, "warm_shell", 0.014)
                continue
            liner = {"fridge": "white_painted", "oven": "graphite"}.get(kind, "warm_panel")
            hollow(prefix, bx0, bx1, y0, y1 - 0.02, 0.09, top - 0.04, 0.018, "warm_shell", liner)
            BAY_CONTENTS[kind](prefix, bx0 + 0.02, bx1 - 0.02, y0 + 0.03, y1 - 0.05, 0.11, top - 0.06)
    box("worktop_worktop", x0 - 0.015, x1 + 0.015, y0, y1 + 0.03, top - 0.04, top, "worktop", 0.012)
    box("upstand_worktop", x0 - 0.015, x1 + 0.015, y0, y0 + 0.02, top, top + 0.1, "worktop", 0.006)


# ---------- what's behind the doors ----------

def _fridge_contents(p, x0, x1, y0, y1, z0, z1):
    for i, z in enumerate((z0 + (z1 - z0) * .36, z0 + (z1 - z0) * .68)):
        box(f"{p}_shelf_{i}_satin_steel", x0, x1, y0, y1 - 0.02, z, z + 0.008, "satin_steel", 0.002)
    box(f"{p}_lamp_lamp_white", x0 + 0.1, x1 - 0.1, y0 + 0.05, y0 + 0.08, z1 - 0.02, z1 - 0.005, "lamp_white", 0)
    w = x1 - x0
    cartons = [box("c", x0 + w * f - 0.035, x0 + w * f + 0.035, y0 + 0.04, y0 + 0.11, z0, z0 + 0.19, "white_painted", 0.006) for f in (0.18, 0.34)]
    join(f"{p}_cartons_white_painted", cartons)
    join(f"{p}_carton_tops_teal", [box("c", x0 + w * f - 0.035, x0 + w * f + 0.035, y0 + 0.04, y0 + 0.11, z0 + 0.19, z0 + 0.21, "teal", 0.004) for f in (0.18, 0.34)])
    zs = z0 + (z1 - z0) * .36 + 0.008
    join(f"{p}_pouches_pouch_silver", [box("q", x0 + w * f - 0.05, x0 + w * f + 0.05, y0 + 0.05, y0 + 0.13, zs, zs + 0.13, "pouch_silver", 0.01) for f in (0.2, 0.42, 0.64)])
    join(f"{p}_greens_leaf_green", [sphere("g", (x0 + w * f, y0 + 0.16, z0 + 0.06), 0.07, "leaf_green", scale=(1.0, 1.0, 0.8), segments=14) for f in (0.7, 0.84)])
    zt = z0 + (z1 - z0) * .68 + 0.008
    join(f"{p}_tubs_amber", [cyl("t", (x0 + w * f, y0 + 0.12, zt + 0.04), 0.045, 0.08, "amber", verts=20, bevel=0.005) for f in (0.3, 0.55)])


def _sink_contents(p, x0, x1, y0, y1, z0, z1):
    xm = (x0 + x1) / 2
    join(f"{p}_trap_satin_steel", [rod("t", (xm, y0 + 0.2, z1), (xm, y0 + 0.2, z1 - 0.22), 0.022, "satin_steel"),
                                   rod("t", (xm, y0 + 0.2, z1 - 0.22), (xm, y0 + 0.02, z1 - 0.26), 0.022, "satin_steel")])
    join(f"{p}_supply_pipes_dark_alloy", [rod("s", (x, y0 + 0.02, z0 + 0.35), (x, y0 + 0.02, z1), 0.012, "dark_alloy") for x in (xm - 0.1, xm + 0.1)])
    cyl(f"{p}_bottle_teal", (x0 + 0.07, y0 + 0.16, z0 + 0.11), 0.04, 0.22, "teal", verts=20, bevel=0.01)
    cyl(f"{p}_bottle_orange", (x0 + 0.17, y0 + 0.2, z0 + 0.09), 0.035, 0.18, "orange", verts=20, bevel=0.01)
    box(f"{p}_cloths_cool_blue", x1 - 0.18, x1 - 0.04, y0 + 0.1, y0 + 0.25, z0, z0 + 0.05, "cool_blue", 0.01)


def _oven_contents(p, x0, x1, y0, y1, z0, z1):
    zr = z0 + (z1 - z0) * .45
    rack = [rod("r", (x0 + 0.02, y, zr), (x1 - 0.02, y, zr), 0.004, "satin_steel", 6) for y in [y0 + 0.04 + i * 0.05 for i in range(10)] if y < y1 - 0.03]
    rack += [rod("r", (x, y0 + 0.03, zr), (x, y1 - 0.04, zr), 0.005, "satin_steel", 6) for x in (x0 + 0.02, x1 - 0.02)]
    join(f"{p}_rack_satin_steel", rack)
    join(f"{p}_element_amber", [rod("e", (x0 + 0.05, y, z1 - 0.03), (x1 - 0.05, y, z1 - 0.03), 0.006, "amber", 8) for y in (y0 + 0.08, (y0 + y1) / 2, y1 - 0.08)])
    box(f"{p}_tray_dark_alloy", x0 + 0.08, x1 - 0.08, y0 + 0.06, y1 - 0.08, zr + 0.006, zr + 0.026, "dark_alloy", 0.006)
    box(f"{p}_meal_orange", x0 + 0.14, x1 - 0.14, y0 + 0.1, y1 - 0.12, zr + 0.026, zr + 0.05, "orange", 0.012)


def _cupboard_contents(p, x0, x1, y0, y1, z0, z1):
    zs = z0 + (z1 - z0) * .5
    box(f"{p}_shelf_warm_panel", x0, x1, y0, y1 - 0.02, zs, zs + 0.014, "warm_panel", 0.003)
    w = x1 - x0
    join(f"{p}_plates_white_painted", [cyl("pl", (x0 + w * .3, y0 + 0.16, z0 + 0.008 + i * 0.016), 0.11, 0.012, "white_painted", verts=28, bevel=0.003) for i in range(6)])
    join(f"{p}_bowls_teal_soft", [cyl("bw", (x0 + w * .72, y0 + 0.15, z0 + 0.03 + i * 0.045), 0.075, 0.05, "teal_soft", verts=24, radius2=0.055, bevel=0.004) for i in range(3)])
    join(f"{p}_boxes_pouch_silver", [box("bx", x0 + w * f - 0.06, x0 + w * f + 0.06, y0 + 0.04, y0 + 0.2, zs + 0.014, zs + 0.2, "pouch_silver", 0.008) for f in (0.22, 0.48)])
    box(f"{p}_box_label_orange", x0 + w * .22 - 0.04, x0 + w * .22 + 0.04, y0 + 0.2, y0 + 0.204, zs + 0.08, zs + 0.12, "orange", 0)
    join(f"{p}_mugs_cool_blue", [cyl("m", (x0 + w * f, y0 + 0.14, zs + 0.06), 0.04, 0.09, "cool_blue", verts=20, bevel=0.004) for f in (0.74, 0.86)])


BAY_CONTENTS = {"fridge": _fridge_contents, "sink": _sink_contents, "oven": _oven_contents, "cupboard": _cupboard_contents}


def door_front(prefix, x0, x1, z0, z1, y, mat="white_painted", pull_top=True):
    box(f"{prefix}_door_{mat}", x0 + 0.006, x1 - 0.006, y, y + 0.02, z0, z1, mat, 0.008)
    z = z1 - 0.06 if pull_top else z0 + 0.06
    handle(f"{prefix}_pull_satin_steel", x0 + 0.06, x1 - 0.06, z, y + 0.02)


def galley_kitchenette():
    """One galley run, 2.4 m: an under-counter fridge, a sink, an induction
    hob over a compact oven, a rehydration tap with a pouch shelf, wall
    cupboards and a light strip under them. Worktop at 0.92 m."""
    X0, X1 = -1.2, 1.2
    Y0, Y1 = -0.32, 0.32
    base_units(X0, X1, Y0, Y1, bays=[("fridgebay", -1.2, -0.6, "fridge"), ("sinkbay", -0.6, 0.0, "sink"),
                                      ("ovenbay", 0.0, 0.6, "oven"), ("drawerbay", 0.6, 1.2, "solid")])
    # Fronts, left to right: fridge (0.6), sink cupboard (0.6), oven (0.6), drawers (0.6).
    box("fridge_door_white_painted", -1.194, -0.606, Y1 - 0.02, Y1, 0.11, 0.86, "white_painted", 0.01)
    rod("fridge_handle_satin_steel", (-0.65, Y1 + 0.03, 0.3), (-0.65, Y1 + 0.03, 0.78), 0.011, "satin_steel")
    box("fridge_display_screen_cyan", -1.1, -0.98, Y1 + 0.001, Y1 + 0.004, 0.76, 0.8, "screen_cyan", 0)
    vent("fridge_vent_dark_alloy", -1.15, -0.65, 0.1, 0.13, Y1 - 0.02, slats=2)
    door_front("sink_l", -0.6, -0.3, 0.11, 0.86, Y1 - 0.02)
    door_front("sink_r", -0.3, 0.0, 0.11, 0.86, Y1 - 0.02)
    # Oven under the hob.
    box("oven_door_slate_panel", 0.006, 0.594, Y1 - 0.02, Y1 + 0.005, 0.12, 0.68, "slate_panel", 0.012)
    box("oven_window_dark_glass", 0.08, 0.52, Y1 + 0.005, Y1 + 0.01, 0.22, 0.56, "dark_glass", 0.006)
    handle("oven_handle_satin_steel", 0.08, 0.52, 0.63, Y1 + 0.005)
    box("oven_controls_graphite", 0.006, 0.594, Y1 - 0.02, Y1 + 0.004, 0.7, 0.86, "graphite", 0.006)
    join("oven_knobs_satin_steel", [cyl("k", (x, Y1 + 0.02, 0.78), 0.022, 0.03, "satin_steel", axis="y", verts=20, bevel=0.003) for x in (0.1, 0.18)])
    box("oven_display_screen_cyan", 0.3, 0.5, Y1 + 0.004, Y1 + 0.008, 0.75, 0.81, "screen_cyan", 0)
    for i, (z0, z1) in enumerate(((0.11, 0.36), (0.37, 0.61), (0.62, 0.86))):
        door_front(f"drawer_{i}", 0.6, 1.2, z0, z1, Y1 - 0.02, "white_painted")
    # Sink: a steel basin let into the worktop, with a tap.
    box("sink_rim_satin_steel", -0.55, -0.05, -0.2, 0.22, 0.915, 0.925, "satin_steel", 0.004)
    box("sink_basin_dark_alloy", -0.5, -0.1, -0.15, 0.17, 0.75, 0.922, "dark_alloy", 0.01)
    cyl("sink_drain_graphite", (-0.3, 0.01, 0.923), 0.03, 0.004, "graphite", verts=20)
    rod("tap_satin_steel", (-0.3, -0.25, 0.92), (-0.3, -0.25, 1.15), 0.016, "satin_steel")
    rod("tap_spout_satin_steel", (-0.3, -0.25, 1.15), (-0.3, -0.08, 1.12), 0.013, "satin_steel")
    box("tap_lever_orange", -0.27, -0.22, -0.27, -0.23, 1.05, 1.08, "orange", 0.004)
    # Induction hob.
    box("hob_dark_glass", 0.04, 0.56, -0.24, 0.24, 0.92, 0.93, "dark_glass", 0.006)
    join("hob_rings_slate_panel", [torus("r", (x, y, 0.932), 0.075, 0.004, "slate_panel") for x in (0.17, 0.43) for y in (-0.1, 0.1)])
    box("hob_indicator_amber", 0.46, 0.53, 0.19, 0.21, 0.931, 0.934, "amber", 0)
    # Rehydration tap: hot and cold nozzles over a drip tray, pouch shelf above.
    box("rehydration_body_white_painted", 0.72, 1.12, -0.3, -0.12, 0.92, 1.3, "white_painted", 0.014)
    box("rehydration_display_screen_cyan", 0.78, 0.95, -0.121, -0.117, 1.18, 1.25, "screen_cyan", 0)
    for x, mat in ((0.86, "orange"), (0.98, "cool_blue")):
        rod(f"nozzle_{'hot' if mat == 'orange' else 'cold'}_satin_steel", (x, -0.14, 1.1), (x, -0.06, 1.06), 0.012, "satin_steel")
        box(f"nozzle_tag_{mat}", x - 0.02, x + 0.02, -0.119, -0.115, 1.12, 1.14, mat, 0)
    box("drip_tray_satin_steel", 0.76, 1.08, -0.12, 0.06, 0.92, 0.935, "satin_steel", 0.004)
    # Wall cupboards and a light strip.
    WZ0, WZ1, WY0, WY1 = 1.5, 2.15, -0.32, 0.02
    box("wall_cupboards_warm_shell", X0, X1, WY0, WY1, WZ0, WZ1, "warm_shell", 0.014)
    for i in range(4):
        x0 = X0 + i * 0.6
        door_front(f"wall_door_{i}", x0, x0 + 0.6, WZ0 + 0.01, WZ1 - 0.01, WY1, "white_painted", pull_top=False)
    box("light_strip_lamp_white", X0 + 0.05, X1 - 0.05, -0.1, 0.0, WZ0 - 0.012, WZ0, "lamp_white", 0)
    box("splashback_slate_panel", X0, X1, Y0, Y0 + 0.012, 1.02, WZ0, "slate_panel", 0)
    # Food pouches on a shelf between the cupboards and the worktop.
    box("pouch_shelf_alloy", 0.62, 1.18, -0.32, -0.16, 1.38, 1.395, "alloy", 0.003)
    pouches, labels = [], []
    for i in range(6):
        x = 0.67 + i * 0.09
        pouches.append(box("p", x - 0.035, x + 0.035, -0.28, -0.2, 1.395, 1.47, "pouch_silver", 0.008))
        labels.append(box("l", x - 0.02, x + 0.02, -0.199, -0.196, 1.42, 1.45, "orange", 0))
    join("food_pouches_pouch_silver", pouches)
    join("pouch_labels_orange", labels)


def galley_bench_unit():
    """A matching 1.2 m base unit: two cupboards and a clear worktop to put
    things on. Lines up with the kitchenette."""
    Y0, Y1 = -0.32, 0.32
    base_units(-0.6, 0.6, Y0, Y1, bays=[("cupboard_left", -0.6, 0.0, "cupboard"), ("cupboard_right", 0.0, 0.6, "cupboard")])
    door_front("door_l", -0.6, 0.0, 0.11, 0.86, Y1 - 0.02)
    door_front("door_r", 0.0, 0.6, 0.11, 0.86, Y1 - 0.02)
    box("label_orange", -0.05, 0.05, Y1 + 0.0, Y1 + 0.004, 0.8, 0.82, "orange", 0)


def wall_screen():
    """A wall screen in a slim frame. The game draws on display_screen_glass
    (status, a view of Mars or Earth); the frame has a status light."""
    box("frame_graphite", -0.58, 0.58, 0.0, 0.045, -0.36, 0.36, "graphite", 0.012)
    box("bezel_dark_alloy", -0.56, 0.56, 0.045, 0.05, -0.34, 0.34, "dark_alloy", 0.004)
    box("display_screen_glass_dark_glass", -0.54, 0.54, 0.05, 0.052, -0.31, 0.31, "dark_glass", 0)
    box("mount_dark_alloy", -0.2, 0.2, -0.0, 0.01, -0.2, 0.2, "dark_alloy", 0)
    box("status_light_screen_green", 0.48, 0.52, 0.05, 0.054, -0.335, -0.325, "screen_green", 0)
    box("brand_strip_orange", -0.52, -0.42, 0.05, 0.053, -0.335, -0.327, "orange", 0)


def mini_gar_y():
    """A toy GAR-Y, about 22 cm tall: white shell, six wheels, mast head with
    glowing eyes and the orange Y badge."""
    s = 0.24
    def S(v): return tuple(c * s for c in v)
    box("chassis_rover_white", *[c * s for c in (-0.32, 0.32, -0.42, 0.42, 0.30, 0.49)], "rover_white", 0.012)
    box("deck_white_painted", *[c * s for c in (-0.345, 0.345, -0.445, 0.445, 0.47, 0.525)], "white_painted", 0.006)
    box("belly_graphite", *[c * s for c in (-0.28, 0.28, -0.38, 0.38, 0.25, 0.31)], "graphite", 0.004)
    join("trim_orange", [box("t", *[c * s for c in (k * 0.323, k * 0.331, -0.36, 0.36, 0.395, 0.425)], "orange", 0.001) for k in (-1, 1)])
    box("solar_cells_solar_cell", *[c * s for c in (-0.275, 0.275, -0.405, -0.035, 0.525, 0.535)], "solar_cell", 0)
    wheels = []
    for y in (0.36, -0.02, -0.38):
        for k in (-1, 1):
            wheels.append(cyl("w", S((k * 0.45, y, 0.165)), 0.165 * s, 0.11 * s, "black_rubber", axis="x", verts=24, bevel=0.003))
    join("wheels_black_rubber", wheels)
    join("hubs_orange", [cyl("h", S((k * 0.51, y, 0.165)), 0.04 * s, 0.01 * s, "orange", axis="x", verts=12) for y in (0.36, -0.02, -0.38) for k in (-1, 1)])
    join("legs_dark_alloy", [rod("r", S((k * 0.39, 0.02, 0.36)), S((k * 0.43, y, 0.17)), 0.016 * s, "dark_alloy", 8) for k in (-1, 1) for y in (0.36, -0.38)])
    cyl("pole_alloy", S((0.0, 0.2, 0.7)), 0.03 * s, 0.32 * s, "alloy", verts=12)
    box("head_rover_white", *[c * s for c in (-0.14, 0.14, 0.12, 0.29, 0.81, 0.97)], "rover_white", 0.01)
    box("visor_dark_glass", *[c * s for c in (-0.12, 0.12, 0.288, 0.298, 0.83, 0.955)], "dark_glass", 0.003)
    join("eyes_eye_glow", [box("e", *[c * s for c in (x - 0.03, x + 0.03, 0.298, 0.304, 0.865, 0.925)], "eye_glow", 0.002) for x in (-0.055, 0.055)])
    box("brow_orange", *[c * s for c in (-0.1, 0.1, 0.27, 0.294, 0.962, 0.978)], "orange", 0.002)
    rod("antenna_dark_alloy", S((-0.24, -0.38, 0.52)), S((-0.24, -0.38, 0.86)), 0.008 * s, "dark_alloy", 8)
    sphere("antenna_tip_orange", S((-0.24, -0.38, 0.87)), 0.02 * s, "orange", segments=10)


MODELS = [
    ("work_desk_blank", work_desk_blank, "floor"),
    ("galley_kitchenette", galley_kitchenette, "floor"),
    ("galley_bench_unit", galley_bench_unit, "floor"),
    ("wall_screen", wall_screen, "wall"),
    ("mini_gar_y", mini_gar_y, "floor"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Crew comforts: blank desk, galley kitchenette and bench units, wall screen, toy GAR-Y"')
exec(_TAIL)
