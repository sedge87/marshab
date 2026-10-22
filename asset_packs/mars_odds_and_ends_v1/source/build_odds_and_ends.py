"""Blender (5.x) build script: Odds & Ends pack for MARS: HABITAT (v1).

Run:  blender --background --python build_odds_and_ends.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

Small personal and work items the crew can put on tables, desks, shelves and
crates: a mug, a tablet, books, a chess set, a zero-g plush and so on. They
share the furnishings pack's materials, bevels and export (its helpers are
loaded from ../../mars_habitat_furnishings_v1/source/build_furnishings.py) so
they sit in the same rooms without looking out of place.

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
    "paper": ((0.93, 0.90, 0.80, 1), .0, .85),
    "coffee": ((0.20, 0.11, 0.06, 1), .0, .25),
    "regolith": ((0.62, 0.27, 0.14, 1), .0, .95),
    "plush_tan": ((0.78, 0.60, 0.42, 1), .0, .98),
    "plush_white": ((0.92, 0.92, 0.90, 1), .0, .98),
    "spruce": ((0.86, 0.68, 0.42, 1), .02, .45),
    "book_red": ((0.62, 0.17, 0.15, 1), .02, .7),
    "book_navy": ((0.14, 0.22, 0.38, 1), .02, .7),
    "earth_blue": ((0.20, 0.45, 0.85, 1), .0, .3),
    "water": ((0.45, 0.70, 0.90, 0.55), .0, .1),
})
GLOW.update({"earth_blue": 0.6})


def tilt(obj, angle, axis="X", pivot=(0, 0, 0)):
    """Rotates an object about a pivot (radians) and applies it."""
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    old = bpy.context.scene.tool_settings.transform_pivot_point
    bpy.context.scene.tool_settings.transform_pivot_point = "CURSOR"
    bpy.ops.transform.rotate(value=angle, orient_axis=axis, center_override=pivot)
    bpy.context.scene.tool_settings.transform_pivot_point = old
    bpy.ops.object.transform_apply(rotation=True, location=False)
    bpy.context.scene.cursor.location = (0, 0, 0)
    return obj


def crew_mug():
    """A crew mug with a mission band: in Mars gravity a cup works again."""
    cyl("mug_body_white_painted", (0, 0, 0.05), 0.042, 0.1, "white_painted", verts=40, bevel=0.004)
    cyl("mug_band_orange", (0, 0, 0.068), 0.0425, 0.016, "orange", verts=40)
    torus("mug_handle_white_painted", (0.052, 0, 0.052), 0.026, 0.007, "white_painted", axis="y")
    cyl("coffee_coffee", (0, 0, 0.094), 0.037, 0.004, "coffee", verts=32)
    cyl("mug_patch_teal", (0, 0.042, 0.04), 0.012, 0.003, "teal", axis="y", verts=20)


def crew_tablet():
    """A procedures tablet leaning on its folding stand."""
    parts = []
    body = box("tablet_body_graphite", -0.13, 0.13, -0.006, 0.006, 0.0, 0.18, "graphite", 0.008)
    screen = box("tablet_screen_dark_glass", -0.12, 0.12, 0.006, 0.008, 0.01, 0.17, "dark_glass", 0)
    tiles = join("tablet_tiles_screen_cyan", [box("t", x, x + 0.05, 0.008, 0.009, z, z + 0.035, "screen_cyan", 0) for x in (-0.105, -0.045, 0.015) for z in (0.03, 0.08, 0.125)])
    bar = box("tablet_bar_orange", 0.07, 0.105, 0.008, 0.009, 0.03, 0.16, "orange", 0)
    for obj in (body, screen, tiles, bar):
        tilt(obj, math.radians(-22), "X", (0, 0, 0))
    box("stand_foot_dark_alloy", -0.1, 0.1, -0.02, 0.03, 0.0, 0.01, "dark_alloy", 0.004)
    stand = box("stand_leg_dark_alloy", -0.08, 0.08, -0.005, 0.0, 0.0, 0.12, "dark_alloy", 0.002)
    tilt(stand, math.radians(28), "X", (0, -0.06, 0))


def crew_laptop():
    """An open laptop: the ISS runs on dozens of them."""
    cabinet_base = box("laptop_base_graphite", -0.17, 0.17, -0.12, 0.12, 0.0, 0.02, "graphite", 0.006)
    keys = [box("k", -0.15 + i * 0.0215, -0.15 + i * 0.0215 + 0.017, -0.06 + j * 0.022, -0.06 + j * 0.022 + 0.017, 0.02, 0.023, "dark_alloy", 0)
            for i in range(14) for j in range(5)]
    join("laptop_keys_dark_alloy", keys)
    box("laptop_pad_slate_panel", -0.05, 0.05, -0.11, -0.065, 0.02, 0.0215, "slate_panel", 0.002)
    lid = box("laptop_lid_graphite", -0.17, 0.17, 0.11, 0.122, 0.0, 0.22, "graphite", 0.006)
    screen = box("laptop_screen_dark_glass", -0.155, 0.155, 0.106, 0.11, 0.015, 0.205, "dark_glass", 0)
    plot = join("laptop_plot_screen_green", [box("p", -0.13 + i * 0.026, -0.13 + i * 0.026 + 0.02, 0.105, 0.106, 0.03, 0.03 + h, "screen_green", 0)
                                           for i, h in enumerate((0.04, 0.07, 0.06, 0.1, 0.12, 0.09, 0.14, 0.13, 0.15, 0.11))])
    for obj in (lid, screen, plot):
        tilt(obj, math.radians(-14), "X", (0, 0.116, 0.01))
    box("laptop_sticker_orange", -0.14, -0.1, 0.123, 0.124, 0.15, 0.19, "orange", 0)


def paper_books():
    """Three paper books: heavy, but crews still ask for them."""
    specs = [(0.0, 0.034, 0.22, 0.15, "book_navy", 0.0), (0.034, 0.028, 0.2, 0.14, "book_red", 0.12), (0.062, 0.024, 0.18, 0.13, "teal", -0.08)]
    for i, (z, t, w, d, cover, turn) in enumerate(specs):
        c = box(f"book{i}_cover_{cover}", -w / 2, w / 2, -d / 2, d / 2, z, z + t, cover, 0.004)
        p = box(f"book{i}_pages_paper", -w / 2 + 0.006, w / 2 + 0.002, -d / 2 + 0.004, d / 2 - 0.004, z + 0.003, z + t - 0.003, "paper", 0.001)
        s = box(f"book{i}_title_amber", -w / 2 + 0.03, -w / 2 + 0.09, -d / 2 - 0.001, -d / 2, z + t * 0.35, z + t * 0.65, "amber", 0)
        for obj in (c, p, s):
            tilt(obj, turn, "Z", (0, 0, 0))


def photo_frame():
    """A framed photo of Earth as seen from Mars: a small blue star."""
    parts = [box("frame_alloy", -0.09, 0.09, -0.008, 0.008, 0.0, 0.24, "alloy", 0.006)]
    photo = box("photo_graphite", -0.075, 0.075, 0.008, 0.01, 0.015, 0.225, "graphite", 0)
    earth = cyl("earth_earth_blue", (0.0, 0.011, 0.14), 0.035, 0.003, "earth_blue", axis="y", verts=32)
    land = join("land_leaf_light", [cyl("l", (x, 0.0125, z), r, 0.002, "leaf_light", axis="y", verts=12) for x, z, r in ((-0.01, 0.15, 0.012), (0.015, 0.13, 0.009))])
    cloud = cyl("cloud_white_painted", (0.012, 0.0127, 0.158), 0.008, 0.002, "white_painted", axis="y", verts=12)
    horizon = box("horizon_regolith", -0.075, 0.075, 0.009, 0.011, 0.015, 0.06, "regolith", 0)
    for obj in parts + [photo, earth, land, cloud, horizon]:
        tilt(obj, math.radians(-12), "X", (0, 0, 0))
    leg = box("leg_dark_alloy", -0.015, 0.015, -0.004, 0.0, 0.0, 0.16, "dark_alloy", 0.002)
    tilt(leg, math.radians(25), "X", (0, -0.03, 0))


def chess_set():
    """A magnetic chess set, mid-game: crews have played Earth by radio."""
    box("board_frame_graphite", -0.16, 0.16, -0.16, 0.16, 0.0, 0.022, "graphite", 0.006)
    light, dark = [], []
    for i in range(8):
        for j in range(8):
            x0 = -0.14 + i * 0.035; y0 = -0.14 + j * 0.035
            (light if (i + j) % 2 == 0 else dark).append(box("s", x0, x0 + 0.035, y0, y0 + 0.035, 0.022, 0.025, "paper" if (i + j) % 2 == 0 else "slate_panel", 0))
    join("squares_paper", light)
    join("squares_slate_panel", dark)
    def square(i, j):
        return (-0.1225 + i * 0.035, -0.1225 + j * 0.035)
    whites, blacks = [], []
    for side, row, pawn_row, mat, out in (("w", 0, 1, "white_painted", whites), ("b", 7, 6, "graphite", blacks)):
        for i in (0, 2, 3, 5, 6):
            x, y = square(i, pawn_row if i != 3 else (pawn_row + (1 if side == "w" else -1)))
            out.append(cyl("p", (x, y, 0.035), 0.009, 0.02, mat, verts=16, radius2=0.006))
            out.append(sphere("p", (x, y, 0.05), 0.0075, mat, segments=12))
        for i, h in ((4, 0.05), (3, 0.045), (0, 0.032), (7, 0.032)):
            x, y = square(i, row)
            out.append(cyl("k", (x, y, 0.025 + h / 2), 0.011, h, mat, verts=16, radius2=0.007))
            out.append(sphere("k", (x, y, 0.027 + h), 0.008, mat, segments=12))
        x, y = square(4, row)
        out.append(box("c", x - 0.002, x + 0.002, y - 0.002, y + 0.002, 0.08, 0.095, mat, 0))
    join("pieces_white_painted", whites)
    join("pieces_graphite", blacks)


def zero_g_plush():
    """A plush bear in a little suit: when it floats, you've reached orbit."""
    sphere("body_plush_white", (0, 0, 0.075), 0.06, "plush_white", scale=(1.0, 0.85, 1.05), segments=20)
    sphere("head_plush_tan", (0, 0, 0.165), 0.05, "plush_tan", segments=20)
    join("ears_plush_tan", [sphere("e", (x, 0, 0.205), 0.018, "plush_tan", segments=12) for x in (-0.035, 0.035)])
    sphere("snout_plush_white", (0, 0.042, 0.155), 0.02, "plush_white", scale=(1.0, 0.7, 0.8), segments=12)
    join("eyes_graphite", [sphere("e", (x, 0.044, 0.175), 0.006, "graphite", segments=8) for x in (-0.018, 0.018)] + [sphere("n", (0, 0.056, 0.158), 0.006, "graphite", segments=8)])
    join("limbs_plush_white", [sphere("a", (x, 0.01, 0.09), 0.022, "plush_white", scale=(1.0, 1.0, 1.4), segments=12) for x in (-0.065, 0.065)]
         + [sphere("l", (x, 0.02, 0.02), 0.024, "plush_white", scale=(1.0, 1.3, 0.8), segments=12) for x in (-0.03, 0.03)])
    cyl("patch_orange", (0, 0.052, 0.09), 0.016, 0.003, "orange", axis="y", verts=20)
    torus("collar_teal", (0, 0, 0.123), 0.032, 0.007, "teal")


