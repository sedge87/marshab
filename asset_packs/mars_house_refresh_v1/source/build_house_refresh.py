"""Blender (5.x) build script: House Refresh pack for MARS: HABITAT (v1).

Run:  blender --background --python build_house_refresh.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

Rebuilds the six oldest placeholder models (cream panels with toy-like
buttons, from before the asset packs) in the house style every other pack now
shares (docs/house-style.md): white shells with rounded bevels, graphite
bezels and frames, satin metal trim, one orange accent, cyan screens and
small status lights. Catalogue ids are unchanged. Shares the furnishings
pack's materials, helpers and export (loaded from
../../mars_habitat_furnishings_v1/source/build_furnishings.py).

Metres. Floor items: floor origin. Wall items: back face on the wall at
Blender y = 0, front +Y (glTF -Z), centred on the origin.
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
    "red_light": ((0.95, 0.30, 0.25, 1), .0, .3),
    "amber_light": ((1.0, 0.72, 0.25, 1), .0, .3),
})
GLOW.update({"red_light": 1.4, "amber_light": 1.4})


def wall_shell(prefix, w, h, d, mat="white_painted"):
    """A wall-mounted housing: a graphite back plate, a rounded white body and
    a satin trim line round the front edge."""
    box(f"{prefix}_backplate_graphite", -w / 2 - .015, w / 2 + .015, 0, .012, -h / 2 - .015, h / 2 + .015, "graphite", .006)
    box(f"{prefix}_body_{mat}", -w / 2, w / 2, .012, d, -h / 2, h / 2, mat, .022)
    gasket(f"{prefix}_seam_black_rubber", -w / 2 + .01, w / 2 - .01, -h / 2 + .01, h / 2 - .01, d - .002, w=.006)
    bolts(f"{prefix}_fixings_satin_steel", [(x, z) for x in (-w / 2 + .03, w / 2 - .03) for z in (-h / 2 + .03, h / 2 - .03)], d, r=.009)


def status_light(name, x, z, y, mat):
    cyl(f"{name}_bezel_graphite", (x, y + .004, z), .018, .01, "graphite", axis="y", verts=20)
    cyl(f"{name}_{mat}", (x, y + .011, z), .012, .006, mat, axis="y", verts=20)


def airlock_control_panel():
    """Airlock cycle panel: a screen for the pressure readout, three large
    cycle buttons (seal, cycle, emergency stop) and an orange hazard band."""
    W, H, D = .52, .82, .07
    wall_shell("panel", W, H, D)
    box("screen_bezel_graphite", -.21, .21, D, D + .012, .04, .36, "graphite", .01)
    box("display_screen_glass_dark_glass", -.19, .19, D + .012, D + .015, .06, .34, "dark_glass", 0)
    box("display_glow_screen_cyan", -.17, -.05, D + .015, D + .017, .3, .32, "screen_cyan", 0)
    for i, (x, mat, label) in enumerate(((-.14, "screen_green", "seal"), (0, "amber", "cycle"), (.14, "red_cross", "stop"))):
        cyl(f"button_{label}_ring_graphite", (x, D + .006, -.1), .05, .012, "graphite", axis="y", verts=32, bevel=.003)
        cyl(f"button_{label}_{mat}", (x, D + .02, -.1), .038, .02, mat, axis="y", verts=32, bevel=.006)
        box(f"button_{label}_tag_slate_panel", x - .045, x + .045, D, D + .004, -.19, -.165, "slate_panel", 0)
    box("hazard_band_orange", -W / 2, W / 2, D - .001, D + .003, -.33, -.28, "orange", 0)
    join("hazard_stripes_graphite", [box("s", x, x + .03, D + .003, D + .005, -.33, -.28, "graphite", 0) for x in [-.24 + i * .07 for i in range(7)]])
    status_light("status_pressure", .19, .39, D, "screen_green")


def suit_service_panel():
    """Suit service station: a status screen, two umbilical ports with coiled
    hoses (oxygen teal, power orange) and a valve rail with status lights."""
    W, H, D = .86, 1.04, .09
    wall_shell("service", W, H, D)
    box("status_head_graphite", -.36, .36, D, D + .02, .24, .48, "graphite", .012)
    box("display_screen_glass_dark_glass", -.33, .1, D + .02, D + .023, .27, .45, "dark_glass", 0)
    box("display_glow_screen_cyan", -.3, -.08, D + .023, D + .025, .4, .42, "screen_cyan", 0)
    for i, x in enumerate((.17, .23, .29)):
        status_light(f"valve_light_{i}", x, .36, D + .02, ("screen_green", "screen_green", "amber_light")[i])
    for side, (x, mat) in enumerate(((-.2, "teal"), (.2, "orange"))):
        cyl(f"port_{side}_collar_satin_steel", (x, D + .02, .04), .07, .04, "satin_steel", axis="y", verts=32, bevel=.006)
        cyl(f"port_{side}_socket_graphite", (x, D + .042, .04), .045, .01, "graphite", axis="y", verts=32)
        # A loose coil of hose hanging below the port.
        coil = []
        for k in range(3):
            coil.append(torus("c", (x, D + .07, -.18 - k * .05), .085, .016, mat, axis="z"))
        coil.append(rod("h", (x, D + .04, .04), (x, D + .07, -.12), .016, mat))
        join(f"hose_{side}_{mat}", coil)
    box("valve_rail_satin_steel", -.36, .36, D, D + .03, -.42, -.38, "satin_steel", .006)
    join("valve_handles_orange", [box("v", x - .025, x + .025, D + .03, D + .06, -.43, -.37, "orange", .006) for x in (-.24, 0, .24)])
    box("name_plate_slate_panel", .12, .34, D + .02, D + .023, .27, .31, "slate_panel", 0)


def utility_conduit():
    """A pipe and cable run on stand-off brackets: water (teal), oxygen
    (white with an orange band), a satin return line and a cable tray."""
    L = 2.3
    for i, x in enumerate((-1.0, -.35, .35, 1.0)):
        box(f"bracket_{i}_dark_alloy", x - .03, x + .03, 0, .12, -.24, .24, "dark_alloy", .006)
        box(f"bracket_{i}_foot_graphite", x - .05, x + .05, 0, .012, -.26, .26, "graphite", .004)
    for z, r, mat in ((.16, .035, "teal"), (.06, .03, "white_painted"), (-.04, .025, "satin_steel")):
        cyl(f"pipe_{mat}", (0, .08, z), r, L, mat, axis="x", verts=24)
        join(f"pipe_clamps_{mat}_dark_alloy", [torus("c", (x, .08, z), r + .006, .006, "dark_alloy", axis="x") for x in (-1.0, -.35, .35, 1.0)])
    join("oxygen_bands_orange", [cyl("b", (x, .08, .06), .032, .05, "orange", axis="x", verts=24) for x in (-.68, 0, .68)])
    box("cable_tray_graphite", -L / 2, L / 2, .03, .13, -.2, -.17, "graphite", .004)
    join("cables_black_rubber", [cyl("c", (0, y, -.15), .012, L - .02, "black_rubber", axis="x", verts=10) for y in (.05, .08, .11)])


def corridor_light_strip():
    """Low wall route light: a graphite housing, a warm diffuser and end caps."""
    L = 1.5
    box("housing_graphite", -L / 2, L / 2, 0, .06, -.06, .06, "graphite", .012)
    box("light_diffuser_lamp_white", -L / 2 + .04, L / 2 - .04, .06, .066, -.035, .035, "lamp_white", .006)
    join("end_caps_satin_steel", [box("e", x - .02, x + .02, 0, .07, -.065, .065, "satin_steel", .008) for x in (-L / 2 + .02, L / 2 - .02)])
    box("route_arrow_orange", -.04, .04, .062, .068, -.06, -.045, "orange", 0)


def wayfinding_panel():
    """A wayfinding screen in a slim graphite frame with an orange side bar;
    the game draws live directions or the crew's own sign on the screen."""
    W, H = 1.1, .48
    box("frame_graphite", -W / 2, W / 2, 0, .045, -H / 2, H / 2, "graphite", .014)
    box("display_screen_glass_dark_glass", -W / 2 + .05, W / 2 - .03, .045, .048, -H / 2 + .03, H / 2 - .03, "dark_glass", 0)
    box("side_bar_orange", -W / 2 + .008, -W / 2 + .036, .045, .05, -H / 2 + .03, H / 2 - .03, "orange", .004)
    box("top_trim_satin_steel", -W / 2, W / 2, .03, .05, H / 2 - .008, H / 2 + .004, "satin_steel", .003)


