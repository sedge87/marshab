"""Blender (5.x) build script: roof fittings for the room changes (31 Oct).

Run:  blender --background --python build_roof_fittings.py -- <out_dir> [id ...]
Writes <out_dir>/models/<id>.glb, previews/<id>.png and asset_manifest.json.

Each room type carries a fitting on its roof that says what it does from
outside (scripts/build_controller.gd ROOF_ACCESSORY_SCENES). The room changes
(docs/room-changes.md) gave three rooms new jobs, so they get new fittings:
  roof_sleeping_quarters   a quiet air intake: hooded inlet, a silencer drum
  roof_day_room            the kitchen's extract stack over a filter box,
                           with a heat-recovery fin bank
  roof_storage_recycling   a roof cargo hatch and a small davit hoist
(The General Module takes the old Living Quarters comms mast.)

Same footprint as the old fittings (a 2.36 m roof plate) and the furnishings
pack's materials and helpers (house style: white shells, graphite frames,
satin metal, one orange accent each). Metres, origin on the roof at the
plate's centre; the game seats the lowest point on the roof.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FURNISHINGS = os.path.join(HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_TEXT = open(FURNISHINGS, encoding="utf-8").read()
exec(_TEXT.split("def galley_table_set")[0])

PLATE = 1.18   # half the roof plate


def plate(prefix):
    """The mounting plate every fitting stands on: a panel in a dark frame, bolted down."""
    box(f"{prefix}_plate_warm_panel", -PLATE, PLATE, -PLATE, PLATE, 0, 0.05, "warm_panel", 0.01)
    rim = [box("r", -PLATE, PLATE, y0, y1, 0.05, 0.075, "dark_alloy", 0.004) for y0, y1 in ((-PLATE, -PLATE + 0.05), (PLATE - 0.05, PLATE))]
    rim += [box("r", x0, x1, -PLATE, PLATE, 0.05, 0.075, "dark_alloy", 0.004) for x0, x1 in ((-PLATE, -PLATE + 0.05), (PLATE - 0.05, PLATE))]
    join(f"{prefix}_rim_dark_alloy", rim)
    corners = [(x, y) for x in (-PLATE + 0.1, PLATE - 0.1) for y in (-PLATE + 0.1, PLATE - 0.1)]
    join(f"{prefix}_bolts_satin_steel", [cyl("b", (x, y, 0.06), 0.018, 0.03, "satin_steel", verts=12) for x, y in corners])


def status_light(name, x, y, z, mat="bright_green"):
    join(name, [box("h", x - 0.035, x + 0.035, y - 0.02, y + 0.02, z, z + 0.05, "graphite", 0.006),
                box("l", x - 0.02, x + 0.02, y + 0.018, y + 0.024, z + 0.012, z + 0.038, mat, 0.002)])


def roof_sleeping_quarters():
    """Quiet air intake: no machinery, just a hooded inlet and a silencer."""
    plate("intake")
    # The inlet box and its overhanging hood, the slatted face towards the front.
    cabinet("intake_box", -0.55, 0.35, -0.35, 0.2, 0.075, 0.55, body="white_painted", cap="white_painted")
    box("intake_hood_warm_shell", -0.6, 0.4, -0.4, 0.42, 0.55, 0.6, "warm_shell", 0.02)
    vent("intake_inlet_vent", -0.48, 0.28, 0.16, 0.48, 0.2, slats=6)
    gasket("intake_seam_rubber", -0.5, 0.3, 0.14, 0.5, 0.2)
    # A silencer drum lying beside it, on two saddles, with banded ends.
    cyl("intake_silencer_satin_steel", (0.75, -0.1, 0.3), 0.17, 0.95, "satin_steel", axis="y", verts=40, bevel=0.01)
    join("intake_bands_dark_alloy", [cyl("b", (0.75, y, 0.3), 0.18, 0.04, "dark_alloy", axis="y", verts=40) for y in (-0.52, 0.32)])
    join("intake_saddles_graphite", [box("s", 0.6, 0.9, y - 0.05, y + 0.05, 0.075, 0.2, "graphite", 0.008) for y in (-0.35, 0.15)])
    rod("intake_duct_alloy", (0.35, -0.1, 0.3), (0.58, -0.1, 0.3), 0.09, "alloy", verts=24)
    # The one accent: an orange band round the hood's front edge.
    box("intake_band_orange", -0.6, 0.4, 0.42, 0.44, 0.555, 0.595, "orange", 0.004)
    status_light("intake_status_light", -0.42, 0.21, 0.08)


def roof_day_room():
    """The kitchen's extract stack on a filter box, with a heat-recovery fin bank."""
    plate("extract")
    cabinet("extract_filter", -0.4, 0.4, -0.4, 0.4, 0.075, 0.55, body="white_painted", cap="white_painted")
    vent("extract_filter_vent", -0.3, 0.3, 0.17, 0.45, 0.4, slats=6)
    gasket("extract_filter_seam_rubber", -0.32, 0.32, 0.15, 0.47, 0.4)
    bolts("extract_filter_bolts", [(-0.33, 0.13), (0.33, 0.13), (-0.33, 0.49), (0.33, 0.49)], 0.4)
    # The stack, its collar and a cone cowl to keep dust out.
    cyl("extract_collar_dark_alloy", (0, 0, 0.6), 0.2, 0.1, "dark_alloy", verts=40)
    cyl("extract_stack_satin_steel", (0, 0, 1.0), 0.14, 0.8, "satin_steel", verts=40, bevel=0.006)
    cyl("extract_band_orange", (0, 0, 1.12), 0.145, 0.06, "orange", verts=40)
    join("extract_struts_alloy", [rod("s", (x * 0.1, y * 0.1, 1.38), (x * 0.1, y * 0.1, 1.48), 0.012, "alloy") for x, y in ((1, 1), (-1, 1), (1, -1), (-1, -1))])
    cyl("extract_cowl_dark_alloy", (0, 0, 1.53), 0.26, 0.12, "dark_alloy", verts=40, radius2=0.05)
    # Heat recovery: a fin bank beside the box, piped back into the stack.
    fins = [box("f", 0.62, 1.0, -0.45 + i * 0.075, -0.43 + i * 0.075, 0.12, 0.5, "dark_alloy", 0.003) for i in range(10)]
    join("extract_fins_dark_alloy", fins)
    join("extract_fin_frame_graphite", [box("r", 0.6, 1.02, -0.5, 0.3, z, z + 0.04, "graphite", 0.006) for z in (0.08, 0.5)])
    rod("extract_return_pipe_alloy", (0.4, -0.1, 0.35), (0.62, -0.1, 0.35), 0.04, "alloy", verts=20)
    status_light("extract_status_light", -0.3, 0.41, 0.1)


