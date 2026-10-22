"""Blender (5.x) build script: Observation pack for MARS: HABITAT (v1).

Run:  blender --background --python build_observation.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

The camera mast (backlog item 28): a 6 m pole on a ballasted tripod foot,
with a pan-tilt camera head on top that the game turns a full 360°. Built in
the house style (docs/house-style.md) with the furnishings pack's helpers.

Part names the game uses (scripts/equipment_rig.gd, action "camera"):
  head_yaw_*   the turntable and yoke: they pan round the pole's axis;
  head_tilt_*  the camera body, lens and sunshade: they tilt in the yoke;
  head_tilt_lens_*  the lens (the view starts just in front of it).
Metres, floor origin, front faces -Z in glTF (Blender +Y here).
"""
import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({"status_green": ((0.35, 0.95, 0.55, 1), .0, .3)})
GLOW.update({"status_green": 1.6})

POLE_TOP = 5.7
PAN_Z = POLE_TOP + 0.12      # turntable top
TILT_Z = PAN_Z + 0.26        # the camera's tilt axis


def camera_mast():
    # Foot: three ballast legs and a hub plate, a junction box with a status light.
    legs = []
    for i in range(3):
        a = i * math.tau / 3 + math.pi / 2
        end = (math.cos(a) * 0.85, math.sin(a) * 0.85, 0.05)
        legs.append(rod("leg", (0, 0, 0.32), end, 0.035, "dark_alloy"))
        legs.append(box("pad", end[0] - 0.12, end[0] + 0.12, end[1] - 0.12, end[1] + 0.12, 0.0, 0.06, "graphite", 0.01))
        legs.append(box("ballast", end[0] - 0.09, end[0] + 0.09, end[1] - 0.09, end[1] + 0.09, 0.06, 0.2, "slate_panel", 0.012))
    join("foot_dark_alloy", legs)
    cyl("hub_graphite", (0, 0, 0.3), 0.12, 0.2, "graphite", verts=24, bevel=0.01)
    cabinet("junction", -0.16, 0.16, 0.1, 0.32, 0.55, 1.05, "white_painted", "warm_shell", plinth=False)
    box("junction_label_orange", -0.1, 0.1, 0.32, 0.326, 0.95, 0.99, "orange", 0)
    cyl("status_light_status_green", (0.1, 0.33, 0.62), 0.018, 0.012, "status_green", axis="y", verts=16)
    rod("conduit_black_rubber", (0, 0.12, 0.6), (0, 0.06, 1.2), 0.02, "black_rubber", 10)
    # The pole: two sections with a collar, and climbing rungs.
    cyl("pole_lower_satin_steel", (0, 0, 0.3 + 1.6), 0.07, 3.2, "satin_steel", verts=24)
    cyl("pole_upper_satin_steel", (0, 0, 3.5 + (POLE_TOP - 3.5) / 2), 0.055, POLE_TOP - 3.5, "satin_steel", verts=24)
    cyl("collar_orange", (0, 0, 3.5), 0.085, 0.12, "orange", verts=24, bevel=0.01)
    join("rungs_dark_alloy", [rod("r", (-0.12, 0.0, z), (0.12, 0.0, z), 0.012, "dark_alloy", 8) for z in [1.4 + i * 0.4 for i in range(5)]])
    join("guy_brackets_graphite", [box("g", -0.02 + math.cos(a) * 0.08, 0.02 + math.cos(a) * 0.08, -0.02 + math.sin(a) * 0.08, 0.02 + math.sin(a) * 0.08, 3.3, 3.45, "graphite", 0.004) for a in (0, 2.09, 4.19)])
    # Top: a fixed bearing housing (stays put).
    cyl("bearing_graphite", (0, 0, POLE_TOP + 0.05), 0.11, 0.1, "graphite", verts=28, bevel=0.01)
    # Pans: turntable and yoke.
    cyl("head_yaw_turntable_dark_alloy", (0, 0, PAN_Z - 0.02), 0.13, 0.05, "dark_alloy", verts=32, bevel=0.008)
    join("head_yaw_yoke_white_painted", [box("y", x - 0.025, x + 0.025, -0.06, 0.06, PAN_Z, TILT_Z + 0.06, "white_painted", 0.012) for x in (-0.19, 0.19)])
    join("head_yaw_axles_satin_steel", [cyl("a", (x, 0, TILT_Z), 0.03, 0.03, "satin_steel", axis="x", verts=16) for x in (-0.205, 0.205)])
    # Tilts: the camera body, lens and sunshade (it looks along +Y here, -Z in game).
    box("head_tilt_body_white_painted", -0.15, 0.15, -0.2, 0.22, TILT_Z - 0.1, TILT_Z + 0.1, "white_painted", 0.03)
    box("head_tilt_band_orange", -0.152, 0.152, 0.05, 0.08, TILT_Z - 0.102, TILT_Z + 0.102, "orange", 0.004)
    box("head_tilt_sunshade_graphite", -0.17, 0.17, -0.16, 0.3, TILT_Z + 0.1, TILT_Z + 0.125, "graphite", 0.008)
    cyl("head_tilt_lens_barrel_graphite", (0, 0.26, TILT_Z), 0.07, 0.08, "graphite", axis="y", verts=28, bevel=0.006)
    cyl("head_tilt_lens_dark_glass", (0, 0.302, TILT_Z), 0.055, 0.006, "dark_glass", axis="y", verts=28)
    box("head_tilt_rear_vent_dark_alloy", -0.08, 0.08, -0.205, -0.2, TILT_Z - 0.05, TILT_Z + 0.05, "dark_alloy", 0)
    cyl("head_tilt_tally_status_green", (0.1, 0.221, TILT_Z + 0.07), 0.01, 0.006, "status_green", axis="y", verts=12)


MODELS = [("camera_mast", camera_mast, "floor")]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Observation: the pan-tilt camera mast, in the house style"')
exec(_TAIL)
