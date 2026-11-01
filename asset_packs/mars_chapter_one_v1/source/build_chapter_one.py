"""Blender (5.x) build script: chapter one's models for Outpost One (1 Nov 2026).

Run:  blender --background --python build_chapter_one.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, textures/, previews/ and asset_manifest.json.

The start and chapter one (docs/start-and-chapter-one.md): the fabricator,
the precursor crates in three sizes (no lettering: they differ only by size)
and the hand corer. Built with the HQ kit (asset_packs/mars_hq_v1/source/
hq_kit.py) in the house style. The game loads these GLBs from
assets/equipment/mars_chapter_one_v1/ (scripts/fabricator.gd,
precursor_crate.gd, hand_corer.gd), not through the asset-pack importer.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(_HERE, "..", "..", "mars_hq_v1", "source", "hq_kit.py"), encoding="utf-8").read())


# ---------- the fabricator ----------

def fabricator():
    """A bench-sized fabricator: a white cabinet on a recessed plinth, a build
    chamber behind a dark window (a build plate and a print head on its
    gantry), a powder hopper with an orange lid band, an output drawer, a
    working display and status lights. Front faces +Y here."""
    X0, X1, Y0, Y1 = -0.72, 0.72, -0.42, 0.42
    box("plinth_deep_graphite", X0 + 0.05, X1 - 0.05, Y0 + 0.05, Y1 - 0.06, 0.0, 0.08, "deep_graphite", 0.008)
    box("carcass_shell_white", X0, X1, Y0, Y1, 0.07, 0.86, "shell_white", 0.025)
    box("cap_panel_cool", X0 - 0.01, X1 + 0.01, Y0 - 0.01, Y1 + 0.01, 0.86, 0.9, "panel_cool", 0.015)
    seam_grid("carcass_seams_deep_graphite", X0 + 0.04, X1 - 0.04, 0.12, 0.82, Y1, 2, 1)
    # The output drawer, inset with a rubber seam, and a satin handle.
    box("Output_Drawer_front_panel_warm", -0.62, 0.12, Y1 - 0.02, Y1 + 0.006, 0.14, 0.5, "panel_warm", 0.014)
    gasket("Output_Drawer_gasket_black_rubber", -0.63, 0.13, 0.13, 0.51, Y1 + 0.004)
    handle("Output_Drawer_handle_satin_alloy", -0.4, -0.1, 0.44, Y1 + 0.006, mat="satin_alloy")
    # A service door on the right, with a vent.
    box("service_door_panel_warm", 0.2, 0.62, Y1 - 0.02, Y1 + 0.006, 0.14, 0.8, "panel_warm", 0.014)
    gasket("service_door_gasket_black_rubber", 0.19, 0.63, 0.13, 0.81, Y1 + 0.004)
    vent("service_door_vent_dark_alloy", 0.26, 0.56, 0.18, 0.34, Y1 + 0.006, slats=6)
    bolts("service_door_bolts_satin_steel", [(0.23, 0.17), (0.59, 0.17), (0.23, 0.77), (0.59, 0.77)], Y1 + 0.006)
    # The working display (the game draws the job on it) and status lights.
    box("display_frame_frame_graphite", 0.28, 0.56, Y1 + 0.004, Y1 + 0.016, 0.5, 0.7, "frame_graphite", 0.008)
    box("display_screen_glass_cyan", 0.3, 0.54, Y1 + 0.016, Y1 + 0.018, 0.52, 0.68, "screen_cyan", 0)
    status_leds("status_led", 0.5, Y1 + 0.006, 0.76, colours=("led_green", "led_green", "led_red"))
    plate("fabricator_tag", -0.5, Y1 + 0.006, 0.6, 0.14, 0.03)
    # The build chamber: a graphite frame round a dark window.
    CX0, CX1 = -0.66, 0.22
    box("chamber_shell_white", CX0, CX1, Y0 + 0.06, Y1 - 0.04, 0.9, 1.46, "shell_white", 0.02)
    box("chamber_frame_frame_graphite", CX0 + 0.04, CX1 - 0.04, Y1 - 0.05, Y1 - 0.03, 0.96, 1.4, "frame_graphite", 0.01)
    box("chamber_window_dark_glass", CX0 + 0.07, CX1 - 0.07, Y1 - 0.035, Y1 - 0.025, 0.99, 1.37, "dark_glass", 0.004)
    gasket("chamber_window_gasket_black_rubber", CX0 + 0.065, CX1 - 0.065, 0.985, 1.375, Y1 - 0.024, w=0.006)
    # Inside, seen through the glass: a build plate, a part being printed,
    # and a print head on two gantry rods.
    box("build_plate_satin_alloy", CX0 + 0.12, CX1 - 0.12, Y0 + 0.14, Y1 - 0.12, 0.96, 0.98, "satin_alloy", 0.004)
    box("build_part_panel_cool", -0.34, -0.12, -0.1, 0.12, 0.98, 1.06, "panel_cool", 0.01)
    for y in (-0.16, 0.16):
        rod(f"gantry_rod_{'b' if y < 0 else 'f'}_satin_alloy", (CX0 + 0.06, y, 1.3), (CX1 - 0.06, y, 1.3), 0.008, "satin_alloy", verts=12)
    box("print_head_frame_graphite", -0.3, -0.16, -0.2, 0.2, 1.24, 1.34, "frame_graphite", 0.012)
    cyl("print_nozzle_dark_alloy", (-0.23, 0.0, 1.21), 0.012, 0.06, "dark_alloy", verts=12, radius2=0.004)
    cyl("chamber_lamp_led_warm", (-0.22, 0.0, 1.43), 0.08, 0.006, "led_warm", verts=24)
    # The powder hopper: a satin funnel with an orange lid band, and its feed pipe.
    cyl("hopper_body_satin_alloy", (0.47, -0.06, 1.12), 0.15, 0.4, "satin_alloy", verts=40, bevel=0.01, radius2=0.11)
    cyl("hopper_lid_shell_white", (0.47, -0.06, 1.34), 0.16, 0.04, "shell_white", verts=40, bevel=0.012)
    cyl("hopper_band_accent_orange", (0.47, -0.06, 1.3), 0.153, 0.025, "accent_orange", verts=40)
    cyl("hopper_knob_frame_graphite", (0.47, -0.06, 1.38), 0.03, 0.03, "frame_graphite", verts=20)
    rod("hopper_feed_satin_alloy", (0.34, -0.06, 0.98), (0.22, -0.06, 1.06), 0.022, "satin_alloy", verts=16)
    box("hopper_cradle_frame_graphite", 0.3, 0.64, -0.24, 0.12, 0.9, 0.94, "frame_graphite", 0.008)
    # Cables up the back, and side handholds.
    cable("power_cable_black_rubber", [(0.6, Y0 + 0.02, 0.1), (0.6, Y0 - 0.02, 0.6), (0.4, Y0 - 0.02, 0.9)], radius=0.01)
    handrail("side_rail_l_satin_alloy", (X0, -0.2, 0.62), (X0, 0.2, 0.62), axis_out=(-1, 0, 0))
    handrail("side_rail_r_satin_alloy", (X1, -0.2, 0.62), (X1, 0.2, 0.62), axis_out=(1, 0, 0))


# ---------- the precursor crates ----------

def _crate(w, d, h, latches):
    """A composite cargo crate: white panels in graphite corner posts and
    rails, skids underneath, satin latches (one with an orange lever),
    lifting lugs and a blank ID plate. Floor origin, centred."""
    X0, X1, Y0, Y1 = -w / 2, w / 2, -d / 2, d / 2
    # Skids.
    for x in (X0 + 0.12, X1 - 0.16):
        box(f"skid_{'l' if x < 0 else 'r'}_deep_graphite", x, x + 0.04 + 0.0, Y0 + 0.04, Y1 - 0.04, 0.0, 0.08, "deep_graphite", 0.006)
    box("base_frame_graphite", X0, X1, Y0, Y1, 0.08, 0.14, "frame_graphite", 0.01)
    # Panels, inset in the frame.
    box("body_shell_white", X0 + 0.03, X1 - 0.03, Y0 + 0.03, Y1 - 0.03, 0.14, h - 0.06, "shell_white", 0.012)
    box("lid_panel_cool", X0 - 0.005, X1 + 0.005, Y0 - 0.005, Y1 + 0.005, h - 0.07, h, "panel_cool", 0.012)
    gasket("lid_seam_black_rubber", X0 + 0.03, X1 - 0.03, h - 0.075, h - 0.065, Y1 - 0.025)
    # Corner posts and mid rails.
    for x in (X0, X1 - 0.05):
        for y in (Y0, Y1 - 0.05):
            box(f"post_{'l' if x < 0 else 'r'}{'b' if y < 0 else 'f'}_frame_graphite", x, x + 0.05, y, y + 0.05, 0.08, h - 0.02, "frame_graphite", 0.008)
    for side, y in (("f", Y1 - 0.025), ("b", Y0 + 0.005)):
        box(f"rail_{side}_frame_graphite", X0 + 0.05, X1 - 0.05, y, y + 0.02, h * 0.48, h * 0.48 + 0.05, "frame_graphite", 0.006)
    seam_grid("front_seams_deep_graphite", X0 + 0.08, X1 - 0.08, 0.18, h - 0.12, Y1 - 0.03, max(1, round(w / 0.7)), 2)
    # Latches across the lid seam, the first with the orange lever.
    for k in range(latches):
        x = X0 + w * (k + 1) / (latches + 1)
        box(f"latch_{k}_body_satin_alloy", x - 0.05, x + 0.05, Y1 - 0.03, Y1 + 0.0, h - 0.16, h - 0.06, "satin_alloy", 0.006)
        rod(f"latch_{k}_lever_{'accent_orange' if k == 0 else 'frame_graphite'}", (x, Y1 + 0.005, h - 0.15), (x, Y1 + 0.005, h - 0.08), 0.008,
            "accent_orange" if k == 0 else "frame_graphite", verts=10)
    # Lifting lugs on the lid corners, a handle each end, the ID plate.
    for x in (X0 + 0.08, X1 - 0.08):
        for y in (Y0 + 0.08, Y1 - 0.08):
            torus(f"lug_{'l' if x < 0 else 'r'}{'b' if y < 0 else 'f'}_satin_alloy", (x, y, h + 0.02), 0.025, 0.007, "satin_alloy", axis="x")
    for x in (X0, X1):
        handrail(f"end_handle_{'l' if x < 0 else 'r'}_satin_alloy", (x, -min(0.18, d * 0.25), h * 0.6), (x, min(0.18, d * 0.25), h * 0.6),
                 standoff=0.04, axis_out=(-1 if x < 0 else 1, 0, 0), radius=0.012)
    plate("crate_tag", X1 - 0.18, Y1 - 0.03, h * 0.3, 0.16, 0.05)


def precursor_crate_small():
    """Kit: about a metre on a side."""
    _crate(1.2, 1.0, 0.9, 2)


def precursor_crate_long():
    """Frames and panels: long and low."""
    _crate(2.6, 1.2, 1.1, 3)


def precursor_crate_tall():
    """Tanks: tall and square."""
    _crate(1.3, 1.3, 2.4, 2)


# ---------- the hand corer ----------

def hand_corer():
    """A hand corer: a T-handle with rubber grips on a satin core tube, an
    orange collar, depth rings, and a dark cutting crown. Stands upright,
    tip at the origin, 1.15 m tall."""
    cyl("crown_dark_alloy", (0, 0, 0.04), 0.03, 0.08, "dark_alloy", verts=24, radius2=0.026)
    join("crown_teeth_dark_alloy", [cyl("t", (0.028 * math.cos(a), 0.028 * math.sin(a), 0.004), 0.006, 0.012, "dark_alloy", verts=6)
                                    for a in [k * math.pi / 4 for k in range(8)]])
    cyl("tube_satin_alloy", (0, 0, 0.5), 0.024, 0.84, "satin_alloy", verts=24)
    join("depth_rings_deep_graphite", [torus("r", (0, 0, 0.2 + 0.1 * k), 0.025, 0.002, "deep_graphite") for k in range(6)])
    box("sight_slot_deep_graphite", -0.004, 0.004, 0.0235, 0.026, 0.14, 0.62, "deep_graphite", 0.001)
    cyl("collar_accent_orange", (0, 0, 0.9), 0.032, 0.04, "accent_orange", verts=24, bevel=0.004)
    cyl("head_frame_graphite", (0, 0, 0.96), 0.03, 0.08, "frame_graphite", verts=24, bevel=0.006)
    rod("t_bar_satin_alloy", (-0.22, 0, 1.02), (0.22, 0, 1.02), 0.012, "satin_alloy", verts=16)
    for x in (-0.15, 0.15):
        cyl(f"grip_{'l' if x < 0 else 'r'}_black_rubber", (x, 0, 1.02), 0.02, 0.12, "black_rubber", axis="x", verts=16, bevel=0.006)
    cyl("end_cap_frame_graphite", (0, 0, 1.05), 0.02, 0.03, "frame_graphite", verts=16)
    box("strap_nomex_webbing", -0.006, 0.006, -0.028, 0.028, 0.66, 0.86, "nomex_webbing", 0.002)


MODELS = [
    ("fabricator", fabricator, "floor"),
    ("precursor_crate_small", precursor_crate_small, "floor"),
    ("precursor_crate_long", precursor_crate_long, "floor"),
    ("precursor_crate_tall", precursor_crate_tall, "floor"),
    ("hand_corer", hand_corer, "floor"),
]

run()
