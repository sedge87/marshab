"""HQ kit: the Forward+ quality pass for Outpost One models (31 Oct 2026).

The earlier packs were made for the Compatibility renderer: plain colours that
the game's house materials (scripts/mh_palette.gd) flatten further, so they
read flat and washed out. This kit keeps the house look (ISS and The Martian:
off-white composite shells, graphite frames, satin metal, Nomex soft goods,
one orange accent) and adds what Forward+ can show:

  - surface detail: seams, fasteners, stitched soft goods, ID plates,
    cable runs, handrails, slim LED strips. No lettering anywhere: text
    belongs only on working displays, which the game draws live;
  - physically based materials: real metal, roughness that varies, edge wear,
    fabric weave, light grime in the corners;
  - all of it baked (Cycles) into one texture atlas per model: base colour
    with ambient occlusion, a normal map (rounded edges, weave, seams) and an
    occlusion-roughness-metal map.

Textured materials are left alone by the house palette, so the bake survives
in the game. Accent, glass and glowing parts stay plain materials on their own
meshes: the accent still follows the colony colour, screens still glow.

Use from a model script:
    exec(open(<this file>).read())
    def my_model(): ...            # build with box/cyl/rod/... and HQ materials
    MODELS = [("id", my_model, "floor")]
    run()                          # builds, bakes, exports, previews

Geometry helpers come from the furnishings pack (box, cyl, rod, torus, join,
gasket, vent, bolts, handle, cushion). Metres, floor origin, front faces -Z in
glTF (Blender +Y here). Mesh names are component_material, so the game's
interaction rig finds parts by component.

Importing: zip the WHOLE pack folder (source, textures and previews too).
tools/import_asset_pack.py replaces asset_packs/<pack>/ with the zip's
contents, so a zip of the models alone would delete the source.
"""
import json
import math
import os
import time

import bpy
import bmesh
import numpy as np
from mathutils import Vector

_HQ_HERE = os.path.dirname(os.path.abspath(__file__))
_FURN = os.path.join(_HQ_HERE, "..", "..", "mars_habitat_furnishings_v1", "source", "build_furnishings.py")
_FURN_TEXT = open(_FURN, encoding="utf-8").read()
exec(_FURN_TEXT.split("def galley_table_set")[0])

BAKE_SIZE = 2048
BAKE_SAMPLES = 8
# Materials that are never baked: the accent (follows the colony colour),
# glass, and anything that glows.
NO_BAKE_WORDS = ("orange", "glass", "screen", "led", "lamp", "emit")


# ---------- materials ----------

