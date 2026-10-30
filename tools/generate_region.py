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
  ground_*.png    Terrain3D textures: albedo + height (alpha), normal + roughness (alpha)

Usage: python tools/generate_region.py [region_id]
"""
import gzip
import json
import math
import os
import sys

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
MESAS = [(-760.0, 420.0, 170.0, 48.0), (-2050.0, 1650.0, 240.0, 62.0), (300.0, 1500.0, 140.0, 40.0), (-1950.0, 380.0, 110.0, 34.0), (2100.0, 1700.0, 260.0, 70.0)]


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

    # The mound: layered, terraced, like a small Mount Sharp.
    md = dist(x, z, MOUND["centre"]) / MOUND["radius"]
    rise = MOUND["height"] * np.clip(1.0 - md, 0.0, 1.0) ** 1.4
    terraces = np.floor(rise / 11.0) * 11.0
    h += 0.55 * rise + 0.45 * (terraces + 3.0 * smoothstep(0.0, 1.0, (rise % 11.0) / 11.0))

    # Dunes between the plains and the canyon.
    dd = dist(x, z, (-150.0, -1350.0))
    dune_mask = 1.0 - smoothstep(450.0, 800.0, dd)
    phase = (x * 0.8 + z * 0.6) / 52.0 + 2.5 * medium
    h += dune_mask * 7.0 * np.abs(np.sin(phase)) ** 1.6

    # Ice fields to the north-east: lower, smooth, cracked into polygons.
    idist = dist(x, z, (-1500.0, -1100.0))
    ice_mask = 1.0 - smoothstep(500.0, 900.0, idist)
    warp = 6.0 * medium
    poly = np.minimum(np.abs(np.sin((x + warp) / 9.0)), np.abs(np.sin((z - warp) / 9.0)))
    h = h * (1.0 - 0.6 * ice_mask)                                    # smoother ground
    h += ice_mask * (-18.0 - 0.45 * (1.0 - smoothstep(0.0, 0.25, poly)))

    # Mesas: flat-topped buttes with steep, crumbling sides.
    for mx, mz, mr, mh in MESAS:
        md = dist(x, z, (mx, mz)) / (mr * (1.0 + 0.12 * medium))
        h += mh * (1.0 - smoothstep(0.82, 1.08, md)) + mh * 0.25 * np.exp(-((md - 1.1) / 0.18) ** 2)

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
    return h


def save_heights(h):
    lo, hi = float(h.min()) - 1.0, float(h.max()) + 1.0
    q = np.clip(np.round((h - lo) / (hi - lo) * 65535.0), 0, 65535).astype("<u2")
    with open(os.path.join(OUT, "height.r16.gz"), "wb") as f:
        f.write(gzip.compress(q.tobytes(), compresslevel=9))
    # Each zone's level as stored (after rounding to 16 bits), so its pad reads
    # exactly 0 in the game.
    for zone in ZONES.values():
        code = round((zone["height"] - lo) / (hi - lo) * 65535.0)
        zone["height"] = lo + code / 65535.0 * (hi - lo)
    return lo, hi


def texture(name, base, dark, seed, ripple, layers, rough):
    """A seamless 1024 px ground texture for Terrain3D: albedo with height in
    alpha, and an OpenGL normal map with roughness in alpha."""
    n = 1024
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
    height = 0.5 + 0.18 * coarse + 0.08 * grain
    u = np.arange(n) / n
    uu, vv = np.meshgrid(u, u)
    if ripple:
        height += 0.12 * np.sin((uu * 2 + vv) * math.tau * 6 + 1.5 * coarse)
    if layers:
        height += 0.16 * np.abs(np.sin(vv * math.tau * 5 + 0.8 * coarse)) - 0.1 * (np.abs(noise(2.6)) > 1.6)
    height = np.clip((height - height.min()) / (height.max() - height.min()), 0, 1)
    shade = 0.82 + 0.3 * (height - 0.5) + 0.05 * grain
    base = np.array(base) / 255.0; dark = np.array(dark) / 255.0
    mix = np.clip(0.5 + 0.35 * coarse, 0, 1)[..., None]
    rgb = (base * (1 - mix) + dark * mix) * shade[..., None]
    alb = np.dstack([np.clip(rgb, 0, 1), height])
    Image.fromarray((alb * 255).astype("uint8"), "RGBA").save(os.path.join(OUT, f"ground_{name}_albedo_height.png"))
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 6.0
    gz = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 6.0
    nrm = np.dstack([-gx, gz, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    rgh = np.clip(rough + 0.05 * grain, 0, 1)
    img = np.dstack([nrm * 0.5 + 0.5, rgh])
    Image.fromarray((img * 255).astype("uint8"), "RGBA").save(os.path.join(OUT, f"ground_{name}_normal_roughness.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    h = build_heights()
    lo, hi = save_heights(h)
    texture("dust", (170, 120, 92), (140, 94, 70), SEED + 20, ripple=True, layers=False, rough=0.92)
    texture("rock", (122, 84, 66), (88, 62, 52), SEED + 21, ripple=False, layers=True, rough=0.8)
    meta = {
        "id": REGION_ID,
        "size": N, "spacing": SPACING, "half": HALF,
        "height_min": lo, "height_max": hi,
        "zones": {k: {"centre": list(v["centre"]), "flat_radius": v["flat_radius"], "height": v["height"], "label": v["label"]} for k, v in ZONES.items()},
        "crater": CRATER, "mound": MOUND,
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
    Image.fromarray(img).save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
