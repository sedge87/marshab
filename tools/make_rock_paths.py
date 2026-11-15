"""Write scenes/terrain/rock_paths.tscn (B5 step 7): Path3D rock paths (scripts/tools/rock_path.gd) along
the feet of the region's scarps, the east front, the glacier's moraines, the raised riverbeds' caprock and
the ice scarps. Each path is drawn relative to an anchor, and lies where the generated land actually has
the foot of its feature (found from the heights), so run this after a build that moved them:

    python tools/make_rock_paths.py

The scene can be hand-edited in Godot afterwards (move points, change spacing), but running this again
writes it afresh.
"""
import gzip
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import region_layout  # noqa: E402

REGION = os.path.join(ROOT, "assets", "terrain", "test_region")
OUT = os.path.join(ROOT, "scenes", "terrain", "rock_paths.tscn")

meta = json.load(open(os.path.join(REGION, "region.json")))
N = meta["size"]; S = meta["spacing"]; HALF = meta["half"]; lo = meta["height_min"]; hi = meta["height_max"]
H = np.frombuffer(gzip.decompress(open(os.path.join(REGION, "height.r16.gz"), "rb").read()), "<u2").reshape(N, N) / 65535.0 * (hi - lo) + lo
ANCHORS = {a["id"]: a for a in meta.get("anchors", [])}
LAYOUT = region_layout.load()
BY_ID = {e["id"]: e for e in LAYOUT["landforms"]}


def height(x, z):
    i = min(max((x + HALF) / S, 0.0), N - 1.001); j = min(max((z + HALF) / S, 0.0), N - 1.001)
    i0 = int(i); j0 = int(j); fi = i - i0; fj = j - j0
    return (H[j0, i0] * (1 - fi) * (1 - fj) + H[j0, i0 + 1] * fi * (1 - fj) + H[j0 + 1, i0] * (1 - fi) * fj + H[j0 + 1, i0 + 1] * fi * fj)


def resample(points, step):
    pts = np.array(points, dtype=float)
    seg = np.hypot(*np.diff(pts, axis=0).T); cum = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.arange(0.0, cum[-1] + 0.01, step)
    return np.stack([np.interp(t, cum, pts[:, 0]), np.interp(t, cum, pts[:, 1])], axis=1)