def dust_grate():
    """A walk-over dust grate: a recessed graphite tray with satin bars, ramped
    edges so it can't be tripped on, and orange edge markings."""
    W, D, Ht = 1.3, .95, .05
    box("tray_graphite", -W / 2, W / 2, -D / 2, D / 2, 0, Ht * .6, "graphite", .006)
    join("ramps_dark_alloy", [box("r", -W / 2 - .05, W / 2 + .05, y - .03, y + .03, 0, Ht * .7, "dark_alloy", .02) for y in (-D / 2, D / 2)]
         + [box("r", x - .03, x + .03, -D / 2, D / 2, 0, Ht * .7, "dark_alloy", .02) for x in (-W / 2, W / 2)])
    join("bars_satin_steel", [box("b", x - .012, x + .012, -D / 2 + .04, D / 2 - .04, Ht * .3, Ht, "satin_steel", .003) for x in [-W / 2 + .07 + i * .0525 for i in range(23)]])
    join("edge_marks_orange", [box("m", -W / 2 - .04, W / 2 + .04, y - .012, y + .012, Ht * .7, Ht * .7 + .003, "orange", 0) for y in (-D / 2, D / 2)])


MODELS = [
    ("airlock_control_panel", airlock_control_panel, "wall"),
    ("suit_service_panel", suit_service_panel, "wall"),
    ("utility_conduit", utility_conduit, "wall"),
    ("corridor_light_strip", corridor_light_strip, "wall"),
    ("wayfinding_panel", wayfinding_panel, "wall"),
    ("dust_grate", dust_grate, "floor"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"House refresh: the oldest placeholder panels rebuilt in the shared house style"')
exec(_TAIL)
