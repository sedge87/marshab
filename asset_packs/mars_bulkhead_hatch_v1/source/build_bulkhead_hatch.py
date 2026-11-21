"""Blender (5.x) build script: the habitat's bulkhead hatch (21 Nov 2026).

Run:  blender --background --python build_bulkhead_hatch.py -- <out_dir>

Every habitat door except the Garage's hangar door (scripts/airlock_door.gd)
is this pressure hatch:
- a rounded frame through the wall;
- a 1.2 x 1.9 m opening over an 8 cm sill, wide enough for GAR-Y (1.04 m),
  which cycles the airlock by itself;
- a thick leaf on a left-hand hinge. Its parts are named leaf_* and the game
  swings them on the hinge line, x -0.71, y -0.205;
- a round window and an orange lever on each face of the leaf;
- on the frame: a gasket, bolts, a handrail each side, a warm light and
  status LEDs.

Blender +Y is the glTF front (-Z). No lettering (house rule). Built with
hq_kit.py.
"""
import math
import os
import sys

import bmesh

_HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(_HERE, "..", "..", "mars_hq_v1", "source", "hq_kit.py"), encoding="utf-8").read())


def _rrect(x0, x1, z0, z1, r, seg=8):
    """A rounded rectangle's outline in the XZ plane, anticlockwise from the bottom right."""
    r = min(r, (x1 - x0) / 2 - 1e-4, (z1 - z0) / 2 - 1e-4)
    corners = [(x1 - r, z0 + r, -90), (x1 - r, z1 - r, 0), (x0 + r, z1 - r, 90), (x0 + r, z0 + r, 180)]
    pts = []
    for cx, cz, a0 in corners:
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def _mesh_obj(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh); bm.free()
    return obj


def slab(name, x0, x1, z0, z1, r, y0, y1, mat, bevel=0.008):
    """A rounded-rectangle slab, y0 to y1 thick."""
    pts = _rrect(x0, x1, z0, z1, r)
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    return _finish(_mesh_obj(name, verts, faces), name, mat, bevel, 2)


def ring(name, outer, inner, y0, y1, mat, bevel=0.008):
    """A rounded-rectangle frame: outer and inner are (x0, x1, z0, z1, r)."""
    po = _rrect(*outer)
    pi = _rrect(*inner)
    n = len(po)
    verts = [(x, y0, z) for x, z in po] + [(x, y1, z) for x, z in po] + [(x, y0, z) for x, z in pi] + [(x, y1, z) for x, z in pi]
    OF, OB, IF, IB = 0, n, 2 * n, 3 * n
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append([OF + i, OF + j, IF + j, IF + i])      # y0 face
        faces.append([OB + i, IB + i, IB + j, OB + j])      # y1 face
        faces.append([OF + i, OB + i, OB + j, OF + j])      # outer wall
        faces.append([IF + i, IF + j, IB + j, IB + i])      # inner wall (the reveal)
    return _finish(_mesh_obj(name, verts, faces), name, mat, bevel, 2)


def lever(prefix, x, z, y, out):
    """A dogging lever on a hub, hanging down, standing off the face at y toward out (+1/-1)."""
    hub = cyl(f"{prefix}_hub", (x, y + out * 0.02, z), 0.05, 0.04, "dark_alloy", axis="y", verts=28, bevel=0.006)
    bar = rod(f"{prefix}_bar", (x, y + out * 0.045, z), (x, y + out * 0.045, z - 0.27), 0.017, "accent_orange", verts=16)
    knob = sphere(f"{prefix}_knob", (x, y + out * 0.045, z - 0.28), 0.026, "accent_orange", segments=16)
    return [hub, bar, knob]