def _node(nodes, kind, x, y, **props):
    n = nodes.new(kind)
    n.location = (x, y)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def pbr(name, colour, rough, metal=0.0, rough_var=0.08, bump=0.15, bump_scale=90.0, wear=0.0, wear_colour=None,
        grime=0.12, weave=0.0, weave_scale=420.0, brushed=False, bevel=0.004, emission=0.0, alpha=1.0):
    """A procedural PBR material: varied roughness, worn edges, light grime,
    an optional fabric weave or brushed grain, and rounded edges (bevel)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.location = (600, 0)
    rgba = tuple(colour) + ((alpha,) if len(colour) == 3 else ())
    coord = _node(nodes, "ShaderNodeTexCoord", -1400, 0)
    # Roughness: a fine mottle, stretched along X for brushed metal.
    mapping = _node(nodes, "ShaderNodeMapping", -1200, 200)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    if brushed: mapping.inputs["Scale"].default_value = (2.0, 60.0, 60.0)
    mottle = _node(nodes, "ShaderNodeTexNoise", -1000, 200)
    mottle.inputs["Scale"].default_value = 22.0
    mottle.inputs["Detail"].default_value = 8.0
    links.new(mapping.outputs["Vector"], mottle.inputs["Vector"])
    rough_map = _node(nodes, "ShaderNodeMapRange", -800, 200)
    rough_map.inputs["To Min"].default_value = max(0.02, rough - rough_var)
    rough_map.inputs["To Max"].default_value = min(1.0, rough + rough_var)
    links.new(mottle.outputs["Fac"], rough_map.inputs["Value"])
    # Grime: large soft blotches that darken a little.
    blotch = _node(nodes, "ShaderNodeTexNoise", -1000, -200)
    blotch.inputs["Scale"].default_value = 3.0
    blotch.inputs["Detail"].default_value = 4.0
    links.new(coord.outputs["Object"], blotch.inputs["Vector"])
    grime_ramp = _node(nodes, "ShaderNodeMapRange", -800, -200)
    grime_ramp.inputs["From Min"].default_value = 0.45
    grime_ramp.inputs["From Max"].default_value = 0.75
    grime_ramp.inputs["To Min"].default_value = 1.0
    grime_ramp.inputs["To Max"].default_value = 1.0 - grime
    links.new(blotch.outputs["Fac"], grime_ramp.inputs["Value"])
    base_rgb = _node(nodes, "ShaderNodeRGB", -800, -450)
    base_rgb.outputs[0].default_value = rgba[:3] + (1.0,)
    tint = _node(nodes, "ShaderNodeMix", -550, -300, data_type="RGBA", blend_type="MULTIPLY")
    tint.inputs["Factor"].default_value = 1.0
    links.new(base_rgb.outputs[0], tint.inputs[6])
    gval = _node(nodes, "ShaderNodeCombineColor", -650, -150)
    for ch in ("Red", "Green", "Blue"): links.new(grime_ramp.outputs["Result"], gval.inputs[ch])
    links.new(gval.outputs["Color"], tint.inputs[7])
    colour_out = tint.outputs[2]
    rough_out = rough_map.outputs["Result"]
    # Rounded edges: the bevel normal; edges are where it leaves the face normal.
    bev = _node(nodes, "ShaderNodeBevel", -400, -700)
    bev.inputs["Radius"].default_value = bevel
    bev.samples = 8
    normal_in = bev.outputs["Normal"]
    if wear > 0:
        geo = _node(nodes, "ShaderNodeNewGeometry", -400, -900)
        dot = _node(nodes, "ShaderNodeVectorMath", -200, -800, operation="DOT_PRODUCT")
        links.new(bev.outputs["Normal"], dot.inputs[0])
        links.new(geo.outputs["Normal"], dot.inputs[1])
        edge = _node(nodes, "ShaderNodeMapRange", 0, -800)
        edge.inputs["From Min"].default_value = 0.995
        edge.inputs["From Max"].default_value = 0.93
        links.new(dot.outputs["Value"], edge.inputs["Value"])
        chip = _node(nodes, "ShaderNodeMath", 150, -800, operation="MULTIPLY")
        chip.inputs[1].default_value = wear
        links.new(edge.outputs["Result"], chip.inputs[0])
        worn = _node(nodes, "ShaderNodeMix", 300, -300, data_type="RGBA", blend_type="MIX")
        links.new(chip.outputs["Value"], worn.inputs["Factor"])
        links.new(colour_out, worn.inputs[6])
        wc = wear_colour or tuple(min(1.0, c * 1.12 + 0.04) for c in rgba[:3])
        worn.inputs[7].default_value = tuple(wc) + (1.0,)
        colour_out = worn.outputs[2]
        smooth = _node(nodes, "ShaderNodeMath", 300, 200, operation="SUBTRACT")
        links.new(rough_out, smooth.inputs[0])
        smooth_k = _node(nodes, "ShaderNodeMath", 150, 100, operation="MULTIPLY")
        smooth_k.inputs[1].default_value = 0.25
        links.new(chip.outputs["Value"], smooth_k.inputs[0])
        links.new(smooth_k.outputs["Value"], smooth.inputs[1])
        rough_out = smooth.outputs["Value"]
    # Surface relief: weave for fabric, fine grain otherwise.
    height = None
    if weave > 0:
        wave_a = _node(nodes, "ShaderNodeTexWave", -1000, -1100)
        wave_a.inputs["Scale"].default_value = weave_scale
        wave_a.bands_direction = "X"
        wave_b = _node(nodes, "ShaderNodeTexWave", -1000, -1300)
        wave_b.inputs["Scale"].default_value = weave_scale
        wave_b.bands_direction = "Y"
        for w in (wave_a, wave_b): links.new(coord.outputs["Object"], w.inputs["Vector"])
        mul = _node(nodes, "ShaderNodeMath", -800, -1200, operation="MULTIPLY")
        links.new(wave_a.outputs["Fac"], mul.inputs[0])
        links.new(wave_b.outputs["Fac"], mul.inputs[1])
        height = mul.outputs["Value"]
        bump = max(bump, weave)
    elif bump > 0:
        grain = _node(nodes, "ShaderNodeTexNoise", -1000, -1100)
        grain.inputs["Scale"].default_value = bump_scale
        grain.inputs["Detail"].default_value = 2.0
        links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
        height = grain.outputs["Fac"]
    if height is not None:
        bmp = _node(nodes, "ShaderNodeBump", 300, -1000)
        bmp.inputs["Strength"].default_value = bump
        bmp.inputs["Distance"].default_value = 0.002
        links.new(height, bmp.inputs["Height"])
        links.new(bev.outputs["Normal"], bmp.inputs["Normal"])
        normal_in = bmp.outputs["Normal"]
    # Named hand-offs, so the bake can read the plain colour (a metal's
    # diffuse pass bakes black).
    colour_tap = _node(nodes, "NodeReroute", 450, -300)
    colour_tap.name = "hq_colour"
    links.new(colour_out, colour_tap.inputs[0])
    links.new(colour_tap.outputs[0], bsdf.inputs["Base Color"])
    links.new(rough_out, bsdf.inputs["Roughness"])
    links.new(normal_in, bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"): m.surface_render_method = "BLENDED"
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = rgba[:3] + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = rgba
    m["hq_metal"] = metal
    MATS[name] = m
    return m


def plain(name, colour, rough=0.5, metal=0.0, emission=0.0, alpha=1.0):
    """An untextured material (accents, glass, glowing parts): never baked."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgba = tuple(colour)[:3] + (1.0,)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"): m.surface_render_method = "BLENDED"
    m.diffuse_color = tuple(colour)[:3] + (alpha,)
    MATS[name] = m
    return m


