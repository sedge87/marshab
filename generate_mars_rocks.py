"""Create lightweight, reusable Mars rock GLB assets for Godot.

Run from the project root:
  blender --background --python blender/generate_mars_rocks.py
"""
import bpy
import math
import os
import random

OUTPUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "models"))
os.makedirs(OUTPUT, exist_ok=True)

for item in list(bpy.data.objects):
    bpy.data.objects.remove(item, do_unlink=True)

def material(name, colour):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.92
    return mat

MATS = [
    material("Rust Rock", (0.22, 0.065, 0.035)),
    material("Ochre Rock", (0.32, 0.12, 0.055)),
    material("Dark Basalt", (0.075, 0.055, 0.05)),
]

def rock(name, seed, size, mat_index=0, location=(0, 0, 0)):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for vertex in obj.data.vertices:
        direction = vertex.co.normalized()
        irregularity = 0.78 + rng.random() * 0.38
        vertex.co *= irregularity
        vertex.co.z *= 0.8 + rng.random() * 0.24
        vertex.co.x += direction.x * rng.uniform(-0.08, 0.08)
    lowest = min(vertex.co.z for vertex in obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co.z -= lowest
    obj.data.materials.append(MATS[mat_index % len(MATS)])
    return obj

def export_asset(asset_name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUTPUT, asset_name + ".glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)

export_asset("mars_boulder_round", [rock("BoulderRound", 11, (1.25, 1.05, 0.95), 1)])
export_asset("mars_boulder_flat", [rock("BoulderFlat", 29, (1.55, 0.8, 0.58), 0)])
export_asset("mars_boulder_dark", [rock("BoulderDark", 53, (1.1, 1.2, 1.45), 2)])

cluster = [
    rock("ClusterA", 71, (0.72, 0.64, 0.58), 0, (0.0, 0.0, 0.0)),
    rock("ClusterB", 72, (0.48, 0.55, 0.42), 1, (0.74, 0.24, 0.0)),
    rock("ClusterC", 73, (0.39, 0.32, 0.3), 2, (-0.58, 0.25, 0.0)),
]
export_asset("mars_rock_cluster", cluster)

formation = [
    rock("FormationBase", 91, (2.8, 1.4, 1.7), 2),
    rock("FormationFace", 92, (1.55, 1.05, 2.3), 0, (0.85, -0.1, 0.25)),
]
export_asset("mars_rock_formation", formation)

debris = []
for index, location in enumerate([(-0.8, -0.15, 0), (-0.35, 0.42, 0), (0.18, -0.37, 0), (0.76, 0.2, 0), (0.56, 0.74, 0)]):
    debris.append(rock("Debris" + str(index), 120 + index, (0.18 + index * 0.025, 0.14 + index * 0.018, 0.12 + index * 0.012), index, location))
export_asset("mars_stone_debris", debris)

print("Exported Mars rock library to", OUTPUT)
