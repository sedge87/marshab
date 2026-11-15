"""Generate the test region (gameplay loop prototype, 31 Oct 2026).

One 6 km x 6 km composite region with two landing zones (docs/gameplay-loop-brief.md
§5.1): open plains with mesas in the south-west, a 2.2 km crater with a layered central
mound in the east, a canyon scarp along the north edge, a dune field below it,
polygon-cracked ice fields in the north-west, and ragged hills framing the edge.
(-Z is north.)

Writes assets/terrain/<id>/:
  height.r16.gz   heights, 16-bit unsigned little-endian, rows = +Z, gzip; point (i, j)
                  is at x = -half + i * spacing, z = -half + j * spacing
  region.json     size, spacing, height range, landing zones, home and the rings, caves, fissures,
                  step lines, kit places, viewpoints and the design's checks
  ground.png      red the ground kind, green the hidden layer (hollow ground), blue shallow ice
  control.u32.gz  Terrain3D control map: base texture by zone, bedrock on slopes
  colour.png      Terrain3D colour map (half resolution): large-scale tint
  ground_*.png    Terrain3D textures: albedo + height (alpha), normal + roughness (alpha)

Every landform comes from data/region_layout.json (docs/terrain-design.md §13); this script holds the recipes.

Usage: python tools/generate_region.py [region_id] [--quick] [--layout path]
"""
import gzip
import json
import math
import os
import sys
import time

import numpy as np
from PIL import Image

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
QUICK = "--quick" in sys.argv   # heights, maps and preview only: skips the ground textures
REGION_ID = ARGS[0] if ARGS else "test_region"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "terrain", REGION_ID)

# ---------- the layout (data/region_layout.json, docs/terrain-design.md §13) ----------
# Every landform's place and numbers live in the layout file; this script holds how each kind is made.
# The names below are the layout read back into the shapes the recipes were written for.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import region_layout   # noqa: E402

LAYOUT_PATH = next((sys.argv[k + 1] for k, a in enumerate(sys.argv[:-1]) if a == "--layout"), region_layout.PATH)
LAYOUT = region_layout.load(LAYOUT_PATH)
ARGS = [a for a in ARGS if a != LAYOUT_PATH]
REGION_ID = ARGS[0] if ARGS else LAYOUT["region"].get("id", "test_region")
OUT = os.path.join(ROOT, "assets", "terrain", REGION_ID)
_R = LAYOUT["region"]


def landforms(kind):
    """Every landform of a kind, in the file's order."""
    return region_layout.by_kind(LAYOUT, kind)


def landform(landform_id):
    return region_layout.by_id(LAYOUT, landform_id)


def seed_of(entry):
    return region_layout.seed_of(LAYOUT, entry)


def kind_seed(kind, fallback):
    """The random stream a kind's recipe draws from (the first landform's seed; kinds made before the layout
    file shared one stream, kept so the land stays the same)."""
    found = landforms(kind)
    return seed_of(found[0]) if found else fallback


def _xz(v):
    return (float(v[0]), float(v[1]))


N = int(_R["size"])            # points per side
SPACING = float(_R["spacing"])  # metres between points
HALF = N * SPACING / 2.0
SEED = int(_R["seed"])

# Landing zones (region coordinates, metres; the base is built around them).
ZONES = {k: {"centre": _xz(v["centre"]), "flat_radius": v["flat_radius"], "label": v["label"]} for k, v in _R["zones"].items()}
_c = landform("big_crater")
CRATER = {"centre": _xz(_c["centre"]), "radius": _c["radius"], "depth": _c["depth"], "rim": _c["rim"]}
_m = landform("mound")
MOUND = {"centre": _xz(_m["centre"]), "radius": _m["radius"], "height": _m["height"]}
_d = landforms("dune_field")[0]
DUNES = _xz(_d["centre"])          # the dune field's centre, clear of the crater rim
DUNES_RADIUS = _d["radius"]        # across the wind; it runs 1.8 times longer along it
DUNE_WIND = _xz(_R["wind"])        # along the canyon, away from the crater
ICE_PATCHES = [(e["centre"][0], e["centre"][1], e["radius"]) for e in landforms("ice_field")]
# The ancient river: from the southern hills it meanders north, widens into
# a cliff-walled valley (the riverbed landing zone), breaches the crater's
# south-west rim and spreads a delta over the crater floor, like Jezero.
_rv = landform("river")
RIVER_SOURCE = _xz(_rv["source"])
RIVER_MOUTH_ANGLE = _xz(_rv["mouth_angle"])   # where it breaks through the rim, from the crater's centre
RIVER_WIDE_AT = _rv["wide_at"]                # how far along the valley widens (0 source, 1 rim)


def river_course():
    """The river's centreline: points from the source to the delta's apex,
    each with how far along it is (0..1 at the rim, more inside the crater)."""
    cx, cz = CRATER["centre"]
    rim = np.array([cx + RIVER_MOUTH_ANGLE[0] * CRATER["radius"], cz + RIVER_MOUTH_ANGLE[1] * CRATER["radius"]])
    apex = np.array([cx, cz]) + (rim - np.array([cx, cz])) * 0.66
    start = np.array(RIVER_SOURCE)
    along = rim - start
    perp = np.array([-along[1], along[0]]) / np.linalg.norm(along)
    points, params = [], []
    for i in range(361):
        t = i / 360.0
        swing = 230.0 * math.sin(math.tau * 3.3 * t + 0.6) + 60.0 * math.sin(math.tau * 8.1 * t + 1.7)
        points.append(start + along * t + perp * swing * math.sin(math.pi * t) ** 0.6)
        params.append(t)
    for i in range(1, 41):
        t = i / 40.0
        points.append(rim + (apex - rim) * t)
        params.append(1.0 + 0.25 * t)
    return np.array(points), np.array(params)


RIVER_POINTS, RIVER_T = river_course()
_wide = int(round(RIVER_WIDE_AT * 360))
_rz = _R["riverbed_zone"]
ZONES["riverbed"] = {"centre": (float(RIVER_POINTS[_wide][0]), float(RIVER_POINTS[_wide][1])), "flat_radius": _rz["flat_radius"], "blend": _rz["blend"], "label": _rz["label"]}
# Named places for the region map (region metres); some are points on the river.
FEATURES = [(e["name"], tuple(float(v) for v in RIVER_POINTS[e["river_point"]]) if "river_point" in e else _xz(e["position"])) for e in LAYOUT["map_names"]]

# Ring 1's three are low, with scree you can scramble; the far mesa (300, 1500) has a real cliff, the first
# rope face; the east one stands as an island in the lava plain; the last is the glacier's mesa in the ice fields.
_mesas = landforms("mesa")
MESAS = [(e["centre"][0], e["centre"][1], e["radius"], e["height"]) for e in _mesas]
# Mesas with a ramp of fallen wall the rover can climb: mesa index -> the ramp's direction (radians).
MESA_RAMPS = {k: e["ramp"] for k, e in enumerate(_mesas) if e.get("ramp") is not None}
# A scree gully up a mesa's flank (a steep short cut on foot): mesa index -> direction.
MESA_GULLIES = {k: e["gully"] for k, e in enumerate(_mesas) if e.get("gully") is not None}
# The big crater's breaches: (direction from its centre, angular width, how much of the rim is gone).
CRATER_BREACHES = [(b["angle"], b["width"], b["drop"]) for b in _c["breaches"]]
_cy = landform("canyon")
CANYON_DEPTH = _cy["depth"]
CANYON_FAR_EDGE = _cy["far_edge"]   # the canyon's far (north) wall
# Side canyons biting back into the plateau: (x, length, half width, ramp up from the floor?).
SIDE_RAMP_LENGTH = _cy["side_ramp_length"]
# The long ramp is the rover's way; the short ones are chutes of fallen rock, ways out on foot
# (nothing traps you: every stretch of the floor is within about 600 m of one).
SIDE_CANYONS = [(s["x"], s["length"], s["half_width"], s["ramp"]) for s in _cy["side_canyons"]]
CANYON_LANDSLIDES = [(s["x"], s["run_out"], s["half_width"]) for s in _cy["landslides"]]   # x, run-out, half width
# Wrinkle ridges on the plains: control points, and where along them (0..1) the passes are.
WRINKLE_RIDGES = [([_xz(p) for p in e["points"]], e["passes"]) for e in landforms("wrinkle_ridge")]
# Boulder fields (x, z, radius), each crossed by a few clear corridors.
BOULDER_FIELDS = [(e["centre"][0], e["centre"][1], e["radius"]) for e in landforms("boulder_field")]
SHARP_BOULDERS = [k for k, e in enumerate(landforms("boulder_field")) if e.get("sharp")]   # wind-sharpened rock that wears wheels

# Home (docs/terrain-design.md, 14 Nov): you always land on the plains, within
# `radius` of this centre. The rings are distances from it, for pacing; the
# land never draws them.
HOME = {"centre": _xz(_R["home"]["centre"]), "radius": _R["home"]["radius"]}
RINGS = list(_R["rings"])

# The young lava plain in the east: it flowed in from a vent beyond the map's
# edge, flooded the low ground south and east of the crater and stopped in a
# lobate front. Its west margin is the platy belt.
LAVA_PLAIN = {k: landform("lava_plain")[k] for k in ("west", "north", "strip_west", "strip_north", "thickness")}
PLATY_BELT = {k: landform("platy_belt")[k] for k in ("width", "east", "plate", "lanes")}
# Fissures (Cerberus Fossae, scaled down): from the narrow end to the wide end,
# widest half-width (m), deepest (m). They lead towards the heart.
FISSURES = [{"id": e["id"], "from": _xz(e["points"][0]), "to": _xz(e["points"][-1]), "half_width": e["half_width"], "depth": e["depth"], "bridge": e["bridge"]}
            for e in landforms("fissure")]
# The yardang maze between home and the crater: its long axis lies along the wind.
_y = landform("yardangs")
YARDANGS = {"centre": _xz(_y["centre"]), "length": _y["length"], "width": _y["width"]}
DRONE_WRECK = _xz(landform("drone_wreck")["centre"])
# Ripple belts beside the one round the dune sea: centre, length across the wind, width along it.
RIPPLE_BELTS = [(e["centre"][0], e["centre"][1], e["length"], e["width"]) for e in landforms("ripple_belt")]
# The raised riverbeds, and the sand that has gathered on the plain beside them.
_iv = landform("raised_riverbeds")
INVERTED_CHANNELS = {"points": [_xz(p) for p in _iv["points"]], "tributaries": [(t["at"], t["turn"]) for t in _iv["tributaries"]],
                     "sand_centre": _xz(_iv["sand_centre"]), "sand_radius": _iv["sand_radius"]}
# The buried glacier: a lobe of rubble-covered ice from the foot of the last mesa.
_g = landform("glacier")
GLACIER = {"from": _xz(_g["from"]), "flow": _xz(_g["flow"]), "length": _g["length"], "width": _g["width"], "thickness": _g["thickness"], "pits": _g["pits"]}
_cb = landform("chaos_blocks")
CHAOS_BLOCKS = (_cb["centre"][0], _cb["centre"][1], _cb["radius"], _cb["block"])   # centre, radius, block size
_fc = landform("fresh_crater")
FRESH_CRATER = (_fc["centre"][0], _fc["centre"][1], _fc["radius"])
# Ring 1 (docs/terrain-design.md).
_ch = landform("channel"); _sl = landform("sliver")
HOME_GROUND = {
    "frost_hollow": tuple(landform("frost_hollow")["centre"]) + (landform("frost_hollow")["radius"], landform("frost_hollow")["depth"]),   # x, z, radius, depth
    "channel": {"points": [_xz(p) for p in _ch["points"]], "depth": _ch["depth"], "crossings": _ch["crossings"]},
    "sand_sheet": tuple(landform("sand_sheet")["centre"]) + (landform("sand_sheet")["radius"],),
    "outcrop": tuple(landform("outcrop")["centre"]) + (landform("outcrop")["radius"], landform("outcrop")["height"]),          # the ladder's place: x, z, radius, height
    "pit": tuple(landform("collapse_pit")["centre"]) + (landform("collapse_pit")["radius"], landform("collapse_pit")["depth"]),  # the rope's place: x, z, radius, depth
    "sliver": {"from": _xz(_sl["points"][0]), "to": _xz(_sl["points"][-1]), "split": tuple(_sl["split"]), "bulge": _sl["bulge"], "half_width": _sl["half_width"], "depth": _sl["depth"]},   # the bridge's
}
# Step lines: where the land steps up from the home plain to the Reach. Each follows the geology and
# fades at its ends; `up` says which side of the line (as drawn) is high (+1 left of travel on the map,
# which is south for a line drawn eastward); `passes` are where a rover can climb.
STEP_LINES = [{"id": e["id"], "kind": e["style"], "points": [_xz(p) for p in e["points"]], "up": e["up"], "height": e["height"], "passes": e["passes"],
               "sheer": e.get("sheer", 6.0), "pass_run": e.get("pass_run", 95.0)} for e in landforms("step_line")]
MINOR_CRACKS = int(_R["minor_cracks"])
HEART = _xz(landform("heart")["centre"])   # where the tube's lower level meets the old magnetised body, about 150 m down (the last point of DEEP's course)
ICE_SCARPS = [(_xz(e["points"][0]), _xz(e["points"][-1]), e["drop"]) for e in landforms("ice_scarp")]


def write_file(path, writer):
    """Write a file, retrying for a few seconds: on Windows the Godot editor
    can hold a file briefly while it re-imports the folder."""
    for attempt in range(20):
        try:
            writer(path)
            return
        except OSError:
            if attempt == 19:
                raise
            time.sleep(0.5)


def grid():
    coords = (np.arange(N) * SPACING) - HALF   # point i sits at -HALF + i * SPACING (on Terrain3D's vertex grid)
    x, z = np.meshgrid(coords, coords)   # x along columns, z along rows
    return x, z