def srgb(hex_colour):
    """'#RRGGBB' to linear RGB, as Blender's colour inputs want."""
    h = hex_colour.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def hq_materials():
    """The HQ palette: the house roles, with real surfaces."""
    MATS.clear()
    pbr("shell_white", srgb("#E9E8E2"), .42, wear=.35, grime=.10, bump=.05)           # composite shell
    pbr("panel_warm", srgb("#CFCCC3"), .55, wear=.25, grime=.14, bump=.06)            # painted panels
    pbr("panel_cool", srgb("#AEB6B9"), .5, wear=.25, grime=.12, bump=.05)
    pbr("frame_graphite", srgb("#3B4349"), .5, wear=.45, wear_colour=srgb("#7C878D"), grime=.08, bump=.08)
    pbr("deep_graphite", srgb("#23292D"), .6, grime=.05, bump=.05)
    pbr("satin_alloy", srgb("#C3C9CC"), .3, metal=1.0, rough_var=.06, brushed=True, bump=.04, bump_scale=300)
    pbr("dark_alloy", srgb("#5F686D"), .38, metal=1.0, brushed=True, bump=.04, bump_scale=300)
    pbr("black_rubber", srgb("#1B1F21"), .82, grime=.04, bump=.25, bump_scale=160)
    # Weave scales stay coarse enough for a 2048 atlas (about 3 mm a pixel);
    # finer ones alias into grain.
    pbr("nomex_fabric", srgb("#DCD3BC"), .88, weave=.2, weave_scale=170, grime=.18)    # ISS soft goods
    pbr("nomex_webbing", srgb("#C9BC98"), .8, weave=.25, weave_scale=130, grime=.12)
    pbr("fabric_slate", srgb("#55697A"), .9, weave=.2, weave_scale=160, grime=.1)      # sleeping bag, cushions
    pbr("fabric_teal", srgb("#5E8C8F"), .9, weave=.2, weave_scale=160, grime=.1)
    pbr("label_white", srgb("#F3F3EF"), .35, grime=.03, bump=0)
    pbr("ink_red", srgb("#B3322A"), .45, bump=0)
    pbr("velcro_hook", srgb("#D8CFB6"), .95, weave=.3, weave_scale=300)
    pbr("tile_melted", srgb("#8C7A5C"), .55, grime=.2, bump=.35, bump_scale=40)      # compacted waste tiles
    pbr("belt_rubber", srgb("#24282A"), .75, bump=.3, bump_scale=200)
    # The furnishings helpers' own material names.
    pbr("graphite", srgb("#3B4349"), .5, wear=.45, wear_colour=srgb("#7C878D"), grime=.08, bump=.08)
    pbr("alloy", srgb("#B9C0C4"), .32, metal=1.0, brushed=True, bump=.04, bump_scale=300)
    pbr("satin_steel", srgb("#C8CDD0"), .28, metal=1.0, brushed=True, bump=.03, bump_scale=300)
    pbr("warm_shell", srgb("#DEDAD0"), .5, wear=.3, grime=.12, bump=.05)
    pbr("white_painted", srgb("#ECECE7"), .45, wear=.3, grime=.08, bump=.04)
    pbr("teal_soft", srgb("#5E8C8F"), .9, weave=.3, weave_scale=480, grime=.1)
    pbr("mirror", srgb("#D5DADD"), .05, metal=1.0, rough_var=.02, grime=.03, bump=0)
    plain("accent_orange", srgb("#E98A45"), .45)
    plain("frosted_glass", srgb("#C9D6DC"), .3, alpha=.22)
    plain("dark_glass", srgb("#1E2A30"), .06, alpha=.55)
    plain("screen_cyan", srgb("#3FD6EA"), .3, emission=2.2)
    plain("screen_amber", srgb("#F2B54A"), .3, emission=2.0)
    plain("led_warm", srgb("#FFE2B0"), .3, emission=3.0)
    plain("led_green", srgb("#5BE38A"), .3, emission=2.5)
    plain("led_red", srgb("#F2544A"), .3, emission=2.5)


