"""Blender (5.x): repair the emergency supply locker (24 Oct).

Run: blender --background --python fix_emergency_locker.py -- <in.glb> <out.glb>

The delivered model had its right-hand door exported swung open along the
cabinet's side, so the front was always half open. This removes that door
and makes a closed right door by mirroring the left door, its handle, latch
and seal across the middle. Names stay component_material, so the game's
rig can swing both doors (right_door_*, hinged on max_x).
"""
import sys

import bmesh
import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ARGS[0])
for name in ("right_door_white_painted", "right_door_gasket_rubber_gasket", "right_door_handle_dark_alloy"):
    obj = bpy.data.objects.get(name)
    if obj: bpy.data.objects.remove(obj, do_unlink=True)
MIRROR = {"left_door_white_painted": "right_door_white_painted", "left_door_handle_dark_alloy": "right_door_handle_dark_alloy",
          "left_door_latch_orange": "right_door_latch_orange", "door_seal_rubber_gasket": "right_door_seal_rubber_gasket"}
for source, target in MIRROR.items():
    src = bpy.data.objects[source]
    copy = src.copy()
    copy.data = src.data.copy()
    copy.name = target
    copy.data.name = target
    for c in src.users_collection: c.objects.link(copy)
    # Mirror across x = 0 in world space, then fix the faces' winding.
    world = copy.matrix_world.copy()
    mesh = copy.data
    for v in mesh.vertices:
        p = world @ v.co
        p.x = -p.x
        v.co = world.inverted() @ p
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(mesh); bm.free()
    mesh.update()
bpy.ops.export_scene.gltf(filepath=ARGS[1], export_format="GLB")
print("FIXED", ARGS[1])
