"""Remove lone height spikes from a region's heightmap (21 Nov playtest).

The playtest found sharp four-sided "pyramids" standing on open ground: each is
one height sample several metres above all eight of its neighbours (at 2 m
spacing Terrain3D draws a single raised point as a pyramid, and its steep faces
take the cliff texture). The source in tools/generate_region.py wasn't found;
generate_region.py now runs despike() before it saves, and this tool fixes an
existing height.r16.gz in place, touching only the spike samples.

    python tools/despike_heights.py [assets/terrain/test_region]
"""
import gzip
import json
import os
import sys

import numpy as np

RISE = 1.5      # metres above the highest neighbour: a spike
SPREAD = 2.5    # ... while the neighbours themselves sit within this (smooth ground, not a pinnacle's flank)


def despike(h, keep_out=()):
    """Lower each lone spike to the mean of its neighbours. keep_out: (x, z, radius, half, spacing)
    discs left alone (the layout's monuments). Returns how many samples changed."""
    n = h.shape[0]
    pad = np.pad(h, 1, mode="edge")
    around = np.stack([pad[1 + dy:1 + dy + n, 1 + dx:1 + dx + n] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx])
    top = around.max(axis=0)
    spread = top - around.min(axis=0)
    spike = (h - top > RISE) & (spread < SPREAD)
    for x, z, r, half, spacing in keep_out:
        i0, i1 = int((x - r + half) / spacing), int((x + r + half) / spacing) + 1
        j0, j1 = int((z - r + half) / spacing), int((z + r + half) / spacing) + 1
        spike[max(j0, 0):max(j1, 0), max(i0, 0):max(i1, 0)] = False
    h[spike] = around.mean(axis=0)[spike]
    return int(spike.sum())


def monuments(root):
    path = os.path.join(root, "data", "region_layout.json")
    if not os.path.exists(path):
        return []
    layout = json.load(open(path, encoding="utf-8"))
    out = []
    for value in layout.values() if isinstance(layout, dict) else []:
        if isinstance(value, list):
            for e in value:
                if isinstance(e, dict) and e.get("kind") == "monument" and "centre" in e:
                    out.append((float(e["centre"][0]), float(e["centre"][1]), float(e.get("radius", 8.0)) * 2.0))
    return out


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "terrain", "test_region")
    meta = json.load(open(os.path.join(folder, "region.json"), encoding="utf-8"))
    raw = gzip.open(os.path.join(folder, "height.r16.gz")).read()
    n = int(meta["size"])
    lo, hi = float(meta["height_min"]), float(meta["height_max"])
    spacing, half = float(meta["spacing"]), float(meta["half"])
    q = np.frombuffer(raw, dtype="<u2").reshape(n, n)
    h = lo + q.astype(np.float64) / 65535.0 * (hi - lo)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    keep = [(x, z, r, half, spacing) for x, z, r in monuments(root)]
    changed = despike(h, keep)
    # Same 16-bit range as before, so region.json's levels stay right.
    out = np.clip(np.round((h - lo) / (hi - lo) * 65535.0), 0, 65535).astype("<u2")
    open(os.path.join(folder, "height.r16.gz"), "wb").write(gzip.compress(out.tobytes(), compresslevel=9))
    print(f"despiked {changed} samples in {folder}")


if __name__ == "__main__":
    main()