def spectral_noise(beta, seed, k_low=0.0, k_high=None):
    """Seamless fractal noise by spectral synthesis, normalised to std 1."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((N, N))
    f = np.fft.fftfreq(N)
    kx, kz = np.meshgrid(f, f)
    k = np.sqrt(kx * kx + kz * kz)
    k[0, 0] = 1.0
    amp = 1.0 / np.power(k, beta / 2.0)
    amp[0, 0] = 0.0
    if k_low > 0.0:
        amp *= 1.0 - np.exp(-(k / k_low) ** 2)
    if k_high is not None:
        amp *= np.exp(-(k / k_high) ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return out / out.std()


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def dist(x, z, centre):
    return np.sqrt((x - centre[0]) ** 2 + (z - centre[1]) ** 2)


def polyline_field(points, reach, params=None, step=2):
    """Distance (m) to a polyline, how far along it the nearest point is, and
    which side of it a point lies (+1 left of the direction of travel, -1
    right), within `reach` of it; inf, 0 and 0 further away. Worked out in a
    window round each segment on a grid `step` times coarser than the region's,
    then scaled up."""
    n = N // step
    coords = (np.arange(n) * SPACING * step - HALF).astype(np.float32)
    if params is None:
        params = np.linspace(0.0, 1.0, len(points))
    best = np.full((n, n), np.inf, dtype=np.float32)
    best_t = np.zeros((n, n), dtype=np.float32)
    side = np.zeros((n, n), dtype=np.float32)
    cell = SPACING * step
    for k in range(len(points) - 1):
        a = points[k]; b = points[k + 1]
        i0 = max(0, int((min(a[0], b[0]) - reach + HALF) / cell)); i1 = min(n, int((max(a[0], b[0]) + reach + HALF) / cell) + 2)
        j0 = max(0, int((min(a[1], b[1]) - reach + HALF) / cell)); j1 = min(n, int((max(a[1], b[1]) + reach + HALF) / cell) + 2)
        if i1 <= i0 or j1 <= j0:
            continue
        px = coords[None, i0:i1]; pz = coords[j0:j1, None]
        sx = b[0] - a[0]; sz = b[1] - a[1]
        length2 = max(sx * sx + sz * sz, 1e-6)
        u = np.clip(((px - a[0]) * sx + (pz - a[1]) * sz) / length2, 0.0, 1.0)
        dx = px - (a[0] + u * sx); dz = pz - (a[1] + u * sz)
        d = np.sqrt(dx * dx + dz * dz)
        window = best[j0:j1, i0:i1]
        closer = d < window
        window[closer] = d[closer]
        best_t[j0:j1, i0:i1][closer] = (params[k] + u * (params[k + 1] - params[k]))[closer]
        cross = sx * (pz - a[1]) - sz * (px - a[0])
        side[j0:j1, i0:i1][closer] = np.sign(cross)[closer]
    best[np.isinf(best)] = reach * 4.0
    if step == 1:
        return best, best_t, side

    def grow(field):
        return np.asarray(Image.fromarray(field.astype(np.float32), "F").resize((N, N), Image.BILINEAR))
    return grow(best), grow(best_t), grow(side)


def wander(start, heading, length, rng, step=20.0, turn=0.18, pull=None):
    """A meandering line: from `start`, roughly along `heading` (radians),
    turning a little each step; `pull(point, heading)` may bend it."""
    points = [np.array(start, dtype=float)]
    swing = 0.0
    for _ in range(int(length / step)):
        swing = 0.7 * swing + rng.normal(0.0, turn)
        heading += swing * 0.5
        if pull is not None:
            heading = pull(points[-1], heading)
        points.append(points[-1] + step * np.array([math.cos(heading), math.sin(heading)]))
    return np.array(points)


def sample(h, px, pz):
    j = int(np.clip((pz + HALF) / SPACING, 0, N - 1)); i = int(np.clip((px + HALF) / SPACING, 0, N - 1))
    return float(h[j, i])


# ---------- craters ----------

def add_small_craters(h, x, z, rng, count, keep_out, masks):
    """Bowl craters with raised rims, sizes on a power law, and of every age:
    fresh ones are deep and sharp with a rocky blanket, old ones shallow and
    filled with dust, the oldest only a ghost of a rim. Each is recorded in
    masks["craters"] as (x, z, radius, age) for the rocks and textures."""
    placed = []
    for _ in range(count):
        r = min(70.0, 4.0 * rng.random() ** -0.6)
        cx = rng.uniform(-HALF + 300, HALF - 300)
        cz = rng.uniform(-HALF + 300, HALF - 300)
        age = rng.random()
        if any(math.hypot(cx - kx, cz - kz) < kr + r * 2.5 for kx, kz, kr in keep_out):
            continue
        if "lava" in masks and masks["lava"][int((cz + HALF) / SPACING), int((cx + HALF) / SPACING)] > 0.5:
            if rng.random() < 0.85:   # young lava: few craters yet, and those fresh
                continue
            age *= 0.4
        add_crater(h, x, z, cx, cz, r, age, rng)
        placed.append((cx, cz, r, age))
    masks["craters"] = placed


def add_crater(h, x, z, cx, cz, r, age, rng, stretch=(1.0, 0.0)):
    """One simple crater (age 0 fresh .. 1 a ghost). `stretch` (factor, angle)
    elongates it, as for secondaries thrown in at a low angle."""
    reach = r * 2.6 * stretch[0]
    i0 = max(0, int((cx - reach + HALF) / SPACING)); i1 = min(N, int((cx + reach + HALF) / SPACING) + 1)
    j0 = max(0, int((cz - reach + HALF) / SPACING)); j1 = min(N, int((cz + reach + HALF) / SPACING) + 1)
    if i1 <= i0 or j1 <= j0:
        return
    dx = x[j0:j1, i0:i1] - cx; dz = z[j0:j1, i0:i1] - cz
    if stretch[0] != 1.0:
        c, s = math.cos(stretch[1]), math.sin(stretch[1])
        along = (dx * c + dz * s) / stretch[0]; across = -dx * s + dz * c
        dx, dz = along, across
    ang = np.arctan2(dz, dx)
    wobble = 1.0 + 0.06 * np.sin(ang * 3.0 + rng.uniform(0, 6.3)) + 0.04 * np.sin(ang * 5.0 + rng.uniform(0, 6.3))
    d = np.sqrt(dx * dx + dz * dz) / (r * wobble)
    fresh = 1.0 - age
    depth = 0.2 * r * (0.25 + 0.75 * fresh)
    fill = 0.55 * age   # dust and sand in the floor of older craters
    bowl = np.where(d < 1.0, -depth * np.minimum(1.0 - d * d, 1.0 - fill) / (1.0 - fill), 0.0)
    rim = 0.055 * r * fresh ** 1.5 * np.exp(-((d - 1.0) / (0.22 + 0.25 * age)) ** 2)
    ejecta = np.where(d > 1.0, 0.035 * r * fresh ** 2 * np.power(np.maximum(d, 1.0), -3.0), 0.0)
    if age > 0.88:   # a ghost: only a low ring of rubble left
        bowl *= 0.15; rim = 0.012 * r * np.exp(-((d - 1.0) / 0.12) ** 2); ejecta *= 0.0
    h[j0:j1, i0:i1] += bowl + rim + ejecta


def add_big_crater(h, x, z, masks, medium, lobes_field, ragged_field):
    """The big crater as a complex crater: a slightly polygonal rim (it follows
    the bedrock's joints), slump terraces down the inner wall, a slump lobe
    spilled on to the floor, gullies on the pole-facing wall, and a hummocky
    ejecta blanket thinning outward (thickness falls as the cube of distance)
    and ending in lobes with a low rampart. Three breaches let a rover in."""
    cx, cz = CRATER["centre"]
    angle = np.arctan2(z - cz, x - cx)
    radius = CRATER["radius"] * (1.0 + 0.022 * np.cos(6.0 * (angle + 0.4)) + 0.02 * np.sin(angle * 5.0 + 1.3) + 0.012 * np.sin(angle * 11.0) + 0.025 * lobes_field)
    d = dist(x, z, (cx, cz)) / radius
    depth = CRATER["depth"]; rim = CRATER["rim"]
    # Terraces: blocks that slid down the wall in arcs; their edges wander.
    tw = 0.02 * np.sin(angle * 3.0 + 0.5) + 0.012 * np.sin(angle * 7.0 + 1.0) + 0.008 * ragged_field
    # Each terrace comes and goes round the crater: where one fades, the
    # wall between its neighbours is a single steeper slope.
    share = [np.clip(1.0 + 0.7 * np.sin(angle * (2 + k) + k * 1.7) + 0.4 * np.sin(angle * (5 + k) + k), 0.15, 2.0) for k in range(4)]
    total = share[0] + share[1] + share[2] + share[3]
    wall = (share[0] * smoothstep(0.58, 0.66, d) + share[1] * smoothstep(0.7 + tw, 0.76 + tw, d)
            + share[2] * smoothstep(0.8 + tw, 0.86 + tw, d) + share[3] * smoothstep(0.9 + tw * 0.5, 0.99, d)) / total
    wall += 0.012 * medium * smoothstep(0.6, 0.7, d) * (1.0 - smoothstep(0.95, 1.0, d))   # broken benches
    # Gullies down the pole-facing (southern) inner wall, each with a small fan.
    pole = smoothstep(0.1, 0.7, np.sin(angle))
    groove = 1.0 - smoothstep(0.0, 0.2, np.abs(np.sin(angle * 46.0 + 0.3 * medium)))
    some = smoothstep(0.55, 0.8, 0.5 + 0.5 * np.sin(angle * 13.0 + 2.0) + 0.25 * ragged_field)   # only some of them
    wall -= pole * some * groove * 0.045 * smoothstep(0.8, 0.86, d) * (1.0 - smoothstep(0.95, 0.99, d))
    inside = -depth + (depth + rim) * wall
    # Ejecta: thick at the rim, thinning as the cube of distance, ending in
    # lobes with a low rampart; hummocky.
    end = 2.05 + 0.35 * lobes_field + 0.12 * np.sin(angle * 7.0 + 0.4)
    blanket = rim * np.power(np.maximum(d, 1.0), -3.0) * (1.0 - smoothstep(end - 0.4, end, d))
    blanket += 1.5 * np.exp(-((d - end + 0.12) / 0.06) ** 2) * (d > 1.0)
    blanket *= 1.0 + 0.18 * medium
    crater = np.where(d < 1.0, inside, blanket)
    # Breaches: a slump scar, an eastern notch, and the old river's gap.
    for b_angle, b_width, drop in CRATER_BREACHES:
        wb = (1.0 - smoothstep(b_width * 0.25, b_width, np.abs(np.angle(np.exp(1j * (angle - b_angle)))))) * (1.0 - smoothstep(1.35, 1.7, d))
        top = rim * (1.0 - drop)
        ramp = -depth + (depth + top) * smoothstep(0.0, 1.0, np.clip((d - 0.42) / 0.83, 0.0, 1.0)) ** 0.9
        notch = np.where(d < 1.25, ramp, np.minimum(blanket, top))
        crater = crater * (1.0 - wb) + np.minimum(crater, notch) * wb
    # The slump lobe: wall rock spilled on to the floor below the scar.
    s_angle = CRATER_BREACHES[0][0]
    ws = np.exp(-(np.angle(np.exp(1j * (angle - s_angle))) / 0.22) ** 2)
    lobe = landform("big_crater").get("slump_lobe", 16.0) * ws * np.clip(1.0 - np.abs(d - 0.56) / 0.12, 0.0, 1.0) ** 0.7 * (1.0 + 0.25 * medium)
    calm = 1.0 - 0.75 * (1.0 - smoothstep(0.6, 0.85, d))           # quieter floor
    h *= calm
    h += crater + lobe
    masks["crater_d"] = d
    masks["crater_angle"] = angle
    masks["ejecta"] = ((d > 1.0) & (d < end)).astype(np.float32) * np.clip(np.power(np.maximum(d, 1.0), -2.0), 0, 1)
    # Secondary craters: chains of small elongated pits thrown out by the impact.
    rng = np.random.default_rng(kind_seed("crater", SEED + 40))
    for _ in range(int(landform("big_crater").get("secondaries", 9))):
        a = rng.uniform(-math.pi, math.pi)
        start = rng.uniform(2.0, 2.4)
        for k in range(rng.integers(5, 11)):
            rr = CRATER["radius"] * (start + k * rng.uniform(0.04, 0.07))
            px = cx + math.cos(a) * rr + rng.normal(0, 15); pz = cz + math.sin(a) * rr + rng.normal(0, 15)
            if abs(px) > HALF - 500 or abs(pz) > HALF - 500 or near_zone(px, pz, 60.0):
                continue
            add_crater(h, x, z, px, pz, rng.uniform(6.0, 15.0), rng.uniform(0.0, 0.4), rng, (1.6, a))


def near_zone(px, pz, extra):
    return any(math.hypot(px - zone["centre"][0], pz - zone["centre"][1]) < zone["flat_radius"] * zone.get("blend", 3.2) + extra for zone in ZONES.values())


# ---------- canyon ----------

def distance_field(mask, step=2):
    """Distance (m) from each point to the nearest point where `mask` is
    true, by a chamfer sweep on a grid `step` times coarser (about 8 %
    out at worst), scaled back up. Sweeps run a whole row or column at once."""
    m = mask[::step, ::step]
    big = 1e9
    d = np.where(m, 0.0, big).astype(np.float64)
    n = d.shape[0]
    diag = math.sqrt(2.0)
    for _ in range(2):
        for j in range(1, n):   # down
            prev = d[j - 1]
            cand = np.minimum(prev + 1.0, np.minimum(np.concatenate(([big], prev[:-1])), np.concatenate((prev[1:], [big]))) + diag)
            d[j] = np.minimum(d[j], cand)
        for j in range(n - 2, -1, -1):   # up
            prev = d[j + 1]
            cand = np.minimum(prev + 1.0, np.minimum(np.concatenate(([big], prev[:-1])), np.concatenate((prev[1:], [big]))) + diag)
            d[j] = np.minimum(d[j], cand)
        for i in range(1, n):   # right
            prev = d[:, i - 1]
            cand = np.minimum(prev + 1.0, np.minimum(np.concatenate(([big], prev[:-1])), np.concatenate((prev[1:], [big]))) + diag)
            d[:, i] = np.minimum(d[:, i], cand)
        for i in range(n - 2, -1, -1):   # left
            prev = d[:, i + 1]
            cand = np.minimum(prev + 1.0, np.minimum(np.concatenate(([big], prev[:-1])), np.concatenate((prev[1:], [big]))) + diag)
            d[:, i] = np.minimum(d[:, i], cand)
    d = np.minimum(d, 4096.0) * SPACING * step
    return np.asarray(Image.fromarray(d.astype(np.float32), "F").resize((N, N), Image.BILINEAR))


def box_blur(a, radius, passes=2):
    """Blur by `passes` box filters `radius` points each side (two make a
    tent, three nearly a Gaussian); edges clamp."""
    out = a.astype(np.float64)
    for _ in range(passes):
        for axis in (0, 1):
            pad = [(0, 0), (0, 0)]; pad[axis] = (radius + 1, radius)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            hi = [slice(None), slice(None)]; lo = [slice(None), slice(None)]
            hi[axis] = slice(2 * radius + 1, None); lo[axis] = slice(0, -2 * radius - 1)
            out = (c[tuple(hi)] - c[tuple(lo)]) / (2 * radius + 1)
    return out.astype(np.float32)


def signed_distance(inside, step=2):
    """Metres to the edge of a region: positive inside it, negative outside."""
    return distance_field(~inside, step) - distance_field(inside, step)


def add_canyon(h, x, z, masks, medium):
    """The canyon along the north edge: a layered cliff on top, a talus slope
    below it, spurs and alcoves along the rim, side canyons biting back into
    the plateau (one with a ramp up from the floor, the rover's way), and
    landslide tongues on the floor."""
    row = x[0]
    base_edge = -2030.0 + 60.0 * spectral_noise(3.4, kind_seed("canyon", SEED + 3), k_high=0.01)[0]
    spurs = spectral_noise(3.0, kind_seed("canyon", SEED + 3) + 1, k_low=0.008, k_high=0.03)
    edge = base_edge[None, :] + 45.0 * spurs   # spurs and alcoves
    plateau = z > edge
    bay_wobble = 22.0 * spectral_noise(3.0, kind_seed("canyon", SEED + 3) + 2, k_low=0.004, k_high=0.03)
    ramp_bay = np.zeros(h.shape, dtype=bool)
    ramp_len = np.full(h.shape, SIDE_RAMP_LENGTH, dtype=np.float32); ramp_off = np.full(h.shape, 240.0, dtype=np.float32)
    for sx, length, width, is_ramp in SIDE_CANYONS:
        q = np.clip((z - base_edge[None, :]) / length, 0.0, 1.0)
        bay = (np.abs(x - sx + bay_wobble) < width * (1.0 - (0.15 if is_ramp else 0.45) * q)) & (z < base_edge[None, :] + length + 30.0 * spurs)
        plateau &= ~bay
        if is_ramp:
            ramp_bay |= bay
            if length < SIDE_RAMP_LENGTH:   # a chute: short and steep, on foot
                band = np.abs(x - sx) < width * 2.5 + 60.0
                ramp_len[band] = length; ramp_off[band] = 110.0
    u = box_blur(signed_distance(plateau), 8)   # > 0 on the plateau (smoothed: the chamfer distance is a little angular)
    # The cliff in three layers (hard caps over softer beds), talus below.
    v = np.clip((u + 90.0) / 90.0, 0.0, 1.0) * 3.0 + 0.15 * medium
    stair = (np.floor(v) + smoothstep(0.55, 1.0, v - np.floor(v))) / 3.0
    profile = np.where(u > -90.0, 0.45 + 0.55 * np.clip(stair, 0.0, 1.0),
                       0.45 * np.clip((u + 240.0) / 150.0, 0.0, 1.0) ** 1.6)
    profile = np.where(u >= 0.0, 1.0, profile)
    # The ramp canyon: its floor climbs steadily from the canyon floor to the plateau.
    into = np.clip((z - base_edge[None, :] + ramp_off) / (ramp_len + ramp_off * 0.5), 0.0, 1.0)   # level with the plateau 120 m before the head
    bay_depth = box_blur(signed_distance(ramp_bay), 6)   # metres into the bay (negative outside)
    in_bay = smoothstep(4.0, 30.0, bay_depth)
    profile = profile * (1.0 - in_bay) + into * in_bay   # the bay's floor is the ramp
    profile = np.maximum(profile, into * smoothstep(-70.0, 0.0, bay_depth))   # and no step where it meets the plateau
    # The far wall: the same layers, rising north to the region's edge.
    far = (CANYON_FAR_EDGE + 40.0 * spectral_noise(3.4, kind_seed("canyon", SEED + 3) + 3, k_high=0.01)[0][None, :] + 30.0 * spurs) - z
    v2 = np.clip((far + 90.0) / 90.0, 0.0, 1.0) * 3.0 + 0.15 * medium
    stair2 = (np.floor(v2) + smoothstep(0.55, 1.0, v2 - np.floor(v2))) / 3.0
    far_profile = np.where(far >= 0.0, 1.0, np.where(far > -90.0, 0.45 + 0.55 * np.clip(stair2, 0.0, 1.0), 0.45 * np.clip((far + 200.0) / 110.0, 0.0, 1.0) ** 1.6))
    profile = np.maximum(profile, far_profile * (z < base_edge[None, :] - 150.0))
    h += -CANYON_DEPTH * (1.0 - profile)
    floor = (1.0 - smoothstep(-260.0, -200.0, u)) * (1.0 - smoothstep(-200.0, -150.0, far))
    h += 1.8 * medium * floor   # a rough floor, but drivable
    # Landslide tongues: lobes of debris run out across the floor.
    landslide = np.zeros(h.shape, dtype=np.float32)
    for lx, length, width in CANYON_LANDSLIDES:
        foot = float(np.interp(lx, row, base_edge)) - 200.0
        along = (foot - z) / length   # northward from the talus foot
        across = (x - lx) / width
        tongue = np.clip(1.0 - along, 0.0, 1.0) ** 0.6 * np.exp(-across * across * (1.0 + np.clip(along, -0.3, 1.0))) * (along > -0.3)
        h += landform("canyon").get("landslide_height", 13.0) * tongue * (1.0 + 0.3 * medium) * smoothstep(-0.3, 0.0, along)
        landslide = np.maximum(landslide, tongue * smoothstep(-0.3, 0.0, along))
    masks["canyon_u"] = u
    masks["canyon_floor"] = floor
    masks["landslide"] = landslide
    masks["ramp_canyon"] = in_bay * (u < 0.0)


# ---------- mesas and buttes ----------

def mesa_profile(md, mh, medium):
    """A layered mesa: flat cap rock, a stepped cliff, a concave talus apron."""
    v = np.clip((0.92 - md) / 0.1, 0.0, 1.0) * 3.0 + 0.2 * medium
    stair = np.clip((np.floor(v) + smoothstep(0.5, 1.0, v - np.floor(v))) / 3.0, 0.0, 1.0)
    cliff = 0.38 + 0.62 * stair
    talus = 0.38 * np.clip((1.65 - md) / 0.73, 0.0, 1.0) ** 1.9
    return mh * np.where(md < 0.82, 1.0, np.where(md < 0.92, cliff, talus))


def add_mesas(h, x, z, masks, medium, edge_warp):
    """Flat-topped mesas of horizontal layers with talus aprons, small buttes
    broken off beside them, and on two of them a ramp of fallen wall."""
    rng = np.random.default_rng(kind_seed("mesa", SEED + 50))
    masks["mesa_body"] = np.zeros_like(h)
    masks["talus"] = np.zeros_like(h)
    bodies = []
    gullies = {}
    masks["scree"] = np.zeros_like(h)
    for index, (mx, mz, mr, mh) in enumerate(MESAS):
        bodies.append((mx, mz, mr, mh, MESA_RAMPS.get(index)))
        if index in MESA_GULLIES:
            gullies[(mx, mz)] = MESA_GULLIES[index]
        for _ in range(int(_mesas[index].get("buttes", 2))):
            a = rng.uniform(-math.pi, math.pi)
            br = mr * rng.uniform(0.2, 0.3)
            bx = mx + math.cos(a) * mr * rng.uniform(1.7, 2.1); bz = mz + math.sin(a) * mr * rng.uniform(1.7, 2.1)
            if near_zone(bx, bz, br * 2.0):
                continue
            bodies.append((bx, bz, br, mh * rng.uniform(0.65, 0.9), None))
    for mx, mz, mr, mh, r_angle in bodies:
        reach = mr * (2.4 if r_angle is None else max(2.4, 0.9 + mh / (0.15 * mr)))   # a ramp runs out past the talus
        i0 = max(0, int((mx - reach + HALF) / SPACING)); i1 = min(N, int((mx + reach + HALF) / SPACING) + 1)
        j0 = max(0, int((mz - reach + HALF) / SPACING)); j1 = min(N, int((mz + reach + HALF) / SPACING) + 1)
        win = (slice(j0, j1), slice(i0, i1))
        dx = x[win] - mx; dz = z[win] - mz
        ang = np.arctan2(dz, dx)
        seed = int(abs(mx)) % 997
        shape = 1.0 + 0.1 * medium[win] + 0.08 * np.sin(ang * 3.0 + seed) + 0.05 * np.sin(ang * 7.0 + seed * 0.3)
        md = np.sqrt(dx * dx + dz * dz) / (mr * shape) + edge_warp(seed, 0.12, 0.05)[win]
        lift = mesa_profile(md, mh, medium[win])
        if r_angle is not None:
            wb = 1.0 - smoothstep(0.16, 0.3, np.abs(np.angle(np.exp(1j * (ang - r_angle)))))
            run = mh / (0.15 * mr)   # about 9 degrees, in mesa radii
            plain = np.sqrt(dx * dx + dz * dz) / mr   # the ramp ignores the outline's wobble
            ramp = mh * np.clip(1.0 - (plain - 0.78) / run, 0.0, 1.0)
            # The fallen wall replaces the cliff there: flat top, then the ramp down.
            lift = lift * (1.0 - wb) + np.maximum(ramp, np.where(plain < 0.78, mh, 0.0)) * wb
        if (mx, mz) in gullies:
            # A gully of loose scree cut back into the cliff: steep, but a way up.
            wg = 1.0 - smoothstep(0.05, 0.11, np.abs(np.angle(np.exp(1j * (ang - gullies[(mx, mz)])))))
            plain = np.sqrt(dx * dx + dz * dz) / mr
            run = mh / (0.68 * mr)
            chute = mh * np.clip(1.0 - (plain - 0.55) / run, 0.0, 1.0)
            lift = lift * (1.0 - wg) + np.minimum(lift, chute) * wg
            masks["scree"][win] = np.maximum(masks["scree"][win], wg * (plain > 0.5) * (plain < 0.6 + run))
        h[win] += lift
        masks["mesa_body"][win] = np.maximum(masks["mesa_body"][win], 1.0 - smoothstep(0.88, 0.96, md))
        masks["talus"][win] = np.maximum(masks["talus"][win], smoothstep(0.9, 0.96, md) * (1.0 - smoothstep(1.2, 1.65, md)))
    masks["skirts"] = masks["talus"]
    masks["mesa_list"] = bodies


# ---------- wrinkle ridges ----------

def add_wrinkle_ridges(h, x, z, masks, medium):
    """Wrinkle ridges on the lava plains (T3, docs/terrain-design.md §13): a broad arch with a tall,
    lumpy crest on top, one side steep and broken into ledges and gullies (too steep for a rover; the
    gullies are scrambles on foot), the other gentler but still too steep to drive, and a few low
    saddles (passes): the only places a rover gets over."""
    masks["ridges"] = np.zeros_like(h)
    masks.setdefault("no_grade", np.zeros_like(h))
    masks.setdefault("obstacle_lines", [])
    lumps = np.roll(masks["noise"], (300, 700), (0, 1))
    for r in landforms("wrinkle_ridge"):
        rng = np.random.default_rng(seed_of(r))
        control = np.array(r["points"], dtype=float)
        # A smooth, sinuous line through the control points.
        fine = []
        for k in range(len(control) - 1):
            for s in np.linspace(0.0, 1.0, 12, endpoint=False):
                fine.append(control[k] + (control[k + 1] - control[k]) * s)
        fine.append(control[-1])
        fine = np.array(fine)
        normal = np.gradient(fine, axis=0)[:, ::-1] * np.array([1.0, -1.0])
        normal /= np.linalg.norm(normal, axis=1, keepdims=True)
        fine += normal * (r["wiggle"] * np.sin(np.linspace(0, 9.0, len(fine)) + rng.uniform(0, 6))[:, None])
        reach = max(420.0, r["arch_width"] * 2.6)
        d, t, side = polyline_field(fine, reach, step=2)
        s = d * side   # signed: > 0 on the steep side
        length = float(np.sum(np.hypot(*np.diff(fine, axis=0).T)))
        taper = np.clip(np.sin(np.pi * np.clip(t, 0.0, 1.0)), 0.0, 1.0) ** 0.4
        pass_w = np.zeros_like(t)
        width_t = r.get("pass_width", 70.0) / length   # a pass's half width, as a share of the length
        for p in r["passes"]:
            pass_w = np.maximum(pass_w, np.exp(-((t - p) / width_t) ** 2))
        low = 1.0 - r.get("pass_depth", 0.9) * pass_w
        crest_at = r["crest_at"]
        u = (s - crest_at) / r["steep_side"]
        # The steep side: a face broken into ledges, with gullies cut into it every so often (eased: scrambles).
        gully = 1.0 - smoothstep(0.0, 0.25, np.abs(np.sin(t * length / r.get("gully_spacing", 160.0) * math.pi + 1.3)))
        u = u / (1.0 + 1.3 * gully)
        face = np.exp(-np.maximum(u, 0.0) ** 2)
        ledges = (np.floor(face * 3.0) + smoothstep(0.55, 1.0, face * 3.0 - np.floor(face * 3.0))) / 3.0
        steep = 0.45 * face + 0.55 * ledges
        gentle = np.exp(-((s - crest_at) / r["gentle_side"]) ** 2)
        crest = np.where(s - crest_at > 0.0, steep, gentle)
        # A lumpy, crenulated crest.
        crest *= 0.74 + 0.18 * np.sin(t * length / 55.0 + 2.0 * medium) + 0.14 * np.clip(lumps, -1.5, 1.5)
        arch = np.exp(-(s / r["arch_width"]) ** 2)
        lift = (r["arch"] * arch + r["crest"] * crest) * taper * np.clip(low, 0.05, 1.0)
        # Fallen rubble at the foot of the steep side.
        foot = np.clip(1.0 - np.abs(s - crest_at - r["steep_side"] * 1.6) / 22.0, 0.0, 1.0) * taper * (1.0 - pass_w)
        lift += 1.6 * foot * (0.6 + 0.4 * np.abs(lumps))
        h += lift
        top = r["arch"] + r["crest"]
        masks["ridges"] = np.maximum(masks["ridges"], lift / top)
        masks["no_grade"] = np.maximum(masks["no_grade"], ((lift > 0.25 * top) & (pass_w < 0.3)).astype(np.float32))
        passes = [[round(float(q[0]), 1), round(float(q[1]), 1)] for q in (fine[int(p * (len(fine) - 1))] for p in r["passes"])]
        masks.setdefault("ridge_passes", {})[r["id"]] = passes
        masks["obstacle_lines"].append({"id": r["id"], "label": r.get("label", r["id"]), "line": fine, "passes": passes, "reach": 350.0,
                                        "s": s[::5, ::5], "t": t[::5, ::5], "low": -(r["gentle_side"] * 2.2 + 20.0), "high": crest_at + r["steep_side"] * 2.6 + 20.0,
                                        "pass_radius": r.get("pass_width", 70.0) * 1.6 + 40.0})


# ---------- valleys ----------

def carve_channel(h, points, floor, half_width, depth, wall_run, reach_extra=40.0, step=1, params=None):
    """Cut a valley along `points` whose floor heights are `floor` (per point):
    a flat floor `half_width` wide, walls rising `depth` over `wall_run`,
    then on up steeply wherever the cut runs deeper. Returns the floor mask."""
    reach = float(np.max(half_width)) + float(np.max(wall_run)) + reach_extra
    if params is None:
        params = np.arange(len(points), dtype=float)
    d, t, _ = polyline_field(points, reach, params, step=step)
    near = d < reach
    idx = params
    floor_at = np.interp(t[near], idx, floor)
    width_at = np.interp(t[near], idx, half_width)
    depth_at = np.interp(t[near], idx, depth)
    run_at = np.interp(t[near], idx, wall_run)
    s = np.maximum(0.0, d[near] - width_at)
    rise = np.where(s < run_at, depth_at * smoothstep(0.0, 1.0, s / run_at) ** 0.85, depth_at + (s - run_at) * 1.4)
    target = floor_at + rise
    cut = h[near]
    h[near] = np.minimum(cut, target)
    mask = np.zeros(h.shape, dtype=np.float32)
    mask[near] = (d[near] < width_at + 1.5)
    return mask


def add_valley_network(h, x, z, masks, trunk_floor):
    """Tributaries feeding the old river: first-order branches off the trunk
    heading back upslope, second-order ones off those, each floor running
    downhill to its junction. Together a dendritic network like Warrego
    Valles's, with the trunk (and the riverbed landing zone) its main stem."""
    rng = np.random.default_rng(SEED + 70)
    coarse = h[::8, ::8]
    gz, gx = np.gradient(coarse, SPACING * 8)

    def uphill(point, heading):
        j = int(np.clip((point[1] + HALF) / (SPACING * 8), 0, coarse.shape[0] - 1)); i = int(np.clip((point[0] + HALF) / (SPACING * 8), 0, coarse.shape[1] - 1))
        g = np.array([gx[j, i], gz[j, i]])
        if np.linalg.norm(g) < 1e-4:
            return heading
        want = math.atan2(g[1], g[0])
        return heading + 0.12 * math.sin(want - heading)

    def blocked(p):
        if abs(p[0]) > HALF - 720 or abs(p[1]) > HALF - 720:
            return True
        if near_zone(p[0], p[1], 40.0) and math.hypot(p[0] - ZONES["riverbed"]["centre"][0], p[1] - ZONES["riverbed"]["centre"][1]) > 30.0:
            return True
        if math.hypot(p[0] - CRATER["centre"][0], p[1] - CRATER["centre"][1]) < CRATER["radius"] * 1.12:
            return True
        if p[1] < -1850.0:
            return True
        pj = int(np.clip((p[1] + HALF) / SPACING, 0, N - 1)); pi = int(np.clip((p[0] + HALF) / SPACING, 0, N - 1))
        if masks["lava_sd"][pj, pi] > -30.0 or masks["sand_sheet"][pj, pi] > 0.2 or masks["yardang_field"][pj, pi] > 0.1:
            return True
        for mx, mz, mr, mh, _ in masks["mesa_list"]:
            if math.hypot(p[0] - mx, p[1] - mz) < mr * 1.25:
                return True
        for bx, bz, br in ICE_PATCHES:
            if math.hypot(p[0] - bx, p[1] - bz) < br:
                return True
        return False

    def grow(start, heading, length, order):
        line = wander(start, heading, length, rng, step=16.0, turn=0.16, pull=uphill)
        keep = 1
        while keep < len(line) and not blocked(line[keep]):
            keep += 1
        return line[:keep]

    branches = []
    trunk_dir = np.gradient(RIVER_POINTS, axis=0)
    zone_index = int(round(RIVER_WIDE_AT * 360))
    candidates = [i for i in range(25, 345, 22) if abs(i - zone_index) > 22]
    for n, i in enumerate(candidates):
        up = -trunk_dir[i] / np.linalg.norm(trunk_dir[i])
        side = 1.0 if n % 2 == 0 else -1.0
        heading = math.atan2(up[1], up[0]) + side * rng.uniform(0.6, 1.1)
        line = grow(RIVER_POINTS[i], heading, rng.uniform(500.0, 1300.0), 1)
        if len(line) < 8:
            continue
        branches.append((line, 1, ("trunk", i)))
        parent = len(branches) - 1
        for _ in range(rng.integers(1, 4)):
            k = int(len(line) * rng.uniform(0.25, 0.7))
            if k < 3 or k >= len(line) - 3:
                continue
            fwd = line[min(k + 1, len(line) - 1)] - line[k - 1]
            h2 = math.atan2(fwd[1], fwd[0]) + rng.choice([-1.0, 1.0]) * rng.uniform(0.5, 1.0)
            sub = grow(line[k], h2, rng.uniform(220.0, 600.0), 2)
            if len(sub) >= 6:
                branches.append((sub, 2, (parent, k)))
    floors = []
    channel_mask = np.zeros(h.shape, dtype=np.float32)
    for line, order, (parent, at) in branches:
        m = len(line)
        f = np.linspace(1.0, 0.0, m)   # 1 at the junction, 0 at the head
        if order == 1:
            depth = 2.0 + 8.0 * f; half_width = 2.0 + 5.0 * f; wall_run = 7.0 + 9.0 * f
            junction_floor = trunk_floor[at]
        else:
            depth = 1.5 + 4.0 * f; half_width = 1.5 + 2.5 * f; wall_run = 5.0 + 5.0 * f
            junction_floor = floors[parent][at]
        floor = np.empty(m)
        for k in range(m - 1, -1, -1):   # from the head down to the junction
            ground = sample(h, line[k][0], line[k][1]) - depth[k]
            floor[k] = ground if k == m - 1 else min(ground, floor[k + 1] - 0.03)
        floor = np.maximum(floor, junction_floor)
        floors.append(floor)
        channel_mask = np.maximum(channel_mask, carve_channel(h, line, floor, half_width, depth, wall_run, step=1))
    masks["channels"] = channel_mask
    masks["branches"] = [b[0] for b in branches]


# ---------- dunes ----------

def add_dunes(h, x, z, masks, medium, edge_warp, lobes_field):
    """A dune field shaped by one prevailing wind: transverse ridges where the
    sand is thick (gentle windward slopes, steep slip faces, sinuous crests
    across the wind) and barchans, crescents with their horns downwind,
    where it thins out at the field's edges."""
    wind = np.array(DUNE_WIND)
    along = ((x - DUNES[0]) * wind[0] + (z - DUNES[1]) * wind[1])
    across = (-(x - DUNES[0]) * wind[1] + (z - DUNES[1]) * wind[0])
    dd = np.sqrt((along / (DUNES_RADIUS * 1.8)) ** 2 + (across / DUNES_RADIUS) ** 2) + edge_warp(410, 0.18, 0.09) + 0.08 * np.sin(across / DUNES_RADIUS * 9.0 + 3.0 * lobes_field)
    field = 1.0 - smoothstep(0.7, 1.0, dd)
    field *= 1.0 - masks["ramp_canyon"]
    masks["dune_dd"] = dd
    # Transverse ridges, about 65 m apart.
    phase = along / landforms("dune_field")[0].get("spacing", 65.0) + 0.25 * np.sin(across / 140.0 + 0.6 * medium) + 0.12 * medium
    f = phase - np.floor(phase)
    shape = np.where(f < 0.78, smoothstep(0.0, 1.0, f / 0.78), 1.0 - smoothstep(0.0, 1.0, (f - 0.78) / 0.22))
    core = smoothstep(0.35, 0.75, field)
    sand = landforms("dune_field")[0].get("ridge_height", 8.0) * core * shape ** 1.25 + 1.5 * field   # and a sand sheet under them
    # Barchans where the sand runs thin.
    rng = np.random.default_rng(kind_seed("dune_field", SEED + 80))
    barchans = np.zeros_like(h)
    masks["barchan_list"] = []
    for _ in range(4000):
        if len(masks["barchan_list"]) >= landforms("dune_field")[0].get("barchans", 70):
            break
        a0 = rng.uniform(-1.3, 1.5) * DUNES_RADIUS * 1.8
        c0 = rng.uniform(-1.25, 1.25) * DUNES_RADIUS
        px = DUNES[0] + a0 * wind[0] - c0 * wind[1]; pz = DUNES[1] + a0 * wind[1] + c0 * wind[0]
        j = int((pz + HALF) / SPACING); i = int((px + HALF) / SPACING)
        if not (0 <= i < N and 0 <= j < N):
            continue
        thickness = field[j, i]
        if not (0.03 < thickness < 0.5) or (a0 < 0 and rng.random() < 0.6):
            continue
        size = rng.uniform(22.0, 55.0)
        if any(math.hypot(px - bx, pz - bz) < (size + bs) * 1.3 for bx, bz, bs in masks["barchan_list"]):
            continue
        masks["barchan_list"].append((px, pz, size))
        reach = size * 2.6
        i0 = max(0, int((px - reach + HALF) / SPACING)); i1 = min(N, int((px + reach + HALF) / SPACING) + 1)
        j0 = max(0, int((pz - reach + HALF) / SPACING)); j1 = min(N, int((pz + reach + HALF) / SPACING) + 1)
        win = (slice(j0, j1), slice(i0, i1))
        an = (along[win] - a0) / size
        cn = (across[win] - c0) / size
        width = np.clip(1.0 - cn * cn, 0.0, 1.0)
        crest = 0.6 * cn * cn
        windward = smoothstep(-1.4 + 0.7 * cn * cn, crest, an)
        lee = 1.0 - np.clip((an - crest) / 0.3, 0.0, 1.0)
        barchans[win] = np.maximum(barchans[win], size * 0.24 * width ** 0.7 * np.where(an < crest, windward, lee))
    h += np.maximum(sand, barchans)
    masks["dunes"] = np.clip(np.maximum(field * 1.2, barchans / 2.0), 0.0, 1.0)


# ---------- ice ----------

def cell_hash(i, j, salt):
    v = np.sin(i * 127.1 + j * 311.7 + salt * 74.7) * 43758.5453
    return v - np.floor(v)


def add_ice_ground(h, x, z, masks, medium, small, edge_warp):
    """Ice-rich ground: the same height as the land round it, gently lumpy,
    cracked into polygons by thermal contraction (irregular 20-30 m cells
    with troughs), with scalloped hollows where ice has sublimated (steep
    pole-facing walls) and two scarps where clean ice shows."""
    idist = np.min(np.stack([dist(x, z, (bx, bz)) / br for bx, bz, br in ICE_PATCHES]), axis=0) + edge_warp(820, 0.3, 0.14)
    ice = 1.0 - smoothstep(0.78, 1.08, idist)
    masks["ice"] = ice
    h -= ice * (0.7 * 2.6 * medium + 0.5 * 0.22 * small)   # smoother ground
    h += ice * (-2.5 + 1.2 * spectral_noise(2.8, SEED + 90, k_low=0.02, k_high=0.08))
    # Polygons: the edges of an irregular Voronoi pattern, its points warped.
    cols = np.where(ice.max(axis=0) > 0.01)[0]; rows = np.where(ice.max(axis=1) > 0.01)[0]
    win = (slice(rows[0], rows[-1] + 1), slice(cols[0], cols[-1] + 1))
    size = 26.0
    px = (x[win] + 5.0 * medium[win]) / size; pz = (z[win] - 5.0 * medium[win]) / size
    ci = np.floor(px); cj = np.floor(pz)
    f1 = np.full(px.shape, 9.0); f2 = np.full(px.shape, 9.0)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            sx = ci + di + 0.1 + 0.8 * cell_hash(ci + di, cj + dj, 1.0)
            sz = cj + dj + 0.1 + 0.8 * cell_hash(ci + di, cj + dj, 2.0)
            dd = np.sqrt((px - sx) ** 2 + (pz - sz) ** 2)
            f2 = np.where(dd < f1, f1, np.minimum(f2, dd))
            f1 = np.minimum(f1, dd)
    edge = (f2 - f1) * size   # about twice the distance to the nearest crack, metres
    trough = 1.0 - smoothstep(0.0, 4.5, edge)
    polygons = np.zeros_like(h)
    polygons[win] = trough
    h -= 0.8 * polygons * ice
    masks["polygons"] = polygons * ice
    # Scalloped hollows: shallow, steep on their southern (pole-facing) wall.
    rng = np.random.default_rng(kind_seed("ice_field", SEED + 91))
    scallops = 0
    for _ in range(600):
        if scallops >= 45:
            break
        bx, bz, br = ICE_PATCHES[rng.integers(len(ICE_PATCHES))]
        sx = bx + rng.uniform(-1, 1) * br; sz = bz + rng.uniform(-1, 1) * br
        j = int((sz + HALF) / SPACING); i = int((sx + HALF) / SPACING)
        if ice[j, i] < 0.7:
            continue
        r = rng.uniform(20.0, 70.0); depth = rng.uniform(2.0, 5.0)
        reach = r * 1.6
        i0 = max(0, int((sx - reach + HALF) / SPACING)); i1 = min(N, int((sx + reach + HALF) / SPACING) + 1)
        j0 = max(0, int((sz - reach + HALF) / SPACING)); j1 = min(N, int((sz + reach + HALF) / SPACING) + 1)
        w = (slice(j0, j1), slice(i0, i1))
        dx = (x[w] - sx) / (r * 1.4); dz = (z[w] - sz) / np.where(z[w] > sz, r * 0.55, r)
        rr = np.sqrt(dx * dx + dz * dz)
        bowl = np.clip(1.0 - rr, 0.0, 1.0)
        h[w] -= depth * np.where(z[w] > sz, smoothstep(0.0, 0.35, bowl), smoothstep(0.0, 1.0, bowl))
        scallops += 1
    # Ice scarps: the ground drops to the north; their pole-facing faces show clean ice.
    masks["ice_scarp"] = np.zeros_like(h)
    for a, b, drop in ICE_SCARPS:
        line = np.array([a, b], dtype=float)
        d, t, side = polyline_field(line, 260.0, step=1)
        s = d * side * (1.0 if b[0] > a[0] else -1.0)   # > 0 south of the scarp
        ends = smoothstep(0.0, 0.18, t) * smoothstep(1.0, 0.82, t)
        lowered = drop * (1.0 - smoothstep(-5.0, 5.0, s)) * smoothstep(-230.0, -70.0, s) * ends
        h -= lowered
        masks["ice_scarp"] = np.maximum(masks["ice_scarp"], (np.abs(s) < 7.0) * ends)



# ---------- the young lava plain, its platy belt and the fissures (B2) ----------

def add_lava_plain(h, x, z, masks, medium, small, lobes_field, ragged_field):
    """Young lava floods the low ground in the east: a nearly level surface
    over the (smoothed) buried land, older ground standing out of it as
    islands, ending in a lobate front a few metres high. Inflated lobes and
    low pressure ridges roughen it."""
    c = LAVA_PLAIN
    lob = np.roll(lobes_field, (500, 900), (0, 1)); lob2 = np.roll(lobes_field, (-700, 300), (0, 1))
    rag = np.roll(ragged_field, (300, 700), (0, 1))
    south = (x > c["west"] + 170.0 * lob + 45.0 * rag) & (z > c["north"] + 130.0 * lob2 + 40.0 * rag)
    strip = (x > c["strip_west"] + 140.0 * lob2 + 40.0 * rag) & (z > c["strip_north"] + 120.0 * lob)
    inside = (south | strip) & (masks["crater_d"] > 1.2 + 0.05 * lob) & (z + 160.0 * masks["large"] < HALF - 600.0)
    sd = box_blur(signed_distance(inside), 3)
    # Lava finds its level: the plain falls gently south-south-west, away
    # from the vent, and the old land's broad swells are buried under it
    # (they're eased towards that level well back from the front).
    buried = box_blur(h, 70)
    level = float(np.median(buried[inside]))
    plane = level - 0.008 * ((x - 2250.0) * -0.47 + (z - 1050.0) * 0.88)
    ease = smoothstep(-350.0, 150.0, sd)
    h -= 0.9 * ease * (buried - plane)
    buried = buried - 0.9 * ease * (buried - plane)
    thick = c["thickness"] * (1.0 + 0.45 * np.roll(lob, (-300, 400), (0, 1)))
    tumuli = 1.4 * np.clip(spectral_noise(2.6, kind_seed("lava_plain", SEED + 120), k_low=0.02, k_high=0.07) - 0.9, 0.0, None)
    # Inflated lobes: the surface steps down a metre or two from sheet to sheet.
    sheets = spectral_noise(3.2, kind_seed("lava_plain", SEED + 120) + 1, k_low=0.004, k_high=0.02) * 2.2
    sgz, sgx = np.gradient(sheets, SPACING)
    edge = np.clip(3.0 * np.sqrt(sgx * sgx + sgz * sgz), 0.004, 0.5)   # each sheet ends in a face about 3 m across
    part = sheets - np.floor(sheets)
    stepped = smoothstep(1.0 - edge, 1.0, part) - part
    top = buried + thick + 0.35 * medium + tumuli + 2.6 * stepped
    front = smoothstep(0.0, 10.0, sd)
    h += (np.maximum(h, top) - h) * front
    masks["lava"] = front * (h <= top + 0.5)
    masks["lava_sd"] = sd


def voronoi_edges(px, pz, salt):
    """For points in cell units: distance to the nearest cell point, how far
    it is to the edge between the two nearest (cell units), and the nearest
    cell's indices."""
    ci = np.floor(px); cj = np.floor(pz)
    f1 = np.full(px.shape, 9.0); f2 = np.full(px.shape, 9.0)
    ni = np.zeros(px.shape); nj = np.zeros(px.shape)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            sx = ci + di + 0.1 + 0.8 * cell_hash(ci + di, cj + dj, salt)
            sz = cj + dj + 0.1 + 0.8 * cell_hash(ci + di, cj + dj, salt + 1.0)
            dd = np.sqrt((px - sx) ** 2 + (pz - sz) ** 2)
            closer = dd < f1
            f2 = np.where(closer, f1, np.minimum(f2, dd))
            ni = np.where(closer, ci + di, ni); nj = np.where(closer, cj + dj, nj)
            f1 = np.minimum(f1, dd)
    return f1, f2 - f1, ni, nj


def add_platy_belt(h, x, z, masks, medium):
    """The platy belt along the lava plain's west margin: the crust broke
    into plates tens of metres across that rafted apart, tilted and jammed,
    with pressure ridges where they met and rough gaps between. A few lines
    of smoother lava wind through it: the safe ways across."""
    c = PLATY_BELT
    sd = masks["lava_sd"]
    belt = smoothstep(14.0, 40.0, sd) * (1.0 - smoothstep(c["width"] - 40.0, c["width"], sd)) * (1.0 - smoothstep(c["east"] - 60.0, c["east"], x)) * (masks["lava"] > 0.5)
    rows = np.where(belt.max(axis=1) > 0.01)[0]; cols = np.where(belt.max(axis=0) > 0.01)[0]
    win = (slice(rows[0], rows[-1] + 1), slice(cols[0], cols[-1] + 1))
    size = c["plate"]
    px = (x[win] + 9.0 * medium[win]) / size; pz = (z[win] - 9.0 * medium[win]) / size
    f1, edge, ni, nj = voronoi_edges(px, pz, 11.0)
    edge_m = edge * size
    tilt_x = (cell_hash(ni, nj, 13.0) - 0.5) * 0.11; tilt_z = (cell_hash(ni, nj, 14.0) - 0.5) * 0.11
    raft = (cell_hash(ni, nj, 15.0) - 0.5) * 2.4
    slab = raft + ((px - ni - 0.5) * tilt_x + (pz - nj - 0.5) * tilt_z) * size
    jammed = cell_hash(ni, nj, 16.0) > 0.35
    ridge = 2.6 * (1.0 - smoothstep(0.0, 5.0, edge_m)) * jammed
    gap = -1.8 * (1.0 - smoothstep(0.0, 3.0, edge_m)) * (~jammed)
    rough = np.zeros_like(h)
    rough[win] = slab + ridge + gap
    # The safe lines: smoother lava from the front through to the plain.
    rng = np.random.default_rng(kind_seed("platy_belt", SEED + 130))
    zs = np.where(belt.max(axis=1) > 0.5)[0]
    z_lo, z_hi = float(z[zs[0], 0]) + 150.0, float(z[zs[-1], 0]) - 150.0
    lanes = np.ones_like(h)
    lines = []
    for k in range(c["lanes"]):
        start = (LAVA_PLAIN["west"] - 320.0, z_lo + (z_hi - z_lo) * (k + 0.5) / c["lanes"] + rng.uniform(-120.0, 120.0))
        line = wander(start, 0.0, c["width"] + 760.0, rng, step=14.0, turn=0.2)
        d, _, _ = polyline_field(line, 40.0, step=1)
        lanes = np.minimum(lanes, smoothstep(5.0, 16.0, d))
        lines.append([[round(float(q[0]), 1), round(float(q[1]), 1)] for q in line[::4]])
    amount = belt * lanes
    h += rough * amount
    masks["platy"] = amount
    masks["platy_belt"] = belt
    masks["platy_lanes"] = lines


def plan_fissures(masks):
    """Each fissure's line, and its width and depth along it. Where one is
    too wide or deep to drive, the route check is told the ground is closed,
    so rover routes go round and no track is ever graded across."""
    plans = []
    block = np.zeros((N, N), dtype=bool)
    rng = np.random.default_rng(kind_seed("fissure", SEED + 140))
    for f in FISSURES:
        a = np.array(f["from"]); b = np.array(f["to"])
        length = float(np.linalg.norm(b - a))
        n = int(length / 20.0) + 1
        t = np.linspace(0.0, 1.0, n)
        line = a[None, :] + (b - a)[None, :] * t[:, None]
        across = np.array([-(b - a)[1], (b - a)[0]]) / length
        # En echelon: straight stretches that step sideways a little.
        offset = np.cumsum(rng.normal(0.0, 1.0, n)); offset -= np.linspace(offset[0], offset[-1], n)
        offset = 14.0 * offset / max(1.0, float(np.abs(offset).max())) + 9.0 * np.tanh(4.0 * np.sin(np.linspace(0.0, 21.0, n)))
        line = line + across[None, :] * offset[:, None]
        grow = smoothstep(0.0, 0.35, t)   # from nothing at the narrow end
        half_width = 1.0 + (f["half_width"] - 1.0) * grow * (0.8 + 0.2 * np.sin(t * 37.0))
        depth = f["depth"] * smoothstep(0.0, 0.3, t) * (0.85 + 0.15 * np.sin(t * 23.0 + 1.0))
        d, tt, _ = polyline_field(line, 90.0, t, step=1)
        width_at = np.interp(tt, t, half_width)
        block |= (d < width_at + 8.0) & (np.interp(tt, t, depth) > 1.5)
        plans.append({"f": f, "line": line, "t": t, "half_width": half_width, "depth": depth, "length": length, "d": d, "tt": tt, "width_at": width_at})
    plan_cracks(masks, plans, block)
    plan_minor_cracks(masks, plans, block)
    masks["route_block"] = block
    return plans


def carve_fissures(h, x, z, masks, plans):
    """Fissures: the crust pulled apart along a line. Sheer walls, a rubble
    floor, widest and deepest in the east and pinching out to nothing at the
    west end, where the floor climbs back to the land (the way out on foot)."""
    out = []
    masks["fissure"] = np.zeros_like(h)
    masks["fissure_near"] = np.zeros_like(h)
    for plan in plans:
        f, line, t, half_width, depth, length = plan["f"], plan["line"], plan["t"], plan["half_width"], plan["depth"], plan["length"]
        d, tt, width_at = plan["d"], plan["tt"], plan["width_at"]
        n = len(line)
        land = np.array([sample(h, q[0], q[1]) for q in line])
        land = run_filter(land, 6, np.min)
        floor = land - depth
        wall_run = np.full(n, plan.get("wall_run", 3.0))
        mask = carve_channel(h, line, floor, half_width, depth, wall_run, reach_extra=20.0, step=1, params=t)
        masks["fissure"] = np.maximum(masks["fissure"], mask * (np.interp(tt, t, depth) > 3.0))
        masks["fissure_near"] = np.maximum(masks["fissure_near"], 1.0 - smoothstep(width_at + 4.0, width_at + 40.0, d))
        entry = {"id": f["id"], "half_width": f["half_width"], "depth": f["depth"],
                 "points": [[round(float(q[0]), 1), round(float(q[1]), 1), round(float(w), 1), round(float(dp), 1)] for q, w, dp in zip(line[::3], half_width[::3], depth[::3])]}
        if f["id"] in ("home_crack", "crack"):
            continue
        if f["bridge"] is not None:
            k = int(f["bridge"] * (n - 1))
            entry["bridge"] = {"position": [round(float(line[k][0]), 1), round(float(line[k][1]), 1)], "span": round(float(half_width[k] * 2.0 + 6.0), 1)}
        out.append(entry)
        print(f"  {f['id']}: {length:.0f} m, to {half_width.max() * 2:.0f} m wide and {depth.max():.0f} m deep")
    return out


def add_hollow_ground(h, x, z, masks, tube):
    """Hollow ground along the lava tube: a thin crust over voids. A few have
    already fallen in (small collapse pits); the rest only show to radar,
    and are written to the hidden layer of the ground map."""
    rng = np.random.default_rng(SEED + 150)
    pts = np.array([[q[0], q[1]] for q in tube["points"][:tube["deep"]["from"]]])   # over the upper tube only: the deep lies far below
    hidden = np.zeros_like(h)
    pits = []
    for _ in range(400):
        if len(pits) >= 46:
            break
        k = int(rng.integers(20, len(pts) - 20))
        side = rng.choice([-1.0, 1.0]) * rng.uniform(26.0, 120.0)
        tangent = pts[min(k + 4, len(pts) - 1)] - pts[max(k - 4, 0)]; tangent /= np.linalg.norm(tangent)
        q = pts[k] + np.array([-tangent[1], tangent[0]]) * side
        r = rng.uniform(2.5, 6.0)
        if any(math.hypot(q[0] - p[0], q[1] - p[1]) < r + p[2] + 14.0 for p in pits):
            continue
        if any(math.hypot(q[0] - s["position"][0], q[1] - s["position"][1]) < s["radius"] * 4.0 + r for s in tube["skylights"]):
            continue
        fallen = len(pits) % 3 == 0
        pits.append((float(q[0]), float(q[1]), r, fallen))
        i0 = max(0, int((q[0] - r * 3 + HALF) / SPACING)); i1 = min(N, int((q[0] + r * 3 + HALF) / SPACING) + 1)
        j0 = max(0, int((q[1] - r * 3 + HALF) / SPACING)); j1 = min(N, int((q[1] + r * 3 + HALF) / SPACING) + 1)
        win = (slice(j0, j1), slice(i0, i1))
        d = np.hypot(x[win] - q[0], z[win] - q[1])
        if fallen:   # a pit with a rubble slope you can scramble out of
            h[win] -= rng.uniform(2.0, 3.6) * (1.0 - smoothstep(r * 0.5, r * 1.5, d))
        else:
            h[win] -= 0.35 * (1.0 - smoothstep(r * 0.6, r * 2.2, d))   # a faint sag is the only sign
            hidden[win] = np.maximum(hidden[win], (d < r).astype(np.float32))
    masks["hollow"] = hidden
    return [{"position": [round(p[0], 1), round(p[1], 1)], "radius": round(p[2], 1), "fallen": bool(p[3])} for p in pits]



# ---------- yardangs, ripple belts, raised riverbeds, the buried glacier (B2) ----------

def window(cx, cz, reach):
    i0 = max(0, int((cx - reach + HALF) / SPACING)); i1 = min(N, int((cx + reach + HALF) / SPACING) + 1)
    j0 = max(0, int((cz - reach + HALF) / SPACING)); j1 = min(N, int((cz + reach + HALF) / SPACING) + 1)
    return (slice(j0, j1), slice(i0, i1))


def add_yardangs(h, x, z, masks, medium):
    """A yardang maze (T3, in the style of the Medusae Fossae yardangs): long, sharp-crested,
    steep-sided ridges of soft rock, 3 to 5 times longer than wide and taller than you can see over,
    lying along the wind in lanes, with narrow corridors between. Here and there two ridges join across
    a corridor and close it (a dead end); gaps in the ridges let you change lane. Only a few ways lead
    through. The real HiRISE yardangs (Arabia Terra) give the ridges their surface detail."""
    c = landform("yardangs")
    rng = np.random.default_rng(seed_of(c))
    wind = np.array(DUNE_WIND) / np.linalg.norm(DUNE_WIND)
    side_dir = np.array([-wind[1], wind[0]])
    centre = np.array(c["centre"])
    L, W = c["length"], c["width"]
    win = window(centre[0], centre[1], max(L, W) * 0.62)
    X, Z = x[win], z[win]
    along = (X - centre[0]) * wind[0] + (Z - centre[1]) * wind[1]
    across = -(X - centre[0]) * wind[1] + (Z - centre[1]) * wind[0]
    shape_p = 4.0   # a rounded block, not an oval: every lane runs most of the field's length (an oval's outer lanes are short and easy to walk round)
    dd = ((np.abs(along) / (L * 0.5)) ** shape_p + (np.abs(across) / (W * 0.5)) ** shape_p) ** (1.0 / shape_p) + 0.06 * medium[win]
    field = 1.0 - smoothstep(0.9, 1.08, dd)
    h[win] -= field * (2.5 + 1.2 * np.sin(across / 9.0 + 2.0 * medium[win]))   # the wind has scoured the patch down, in grooves
    H = c.get("ridge_height", 55.0)
    wmin, wmax = c.get("ridge_width", [44.0, 78.0])
    cmin, cmax = c.get("corridor", [12.0, 22.0])
    lmin, lmax = c.get("ridge_length", [200.0, 360.0])
    gap_share = c.get("gap_share", 0.45)    # how often a ridge ends in a gap you can walk through (else the next one overlaps it)
    joins_per = c.get("joins", 0.0045)     # joins across a corridor, per metre along it
    # Lanes across the field, ridges along each lane.
    lanes = []
    v = -W * 0.62
    while v < W * 0.62:
        w = rng.uniform(wmin, wmax)
        lanes.append((v + w * 0.5, w))
        v += w + rng.uniform(cmin, cmax)
    ridges = []
    for v0, w in lanes:
        u = -L * 0.62 - rng.uniform(0.0, 120.0)
        while u < L * 0.62:
            length = rng.uniform(lmin, lmax)
            ridges.append((u, v0 + rng.normal(0.0, 3.0), length, w * rng.uniform(0.85, 1.1), H * rng.uniform(0.9, 1.08), rng.uniform(0, 6.3)))
            u += length + (rng.uniform(16.0, 30.0) if rng.random() < gap_share else -length * rng.uniform(0.1, 0.25))
    joins = []
    corridors = len(lanes) - 1
    through = set(rng.choice(corridors, size=min(int(c.get("through_lanes", 2)), corridors), replace=False).tolist()) if corridors > 0 else set()
    for k in range(corridors):
        (va, wa), (vb, wb) = lanes[k], lanes[k + 1]
        if k in through:   # one of the few lanes that lead all the way through (it still has to be found)
            continue
        n = max(1, rng.poisson(joins_per * L))
        for _ in range(n):
            joins.append((rng.uniform(-L * 0.45, L * 0.45), 0.5 * (va + wa * 0.5 + vb - wb * 0.5), (vb - wb * 0.5) - (va + wa * 0.5) + 30.0, rng.uniform(16.0, 26.0)))
    ridge_body = np.zeros_like(X)
    for u0, v0, length, w, height, ph in ridges:
        un = (along - u0) / length
        near = (un > -0.05) & (un < 1.05) & (np.abs(across - v0) < w)
        if not near.any():
            continue
        unn = un[near]
        half = 0.5 * w * smoothstep(-0.02, 0.12, unn) * (1.0 - 0.55 * np.clip(unn, 0.0, 1.0) ** 1.6)   # blunt upwind, tapering downwind
        bend = 0.12 * w * np.sin(unn * 4.0 + ph)
        dv = np.abs(across[near] - v0 - bend)
        crest = height * smoothstep(-0.02, 0.08, unn) * (1.0 - 0.4 * smoothstep(0.45, 1.0, unn))
        ridge_body[near] = np.maximum(ridge_body[near], crest * np.clip(1.0 - dv / np.maximum(half, 0.5), 0.0, 1.0) ** c.get("crest_sharpness", 0.9) * (unn < 1.0))

    def join_body(keep):
        out = np.zeros_like(X)
        for j, (uj, vj, span, thick) in enumerate(joins):
            if not keep[j]:
                continue
            du = np.abs(along - uj) / (thick * 0.5); dv = np.abs(across - vj) / (span * 0.5)
            near = (du < 1.0) & (dv < 1.0)
            out[near] = np.maximum(out[near], 0.85 * H * np.clip(1.0 - du[near], 0.0, 1.0) ** 0.5 * (1.0 - smoothstep(0.85, 1.0, dv[near])))
        return out

    entry = centre - wind * (L * 0.5 + 20.0); exit_ = centre + wind * (L * 0.5 + 20.0)       # along the wind: the through-lanes
    side_a = centre - side_dir * (W * 0.5 + 20.0); side_b = centre + side_dir * (W * 0.5 + 20.0)   # across it: the hard way
    dd0 = ((np.abs(along) / (L * 0.5)) ** shape_p + (np.abs(across) / (W * 0.5)) ** shape_p) ** (1.0 / shape_p)   # the walked region (no wobble, so the ends always meet it)
    # Across the wind the way is measured through the field, not round its ends (walking round is allowed in
    # the game, but it isn't the maze): a band over the middle of the field's length.
    across_region = (np.abs(along) < L * 0.4) & (np.abs(across) < W * 0.5 + 40.0)
    keep = [True] * len(joins)
    for attempt in range(40):   # a way must lead through: take joins away (at random) until one does
        body = np.maximum(ridge_body, join_body(keep)) * field
        result = maze_paths(body, win, entry, exit_, (dd0 < 1.15), 4)
        across_result = maze_paths(body, win, side_a, side_b, across_region, 4)
        if (result["through"] and across_result["through"]) or not any(keep):
            break
        on = [j for j, k_ in enumerate(keep) if k_]
        keep[on[int(rng.integers(len(on)))]] = False
    stepped = np.floor(body / 6.0) * 6.0 + 6.0 * smoothstep(0.35, 1.0, (body % 6.0) / 6.0)   # hard beds stand out as ledges on the flanks
    lift = 0.4 * body + 0.6 * stepped
    patch_path = os.path.join(ROOT, "assets", "terrain", "patches", "yardangs_arabia.npz")
    if os.path.exists(patch_path):
        relief = np.load(patch_path)["relief"].astype(np.float32)
        rows, cols = relief.shape

        def mirror(tt, n):
            tt = np.mod(tt, 2.0 * (n - 1.001))
            return np.where(tt > n - 1.001, 2.0 * (n - 1.001) - tt, tt)
        uu = mirror(along / SPACING + cols / 2.0, cols); vv = mirror(across / SPACING + rows / 2.0, rows)
        i0 = np.floor(uu).astype(int); j0 = np.floor(vv).astype(int); fu = uu - i0; fv = vv - j0
        real = (relief[j0, i0] * (1 - fu) * (1 - fv) + relief[j0, i0 + 1] * fu * (1 - fv) + relief[j0 + 1, i0] * (1 - fu) * fv + relief[j0 + 1, i0 + 1] * fu * fv)
        lift += c.get("real_detail", 0.18) * real * smoothstep(2.0, 12.0, body)   # surface grooves and knobs on the ridges, not on the corridor floors
    h[win] += lift
    full = np.zeros_like(h); full[win] = (body > 4.0)
    masks["yardangs"] = full.astype(np.float32)
    f = np.zeros_like(h); f[win] = field
    masks["yardang_field"] = f
    jpos = [(centre + wind * uj + side_dir * vj) for (uj, vj, _, _), k_ in zip(joins, keep) if k_]
    masks["maze_plan"] = {"win": win, "entry": entry, "exit": exit_, "side_a": side_a, "side_b": side_b, "region": (dd0 < 1.15), "across_region": across_region, "joins": jpos}
    no = np.zeros_like(h); no[win] = (body > 6.0)
    masks["no_grade"] = np.maximum(masks.setdefault("no_grade", np.zeros_like(h)), no)
    print(f"  yardangs: {len(ridges)} ridges in {len(lanes)} lanes, {sum(keep)} joins, to {float(body.max()):.0f} m; "
          f"along the wind {result['ratio']:.1f}x the straight line, across it {across_result['ratio']:.1f}x" + ("" if result["through"] and across_result["through"] else " (NO WAY THROUGH)"))


def add_ripple_belts(h, x, z, masks, medium):
    """Ripple belts: bands of big, pale sand ripples (transverse aeolian
    ridges) a metre or three tall and a few tens of metres apart, across
    the wind. Rovers bog in them. One rings the dune sea, others lie in
    low ground on their own."""
    wind = np.array(DUNE_WIND)
    along = x * wind[0] + z * wind[1]
    across = -x * wind[1] + z * wind[0]
    belt = smoothstep(0.98, 1.06, masks["dune_dd"]) * (1.0 - smoothstep(1.22, 1.4, masks["dune_dd"]))
    belt *= 0.5 + 0.5 * smoothstep(-0.3, 0.3, np.roll(medium, (211, 97), (0, 1)))   # it comes and goes
    for cx, cz, length, width in RIPPLE_BELTS:
        a = (x - cx) * wind[0] + (z - cz) * wind[1]; c = -(x - cx) * wind[1] + (z - cz) * wind[0]
        # Belts lie across the wind: long across it, short along it.
        dd = np.sqrt((a / (width * 0.5)) ** 2 + (c / (length * 0.5)) ** 2) + 0.15 * medium
        belt = np.maximum(belt, 1.0 - smoothstep(0.8, 1.05, dd))
    belt *= (masks["canyon_u"] > 40.0) * (1.0 - masks["mesa_body"]) * (masks["crater_d"] > 1.04)
    phase = along / 26.0 + 0.3 * np.sin(across / 60.0 + 0.5 * medium) + 0.1 * medium
    f = phase - np.floor(phase)
    crest = np.where(f < 0.55, smoothstep(0.0, 1.0, f / 0.55), 1.0 - smoothstep(0.0, 1.0, (f - 0.55) / 0.45))
    tall = 1.6 + 0.9 * np.sin(across / 45.0 + 1.3 * medium)
    h += belt * (tall * crest ** 1.3 + 0.4)
    masks["ripples"] = belt


def raised_channel(h, line, top, half_width, masks, side_run=9.0):
    """Lay a raised riverbed along `line`: a flat-topped ridge of cemented
    gravel standing `top` (per point) over the land beside it."""
    params = np.arange(len(line), dtype=float)
    reach = float(np.max(half_width)) + side_run + 30.0
    d, t, _ = polyline_field(line, reach, params, step=1)
    near = d < reach
    top_at = np.interp(t[near], params, top)
    width_at = np.interp(t[near], params, half_width)
    s = np.maximum(0.0, d[near] - width_at)
    lift = top_at * (1.0 - smoothstep(0.0, side_run, s))
    h[near] += lift
    masks["inverted"][near] = np.maximum(masks["inverted"][near], (s < 1.0).astype(np.float32))
    masks["inverted_side"][near] = np.maximum(masks["inverted_side"][near], ((s >= 1.0) & (s < side_run)).astype(np.float32))


def add_inverted_channels(h, x, z, masks, medium):
    """Raised old riverbeds: an older river than the valley network. Its
    gravel bed set hard, the soft plain round it blew away, and the channel
    was left standing as a sinuous ridge with tributaries joining it. Sand
    has gathered on the plain beside it, so the ridge top is the firm way."""
    c = INVERTED_CHANNELS
    rng = np.random.default_rng(kind_seed("raised_riverbed", SEED + 170))
    masks["inverted"] = np.zeros_like(h); masks["inverted_side"] = np.zeros_like(h)
    sheet = 1.0 - smoothstep(0.75, 1.05, dist(x, z, c["sand_centre"]) / c["sand_radius"] + 0.2 * medium)
    sheet *= 1.0 - smoothstep(0.85, 1.0, masks["mesa_body"] + masks["talus"])
    h += sheet * (0.9 + 0.5 * np.sin((x * 0.6 + z) / 11.0 + medium))
    masks["sand_sheet"] = np.maximum(masks.get("sand_sheet", 0.0), sheet)
    lines = []
    main = smooth_line(c["points"], 16.0, 30.0, rng)
    n = len(main)
    ends = np.clip(np.minimum(np.arange(n), n - 1 - np.arange(n)) / 6.0, 0.0, 1.0)
    raised_channel(h, main, (6.0 + 6.0 * np.linspace(0.0, 1.0, n)) * ends, 16.0 + 14.0 * np.linspace(0.0, 1.0, n), masks)
    lines.append(main)
    for at, turn in c["tributaries"]:
        k = int(at * (n - 1))
        back = main[k - 2] - main[k + 2]
        heading = math.atan2(back[1], back[0]) + turn
        branch = wander(main[k], heading, rng.uniform(320.0, 520.0), rng, step=16.0, turn=0.08)
        m = len(branch)
        fade = np.clip((m - 1 - np.arange(m)) / 6.0, 0.0, 1.0)
        raised_channel(h, branch, (4.0 + 4.0 * np.linspace(1.0, 0.0, m)) * fade, 8.0 + 8.0 * np.linspace(1.0, 0.0, m), masks)
        lines.append(branch)
    masks["inverted_lines"] = [[[round(float(q[0]), 1), round(float(q[1]), 1)] for q in line[::3]] for line in lines]


def add_buried_glacier(h, x, z, masks, medium):
    """A buried glacier: ice under a few metres of rubble, flowed out from a
    mesa's foot as a lobate apron with a steep convex front, ridges along
    the flow, and pits where the ice has sublimated away. Some pits are
    still roofed over: those go on the hidden layer for radar to find."""
    c = GLACIER
    rng = np.random.default_rng(kind_seed("glacier", SEED + 180))
    axis = np.array(c["flow"]); axis = axis / np.linalg.norm(axis)
    origin = np.array(c["from"])
    win = window(origin[0] + axis[0] * c["length"] * 0.5, origin[1] + axis[1] * c["length"] * 0.5, c["length"])
    u = ((x[win] - origin[0]) * axis[0] + (z[win] - origin[1]) * axis[1]) / c["length"]
    v = (-(x[win] - origin[0]) * axis[1] + (z[win] - origin[1]) * axis[0]) / (c["width"] * 0.5)
    spread = 0.55 + 0.45 * smoothstep(0.0, 0.6, u)   # it fans out as it flows
    r = np.sqrt(np.clip(u, 0.0, None) ** 2 + (v / spread) ** 2) + 0.1 * medium[win] + 0.05 * np.sin(np.arctan2(v, u) * 7.0)
    lobe = np.clip(1.0 - r ** 4, 0.0, 1.0) ** 0.5 * (u > -0.1) * smoothstep(-0.1, 0.05, u)
    lines = 0.7 * np.sin(v * 26.0 + 2.0 * medium[win]) * lobe
    arcs = 0.9 * np.sin(r * 40.0) * smoothstep(0.55, 0.9, r) * lobe   # ridges bowed round the front
    h[win] += c["thickness"] * lobe + lines + arcs
    body = np.zeros_like(h); body[win] = (lobe > 0.25)
    masks["glacier"] = body
    hidden = masks.setdefault("sinkholes", np.zeros_like(h))
    pits = []
    for _ in range(600):
        if len(pits) >= c["pits"]:
            break
        pu = rng.uniform(0.15, 0.85); pv = rng.uniform(-0.6, 0.6) * (0.55 + 0.45 * pu)
        q = origin + axis * pu * c["length"] + np.array([-axis[1], axis[0]]) * pv * c["width"] * 0.5
        pr = rng.uniform(5.0, 18.0)
        if any(math.hypot(q[0] - p[0], q[1] - p[1]) < pr + p[2] + 10.0 for p in pits):
            continue
        roofed = len(pits) % 4 == 3
        pits.append((float(q[0]), float(q[1]), pr, roofed))
        w2 = window(q[0], q[1], pr * 2.2)
        d = np.hypot(x[w2] - q[0], z[w2] - q[1])
        if roofed:
            hidden[w2] = np.maximum(hidden[w2], (d < pr * 0.8).astype(np.float32))
            h[w2] -= 0.3 * (1.0 - smoothstep(pr * 0.5, pr * 1.6, d))
        else:   # an open pit, steeper on its pole-facing side, always with a slope you can climb
            h[w2] -= rng.uniform(2.0, 5.0) * (1.0 - smoothstep(pr * 0.35, pr * 1.25, d))
    masks["glacier_pits"] = [{"position": [round(p[0], 1), round(p[1], 1)], "radius": round(p[2], 1), "roofed": bool(p[3])} for p in pits]


def add_chaos_blocks(h, x, z, masks, medium):
    """Chaos blocks: the ground broke into flat-topped blocks tens of metres
    across when what lay under it gave way, leaving a maze of troughs."""
    cx, cz, radius, size = CHAOS_BLOCKS
    win = window(cx, cz, radius * 1.4)
    px = (x[win] + 14.0 * medium[win]) / size; pz = (z[win] - 14.0 * medium[win]) / size
    f1, edge, ni, nj = voronoi_edges(px, pz, 31.0)
    field = 1.0 - smoothstep(0.7, 1.05, np.hypot(x[win] - cx, z[win] - cz) / radius + 0.15 * medium[win])
    height = 18.0 + 38.0 * cell_hash(ni, nj, 33.0)
    gap = (12.0 + 16.0 * cell_hash(ni, nj, 34.0)) / size
    block = smoothstep(gap * 0.5, gap * 0.5 + 0.09, edge)   # sheer-sided, flat-topped
    tilt = ((px - ni - 0.5) * (cell_hash(ni, nj, 35.0) - 0.5) + (pz - nj - 0.5) * (cell_hash(ni, nj, 36.0) - 0.5)) * 9.0
    keep = cell_hash(ni, nj, 37.0) > 0.12   # a few have gone altogether
    h[win] += field * block * keep * (height + tilt)
    body = np.zeros_like(h); body[win] = field * block * keep
    masks["chaos"] = body


def add_home_ground(h, x, z, masks, medium):
    """Ring 1's own landforms (docs/terrain-design.md §3 and §6): the frost
    hollow with its shallow ice, dry channels with low crossings, a
    sand sheet in a mesa's lee, and the places the land locks until you
    have the kit: a ledge-topped outcrop (a ladder) and a collapse pit (a
    rope). The cracked sliver (a bridge) is carved with the fissures."""
    c = HOME_GROUND
    # The frost hollow.
    fx, fz, fr, fd = c["frost_hollow"]
    w = window(fx, fz, fr * 2.0)
    d = np.hypot(x[w] - fx, z[w] - fz) / fr + 0.12 * medium[w]
    bowl = 1.0 - smoothstep(0.25, 1.25, d)
    h[w] -= fd * bowl
    hollow = np.zeros_like(h); hollow[w] = (bowl > 0.45)
    masks["frost_hollow"] = hollow
    for k, e in enumerate(landforms("channel")):
        add_dry_channel(h, x, z, masks, medium, e, first=(k == 0))
    # A sand sheet in the lee of a mesa.
    sx, sz, sr = c["sand_sheet"]
    wind = np.array(DUNE_WIND)
    a = (x - sx) * wind[0] + (z - sz) * wind[1]; b = -(x - sx) * wind[1] + (z - sz) * wind[0]
    sheet = 1.0 - smoothstep(0.7, 1.05, np.sqrt((a / (sr * 1.6)) ** 2 + (b / sr) ** 2) + 0.2 * medium)
    sheet *= 1.0 - smoothstep(0.85, 1.0, masks["mesa_body"] + masks["talus"])
    h += sheet * (1.0 + 0.6 * np.sin(a / 9.0 + medium))
    masks["sand_sheet"] = np.maximum(masks.get("sand_sheet", 0.0), sheet)
    # The ledge-topped outcrop: a knob of hard rock, sheer all round.
    ox, oz, orad, oh = c["outcrop"]
    w = window(ox, oz, orad * 2.5)
    ang = np.arctan2(z[w] - oz, x[w] - ox)
    d = np.hypot(x[w] - ox, z[w] - oz) / (orad * (1.0 + 0.14 * np.sin(ang * 3.0 + 1.0) + 0.08 * np.sin(ang * 5.0)))
    top = sample(h, ox, oz) + oh
    knob = 1.0 - smoothstep(1.0, 1.0 + 2.2 / orad, d)
    h[w] = h[w] * (1.0 - knob) + (top + 0.25 * medium[w]) * knob
    h[w] += 1.2 * np.clip(1.0 - (d - 1.1) / 0.9, 0.0, 1.0) * (d > 1.1)   # a little fallen rubble at its foot
    # The collapse pit: sheer, with a low rubble lip, so nobody walks in by accident.
    px, pz, prad, pdepth = c["pit"]
    w = window(px, pz, prad * 3.0)
    d = np.hypot(x[w] - px, z[w] - pz) / prad
    h[w] += 0.9 * np.exp(-((d - 1.35) / 0.25) ** 2)
    h[w] -= pdepth * (1.0 - smoothstep(0.86, 1.0, d))
    clear = masks.setdefault("kit_clear", np.zeros_like(h))
    for qx, qz, qr in ((ox, oz, orad * 2.2), (px, pz, prad * 2.5)):
        w = window(qx, qz, qr)
        clear[w] = np.maximum(clear[w], (np.hypot(x[w] - qx, z[w] - qz) < qr).astype(np.float32))


def maze_paths(hh, win, entry, exit_, region, cell):
    """On foot through a patch: is there a way from entry to exit (no step steeper than 40 degrees, staying in
    `region`), how long is it against the straight line, and which cells can you reach. Heights `hh` are the
    window `win` of the region grid (2 m), worked on a `cell`-metre grid."""
    k = int(cell / SPACING)
    g = hh[::k, ::k]; allowed = region[::k, ::k].copy()
    j0, i0 = win[0].start, win[1].start

    def at(p):
        return int(round((p[1] + HALF) / SPACING - j0)) // k, int(round((p[0] + HALF) / SPACING - i0)) // k

    rows, cols = g.shape
    ej, ei = at(entry); xj, xi = at(exit_)
    ej, ei, xj, xi = min(max(ej, 0), rows - 1), min(max(ei, 0), cols - 1), min(max(xj, 0), rows - 1), min(max(xi, 0), cols - 1)
    for (pj, pi) in ((ej, ei), (xj, xi)):   # a pad at each end, outside the field
        allowed[max(pj - 6, 0):pj + 7, max(pi - 6, 0):pi + 7] = True
    limit = math.tan(math.radians(40.0))
    shifts = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0), (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414)]
    moves = []
    for dj, di, dist_ in shifts:
        src = (slice(max(-dj, 0), rows - max(dj, 0)), slice(max(-di, 0), cols - max(di, 0)))
        dst = (slice(max(dj, 0), rows - max(-dj, 0)), slice(max(di, 0), cols - max(-di, 0)))
        ok = (np.abs(g[dst] - g[src]) <= limit * cell * dist_) & allowed[src] & allowed[dst]
        moves.append((src, dst, ok))
    steps = np.full(g.shape, -1, dtype=np.int32)
    steps[ej, ei] = 0
    front = np.zeros(g.shape, dtype=bool); front[ej, ei] = True
    n = 0
    while front.any() and steps[xj, xi] < 0 and n < 4000:
        n += 1
        new = np.zeros_like(front)
        for src, dst, ok in moves:
            new[dst] |= front[src] & ok
        new &= steps < 0
        steps[new] = n
        front = new
    if steps[xj, xi] < 0:   # finish the flood, for what can be reached at all
        while front.any() and n < 4000:
            n += 1
            new = np.zeros_like(front)
            for src, dst, ok in moves:
                new[dst] |= front[src] & ok
            new &= steps < 0
            steps[new] = n
            front = new
    straight = max(abs(xj - ej), abs(xi - ei))
    through = bool(steps[xj, xi] >= 0)
    return {"through": through, "ratio": (float(steps[xj, xi]) / max(straight, 1)) if through else 0.0, "reached": steps >= 0, "cell": cell}