def herb_pot():
    """A little pot of basil: fresh leaves for the galley."""
    cyl("pot_white_painted", (0, 0, 0.045), 0.06, 0.09, "white_painted", verts=32, bevel=0.006, radius2=0.07)
    cyl("pot_band_teal", (0, 0, 0.07), 0.068, 0.012, "teal", verts=32)
    cyl("soil_soil", (0, 0, 0.087), 0.062, 0.006, "soil", verts=32)
    stems, leaves = [], []
    for i in range(9):
        a = i * 2.4
        r = 0.02 + 0.012 * (i % 3)
        top = (r * math.cos(a), r * math.sin(a), 0.13 + 0.02 * (i % 4))
        stems.append(rod("s", (0, 0, 0.088), top, 0.003, "leaf_green", 6))
        leaves.append(sphere("l", top, 0.022, "leaf_light", scale=(1.0, 0.6, 0.35), segments=10))
    join("stems_leaf_green", stems)
    join("leaves_leaf_light", leaves)


def desk_lamp():
    """An LED desk lamp on a jointed arm."""
    cyl("base_graphite", (0, 0, 0.01), 0.07, 0.02, "graphite", verts=32, bevel=0.004)
    cyl("switch_orange", (0.04, 0.03, 0.022), 0.008, 0.006, "orange", verts=12)
    join("arm_alloy", [rod("a", (0, 0, 0.02), (-0.03, 0, 0.24), 0.008, "alloy"), rod("b", (-0.03, 0, 0.24), (0.1, 0, 0.32), 0.007, "alloy")])
    join("joints_dark_alloy", [sphere("j", (-0.03, 0, 0.24), 0.013, "dark_alloy", segments=12), sphere("j", (0, 0, 0.02), 0.012, "dark_alloy", segments=12)])
    head = cyl("head_white_painted", (0.13, 0, 0.3), 0.045, 0.05, "white_painted", verts=32, radius2=0.025, bevel=0.003)
    tilt(head, math.radians(-25), "Y", (0.13, 0, 0.3))
    glow = cyl("bulb_lamp_white", (0.13, 0, 0.276), 0.038, 0.004, "lamp_white", verts=32)
    tilt(glow, math.radians(-25), "Y", (0.13, 0, 0.3))