# ---------- extra geometry ----------

def plate(prefix, x, y, z, w, h, face="front"):
    """A small blank ID plate, raised a few millimetres. Never lettering:
    text goes only on working displays (the game draws those live)."""
    if face == "front":
        return box(f"{prefix}_plate_panel_cool", x - w / 2, x + w / 2, y, y + 0.003, z - h / 2, z + h / 2, "panel_cool", 0.0015)
    return box(f"{prefix}_plate_panel_cool", x - w / 2, x + w / 2, y - h / 2, y + h / 2, z, z + 0.003, "panel_cool", 0.0015)


def pleated(name, x0, x1, z0, z1, y, pleats, depth, mat, thickness=0.004):
    """A hanging fabric panel with soft pleats along X."""
    bm = bmesh.new()
    cols, rows = pleats * 8, 6
    verts = []
    for r in range(rows + 1):
        row = []
        z = z0 + (z1 - z0) * r / rows
        for c in range(cols + 1):
            t = c / cols
            x = x0 + (x1 - x0) * t
            yy = y + depth * math.sin(t * pleats * 2 * math.pi) * (0.85 + 0.15 * (r / rows))
            row.append(bm.verts.new((x, yy, z)))
        verts.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mod = obj.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = thickness
    return _finish(obj, name, mat)


def quilted(prefix, x0, x1, y0, y1, z0, z1, mat, cols=4, rows=2):
    """A padded cushion with stitched quilting seams on top."""
    cushion(f"{prefix}_{mat}", x0, x1, y0, y1, z0, z1, mat)
    seams = []
    for i in range(1, cols):
        x = x0 + (x1 - x0) * i / cols
        seams.append(box("s", x - 0.003, x + 0.003, y0 + 0.03, y1 - 0.03, z1 - 0.006, z1 + 0.001, "nomex_webbing", 0))
    for j in range(1, rows):
        yy = y0 + (y1 - y0) * j / rows
        seams.append(box("s", x0 + 0.03, x1 - 0.03, yy - 0.003, yy + 0.003, z1 - 0.006, z1 + 0.001, "nomex_webbing", 0))
    if seams: join(f"{prefix}_stitching_nomex_webbing", seams)