def roof_storage_recycling():
    """A roof cargo hatch for crates going in and baled waste going out, and a davit to lift them."""
    plate("hatch")
    # The hatch: a raised coaming, a white lid with a seam, and dogs round it.
    box("hatch_coaming_graphite", -0.6, 0.5, -0.55, 0.55, 0.075, 0.2, "graphite", 0.012)
    box("hatch_lid_white_painted", -0.56, 0.46, -0.51, 0.51, 0.2, 0.27, "white_painted", 0.02)
    join("hatch_seam_black_rubber", [box("g", -0.57, 0.47, -0.52, 0.52, 0.195, 0.21, "black_rubber", 0)])
    box("hatch_lid_panel_warm_panel", -0.4, 0.3, -0.35, 0.35, 0.27, 0.285, "warm_panel", 0.006)
    dogs = [box("d", x - 0.04, x + 0.04, y - 0.03, y + 0.03, 0.2, 0.3, "satin_steel", 0.006) for x, y in ((-0.6, 0), (0.5, 0), (-0.05, -0.55), (-0.05, 0.55))]
    join("hatch_dogs_satin_steel", dogs)
    rod("hatch_grab_bar_satin_steel", (-0.25, 0.0, 0.33), (0.15, 0.0, 0.33), 0.016, "satin_steel")
    join("hatch_grab_posts_satin_steel", [rod("p", (x, 0.0, 0.28), (x, 0.0, 0.33), 0.012, "satin_steel") for x in (-0.22, 0.12)])
    # The davit: a post on a base, an arm over the hatch, a hook block (the one accent).
    box("davit_base_dark_alloy", 0.72, 1.02, -0.85, -0.55, 0.075, 0.14, "dark_alloy", 0.01)
    cyl("davit_post_satin_steel", (0.87, -0.7, 0.75), 0.055, 1.2, "satin_steel", verts=24)
    rod("davit_arm_satin_steel", (0.87, -0.7, 1.32), (0.05, -0.05, 1.32), 0.04, "satin_steel", verts=20)
    rod("davit_brace_alloy", (0.87, -0.7, 1.0), (0.5, -0.41, 1.3), 0.02, "alloy")
    rod("davit_cable_dark_alloy", (0.05, -0.05, 1.3), (0.05, -0.05, 0.75), 0.006, "dark_alloy", verts=8)
    box("davit_hook_block_orange", 0.0, 0.1, -0.1, 0.0, 0.62, 0.76, "orange", 0.012)
    status_light("hatch_status_light", 0.55, 0.6, 0.08, mat="amber")


MODELS = [
    ("roof_sleeping_quarters", roof_sleeping_quarters, "roof"),
    ("roof_day_room", roof_day_room, "roof"),
    ("roof_storage_recycling", roof_storage_recycling, "roof"),
]

_TAIL = _TEXT.split("# ---------- build, export, preview ----------")[1]
_TAIL = _TAIL.replace('"Practical habitat furnishings, v2 detail pass (matches the Martian/Hail Mary packs)"',
                      '"Roof fittings for the room changes (31 Oct), same materials as the furnishings pack"')
exec(_TAIL)