def water_bottle():
    """A refillable water bottle (every litre on Mars gets recycled)."""
    cyl("bottle_water", (0, 0, 0.1), 0.035, 0.2, "water", verts=32, bevel=0.006)
    cyl("water_level_cool_blue", (0, 0, 0.065), 0.031, 0.12, "cool_blue", verts=32)
    cyl("cap_graphite", (0, 0, 0.215), 0.026, 0.03, "graphite", verts=24, bevel=0.004)
    torus("loop_graphite", (0, 0, 0.236), 0.014, 0.004, "graphite", axis="x")
    cyl("label_orange", (0, 0, 0.13), 0.0355, 0.035, "orange", verts=32)


def sample_jars():
    """Three sealed regolith sample jars in a carry tray."""
    box("tray_alloy", -0.13, 0.13, -0.05, 0.05, 0.0, 0.03, "alloy", 0.006)
    box("tray_handle_dark_alloy", -0.11, 0.11, -0.006, 0.006, 0.03, 0.15, "dark_alloy", 0.004)
    jars, fills, lids, labels = [], [], [], []
    for x, h in ((-0.085, 0.05), (0.0, 0.07), (0.085, 0.04)):
        x = x if x == 0.0 else x
        jars.append(cyl("j", (x, -0.0, 0.08), 0.032, 0.11, "iv_clear", verts=24))
        fills.append(cyl("f", (x, 0.0, 0.025 + h / 2), 0.029, h, "regolith", verts=24))
        lids.append(cyl("l", (x, 0.0, 0.142), 0.034, 0.016, "orange", verts=24, bevel=0.003))
        labels.append(box("t", x - 0.018, x + 0.018, 0.031, 0.033, 0.085, 0.11, "white_painted", 0))
    join("jars_iv_clear", jars)
    join("samples_regolith", fills)
    join("lids_orange", lids)
    join("labels_white_painted", labels)