def add_dry_channel(h, x, z, masks, medium, e, first):
    """A dry channel (T3, after HiRISE ESP_088471_1750): terraced banks down to a gravel floor, a narrower
    inner channel meandering in it, gravel bars beside that, low crossings where the banks ease, and a
    little network of V-shaped tributaries branching off upstream."""
    rng = np.random.default_rng(seed_of(e))
    line = smooth_line(e["points"], 14.0, e.get("wiggle", 22.0), rng)
    n = len(line)
    t = np.linspace(0.0, 1.0, n)
    ends = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t)
    low = np.ones(n)
    for p in e["crossings"]:
        low -= 0.8 * np.exp(-((t - p) / 0.035) ** 2)
    low = np.clip(low, 0.2, 1.0)
    depth = e["depth"] * ends * low
    floor = np.empty(n)
    for k in range(n):
        ground = sample(h, line[k][0], line[k][1]) - depth[k]
        floor[k] = ground if k == 0 else min(ground, floor[k - 1] - 0.01)
    hw = np.full(n, e.get("half_width", 8.0)) * (0.5 + 0.5 * ends)
    at_crossing = low < 0.6
    # Terraced banks: a bench half way up, then the inner bank down to the floor.
    bench = e.get("bench", 0.5)
    carve_channel(h, line, floor + depth * bench, hw * e.get("bench_width", 1.9), np.maximum(depth * (1.0 - bench), 0.2),
                  np.where(at_crossing, 16.0, 3.5) * np.ones(n), step=1)
    mask = carve_channel(h, line, floor, hw, np.maximum(depth * bench, 0.3), np.where(at_crossing, 16.0, 3.0) * np.ones(n), step=1)
    # The inner channel: narrow, a metre or so deeper, meandering across the floor (not at the crossings).
    _, nrm = line_frames(line)
    s = np.arange(n) * 14.0
    offset = hw * 0.45 * np.sin(s / 41.0 + rng.uniform(0, 6.3))
    inner = line + nrm * offset[:, None]
    inner_depth = e.get("inner_depth", 1.2) * ends * (1.0 - 0.85 * (1.0 - low) / 0.8)
    carve_channel(h, inner, floor - inner_depth, hw * 0.28, np.maximum(inner_depth, 0.05), np.full(n, 1.5), step=1)
    # Gravel bars on the floor, on the inside of the bends, opposite the inner channel.
    floor_mask = np.zeros_like(h)
    for k in range(3, n - 3, 5):
        if at_crossing[k]:
            continue
        q = line[k] - nrm[k] * np.sign(offset[k]) * hw[k] * 0.45
        tangent = line[min(k + 1, n - 1)] - line[k - 1]; tangent /= np.linalg.norm(tangent)
        w2 = window(q[0], q[1], 22.0)
        du = ((x[w2] - q[0]) * tangent[0] + (z[w2] - q[1]) * tangent[1]) / 18.0
        dv = (-(x[w2] - q[0]) * tangent[1] + (z[w2] - q[1]) * tangent[0]) / (hw[k] * 0.35)
        h[w2] += 0.55 * np.clip(1.0 - du * du - dv * dv, 0.0, 1.0) ** 0.7
    # Tributaries: V-shaped, branching off upstream and climbing away from it.
    tribs = []
    count = int(e.get("tributaries", 4))
    starts = sorted(rng.uniform(0.06, 0.48, count))
    clear_of = [(HOME_GROUND["pit"][0], HOME_GROUND["pit"][1], 70.0), (HOME_GROUND["outcrop"][0], HOME_GROUND["outcrop"][1], 70.0)]
    for j, at in enumerate(starts):
        k = int(at * (n - 1))
        if any(abs(at - p) < 0.07 for p in e["crossings"]):
            continue
        back = line[max(k - 2, 0)] - line[min(k + 2, n - 1)]
        heading = math.atan2(back[1], back[0]) + (1.0 if j % 2 == 0 else -1.0) * rng.uniform(0.7, 1.15)
        branch = wander(line[k] + nrm[k] * (1.0 if j % 2 == 0 else -1.0) * hw[k], heading, rng.uniform(140.0, 320.0), rng, step=10.0, turn=0.12)
        keep = 1
        while keep < len(branch) and not any(math.hypot(branch[keep][0] - cx, branch[keep][1] - cz) < cr for cx, cz, cr in clear_of):
            keep += 1
        branch = branch[:keep]
        m = len(branch)
        if m < 6:
            continue
        f = np.linspace(1.0, 0.0, m)   # 1 at the junction, 0 at the head
        tdepth = 0.4 + e.get("tributary_depth", 2.2) * f
        tfloor = np.empty(m)
        for q in range(m - 1, -1, -1):
            ground = sample(h, branch[q][0], branch[q][1]) - tdepth[q]
            tfloor[q] = ground if q == m - 1 else min(ground, tfloor[q + 1] - 0.03)
        tfloor = np.maximum(tfloor, floor[k] + inner_depth[k] * 0.0)
        mask = np.maximum(mask, carve_channel(h, branch, tfloor, 0.4 + 1.2 * f, tdepth, 3.5 + 4.0 * f, step=1))
        tribs.append([[round(float(p[0]), 1), round(float(p[1]), 1)] for p in branch[::3]])
    floor_mask = np.maximum(floor_mask, mask)
    masks["channels"] = np.maximum(masks["channels"], floor_mask) if "channels" in masks else floor_mask
    masks["channel_floor"] = np.maximum(masks.get("channel_floor", np.zeros_like(h)), floor_mask)
    if first:
        masks["home_channel"] = [[round(float(q[0]), 1), round(float(q[1]), 1)] for q in line[::3]]
        masks["home_crossings"] = [[round(float(line[int(p * (n - 1))][0]), 1), round(float(line[int(p * (n - 1))][1]), 1)] for p in e["crossings"]]
        masks["home_tributaries"] = tribs


