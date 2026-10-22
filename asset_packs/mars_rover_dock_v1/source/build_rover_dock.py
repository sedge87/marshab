"""Blender (5.x) build script: the GAR-Y rover dock for MARS: HABITAT.

Run:  blender --background --python build_rover_dock.py -- <out_dir>
Writes <out_dir>/models/rover_charger.glb, previews/ and asset_manifest.json
(the furnishings pack's export), for tools/import_asset_pack.py.

A low pad that GAR-Y reverses onto, and a pylon at the back with a battery
screen, a status ring and the charging plug that slides out into GAR-Y's
rear bumper. Shares the furnishings pack's materials and helpers.

Rig part names (data/equipment_rigs.json): charging_plug (slides forward),
service_hatch (hinges up). Collision is the pylon only (pylon-colonly), so
GAR-Y can drive onto the pad.

Metres, floor origin, front faces -Z in glTF (Blender +Y here): the pad is
at the front, the pylon at the back.
"""
import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

COLORS.update({"rover_white": ((0.92, 0.92, 0.89, 1), 0.04, 0.5)})


def rover_charger():
    """GAR-Y's dock: a pad with guide rails and a pylon with the charging plug."""
    # ---- the pad ----
    box("pad_graphite", -0.56, 0.56, -0.46, 0.78, 0.0, 0.035, "graphite", 0.012)
    box("pad_deck_slate_panel", -0.5, 0.5, -0.42, 0.72, 0.035, 0.045, "slate_panel", 0.004)
    join("chevrons_orange", [box("c", -0.04 - 0.16 * k, 0.04 + 0.16 * k, 0.5 - 0.11 * k, 0.53 - 0.11 * k, 0.045, 0.048, "orange", 0)
                             for k in range(3)])
    join("guide_rails_alloy", [box("r", s * 0.56 - 0.03, s * 0.56 + 0.03, -0.42, 0.62, 0.035, 0.09, "alloy", 0.01) for s in (-1, 1)])
    join("rail_lights_lamp_white", [box("l", s * 0.56 - 0.006, s * 0.56 + 0.006, y, y + 0.05, 0.09, 0.094, "lamp_white", 0) for s in (-1, 1) for y in (-0.3, 0.0, 0.3)])
    box("ramp_lip_alloy", -0.5, 0.5, 0.72, 0.8, 0.0, 0.02, "alloy", 0.006)
    # ---- the pylon ----
    box("pylon_rover_white", -0.32, 0.32, -0.72, -0.46, 0.0, 1.0, "rover_white", 0.035)
    box("pylon_cap_white_painted", -0.34, 0.34, -0.74, -0.44, 0.98, 1.03, "white_painted", 0.02)
    box("pylon_base_graphite", -0.3, 0.3, -0.7, -0.48, 0.0, 0.07, "graphite", 0.01)
    # Battery readout and a status ring, facing the pad.
    box("screen_frame_graphite", -0.2, 0.2, -0.462, -0.452, 0.66, 0.9, "graphite", 0.008)
    box("screen_dark_glass", -0.18, 0.18, -0.452, -0.448, 0.68, 0.88, "dark_glass", 0)
    join("battery_bars_screen_green", [box("b", -0.14 + i * 0.058, -0.14 + i * 0.058 + 0.045, -0.448, -0.446, 0.72, 0.84, "screen_green", 0) for i in range(5)])
    torus("status_ring_screen_cyan", (0.0, -0.455, 0.55), 0.05, 0.008, "screen_cyan", axis="y")
    # The charging plug on its housing, at GAR-Y's rear-bumper height.
    cyl("plug_housing_graphite", (0.0, -0.44, 0.345), 0.07, 0.06, "graphite", axis="y", verts=24, bevel=0.008)
    cyl("charging_plug_orange", (0.0, -0.395, 0.345), 0.04, 0.07, "orange", axis="y", verts=20, bevel=0.006)
    cyl("charging_plug_tip_satin_steel", (0.0, -0.355, 0.345), 0.022, 0.02, "satin_steel", axis="y", verts=16)
    # Service hatch on the side (hinges up) and its vents.
    box("service_hatch_warm_panel", 0.32, 0.335, -0.7, -0.48, 0.18, 0.5, "warm_panel", 0.006)
    vent("side_vent", -0.335, -0.32, 0.6, 0.85, -0.6)
    # Power cable from the pylon into the floor, and a GAR-Y badge.
    rod("cable_black_rubber", (0.2, -0.73, 0.15), (0.32, -0.8, 0.01), 0.018, "black_rubber", 12)
    join("badge_orange", [rod("y", (-0.06, -0.452, 0.94), (0.0, -0.452, 0.92), 0.007, "orange", 8), rod("y", (0.06, -0.452, 0.94), (0.0, -0.452, 0.92), 0.007, "orange", 8),
                          rod("y", (0.0, -0.452, 0.92), (0.0, -0.452, 0.895), 0.007, "orange", 8)])
    # Collision for the pylon only (Godot turns "-colonly" meshes into a static shape).
    col = box("pylon-colonly", -0.34, 0.34, -0.74, -0.44, 0.0, 1.03, "graphite", 0)
    col.name = "pylon-colonly"


MODELS = [("rover_charger", rover_charger, "floor")]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"GAR-Y rover dock: pad, pylon and charging plug, same materials as the furnishings pack"')
exec(_TAIL)