def toolbox():
    """A sealed toolbox: Mars dust gets into everything."""
    box("box_orange", -0.2, 0.2, -0.1, 0.1, 0.0, 0.15, "orange", 0.012)
    box("lid_graphite", -0.205, 0.205, -0.105, 0.105, 0.15, 0.18, "graphite", 0.01)
    gasket("seal_black_rubber", -0.2, 0.2, 0.145, 0.152, 0.1, w=0.006)
    join("handle_satin_steel", [rod("h", (-0.1, 0, 0.215), (0.1, 0, 0.215), 0.01, "satin_steel")] + [rod("s", (x, 0, 0.18), (x, 0, 0.215), 0.008, "satin_steel") for x in (-0.1, 0.1)])
    join("latches_satin_steel", [box("l", x - 0.02, x + 0.02, 0.1, 0.112, 0.12, 0.17, "satin_steel", 0.003) for x in (-0.13, 0.13)])
    box("label_white_painted", -0.06, 0.06, 0.1, 0.102, 0.05, 0.1, "white_painted", 0)


def ration_packs():
    """A stack of food pouches: built to last five years for Mars."""
    stripes = ["orange", "bright_green", "cool_blue", "amber"]
    for i, (dx, turn) in enumerate(((0, 0.0), (0.01, 0.08), (-0.008, -0.06), (0.006, 0.14))):
        z = i * 0.035
        p = cushion(f"pouch{i}_pouch_silver", -0.1 + dx, 0.1 + dx, -0.07, 0.07, z, z + 0.035, "pouch_silver")
        s = box(f"pouch{i}_label_{stripes[i]}", -0.04 + dx, 0.04 + dx, -0.071, -0.069, z + 0.008, z + 0.027, stripes[i], 0)
        for obj in (p, s):
            tilt(obj, turn, "Z", (0, 0, 0))