def plan_cracks(masks, plans, block):
    """The cracked sliver near home: the westmost arm of the fissures. One
    crack that splits in two round a sliver of ground and joins again, so
    the sliver is cut off on every side until you can span a crack."""
    c = HOME_GROUND["sliver"]
    a = np.array(c["from"]); b = np.array(c["to"])
    length = float(np.linalg.norm(b - a))
    along = (b - a) / length; across = np.array([-along[1], along[0]])
    n = int(length / 6.0) + 1
    t = np.linspace(0.0, 1.0, n)
    s0, s1 = c["split"]
    bulge = np.sin(np.pi * np.clip((t - s0) / (s1 - s0), 0.0, 1.0)) * c["bulge"]
    taper = smoothstep(0.0, 0.16, t) * smoothstep(1.0, 0.84, t)
    half_width = 0.8 + (c["half_width"] - 0.8) * taper
    depth = c["depth"] * taper
    for sign in (1.0, -1.0):
        line = a[None, :] + (b - a)[None, :] * t[:, None] + across[None, :] * (sign * bulge)[:, None]
        d, tt, _ = polyline_field(line, 60.0, t, step=1)
        width_at = np.interp(tt, t, half_width)
        block |= (d < width_at + 6.0) & (np.interp(tt, t, depth) > 1.5)
        plans.append({"f": {"id": "home_crack", "half_width": c["half_width"], "depth": c["depth"], "bridge": None}, "line": line, "t": t,
                      "half_width": half_width, "depth": depth, "length": length, "d": d, "tt": tt, "width_at": width_at, "wall_run": 2.0})
    mid = a + (b - a) * (s0 + s1) * 0.5
    masks["sliver"] = [round(float(mid[0]), 1), round(float(mid[1]), 1)]



# ---------- no straight lines: step lines and broken ground (B2, docs/terrain-design.md §6) ----------

def smooth_line(control, step=16.0, wiggle=0.0, rng=None):
    """A smooth line through control points, with a meander of `wiggle` metres."""
    p = resample(control, step)
    for _ in range(6):
        p[1:-1] = (p[:-2] + 2.0 * p[1:-1] + p[2:]) / 4.0
    if wiggle > 0.0:
        _, n = line_frames(p)
        s = np.arange(len(p)) * step
        ends = np.clip(np.minimum(s, s[-1] - s) / 80.0, 0.0, 1.0)
        p = p + n * (ends * (wiggle * np.sin(s / 90.0 + rng.uniform(0, 6.3)) + 0.4 * wiggle * np.sin(s / 37.0 + rng.uniform(0, 6.3))))[:, None]
    return p


def add_step_lines(h, x, z, masks, medium, lobes_field, ragged_field):
    """The land steps up from the home plain to the Reach, but never in a ring (T3, §13): each step
    follows the geology and fades out at its ends. A caprock scarp stands in three ledges with spurs
    pushed out and dead-end bays cut back into it, and a fallen-rock apron at its foot; a lava flow's
    front pushes out in lobes, with small breakouts ahead of it and rough ground at its foot. A few
    passes, where fallen rock makes a ramp a rover can climb, are the only ways up by rover."""
    masks["step_front"] = np.zeros_like(h)
    masks["step_apron"] = np.zeros_like(h)
    masks.setdefault("no_grade", np.zeros_like(h))
    masks.setdefault("obstacle_lines", [])
    rough = np.abs(np.roll(masks["noise"], (900, 200), (0, 1)))
    report = []
    entries = landforms("step_line")
    for index, (c, e) in enumerate(zip(STEP_LINES, entries)):
        rng = np.random.default_rng(seed_of(e))
        line = smooth_line(c["points"], 20.0)
        length = float(np.sum(np.hypot(*np.diff(line, axis=0).T)))
        d, t, side = polyline_field(line, 1000.0, step=2)
        lob = np.roll(lobes_field, (137 * (index + 1), 71 * (index + 1)), (0, 1)); rag = np.roll(ragged_field, (53 * (index + 1), 211 * (index + 1)), (0, 1))
        flow = c["kind"] == "flow_front"
        warp = e.get("warp", 0.5) * ((95.0 * lob + 22.0 * rag) if flow else (50.0 * rag + 40.0 * lob + 14.0 * medium))   # wander off the drawn line
        s = d * side * c["up"] + warp   # > 0 on the high side
        pass_w = np.zeros_like(t)
        pass_t = e.get("pass_width", 90.0) / length
        for p in c["passes"]:
            pass_w = np.maximum(pass_w, np.exp(-((t - p) / pass_t) ** 2))
        far_from_pass = lambda tb: all(abs(tb - p) > 2.2 * pass_t for p in c["passes"])
        if flow:
            # Lobes pushing out like a real lava flow's edge (convex outward), and breakouts ahead of it.
            n_lobes = e.get("lobes", 7)
            s += e.get("lobe_size", 70.0) * (0.5 + 0.5 * np.cos(math.tau * t * n_lobes + rng.uniform(0, 6.3))) ** 2.5
        else:
            # Spurs pushed out, and dead-end bays cut back into the scarp: slots a rover drives into and must back out of.
            for _ in range(int(e.get("spurs", 4))):
                tb = rng.uniform(0.12, 0.88)
                if far_from_pass(tb):
                    wt = rng.uniform(35.0, 60.0) / length
                    s += rng.uniform(70.0, 140.0) * (1.0 - smoothstep(0.5, 1.0, np.abs(t - tb) / wt)) * smoothstep(-400.0, -50.0, s)
            for _ in range(int(e.get("bays", 4))):
                tb = rng.uniform(0.1, 0.9)
                if far_from_pass(tb):
                    wt = rng.uniform(22.0, 38.0) / length   # 45-75 m wide
                    s -= rng.uniform(120.0, 220.0) * (1.0 - smoothstep(0.55, 1.0, np.abs(t - tb) / wt)) * smoothstep(-60.0, 40.0, s)
        ends = smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.9, t)
        height = c["height"] * ends * (0.85 + 0.2 * np.sin(t * 9.0 + index * 2.0))
        behind = 1.0 - smoothstep(350.0, 900.0, s)
        run = c["sheer"] + c["pass_run"] * smoothstep(0.25, 0.8, pass_w)   # sheer, or eased to a ramp at a pass
        if not flow:   # three beds: ledge, bench, ledge, bench, ledge
            gap = e.get("ledge_gap", 24.0)
            front = sum(smoothstep(0.0, 1.0, (s - k * (gap + 0.3 * run)) / run) for k in range(3)) / 3.0
        else:
            front = smoothstep(0.0, 1.0, s / run)
        lift = height * front * behind * (d < 960.0)   # nothing at the edge of the worked window, where the fields are blended
        # Fallen rock at the foot (a scarp's apron of blocks; a flow's rubbly toe), and the breakouts.
        apron_w = e.get("apron", 40.0)
        apron = np.clip(1.0 + s / apron_w, 0.0, 1.0) * (s < 0.0) * ends * (1.0 - pass_w) * (d < 960.0)
        lift += apron ** 1.5 * (e.get("apron_height", 4.0) * (0.55 + 0.45 * rough)) * np.clip(height / max(c["height"], 1.0), 0.0, 1.0)
        if flow:
            for _ in range(int(e.get("breakouts", 4))):
                tb = rng.uniform(0.12, 0.88)
                if far_from_pass(tb):
                    wt = rng.uniform(25.0, 45.0) / length; reach = rng.uniform(70.0, 140.0)
                    tongue = (1.0 - smoothstep(0.4, 1.0, np.abs(t - tb) / wt)) * np.clip(1.0 + s / reach, 0.0, 1.0) * (s < 2.0)
                    lift = np.maximum(lift, tongue ** 0.6 * rng.uniform(4.0, 7.0) * ends)
        h += lift
        masks["step_front"] = np.maximum(masks["step_front"], ((s > -4.0) & (s < 40.0 + (60.0 if not flow else 0.0)) & (height > 3.0)).astype(np.float32))
        masks["step_apron"] = np.maximum(masks["step_apron"], apron)
        masks["no_grade"] = np.maximum(masks["no_grade"], ((front > 0.05) & (front < 0.97) & (pass_w < 0.3) & (height > 0.3 * c["height"]) & (d < 960.0)).astype(np.float32))
        pass_points = [[round(float(line[int(p * (len(line) - 1))][0]), 1), round(float(line[int(p * (len(line) - 1))][1]), 1)] for p in c["passes"]]
        report.append({"id": c["id"], "kind": c["kind"], "height": c["height"],
                       "points": [[round(float(q[0]), 1), round(float(q[1]), 1)] for q in line[::4]], "passes": pass_points})
        top = (2.0 * (e.get("ledge_gap", 24.0) + 0.3 * c["sheer"]) + c["sheer"]) if not flow else c["sheer"]
        masks["obstacle_lines"].append({"id": c["id"], "label": e.get("label", c["id"]), "line": line, "passes": pass_points, "reach": 450.0,
                                        "s": s[::5, ::5], "t": t[::5, ::5], "low": -(apron_w + 25.0), "high": top + 25.0,
                                        "pass_radius": e.get("pass_width", 90.0) * 1.6 + c["pass_run"] + 40.0})
    masks["step_lines"] = report


