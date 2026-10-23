"""Blender (5.x) build script: Living on Mars pack for MARS: HABITAT (v1).

Run:  blender --background --python build_living_on_mars.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

The equipment Missions 7-10 need (docs/missions-7-10-design.md): radiation
shielding (printed regolith blocks, a water wall), the storm shelter locker,
a hull patch kit, an air reserve rack and a spare parts rack. A detail step
up from the earlier packs, in the same house style (docs/house-style.md):
white shells with rounded bevels, graphite frames and bezels, satin metal
trim, one orange accent per item, cyan screens and small status lights.
Regolith keeps its natural Mars colour (the house materials leave it alone).
Shares the furnishings pack's materials, helpers and export.

Metres. Floor items (the shield wall and water wall stand against a wall):
floor origin, front +Y in Blender (glTF -Z). Wall items:
back face on the wall at Blender y = 0, front +Y, centred on the origin.
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
    "regolith_printed": ((0.56, 0.31, 0.19, 1), .0, .9),
    "regolith_dark": ((0.40, 0.21, 0.13, 1), .0, .92),
    "water_blue": ((0.25, 0.55, 0.72, 0.55), .0, .08),
    "red_light": ((0.95, 0.30, 0.25, 1), .0, .3),
    "amber_light": ((1.0, 0.72, 0.25, 1), .0, .3),
    "composite_white": ((0.92, 0.93, 0.91, 1), .05, .45),
})
GLOW.update({"red_light": 1.4, "amber_light": 1.4})


def wall_shell(prefix, w, h, d, mat="white_painted"):
    box(f"{prefix}_backplate_graphite", -w / 2 - .015, w / 2 + .015, 0, .012, -h / 2 - .015, h / 2 + .015, "graphite", .006)
    box(f"{prefix}_body_{mat}", -w / 2, w / 2, .012, d, -h / 2, h / 2, mat, .022)
    gasket(f"{prefix}_seam_black_rubber", -w / 2 + .01, w / 2 - .01, -h / 2 + .01, h / 2 - .01, d - .002, w=.006)
    bolts(f"{prefix}_fixings_satin_steel", [(x, z) for x in (-w / 2 + .03, w / 2 - .03) for z in (-h / 2 + .03, h / 2 - .03)], d, r=.009)


def status_light(name, x, z, y, mat):
    cyl(f"{name}_bezel_graphite", (x, y + .004, z), .018, .01, "graphite", axis="y", verts=20)
    cyl(f"{name}_{mat}", (x, y + .011, z), .012, .006, mat, axis="y", verts=20)


def trefoil(name, cx, cz, y, r, mat):
    """The radiation symbol: three blades round a dot, flat on a face."""
    parts = [cyl("d", (cx, y, cz), r * .18, .004, mat, axis="y", verts=20)]
    for k in range(3):
        a0 = math.radians(90 + k * 120 - 30)
        pts = []
        for i in range(7):
            a = a0 + math.radians(60) * i / 6
            pts.append((cx + math.cos(a) * r, cz + math.sin(a) * r))
        for i in range(6):
            a = a0 + math.radians(60) * (i + .5) / 6
            mid = Vector((cx + math.cos(a) * r * .62, 0, cz + math.sin(a) * r * .62))
            parts.append(box("b", mid.x - r * .2, mid.x + r * .2, y, y + .004, mid.z - r * .2, mid.z + r * .2, mat, 0))
    join(name, parts)


def centre_depth(depth):
    """Floor items stand on the floor centred on the origin: move the parts
    built from the wall (y = 0) forward so the footprint is centred."""
    for obj in PARTS: obj.location.y -= depth / 2


# ---------- radiation shielding ----------

def regolith_shield_block():
    """Printed regolith shielding: a wall of interlocking blocks printed from
    Mars soil (layer lines show the printer's passes), held in a satin steel
    frame with corner brackets. Thick and heavy: about 20 cm of soil."""
    W, H, D = 1.2, 2.1, .3
    # Frame
    box("frame_left_dark_alloy", -W / 2 - .04, -W / 2, 0, D + .02, 0, H, "dark_alloy", .008)
    box("frame_right_dark_alloy", W / 2, W / 2 + .04, 0, D + .02, 0, H, "dark_alloy", .008)
    box("frame_top_dark_alloy", -W / 2 - .04, W / 2 + .04, 0, D + .02, H, H + .05, "dark_alloy", .008)
    box("frame_base_graphite", -W / 2 - .06, W / 2 + .06, 0, D + .06, 0, .06, "graphite", .01)
    bolts("frame_bolts_satin_steel", [(x, z) for x in (-W / 2 - .02, W / 2 + .02) for z in (.25, H / 2, H - .25)], D + .02, r=.012)
    # Blocks: running bond, each with printed layer ridges on the face.
    rows = 7
    bh = (H - .06) / rows
    blocks = []
    ridges = []
    for row in range(rows):
        z0 = .06 + row * bh
        offset = (row % 2) * .2
        x = -W / 2 - offset
        while x < W / 2 - .01:
            x0 = max(-W / 2, x); x1 = min(W / 2, x + .4)
            if x1 - x0 > .05:
                inset = .004 + (row * 7 + int((x + 1) * 10)) % 3 * .004
                blocks.append(box("blk", x0 + .006, x1 - .006, .01, D - inset, z0 + .006, z0 + bh - .006, "regolith_printed", .02))
                for k in range(1, 6):
                    zz = z0 + bh * k / 6
                    ridges.append(box("r", x0 + .02, x1 - .02, D - inset, D - inset + .005, zz - .004, zz + .004, "regolith_dark", 0))
            x += .4
    join("blocks_regolith_printed", blocks)
    join("layer_lines_regolith_dark", ridges)
    # A small tag: printed on Mars.
    box("tag_plate_white_painted", W / 2 - .3, W / 2 - .06, D + .02, D + .03, H - .2, H - .1, "white_painted", .004)
    box("tag_band_orange", W / 2 - .3, W / 2 - .06, D + .03, D + .033, H - .2, H - .17, "orange", 0)
    centre_depth(D + .06)


def water_wall_panel():
    """A water wall: a slim tank of water hung on the wall as shielding (and
    a store of 200 L). Quilted bladder face, a sight glass showing the level,
    a fill valve and a level gauge."""
    W, H, D = 1.2, 2.0, .26
    box("frame_backplate_graphite", -W / 2 - .02, W / 2 + .02, 0, .015, 0, H, "graphite", .006)
    box("tank_shell_white_painted", -W / 2, W / 2, .015, D, .04, H - .04, "white_painted", .04)
    # Quilted face: a grid of soft cushions.
    quilt = []
    for i in range(3):
        for j in range(5):
            x0 = -W / 2 + .1 + i * .3; z0 = .2 + j * .32
            quilt.append(box("q", x0, x0 + .27, D, D + .025, z0, z0 + .29, "warm_shell", .05))
    join("bladder_cushions_warm_shell", quilt)
    # Sight glass with water inside.
    box("sight_frame_satin_steel", W / 2 - .12, W / 2 - .04, D, D + .04, .2, H - .2, "satin_steel", .01)
    box("sight_glass_dark_glass", W / 2 - .11, W / 2 - .05, D + .04, D + .045, .22, H - .22, "dark_glass", 0)
    box("water_level_water_blue", W / 2 - .105, W / 2 - .055, D + .045, D + .05, .22, H * .78, "water_blue", 0)
    join("level_marks_graphite", [box("m", W / 2 - .13, W / 2 - .11, D + .04, D + .046, z - .003, z + .003, "graphite", 0) for z in [.4 + k * .25 for k in range(6)]])
    # Fill valve and pipe at the top.
    cyl("fill_pipe_satin_steel", (-W / 2 + .2, D + .03, H - .02), .03, .12, "satin_steel", axis="z", verts=20)
    cyl("fill_valve_wheel_orange", (-W / 2 + .2, D + .03, H + .05), .06, .02, "orange", axis="z", verts=24, bevel=.004)
    # Gauge.
    cyl("gauge_body_graphite", (-W / 2 + .2, D + .02, H - .22), .07, .04, "graphite", axis="y", verts=32, bevel=.004)
    cyl("gauge_face_white_painted", (-W / 2 + .2, D + .042, H - .22), .055, .004, "white_painted", axis="y", verts=32)
    box("gauge_needle_red_light", -W / 2 + .198, -W / 2 + .202, D + .046, D + .05, H - .22, H - .17, "red_light", 0)
    bolts("tank_fixings_satin_steel", [(x, z) for x in (-W / 2 + .04, W / 2 - .04) for z in (.08, H - .08)], D, r=.011)
    centre_depth(D + .05)


def storm_shelter_locker():
    """The storm shelter locker: emergency food, water, first aid and
    dosimeters for a day in the shelter. A tall white locker with two doors,
    an amber radiation band with the trefoil, a dosimeter readout and an
    orange handle. Placing it makes its room the storm shelter."""
    W, D, H = .9, .55, 2.0
    box("plinth_graphite", -W / 2 + .03, W / 2 - .03, -D / 2 + .03, D / 2 - .03, 0, .08, "graphite", .01)
    box("body_white_painted", -W / 2, W / 2, -D / 2, D / 2 - .03, .08, H - .04, "white_painted", .02)
    box("cap_white_painted", -W / 2 - .015, W / 2 + .015, -D / 2 - .015, D / 2, H - .05, H, "white_painted", .02)
    # Doors (the rig swings these).
    for side, (x0, x1) in (("L", (-W / 2 + .02, -.005)), ("R", (.005, W / 2 - .02))):
        door = []
        door.append(box("d", x0, x1, D / 2 - .03, D / 2, .12, H - .09, "white_painted", .012))
        door.append(box("v", x0 + .06, x1 - .06, D / 2, D / 2 + .004, H - .42, H - .3, "graphite", .002))
        join(f"Shelter_Door_{side}_white_painted", door)
        gasket(f"Shelter_Door_{side}_seam_black_rubber", x0 + .01, x1 - .01, .13, H - .1, D / 2 - .001, w=.005)
    # Radiation band across both doors.
    box("Shelter_Door_L_band_amber", -W / 2 + .02, -.005, D / 2, D / 2 + .004, .95, 1.2, "amber", 0)
    box("Shelter_Door_R_band_amber", .005, W / 2 - .02, D / 2, D / 2 + .004, .95, 1.2, "amber", 0)
    trefoil("Shelter_Door_L_trefoil_graphite", -.22, 1.075, D / 2 + .004, .09, "graphite")
    # Handles.
    box("Shelter_Door_L_handle_orange", -.06, -.035, D / 2 + .004, D / 2 + .04, .8, 1.0, "orange", .008)
    box("Shelter_Door_R_handle_orange", .035, .06, D / 2 + .004, D / 2 + .04, .8, 1.0, "orange", .008)
    # Dosimeter readout panel on the right door.
    box("Shelter_Door_R_screen_bezel_graphite", .1, .38, D / 2, D / 2 + .012, 1.45, 1.66, "graphite", .008)
    box("display_screen_glass_dark_glass", .115, .365, D / 2 + .012, D / 2 + .015, 1.465, 1.645, "dark_glass", 0)
    box("Shelter_Door_R_readout_screen_green", .13, .26, D / 2 + .015, D / 2 + .017, 1.6, 1.625, "screen_green", 0)
    status_light("Shelter_Door_R_status", .33, 1.5, D / 2 + .012, "amber_light")
    # Vents near the base.
    vent("vent_graphite", -.3, .3, .14, .22, D / 2 - .03 + .001, slats=6)


def hull_patch_kit():
    """Hull patch kit: a wall case with a hinged lid, holding patch plates,
    sealant cartridges and a cutting tool. An emergency light on top."""
    W, H, D = .62, .48, .17
    box("case_backplate_graphite", -W / 2 - .02, W / 2 + .02, 0, .012, -H / 2 - .02, H / 2 + .02, "graphite", .006)
    box("case_body_white_painted", -W / 2, W / 2, .012, D - .05, -H / 2, H / 2, "white_painted", .02)
    lid = [box("l", -W / 2, W / 2, D - .05, D, -H / 2, H / 2, "white_painted", .02)]
    join("Patch_Lid_white_painted", lid)
    gasket("Patch_Lid_seam_black_rubber", -W / 2 + .01, W / 2 - .01, -H / 2 + .01, H / 2 - .01, D - .051, w=.006)
    box("Patch_Lid_band_orange", -W / 2, W / 2, D, D + .004, -.06, .06, "orange", 0)
    box("Patch_Lid_label_graphite", -.2, .2, D + .004, D + .007, -.035, .035, "graphite", 0)
    join("Patch_Lid_latches_satin_steel", [box("t", x - .03, x + .03, D - .01, D + .02, -H / 2 - .015, -H / 2 + .02, "satin_steel", .005) for x in (-.18, .18)])
    box("Patch_Lid_handle_graphite", -.1, .1, D + .004, D + .03, H / 2 - .07, H / 2 - .045, "graphite", .008)
    # Inside (seen with the lid open): patch plates and sealant.
    join("patch_plates_satin_steel", [box("p", -.26 + k * .012, -.02 + k * .012, .03 + k * .012, .036 + k * .012, -.18, .18, "satin_steel", .004) for k in range(4)])
    join("sealant_cartridges_amber", [cyl("c", (x, .07, 0), .028, .3, "amber", axis="z", verts=20) for x in (.06, .13, .2)])
    # Emergency light on top.
    cyl("beacon_base_graphite", (0, .08, H / 2 + .02), .04, .04, "graphite", axis="z", verts=24)
    cyl("beacon_red_light", (0, .08, H / 2 + .06), .032, .05, "red_light", axis="z", verts=24, bevel=.006)


def air_reserve_rack():
    """Air reserve rack: four composite tanks of stored air (nitrogen and
    oxygen) on a frame, piped to a manifold with gauges and a main valve.
    Refills a vented section once a breach is patched."""
    W, D, H = 1.7, .72, 1.55
    # Frame
    for x in (-W / 2, W / 2 - .05):
        for y in (-D / 2, D / 2 - .05):
            box(f"post_{int(x*10)}_{int(y*10)}_dark_alloy", x, x + .05, y, y + .05, 0, H, "dark_alloy", .008)
    for z in (.06, H - .06):
        box(f"rail_front_{int(z*10)}_dark_alloy", -W / 2, W / 2, D / 2 - .05, D / 2, z - .025, z + .025, "dark_alloy", .006)
        box(f"rail_back_{int(z*10)}_dark_alloy", -W / 2, W / 2, -D / 2, -D / 2 + .05, z - .025, z + .025, "dark_alloy", .006)
    box("base_plate_graphite", -W / 2 - .03, W / 2 + .03, -D / 2 - .03, D / 2 + .03, 0, .03, "graphite", .006)
    # Tanks: horizontal, with domed ends and colour bands.
    for i, z in enumerate((.3, .62, .94, 1.26)):
        cyl(f"tank_{i}_composite_white", (-.08, 0, z), .14, W - .45, "composite_white", axis="x", verts=40, bevel=.03)
        sphere(f"tank_{i}_dome_composite_white", (-.08 - (W - .45) / 2, 0, z), .138, "composite_white", scale=(.5, 1, 1))
        sphere(f"tank_{i}_neck_composite_white", (-.08 + (W - .45) / 2, 0, z), .138, "composite_white", scale=(.5, 1, 1))
        band = "teal" if i < 3 else "white_painted"
        cyl(f"tank_{i}_band_{band}", (-.08, 0, z), .143, .08, band, axis="x", verts=40)
        join(f"tank_{i}_straps_satin_steel", [torus("s", (x, 0, z), .145, .008, "satin_steel", axis="x") for x in (-.5, .34)])
        cyl(f"tank_{i}_valve_satin_steel", (-.08 + (W - .45) / 2 + .1, 0, z), .025, .1, "satin_steel", axis="x", verts=16)
    # Manifold on the right end.
    box("manifold_block_satin_steel", W / 2 - .2, W / 2 - .08, -.06, .06, .2, 1.36, "satin_steel", .01)
    for i, z in enumerate((.45, .85)):
        cyl(f"gauge_{i}_body_graphite", (W / 2 - .14, .1, z), .055, .04, "graphite", axis="y", verts=32, bevel=.004)
        cyl(f"gauge_{i}_face_white_painted", (W / 2 - .14, .122, z), .044, .004, "white_painted", axis="y", verts=32)
        box(f"gauge_{i}_needle_red_light", W / 2 - .142, W / 2 - .138, .126, .13, z, z + .035, "red_light", 0)
    cyl("main_valve_wheel_orange", (W / 2 - .14, .12, 1.15), .07, .025, "orange", axis="y", verts=28, bevel=.004)
    status_light("rack_status", W / 2 - .14, 1.32, .06, "screen_green")


def spare_parts_rack():
    """Spare parts rack: open shelving with labelled parts bins (pumps,
    filters, seals, boards), an inventory tablet and one orange-handled
    drawer of tools. Every repair uses a part."""
    W, D, H = 1.25, .5, 1.95
    for x in (-W / 2, W / 2 - .04):
        box(f"upright_{'L' if x < 0 else 'R'}_dark_alloy", x, x + .04, -D / 2, D / 2, 0, H, "dark_alloy", .008)
    shelves = (.08, .5, .92, 1.34, 1.76)
    for i, z in enumerate(shelves):
        box(f"shelf_{i}_white_painted", -W / 2 + .04, W / 2 - .04, -D / 2, D / 2, z - .02, z + .02, "white_painted", .006)
    box("back_panel_graphite", -W / 2 + .04, W / 2 - .04, -D / 2, -D / 2 + .015, .06, H - .05, "graphite", .004)
    # Bins on the middle shelves.
    for row, z in enumerate(shelves[1:4]):
        for k in range(3):
            x0 = -W / 2 + .08 + k * .375
            box(f"bin_{row}_{k}_graphite", x0, x0 + .33, -D / 2 + .04, D / 2 - .03, z + .02, z + .26, "graphite", .015)
            box(f"bin_{row}_{k}_label_white_painted", x0 + .08, x0 + .25, D / 2 - .03, D / 2 - .025, z + .17, z + .23, "white_painted", .003)
            box(f"bin_{row}_{k}_mark_teal", x0 + .09, x0 + .12, D / 2 - .025, D / 2 - .022, z + .18, z + .22, "teal", 0)
    # Some parts showing above the bins.
    cyl("part_pump_satin_steel", (-.38, 0, 1.47), .07, .18, "satin_steel", axis="x", verts=24, bevel=.01)
    cyl("part_filter_white_painted", (0, 0, 1.47), .06, .2, "white_painted", axis="z", verts=24, bevel=.01)
    torus("part_seal_black_rubber", (.36, 0, 1.4), .07, .015, "black_rubber", axis="z")
    # Bottom drawer of tools.
    box("Tool_Drawer_front_white_painted", -W / 2 + .06, W / 2 - .06, D / 2 - .02, D / 2 + .01, .1, .46, "white_painted", .012)
    box("Tool_Drawer_handle_orange", -.2, .2, D / 2 + .01, D / 2 + .035, .38, .41, "orange", .008)
    # Inventory tablet on the top shelf.
    box("tablet_body_graphite", -.2, .2, .05, .07, 1.78, 2.06, "graphite", .012)
    box("display_screen_glass_dark_glass", -.18, .18, .07, .073, 1.8, 2.04, "dark_glass", 0)
    box("tablet_rows_screen_cyan", -.15, .05, .073, .075, 1.95, 1.97, "screen_cyan", 0)


MODELS = [
    ("regolith_shield_block", regolith_shield_block, "floor"),
    ("water_wall_panel", water_wall_panel, "floor"),
    ("storm_shelter_locker", storm_shelter_locker, "floor"),
    ("hull_patch_kit", hull_patch_kit, "wall"),
    ("air_reserve_rack", air_reserve_rack, "floor"),
    ("spare_parts_rack", spare_parts_rack, "floor"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Living on Mars: shielding, shelter, breach and repair equipment for Missions 7-10, in the house style"')
exec(_TAIL)
