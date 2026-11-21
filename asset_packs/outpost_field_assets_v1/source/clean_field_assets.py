"""Phase 6 (21 Nov): the user's three field models made house-ready.

  blender -b --python clean_field_assets.py -- <original.glb> <out.glb>

- No lettering on models (house rule, docs/house-style.md): every face painted
  with a screen-print, legend or telemetry-graphics material goes, and the
  baked "Preview_Graphics_*" screens go with it. Working displays are kept
  as blank "Display_Surface_*" quads; the game draws on them.
- Everything else (the worn textures, the named empties the game hangs its
  parts on: Driver_Eye, Steer_FL, Galley_Drawer_01, Ratchet_Head...) is kept.
"""
import bpy, bmesh, sys

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
LETTERING = ("screen print", "legend", "telemetry graphics")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

removed = 0
repainted = 0
for name in [o.name for o in bpy.context.scene.objects if o.name.startswith("Preview_Graphics")]:
    o = bpy.data.objects.get(name)
    if o is None: continue
    for child in list(o.children_recursive): bpy.data.objects.remove(child, do_unlink=True)
    bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.context.scene.objects:
    if o.type != "MESH": continue
    bad = {i for i, s in enumerate(o.material_slots) if s.material and any(w in s.material.name.lower() for w in LETTERING)}
    if not bad: continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # Lettering cut into a panel takes the panel's paint (deleting it left
    # letter-shaped holes); lettering that floats as its own piece is deleted.
    todo = [f for f in bm.faces if f.material_index in bad]
    for _ in range(64):
        changed = False
        for f in todo:
            if f.material_index not in bad: continue
            for e in f.edges:
                near = [g for g in e.link_faces if g is not f and g.material_index not in bad]
                if near:
                    f.material_index = near[0].material_index
                    changed = True
                    break
        if not changed: break
    faces = [f for f in bm.faces if f.material_index in bad]
    repainted += len(todo) - len(faces)
    removed += len(faces)
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
# Raised lettering modelled in a hull material, found by hand (Blender
# space, metres): (file name part, mesh, material, min corner, max corner).
RAISED = [
    ("Traverse_06", "Chassis_Visual", "Anodised gunmetal", (-0.4, 1.2, 3.4), (0.2, 1.62, 3.46)),   # the "06" on the roof
]
for key, mesh, mat, lo, hi in RAISED:
    if key not in src: continue
    o = bpy.data.objects.get(mesh)
    if o is None: continue
    mw = o.matrix_world
    bm = bmesh.new(); bm.from_mesh(o.data)
    faces = []
    for f in bm.faces:
        w = mw @ f.calc_center_median()
        if o.material_slots[f.material_index].material.name == mat and all(lo[i] <= w[i] <= hi[i] for i in range(3)): faces.append(f)
    removed += len(faces)
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(o.data); bm.free()
print("CLEAN repainted %d lettering faces, removed %d" % (repainted, removed))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=False, export_extras=True)