def open_ground(x, z, masks):
    """Where the plains are plain: not a pad, dune, ice, crater, canyon, mesa,
    lava or any other landform with a surface of its own."""
    keep = np.ones(x.shape, dtype=np.float32)
    for zone in ZONES.values():
        keep *= smoothstep(zone["flat_radius"] * 1.3, zone["flat_radius"] * 2.6, dist(x, z, zone["centre"]))
    keep *= 1.0 - np.clip(masks["dunes"] + masks["ice"] + masks["mound"] + masks["mesa_body"] + masks["talus"] + masks["lava"] + masks["yardang_field"]
                          + masks["glacier"] + masks["sand_sheet"] + masks["ripples"] + masks["frost_hollow"] + masks["chaos"] + masks["inverted"]
                          + masks["inverted_side"] + masks["river_floor"] + masks["channels"] + masks["kit_clear"], 0.0, 1.0)
    keep *= smoothstep(1.08, 1.3, masks["crater_d"]) * smoothstep(40.0, 160.0, masks["canyon_u"])
    keep *= 1.0 - np.clip(masks["ejecta"] * 4.0, 0.0, 1.0)   # the crater's blanket is broken ground of its own
    keep *= 1.0 - smoothstep(HALF - 760.0, HALF - 600.0, np.maximum(-x, z) + 160.0 * masks["large"])
    return box_blur(keep, 4, 1)


def add_ledges(h, x, z, masks, medium):
    """Broken ground: low ledges where hard beds and old lava lobes end, a
    metre or four high, each a gentle back slope up to a steep face. They
    wander, fade out in places (the ways through) and lie closer together
    further from home, so a straight line always meets a choice."""
    keep = open_ground(x, z, masks)
    masks["open_ground"] = keep
    home = dist(x, z, HOME["centre"])
    total = np.zeros_like(h)
    faces = np.zeros_like(h)
    for index, (k_low, k_high, levels, far) in enumerate(((0.0022, 0.011, 1.5, 0.0), (0.008, 0.028, 1.4, 1.0))):
        v = spectral_noise(3.0, SEED + 200 + index, k_low=k_low, k_high=k_high) * levels * (1.0 + 0.7 * smoothstep(1600.0, 3000.0, home))
        gz, gx = np.gradient(v, SPACING)
        steep = np.clip(3.2 * np.sqrt(gx * gx + gz * gz), 0.004, 0.5)   # so every face is about 3 m across, however gentle the field
        f = v - np.floor(v)
        riser = smoothstep(1.0 - steep, 1.0, f)
        gaps = smoothstep(-0.35, 0.2, spectral_noise(3.0, SEED + 210 + index, k_low=0.004, k_high=0.02))
        tall = 2.3 + 1.1 * np.roll(medium, (400 + 90 * index, 250), (0, 1)).clip(-1.0, 1.5)
        amount = keep * gaps * (1.0 if far == 0.0 else smoothstep(900.0, 1500.0, home))
        total += amount * tall * (riser - f)
        faces = np.maximum(faces, amount * (riser > 0.05) * (riser < 0.95))
    h += total
    masks["ledges"] = faces


def plan_minor_cracks(masks, plans, block):
    """Small cracks in the open ground, a few metres wide and deep, running
    with the fissures' trend: jump one, or walk to its end. More of them
    towards the east, where the ground has pulled apart most."""
    rng = np.random.default_rng(SEED + 220)
    trend = np.array(FISSURES[0]["to"]) - np.array(FISSURES[0]["from"]); trend = trend / np.linalg.norm(trend)
    placed = []
    for _ in range(4000):
        if len(placed) >= MINOR_CRACKS:
            break
        cx = rng.uniform(-2300.0, 2900.0); cz = rng.uniform(-1700.0, 2300.0)
        if rng.random() > 0.25 + 0.75 * smoothstep(-2300.0, 2400.0, cx):
            continue
        j = int((cz + HALF) / SPACING); i = int((cx + HALF) / SPACING)
        if masks["open_ground"][j, i] < 0.9 or math.hypot(cx - HOME["centre"][0], cz - HOME["centre"][1]) < 420.0:
            continue
        if any(math.hypot(cx - px, cz - pz) < 260.0 for px, pz in placed):
            continue
        placed.append((cx, cz))
        length = rng.uniform(90.0, 260.0)
        a = np.array([cx, cz]) - trend * length * 0.5
        heading = math.atan2(trend[1], trend[0]) + rng.normal(0.0, 0.12)
        line = wander(a, heading, length, rng, step=6.0, turn=0.05)
        n = len(line)
        t = np.linspace(0.0, 1.0, n)
        taper = np.sin(np.pi * t) ** 0.6
        half_width = 0.6 + rng.uniform(1.3, 2.4) * taper
        depth = rng.uniform(3.0, 5.0) * taper
        d, tt, _ = polyline_field(line, 30.0, t, step=1)
        width_at = np.interp(tt, t, half_width)
        block |= (d < width_at + 5.0) & (np.interp(tt, t, depth) > 1.5)
        plans.append({"f": {"id": "crack", "half_width": float(half_width.max()), "depth": float(depth.max()), "bridge": None}, "line": line, "t": t,
                      "half_width": half_width, "depth": depth, "length": length, "d": d, "tt": tt, "width_at": width_at, "wall_run": 1.5})
    masks["minor_cracks"] = [[round(px, 1), round(pz, 1)] for px, pz in placed]


# ---------- the whole region ----------

def build_heights():
    x, z = grid()
    large = spectral_noise(3.6, SEED, k_high=0.012)
    medium = spectral_noise(3.0, SEED + 1, k_low=0.006, k_high=0.06)
    small = spectral_noise(2.2, SEED + 2, k_low=0.05)
    h = 30.0 * large + 2.6 * medium + 0.22 * small + 0.012 * z   # the land falls gently north, to the canyon
    lobes_field = spectral_noise(3.8, SEED + 30, k_high=0.008)
    ragged_field = spectral_noise(3.0, SEED + 31, k_low=0.006, k_high=0.035)

    def edge_warp(shift, lobes=0.35, ragged=0.13):
        """How far a zone's edge is pushed in or out here (in zone radii)."""
        return lobes * np.roll(lobes_field, (shift, shift * 2), (0, 1)) + ragged * np.roll(ragged_field, (shift * 3, shift), (0, 1))

    fine = 2.6 * medium + 0.22 * small
    masks = {"noise": small, "large": large, "medium": medium}
    add_canyon(h, x, z, masks, medium); lap("add_canyon")
    add_big_crater(h, x, z, masks, medium, lobes_field, ragged_field); lap("add_big_crater")

    # The mound: layered, terraced, like a small Mount Sharp.
    mangle = np.arctan2(z - MOUND["centre"][1], x - MOUND["centre"][0])
    lobes = 1.0 + 0.16 * np.sin(mangle * 3.0 + 0.7) + 0.09 * np.sin(mangle * 7.0 + 2.1) + 0.08 * medium
    md = dist(x, z, MOUND["centre"]) / (MOUND["radius"] * lobes)
    rise = MOUND["height"] * np.clip(1.0 - md, 0.0, 1.0) ** 1.15 * (1.0 + 0.06 * medium)
    masks["mound"] = (md < 1.0).astype(float)
    step = landform("mound").get("terrace", 11.0)
    terraces = np.floor(rise / step) * step
    h += 0.35 * rise + 0.65 * (terraces + 4.0 * smoothstep(0.55, 1.0, (rise % step) / step))   # benches and steps

    add_mesas(h, x, z, masks, medium, edge_warp); lap("add_mesas")
    add_wrinkle_ridges(h, x, z, masks, medium); lap("add_wrinkle_ridges")
    add_step_lines(h, x, z, masks, medium, lobes_field, ragged_field); lap("add_step_lines")
    add_dunes(h, x, z, masks, medium, edge_warp, lobes_field); lap("add_dunes")
    add_ice_ground(h, x, z, masks, medium, small, edge_warp); lap("add_ice_ground")
    add_chaos_blocks(h, x, z, masks, medium)
    add_lava_plain(h, x, z, masks, medium, small, lobes_field, ragged_field); lap("add_lava_plain")
    add_yardangs(h, x, z, masks, medium)
    add_ripple_belts(h, x, z, masks, medium)
    add_buried_glacier(h, x, z, masks, medium)
    add_inverted_channels(h, x, z, masks, medium); lap("yardangs, ripples, glacier, raised riverbeds")

    # Hills framing the west and south edges, ragged rather than square. The
    # canyon's far wall is the northern edge; in the east the lava plain runs on.
    ring = np.maximum(-x, z) + 160.0 * large
    h += (240.0 + 80.0 * large) * smoothstep(HALF - 650.0, HALF - 80.0, ring)

    trunk_floor = carve_river(h, x, z, masks, medium, lobes_field)
    add_valley_network(h, x, z, masks, trunk_floor); lap("add_valley_network")
    add_home_ground(h, x, z, masks, medium); lap("add_home_ground")
    add_ledges(h, x, z, masks, medium); lap("add_ledges")

    # Small craters of every age, except on the landing zones, the mound, the
    # mesas and the dunes.
    keep = [(ZONES[k]["centre"][0], ZONES[k]["centre"][1], ZONES[k]["flat_radius"] * 2.2) for k in ZONES]
    keep.append((MOUND["centre"][0], MOUND["centre"][1], MOUND["radius"]))
    keep += [(mx, mz, mr * 1.3) for mx, mz, mr, mh, _ in masks["mesa_list"]]
    keep.append((DUNES[0], DUNES[1], DUNES_RADIUS * 1.2))
    keep.append((YARDANGS["centre"][0], YARDANGS["centre"][1], YARDANGS["length"] * 0.55))
    keep.append((GLACIER["from"][0] + GLACIER["flow"][0] * 200.0, GLACIER["from"][1] + GLACIER["flow"][1] * 200.0, 260.0))
    keep.append((CHAOS_BLOCKS[0], CHAOS_BLOCKS[1], CHAOS_BLOCKS[2]))
    keep.append((FRESH_CRATER[0], FRESH_CRATER[1], FRESH_CRATER[2] * 1.5))
    keep += [(HOME_GROUND[k][0], HOME_GROUND[k][1], 60.0) for k in ("outcrop", "pit")]
    keep.append((HOME_GROUND["frost_hollow"][0], HOME_GROUND["frost_hollow"][1], 150.0))
    keep.append((-1400.0, 95.0, 380.0))   # the cracked sliver
    add_small_craters(h, x, z, np.random.default_rng(SEED + 9), 900, keep, masks)
    # One big fresh crater in the south: a sharp rim, a rocky blanket, a bowl you can walk into and out of.
    add_crater(h, x, z, FRESH_CRATER[0], FRESH_CRATER[1], FRESH_CRATER[2], 0.04, np.random.default_rng(kind_seed("fresh_crater", SEED + 10)))
    masks["craters"].append((FRESH_CRATER[0], FRESH_CRATER[1], FRESH_CRATER[2], 0.04))
    # Craters added in the land editor ("impact"): each its own seed, so adding one reshuffles nothing.
    for e in landforms("impact"):
        add_crater(h, x, z, e["centre"][0], e["centre"][1], e["radius"], e.get("age", 0.3), np.random.default_rng(seed_of(e)))
        masks["craters"].append((e["centre"][0], e["centre"][1], e["radius"], e.get("age", 0.3)))
    add_platy_belt(h, x, z, masks, medium); lap("add_platy_belt")

    # Landing zones: a level pad that blends into the land around it.
    for zone in ZONES.values():
        zd = dist(x, z, zone["centre"])
        r = zone["flat_radius"]
        j = int((zone["centre"][1] + HALF) / SPACING); i = int((zone["centre"][0] + HALF) / SPACING)
        level = float(h[j - 20:j + 20, i - 20:i + 20].mean())
        blend = smoothstep(r, r * zone.get("blend", 3.2), zd)
        detail = smoothstep(r, r * 1.5, zd)
        # Exactly level inside the flat radius; the big shapes ease in over
        # the blend, the small bumps come back soon after the edge.
        h = level + (h - level) * blend + fine * (np.maximum(detail, blend) - blend)
        zone["height"] = level
    return h, masks


def carve_river(h, x, z, masks, medium, lobes_field):
    """The valley network's trunk: cut the old river's valley (its floor always running downhill, through the
    crater rim) and lay its delta on the crater floor."""
    dist_to, t, _ = polyline_field(RIVER_POINTS, 520.0, RIVER_T, step=2)
    # The floor along the course: below the ground by the valley's depth,
    # never rising downstream.
    depth = 16.0 + 10.0 * np.exp(-((RIVER_T - RIVER_WIDE_AT) / 0.08) ** 2)
    depth = np.where(RIVER_T > 1.0, np.maximum(2.0, depth * (1.25 - RIVER_T) * 4.0), depth)
    floor = np.empty(RIVER_T.size)
    for i, (px, pz) in enumerate(RIVER_POINTS):
        j = int(np.clip((pz + HALF) / SPACING, 0, N - 1)); k = int(np.clip((px + HALF) / SPACING, 0, N - 1))
        floor[i] = h[j, k] - depth[i]
        if i > 0:
            floor[i] = min(floor[i], floor[i - 1] - 0.02)
    floor_at = np.interp(t, RIVER_T, floor)
    depth_at = np.interp(t, RIVER_T, depth)
    half_width = 32.0 + 22.0 * np.exp(-((t - RIVER_WIDE_AT) / 0.07) ** 2) + 3.0 * medium   # about 55 m each side at the zone: cliffs close by
    half_width = np.where(t > 1.0, half_width * (1.0 + (t - 1.0) * 3.0), half_width)
    wall_run = 18.0 + 6.0 * medium
    s = np.maximum(0.0, dist_to - half_width)
    # Walls with a bench half way up, then on up at a steep slope wherever the
    # cut runs deeper than the valley (through the rim).
    rise = np.where(s < wall_run, depth_at * (0.55 * smoothstep(0.0, 0.45, s / wall_run) + 0.45 * smoothstep(0.6, 1.0, s / wall_run)),
                    depth_at + (s - wall_run) * 1.6)
    target = floor_at + rise + 0.5 * np.abs(medium) * (s > 0)
    # Cut only as far as the breach in the rim: inside the crater the river
    # dropped its load instead (the delta, below).
    river = (t < 1.02) & (dist_to < half_width + wall_run + 400.0)
    h[river] = np.minimum(h[river], target[river])
    masks["river_floor"] = ((dist_to < half_width + 2.0) & (t < 1.02)).astype(float)
    # The delta: a flat-topped fan of layered sediment on the crater floor,
    # with a steep front, lobes and old distributary channels.
    rim = RIVER_POINTS[360]; apex = RIVER_POINTS[-1]
    inward = (apex - rim) / np.linalg.norm(apex - rim)
    rx = x - rim[0]; rz = z - rim[1]
    r = np.sqrt(rx * rx + rz * rz)
    ang = np.arctan2(rx * inward[1] - rz * inward[0], rx * inward[0] + rz * inward[1])
    reach = 640.0 * (1.0 + 0.12 * np.sin(ang * 7.0 + 0.9) + 0.06 * np.sin(ang * 17.0)) * (1.0 + 0.08 * lobes_field)
    fan = (1.0 - smoothstep(0.86, 1.0, r / reach)) * (1.0 - smoothstep(0.7, 1.0, np.abs(ang) / 0.95)) * smoothstep(0.1, 0.3, r / reach)
    inside = masks["crater_d"] < 0.95
    channels = 1.6 * smoothstep(0.82, 0.98, np.abs(np.sin(ang * 9.0 + 1.5 * medium)))
    lift = np.where(inside, fan * (12.0 - channels), 0.0)
    h += lift
    masks["delta"] = (lift > 3.0).astype(float)
    return floor


# ---------- rover routes ----------

ROUTE_CELL = 10.0     # metres, as scripts/rover_route.gd
ROUTE_MAX_GRADE = 0.4  # rise over run, about 22 degrees: steeper than rover_route.gd's "dear" (0.36), well short of its cliff (0.8)


# ---------- caves and the lava tube (stage 5) ----------
# A heightmap can't open into a cave, so here the generator only shapes the
# ground round each way in (the lava tube's ramp pit and skylights, a notch
# at a cave's mouth) and writes each cave's centreline to region.json
# "caves". The game (scripts/caves.gd) builds the tunnels, sinks the
# ground under them and lays a copy of it back over the top.
_caves = LAYOUT["caves"]
LAVA_TUBE = dict(_caves["lava_tube"])
LAVA_TUBE["course"] = [_xz(p) for p in LAVA_TUBE["course"]]
# Skylights: how far along, radius, which side of the passage the fallen roof lies.
LAVA_TUBE["skylights"] = [(s["along"], s["radius"], s["side"]) for s in LAVA_TUBE["skylights"]]
# The deep (docs/terrain-design.md §3): past the upper tube's upstream end the passage goes on, down three
# steep pitches (old lava falls: rope work, on foot only) to a lower level and the heart's chamber, about
# 150 m under the plain. It never crosses itself on the map, so a place on the map is one place underground.
DEEP = dict(_caves["deep"])
DEEP["course"] = [_xz(p) for p in DEEP["course"]]
DEEP["pitches"] = [(p["after"], p["drop"]) for p in DEEP["pitches"]]   # just past this course point, this far down
DEEP["sizes"] = {k: tuple(v) for k, v in DEEP["sizes"].items()}
# The maze (15 Nov): the tube braids into lanes split by walls of rock, with chokes (dead ends), gaps
# and pits. from/to/at are point numbers (2 m apart) from the mouth, or from where the deep begins when
# "deep" is set; side is across the passage (-1 the left wall, 1 the right, looking in).
MAZE = []
for _mz in _caves["maze"]:
    _e = dict(_mz)
    _e["walls"] = [(w["from"], w["to"], w["side"], [tuple(g) for g in w["gaps"]]) for w in _mz["walls"]]
    _e["chokes"] = [(c["at"], c["from_side"], c["to_side"]) for c in _mz["chokes"]]
    _e["pits"] = [(q["at"], q["side"], q["radius"], q["depth"]) for q in _mz["pits"]]
    MAZE.append(_e)
# Natural caves, found on foot: where you walk up from, the way in, and size.
NATURAL_CAVES = [dict(c, approach=_xz(c["approach"]), heading=_xz(c["heading"])) for c in _caves["natural"]]
CAVE_COVER = _caves["cover"]   # ground kept at least this far over a cave's roof
CAVE_STEP = _caves["step"]     # centreline points


def resample(points, step):
    pts = np.array(points, dtype=float)
    s = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
    t = np.linspace(0.0, s[-1], int(s[-1] / step) + 1)
    return np.stack([np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])], 1)


def run_filter(a, k, fn):
    return np.array([fn(a[max(0, i - k):i + k + 1]) for i in range(len(a))])


def line_frames(p):
    t = np.gradient(p, axis=0)
    t /= np.linalg.norm(t, axis=1)[:, None]
    return t, np.stack([-t[:, 1], t[:, 0]], 1)


def ground_across(h, p, n, half):
    """The lowest and mean ground across a line, half each side."""
    offs = np.arange(-half, half + 0.01, 1.5)
    vals = np.array([[sample(h, q[0] + o * m[0], q[1] + o * m[1]) for o in offs] for q, m in zip(p, n)])
    return vals.min(axis=1), vals.mean(axis=1)


def local_frame(x, z, origin, axis, reach):
    """A window round origin, and each point's distance along axis (u) and to the side of it (v)."""
    i0 = max(0, int((origin[0] - reach + HALF) / SPACING)); i1 = min(N, int((origin[0] + reach + HALF) / SPACING) + 1)
    j0 = max(0, int((origin[1] - reach + HALF) / SPACING)); j1 = min(N, int((origin[1] + reach + HALF) / SPACING) + 1)
    win = (slice(j0, j1), slice(i0, i1))
    dx = x[win] - origin[0]; dz = z[win] - origin[1]
    return win, dx * axis[0] + dz * axis[1], np.abs(-dx * axis[1] + dz * axis[0])


