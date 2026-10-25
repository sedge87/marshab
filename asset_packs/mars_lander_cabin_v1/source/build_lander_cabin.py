"""Blender (5.x) build script: Lander Cabin pack for OUTPOST ONE: MARS (v1).

Run:  blender --background --python build_lander_cabin.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

From the 26 Oct playtest: the crew lander's cabin had office chairs on
casters, which would roll about and crash on touchdown. A landing seat is a
reclined crew couch bolted to the deck: floor rails and a base plate with
visible bolts, a shock-absorbing pedestal, a white bucket shell with head
wings, teal cushions, a five-point harness (the orange buckle is its one
accent), armrests with a small control pad, and a footrest bar. Shares the
furnishings pack's materials, bevels and export (docs/house-style.md).

Metres, floor origin, front faces -Z in glTF (Blender +Y here).
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({"amber_status": ((0.95, 0.72, 0.25, 1), 0.0, 0.35)})
GLOW.update({"amber_status": 1.2})


def recline(objs, pivot, degrees):
    """Tilt parts back (their tops towards -Y) about a hinge along X."""
    p = Vector(pivot)
    m = Matrix.Translation(p) @ Matrix.Rotation(math.radians(degrees), 4, "X") @ Matrix.Translation(-p)
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def landing_seat():
    """A crew couch for touchdown, bolted to the deck."""
    W = 0.3
    # Bolted to the deck: a graphite base plate on two floor rails.
    box("base_plate_graphite", -0.34, 0.34, -0.5, 0.46, 0.0, 0.025, "graphite", 0.006)
    for side in (-1, 1):
        box(f"rail_{'l' if side < 0 else 'r'}_dark_alloy", side * 0.22 - 0.035, side * 0.22 + 0.035, -0.46, 0.42, 0.025, 0.06, "dark_alloy", 0.006)
    join("bolts_satin_steel", [cyl("b", (x, y, 0.064), 0.012, 0.01, "satin_steel", verts=10) for x in (-0.22, 0.22) for y in (-0.4, -0.05, 0.36)])
    # The pedestal: two struts and a shock absorber.
    for side in (-1, 1):
        box(f"strut_{'l' if side < 0 else 'r'}_dark_alloy", side * 0.22 - 0.03, side * 0.22 + 0.03, -0.12, 0.08, 0.06, 0.38, "dark_alloy", 0.008)
    cyl("damper_body_graphite", (0, -0.02, 0.17), 0.055, 0.2, "graphite", verts=24, bevel=0.006)
    rod("damper_rod_satin_steel", (0, -0.02, 0.27), (0, -0.02, 0.38), 0.022, "satin_steel")
    torus("damper_spring_satin_steel", (0, -0.02, 0.3), 0.04, 0.006, "satin_steel")
    box("seat_frame_dark_alloy", -W, W, -0.22, 0.3, 0.38, 0.43, "dark_alloy", 0.01)
    # The seat: a white bucket with side bolsters and a teal cushion.
    box("seat_shell_white_painted", -W, W, -0.22, 0.32, 0.43, 0.49, "white_painted", 0.02)
    for side in (-1, 1):
        box(f"seat_bolster_{'l' if side < 0 else 'r'}_white_painted", side * W - 0.03, side * W + 0.02, -0.2, 0.32, 0.49, 0.6, "white_painted", 0.015)
    cushion("seat_cushion_teal_soft", -0.255, 0.255, -0.18, 0.3, 0.49, 0.565)
    # Lap belts and crotch strap to the buckle.
    for side in (-1, 1):
        box(f"lap_belt_{'l' if side < 0 else 'r'}_black_rubber", min(side * 0.25, side * 0.04), max(side * 0.25, side * 0.04), 0.02, 0.07, 0.565, 0.575, "black_rubber", 0.002)
    box("crotch_strap_black_rubber", -0.025, 0.025, 0.07, 0.28, 0.565, 0.575, "black_rubber", 0.002)
    cyl("buckle_orange", (0, 0.045, 0.582), 0.045, 0.02, "orange", verts=24, bevel=0.004)
    # The back, head wings and shoulder straps, reclined 18 degrees.
    back = [
        box("back_shell_white_painted", -W, W, -0.28, -0.2, 0.47, 1.18, "white_painted", 0.02),
        cushion("back_cushion_teal_soft", -0.245, 0.245, -0.2, -0.12, 0.57, 1.0),
        cushion("head_cushion_teal_soft", -0.16, 0.16, -0.2, -0.13, 1.02, 1.17),
    ]
    for side in (-1, 1):
        s = "l" if side < 0 else "r"
        back.append(box(f"back_wing_{s}_white_painted", side * W - 0.03, side * W + 0.02, -0.26, -0.08, 0.55, 0.98, "white_painted", 0.015))
        back.append(box(f"head_wing_{s}_white_painted", side * 0.17 - 0.035 if side < 0 else side * 0.17, side * 0.17 if side < 0 else side * 0.17 + 0.035, -0.26, -0.04, 1.0, 1.2, "white_painted", 0.012))
        back.append(box(f"shoulder_strap_{s}_black_rubber", side * 0.13 - 0.025, side * 0.13 + 0.025, -0.125, -0.112, 0.62, 1.0, "black_rubber", 0.002))
    recline(back, (0, -0.2, 0.49), 18)
    # Armrests on posts; a small control pad on the right one.
    for side in (-1, 1):
        s = "l" if side < 0 else "r"
        box(f"arm_post_{s}_dark_alloy", side * 0.345 - 0.02, side * 0.345 + 0.02, 0.0, 0.05, 0.43, 0.67, "dark_alloy", 0.006)
        box(f"armrest_{s}_graphite", side * 0.345 - 0.035, side * 0.345 + 0.035, -0.14, 0.24, 0.67, 0.72, "graphite", 0.012)
    box("control_pad_screen_cyan", 0.32, 0.37, 0.12, 0.21, 0.72, 0.726, "screen_cyan", 0.002)
    sphere("status_light_amber_status", (0.345, 0.225, 0.726), 0.007, "amber_status", segments=10)
    # Footrest bar on two stays from the seat frame.
    for side in (-1, 1):
        rod(f"foot_stay_{'l' if side < 0 else 'r'}_dark_alloy", (side * 0.22, 0.28, 0.4), (side * 0.22, 0.44, 0.18), 0.016, "dark_alloy")
    rod("footrest_satin_steel", (-0.24, 0.44, 0.18), (0.24, 0.44, 0.18), 0.02, "satin_steel")


MODELS = [
    ("landing_seat", landing_seat, "floor"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Lander cabin: a landing seat bolted to the deck"')
exec(_TAIL)