def handrail(name, a, b, standoff=0.05, axis_out=(0, 1, 0), radius=0.014, mat="satin_alloy"):
    """An ISS-style handrail: a bar on two stand-offs."""
    out = Vector(axis_out) * standoff
    a, b = Vector(a), Vector(b)
    parts = [rod("bar", a + out, b + out, radius, mat, verts=20)]
    d = (b - a).normalized() * 0.04
    for p in (a + d, b - d):
        parts.append(rod("post", p, p + out, radius * 0.8, mat, verts=16))
    return join(name, parts)


def cable(name, points, radius=0.006, mat="black_rubber", ties=True):
    """A cable run through points, with ties."""
    parts = []
    pts = [Vector(p) for p in points]
    for i in range(len(pts) - 1):
        parts.append(rod("c", pts[i], pts[i + 1], radius, mat, verts=10))
        if ties:
            mid = (pts[i] + pts[i + 1]) / 2
            parts.append(cyl("t", tuple(mid), radius * 1.6, 0.006, "deep_graphite", axis=_axis_of(pts[i + 1] - pts[i]), verts=10))
    return join(name, parts)


def _axis_of(v):
    v = Vector((abs(v.x), abs(v.y), abs(v.z)))
    return "x" if v.x >= v.y and v.x >= v.z else ("y" if v.y >= v.z else "z")


def screw_row(name, x0, x1, z, y, count, face="front"):
    pts = [(x0 + (x1 - x0) * i / max(1, count - 1), z) for i in range(count)]
    return bolts(name, pts, y, mat="satin_alloy", r=0.0045)


def seam_grid(name, x0, x1, z0, z1, y, cols, rows, w=0.003):
    """Panel seams (thin dark grooves) on a front face at y."""
    parts = []
    for i in range(1, cols):
        x = x0 + (x1 - x0) * i / cols
        parts.append(box("g", x - w / 2, x + w / 2, y - 0.001, y + 0.0015, z0, z1, "deep_graphite", 0))
    for j in range(1, rows):
        z = z0 + (z1 - z0) * j / rows
        parts.append(box("g", x0, x1, y - 0.001, y + 0.0015, z - w / 2, z + w / 2, "deep_graphite", 0))
    return join(name, parts) if parts else None


def status_leds(prefix, x, y, z, colours=("led_green", "led_green", "led_red"), step=0.022):
    for i, c in enumerate(colours):
        cyl(f"{prefix}_{i}_{c}", (x + i * step, y + 0.002, z), 0.0045, 0.006, c, axis="y", verts=12)


# ---------- bake, export, preview ----------

def _no_bake(mat_name):
    return any(w in mat_name for w in NO_BAKE_WORDS)


def _apply_modifiers(objs):
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except RuntimeError:
                o.modifiers.remove(mod)


def _new_image(name, size, non_colour=False, alpha=False):
    img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False)
    if non_colour: img.colorspace_settings.name = "Non-Color"
    return img


def _set_target(mats, img):
    for m in mats:
        nodes = m.node_tree.nodes
        node = nodes.get("hq_bake_target") or nodes.new("ShaderNodeTexImage")
        node.name = "hq_bake_target"
        node.image = img
        for n in nodes: n.select = False
        node.select = True
        nodes.active = node


def _soften(img, radius):
    """A separable box blur (numpy), radius in pixels."""
    k = 2 * radius + 1
    pad = np.pad(img, radius, mode="edge")
    rows = np.cumsum(np.pad(pad, ((0, 0), (1, 0))), axis=1)
    pad = (rows[:, k:] - rows[:, :-k]) / k
    cols = np.cumsum(np.pad(pad, ((1, 0), (0, 0))), axis=0)
    return (cols[k:, :] - cols[:-k, :]) / k