def add_lava_tube(h, x, z, masks):
    """The tube's course and floor (level-ish, CAVE_COVER under the land at
    least), the ramp pit down to its mouth and the skylights over it."""
    c = LAVA_TUBE
    p = resample(c["course"], CAVE_STEP)
    for _ in range(3):   # ease the corners, keeping the ends
        p[1:-1] = (p[:-2] + 2.0 * p[1:-1] + p[2:]) / 4.0
    t, n = line_frames(p)
    hw, ht = c["half_width"], c["height"]
    low, mean = ground_across(h, p, n, hw + 2.0)
    limit = low - ht - CAVE_COVER
    floor = np.minimum(run_filter(mean, 40, np.mean) - c["depth"], limit)
    floor = run_filter(run_filter(floor, 12, np.min), 12, np.mean)
    floor = np.minimum(run_filter(np.minimum(floor, limit), 3, np.mean), limit)
    grade = float(np.abs(np.diff(floor)).max() / CAVE_STEP)
    # The ramp pit: fallen roof, a straight ramp from the land down to the
    # mouth, level for its last stretch and wide at the bottom; the land past
    # the mouth is the tube's roof and isn't touched.
    mouth, axis = p[0], t[0]
    top = sample(h, *(mouth - axis * c["ramp"]))
    win, u, v = local_frame(x, z, mouth, axis, c["ramp"] + 80.0)
    run = np.clip((-u - 14.0) / (c["ramp"] - 14.0), 0.0, 1.0)
    half = 14.0 - 2.0 * run   # wide enough for the route planner's 10 m cells
    cut = floor[0] + (top - floor[0]) * run + np.maximum(-u - c["ramp"], 0.0) * 0.9 + np.maximum(v - half, 0.0) * 0.9
    cut += 0.25 * masks["noise"][win] + np.maximum(u, 0.0) * 2.5   # past the mouth, a steep end wall
    h[win] = np.minimum(h[win], cut)
    masks["cave_clear"][win] = np.maximum(masks["cave_clear"][win], ((u <= 12.0) & (u > -c["ramp"] - 10.0) & (v < half + 4.0)).astype(float))
    ramp_grade = (top - floor[0]) / (c["ramp"] - 14.0)
    # Skylights: a sag where the roof has settled and a sheer pit down to the
    # roof's top (the game opens the hole in its floor and the tunnel under it).
    skylights = []
    for along, r, side in c["skylights"]:
        k = int(along * (len(p) - 1))
        win, u, v = local_frame(x, z, p[k], t[k], r * 4.0)
        d = np.hypot(u, v)
        shelf = floor[k] + ht * 1.12 + 1.1   # over the game's roof, however it's roughened
        sag = h[win] - 1.8 * (1.0 - smoothstep(r, r * 2.8, d))
        h[win] = np.where(h[win] > shelf, np.maximum(sag, shelf), sag)   # never below the roof
        h[win] = np.minimum(h[win], shelf + np.maximum(d - r - 2.5, 0.0) * 3.5)
        masks["cave_clear"][win] = np.maximum(masks["cave_clear"][win], (d < r * 2.8).astype(float))
        skylights.append({"position": [round(float(p[k][0]), 2), round(float(p[k][1]), 2)], "radius": r,
                          "floor": round(float(floor[k]), 2), "rubble_side": side})
    print(f"  lava tube: {len(p) * CAVE_STEP:.0f} m, floor {floor.min():.1f}..{floor.max():.1f} m (worst grade {grade:.3f}), "
          f"ramp grade {ramp_grade:.2f}, cover at least {float((low - floor - ht).min()):.1f} m")
    k_mid = len(p) // 2
    n_upper = len(p)
    # The deep: on from the upper end, down the pitches to the heart's chamber.
    d = DEEP
    control = np.array([p[-1]] + d["course"], dtype=float)
    q = resample(control, CAVE_STEP)
    for _ in range(4):
        q[1:-1] = (q[:-2] + 2.0 * q[1:-1] + q[2:]) / 4.0
    q = q[1:]
    along = (np.arange(len(q)) + 1) * CAVE_STEP
    marks = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(control, axis=0).T))])
    deep_floor = floor[-1] - d["grade"] * along
    size = np.tile(np.array(d["sizes"]["mid"]), (len(q), 1))
    pitches = []
    for index, (at, drop) in enumerate(d["pitches"]):
        s0 = marks[at + 1] + 4.0
        fall = smoothstep(s0, s0 + d["pitch_run"], along)
        deep_floor = deep_floor - drop * fall
        on_pitch = (along > s0 - 6.0) & (along < s0 + d["pitch_run"] + 6.0)
        size[on_pitch] = d["sizes"]["pitch"]
        if index == len(d["pitches"]) - 1:
            size[along >= s0 + d["pitch_run"] + 6.0] = d["sizes"]["lower"]
        k0 = int(np.searchsorted(along, s0)); k1 = int(np.searchsorted(along, s0 + d["pitch_run"]))
        pitches.append((k0, k1, drop))
    size[along > along[-1] - d["chamber"]] = d["sizes"]["chamber"]
    for column in range(2):   # ease from one size to the next
        size[:, column] = run_filter(size[:, column], 6, np.mean)
    size[:8] = np.linspace(0.0, 1.0, 8)[:, None] * size[:8] + np.linspace(1.0, 0.0, 8)[:, None] * np.array([hw, ht])
    sizes = np.concatenate([np.tile(np.array([hw, ht]), (n_upper, 1)), size])
    surface = np.array([sample(h, v[0], v[1]) for v in q])
    print(f"  the deep: {along[-1]:.0f} m more, {len(pitches)} pitches, its floor {float((surface - deep_floor).max()):.0f} m under the land at the heart "
          f"(steepest {float(np.abs(np.diff(deep_floor)).max() / CAVE_STEP):.2f})")
    p_all = np.concatenate([p, q]); floor_all = np.concatenate([floor, deep_floor])
    # The maze: wide chambers, the walls that split them into lanes, chokes and pits.
    for chamber in MAZE:
        base = n_upper if chamber.get("deep") else 0
        sizes[base + chamber["from"]:base + chamber["to"] + 1] = (chamber["half"], chamber["height"])
    for column in range(2):
        sizes[:, column] = run_filter(sizes[:, column], 7, np.mean)
    sizes[:8] = (hw, ht)   # the mouth keeps its size, for the portal
    profile = [[round(float(a), 2), round(float(b), 2)] for a, b in sizes]
    _, normals = line_frames(p_all)
    walls = []; pits = []; places = []

    def across(k, side):
        return p_all[k] + normals[k] * side * sizes[k, 0]

    for chamber in MAZE:
        base = n_upper if chamber.get("deep") else 0
        mid = base + (chamber["from"] + chamber["to"]) // 2
        places.append({"name": chamber["name"], "from": base + chamber["from"], "to": base + chamber["to"],
                       "position": [round(float(p_all[mid][0]), 1), round(float(p_all[mid][1]), 1)]})
        for index, (k0, k1, side, gaps) in enumerate(chamber["walls"]):
            piece = []
            for k in range(base + k0, base + k1 + 1):
                if any(base + g0 <= k <= base + g1 for g0, g1 in gaps):
                    if len(piece) > 3:
                        walls.append({"points": piece, "thick": 4.5})
                    piece = []
                    continue
                v = across(k, side + 0.05 * math.sin(k * 0.21 + index * 2.0))
                piece.append([round(float(v[0]), 2), round(float(v[1]), 2)])
            if len(piece) > 3:
                walls.append({"points": piece, "thick": 4.5})
        for k, a, b in chamber["chokes"]:
            k += base
            steps = max(3, int(abs(b - a) * sizes[k, 0] / 2.0))
            walls.append({"points": [[round(float(v[0]), 2), round(float(v[1]), 2)] for v in (across(k, a + (b - a) * i / steps) for i in range(steps + 1))],
                          "thick": 5.5, "choke": True})
        for k, side, radius, depth in chamber["pits"]:
            v = across(base + k, side)
            pits.append({"position": [round(float(v[0]), 2), round(float(v[1]), 2)], "radius": radius, "depth": depth})
    # How the rock looks along the way: frost at the cold trap (the upper tube's end), and the deep's
    # own rock, more so further down, most of all in the heart's chamber.
    index = np.arange(len(p_all))
    frost = smoothstep(n_upper - 120.0, n_upper - 70.0, index) * (1.0 - smoothstep(n_upper + 2.0, n_upper + 16.0, index))
    deepness = 0.4 * smoothstep(n_upper + 20.0, n_upper + 60.0, index) + 0.15 * smoothstep(n_upper + 120.0, n_upper + 150.0, index) \
        + 0.15 * smoothstep(n_upper + 200.0, n_upper + 240.0, index) + 0.3 * smoothstep(len(p_all) - 44.0, len(p_all) - 20.0, index)
    tint = [[round(float(a), 2), round(float(b), 2)] for a, b in zip(frost, deepness)]
    # The way on into the deep is shut at first: a plug of fallen roof past the cold trap. A
    # marsquake late in the story shakes it loose (the user, 15 Nov: quakes and storms reveal places).
    plug = n_upper + 12
    gates = [{"id": "deep_plug", "opens": "marsquake", "point": plug, "thick": 7.0,
              "points": [[round(float(v[0]), 2), round(float(v[1]), 2)] for v in (across(plug, -1.35 + 2.7 * i / 12) for i in range(13))]}]
    print(f"  the maze: {len(MAZE)} chambers, {len(walls)} walls and chokes, {len(pits)} pits, {len(gates)} gate")
    deep = {"from": n_upper,
            "pitches": [{"top": n_upper + k0, "foot": n_upper + k1, "drop": drop,
                         "anchor": [round(float(q[max(k0 - 2, 0)][0]), 2), round(float(q[max(k0 - 2, 0)][1]), 2), round(float(deep_floor[max(k0 - 2, 0)]), 2)]} for k0, k1, drop in pitches],
            "cold_trap": n_upper - 30,
            "heart": {"point": len(p_all) - int(d["chamber"] / CAVE_STEP / 2), "position": [round(float(q[-1][0]), 1), round(float(q[-1][1]), 1)],
                      "floor": round(float(deep_floor[-1]), 1), "depth": round(float(surface[-1] - deep_floor[-1]), 1)}}
    foot = mouth - axis * 25.0
    EXTRA_ROUTE_TARGETS.append(("lava tube", float(foot[0]), float(foot[1]), 15.0))
    return {"id": c["id"], "name": c["name"], "kind": c["kind"], "half_width": hw, "height": ht, "seed": SEED + 300,
            "points": [[round(float(v[0]), 2), round(float(v[1]), 2), round(float(f), 2)] for v, f in zip(p_all, floor_all)],
            "profile": profile, "deep": deep, "walls": walls, "pits": pits, "tint": tint, "places": places, "gates": gates,
            # For the systems that make it risky (later sections): where the floor is ice, where roof has fallen and may again.
            "hazards": [{"kind": "ice_floor", "from": n_upper - 90, "to": n_upper + 6}]
            + [{"kind": "rockfall", "point": n_upper + k0} for k0, _, _ in pitches]
            + [{"kind": "pit", "position": pit["position"], "depth": pit["depth"]} for pit in pits],
            "mouth": [round(float(mouth[0]), 2), round(float(mouth[1]), 2)],
            "ramp_top": [round(float(v_), 2) for v_ in mouth - axis * c["ramp"]],
            "skylights": skylights,
            "finds": [{"id": "fresh_basalt", "point": k_mid // 2}, {"id": "cave_climate", "point": int(len(p) * 0.6)},
                      {"id": "mineral_crust", "point": int(len(p) * 0.8)}, {"id": "cave_ice", "point": len(p) - 4}]}


def add_natural_cave(h, x, z, masks, c, index):
    """A small cave on foot: a notch cut level from where you walk up to the
    point where the land stands well over the roof (the mouth), then the
    cave runs on under it."""
    a = np.array(c["heading"], dtype=float); a /= np.linalg.norm(a)
    side = np.array([-a[1], a[0]])
    hw, ht = c["half_width"], c["height"]
    start = np.array(c["approach"], dtype=float)
    f0 = sample(h, *start)
    reach = 0.0
    while reach < 150.0:
        q = start + a * reach
        if min(sample(h, *(q + side * o)) for o in np.arange(-hw - 1.5, hw + 1.6, 1.5)) >= f0 + ht + 2.0:
            break
        reach += 1.0
    mouth = start + a * reach
    win, u, v = local_frame(x, z, mouth, a, reach + 40.0)
    cut = f0 + np.maximum(-u - reach, 0.0) * 0.5 + np.maximum(v - (hw + 2.5), 0.0) * 1.4
    h[win] = np.minimum(h[win], np.where(u <= 0.0, cut, np.inf))
    masks["cave_clear"][win] = np.maximum(masks["cave_clear"][win], ((u <= 0.0) & (u > -reach - 4.0) & (v < hw + 4.0)).astype(float))
    s = np.arange(0.0, c["length"] + 0.01, CAVE_STEP)
    p = mouth[None, :] + a[None, :] * s[:, None] + side[None, :] * (1.6 * np.sin(s / 9.0 + index * 2.0) * smoothstep(0.0, 12.0, s))[:, None]
    floor = f0 + c["grade"] * s
    _, n = line_frames(p)
    low, _ = ground_across(h, p, n, hw + 1.5)
    cover = low - floor - ht
    print(f"  {c['id']}: notch {reach:.0f} m, floor {f0:.1f} m, cover past the mouth at least {float(cover[3:].min()):.1f} m")
    return {"id": c["id"], "name": c["name"], "kind": c["kind"], "half_width": hw, "height": ht, "seed": SEED + 310 + index,
            "points": [[round(float(q[0]), 2), round(float(q[1]), 2), round(float(f), 2)] for q, f in zip(p, floor)],
            "mouth": [round(float(mouth[0]), 2), round(float(mouth[1]), 2)], "skylights": [],
            "finds": ([{"id": "layered_sediments", "point": len(p) // 3}, {"id": "mineral_crust", "point": len(p) - 3}]
                      if c["kind"] == "cave" else [{"id": "cave_ice", "point": len(p) - 2}])}


def add_caves(h, x, z, masks):
    masks["cave_clear"] = np.zeros_like(h)
    caves = [add_lava_tube(h, x, z, masks)]
    caves += [add_natural_cave(h, x, z, masks, c, i) for i, c in enumerate(NATURAL_CAVES)]
    return caves


def route_targets():
    """Every major destination: (name, x, z, radius)."""
    targets = [(k, z["centre"][0], z["centre"][1], 40.0) for k, z in ZONES.items()]
    wind = np.array(DUNE_WIND)
    edge = np.array(DUNES) - wind * DUNES_RADIUS * 1.8 * 0.9
    targets += [("dune field", float(edge[0]), float(edge[1]), 60.0), ("ice fields", -1500.0, -1000.0, 60.0),
                ("layered mound", 1242.0, -452.0, 50.0), ("canyon floor", -1200.0, -2400.0, 60.0),
                ("west mesa top", MESAS[1][0], MESAS[1][1], 60.0), ("east mesa top", MESAS[4][0], MESAS[4][1], 60.0)]
    targets += [(name, x, z, r) for name, x, z, r in EXTRA_ROUTE_TARGETS]
    return targets


EXTRA_ROUTE_TARGETS = []   # the foot of the tube's ramp pit is added once the tube is laid (caves are on foot)


def route_grid(h, masks):
    """Heights every ROUTE_CELL and where a rover can go: no steeper than
    ROUTE_MAX_GRADE to any neighbour, not in the dunes."""
    step = int(ROUTE_CELL / SPACING)
    g = h[::step, ::step]
    grade = np.zeros_like(g)
    grade[:, :-1] = np.maximum(grade[:, :-1], np.abs(np.diff(g, axis=1)) / ROUTE_CELL)
    grade[:, 1:] = np.maximum(grade[:, 1:], np.abs(np.diff(g, axis=1)) / ROUTE_CELL)
    grade[:-1, :] = np.maximum(grade[:-1, :], np.abs(np.diff(g, axis=0)) / ROUTE_CELL)
    grade[1:, :] = np.maximum(grade[1:, :], np.abs(np.diff(g, axis=0)) / ROUTE_CELL)
    ok = (grade <= ROUTE_MAX_GRADE) & (masks["dunes"][::step, ::step] < 0.5)
    if "route_block" in masks:
        ok &= ~box_blur(masks["route_block"].astype(np.float32), 2, 1)[::step, ::step].astype(bool)
    return ok, step


def flood(ok, seeds):
    """Every cell reachable from the seed cells through ok cells (8-way)."""
    reach = seeds & ok
    while True:
        grow = reach.copy()
        grow[1:, :] |= reach[:-1, :]; grow[:-1, :] |= reach[1:, :]
        grow[:, 1:] |= reach[:, :-1]; grow[:, :-1] |= reach[:, 1:]
        grow[1:, 1:] |= reach[:-1, :-1]; grow[:-1, :-1] |= reach[1:, 1:]
        grow[1:, :-1] |= reach[:-1, 1:]; grow[:-1, 1:] |= reach[1:, :-1]
        grow &= ok
        if (grow == reach).all():
            return reach
        reach = grow


def disc_cells(shape, step, x, z, r):
    n = shape[0]
    coords = np.arange(n) * SPACING * step - HALF
    return ((coords[None, :] - x) ** 2 + (coords[:, None] - z) ** 2) <= r * r


def carve_ramp(h, a, b, width=14.0):
    """A graded track from a to b: the ground eased to a straight grade
    between them (cut and fill), blended into the sides."""
    ha = sample(h, a[0], a[1]); hb = sample(h, b[0], b[1])
    line = np.array([a, b], dtype=float)
    d, t, _ = polyline_field(line, width * 3.0, step=1)
    near = d < width * 3.0
    track = ha + (hb - ha) * np.clip(t[near], 0.0, 1.0)
    w = 1.0 - smoothstep(width * 0.5, width * 3.0, d[near])
    h[near] = h[near] * (1.0 - w) + track * w


def check_routes(h, masks, fix=True):
    """Every landing zone must reach every destination by rover. Where one
    can't, the nearest gap between what it can reach and the destination is
    bridged with a graded track, and the check runs again. Returns a report."""
    report = []
    for attempt in range(4):
        ok, step = route_grid(h, masks)
        report = []
        fixed = False
        tried = set()
        targets = route_targets()
        for zone_name, zone in ZONES.items():
            reach = flood(ok, disc_cells(ok.shape, step, zone["centre"][0], zone["centre"][1], 40.0))
            for name, x, z, r in targets:
                if name == zone_name:
                    continue
                goal = disc_cells(ok.shape, step, x, z, r)
                good = bool((reach & goal).any())
                if not good and fix and attempt < 3 and name not in tried:
                    tried.add(name)
                    # Bridge the closest gap between where it can get and where it must.
                    pa = None
                    there = flood(ok | goal, goal)
                    ai = np.argwhere(reach); bi = np.argwhere(there)
                    if len(ai) and len(bi):
                        bi = bi[:: max(1, len(bi) // 4000)]
                        best = None
                        for chunk in range(0, len(ai), 4000):
                            part = ai[chunk:chunk + 4000]
                            dd = ((part[:, None, :] - bi[None, :, :]) ** 2).sum(axis=2)
                            k = np.unravel_index(np.argmin(dd), dd.shape)
                            if best is None or dd[k] < best[0]:
                                best = (dd[k], part[k[0]], bi[k[1]])
                        pa = (best[1][1] * SPACING * step - HALF, best[1][0] * SPACING * step - HALF)
                        pb = (best[2][1] * SPACING * step - HALF, best[2][0] * SPACING * step - HALF)
                        rise = abs(sample(h, pb[0], pb[1]) - sample(h, pa[0], pa[1])) / max(math.hypot(pb[0] - pa[0], pb[1] - pa[1]), 1.0)
                        if rise > 0.3:
                            print(f"  route {zone_name} -> {name}: no graded track can bridge the gap at ({pa[0]:.0f}, {pa[1]:.0f})")
                            pa = None
                    if pa is not None and "no_grade" in masks:
                        seg = np.linspace(0.0, 1.0, 40)
                        if any(masks["no_grade"][int((pa[1] + (pb[1] - pa[1]) * u + HALF) / SPACING), int((pa[0] + (pb[0] - pa[0]) * u + HALF) / SPACING)] > 0.5 for u in seg):
                            print(f"  route {zone_name} -> {name}: the gap at ({pa[0]:.0f}, {pa[1]:.0f}) is an obstacle meant as a detour; not graded")
                            pa = None
                    if pa is not None:
                        print(f"  route {zone_name} -> {name}: bridging {math.hypot(pb[0] - pa[0], pb[1] - pa[1]):.0f} m at ({pa[0]:.0f}, {pa[1]:.0f})")
                        carve_ramp(h, pa, pb)
                        fixed = True
                report.append({"from": zone_name, "to": name, "ok": good})
        if not fixed:
            break
    if "--debug-routes" in sys.argv:
        # Where a rover can go: black closed, grey open, and what each start reaches (plains green, crater blue, both cyan).
        ok, step = route_grid(h, masks)
        img = np.zeros(ok.shape + (3,), dtype=np.uint8)
        img[ok] = (90, 90, 90)
        for name, channel in (("plains", 1), ("crater", 2)):
            reach = flood(ok, disc_cells(ok.shape, step, ZONES[name]["centre"][0], ZONES[name]["centre"][1], 40.0))
            img[..., channel][reach] = 230
        Image.fromarray(img).resize((ok.shape[1] * 2, ok.shape[0] * 2), Image.NEAREST).save(os.path.join(ROOT, ".claude_tmp", f"routes_{'fix' if fix else 'final'}.png"))
    bad = [f"{r['from']} -> {r['to']}" for r in report if not r["ok"]]
    print(f"  routes: {len(report) - len(bad)} of {len(report)} drivable" + (f"; NOT: {', '.join(bad)}" if bad else ""))
    return report


def save_heights(h):
    lo, hi = float(h.min()) - 1.0, float(h.max()) + 1.0
    q = np.clip(np.round((h - lo) / (hi - lo) * 65535.0), 0, 65535).astype("<u2")
    data = gzip.compress(q.tobytes(), compresslevel=9)
    write_file(os.path.join(OUT, "height.r16.gz"), lambda path: open(path, "wb").write(data))
    # Each zone's level as stored (after rounding to 16 bits), so its pad reads
    # exactly 0 in the game.
    for zone in ZONES.values():
        code = round((zone["height"] - lo) / (hi - lo) * 65535.0)
        zone["height"] = lo + code / 65535.0 * (hi - lo)
    return lo, hi


# ---------- ground textures ----------
# Terrain3D texture slots (the control map refers to these numbers).
DUST, BEDROCK, SAND, FROST, CLAY, GRAVEL, STRATA, TALUS, ICE, LAVA, PALE_SAND = range(11)
MATERIALS = [
    # name, base colour, dark colour, roughness, features, colour on the region map
    ("dust", (178, 126, 96), (150, 102, 78), 0.93, {"ripples": (7, 0.05), "pebbles": (500, 2, 5)}, (196, 140, 104)),
    ("bedrock", (156, 112, 88), (118, 84, 68), 0.82, {"strata": (6, 0.2), "cracks": (55, 0.012, 0.35)}, (150, 106, 84)),
    ("sand", (110, 84, 74), (82, 63, 58), 0.9, {"ripples": (13, 0.2)}, (104, 80, 70)),
    ("frost", (226, 210, 200), (190, 164, 150), 0.55, {"cracks": (34, 0.02, 0.5), "crack_colour": (150, 104, 82)}, (228, 216, 206)),
    ("clay", (198, 152, 118), (172, 126, 96), 0.88, {"cracks": (130, 0.007, 0.28)}, (214, 168, 128)),
    ("gravel", (152, 108, 86), (116, 82, 68), 0.9, {"pebbles": (2600, 3, 13)}, (166, 120, 96)),
    # Pale layered sediment, like Mount Sharp's: the mound, mesa sides, canyon walls.
    ("strata", (206, 162, 126), (176, 132, 102), 0.86, {"strata": (9, 0.22), "cracks": (40, 0.006, 0.18)}, (222, 182, 146)),
    # Angular broken rock fallen from cliffs.
    ("talus", (140, 100, 82), (104, 74, 62), 0.88, {"cracks": (420, 0.006, 0.35), "blocks": 0.35, "pebbles": (500, 2, 6)}, (132, 96, 80)),
    # Ice-rich ground: pale, fine, cracked.
    ("ice", (196, 166, 146), (170, 140, 122), 0.8, {"cracks": (60, 0.01, 0.3), "ripples": (5, 0.03)}, (190, 160, 138)),
    # Young lava: dark, ropy, cracked into slabs, only thinly dusted.
    ("lava", (104, 78, 68), (70, 54, 50), 0.78, {"cracks": (90, 0.008, 0.4), "blocks": 0.22, "ripples": (9, 0.07)}, (112, 84, 72)),
    # The ripple belts' sand: pale, coarse-grained, in small ripples on the big ones.
    ("pale_sand", (204, 164, 130), (176, 136, 106), 0.92, {"ripples": (17, 0.16), "pebbles": (900, 1, 3)}, (212, 174, 140)),
]


def material_texture(name, base, dark, rough, features, seed, n=1024):
    """A seamless ground texture for Terrain3D: albedo with height in alpha,
    and an OpenGL normal map with roughness in alpha."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    kx, kz = np.meshgrid(f, f)
    k = np.sqrt(kx * kx + kz * kz); k[0, 0] = 1.0

    def noise(beta, lo=0.0):
        a = 1.0 / np.power(k, beta / 2.0); a[0, 0] = 0.0
        if lo > 0.0:
            a *= 1.0 - np.exp(-(k / lo) ** 2)
        o = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * a))
        return (o - o.mean()) / o.std()

    coarse = noise(3.2)
    grain = noise(1.6, 0.08)
    height = 0.5 + 0.12 * coarse + 0.07 * grain
    tint = np.zeros((n, n))
    crack = None
    u = np.arange(n) / n
    uu, vv = np.meshgrid(u, u)
    if "ripples" in features:
        freq, amount = features["ripples"]
        wave = np.sin((uu * 2 + vv) * math.tau * freq + 1.4 * coarse)
        height += amount * np.sign(wave) * np.abs(wave) ** 0.6
    if "strata" in features:
        bands, amount = features["strata"]
        layer = np.sin(vv * math.tau * bands + 0.6 * coarse)
        height += amount * np.abs(layer)
        tint += 0.08 * layer
    if "cracks" in features:
        # Polygon cracks: the edges of a seamless Voronoi pattern.
        cells, width, depth = features["cracks"]
        seeds = rng.random((cells, 2))
        edge = np.empty((n, n), dtype=np.float32)
        nearest = np.zeros((n, n), dtype=np.int64)
        warp_u = uu + 0.015 * coarse
        warp_v = vv + 0.015 * coarse
        for r0 in range(0, n, 64):
            pu = warp_u[r0:r0 + 64, :, None]; pv = warp_v[r0:r0 + 64, :, None]
            du = np.abs(pu - seeds[None, None, :, 0]); du = np.minimum(du, 1 - du)
            dv = np.abs(pv - seeds[None, None, :, 1]); dv = np.minimum(dv, 1 - dv)
            dd = np.sqrt(du * du + dv * dv).astype(np.float32)
            part = np.partition(dd, 1, axis=2)
            edge[r0:r0 + 64] = part[:, :, 1] - part[:, :, 0]
            if "blocks" in features:
                nearest[r0:r0 + 64] = np.argmin(dd, axis=2)
        crack = 1.0 - smoothstep(0.0, width, edge)
        height -= depth * crack
        if "blocks" in features:
            # Angular blocks: each cell a broken stone, raised and shaded on its own.
            lift = rng.uniform(0.0, features["blocks"], cells)
            shade_k = rng.uniform(-0.12, 0.12, cells)
            height += lift[nearest] * smoothstep(0.0, width * 2.5, edge)
            tint += shade_k[nearest]
        tint -= 0.25 * crack
    if "pebbles" in features:
        count, rmin, rmax = features["pebbles"]
        for _ in range(count):
            r = rng.uniform(rmin, rmax)
            cx, cy = rng.uniform(0, n, 2)
            lift = rng.uniform(0.15, 0.35)
            shade = rng.uniform(-0.08, 0.22)
            reach = int(r) + 2
            ys = np.arange(int(cy) - reach, int(cy) + reach + 1) % n
            xs = np.arange(int(cx) - reach, int(cx) + reach + 1) % n
            gy, gx = np.meshgrid(np.arange(-reach, reach + 1) + (int(cy) - cy), np.arange(-reach, reach + 1) + (int(cx) - cx), indexing="ij")
            d2 = (gx * gx + gy * gy) / (r * r)
            bump = np.clip(1.0 - d2, 0.0, 1.0) ** 0.5
            block = np.ix_(ys, xs)
            height[block] = np.maximum(height[block], 0.55 + lift * bump * (bump > 0))
            tint[block] += shade * (bump > 0) * 0.8
    height = np.clip((height - height.min()) / (height.max() - height.min()), 0, 1)
    shade = 0.84 + 0.26 * (height - 0.5) + 0.04 * grain + tint
    base = np.array(base) / 255.0; dark = np.array(dark) / 255.0
    mix = np.clip(0.5 + 0.35 * coarse, 0, 1)[..., None]
    rgb = (base * (1 - mix) + dark * mix) * shade[..., None]
    if crack is not None and "crack_colour" in features:
        c = crack[..., None]
        rgb = rgb * (1 - c) + np.array(features["crack_colour"]) / 255.0 * c
    alb = np.dstack([np.clip(rgb, 0, 1), height])
    write_file(os.path.join(OUT, f"ground_{name}_albedo_height.png"), Image.fromarray((alb * 255).astype("uint8"), "RGBA").save)
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 7.0
    gz = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 7.0
    nrm = np.dstack([-gx, gz, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    rgh = np.clip(rough + 0.05 * grain, 0, 1)
    img = np.dstack([nrm * 0.5 + 0.5, rgh])
    write_file(os.path.join(OUT, f"ground_{name}_normal_roughness.png"), Image.fromarray((img * 255).astype("uint8"), "RGBA").save)


# ---------- control and colour maps ----------

def ground_shape(h):
    """Slope (rise over run), curvature (+ in hollows and at the foot of
    slopes, - on crests) and how much cliff there is nearby, from the heights."""
    gz, gx = np.gradient(h, SPACING)
    slope = np.sqrt(gx * gx + gz * gz)
    soft = box_blur(h, 3)
    curvature = (np.roll(soft, 4, 0) + np.roll(soft, -4, 0) + np.roll(soft, 4, 1) + np.roll(soft, -4, 1) - 4.0 * soft) / (8.0 * SPACING) ** 2
    cliff_near = box_blur((slope > 0.9).astype(np.float32), 10)   # within about 20 m
    facing, _ = np.gradient(box_blur(h, 8), SPACING)   # rise to the south over about 30 m: > 0 faces the pole
    return slope, curvature, cliff_near, facing


def small_crater_marks(h, masks):
    """Rasters from the small craters: fresh ejecta (rocky, gravel) and dark
    wind streaks trailing downwind of them."""
    fresh = np.zeros(h.shape, dtype=np.float32)
    streaks = np.zeros(h.shape, dtype=np.float32)
    wind = np.array(DUNE_WIND)
    for cx, cz, r, age in masks["craters"]:
        if r < 6.0:
            continue
        reach = r * (2.6 if age < 0.35 else 0) + (r * 8.0 if r > 14.0 and age < 0.7 else 0)
        if reach <= 0:
            continue
        i0 = max(0, int((cx - reach + HALF) / SPACING)); i1 = min(N, int((cx + reach + HALF) / SPACING) + 1)
        j0 = max(0, int((cz - reach + HALF) / SPACING)); j1 = min(N, int((cz + reach + HALF) / SPACING) + 1)
        if i1 <= i0 or j1 <= j0:
            continue
        win = (slice(j0, j1), slice(i0, i1))
        dx = (np.arange(i0, i1) * SPACING - HALF - cx)[None, :]; dz = (np.arange(j0, j1) * SPACING - HALF - cz)[:, None]
        d = np.sqrt(dx * dx + dz * dz) / r
        if age < 0.35:
            fresh[win] = np.maximum(fresh[win], (1.0 - age / 0.35) * np.clip(1.0 - (d - 1.0) / 1.4, 0.0, 1.0) * (d > 0.85))
        if r > 14.0 and age < 0.7:
            along = (dx * wind[0] + dz * wind[1]) / r
            across = (-dx * wind[1] + dz * wind[0]) / r
            tail = np.clip(1.0 - (along - 1.0) / 7.0, 0.0, 1.0) * np.exp(-(across / (0.9 + 0.08 * along)) ** 2) * (along > 0.8)
            streaks[win] = np.maximum(streaks[win], tail)
    return fresh, streaks


def write_control(h, masks):
    """Terrain3D control map: per point a base texture chosen by the geology
    there, then by its shape (sand banks in hollows, talus at the foot of
    cliffs, frost on pole-facing slopes), an overlay of bedrock (or layered
    rock where the ground is layered) and a blend that follows the slope,
    with rock showing through on crests. Packed as uint32
    (base << 27 | overlay << 22 | blend << 14), stored raw little-endian."""
    slope, curvature, cliff_near, gz = ground_shape(h)
    fresh, streaks = small_crater_marks(h, masks)
    masks["_slope"] = slope; masks["_curvature"] = curvature; masks["_cliff_near"] = cliff_near
    masks["_fresh"] = fresh; masks["_streaks"] = streaks
    dither = 0.12 * masks["noise"]
    hollow = curvature > 0.012 + 0.006 * masks["noise"]
    base = np.full(h.shape, DUST, dtype=np.uint32)
    base[(masks["ejecta"] > 0.3 + dither) | (fresh > 0.4 + dither)] = GRAVEL
    base[masks["canyon_floor"] + dither > 0.5] = GRAVEL
    base[(masks["canyon_floor"] > 0.5) & hollow] = SAND          # dark sand drifts on the canyon floor
    base[masks["landslide"] + dither > 0.35] = TALUS
    crater_floor = (masks["crater_d"] < 0.6 + dither * 0.3) & (masks["mound"] < 0.5)
    base[crater_floor] = CLAY
    downwind = np.cos(masks["crater_angle"] - math.atan2(DUNE_WIND[1], DUNE_WIND[0])) > 0.55
    base[crater_floor & downwind & (masks["crater_d"] > 0.4 + dither * 0.2)] = SAND   # sand banked against the downwind wall
    base[masks["channels"] > 0.5] = GRAVEL
    base[masks["dunes"] + dither > 0.5] = SAND
    base[(masks["talus"] > 0.4 + dither) | ((cliff_near > 0.08) & (slope < 0.9) & (curvature > 0.0))] = TALUS
    ice = masks["ice"] + dither > 0.5
    base[ice] = ICE
    base[ice & ((masks["polygons"] > 0.85) | (gz > 0.16 + 0.05 * masks["noise"]))] = FROST   # in the troughs, and on slopes facing the pole
    base[masks["ice_scarp"] > 0.5] = FROST
    base[masks["mound"] > 0.5] = STRATA
    base[masks["sand_sheet"] + dither > 0.5] = SAND
    base[masks["ripples"] + dither > 0.5] = PALE_SAND
    base[masks["yardang_field"] + dither > 0.6] = GRAVEL        # scoured lag between the ridges
    base[masks["yardangs"] > 0.5] = STRATA
    base[masks["inverted"] > 0.5] = GRAVEL                      # cemented river gravel on the raised beds
    base[masks["inverted_side"] > 0.5] = TALUS
    base[masks["glacier"] > 0.5] = TALUS                        # rubble over the ice
    base[(masks["frost_hollow"] > 0.5)] = ICE
    base[(masks["frost_hollow"] > 0.5) & (gz > 0.02)] = FROST
    base[masks["scree"] > 0.5] = TALUS
    base[masks["lava"] + dither * 0.5 > 0.5] = LAVA
    base[(masks["fissure"] > 0.5)] = TALUS      # rubble on the fissure floors
    base[masks["river_floor"] > 0.5] = GRAVEL   # rounded river pebbles
    base[masks["delta"] > 0.5] = CLAY           # fine layered sediment
    layered = (masks["mound"] > 0.5) | (masks["mesa_body"] > 0.5) | ((masks["canyon_u"] > -110.0) & (masks["canyon_u"] < 5.0)) | (masks["yardangs"] > 0.5) | (masks["chaos"] > 0.3)
    overlay = np.where(layered, STRATA, BEDROCK).astype(np.uint32)
    crest = smoothstep(0.004, 0.02, -curvature) * 0.45   # rock through the dust on crests and rims
    blend = np.clip((smoothstep(0.45, 0.95, slope) + crest * (slope > 0.12)) * 255.0, 0, 255).astype(np.uint32)
    soft = (base == SAND) | (base == FROST) | (base == ICE) | (base == PALE_SAND)
    blend[soft & (slope < 1.1)] = 0   # dunes and ice stay sand and frost unless it's a real scarp
    blend[base == overlay] = 0   # same rock both ways: Terrain3D's height blend of a texture with itself goes dark in patches (the mound)
    masks["_base"] = base.astype(np.int64)
    control = (base << np.uint32(27)) | (overlay << np.uint32(22)) | (blend << np.uint32(14))
    data = gzip.compress(control.astype("<u4").tobytes(), compresslevel=9)
    write_file(os.path.join(OUT, "control.u32.gz"), lambda path: open(path, "wb").write(data))


def relief(h, masks, size, minor, major):
    """A map image `size` px across: ground colours, multi-directional
    hillshade (lit mainly from the north-west, as maps are: lit from below,
    the eye reads craters as hills) and contour lines every `minor` m,
    heavier every `major` m."""
    step = N // size
    hs = h[::step, ::step]
    colours = np.array([m[5] for m in MATERIALS], dtype=float) / 255.0
    rgb = colours[masks["_base"][::step, ::step]]
    gz, gx = np.gradient(hs, SPACING * step)
    norm = np.sqrt(gx * gx + gz * gz + 1.0)
    shade = np.zeros_like(hs)
    for azimuth, weight in ((315.0, 0.5), (270.0, 0.25), (0.0, 0.25)):   # map azimuths: 0 north, clockwise
        a = math.radians(azimuth)
        lx, lz, ly = math.sin(a), -math.cos(a), 1.1
        ll = math.sqrt(lx * lx + lz * lz + ly * ly)
        shade += weight * np.clip((-gx * lx - gz * lz + ly) / (norm * ll), 0.0, 1.0)
    lift = 0.94 + 0.12 * (hs - hs.min()) / (hs.max() - hs.min())
    img = rgb * (0.25 + 0.95 * shade)[..., None] * lift[..., None]
    for interval, strength in ((minor, 0.12), (major, 0.28)):
        band = np.floor(hs / interval)
        edge = (band != np.roll(band, 1, 0)) | (band != np.roll(band, 1, 1))
        img = img * (1.0 - strength * edge[..., None])
    return np.clip(img, 0, 1)


def write_map(h, masks):
    """The region map (1024 px, 20 m contours) and its close-up (2048 px,
    5 m contours) for the zoomed map round you."""
    write_file(os.path.join(OUT, "map.png"), Image.fromarray((relief(h, masks, 1024, 20.0, 100.0) * 255).astype("uint8"), "RGB").save)
    detail = Image.fromarray((relief(h, masks, 2048, 5.0, 25.0) * 255).astype("uint8"), "RGB")
    write_file(os.path.join(OUT, "map_detail.jpg"), lambda path: detail.save(path, quality=88))


def add_surface_marks(masks):
    """Marks that are only colour: dust devil tracks across the open plains
    and the fresh crater's rays."""
    x, z = grid()
    rng = np.random.default_rng(SEED + 240)
    tracks = np.zeros((N, N), dtype=np.float32)
    for _ in range(46):
        start = (rng.uniform(-2300.0, 2300.0), rng.uniform(-1600.0, 2300.0))
        line = wander(start, rng.normal(math.atan2(DUNE_WIND[1], DUNE_WIND[0]), 0.7), rng.uniform(400.0, 1500.0), rng, step=18.0, turn=0.22)
        width = rng.uniform(3.0, 8.0)
        d, _, _ = polyline_field(line, 30.0, step=1)
        tracks = np.maximum(tracks, (1.0 - smoothstep(width * 0.5, width, d)) * rng.uniform(0.5, 1.0))
    masks["devil_tracks"] = tracks * masks["open_ground"]
    cx, cz, r = FRESH_CRATER
    dd = dist(x, z, (cx, cz)) / r
    ang = np.arctan2(z - cz, x - cx)
    spokes = np.clip(np.sin(ang * 11.0 + 2.0 * np.sin(ang * 3.0)) * 1.6 - 0.5, 0.0, 1.0) + 0.6 * np.clip(np.sin(ang * 23.0 + 1.0) - 0.6, 0.0, 1.0)
    masks["rays"] = (np.clip(spokes, 0.0, 1.0) * np.clip(1.0 - (dd - 1.0) / 6.0, 0.0, 1.0) ** 1.5 * (dd > 1.0) + np.clip(1.0 - (dd - 1.0) / 1.3, 0.0, 1.0) * (dd > 0.9)).astype(np.float32)
    masks["rays"] *= 1.0 - np.clip(masks["mesa_body"] + masks["sand_sheet"], 0.0, 1.0)


def write_colour(masks, h=None):
    """Terrain3D colour map at half resolution (the game scales it up):
    gentle large-scale darkening and hue shifts, like Mars's albedo patches,
    dark wind streaks behind craters, pale dust on high ground.
    White is no change; alpha 0.5 leaves roughness alone."""
    large = masks["large"][::2, ::2]; medium = masks["medium"][::2, ::2]
    v = np.clip(0.93 + 0.05 * large + 0.025 * medium, 0.8, 1.0)
    red = np.clip(v * (1.0 + 0.02 * large), 0, 1)
    green = np.clip(v * (0.98 - 0.015 * medium), 0, 1)
    blue = np.clip(v * (0.96 - 0.02 * large), 0, 1)
    # Layers you can see from afar: light and dark bands by height on the
    # mound, the mesas and the canyon walls (each band about 5 m of rock).
    if h is not None:
        hs = h[::2, ::2]
        canyon_wall = smoothstep(-130.0, -90.0, masks["canyon_u"][::2, ::2]) * (1.0 - smoothstep(-5.0, 5.0, masks["canyon_u"][::2, ::2]))
        steep = smoothstep(0.5, 0.9, masks["_slope"][::2, ::2])
        layered = np.clip(masks["mound"][::2, ::2] + masks["mesa_body"][::2, ::2] + canyon_wall + masks["yardangs"][::2, ::2] + masks["chaos"][::2, ::2]
                          + steep * np.clip(masks["fissure_near"][::2, ::2] + masks["step_front"][::2, ::2], 0, 1), 0, 1)
        bands = 0.5 + 0.5 * np.sin(hs / 5.2 * math.pi + 0.8 * masks["medium"][::2, ::2])
        shade = 1.0 - layered * (0.06 + 0.12 * bands)
        red *= shade; green *= shade * 0.99; blue *= shade * 0.97
        # Pale dust settles on the high ground.
        pale = 0.06 * smoothstep(np.percentile(hs, 70), np.percentile(hs, 97), hs)
        red += pale * (1 - red); green += pale * (1 - green) * 0.9; blue += pale * (1 - blue) * 0.8
    # The young lava: darker where the last sheets ran, with pale dust drifted into its hollows.
    lava = masks["lava"][::2, ::2]
    sheet = 0.5 + 0.5 * np.clip(np.roll(masks["large"], (640, 380), (0, 1))[::2, ::2] + 0.6 * medium, -1.0, 1.0)
    dark = lava * (0.05 + 0.1 * sheet)
    red *= 1.0 - dark; green *= 1.0 - dark; blue *= 1.0 - dark * 0.9
    drift = lava * smoothstep(0.004, 0.02, masks["_curvature"][::2, ::2]) * 0.16
    red += drift * (1 - red); green += drift * (1 - green) * 0.85; blue += drift * (1 - blue) * 0.7
    # Dust devil tracks: thin dark lines where a whirlwind lifted the pale dust (they mark loose ground).
    tracks = masks["devil_tracks"][::2, ::2]
    red *= 1.0 - 0.1 * tracks; green *= 1.0 - 0.09 * tracks; blue *= 1.0 - 0.07 * tracks
    # Bright rays thrown out from the fresh crater.
    rays = masks["rays"][::2, ::2]
    red += 0.1 * rays * (1 - red); green += 0.09 * rays * (1 - green); blue += 0.08 * rays * (1 - blue)
    # The glacier's rubble is a shade paler along its flow lines; the raised riverbeds' gravel is greyer.
    pale2 = 0.05 * masks["glacier"][::2, ::2] + 0.04 * masks["yardang_field"][::2, ::2]
    red += pale2 * (1 - red); green += pale2 * (1 - green); blue += pale2 * (1 - blue)
    grey = 0.06 * masks["inverted"][::2, ::2]
    red *= 1.0 - grey
    streaks = masks["_streaks"][::2, ::2]
    red *= 1.0 - 0.13 * streaks; green *= 1.0 - 0.12 * streaks; blue *= 1.0 - 0.1 * streaks
    dunes = masks["dunes"][::2, ::2]
    red *= 1.0 - 0.08 * dunes; green *= 1.0 - 0.06 * dunes; blue *= 1.0 - 0.04 * dunes
    alpha = np.full(red.shape, 0.5)
    img = np.dstack([np.clip(red, 0, 1), np.clip(green, 0, 1), np.clip(blue, 0, 1), alpha])
    write_file(os.path.join(OUT, "colour.png"), Image.fromarray((img * 255).astype("uint8"), "RGBA").save)


# ---------- rocks and geology ----------

def write_rocks(h, masks):
    """The rock map (1024 px): red is how thickly rocks lie (Terrain3D's
    scatter samples it), green how big they run. Thick under cliffs, on
    fresh ejecta and in boulder fields (each crossed by a few clear
    corridors a rover can drive), sparse on dusty plains, none on dunes."""
    slope = masks["_slope"]; curvature = masks["_curvature"]; cliff_near = masks["_cliff_near"]
    density = np.full(h.shape, 0.07, dtype=np.float32)
    size = np.full(h.shape, 0.15, dtype=np.float32)
    density += 0.18 * smoothstep(-0.02, -0.004, -curvature) * (slope > 0.1)       # crests and rims
    eject = np.clip(masks["ejecta"] * 1.6, 0, 1)
    density = np.maximum(density, 0.55 * eject); size = np.maximum(size, 0.6 * eject)
    density = np.maximum(density, 0.75 * masks["_fresh"]); size = np.maximum(size, 0.7 * masks["_fresh"])
    talus = np.clip(np.maximum(masks["talus"], cliff_near * 4.0) * (slope < 1.0), 0, 1)
    density = np.maximum(density, 0.85 * talus); size = np.maximum(size, 0.9 * talus)
    density = np.maximum(density, 0.6 * smoothstep(0.2, 0.5, masks["landslide"]))
    density = np.maximum(density, 0.3 * masks["channels"])   # cobbles on the valley floors
    density = np.maximum(density, 0.5 * masks.get("channel_floor", 0.0)); size = np.maximum(size, 0.35 * masks.get("channel_floor", 0.0))
    density = np.maximum(density, 0.9 * masks["step_apron"]); size = np.maximum(size, 0.85 * masks["step_apron"])   # fallen blocks below the scarps
    density = np.where(masks["ice"] > 0.5, np.maximum(density, 0.22), density)   # a rock-strewn polygon plain
    # Boulder fields with corridors.
    x, z = grid()
    rng = np.random.default_rng(kind_seed("boulder_field", SEED + 100))
    _boulders = landforms("boulder_field")
    for bx, bz, br in BOULDER_FIELDS:
        field = np.clip(1.0 - (dist(x, z, (bx, bz)) / br + 0.25 * masks["medium"]), 0.0, 1.0)
        field = smoothstep(0.0, 0.3, field)
        lanes = np.full(h.shape, 1.0, dtype=np.float32)
        for _ in range(int(_boulders[len(masks.get("boulder_fields", []))].get("lanes", 3))):
            a = rng.uniform(0, math.tau)
            start = (bx - math.cos(a) * br * 1.3, bz - math.sin(a) * br * 1.3)
            line = wander(start, a, br * 2.6, rng, step=15.0, turn=0.12)
            d, _, _ = polyline_field(line, 20.0, step=1)
            lanes = np.minimum(lanes, smoothstep(3.0, 7.0, d))
        density = np.maximum(density, 0.95 * field * lanes) * np.where(field > 0, lanes, 1.0)
        size = np.maximum(size, 0.8 * field)
        masks.setdefault("boulder_fields", []).append((bx, bz, br))
    density = np.where(masks["lava"] > 0.5, np.minimum(density, 0.12 + 0.5 * masks["platy"]), density)   # young lava: few loose rocks off the plates
    density = np.maximum(density, 0.8 * masks["fissure"])
    # Boulder clusters on the open ground: knots of rock to go round.
    clusters = smoothstep(1.15, 1.6, spectral_noise(2.6, SEED + 230, k_low=0.015, k_high=0.05)) * masks["open_ground"]
    density = np.maximum(density, 0.85 * clusters); size = np.maximum(size, 0.65 * clusters)
    density *= np.where(slope > 1.3, 0.25, 1.0)   # rocks don't sit on cliffs
    density *= 1.0 - smoothstep(0.2, 0.5, masks["dunes"])
    density *= 1.0 - masks["cave_clear"]   # the ramp pit and the caves' notches are cleared
    density *= 1.0 - np.clip(masks["ripples"] + masks["sand_sheet"] + masks["kit_clear"] + masks["yardangs"] + masks["inverted"], 0.0, 1.0)
    density = np.maximum(density, 0.55 * masks["glacier"])
    density *= np.where((curvature > 0.01) & (masks["ice"] < 0.5), 0.5, 1.0)   # dust fills the hollows
    for zone in ZONES.values():
        density *= smoothstep(zone["flat_radius"] * 1.1, zone["flat_radius"] * 1.6, dist(x, z, zone["centre"]))
    step = N // 1024
    img = np.dstack([density[::step, ::step], size[::step, ::step], np.zeros((1024, 1024))])
    write_file(os.path.join(OUT, "rocks.png"), Image.fromarray((np.clip(img, 0, 1) * 255).astype("uint8"), "RGB").save)
    print(f"  rocks: mean density {float(density.mean()):.3f}")


# Geology units for samples (step 5): the rock and soil you'd find there.
GEOLOGY = ["plains_basalt", "ejecta_breccia", "crater_lakebed", "mound_sulfates", "canyon_layers",
           "valley_conglomerate", "dune_sand", "ice_mantle", "mesa_caprock", "talus_debris", "delta_clays", "young_lava", "yardang_ash", "river_gravel_ridge", "glacier_ice"]


def write_geology(h, masks):
    """The geology map (512 px, one unit per pixel as its index in GEOLOGY)."""
    unit = np.zeros(h.shape, dtype=np.uint8)
    unit[masks["ejecta"] > 0.2] = 1
    unit[(masks["crater_d"] < 0.95) & (masks["mound"] < 0.5)] = 2
    unit[(masks["canyon_u"] < 5.0) & (masks["canyon_u"] > -160.0)] = 4
    unit[masks["mesa_body"] > 0.5] = 8
    unit[(masks["talus"] > 0.4) | (masks["landslide"] > 0.3) | (masks["_cliff_near"] > 0.1)] = 9
    unit[masks["mound"] > 0.5] = 3
    unit[(masks["channels"] > 0.5) | (masks["river_floor"] > 0.5)] = 5
    unit[masks["delta"] > 0.5] = 10
    unit[masks["dunes"] > 0.5] = 6
    unit[masks["lava"] > 0.5] = 11
    unit[masks["yardangs"] > 0.5] = 12
    unit[masks["inverted"] > 0.5] = 13
    unit[masks["glacier"] > 0.5] = 14
    unit[masks["ice"] > 0.5] = 7
    step = N // 512
    write_file(os.path.join(OUT, "geology.png"), Image.fromarray(unit[::step, ::step], "L").save)



# ---------- the ground map and the design's checks (B2, docs/terrain-design.md §10) ----------
# What's under your boots, for traversal phase 2 (scripts/ground.gd reads ground.png).
GROUND_KINDS = ["dust", "rock", "sand", "ripples", "gravel", "scree", "ice", "frost", "clay", "lava", "platy_lava", "sharp_boulders"]


def write_ground(h, masks):
    """The ground map (1024 px): red is the ground kind (its index in
    GROUND_KINDS), green the hidden layer (hollow ground and roofed
    sinkholes: nothing on the surface shows them, radar does), blue how
    near the surface ice lies (for frost, fresh ice in new craters, and
    GAR-Y's radar)."""
    base = masks["_base"]
    kind_of = {DUST: 0, BEDROCK: 1, SAND: 2, FROST: 7, CLAY: 8, GRAVEL: 4, STRATA: 1, TALUS: 5, ICE: 6, LAVA: 9, PALE_SAND: 3}
    kind = np.zeros(h.shape, dtype=np.uint8)
    for texture, k in kind_of.items():
        kind[base == texture] = k
    kind[masks["platy"] > 0.35] = 10
    kind[(masks["_slope"] > 0.8) & (kind != 6) & (kind != 7)] = 1   # steep ground is rock, whatever lies round it
    x, z = grid()
    for index in SHARP_BOULDERS:
        bx, bz, br = BOULDER_FIELDS[index]
        kind[(dist(x, z, (bx, bz)) / br + 0.25 * masks["medium"] < 0.85) & (masks["_slope"] < 0.8)] = 11
    hidden = np.maximum(masks["hollow"], masks["sinkholes"])
    ice = np.clip(masks["ice"] * 0.6 + masks["polygons"] * 0.2 + masks["glacier"] + masks["frost_hollow"] + masks["ice_scarp"], 0.0, 1.0)
    step = N // 1024

    def block_max(a):
        return a[:1024 * step, :1024 * step].reshape(1024, step, 1024, step).max(axis=(1, 3))

    img = np.dstack([kind[::step, ::step], (block_max(hidden) * 255).astype(np.uint8), (block_max(ice) * 255).astype(np.uint8)])
    write_file(os.path.join(OUT, "ground.png"), Image.fromarray(img, "RGB").save)
    masks["_kind"] = kind
    share = {GROUND_KINDS[k]: round(float((kind == k).mean()), 3) for k in range(len(GROUND_KINDS))}
    print("  ground: " + ", ".join(f"{name} {100 * v:.0f}%" for name, v in share.items() if v >= 0.005))
    return share


def find_viewpoints(h, masks):
    """High ground that shows you the routes: the mesa tops, the top of each
    step, the crater's rim, and a lookout on the south ridge (the aurora
    is seen only from up there)."""
    out = []

    def highest(name, x0, z0, x1, z1):
        i0, i1 = int((x0 + HALF) / SPACING), int((x1 + HALF) / SPACING); j0, j1 = int((z0 + HALF) / SPACING), int((z1 + HALF) / SPACING)
        part = h[j0:j1, i0:i1]
        j, i = np.unravel_index(int(np.argmax(part)), part.shape)
        out.append({"name": name, "position": [round((i0 + i) * SPACING - HALF, 1), round((j0 + j) * SPACING - HALF, 1)], "height": round(float(part[j, i]), 1)})

    for index, (mx, mz, mr, mh) in enumerate(MESAS):
        out.append({"name": f"Mesa {index + 1}", "position": [mx, mz], "height": round(sample(h, mx, mz), 1)})
    highest("South ridge lookout", -1900.0, 2350.0, -500.0, 2700.0)
    highest("Crater rim, south-west", 150.0, -300.0, 600.0, 250.0)
    highest("Crater rim, north", 800.0, -1950.0, 1400.0, -1700.0)
    highest("Mound top", MOUND["centre"][0] - 150.0, MOUND["centre"][1] - 150.0, MOUND["centre"][0] + 150.0, MOUND["centre"][1] + 150.0)
    for step_line in masks["step_lines"]:
        mid = step_line["points"][len(step_line["points"]) // 2]
        highest("Step: " + step_line["id"].replace("_", " "), mid[0] - 120.0, mid[1] - 120.0, mid[0] + 120.0, mid[1] + 120.0)
    return out


def check_design(h, masks):
    """The design's own checks (docs/terrain-design.md §6, §8 and §10):
    how often a straight line meets a choice in each ring, that no step
    line is ring-shaped, that nothing you can walk into traps you, and
    that the canyon floor is only driven into by the ramp."""
    checks = {}
    home = np.array(HOME["centre"])
    # 1. Straight lines from home: a "choice" is ground too steep to walk straight up
    #    (over 25 degrees across 4 m), a crack, or ground that costs (sand, ripples,
    #    scree, platy lava, sharp boulders).
    costly = np.isin(masks["_kind"], [2, 3, 5, 10, 11])
    events = [0, 0, 0]; lengths = [0.0, 0.0, 0.0]
    for a in np.linspace(0.0, math.tau, 72, endpoint=False):
        d = np.arange(60.0, RINGS[2], 2.0)
        px = home[0] + np.cos(a) * d; pz = home[1] + np.sin(a) * d
        inside = (np.abs(px) < HALF - 700.0) & (pz < HALF - 700.0) & (pz > -1950.0)
        if not inside.any():
            continue
        last = int(np.argmin(inside)) if not inside.all() else len(d)
        if last < 4:
            continue
        d, px, pz = d[:last], px[:last], pz[:last]
        i = ((px + HALF) / SPACING).astype(int); j = ((pz + HALF) / SPACING).astype(int)
        ground = h[j, i]
        steep = np.zeros(len(d), dtype=bool)
        steep[:-2] = np.abs(ground[2:] - ground[:-2]) / 4.0 > math.tan(math.radians(25.0))
        hard = steep | costly[j, i] | (masks["fissure"][j, i] > 0.5)
        hard = np.convolve(hard.astype(float), np.ones(10), mode="same") > 0   # things within 20 m of each other are one choice
        starts = np.flatnonzero(hard[1:] & ~hard[:-1])
        for ring in range(3):
            lo = 0.0 if ring == 0 else RINGS[ring - 1]
            in_ring = (d >= lo) & (d < RINGS[ring])
            lengths[ring] += float(in_ring.sum()) * 2.0
            events[ring] += int(((d[starts] >= lo) & (d[starts] < RINGS[ring])).sum())
    checks["straight_lines"] = [{"ring": k + 1, "metres_between_choices": round(lengths[k] / max(events[k], 1), 0)} for k in range(3)]
    print("  straight lines from home: a choice every " + ", ".join(f"{c['metres_between_choices']:.0f} m in ring {c['ring']}" for c in checks["straight_lines"]))
    # 2. No step line is a ring round home.
    spans = []
    for step_line in masks["step_lines"]:
        dd = [math.hypot(p[0] - home[0], p[1] - home[1]) for p in step_line["points"]]
        spans.append({"id": step_line["id"], "nearest": round(min(dd)), "furthest": round(max(dd)), "passes": len(step_line["passes"])})
    checks["step_lines"] = spans
    for s in spans:
        if s["furthest"] - s["nearest"] < 300:
            print(f"  WARNING: step line {s['id']} keeps a near-constant distance from home ({s['nearest']}..{s['furthest']} m)")
    # 3. Walk-out: everything inside the edges is reached on foot from home (a
    #    scramble, 40 degrees across 10 m, is the limit), bar the places that are
    #    meant to need a rope.
    step = int(ROUTE_CELL / SPACING)
    g = h[::step, ::step]
    # A cell is walkable if any way off it is a scramble or less: use the gentlest neighbour, not the steepest.
    gentle = np.full_like(g, np.inf)
    for axis in (0, 1):
        diff = np.abs(np.diff(g, axis=axis)) / ROUTE_CELL
        lo = [slice(None), slice(None)]; hi = [slice(None), slice(None)]
        lo[axis] = slice(0, -1); hi[axis] = slice(1, None)
        gentle[tuple(lo)] = np.minimum(gentle[tuple(lo)], diff); gentle[tuple(hi)] = np.minimum(gentle[tuple(hi)], diff)
    walk = gentle <= math.tan(math.radians(40.0))
    reach = flood(walk, disc_cells(walk.shape, step, home[0], home[1], 40.0))
    coords = np.arange(g.shape[0]) * SPACING * step - HALF
    gx, gz = np.meshgrid(coords, coords)
    inside = (gx > -HALF + 760.0) & (gx < HALF - 100.0) & (gz < HALF - 760.0) & (gz > CANYON_FAR_EDGE + 120.0)
    lost = inside & walk & ~reach
    checks["walk_out"] = {"reached_share": round(float((reach & inside).sum() / max((walk & inside).sum(), 1)), 4), "unreached_cells": int(lost.sum())}
    floor_cells = masks["canyon_floor"][::step, ::step] > 0.9
    checks["walk_out"]["canyon_floor_reached_share"] = round(float((reach & floor_cells & inside).sum() / max((floor_cells & inside & walk).sum(), 1)), 4)
    print(f"  on foot from home: {100 * checks['walk_out']['reached_share']:.1f}% of walkable ground reached, the canyon floor {100 * checks['walk_out']['canyon_floor_reached_share']:.1f}%")
    if "--debug-routes" in sys.argv:
        img = np.zeros(walk.shape + (3,), dtype=np.uint8)
        img[walk] = (90, 90, 90); img[reach] = (80, 220, 80); img[lost] = (240, 60, 60)
        Image.fromarray(img).resize((walk.shape[1] * 2, walk.shape[0] * 2), Image.NEAREST).save(os.path.join(ROOT, ".claude_tmp", "walk.png"))
    # 4. The canyon floor is only driven into by the ramp.
    ok, _ = route_grid(h, masks)
    start = disc_cells(ok.shape, step, home[0], home[1], 40.0)
    goal = disc_cells(ok.shape, step, -1200.0, -2400.0, 60.0)
    by_ramp = bool((flood(ok, start) & goal).any())
    shut = ok & ~((np.abs(gx + 2050.0) < 260.0) & (gz < -1250.0) & (gz > -2150.0))
    without = bool((flood(shut, start) & goal).any())
    checks["canyon_gate"] = {"driven_by_ramp": by_ramp, "driven_without_ramp": without}
    print(f"  canyon floor by rover: by the ramp {by_ramp}, without it {without}")
    # 5. The edges: past this line Castle and the suit call you back.
    # 6. Ring 2's obstacles: the rover crosses only at the passes; 7. the maze on foot.
    checks["rover_crossings"] = check_rover_crossings(h, masks)
    maze = check_maze(h, masks)
    if maze is not None:
        checks["maze"] = maze
    checks["callback"] = {"x_min": -HALF + 420.0, "x_max": HALF - 160.0, "z_min": CANYON_FAR_EDGE - 60.0, "z_max": HALF - 420.0}
    return checks


def line_coords(line, px, pz):
    """For points (arrays): distance to a polyline, how far along it (0..1) and which side (+1 left of travel)."""
    best = np.full(px.shape, np.inf); bt = np.zeros(px.shape); side = np.zeros(px.shape)
    seg = np.hypot(*np.diff(line, axis=0).T); cum = np.concatenate([[0.0], np.cumsum(seg)]); total = max(cum[-1], 1e-6)
    for k in range(len(line) - 1):
        a = line[k]; b = line[k + 1]
        sx = b[0] - a[0]; sz = b[1] - a[1]; l2 = max(sx * sx + sz * sz, 1e-6)
        u = np.clip(((px - a[0]) * sx + (pz - a[1]) * sz) / l2, 0.0, 1.0)
        d = np.hypot(px - a[0] - u * sx, pz - a[1] - u * sz)
        closer = d < best
        best[closer] = d[closer]; bt[closer] = ((cum[k] + u * seg[k]) / total)[closer]
        side[closer] = np.sign(sx * (pz - a[1]) - sz * (px - a[0]))[closer]
    return best, bt, side


def check_rover_crossings(h, masks):
    """Ring 2's obstacles are real detours (§13): along the middle of each wrinkle ridge and step line, a
    rover gets from one side to the other at its passes, and nowhere else."""
    ok, step = route_grid(h, masks)
    coords = np.arange(ok.shape[0]) * SPACING * step - HALF
    gx, gz = np.meshgrid(coords, coords)
    out = {}
    for ob in masks.get("obstacle_lines", []):
        line = np.array(ob["line"], dtype=float)
        lo = line.min(axis=0) - ob["reach"]; hi = line.max(axis=0) + ob["reach"]
        box = (gx > lo[0]) & (gx < hi[0]) & (gz > lo[1]) & (gz < hi[1])
        d = np.full(gx.shape, np.inf); t = np.zeros(gx.shape); sd = np.zeros(gx.shape)
        d[box], t[box], sd[box] = line_coords(line, gx[box], gz[box])
        so, to = ob["s"][:ok.shape[0], :ok.shape[1]], ob["t"][:ok.shape[0], :ok.shape[1]]   # the obstacle's own signed distance (warp, spurs and bays included)
        band = (d < ob["reach"]) & (to > 0.12) & (to < 0.88)
        a_side = band & (so < ob["low"]); b_side = band & (so > ob["high"])
        blocked = np.zeros_like(ok)
        for p in ob["passes"]:
            blocked |= disc_cells(ok.shape, step, p[0], p[1], ob.get("pass_radius", 110.0))
        with_passes = flood(ok & band, a_side & ok)
        without = flood(ok & band & ~blocked, a_side & ok & ~blocked)
        crosses = bool((with_passes & b_side).any())
        elsewhere = bool((without & b_side).any())
        where = None
        if elsewhere:
            cells = np.argwhere(without & b_side & (d < 120.0))
            if len(cells):
                where = (float(coords[cells[0][1]]), float(coords[cells[0][0]]))
        out[ob["id"]] = {"label": ob["label"], "at_passes": crosses, "only_at_passes": not elsewhere, "at": where,
                         "detail": ("crossed only at its passes" if crosses and not elsewhere else
                                    ("a rover can cross away from the passes" if elsewhere else "a rover can't cross even at the passes"))}
        print(f"  {ob['id']}: rover crosses at the passes {crosses}, elsewhere {elsewhere}")
    return out


def check_maze(h, masks):
    """The yardang maze (§13): on foot the way through is at least twice the straight line, and there are
    at least 3 dead ends (joins you can walk up to)."""
    plan = masks.get("maze_plan")
    if plan is None:
        return None
    win = plan["win"]
    # On the full 2 m grid: a coarser one lets the walk slip between the thin tips of ridges and joins.
    along = maze_paths(h[win], win, plan["entry"], plan["exit"], plan["region"], 2)
    result = maze_paths(h[win], win, plan["side_a"], plan["side_b"], plan["across_region"], 2)   # across the wind: the hard way, the one that counts
    reached = result["reached"] | along["reached"]; k = int(result["cell"] / SPACING)
    j0, i0 = win[0].start, win[1].start
    dead = []
    for p in plan["joins"]:
        cj = int(round((p[1] + HALF) / SPACING - j0)) // k; ci = int(round((p[0] + HALF) / SPACING - i0)) // k
        r = 4
        if reached[max(cj - r, 0):cj + r + 1, max(ci - r, 0):ci + r + 1].any():
            dead.append([round(float(p[0]), 1), round(float(p[1]), 1)])
    masks["yardang_dead_ends"] = dead
    print(f"  the maze on foot: across the wind {result['ratio']:.2f}x the straight line, along it (the through-lanes) {along['ratio']:.2f}x, {len(dead)} dead ends")
    return {"through": result["through"] and along["through"], "ratio": round(result["ratio"], 2), "along_ratio": round(along["ratio"], 2), "dead_ends": len(dead),
            "at": [round(float(plan["entry"][0]), 1), round(float(plan["entry"][1]), 1)]}


# ---------- named anchors (B5, docs/terrain-design.md §13) ----------

def _slug(name):
    return "".join(ch if ch.isalnum() else "_" for ch in name.lower()).strip("_").replace("__", "_")


def sample_bilinear(h, px, pz):
    """Height between points, as the game reads it (scripts/region_terrain.gd height())."""
    gx = min(max((px + HALF) / SPACING, 0.0), N - 1.001); gz = min(max((pz + HALF) / SPACING, 0.0), N - 1.001)
    i, j = int(gx), int(gz); tx, tz = gx - i, gz - j
    top = h[j, i] * (1 - tx) + h[j, i + 1] * tx; bottom = h[j + 1, i] * (1 - tx) + h[j + 1, i + 1] * tx
    return float(top * (1 - tz) + bottom * tz)


def build_anchors(h, masks, caves, fissures):
    """Every landform's centre and its useful points, on the final ground: [{id, position, height, ring, landform}].
    C1 places story things by these ids, so they follow the land when the editor moves it."""
    out = []
    seen = set()
    home = HOME["centre"]

    def add(aid, px, pz, landform_id):
        if aid in seen:
            raise ValueError(f"anchor {aid} twice")
        seen.add(aid)
        d = math.hypot(px - home[0], pz - home[1])
        ring = next((k + 1 for k, r in enumerate(RINGS) if d < r), 0)
        out.append({"id": aid, "position": [round(float(px), 1), round(float(pz), 1)], "height": round(sample_bilinear(h, px, pz), 2),
                    "ring": ring, "landform": landform_id})

    for e in LAYOUT["landforms"]:
        if "centre" in e:
            add(e["id"] + ".centre", e["centre"][0], e["centre"][1], e["id"])
        elif "points" in e:
            pts = resample(e["points"], 4.0)
            mid = pts[len(pts) // 2]
            add(e["id"] + ".centre", mid[0], mid[1], e["id"])
            add(e["id"] + ".start", pts[0][0], pts[0][1], e["id"])
            add(e["id"] + ".end", pts[-1][0], pts[-1][1], e["id"])
    for e in landforms("mesa"):
        mx, mz = e["centre"]; mr, mh = e["radius"], e["height"]
        add(e["id"] + ".top", mx, mz, e["id"])
        if e.get("ramp") is not None:
            reach = mr * (0.78 + mh / (0.15 * mr))
            add(e["id"] + ".ramp_foot", mx + math.cos(e["ramp"]) * reach, mz + math.sin(e["ramp"]) * reach, e["id"])
        if e.get("gully") is not None:
            reach = mr * (0.55 + mh / (0.68 * mr))
            add(e["id"] + ".gully_foot", mx + math.cos(e["gully"]) * reach, mz + math.sin(e["gully"]) * reach, e["id"])
    for line in masks["step_lines"]:
        for k, p in enumerate(line["passes"]):
            add(f"{line['id']}.pass_{k + 1}", p[0], p[1], line["id"])
    for rid, passes in masks.get("ridge_passes", {}).items():
        for k, p in enumerate(passes):
            add(f"{rid}.pass_{k + 1}", p[0], p[1], rid)
    for k, p in enumerate(masks["home_crossings"]):
        add(f"channel.crossing_{k + 1}", p[0], p[1], "channel")
    g = GLACIER
    add("glacier.alcove", g["from"][0], g["from"][1], "glacier")
    flow = np.array(g["flow"]) / np.linalg.norm(g["flow"])
    add("glacier.toe", g["from"][0] + flow[0] * g["length"], g["from"][1] + flow[1] * g["length"], "glacier")
    for f in fissures:
        if "bridge" in f:
            add(f"{f['id']}.bridge", *f["bridge"]["position"], f["id"])
    add("sliver.bridge", masks["sliver"][0], masks["sliver"][1], "sliver")
    add("outcrop.ladder", HOME_GROUND["outcrop"][0], HOME_GROUND["outcrop"][1], "outcrop")
    add("collapse_pit.rope", HOME_GROUND["pit"][0], HOME_GROUND["pit"][1], "collapse_pit")
    for name, zone in ZONES.items():
        add(f"zone.{name}", zone["centre"][0], zone["centre"][1], "zone")
    add("home.centre", home[0], home[1], "home")
    tube = caves[0]
    add("tube.mouth", *tube["mouth"], "lava_tube")
    add("tube.ramp_top", *tube["ramp_top"], "lava_tube")
    for k, s in enumerate(tube["skylights"]):
        add(f"tube.skylight_{k + 1}", *s["position"], "lava_tube")
    for k, p in enumerate(tube["deep"]["pitches"]):
        add(f"tube.pitch_{k + 1}", p["anchor"][0], p["anchor"][1], "lava_tube")
    add("tube.heart", *tube["deep"]["heart"]["position"], "lava_tube")
    for place in tube["places"]:
        add("tube." + _slug(place["name"]), *place["position"], "lava_tube")
    for cave in caves[1:]:
        add(f"{cave['id']}.mouth", *cave["mouth"], cave["id"])
    for v in masks.get("yardang_dead_ends", []):
        add(f"yardangs.dead_end_{len([a for a in out if a['id'].startswith('yardangs.dead_end_')]) + 1}", v[0], v[1], "yardangs")
    return out


def anchor_checks(anchors, previous):
    """WARN when an anchor moved more than 50 m since the last build; FAIL when data in data/ names an anchor that's gone."""
    before = {a["id"]: a["position"] for a in previous.get("anchors", [])}
    now = {a["id"]: a["position"] for a in anchors}
    moved = [{"id": k, "metres": round(math.hypot(now[k][0] - p[0], now[k][1] - p[1]), 1)} for k, p in before.items()
             if k in now and math.hypot(now[k][0] - p[0], now[k][1] - p[1]) > 50.0]
    gone_since = sorted(k for k in before if k not in now)
    named = set()

    def walk(v):
        if isinstance(v, dict):
            for key, item in v.items():
                if key == "anchor" and isinstance(item, str):
                    named.add(item)
                elif key == "anchors" and isinstance(item, list):
                    named.update(i for i in item if isinstance(i, str))
                else:
                    walk(item)
        elif isinstance(v, list):
            for item in v:
                walk(item)

    data = os.path.join(ROOT, "data")
    for name in sorted(os.listdir(data)):
        if name.endswith(".json") and name != "region_layout.json":
            try:
                walk(json.load(open(os.path.join(data, name), encoding="utf-8")))
            except (OSError, ValueError):
                pass
    walk(LAYOUT.get("surprises", []))
    missing = sorted(a for a in named if a not in now)
    for m in moved:
        print(f"  WARNING: anchor {m['id']} moved {m['metres']:.0f} m since the last build")
    for a in missing:
        print(f"  FAIL: data names anchor {a}, which no longer exists")
    return {"count": len(anchors), "moved": moved, "gone_since_last_build": gone_since, "missing_in_data": missing}

# What a choice every so many metres should be at most, ring by ring (docs/terrain-design.md §6).
CHOICE_TARGET = [260.0, 200.0, 200.0]


def checks_list(checks, routes):
    """The checks as one list for the land editor: {name, status PASS/WARN/FAIL, detail, at (optional [x, z])}."""
    out = []

    def add(name, status, detail="", at=None):
        item = {"name": name, "status": status, "detail": detail}
        if at is not None:
            item["at"] = [round(float(at[0]), 1), round(float(at[1]), 1)]
        out.append(item)

    bad = [f"{r['from']} to {r['to']}" for r in routes if not r["ok"]]
    add("Rover routes", "FAIL" if bad else "PASS", ("not drivable: " + ", ".join(bad)) if bad else f"all {len(routes)} drivable")
    w = checks["walk_out"]
    share = w["reached_share"]
    add("Walking out from home", "PASS" if share >= 0.995 else ("WARN" if share >= 0.98 else "FAIL"),
        f"{100 * share:.1f}% of walkable ground reached on foot ({w['unreached_cells']} cells not), canyon floor {100 * w['canyon_floor_reached_share']:.1f}%")
    g = checks["canyon_gate"]
    ok = g["driven_by_ramp"] and not g["driven_without_ramp"]
    add("The canyon gate", "PASS" if ok else "FAIL",
        "the rover reaches the canyon floor only by the ramp" if ok else f"by the ramp {g['driven_by_ramp']}, without it {g['driven_without_ramp']}", (-2050.0, -1700.0))
    for c in checks["straight_lines"]:
        target = CHOICE_TARGET[c["ring"] - 1]
        add(f"A choice every so often, ring {c['ring']}", "PASS" if c["metres_between_choices"] <= target else "WARN",
            f"a choice every {c['metres_between_choices']:.0f} m in a straight line (target {target:.0f} m or less)")
    for s in checks["step_lines"]:
        ring_shaped = s["furthest"] - s["nearest"] < 300
        status = "FAIL" if s["passes"] == 0 else ("WARN" if ring_shaped else "PASS")
        add(f"Passes on {s['id'].replace('_', ' ')}", status, f"{s['passes']} passes; {s['nearest']}..{s['furthest']} m from home"
            + ("; it keeps a near-constant distance from home" if ring_shaped else ""))
    for name, c in checks.get("rover_crossings", {}).items():
        add(f"{c['label']}: rover only at the passes", "PASS" if c["only_at_passes"] and c["at_passes"] else ("FAIL" if not c["at_passes"] else "WARN"),
            c["detail"], c.get("at"))
    if "maze" in checks:
        m = checks["maze"]
        ok = m["ratio"] >= 2.0 and m["dead_ends"] >= 3 and m["through"]
        add("The yardang maze", "PASS" if ok else ("FAIL" if not m["through"] else "WARN"),
            f"way through on foot {m['ratio']:.1f}x the straight line (2x or more), {m['dead_ends']} dead ends (3 or more)", m.get("at"))
    a = checks.get("anchors")
    if a is not None:
        status = "FAIL" if a["missing_in_data"] else ("WARN" if a["moved"] or a["gone_since_last_build"] else "PASS")
        detail = f"{a['count']} anchors"
        if a["moved"]:
            detail += "; moved over 50 m: " + ", ".join(f"{m['id']} ({m['metres']:.0f} m)" for m in a["moved"][:8])
        if a["gone_since_last_build"]:
            detail += "; gone since the last build: " + ", ".join(a["gone_since_last_build"][:8])
        if a["missing_in_data"]:
            detail += "; named in data/ but missing: " + ", ".join(a["missing_in_data"])
        add("Anchors", status, detail)
    s = checks.get("sameness")
    if s is not None:
        add("Something new every few minutes", "WARN" if s["dull"] else "PASS",
            f"{len(s['dull'])} dull stretches (over {s['foot_minutes']:.0f} min on foot or {s['rover_minutes']:.0f} min by rover with nothing new); "
            f"longest {s['longest_foot']:.1f} min on foot, {s['longest_rover']:.1f} min by rover",
            s["dull"][0]["from"] if s["dull"] else None)
    return out


_clock = [time.time()]


def lap(name):
    now = time.time()
    print(f"  [{now - _clock[0]:5.1f} s] {name}")
    _clock[0] = now


def main():
    os.makedirs(OUT, exist_ok=True)
    try:
        with open(os.path.join(OUT, "region.json"), encoding="utf-8") as f:
            previous = json.load(f)   # for the anchor check: what moved since the last build
    except (OSError, ValueError):
        previous = {}
    h, masks = build_heights()
    caves = add_caves(h, *grid(), masks); lap("add_caves")
    hollow = add_hollow_ground(h, *grid(), masks, caves[0])
    plans = plan_fissures(masks)
    routes = check_routes(h, masks); lap("check_routes")
    fissures = carve_fissures(h, *grid(), masks, plans); lap("carve_fissures")
    routes = check_routes(h, masks, fix=False)   # the fissures are hard gates: nothing is graded across them
    lo, hi = save_heights(h); lap("save_heights")
    write_control(h, masks); lap("write_control")
    add_surface_marks(masks)
    write_colour(masks, h); lap("write_colour")
    write_map(h, masks); lap("write_map")
    write_rocks(h, masks); lap("write_rocks")
    write_geology(h, masks)
    ground_share = write_ground(h, masks)
    viewpoints = find_viewpoints(h, masks)
    checks = check_design(h, masks)
    anchors = build_anchors(h, masks, caves, fissures)
    checks["anchors"] = anchor_checks(anchors, previous)
    checks["list"] = checks_list(checks, routes); lap("ground map, anchors and checks")
    for c in checks["list"]:
        if c["status"] != "PASS":
            print(f"  {c['status']}: {c['name']}: {c['detail']}")
    for index, (name, base, dark, rough, features, _) in enumerate(MATERIALS if not QUICK else []):
        material_texture(name, base, dark, rough, dict(features), SEED + 20 + index)
    meta = {
        "id": REGION_ID,
        "size": N, "spacing": SPACING, "half": HALF,
        "height_min": lo, "height_max": hi,
        "zones": {k: {"centre": list(v["centre"]), "flat_radius": v["flat_radius"], "height": v["height"], "label": v["label"]} for k, v in ZONES.items()},
        "crater": CRATER, "mound": MOUND,
        "textures": [m[0] for m in MATERIALS],
        "features": [{"name": n, "position": list(p)} for n, p in FEATURES]
        + [{"name": "Pit chain", "position": caves[0]["skylights"][1]["position"]}],
        "geology": GEOLOGY,
        "routes": routes,
        "caves": caves,
        "boulder_fields": [list(b) for b in BOULDER_FIELDS],
        "sharp_boulder_fields": [list(BOULDER_FIELDS[k]) for k in SHARP_BOULDERS],
        "home": {"centre": list(HOME["centre"]), "radius": HOME["radius"]},
        "rings": RINGS,
        "heart": list(HEART),
        "fissures": fissures,
        "hollow_ground": hollow,
        "platy_lanes": masks["platy_lanes"],
        "ground_kinds": GROUND_KINDS,
        "ground_share": ground_share,
        "viewpoints": viewpoints,
        "checks": checks,
        "anchors": anchors,
        "step_lines": masks["step_lines"],
        "minor_cracks": masks["minor_cracks"],
        "yardangs": {"centre": list(YARDANGS["centre"]), "length": YARDANGS["length"], "width": YARDANGS["width"], "wind": list(DUNE_WIND)},
        "drone_wreck": list(DRONE_WRECK),
        "raised_riverbeds": masks["inverted_lines"],
        "glacier": {"from": list(GLACIER["from"]), "flow": list(GLACIER["flow"]), "length": GLACIER["length"], "pits": masks["glacier_pits"]},
        "home_ground": {"frost_hollow": list(HOME_GROUND["frost_hollow"]), "channel": masks["home_channel"], "crossings": masks["home_crossings"],
                        "sand_sheet": list(HOME_GROUND["sand_sheet"])},
        # Places the land locks until you have the kit (docs/terrain-design.md §6).
        # Places that an event opens or uncovers later in the game (the story decides when).
        "reveals": [
            {"id": "deep_plug", "by": "marsquake", "what": "the rockfall past the lava tube's cold trap comes down: the way into the deep", "position": caves[0]["mouth"], "cave": "lava_tube"},
            {"id": "north_fissure_wall", "by": "marsquake", "what": "a slab falls from the north fissure's wall, baring a pale mineral vein", "position": list(FISSURES[1]["to"])},
            {"id": "sand_sheet_bed", "by": "dust storm", "what": "the storm strips the sand off the old riverbed's lower reach, baring its layered bed", "position": list(INVERTED_CHANNELS["sand_centre"])},
            {"id": "dune_wreck", "by": "dust storm", "what": "the dunes march on and uncover something they had buried", "position": [DUNES[0] + 300.0, DUNES[1] + 60.0]},
        ],
        "kit_places": [
            {"kit": "ladder", "ring": 1, "position": list(HOME_GROUND["outcrop"][:2]), "what": "ledge-topped outcrop"},
            {"kit": "rope", "ring": 1, "position": list(HOME_GROUND["pit"][:2]), "what": "collapse pit", "rope_only": True},
            {"kit": "bridge", "ring": 1, "position": masks["sliver"], "what": "cracked sliver"},
        ],
    }
    with open(os.path.join(OUT, "region.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"region {REGION_ID}: {N}x{N} at {SPACING} m, heights {lo:.1f}..{hi:.1f} m")
    for k, v in meta["zones"].items():
        print(f"  {k}: centre {v['centre']}, level {v['height']:.1f} m")
    # A small top-down preview for checking the layout.
    small = h[::6, ::6]
    shade = (small - small.min()) / (small.max() - small.min())
    gy, gx = np.gradient(small)
    light = np.clip(0.6 + (gx - gy) * 0.08, 0, 1)
    img = (np.dstack([shade * 0.6 + light * 0.4] * 3) * np.array([1.0, 0.78, 0.62]) * 255).astype("uint8")
    write_file(os.path.join(OUT, "preview.png"), Image.fromarray(img).save)


if __name__ == "__main__":
    main()