def guitar():
    """A guitar on a floor stand: there has been one on the ISS since 2001."""
    body_parts = [sphere("b", (0, 0, 0.3), 0.19, "spruce", scale=(1.0, 0.45, 1.0), segments=28),
                  sphere("b", (0, 0, 0.53), 0.14, "spruce", scale=(1.0, 0.45, 1.0), segments=28)]
    body = join("guitar_body_spruce", body_parts)
    hole = cyl("sound_hole_graphite", (0, 0.082, 0.45), 0.045, 0.006, "graphite", axis="y", verts=28)
    bridge = box("bridge_graphite", -0.06, 0.06, 0.08, 0.092, 0.27, 0.295, "graphite", 0.004)
    neck = box("neck_dark_alloy", -0.025, 0.025, -0.02, 0.03, 0.62, 1.0, "dark_alloy", 0.008)
    head = box("headstock_dark_alloy", -0.04, 0.04, -0.015, 0.025, 1.0, 1.12, "dark_alloy", 0.01)
    strings = join("strings_satin_steel", [rod("s", (x, 0.035, 0.28), (x * 0.6, 0.035, 1.06), 0.0012, "satin_steel", 6) for x in (-0.018, -0.011, -0.004, 0.004, 0.011, 0.018)])
    pegs = join("pegs_satin_steel", [cyl("p", (sx * 0.052, 0.005, z), 0.006, 0.025, "satin_steel", axis="x", verts=8) for sx in (-1, 1) for z in (1.03, 1.065, 1.1)])
    for obj in (body, hole, bridge, neck, head, strings, pegs):
        tilt(obj, math.radians(-12), "X", (0, 0, 0.12))
    stand = [rod("l", (0, 0.0, 0.0), (x, 0.0, 0.0), 0.01, "graphite") for x in (-0.18, 0.18)]
    stand += [rod("f", (0, -0.2, 0.01), (0, 0.15, 0.01), 0.01, "graphite"), rod("u", (0, -0.2, 0.01), (0, -0.12, 0.75), 0.01, "graphite")]
    stand += [rod("c", (x, 0.08, 0.02), (x, 0.08, 0.13), 0.012, "black_rubber") for x in (-0.14, 0.14)]
    join("stand_graphite", stand)


MODELS = [
    ("crew_mug", crew_mug, "floor"),
    ("crew_tablet", crew_tablet, "floor"),
    ("crew_laptop", crew_laptop, "floor"),
    ("paper_books", paper_books, "floor"),
    ("photo_frame", photo_frame, "floor"),
    ("chess_set", chess_set, "floor"),
    ("zero_g_plush", zero_g_plush, "floor"),
    ("herb_pot", herb_pot, "floor"),
    ("desk_lamp", desk_lamp, "floor"),
    ("water_bottle", water_bottle, "floor"),
    ("sample_jars", sample_jars, "floor"),
    ("toolbox", toolbox, "floor"),
    ("ration_packs", ration_packs, "floor"),
    ("guitar", guitar, "floor"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Odds and ends: small personal and work items, same materials as the furnishings pack"')
exec(_TAIL)
