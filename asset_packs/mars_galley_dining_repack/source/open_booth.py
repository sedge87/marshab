"""Blender (5.x): the Integrated Mess Booth, opened up (playtest, 21–22 Oct).

blender --background --python open_booth.py -- <in.glb> <out.glb>

The original design is kept, with two changes the user asked for:
  - the two curved benches sit further from the table (more knee room);
  - the benches are backless: cut down just above the seat cushions.
The GLB is triangle soup batched by material, so each face is sorted by
where it sits: inside the table's oval it's table; outside, it's bench.
"""
import sys
import bmesh
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
TABLE_A, TABLE_B = 1.25, 0.80   # table oval half-axes (x, y), Blender space
SPREAD = 1.18                    # benches pushed out by this factor
SEAT_TOP = 0.53                  # cut the benches here (cushions top out at 0.51)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if obj.name == "removable_serving_insert": continue
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bench = set()
    for face in bm.faces:
        c = face.calc_center_median()
        if (c.x / TABLE_A) ** 2 + (c.y / TABLE_B) ** 2 > 1.06: bench.add(face)
    if not bench:
        bm.free()
        continue
    # Push bench vertices outward (only vertices used solely by bench faces).
    verts = {v for f in bench for v in f.verts}
    for v in verts:
        if all(f in bench for f in v.link_faces):
            v.co.x *= SPREAD
            v.co.y *= SPREAD
    # Backless: slice bench geometry at seat height and drop everything above.
    geom = list(bench) + list({e for f in bench for e in f.edges}) + list(verts)
    cut = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, 0, SEAT_TOP)), plane_no=Vector((0, 0, 1)), clear_outer=True)
    # Cap the cut edges so the bench tops read as solid seats.
    cut_edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        try:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
        except Exception:
            pass
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True)
lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for o in bpy.context.scene.objects:
    if o.type != "MESH": continue
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c); lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
print("BOUNDS", [[round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)], [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]])