def bulkhead_hatch():
    # ---------- the frame, through the wall ----------
    OUT = (-0.75, 0.75, 0.0, 2.24, 0.30)
    OPEN = (-0.60, 0.60, 0.08, 1.98, 0.20)
    D = 0.15
    ring("hatch_frame_shell_white", OUT, OPEN, -D, D, "shell_white", 0.012)
    for side, y0, y1 in (("front", D, D + 0.016), ("back", -D - 0.016, -D)):
        ring(f"hatch_trim_{side}_frame_graphite", (-0.69, 0.69, 0.02, 2.08, 0.26), OPEN, y0, y1, "frame_graphite", 0.004)
    # The seal the leaf closes on (back face, where the leaf sits).
    ring("hatch_gasket_black_rubber", (-0.65, 0.65, 0.05, 2.02, 0.23), (-0.61, 0.61, 0.075, 1.985, 0.205), -D - 0.026, -D - 0.016, "black_rubber", 0.002)
    box("hatch_tread_satin_alloy", -0.55, 0.55, -D + 0.01, D - 0.01, 0.08, 0.086, "satin_alloy", 0.002)
    for side, y, out in (("front", D + 0.016, 1), ("back", -D - 0.016, -1)):
        pts = [(x, z) for x in (-0.675, 0.675) for z in (0.35, 0.8, 1.25, 1.7)] + [(x, 2.12) for x in (-0.3, 0.0, 0.3)]
        bolts(f"hatch_bolts_{side}_satin_steel", pts, y if out > 0 else y - 0.012)
        box(f"hatch_light_{side}_led_warm", -0.26, 0.26, y if out > 0 else y - 0.006, y + 0.006 if out > 0 else y, 2.02, 2.045, "led_warm", 0)
        for i, c in enumerate(("led_green", "led_green", "led_red")):
            cyl(f"hatch_status_{side}_{i}_{c}", (0.42 + i * 0.024, y + out * 0.003, 2.035), 0.0055, 0.006, c, axis="y", verts=12)
        handrail(f"hatch_handrail_{side}_satin_alloy", (-0.92, out * 0.08, 0.85), (-0.92, out * 0.08, 1.55), standoff=0.06, axis_out=(0, out, 0))
    # A small equaliser vent on the front of the right jamb.
    vent("hatch_equaliser_vent", 0.62, 0.73, 1.25, 1.6, D + 0.016, slats=5)
    # The hinge knuckles (fixed): the leaf turns about x -0.71, y -0.205.
    for z in (0.42, 1.62):
        cyl(f"hatch_hinge_{int(z * 100)}_dark_alloy", (-0.71, -0.205, z), 0.032, 0.24, "dark_alloy", verts=20, bevel=0.004)

    # ---------- the leaf (swings toward -Y) ----------
    LY0, LY1 = -0.245, -0.172
    slab("leaf_panel_shell_white", -0.65, 0.65, 0.03, 2.03, 0.25, LY0, LY1, "shell_white", 0.012)
    slab("leaf_inset_front_panel_cool", -0.48, 0.48, 0.24, 1.28, 0.1, LY0 - 0.006, LY0, "panel_cool", 0.003)
    slab("leaf_inset_back_panel_cool", -0.48, 0.48, 0.24, 1.28, 0.1, LY1, LY1 + 0.005, "panel_cool", 0.003)
    for side, y, out in (("front", LY0, -1), ("back", LY1, 1)):
        cyl(f"leaf_window_rim_{side}_frame_graphite", (0.0, y + out * 0.006, 1.58), 0.155, 0.014, "frame_graphite", axis="y", verts=48, bevel=0.004)
        cyl(f"leaf_window_{side}_dark_glass", (0.0, y + out * 0.013, 1.58), 0.12, 0.004, "dark_glass", axis="y", verts=48)
        bolts(f"leaf_window_bolts_{side}_satin_steel", [(0.135 * math.cos(a * math.pi / 4), 1.58 + 0.135 * math.sin(a * math.pi / 4)) for a in range(8)], y if out > 0 else y - 0.012, r=0.006)
        join(f"leaf_lever_{side}_accent_orange", lever(f"lev_{side}", 0.44, 1.12, y, out))
    for z in (0.42, 1.62):
        box(f"leaf_strap_{int(z * 100)}_dark_alloy", -0.69, -0.42, LY0 - 0.008, LY0, z - 0.05, z + 0.05, "dark_alloy", 0.004)


MODELS = [("bulkhead_hatch", bulkhead_hatch, "wall")]
run()