def _bake_emitted(mats, img, source, samples=8):
    """Bake what source(material, nodes) gives (a socket or a number) as light."""
    bpy.context.scene.cycles.samples = samples
    saved = {}
    for m in mats:
        nodes, links = m.node_tree.nodes, m.node_tree.links
        out = nodes.get("Material Output")
        saved[m.name] = out.inputs["Surface"].links[0].from_socket
        em = nodes.new("ShaderNodeEmission")
        em.name = "hq_emit"
        what = source(m, nodes)
        if isinstance(what, float):
            em.inputs["Color"].default_value = (what, what, what, 1)
        else:
            links.new(what, em.inputs["Color"])
        links.new(em.outputs[0], out.inputs["Surface"])
    _set_target(mats, img)
    bpy.ops.object.bake(type="EMIT", use_clear=True)
    for m in mats:
        nodes, links = m.node_tree.nodes, m.node_tree.links
        links.new(saved[m.name], nodes.get("Material Output").inputs["Surface"])
        nodes.remove(nodes.get("hq_emit"))


def bake_model(item_id, out_dir, size=BAKE_SIZE):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = BAKE_SAMPLES
    scene.render.bake.margin = 8
    objs = list(PARTS)
    bpy.ops.object.select_all(action="DESELECT")
    _apply_modifiers(objs)
    bake_objs = [o for o in objs if o.data.materials and not _no_bake(o.data.materials[0].name)]
    # One atlas: islands unwrapped together, scaled to an even texel density.
    bpy.ops.object.select_all(action="DESELECT")
    for o in bake_objs:
        o.select_set(True)
        if not o.data.uv_layers: o.data.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = bake_objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.002, scale_to_bounds=False)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    mats = sorted({o.data.materials[0] for o in bake_objs}, key=lambda m: m.name)
    images = {}
    # Colour (lighting-free), roughness, tangent normals, occlusion.
    images["base"] = _new_image(f"{item_id}_base", size)
    _bake_emitted(mats, images["base"], lambda m, nodes: nodes["hq_colour"].outputs[0], samples=16)
    scene.cycles.samples = BAKE_SAMPLES
    images["rough"] = _new_image(f"{item_id}_rough", size, non_colour=True)
    _set_target(mats, images["rough"])
    bpy.ops.object.bake(type="ROUGHNESS", use_clear=True)
    images["normal"] = _new_image(f"{item_id}_normal", size, non_colour=True)
    _set_target(mats, images["normal"])
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True)
    images["ao"] = _new_image(f"{item_id}_ao", size, non_colour=True)
    _set_target(mats, images["ao"])
    scene.cycles.samples = 64
    bpy.ops.object.bake(type="AO", use_clear=True)
    # Metal: each material's value, emitted.
    images["metal"] = _new_image(f"{item_id}_metal", size, non_colour=True)
    _bake_emitted(mats, images["metal"], lambda m, nodes: float(m.get("hq_metal", 0.0)), samples=1)
    # Combine: occlusion into the colour (softly), and an ORM map.
    px = lambda img: np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    base, ao, rough, metal = px(images["base"]), px(images["ao"]), px(images["rough"]), px(images["metal"])
    # Occlusion is noisy at bake samples; a small blur smooths it (the bake
    # margin pads each island, so it stays inside its part).
    ao[..., 0] = _soften(ao[..., 0], 3)
    occl = ao[..., :1]
    base[..., :3] *= (0.55 + 0.45 * occl)
    tex_dir = os.path.join(out_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)
    final_base = _new_image(f"{item_id}_basecolor", size)
    final_base.pixels[:] = base.ravel()
    orm = np.ones((size, size, 4), dtype=np.float32)
    orm[..., 0] = ao[..., 0]
    orm[..., 1] = rough[..., 0]
    orm[..., 2] = metal[..., 0]
    final_orm = _new_image(f"{item_id}_orm", size, non_colour=True)
    final_orm.pixels[:] = orm.ravel()
    final_normal = images["normal"]
    for img, suffix in ((final_base, "basecolor"), (final_orm, "orm"), (final_normal, "normal")):
        img.filepath_raw = os.path.join(tex_dir, f"{item_id}_{suffix}.png")
        img.file_format = "PNG"
        img.save()
    # The one baked material every baked part shares.
    m = bpy.data.materials.new(f"{item_id}_surface")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tb = nodes.new("ShaderNodeTexImage"); tb.image = final_base
    to = nodes.new("ShaderNodeTexImage"); to.image = final_orm
    tn = nodes.new("ShaderNodeTexImage"); tn.image = final_normal
    sep = nodes.new("ShaderNodeSeparateColor")
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(tb.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(to.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    links.new(tn.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    # Occlusion for glTF: the exporter reads the "glTF Material Output" group.
    group = bpy.data.node_groups.get("glTF Material Output")
    if group is None:
        group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    gnode = nodes.new("ShaderNodeGroup"); gnode.node_tree = group
    links.new(sep.outputs["Red"], gnode.inputs["Occlusion"])
    for o in bake_objs:
        o.data.materials.clear()
        o.data.materials.append(m)
    return final_base


def run():
    """Build, bake, export and preview every model in MODELS (or only those named)."""
    for item_id, build, placement in MODELS:
        if ONLY and item_id not in ONLY: continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        hq_materials()
        reset()
        PARTS.clear()
        build()
        bake_model(item_id, OUT)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in PARTS: obj.select_set(True)
        os.makedirs(os.path.join(OUT, "models"), exist_ok=True)
        # Export beside the old file, then swap it in: Windows sometimes holds
        # a just-written GLB (a scanner reading it), which fails a long run.
        final = os.path.join(OUT, "models", item_id + ".glb")
        temp = os.path.join(OUT, "models", item_id + ".new.glb")
        bpy.ops.export_scene.gltf(filepath=temp, export_format="GLB",
                                  use_selection=True, export_apply=True, export_image_format="AUTO")
        for attempt in range(30):
            try:
                os.replace(temp, final)
                break
            except OSError:
                time.sleep(2)
        lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
        tris = 0
        for obj in PARTS:
            for corner in obj.bound_box:
                w = obj.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
        bounds = [[round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]]
        MANIFEST.append({"id": item_id, "file": item_id + ".glb", "placement": placement, "bounds_m": bounds, "triangles": tris,
                         "named_components": sorted({o.name.rsplit("_", 1)[0] for o in PARTS})})
        _preview(item_id, lo, hi)
        print("BUILT", item_id, bounds, "tris", tris)
        # Write the manifest after each model, so a long run keeps what it made.
        path = os.path.join(OUT, "asset_manifest.json")
        existing = []
        if ONLY and os.path.exists(path):
            done = {m["id"] for m in MANIFEST}
            existing = [m for m in json.load(open(path))["assets"] if m["id"] not in done]
        with open(path, "w") as f:
            json.dump({"style": "HQ pass for Forward+: baked PBR atlases (base colour with AO, normal, ORM), house look",
                       "units": "metres; Y up; -Z forward; floor origin", "assets": existing + MANIFEST}, f, indent=2)


def _preview(item_id, lo, hi):
    """A quick Eevee look with a sun and a soft world, for review."""
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    world = bpy.data.worlds.new("bg"); scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.31, 0.30, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(35)))
    bpy.context.active_object.data.energy = 3.5
    bpy.ops.object.light_add(type="AREA", location=(2.5, 3.5, 3.0))
    bpy.context.active_object.data.energy = 300
    bpy.context.active_object.data.size = 3
    centre = (lo + hi) / 2
    size = max(hi - lo)
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; scene.camera = cam
    cam.data.lens = 50
    eye = centre + Vector((0.9, 1.5, 0.75)).normalized() * (size * 2.3 + 0.6)
    cam.location = eye
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)
    scene.render.filepath = os.path.join(OUT, "previews", item_id + ".png")
    bpy.ops.render.render(write_still=True)