def foot_line(points, low_side, reach=180.0, step=20.0, share=0.15):
    """Along a line, the foot of the slope on its `low_side` (+1: left of travel): searching across the line,
    the first point (from the low side in) where the ground has risen `share` of the way to the high ground."""
    out = []
    for k, p in enumerate(resample(points, step)):
        q = resample(points, step)
        a = q[max(k - 1, 0)]; b = q[min(k + 1, len(q) - 1)]
        d = (b - a) / max(np.hypot(*(b - a)), 1e-6)
        left = np.array([-d[1], d[0]])
        offs = np.arange(-reach, reach + 0.1, 2.0)
        prof = np.array([height(*(p + left * low_side * -o)) for o in offs])   # o < 0: towards the low side
        low = np.percentile(prof[:len(offs) // 3], 30); top = np.percentile(prof[-len(offs) // 3:], 70)
        if top - low < 3.0:
            continue
        rise = np.where(prof > low + share * (top - low))[0]
        if len(rise) == 0:
            continue
        o = offs[rise[0]] - 4.0
        out.append(p + left * low_side * -o)
    return out


def ice_foot(e, t0=0.1, t1=0.9, n=12):
    pts = np.array(e["points"], dtype=float)
    f = np.array(e.get("faces", [0.0, -1.0]), dtype=float); f /= np.linalg.norm(f)
    want = np.array([-f[1], f[0]])
    if float(np.dot(pts[-1] - pts[0], want)) < 0.0:
        pts = pts[::-1]
    run = float(e.get("height", 10.0)) / math.tan(math.radians(e.get("face_deg", 55.0)))
    out = []
    seg = np.hypot(*np.diff(pts, axis=0).T); cum = np.concatenate([[0.0], np.cumsum(seg)])
    for t in np.linspace(t0, t1, n):
        at = t * cum[-1]; k = int(np.clip(np.searchsorted(cum, at) - 1, 0, len(seg) - 1))
        q = pts[k] + (pts[k + 1] - pts[k]) * ((at - cum[k]) / max(seg[k], 1e-6))
        d = (pts[k + 1] - pts[k]) / max(seg[k], 1e-6)
        out.append(q - np.array([-d[1], d[0]]) * (run + 7.0))
    return out


def moraine_arc(e, r=1.1, n=16):
    axis = np.array(e["flow"], dtype=float); axis /= np.linalg.norm(axis)
    side = np.array([-axis[1], axis[0]])
    o = np.array(e["from"], dtype=float)
    out = []
    for th in np.linspace(-1.0, 1.0, n):
        u = r * math.cos(th); v = r * math.sin(th)
        out.append(o + axis * u * e["length"] + side * v * e["width"] * 0.5)
    return out


def path_node(name, anchor, pts, spacing=3.0, spread=3.0, scale=(0.5, 1.6), seed=1):
    if anchor not in ANCHORS or len(pts) < 2:
        print(f"  {name}: skipped ({'no anchor ' + anchor if anchor not in ANCHORS else 'no foot found'})")
        return None
    ax, az = ANCHORS[anchor]["position"]
    data = []
    for p in pts:
        data += [0, 0, 0, 0, 0, 0, round(float(p[0] - ax), 2), 0, round(float(p[1] - az), 2)]
    print(f"  {name}: {len(pts)} points from {anchor}")
    return {"name": name, "anchor": anchor, "points": data, "count": len(pts), "spacing": spacing, "spread": spread, "scale": scale, "seed": seed}


def main():
    paths = []
    for sid in ("north_scarp", "east_front"):
        e = BY_ID[sid]
        # the generator's high side is left of travel when up = +1, so the low side (the foot) is -up
        paths.append(path_node(f"{sid}_foot", f"{sid}.centre", foot_line(e["points"], -float(e["up"])), spacing=2.6, spread=6.0, seed=len(paths) + 1))
    g = BY_ID["glacier"]
    for k, r in enumerate((1.06, 1.14)):
        paths.append(path_node(f"glacier_moraine_{k + 1}", "glacier.toe", moraine_arc(g, r), spacing=2.4, spread=4.0, scale=(0.5, 1.5), seed=len(paths) + 1))
    rb = BY_ID["raised_riverbeds"]
    for side in (1.0, -1.0):
        paths.append(path_node(f"riverbed_caprock_{'left' if side > 0 else 'right'}", "raised_riverbeds.centre",
                               foot_line(rb["points"], side, reach=60.0, step=16.0, share=0.3), spacing=3.5, spread=3.0, scale=(0.4, 1.2), seed=len(paths) + 1))
    for e in LAYOUT["landforms"]:
        if e["kind"] == "ice_scarp":
            paths.append(path_node(f"{e['id']}_foot", f"{e['id']}.chip", ice_foot(e), spacing=2.2, spread=4.0, scale=(0.4, 1.4), seed=len(paths) + 1))
    paths = [p for p in paths if p]
    lines = ['[gd_scene load_steps=%d format=3]' % (len(paths) + 2), '',
             '[ext_resource type="Script" path="res://scripts/tools/rock_path.gd" id="1"]', '']
    for k, p in enumerate(paths):
        lines += [f'[sub_resource type="Curve3D" id="Curve3D_{k}"]', '_data = {',
                  '"points": PackedVector3Array(' + ", ".join(str(v) for v in p["points"]) + '),',
                  '"tilts": PackedFloat32Array(' + ", ".join("0" for _ in range(p["count"])) + ')', '}', f'point_count = {p["count"]}', '']
    lines += ['[node name="RockPaths" type="Node3D"]', '']
    for k, p in enumerate(paths):
        lines += [f'[node name="{p["name"]}" type="Path3D" parent="."]', f'curve = SubResource("Curve3D_{k}")', 'script = ExtResource("1")',
                  f'anchor = "{p["anchor"]}"', f'spacing = {p["spacing"]}', f'scale_range = Vector2({p["scale"][0]}, {p["scale"][1]})',
                  f'spread = {p["spread"]}', f'rng_seed = {p["seed"]}', '']
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"wrote {OUT}: {len(paths)} paths")


if __name__ == "__main__":
    main()
