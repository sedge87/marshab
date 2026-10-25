"""Blender (5.x) build script: Recreation pack for OUTPOST ONE: MARS (v1).

Run:  blender --background --python build_recreation.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

From the 25 Oct playtest: players build big Living Quarters and have little
fun to put in them. A lounge sofa, a low-gravity bean bag, an arcade
cabinet, a VR station, table football, a telescope for the window, a music
corner, a magnetic dartboard and a shelf of games. Shares the furnishings
pack's materials, bevels and export (docs/house-style.md): white shells,
graphite frames, satin metal, one orange accent each.

Metres, floor origin, front faces -Z in glTF (Blender +Y here). Wall items
hang from a back plate at y = 0, centred on z = 0.
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
    "screen_arcade": ((0.12, 0.32, 0.55, 1), 0.0, 0.3),
    "marquee_lamp": ((1.0, 0.86, 0.62, 1), 0.0, 0.25),
    "vinyl_black_rubber": ((0.05, 0.05, 0.06, 1), 0.1, 0.35),
    "field_teal": ((0.18, 0.42, 0.44, 1), 0.05, 0.7),
    "board_cork_paper": ((0.62, 0.48, 0.32, 1), 0.0, 0.9),
    "game_box_cool_blue": ((0.30, 0.55, 0.78, 1), 0.05, 0.6),
    "game_box_amber": ((0.94, 0.66, 0.22, 1), 0.05, 0.6),
    "game_box_teal": ((0.22, 0.47, 0.51, 1), 0.05, 0.6),
    "button_red": ((0.85, 0.2, 0.18, 1), 0.05, 0.4),
})
GLOW.update({"screen_arcade": 0.9, "marquee_lamp": 1.2})


def lounge_sofa():
    """A three-seat lounge sofa: white shell on a recessed graphite plinth,
    teal cushions, a cup holder in one arm and an orange stripe on the other."""
    W, D = 1.0, 0.44
    box("plinth_graphite", -W + 0.08, W - 0.08, -D + 0.06, D - 0.06, 0.0, 0.1, "graphite", 0.01)
    box("base_white_painted", -W, W, -D, D, 0.1, 0.4, "white_painted", 0.04)
    box("back_white_painted", -W, W, -D, -D + 0.18, 0.4, 0.82, "white_painted", 0.05)
    box("arm_l_white_painted", -W, -W + 0.16, -D, D, 0.4, 0.62, "white_painted", 0.05)
    box("arm_r_white_painted", W - 0.16, W, -D, D, 0.4, 0.62, "white_painted", 0.05)
    seat = (W - 0.16) * 2 / 3
    for i in range(3):
        x0 = -W + 0.16 + i * seat
        cushion(f"seat_{i}_teal_soft", x0 + 0.01, x0 + seat - 0.01, -D + 0.18, D - 0.02, 0.4, 0.52)
        cushion(f"back_{i}_teal_soft", x0 + 0.02, x0 + seat - 0.02, -D + 0.18, -D + 0.32, 0.5, 0.8)
    box("arm_stripe_orange", W - 0.16, W, D - 0.004, D + 0.002, 0.5, 0.54, "orange", 0.002)
    cyl("cup_holder_graphite", (-W + 0.08, D - 0.12, 0.6), 0.045, 0.05, "graphite", verts=24)
    cyl("cup_ring_satin_steel", (-W + 0.08, D - 0.12, 0.623), 0.05, 0.006, "satin_steel", verts=24)
    join("feet_dark_alloy", [cyl("f", (x, y, 0.02), 0.03, 0.04, "dark_alloy", verts=12) for x in (-W + 0.12, W - 0.12) for y in (-D + 0.1, D - 0.1)])


def bean_bag():
    """A big low-gravity bean bag: a soft teal blob with a dimple where you
    sit, piped seams and an orange carry loop."""
    sphere("bag_teal_soft", (0, 0, 0.3), 0.46, "teal_soft", scale=(1.0, 1.0, 0.66), segments=32)
    sphere("seat_dimple_teal_soft", (0, 0.08, 0.5), 0.3, "teal_soft", scale=(1.0, 0.9, 0.35), segments=24)
    torus("seam_graphite", (0, 0, 0.3), 0.455, 0.008, "graphite")
    torus("loop_orange", (0, -0.42, 0.52), 0.06, 0.012, "orange", axis="x")
    cyl("base_black_rubber", (0, 0, 0.012), 0.34, 0.024, "black_rubber", verts=32)


def arcade_cabinet():
    """A retro arcade cabinet: white sides, a graphite front, a glowing
    screen ("MARS LANDER"), a joystick with an orange ball and three buttons,
    a lit marquee and a coin door."""
    W, D = 0.34, 0.36
    for side in (-1, 1):
        x = side * (W - 0.02)
        join(f"side_{'l' if side < 0 else 'r'}_white_painted", [
            box("s", x - 0.02, x + 0.02, -D, D, 0.0, 0.95, "white_painted", 0.01),
            box("s", x - 0.02, x + 0.02, -D, 0.05, 0.95, 1.86, "white_painted", 0.01),
            box("s", x - 0.02, x + 0.02, 0.05, 0.3, 0.95, 1.12, "white_painted", 0.01)])
    box("plinth_graphite", -W + 0.04, W - 0.04, -D + 0.04, D - 0.02, 0.0, 0.08, "graphite", 0.006)
    box("lower_front_graphite", -W + 0.04, W - 0.04, D - 0.06, D - 0.02, 0.08, 0.86, "graphite", 0.006)
    box("coin_door_slate_panel", -0.1, 0.1, D - 0.02, D - 0.01, 0.4, 0.62, "slate_panel", 0.006)
    join("coin_slots_amber", [box("c", x - 0.012, x + 0.012, D - 0.012, D - 0.006, 0.54, 0.58, "amber", 0.002) for x in (-0.04, 0.04)])
    # The control panel, sloping up towards the player.
    box("control_panel_dark_alloy", -W + 0.04, W - 0.04, 0.1, D, 0.86, 0.96, "dark_alloy", 0.01)
    rod("joystick_satin_steel", (-0.12, 0.24, 0.96), (-0.12, 0.24, 1.06), 0.008, "satin_steel")
    sphere("joystick_ball_orange", (-0.12, 0.24, 1.07), 0.025, "orange", segments=16)
    for i, mat in enumerate(("button_red", "amber", "screen_green")):
        cyl(f"button_{i}_{mat}", (0.04 + i * 0.07, 0.22, 0.965), 0.022, 0.016, mat, verts=20)
    box("screen_bezel_graphite", -W + 0.04, W - 0.04, -0.02, 0.06, 1.1, 1.62, "graphite", 0.01)
    box("arcade_screen_screen_arcade", -W + 0.08, W - 0.08, 0.06, 0.065, 1.15, 1.57, "screen_arcade", 0.0)
    box("marquee_marquee_lamp", -W + 0.04, W - 0.04, 0.0, 0.05, 1.68, 1.84, "marquee_lamp", 0.004)
    box("marquee_band_orange", -W + 0.04, W - 0.04, 0.05, 0.055, 1.66, 1.68, "orange", 0.0)
    box("top_white_painted", -W, W, -D, 0.06, 1.84, 1.88, "white_painted", 0.01)
    box("back_slate_panel", -W + 0.02, W - 0.02, -D, -D + 0.02, 0.08, 1.84, "slate_panel", 0.004)
    vent("vent_dark_alloy", -0.18, 0.18, 0.12, 0.3, D - 0.018)


def vr_station():
    """A VR station: a round rubber mat with a teal boundary ring, a mast
    with a cable boom so you can't trip, a headset on a hook and two
    controllers in a cradle."""
    cyl("mat_black_rubber", (0, 0, 0.006), 0.78, 0.012, "black_rubber", verts=48)
    torus("boundary_teal", (0, 0, 0.014), 0.7, 0.012, "teal")
    box("mast_foot_graphite", -0.86, -0.66, -0.12, 0.12, 0.0, 0.06, "graphite", 0.01)
    rod("mast_dark_alloy", (-0.76, 0, 0.06), (-0.76, 0, 2.05), 0.03, "dark_alloy")
    rod("boom_dark_alloy", (-0.76, 0, 2.02), (0.0, 0, 2.02), 0.022, "dark_alloy")
    cyl("swivel_satin_steel", (0, 0, 1.99), 0.04, 0.06, "satin_steel", verts=20)
    rod("cable_black_rubber", (0.0, 0.0, 1.96), (-0.6, 0.02, 1.25), 0.008, "black_rubber")
    # The headset, hanging from a hook on the mast.
    rod("hook_satin_steel", (-0.76, 0.03, 1.3), (-0.68, 0.06, 1.3), 0.008, "satin_steel")
    box("headset_white_painted", -0.75, -0.55, 0.06, 0.18, 1.12, 1.24, "white_painted", 0.03)
    box("visor_dark_glass", -0.74, -0.56, 0.18, 0.19, 1.14, 1.22, "dark_glass", 0.01)
    box("strap_graphite", -0.73, -0.57, 0.02, 0.06, 1.2, 1.26, "graphite", 0.01)
    box("headset_band_orange", -0.75, -0.55, 0.12, 0.13, 1.235, 1.245, "orange", 0.0)
    # The controller cradle.
    box("cradle_graphite", -0.86, -0.66, 0.14, 0.3, 0.9, 0.96, "graphite", 0.01)
    for i, y in enumerate((0.18, 0.26)):
        cyl(f"controller_{i}_white_painted", (-0.76, y, 1.0), 0.025, 0.12, "white_painted", verts=16)
    box("status_light_screen_green", -0.79, -0.73, 0.3, 0.305, 0.92, 0.94, "screen_green", 0.0)


def table_football():
    """Table football: a white table with a teal pitch under a clear top,
    eight steel rods with rubber grips, orange and white teams, and goals."""
    L, W, H = 0.7, 0.38, 0.9
    # An open box: four walls round the pitch, so you see the game inside.
    join("body_white_painted", [
        box("w", -L, L, -W, -W + 0.04, H - 0.2, H, "white_painted", 0.01),
        box("w", -L, L, W - 0.04, W, H - 0.2, H, "white_painted", 0.01),
        box("w", -L, -L + 0.04, -W, W, H - 0.2, H, "white_painted", 0.01),
        box("w", L - 0.04, L, -W, W, H - 0.2, H, "white_painted", 0.01),
        box("w", -L, L, -W, W, H - 0.2, H - 0.17, "white_painted", 0.01)])
    box("pitch_field_teal", -L + 0.04, L - 0.04, -W + 0.04, W - 0.04, H - 0.17, H - 0.16, "field_teal", 0.0)
    box("halfway_line_white_painted", -0.005, 0.005, -W + 0.06, W - 0.06, H - 0.16, H - 0.158, "white_painted", 0)
    torus("centre_circle_white_painted", (0, 0, H - 0.159), 0.07, 0.003, "white_painted")
    for side in (-1, 1):
        box(f"goal_{'l' if side < 0 else 'r'}_graphite", side * L - 0.02, side * L + 0.02, -0.1, 0.1, H - 0.17, H - 0.09, "graphite", 0.004)
    xs = [-0.55, -0.4, -0.24, -0.08, 0.08, 0.24, 0.4, 0.55]
    rods, grips, orange, white = [], [], [], []
    for i, x in enumerate(xs):
        rods.append(rod("r", (x, -W - 0.12, H - 0.08), (x, W + 0.12, H - 0.08), 0.007, "satin_steel"))
        grips.append(cyl("g", (x, (W + 0.17) * (1 if i % 2 == 0 else -1), H - 0.08), 0.022, 0.1, "black_rubber", axis="y", verts=16))
        team = orange if i % 2 == 0 else white
        count = (1, 2, 3, 2, 2, 3, 2, 1)[i]
        for k in range(count):
            y = (k - (count - 1) / 2) * 0.14
            team.append(box("p", x - 0.012, x + 0.012, y - 0.02, y + 0.02, H - 0.15, H - 0.05, "orange" if team is orange else "white_painted", 0.006))
    join("rods_satin_steel", rods)
    join("grips_black_rubber", grips)
    join("team_orange", orange)
    join("team_white_painted", white)
    join("legs_dark_alloy", [box("l", x - 0.03, x + 0.03, y - 0.03, y + 0.03, 0.0, H - 0.2, "dark_alloy", 0.008) for x in (-L + 0.06, L - 0.06) for y in (-W + 0.06, W - 0.06)])
    join("feet_black_rubber", [cyl("f", (x, y, 0.01), 0.04, 0.02, "black_rubber", verts=16) for x in (-L + 0.06, L - 0.06) for y in (-W + 0.06, W - 0.06)])
    join("score_beads_amber", [sphere("b", (x, -W - 0.01, H - 0.03), 0.012, "amber", segments=10) for x in (-0.06, -0.03, 0.03, 0.06)])


def telescope():
    """A small telescope on a tripod, to put by a window: Phobos, Deimos,
    and Earth as a bright blue evening star."""
    hub = Vector((0, 0, 1.0))
    legs = []
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 2
        legs.append(rod("leg", hub, (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), 0.016, "dark_alloy"))
    join("tripod_dark_alloy", legs)
    join("feet_black_rubber", [sphere("f", (math.cos(2 * math.pi * i / 3 + math.pi / 2) * 0.42, math.sin(2 * math.pi * i / 3 + math.pi / 2) * 0.42, 0.01), 0.025, "black_rubber", segments=10) for i in range(3)])
    cyl("mount_graphite", (0, 0, 1.04), 0.06, 0.09, "graphite", verts=24, bevel=0.01)
    # The tube, tilted up towards the sky over the front.
    tilt = math.radians(35)
    d = Vector((0, math.cos(tilt), math.sin(tilt)))
    centre = Vector((0, 0, 1.16))
    a, b = centre - d * 0.42, centre + d * 0.36
    rod("tube_white_painted", a, b, 0.065, "white_painted", verts=32)
    rod("dew_shield_graphite", b, b + d * 0.12, 0.072, "graphite", verts=32)
    rod("tube_band_orange", centre + d * 0.1, centre + d * 0.14, 0.068, "orange", verts=32)
    rod("eyepiece_black_rubber", a - Vector((0, 0, 0.0)), a + Vector((0, 0, 0.1)), 0.018, "black_rubber")
    rod("finder_satin_steel", centre + d * 0.0 + Vector((0.08, 0, 0.05)), centre + d * 0.25 + Vector((0.08, 0, 0.05)), 0.014, "satin_steel")
    box("cradle_dark_alloy", -0.03, 0.03, -0.08, 0.08, 1.08, 1.12, "dark_alloy", 0.006)


def music_station():
    """A music corner: a low credenza with a record player on top, two
    speakers and headphones on a hook."""
    cabinet("credenza", -0.62, 0.62, -0.22, 0.22, 0.0, 0.62)
    box("record_shelf_graphite", -0.58, -0.05, 0.2, 0.225, 0.08, 0.5, "graphite", 0.004)
    join("records_vinyl_black_rubber", [box("r", -0.55 + i * 0.045, -0.53 + i * 0.045, -0.15, 0.18, 0.1, 0.42, "vinyl_black_rubber", 0.002) for i in range(10)])
    box("turntable_plinth_slate_panel", -0.25, 0.25, -0.18, 0.18, 0.62, 0.7, "slate_panel", 0.012)
    cyl("platter_satin_steel", (-0.04, 0.0, 0.71), 0.15, 0.02, "satin_steel", verts=40)
    cyl("record_vinyl_black_rubber", (-0.04, 0.0, 0.725), 0.145, 0.006, "vinyl_black_rubber", verts=40)
    cyl("record_label_orange", (-0.04, 0.0, 0.729), 0.04, 0.003, "orange", verts=24)
    rod("tonearm_satin_steel", (0.19, 0.12, 0.74), (0.04, -0.04, 0.735), 0.005, "satin_steel")
    cyl("tonearm_base_dark_alloy", (0.19, 0.12, 0.72), 0.025, 0.03, "dark_alloy", verts=16)
    for side in (-1, 1):
        x = side * 0.48
        box(f"speaker_{'l' if side < 0 else 'r'}_graphite", x - 0.12, x + 0.12, -0.16, 0.16, 0.62, 1.04, "graphite", 0.02)
        for z, r in ((0.94, 0.04), (0.76, 0.075)):
            cyl(f"cone_{'l' if side < 0 else 'r'}_{int(z * 100)}_black_rubber", (x, 0.162, z), r, 0.01, "black_rubber", axis="y", verts=24)
            torus(f"cone_ring_{'l' if side < 0 else 'r'}_{int(z * 100)}_dark_alloy", (x, 0.166, z), r, 0.006, "dark_alloy", axis="y")
    box("status_light_screen_green", 0.18, 0.21, 0.18, 0.182, 0.66, 0.67, "screen_green", 0.0)
    torus("headphones_graphite", (0.62, 0.0, 0.48), 0.08, 0.01, "graphite", axis="x")
    join("ear_cups_white_painted", [cyl("e", (0.64, y, 0.42), 0.04, 0.03, "white_painted", axis="x", verts=20) for y in (-0.075, 0.075)])


def dartboard():
    """A magnetic dartboard (no sharp points in a pressurised habitat): a
    graphite back plate, alternating rings, an orange bull and three darts."""
    box("plate_graphite", -0.26, 0.26, 0.0, 0.02, -0.26, 0.26, "graphite", 0.012)
    rings = [(0.22, "black_rubber"), (0.2, "white_painted"), (0.15, "black_rubber"), (0.13, "white_painted"), (0.08, "black_rubber"), (0.06, "white_painted")]
    for i, (r, mat) in enumerate(rings):
        cyl(f"ring_{i}_{mat}", (0, 0.03 + i * 0.002, 0), r, 0.02, mat, axis="y", verts=48)
    cyl("bull_orange", (0, 0.045, 0), 0.02, 0.01, "orange", axis="y", verts=24)
    join("wires_satin_steel", [rod("w", (0, 0.045, 0), (math.cos(a) * 0.22, 0.045, math.sin(a) * 0.22), 0.002, "satin_steel", 6) for a in [i * math.pi / 10 for i in range(20)]])
    darts = []
    for x, z in ((0.05, 0.07), (-0.09, -0.03), (0.02, -0.12)):
        darts.append(rod("d", (x, 0.05, z), (x, 0.15, z + 0.01), 0.005, "satin_steel"))
    join("darts_satin_steel", darts)
    join("flights_amber", [box("f", x - 0.015, x + 0.015, 0.13, 0.16, z - 0.002, z + 0.025, "amber", 0) for x, z in ((0.05, 0.07), (-0.09, -0.03), (0.02, -0.12))])


def games_shelf():
    """A wall shelf of games: board game boxes, a deck of cards, a puzzle
    cube and dice."""
    box("back_plate_graphite", -0.46, 0.46, 0.0, 0.02, -0.3, 0.3, "graphite", 0.01)
    for z in (-0.28, 0.02):
        box(f"shelf_{int((z + 1) * 100)}_white_painted", -0.45, 0.45, 0.02, 0.28, z, z + 0.025, "white_painted", 0.006)
        join(f"brackets_{int((z + 1) * 100)}_dark_alloy", [box("b", x - 0.012, x + 0.012, 0.02, 0.22, z - 0.05, z, "dark_alloy", 0.003) for x in (-0.38, 0.38)])
    # Board games, stacked and standing.
    for i, (mat, h) in enumerate((("game_box_cool_blue", 0.05), ("game_box_amber", 0.04), ("game_box_teal", 0.06))):
        z = -0.255 + sum((0.05, 0.04, 0.06)[:i])
        box(f"game_{i}_{mat}", -0.42, -0.08, 0.04, 0.26, z, z + h - 0.003, mat, 0.004)
    for i, mat in enumerate(("game_box_teal", "white_painted", "game_box_cool_blue", "orange")):
        x = 0.05 + i * 0.07
        box(f"standing_{i}_{mat}", x, x + 0.055, 0.04, 0.26, -0.255, -0.0, mat, 0.004)
    box("cards_white_painted", -0.38, -0.29, 0.1, 0.16, 0.045, 0.075, "white_painted", 0.003)
    # A puzzle cube in signal colours, and two dice.
    for i, mat in enumerate(("button_red", "bright_green", "cool_blue", "amber")):
        x, y = -0.12 + (i % 2) * 0.026, 0.12 + (i // 2) * 0.026
        box(f"cube_{i}_{mat}", x, x + 0.025, y, y + 0.025, 0.045, 0.07, mat, 0.003)
    join("dice_white_painted", [box("d", x, x + 0.022, 0.12, 0.142, 0.045, 0.067, "white_painted", 0.004) for x in (0.05, 0.09)])
    sphere("trophy_cup_satin_steel", (0.32, 0.15, 0.1), 0.04, "satin_steel", scale=(1, 1, 1.2), segments=16)
    cyl("trophy_base_graphite", (0.32, 0.15, 0.055), 0.03, 0.02, "graphite", verts=16)


# ---------- shared R&R space (25 Oct, second set) ----------

def projector_screen():
    """Movie night: a big wall screen in a slim frame (the game can show Mars
    or Earth on it), a sound bar under it and a status light."""
    box("frame_graphite", -1.05, 1.05, 0.0, 0.04, -0.62, 0.62, "graphite", 0.012)
    box("bezel_dark_alloy", -1.02, 1.02, 0.04, 0.045, -0.59, 0.59, "dark_alloy", 0.004)
    box("display_screen_glass_dark_glass", -1.0, 1.0, 0.045, 0.047, -0.57, 0.57, "dark_glass", 0)
    box("sound_bar_graphite", -0.7, 0.7, 0.0, 0.09, -0.74, -0.65, "graphite", 0.02)
    vent("sound_bar_grille_dark_alloy", -0.66, 0.66, -0.73, -0.66, 0.092, slats=24)
    box("status_light_screen_green", 0.9, 0.94, 0.045, 0.05, -0.605, -0.595, "screen_green", 0)
    box("brand_strip_orange", -0.96, -0.82, 0.045, 0.049, -0.605, -0.597, "orange", 0)


def sectional_sofa():
    """A corner sofa for movie nights: an L of teal cushions on a white
    shell and graphite plinth, with a chaise end and an orange stripe."""
    D = 0.86   # seat depth
    box("plinth_graphite", -1.1 + 0.06, 1.1 - 0.06, -0.4 + 0.06, 0.4 - 0.06, 0.0, 0.1, "graphite", 0.01)
    box("plinth_chaise_graphite", 0.3 + 0.06, 1.1 - 0.06, 0.4 - 0.06, 0.4 + D - 0.06, 0.0, 0.1, "graphite", 0.01)
    box("base_white_painted", -1.1, 1.1, -0.4, 0.4, 0.1, 0.4, "white_painted", 0.04)
    box("base_chaise_white_painted", 0.3, 1.1, 0.4, 0.4 + D, 0.1, 0.4, "white_painted", 0.04)
    box("back_white_painted", -1.1, 1.1, -0.4, -0.24, 0.4, 0.84, "white_painted", 0.05)
    box("arm_white_painted", -1.1, -0.94, -0.4, 0.4, 0.4, 0.62, "white_painted", 0.05)
    box("chaise_arm_white_painted", 0.94, 1.1, -0.24, 0.4 + D, 0.4, 0.62, "white_painted", 0.05)
    for i, (x0, x1) in enumerate(((-0.93, -0.32), (-0.31, 0.3), (0.31, 0.93))):
        cushion(f"seat_{i}_teal_soft", x0, x1, -0.24, 0.38, 0.4, 0.53)
        cushion(f"back_{i}_teal_soft", x0 + 0.01, x1 - 0.01, -0.24, -0.1, 0.5, 0.82)
    cushion("chaise_seat_teal_soft", 0.31, 0.93, 0.4, 0.4 + D - 0.02, 0.4, 0.53)
    join("pillows_warm_panel", [cushion("p", x, x + 0.34, -0.1, 0.02, 0.52, 0.78, "warm_panel") for x in (-0.86, 0.5)])
    box("arm_stripe_orange", -1.1, -0.94, 0.396, 0.402, 0.5, 0.54, "orange", 0.002)


def coffee_bar():
    """A cafe corner: a bar counter with an espresso machine, a grinder, a
    rack of cups and a snack cupboard underneath."""
    cabinet("bar", -0.7, 0.7, -0.28, 0.28, 0.0, 1.02)
    for i, (x0, x1) in enumerate(((-0.68, -0.01), (0.01, 0.68))):
        box(f"door_{i}_slate_panel", x0 + 0.02, x1 - 0.02, 0.28, 0.292, 0.12, 0.92, "slate_panel", 0.008)
        handle(f"pull_{i}_satin_steel", (x0 + x1) / 2 - 0.08, (x0 + x1) / 2 + 0.08, 0.84, 0.292)
    box("counter_overhang_warm_panel", -0.74, 0.74, -0.3, 0.42, 1.02, 1.06, "warm_panel", 0.012)
    # The espresso machine.
    box("espresso_body_satin_steel", -0.5, -0.06, -0.24, 0.08, 1.06, 1.42, "satin_steel", 0.02)
    box("espresso_top_graphite", -0.5, -0.06, -0.24, 0.08, 1.42, 1.45, "graphite", 0.008)
    box("drip_tray_dark_alloy", -0.44, -0.12, 0.08, 0.2, 1.06, 1.09, "dark_alloy", 0.006)
    join("group_heads_dark_alloy", [cyl("g", (x, 0.11, 1.24), 0.035, 0.05, "dark_alloy", verts=16) for x in (-0.38, -0.18)])
    cyl("steam_wand_satin_steel", (-0.08, 0.12, 1.18), 0.006, 0.18, "satin_steel", verts=10)
    join("knobs_orange", [cyl("k", (x, 0.085, 1.36), 0.018, 0.02, "orange", axis="y", verts=16) for x in (-0.38, -0.18)])
    box("gauge_screen_cyan", -0.3, -0.24, 0.08, 0.083, 1.33, 1.39, "screen_cyan", 0)
    # Grinder and cups.
    cyl("grinder_graphite", (0.12, -0.08, 1.2), 0.07, 0.28, "graphite", verts=24, bevel=0.01)
    cyl("hopper_iv_clear", (0.12, -0.08, 1.4), 0.06, 0.12, "iv_clear", verts=24, radius2=0.04)
    join("cups_white_painted", [cyl("c", (x, y, 1.1), 0.035, 0.08, "white_painted", verts=16) for x in (0.32, 0.42, 0.52) for y in (-0.15, 0.02)])


def bar_stool():
    """A bar stool: a round teal seat on a satin pedestal with a foot ring."""
    cyl("seat_teal_soft", (0, 0, 0.74), 0.19, 0.07, "teal_soft", verts=32, bevel=0.02)
    cyl("seat_shell_white_painted", (0, 0, 0.69), 0.18, 0.04, "white_painted", verts=32, bevel=0.01)
    rod("pedestal_satin_steel", (0, 0, 0.05), (0, 0, 0.68), 0.03, "satin_steel")
    torus("foot_ring_dark_alloy", (0, 0, 0.3), 0.17, 0.012, "dark_alloy")
    join("spokes_dark_alloy", [rod("s", (0, 0, 0.3), (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.3), 0.008, "dark_alloy", 8) for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)])
    cyl("base_graphite", (0, 0, 0.02), 0.2, 0.04, "graphite", verts=32, bevel=0.01)
    torus("seat_band_orange", (0, 0, 0.705), 0.181, 0.006, "orange")


def plant_wall():
    """A living plant wall: rows of planter pockets in a graphite frame, a
    grow-light bar over them and a drip line."""
    box("frame_graphite", -0.62, 0.62, 0.0, 0.05, -0.72, 0.72, "graphite", 0.012)
    box("felt_back_soil", -0.58, 0.58, 0.05, 0.06, -0.66, 0.6, "soil", 0)
    leaves_dark, leaves_light = [], []
    for row, z in enumerate((-0.52, -0.24, 0.04, 0.32)):
        box(f"pocket_row_{row}_white_painted", -0.58, 0.58, 0.06, 0.16, z - 0.05, z, "white_painted", 0.01)
        for k in range(7):
            x = -0.5 + k * 0.166 + (0.04 if row % 2 else 0.0)
            if x > 0.52: continue
            # A clump of leaves spilling out of each pocket.
            for j, (dx, dz, r) in enumerate(((0.0, 0.05, 0.055), (-0.045, 0.02, 0.045), (0.05, 0.0, 0.04), (0.02, -0.04, 0.035))):
                light = (k + row + j) % 2 == 0
                (leaves_light if light else leaves_dark).append(sphere("l", (x + dx, 0.13 + j * 0.012, z + dz + 0.04), r, "leaf_light" if light else "leaf_green", scale=(1.3, 0.55, 0.8), segments=10))
    join("leaves_leaf_green", leaves_dark)
    join("leaves_light_leaf_light", leaves_light)
    box("grow_light_lamp_white", -0.56, 0.56, 0.12, 0.16, 0.64, 0.67, "lamp_white", 0.006)
    box("grow_light_housing_dark_alloy", -0.6, 0.6, 0.05, 0.17, 0.67, 0.71, "dark_alloy", 0.008)
    rod("drip_line_black_rubber", (-0.58, 0.07, 0.56), (0.58, 0.07, 0.56), 0.006, "black_rubber")
    box("valve_orange", 0.5, 0.56, 0.06, 0.1, -0.7, -0.64, "orange", 0.004)


def floor_rug():
    """A soft woven rug to set a sofa and cushions on: a teal field with a
    warm border and one orange stripe. Furniture stands on it."""
    box("rug_teal_soft", -1.2, 1.2, -0.8, 0.8, 0.0, 0.014, "teal_soft", 0.004)
    join("border_warm_panel", [
        box("b", -1.2, 1.2, -0.8, -0.7, 0.0, 0.016, "warm_panel", 0.002),
        box("b", -1.2, 1.2, 0.7, 0.8, 0.0, 0.016, "warm_panel", 0.002),
        box("b", -1.2, -1.1, -0.7, 0.7, 0.0, 0.016, "warm_panel", 0.002),
        box("b", 1.1, 1.2, -0.7, 0.7, 0.0, 0.016, "warm_panel", 0.002)])
    box("stripe_orange", -1.0, 1.0, -0.62, -0.58, 0.0, 0.017, "orange", 0.001)


def floor_cushions():
    """Big floor cushions round a low tea table."""
    box("table_top_warm_panel", -0.32, 0.32, -0.32, 0.32, 0.3, 0.34, "warm_panel", 0.012)
    join("table_legs_dark_alloy", [box("l", x - 0.025, x + 0.025, y - 0.025, y + 0.025, 0.0, 0.3, "dark_alloy", 0.006) for x in (-0.27, 0.27) for y in (-0.27, 0.27)])
    for i, (x, y) in enumerate(((0.0, -0.62), (0.62, 0.0), (0.0, 0.62), (-0.62, 0.0))):
        cushion(f"cushion_{i}_teal_soft", x - 0.26, x + 0.26, y - 0.26, y + 0.26, 0.0, 0.16)
        box(f"button_{i}_graphite", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0.155, 0.165, "graphite", 0.004)
    join("cups_white_painted", [cyl("c", (x, 0.08, 0.38), 0.035, 0.08, "white_painted", verts=16) for x in (-0.1, 0.06)])
    cyl("teapot_orange", (0.14, -0.1, 0.4), 0.06, 0.12, "orange", verts=20, bevel=0.01)


def window_seat():
    """A window seat: a long cushioned bench with drawers underneath and
    bolster cushions at each end. Put it under a window."""
    cabinet("bench", -0.8, 0.8, -0.27, 0.27, 0.0, 0.42)
    for i, x0 in enumerate((-0.76, -0.25, 0.26)):
        box(f"drawer_{i}_slate_panel", x0, x0 + 0.5, 0.27, 0.282, 0.1, 0.36, "slate_panel", 0.008)
        handle(f"drawer_pull_{i}_satin_steel", x0 + 0.17, x0 + 0.33, 0.32, 0.282)
    cushion("seat_teal_soft", -0.78, 0.78, -0.25, 0.25, 0.42, 0.52)
    join("bolsters_warm_panel", [cyl("b", (x, -0.02, 0.6), 0.09, 0.4, "warm_panel", axis="y", verts=24, bevel=0.02) for x in (-0.66, 0.66)])
    cushion("throw_pillow_orange", -0.2, 0.12, -0.22, -0.1, 0.5, 0.78, "orange")


def table_tennis():
    """Low-gravity table tennis: a compact teal table with white lines, a
    net, folding legs, two bats and a ball."""
    L, W, H = 1.15, 0.65, 0.76
    box("top_field_teal", -L, L, -W, W, H - 0.03, H, "field_teal", 0.006)
    join("lines_white_painted", [
        box("l", -L, L, -W, -W + 0.02, H, H + 0.002, "white_painted", 0),
        box("l", -L, L, W - 0.02, W, H, H + 0.002, "white_painted", 0),
        box("l", -L, -L + 0.02, -W, W, H, H + 0.002, "white_painted", 0),
        box("l", L - 0.02, L, -W, W, H, H + 0.002, "white_painted", 0),
        box("l", -L, L, -0.004, 0.004, H, H + 0.002, "white_painted", 0)])
    box("net_graphite", -0.006, 0.006, -W - 0.06, W + 0.06, H, H + 0.15, "graphite", 0.002)
    join("net_posts_satin_steel", [box("p", -0.015, 0.015, y - 0.015, y + 0.015, H - 0.04, H + 0.16, "satin_steel", 0.004) for y in (-W - 0.06, W + 0.06)])
    box("apron_white_painted", -L + 0.02, L - 0.02, -W + 0.02, W - 0.02, H - 0.1, H - 0.03, "white_painted", 0.01)
    legs = []
    for x in (-L + 0.25, L - 0.25):
        for y in (-W + 0.12, W - 0.12):
            legs.append(box("l", x - 0.025, x + 0.025, y - 0.025, y + 0.025, 0.0, H - 0.1, "dark_alloy", 0.006))
        legs.append(box("l", x - 0.02, x + 0.02, -W + 0.12, W - 0.12, 0.18, 0.22, "dark_alloy", 0.006))
    join("legs_dark_alloy", legs)
    join("wheels_black_rubber", [cyl("w", (x, y, 0.03), 0.03, 0.03, "black_rubber", axis="y", verts=16) for x in (-L + 0.25, L - 0.25) for y in (-W + 0.12, W - 0.12)])
    for i, (x, y) in enumerate(((-0.7, 0.3), (0.75, -0.35))):
        cyl(f"bat_{i}_button_red", (x, y, H + 0.008), 0.075, 0.012, "button_red", verts=24)
        box(f"bat_handle_{i}_warm_panel", x - 0.02, x + 0.02, y + 0.07, y + 0.17, H + 0.002, H + 0.022, "warm_panel", 0.006)
    sphere("ball_orange", (0.3, 0.15, H + 0.02), 0.02, "orange", segments=12)


def climbing_wall():
    """A bouldering wall panel: in Mars's low gravity you climb at a third of
    your weight. Coloured holds on a white board with graphite edging."""
    box("board_white_painted", -0.7, 0.7, 0.0, 0.05, -1.1, 1.1, "white_painted", 0.012)
    box("edge_graphite", -0.73, 0.73, 0.0, 0.04, -1.13, 1.13, "graphite", 0.008)
    holds = {"button_red": [], "bright_green": [], "cool_blue": [], "amber": []}
    import random
    rng = random.Random(7)
    mats = list(holds)
    for i in range(26):
        x = rng.uniform(-0.6, 0.6)
        z = -1.0 + i * 0.08 + rng.uniform(-0.03, 0.03)
        mat = mats[i % 4]
        holds[mat].append(sphere("h", (x, 0.06, z), rng.uniform(0.035, 0.06), mat, scale=(1.2, 0.6, 0.8), segments=10))
    for mat, parts in holds.items():
        join(f"holds_{mat}", parts)
    join("bolts_satin_steel", [cyl("b", (x, 0.052, z), 0.008, 0.006, "satin_steel", axis="y", verts=8) for x in (-0.6, -0.2, 0.2, 0.6) for z in (-1.0, -0.5, 0.0, 0.5, 1.0)])
    box("top_band_orange", -0.7, 0.7, 0.05, 0.054, 1.02, 1.08, "orange", 0.002)


MODELS = [
    ("projector_screen", projector_screen, "wall"),
    ("sectional_sofa", sectional_sofa, "floor"),
    ("coffee_bar", coffee_bar, "floor"),
    ("bar_stool", bar_stool, "floor"),
    ("plant_wall", plant_wall, "wall"),
    ("floor_rug", floor_rug, "floor"),
    ("floor_cushions", floor_cushions, "floor"),
    ("window_seat", window_seat, "floor"),
    ("table_tennis", table_tennis, "floor"),
    ("climbing_wall", climbing_wall, "wall"),
    ("lounge_sofa", lounge_sofa, "floor"),
    ("bean_bag", bean_bag, "floor"),
    ("arcade_cabinet", arcade_cabinet, "floor"),
    ("vr_station", vr_station, "floor"),
    ("table_football", table_football, "floor"),
    ("telescope", telescope, "floor"),
    ("music_station", music_station, "floor"),
    ("dartboard", dartboard, "wall"),
    ("games_shelf", games_shelf, "wall"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Recreation: lounge sofa, bean bag, arcade, VR station, table football, telescope, music corner, dartboard, games shelf"')
exec(_TAIL)
