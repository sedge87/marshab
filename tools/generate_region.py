"""Generate the test region (gameplay loop prototype, 31 Oct 2026).

One 6 km x 6 km composite region with two landing zones (docs/gameplay-loop-brief.md
§5.1): open plains with mesas in the south-west, a 2.2 km crater with a layered central
mound in the east, a canyon scarp along the north edge, a dune field below it,
polygon-cracked ice fields in the north-west, and ragged hills framing the edge.
(-Z is north.)

Writes assets/terrain/<id>/:
  height.r16.gz   heights, 16-bit unsigned little-endian, rows = +Z, gzip; point (i, j)
                  is at x = -half + i * spacing, z = -half + j * spacing
  region.json     size, spacing, height range, landing zones
  control.u32.gz  Terrain3D control map: base texture by zone, bedrock on slopes
  colour.png      Terrain3D colour map (half resolution): large-scale tint
  ground_*.png    Terrain3D textures: albedo + height (alpha), normal + roughness (alpha)

Usage: python tools/generate_region.py [region_id] [--quick]
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

N = 3072            # points per side
SPACING = 2.0       # metres between points
HALF = N * SPACING / 2.0
SEED = 1987

# Landing zones (region coordinates, metres; the base is built around them).
ZONES = {
    "plains": {"centre": (-1400.0, 1000.0), "flat_radius": 95.0, "label": "The plains"},
    "crater": {"centre": (1580.0, -320.0), "flat_radius": 85.0, "label": "The crater floor"},
}
CRATER = {"centre": (1100.0, -700.0), "radius": 1100.0, "depth": 95.0, "rim": 62.0}
MOUND = {"centre": (920.0, -580.0), "radius": 330.0, "height": 135.0}
DUNES = (-650.0, -1640.0)   # the dune field's centre, clear of the crater rim
DUNES_RADIUS = 500.0         # across the wind; it runs 1.8 times longer along it
DUNE_WIND = (0.97, -0.24)    # along the canyon, away from the crater
ICE_PATCHES = [(-1500.0, -1100.0, 600.0), (-1870.0, -640.0, 380.0), (-1120.0, -1480.0, 330.0), (-1950.0, -1350.0, 260.0)]
# Named places for the region map (region metres).
FEATURES = [
    ("Crater", (1100.0, -1500.0)), ("Layered mound", (920.0, -580.0)), ("Canyon", (0.0, -2600.0)),
    ("Dune field", (-650.0, -1640.0)), ("Ice fields", (-1500.0, -1100.0)), ("Mesas", (-1400.0, 1700.0)),
]
# The ancient river: from the southern hills it meanders north, widens into
# a cliff-walled valley (the riverbed landing zone), breaches the crater's
# south-west rim and spreads a delta over the crater floor, like Jezero.
RIVER_SOURCE = (900.0, 2750.0)
RIVER_MOUTH_ANGLE = (-0.33, 0.944)   # where it breaks through the rim, from the crater's centre
RIVER_WIDE_AT = 0.42                 # how far along the valley widens (0 source, 1 rim)


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
ZONES["riverbed"] = {"centre": (float(RIVER_POINTS[_wide][0]), float(RIVER_POINTS[_wide][1])), "flat_radius": 50.0, "blend": 1.15, "label": "The old riverbed"}
FEATURES += [("Ancient river", tuple(float(v) for v in RIVER_POINTS[110])), ("Delta", tuple(float(v) for v in RIVER_POINTS[-12]))]
FEATURES += [("Wrinkle ridge", (-1650.0, 1900.0)), ("Wrinkle ridge", (-600.0, 1900.0)), ("Side canyon", (-250.0, -1800.0))]

MESAS = [(-760.0, 420.0, 170.0, 48.0), (-2050.0, 1650.0, 240.0, 62.0), (300.0, 1500.0, 140.0, 40.0), (-1950.0, 380.0, 110.0, 34.0), (2100.0, 1700.0, 260.0, 70.0)]


# Mesas with a ramp of fallen wall the rover can climb: mesa index -> the ramp's direction (radians).
MESA_RAMPS = {1: 0.0, 4: math.pi}
# The big crater's breaches: (direction from its centre, angular width, how much of the rim is gone).
CRATER_BREACHES = [(-1.2, 0.34, 0.6), (0.25, 0.26, 0.72)]
CANYON_DEPTH = 170.0
CANYON_FAR_EDGE = -2640.0   # the canyon's far (north) wall
# Side canyons biting back into the plateau: (x, length, half width, ramp up from the floor?).
SIDE_RAMP_LENGTH = 700.0
SIDE_CANYONS = [(-2150.0, 420.0, 75.0, False), (-250.0, SIDE_RAMP_LENGTH, 85.0, True), (2050.0, 500.0, 70.0, False), (-1500.0, 230.0, 45.0, False)]
CANYON_LANDSLIDES = [(-950.0, 420.0, 260.0), (1250.0, 380.0, 220.0)]   # x, run-out, half width
# Wrinkle ridges on the plains: control points, and where along them (0..1) the passes are.
WRINKLE_RIDGES = [
    ([(-1750.0, 2450.0), (-1700.0, 2050.0), (-1600.0, 1650.0), (-1700.0, 1300.0), (-1950.0, 950.0), (-2150.0, 600.0), (-2250.0, 150.0)], [0.3, 0.72]),
    ([(-650.0, 2500.0), (-560.0, 2050.0), (-700.0, 1600.0), (-620.0, 1150.0), (-450.0, 800.0)], [0.45]),
]
# Scarps in the ice fields where clean ice shows: from, to, drop (m).
ICE_SCARPS = [((-1760.0, -1240.0), (-1380.0, -1330.0), 10.0), ((-1990.0, -700.0), (-1760.0, -610.0), 8.0)]


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
    lobe = 16.0 * ws * np.clip(1.0 - np.abs(d - 0.56) / 0.12, 0.0, 1.0) ** 0.7 * (1.0 + 0.25 * medium)
    calm = 1.0 - 0.75 * (1.0 - smoothstep(0.6, 0.85, d))           # quieter floor
    h *= calm
    h += crater + lobe
    masks["crater_d"] = d
    masks["crater_angle"] = angle
    masks["ejecta"] = ((d > 1.0) & (d < end)).astype(np.float32) * np.clip(np.power(np.maximum(d, 1.0), -2.0), 0, 1)
    # Secondary craters: chains of small elongated pits thrown out by the impact.
    rng = np.random.default_rng(SEED + 40)
    for _ in range(9):
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
    base_edge = -2030.0 + 90.0 * spectral_noise(3.4, SEED + 3, k_high=0.01)[0]
    spurs = spectral_noise(3.0, SEED + 4, k_low=0.008, k_high=0.03)
    edge = base_edge[None, :] + 45.0 * spurs   # spurs and alcoves
    plateau = z > edge
    bay_wobble = 22.0 * spectral_noise(3.0, SEED + 5, k_low=0.004, k_high=0.03)
    ramp_bay = np.zeros(h.shape, dtype=bool)
    for sx, length, width, is_ramp in SIDE_CANYONS:
        q = np.clip((z - base_edge[None, :]) / length, 0.0, 1.0)
        bay = (np.abs(x - sx + bay_wobble) < width * (1.0 - 0.45 * q)) & (z < base_edge[None, :] + length + 30.0 * spurs)
        plateau &= ~bay
        if is_ramp:
            ramp_bay |= bay
    u = box_blur(signed_distance(plateau), 8)   # > 0 on the plateau (smoothed: the chamfer distance is a little angular)
    # The cliff in three layers (hard caps over softer beds), talus below.
    v = np.clip((u + 90.0) / 90.0, 0.0, 1.0) * 3.0 + 0.15 * medium
    stair = (np.floor(v) + smoothstep(0.55, 1.0, v - np.floor(v))) / 3.0
    profile = np.where(u > -90.0, 0.45 + 0.55 * np.clip(stair, 0.0, 1.0),
                       0.45 * np.clip((u + 240.0) / 150.0, 0.0, 1.0) ** 1.6)
    profile = np.where(u >= 0.0, 1.0, profile)
    # The ramp canyon: its floor climbs steadily from the canyon floor to the plateau.
    into = np.clip((z - base_edge[None, :] + 240.0) / (SIDE_RAMP_LENGTH + 240.0), 0.0, 1.0)
    in_bay = smoothstep(4.0, 30.0, box_blur(distance_field(~ramp_bay), 6))
    profile = np.maximum(profile, in_bay * into)
    # The far wall: the same layers, rising north to the region's edge.
    far = (CANYON_FAR_EDGE + 40.0 * spectral_noise(3.4, SEED + 6, k_high=0.01)[0][None, :] + 30.0 * spurs) - z
    v2 = np.clip((far + 90.0) / 90.0, 0.0, 1.0) * 3.0 + 0.15 * medium
    stair2 = (np.floor(v2) + smoothstep(0.55, 1.0, v2 - np.floor(v2))) / 3.0
    far_profile = np.where(far >= 0.0, 1.0, np.where(far > -90.0, 0.45 + 0.55 * np.clip(stair2, 0.0, 1.0), 0.45 * np.clip((far + 200.0) / 110.0, 0.0, 1.0) ** 1.6))
    profile = np.maximum(profile, far_profile * (z < base_edge[None, :] - 150.0))
    h += -CANYON_DEPTH * (1.0 - profile)
    floor = (1.0 - smoothstep(-260.0, -200.0, u)) * (1.0 - smoothstep(-200.0, -150.0, far))
    h += 5.0 * medium * floor   # rough floor
    # Landslide tongues: lobes of debris run out across the floor.
    for lx, length, width in CANYON_LANDSLIDES:
        foot = float(np.interp(lx, row, base_edge)) - 200.0
        along = (foot - z) / length   # northward from the talus foot
        across = (x - lx) / width
        tongue = np.clip(1.0 - along, 0.0, 1.0) ** 0.6 * np.exp(-across * across * (1.0 + np.clip(along, -0.3, 1.0))) * (along > -0.3)
        h += 13.0 * tongue * (1.0 + 0.3 * medium) * smoothstep(-0.3, 0.0, along)
    masks["canyon_u"] = u
    masks["canyon_floor"] = floor
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
    rng = np.random.default_rng(SEED + 50)
    masks["mesa_body"] = np.zeros_like(h)
    masks["talus"] = np.zeros_like(h)
    bodies = []
    for index, (mx, mz, mr, mh) in enumerate(MESAS):
        bodies.append((mx, mz, mr, mh, MESA_RAMPS.get(index)))
        for _ in range(2):
            a = rng.uniform(-math.pi, math.pi)
            br = mr * rng.uniform(0.2, 0.3)
            bx = mx + math.cos(a) * mr * rng.uniform(1.7, 2.1); bz = mz + math.sin(a) * mr * rng.uniform(1.7, 2.1)
            if near_zone(bx, bz, br * 2.0):
                continue
            bodies.append((bx, bz, br, mh * rng.uniform(0.65, 0.9), None))
    for mx, mz, mr, mh, r_angle in bodies:
        reach = mr * 2.4
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
            wb = 1.0 - smoothstep(0.12, 0.24, np.abs(np.angle(np.exp(1j * (ang - r_angle)))))
            run = mh / (0.2 * mr)   # about 11 degrees, in mesa radii
            ramp = mh * np.clip(1.0 - (md - 0.78) / run, 0.0, 1.0)
            lift = np.maximum(lift, ramp * wb)
        h[win] += lift
        masks["mesa_body"][win] = np.maximum(masks["mesa_body"][win], 1.0 - smoothstep(0.88, 0.96, md))
        masks["talus"][win] = np.maximum(masks["talus"][win], smoothstep(0.9, 0.96, md) * (1.0 - smoothstep(1.2, 1.65, md)))
    masks["skirts"] = masks["talus"]
    masks["mesa_list"] = bodies


# ---------- wrinkle ridges ----------

def add_wrinkle_ridges(h, x, z, masks, medium):
    """Wrinkle ridges on the lava plains: a broad arch with a narrow crest
    on top, steep on one side, crenulated along its length, with a few low
    saddles (passes) where a rover can get over."""
    masks["ridges"] = np.zeros_like(h)
    rng = np.random.default_rng(SEED + 60)
    for control, passes in WRINKLE_RIDGES:
        control = np.array(control, dtype=float)
        # A smooth, sinuous line through the control points.
        fine = []
        for k in range(len(control) - 1):
            for s in np.linspace(0.0, 1.0, 12, endpoint=False):
                fine.append(control[k] + (control[k + 1] - control[k]) * s)
        fine.append(control[-1])
        fine = np.array(fine)
        normal = np.gradient(fine, axis=0)[:, ::-1] * np.array([1.0, -1.0])
        normal /= np.linalg.norm(normal, axis=1, keepdims=True)
        fine += normal * (30.0 * np.sin(np.linspace(0, 9.0, len(fine)) + rng.uniform(0, 6))[:, None])
        d, t, side = polyline_field(fine, 420.0, step=2)
        s = d * side   # signed: > 0 on the steep side
        taper = np.clip(np.sin(np.pi * np.clip(t, 0.0, 1.0)), 0.0, 1.0) ** 0.4
        low = np.ones_like(t)
        for p in passes:
            low -= 0.88 * np.exp(-((t - p) / 0.028) ** 2)
        crest_at = 25.0
        crest = np.where(s - crest_at > 0.0, np.exp(-((s - crest_at) / 16.0) ** 2), np.exp(-((s - crest_at) / 55.0) ** 2))
        crest *= 0.78 + 0.22 * np.sin(t * 140.0 + 2.0 * medium)
        arch = np.exp(-(s / 170.0) ** 2)
        lift = (9.0 * arch + 15.0 * crest) * taper * np.clip(low, 0.06, 1.0)
        h += lift
        masks["ridges"] = np.maximum(masks["ridges"], lift / 24.0)


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
    # Transverse ridges, about 65 m apart.
    phase = along / 65.0 + 0.25 * np.sin(across / 140.0 + 0.6 * medium) + 0.12 * medium
    f = phase - np.floor(phase)
    shape = np.where(f < 0.78, smoothstep(0.0, 1.0, f / 0.78), 1.0 - smoothstep(0.0, 1.0, (f - 0.78) / 0.22))
    core = smoothstep(0.35, 0.75, field)
    sand = 8.0 * core * shape ** 1.25 + 1.5 * field   # and a sand sheet under them
    # Barchans where the sand runs thin.
    rng = np.random.default_rng(SEED + 80)
    barchans = np.zeros_like(h)
    masks["barchan_list"] = []
    for _ in range(4000):
        if len(masks["barchan_list"]) >= 70:
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
    rng = np.random.default_rng(SEED + 91)
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
    add_canyon(h, x, z, masks, medium)
    add_big_crater(h, x, z, masks, medium, lobes_field, ragged_field)

    # The mound: layered, terraced, like a small Mount Sharp.
    mangle = np.arctan2(z - MOUND["centre"][1], x - MOUND["centre"][0])
    lobes = 1.0 + 0.16 * np.sin(mangle * 3.0 + 0.7) + 0.09 * np.sin(mangle * 7.0 + 2.1) + 0.08 * medium
    md = dist(x, z, MOUND["centre"]) / (MOUND["radius"] * lobes)
    rise = MOUND["height"] * np.clip(1.0 - md, 0.0, 1.0) ** 1.15 * (1.0 + 0.06 * medium)
    masks["mound"] = (md < 1.0).astype(float)
    terraces = np.floor(rise / 11.0) * 11.0
    h += 0.35 * rise + 0.65 * (terraces + 4.0 * smoothstep(0.55, 1.0, (rise % 11.0) / 11.0))   # benches and steps

    add_mesas(h, x, z, masks, medium, edge_warp)
    add_wrinkle_ridges(h, x, z, masks, medium)
    add_dunes(h, x, z, masks, medium, edge_warp, lobes_field)
    add_ice_ground(h, x, z, masks, medium, small, edge_warp)

    # Hills framing the edge of the region, ragged rather than square.
    ring = np.maximum(np.abs(x), z) + 160.0 * large   # the canyon's far wall is the northern edge
    h += (240.0 + 80.0 * large) * smoothstep(HALF - 650.0, HALF - 80.0, ring)

    trunk_floor = carve_river(h, x, z, masks, medium, lobes_field)
    add_valley_network(h, x, z, masks, trunk_floor)

    # Small craters of every age, except on the landing zones, the mound, the
    # mesas and the dunes.
    keep = [(ZONES[k]["centre"][0], ZONES[k]["centre"][1], ZONES[k]["flat_radius"] * 2.2) for k in ZONES]
    keep.append((MOUND["centre"][0], MOUND["centre"][1], MOUND["radius"]))
    keep += [(mx, mz, mr * 1.3) for mx, mz, mr, mh, _ in masks["mesa_list"]]
    keep.append((DUNES[0], DUNES[1], DUNES_RADIUS * 1.2))
    add_small_craters(h, x, z, np.random.default_rng(SEED + 9), 900, keep, masks)

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
DUST, BEDROCK, SAND, FROST, CLAY, GRAVEL, STRATA = range(7)
MATERIALS = [
    # name, base colour, dark colour, roughness, features
    ("dust", (178, 126, 96), (150, 102, 78), 0.93, {"ripples": (7, 0.05), "pebbles": (500, 2, 5)}),
    ("bedrock", (156, 112, 88), (118, 84, 68), 0.82, {"strata": (6, 0.2), "cracks": (55, 0.012, 0.35)}),
    ("sand", (110, 84, 74), (82, 63, 58), 0.9, {"ripples": (13, 0.2)}),
    ("frost", (226, 210, 200), (190, 164, 150), 0.55, {"cracks": (34, 0.02, 0.5), "crack_colour": (150, 104, 82)}),
    ("clay", (198, 152, 118), (172, 126, 96), 0.88, {"cracks": (130, 0.007, 0.28)}),
    ("gravel", (152, 108, 86), (116, 82, 68), 0.9, {"pebbles": (2600, 3, 13)}),
    # Pale layered sediment, like Mount Sharp's: the mound.
    ("strata", (206, 162, 126), (176, 132, 102), 0.86, {"strata": (9, 0.22), "cracks": (40, 0.006, 0.18)}),
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
        warp_u = uu + 0.015 * coarse
        warp_v = vv + 0.015 * coarse
        for r0 in range(0, n, 64):
            pu = warp_u[r0:r0 + 64, :, None]; pv = warp_v[r0:r0 + 64, :, None]
            du = np.abs(pu - seeds[None, None, :, 0]); du = np.minimum(du, 1 - du)
            dv = np.abs(pv - seeds[None, None, :, 1]); dv = np.minimum(dv, 1 - dv)
            dd = np.sqrt(du * du + dv * dv).astype(np.float32)
            part = np.partition(dd, 1, axis=2)
            edge[r0:r0 + 64] = part[:, :, 1] - part[:, :, 0]
        crack = 1.0 - smoothstep(0.0, width, edge)
        height -= depth * crack
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

def write_control(h, masks):
    """Terrain3D control map: per point a base texture (by zone), bedrock
    as the overlay, and a blend that follows the slope. Packed as uint32
    (base << 27 | overlay << 22 | blend << 14), stored raw little-endian."""
    dither = 0.12 * masks["noise"]
    base = np.full(h.shape, DUST, dtype=np.uint32)
    base[masks["skirts"] + dither > 0.45] = GRAVEL
    ejecta = (masks["crater_d"] > 1.0) & (masks["crater_d"] < 1.45 + dither)
    base[ejecta] = GRAVEL
    base[masks["canyon_floor"] + dither > 0.5] = GRAVEL
    base[(masks["crater_d"] < 0.7 + dither * 0.3) & (masks["mound"] < 0.5)] = CLAY
    base[masks["dunes"] + dither > 0.5] = SAND
    base[masks["ice"] + dither > 0.5] = FROST
    base[masks["mound"] > 0.5] = STRATA
    base[masks["river_floor"] > 0.5] = GRAVEL   # rounded river pebbles
    base[masks["delta"] > 0.5] = CLAY           # fine layered sediment
    gz, gx = np.gradient(h, SPACING)
    slope = np.sqrt(gx * gx + gz * gz)
    blend = np.clip(smoothstep(0.22, 0.6, slope) * 255.0, 0, 255).astype(np.uint32)
    masks["_base"] = base.astype(np.int64)
    blend[(base == SAND) | (base == FROST)] = 0   # dunes and ice stay sand and frost on their slopes
    control = (base << np.uint32(27)) | (np.uint32(BEDROCK) << np.uint32(22)) | (blend << np.uint32(14))
    data = gzip.compress(control.astype("<u4").tobytes(), compresslevel=9)
    write_file(os.path.join(OUT, "control.u32.gz"), lambda path: open(path, "wb").write(data))


def write_map(h, masks):
    """The region map: shaded relief coloured by ground type, 1024 px."""
    step = N // 1024
    hs = h[::step, ::step]
    colours = np.array([(196, 140, 104), (150, 106, 84), (104, 80, 70), (228, 216, 206), (214, 168, 128), (166, 120, 96), (222, 182, 146)], dtype=float) / 255.0
    control_base = masks["_base"][::step, ::step]
    rgb = colours[control_base]
    gz, gx = np.gradient(hs, SPACING * step)
    # Lit from the north-west (top left), as maps are: lit from anywhere
    # below, the eye reads craters as hills and hills as craters.
    shade = np.clip(0.82 + (gx + gz) * 1.4, 0.35, 1.25)[..., None]
    lift = (0.92 + 0.16 * (hs - hs.min()) / (hs.max() - hs.min()))[..., None]
    img = np.clip(rgb * shade * lift, 0, 1)
    write_file(os.path.join(OUT, "map.png"), Image.fromarray((img * 255).astype("uint8"), "RGB").save)


def write_colour(masks, h=None):
    """Terrain3D colour map at half resolution (the game scales it up):
    gentle large-scale darkening and hue shifts, like Mars's albedo patches.
    White is no change; alpha 0.5 leaves roughness alone."""
    large = masks["large"][::2, ::2]; medium = masks["medium"][::2, ::2]
    v = np.clip(0.93 + 0.05 * large + 0.025 * medium, 0.8, 1.0)
    red = np.clip(v * (1.0 + 0.02 * large), 0, 1)
    green = np.clip(v * (0.98 - 0.015 * medium), 0, 1)
    blue = np.clip(v * (0.96 - 0.02 * large), 0, 1)
    # Layers you can see from afar: light and dark bands by height on the
    # mound and the mesas (each band about 5 m of rock).
    if h is not None:
        hs = h[::2, ::2]
        layered = np.clip(masks["mound"][::2, ::2] + masks["mesa_body"][::2, ::2], 0, 1)
        bands = 0.5 + 0.5 * np.sin(hs / 5.2 * math.pi + 0.8 * masks["medium"][::2, ::2])
        shade = 1.0 - layered * (0.06 + 0.12 * bands)
        red *= shade; green *= shade * 0.99; blue *= shade * 0.97
    dunes = masks["dunes"][::2, ::2]
    red *= 1.0 - 0.08 * dunes; green *= 1.0 - 0.06 * dunes; blue *= 1.0 - 0.04 * dunes
    alpha = np.full(red.shape, 0.5)
    img = np.dstack([red, green, blue, alpha])
    write_file(os.path.join(OUT, "colour.png"), Image.fromarray((img * 255).astype("uint8"), "RGBA").save)


def main():
    os.makedirs(OUT, exist_ok=True)
    h, masks = build_heights()
    lo, hi = save_heights(h)
    write_control(h, masks)
    write_colour(masks, h)
    write_map(h, masks)
    for index, (name, base, dark, rough, features) in enumerate(MATERIALS if not QUICK else []):
        material_texture(name, base, dark, rough, dict(features), SEED + 20 + index)
    meta = {
        "id": REGION_ID,
        "size": N, "spacing": SPACING, "half": HALF,
        "height_min": lo, "height_max": hi,
        "zones": {k: {"centre": list(v["centre"]), "flat_radius": v["flat_radius"], "height": v["height"], "label": v["label"]} for k, v in ZONES.items()},
        "crater": CRATER, "mound": MOUND,
        "textures": [m[0] for m in MATERIALS],
        "features": [{"name": n, "position": list(p)} for n, p in FEATURES],
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
