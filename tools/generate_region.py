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

Usage: python tools/generate_region.py [region_id]
"""
import gzip
import json
import math
import os
import sys
import time

import numpy as np
from PIL import Image

REGION_ID = sys.argv[1] if len(sys.argv) > 1 else "test_region"
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
MESAS = [(-760.0, 420.0, 170.0, 48.0), (-2050.0, 1650.0, 240.0, 62.0), (300.0, 1500.0, 140.0, 40.0), (-1950.0, 380.0, 110.0, 34.0), (2100.0, 1700.0, 260.0, 70.0)]


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


def add_small_craters(h, x, z, rng, count, keep_out):
    """Bowl craters with raised rims, sizes on a power law."""
    for _ in range(count):
        r = min(70.0, 4.0 * rng.random() ** -0.6)
        cx = rng.uniform(-HALF + 300, HALF - 300)
        cz = rng.uniform(-HALF + 300, HALF - 300)
        if any(math.hypot(cx - kx, cz - kz) < kr + r * 2.5 for kx, kz, kr in keep_out):
            continue
        reach = r * 2.4
        i0 = max(0, int((cx - reach + HALF) / SPACING)); i1 = min(N, int((cx + reach + HALF) / SPACING) + 1)
        j0 = max(0, int((cz - reach + HALF) / SPACING)); j1 = min(N, int((cz + reach + HALF) / SPACING) + 1)
        if i1 <= i0 or j1 <= j0:
            continue
        d = dist(x[j0:j1, i0:i1], z[j0:j1, i0:i1], (cx, cz)) / r
        depth = 0.2 * r
        bowl = np.where(d < 1.0, -depth * (1.0 - d * d), 0.0)
        rim = 0.05 * r * np.exp(-((d - 1.0) / 0.32) ** 2)
        ejecta = np.where(d > 1.0, 0.03 * r * np.exp(-(d - 1.0) * 2.2), 0.0)
        h[j0:j1, i0:i1] += bowl + rim + ejecta


def build_heights():
    x, z = grid()
    large = spectral_noise(3.6, SEED, k_high=0.012)
    medium = spectral_noise(3.0, SEED + 1, k_low=0.006, k_high=0.06)
    small = spectral_noise(2.2, SEED + 2, k_low=0.05)
    h = 34.0 * large + 2.6 * medium + 0.22 * small
    lobes_field = spectral_noise(3.8, SEED + 30, k_high=0.008)
    ragged_field = spectral_noise(3.0, SEED + 31, k_low=0.006, k_high=0.035)

    def edge_warp(shift, lobes=0.35, ragged=0.13):
        """How far a zone's edge is pushed in or out here (in zone radii)."""
        return lobes * np.roll(lobes_field, (shift, shift * 2), (0, 1)) + ragged * np.roll(ragged_field, (shift * 3, shift), (0, 1))

    # The canyon: a 170 m scarp along the north edge with gullies, floor below.
    edge = -2050.0 + 90.0 * spectral_noise(3.4, SEED + 3, k_high=0.01)[0:1, :]   # wobble along x
    gullies = 40.0 * np.sin(x / 47.0 + 3.0 * medium) * smoothstep(-2350.0, -2150.0, z) * (1 - smoothstep(-2150.0, -1950.0, z))
    canyon = -170.0 * (1.0 - smoothstep(edge - 160.0, edge + 40.0, z))
    h += canyon + gullies * 0.25
    h += 6.0 * medium * (1.0 - smoothstep(edge - 160.0, edge, z))   # rough floor

    # The crater: bowl, wall, raised rim and ejecta, with a wobbly outline.
    cx, cz = CRATER["centre"]
    angle = np.arctan2(z - cz, x - cx)
    radius = CRATER["radius"] * (1.0 + 0.035 * np.sin(angle * 5.0 + 1.3) + 0.02 * np.sin(angle * 11.0))
    d = dist(x, z, (cx, cz)) / radius
    floor = -CRATER["depth"]
    wall = floor + (CRATER["depth"] + CRATER["rim"]) * smoothstep(0.72, 1.0, d)
    outside = CRATER["rim"] * np.exp(-(d - 1.0) / 0.28)
    crater = np.where(d < 1.0, wall, outside)
    calm = 1.0 - 0.75 * (1.0 - smoothstep(0.6, 0.85, d))           # quieter floor
    h = h * calm + crater
    # The crater floor's clay and the ejecta blanket get ragged edges of their own.
    masks = {"crater_d": d + edge_warp(170, 0.12, 0.05), "canyon_floor": 1.0 - smoothstep(edge - 120.0, edge - 40.0, z)}

    # The mound: layered, terraced, like a small Mount Sharp.
    mangle = np.arctan2(z - MOUND["centre"][1], x - MOUND["centre"][0])
    lobes = 1.0 + 0.16 * np.sin(mangle * 3.0 + 0.7) + 0.09 * np.sin(mangle * 7.0 + 2.1) + 0.08 * medium
    md = dist(x, z, MOUND["centre"]) / (MOUND["radius"] * lobes)
    rise = MOUND["height"] * np.clip(1.0 - md, 0.0, 1.0) ** 1.15 * (1.0 + 0.06 * medium)
    masks["mound"] = (md < 1.0).astype(float)
    terraces = np.floor(rise / 11.0) * 11.0
    h += 0.35 * rise + 0.65 * (terraces + 4.0 * smoothstep(0.55, 1.0, (rise % 11.0) / 11.0))   # benches and steps

    # Dunes between the plains and the canyon.
    # Stretched along the wind, with lobes and fingers.
    wind = np.array(DUNE_WIND)
    along = ((x - DUNES[0]) * wind[0] + (z - DUNES[1]) * wind[1]) / (DUNES_RADIUS * 1.8)
    across = (-(x - DUNES[0]) * wind[1] + (z - DUNES[1]) * wind[0]) / DUNES_RADIUS
    dd = np.sqrt(along * along + across * across) + edge_warp(410, 0.18, 0.09) + 0.08 * np.sin(across * 9.0 + 3.0 * lobes_field)
    dune_mask = 1.0 - smoothstep(0.75, 1.05, dd)
    masks["dunes"] = dune_mask
    phase = (x * DUNE_WIND[0] + z * DUNE_WIND[1]) / 52.0 + 2.5 * medium   # crests across the wind
    h += dune_mask * 7.0 * np.abs(np.sin(phase)) ** 1.6

    # Ice fields to the north-east: lower, smooth, cracked into polygons.
    # Several patches run together, with a ragged edge.
    idist = np.min(np.stack([dist(x, z, (bx, bz)) / br for bx, bz, br in ICE_PATCHES]), axis=0) + edge_warp(820, 0.3, 0.14)
    ice_mask = 1.0 - smoothstep(0.78, 1.08, idist)
    masks["ice"] = ice_mask
    warp = 6.0 * medium
    poly = np.minimum(np.abs(np.sin((x + warp) / 9.0)), np.abs(np.sin((z - warp) / 9.0)))
    h = h * (1.0 - 0.6 * ice_mask)                                    # smoother ground
    h += ice_mask * (-18.0 - 0.45 * (1.0 - smoothstep(0.0, 0.25, poly)))

    # Mesas: flat-topped buttes with steep, crumbling sides.
    skirts = np.zeros_like(h)
    for mx, mz, mr, mh in MESAS:
        md = dist(x, z, (mx, mz)) / (mr * (1.0 + 0.12 * medium)) + edge_warp(int(mx) % 997, 0.22, 0.06)
        skirts = np.maximum(skirts, np.exp(-((md - 1.25) / 0.3) ** 2))
        h += mh * (1.0 - smoothstep(0.82, 1.08, md)) + mh * 0.25 * np.exp(-((md - 1.1) / 0.18) ** 2)

    masks["skirts"] = skirts
    masks["noise"] = small
    masks["large"] = large
    masks["medium"] = medium

    # Hills framing the edge of the region, ragged rather than square.
    ring = np.maximum(np.abs(x), np.abs(z)) + 160.0 * large
    h += (240.0 + 80.0 * large) * smoothstep(HALF - 650.0, HALF - 80.0, ring)

    # Small craters everywhere except the landing zones, the mound and the canyon.
    keep = [(ZONES[k]["centre"][0], ZONES[k]["centre"][1], ZONES[k]["flat_radius"] * 2.2) for k in ZONES]
    keep.append((MOUND["centre"][0], MOUND["centre"][1], MOUND["radius"]))
    keep += [(mx, mz, mr) for mx, mz, mr, mh in MESAS]
    add_small_craters(h, x, z, np.random.default_rng(SEED + 9), 900, keep)

    # Landing zones: a level pad that blends into the land around it.
    for zone in ZONES.values():
        zd = dist(x, z, zone["centre"])
        r = zone["flat_radius"]
        j = int((zone["centre"][1] + HALF) / SPACING); i = int((zone["centre"][0] + HALF) / SPACING)
        level = float(h[j - 20:j + 20, i - 20:i + 20].mean())
        blend = smoothstep(r, r * 3.2, zd)
        h = level + (h - level) * blend   # exactly level inside the flat radius
        zone["height"] = level
    return h, masks


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
DUST, BEDROCK, SAND, FROST, CLAY, GRAVEL = range(6)
MATERIALS = [
    # name, base colour, dark colour, roughness, features
    ("dust", (178, 126, 96), (150, 102, 78), 0.93, {"ripples": (7, 0.05), "pebbles": (500, 2, 5)}),
    ("bedrock", (156, 112, 88), (118, 84, 68), 0.82, {"strata": (6, 0.2), "cracks": (55, 0.012, 0.35)}),
    ("sand", (110, 84, 74), (82, 63, 58), 0.9, {"ripples": (13, 0.2)}),
    ("frost", (226, 210, 200), (190, 164, 150), 0.55, {"cracks": (34, 0.02, 0.5), "crack_colour": (150, 104, 82)}),
    ("clay", (198, 152, 118), (172, 126, 96), 0.88, {"cracks": (130, 0.007, 0.28)}),
    ("gravel", (152, 108, 86), (116, 82, 68), 0.9, {"pebbles": (2600, 3, 13)}),
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
    base[masks["mound"] > 0.5] = BEDROCK
    gz, gx = np.gradient(h, SPACING)
    slope = np.sqrt(gx * gx + gz * gz)
    blend = np.clip(smoothstep(0.22, 0.6, slope) * 255.0, 0, 255).astype(np.uint32)
    masks["_base"] = base.astype(np.int64)
    blend[base == BEDROCK] = 255
    blend[(base == SAND) | (base == FROST)] = 0   # dunes and ice stay sand and frost on their slopes
    control = (base << np.uint32(27)) | (np.uint32(BEDROCK) << np.uint32(22)) | (blend << np.uint32(14))
    data = gzip.compress(control.astype("<u4").tobytes(), compresslevel=9)
    write_file(os.path.join(OUT, "control.u32.gz"), lambda path: open(path, "wb").write(data))


def write_map(h, masks):
    """The region map: shaded relief coloured by ground type, 1024 px."""
    step = N // 1024
    hs = h[::step, ::step]
    colours = np.array([(196, 140, 104), (150, 106, 84), (104, 80, 70), (228, 216, 206), (214, 168, 128), (166, 120, 96)], dtype=float) / 255.0
    control_base = masks["_base"][::step, ::step]
    rgb = colours[control_base]
    gz, gx = np.gradient(hs, SPACING * step)
    shade = np.clip(0.82 - (gx + gz) * 1.4, 0.35, 1.25)[..., None]
    lift = (0.92 + 0.16 * (hs - hs.min()) / (hs.max() - hs.min()))[..., None]
    img = np.clip(rgb * shade * lift, 0, 1)
    write_file(os.path.join(OUT, "map.png"), Image.fromarray((img * 255).astype("uint8"), "RGB").save)


def write_colour(masks):
    """Terrain3D colour map at half resolution (the game scales it up):
    gentle large-scale darkening and hue shifts, like Mars's albedo patches.
    White is no change; alpha 0.5 leaves roughness alone."""
    large = masks["large"][::2, ::2]; medium = masks["medium"][::2, ::2]
    v = np.clip(0.93 + 0.05 * large + 0.025 * medium, 0.8, 1.0)
    red = np.clip(v * (1.0 + 0.02 * large), 0, 1)
    green = np.clip(v * (0.98 - 0.015 * medium), 0, 1)
    blue = np.clip(v * (0.96 - 0.02 * large), 0, 1)
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
    write_colour(masks)
    write_map(h, masks)
    for index, (name, base, dark, rough, features) in enumerate(MATERIALS):
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
