"""Create and export the MARS: HABITAT low-poly solar array for Godot.

Run from Blender's Text Editor or with the Blender MCP.  The model uses the
usual Blender Z-up convention; Godot's GLB importer converts this to Y-up.
"""
import bpy
import math
from mathutils import Vector

EXPORT_PATH = r"C:\Users\10049781\Documents\MarsHabitat\assets\showcase_modules\mh_solar_array.glb"


def material(name, colour, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.5
    return mat


def cube(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Rounded edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return obj


# Start a dedicated collection without touching the user's existing habitat kit.
collection_name = "MH_Solar_Array_Export"
old = bpy.data.collections.get(collection_name)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
collection = bpy.data.collections.new(collection_name)
bpy.context.scene.collection.children.link(collection)

def move_to_collection(obj):
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)


frame = material("MH solar frame", (0.12, 0.16, 0.18), metallic=0.8, roughness=0.28)
panel = material("MH solar cells", (0.015, 0.09, 0.18), metallic=0.32, roughness=0.2)
cell_line = material("MH solar cell lines", (0.11, 0.58, 0.95), metallic=0.2, roughness=0.32, emission=(0.02, 0.12, 0.24))
accent = material("MH solar safety accent", (0.95, 0.3, 0.04), metallic=0.3, roughness=0.33)

root = bpy.data.objects.new("mh_solar_array", None)
collection.objects.link(root)

# Weighted rectangular foot, mast, and a hinged panel mount.
parts = []
parts.append(cube("Solar footing", (0, 0, 0.10), (0.62, 0.46, 0.10), frame, 0.05))
parts.append(cube("Solar mast", (0, 0, 0.70), (0.12, 0.12, 0.58), frame, 0.04))
parts.append(cube("Solar hinge", (0, 0, 1.31), (0.62, 0.15, 0.12), accent, 0.04))

# Two panel wings, raised on a 32-degree tilted support.  The root stays at
# ground level so the Godot placement code can sit it directly on Mars terrain.
tilt = math.radians(32)
for index, x in enumerate((-0.78, 0.78)):
    wing = bpy.data.objects.new("Solar wing %d" % (index + 1), None)
    collection.objects.link(wing)
    wing.parent = root
    wing.location = (x, 0, 1.38)
    wing.rotation_euler = (tilt, 0, 0)
    back = cube("Solar panel backing", (0, 0, 0), (0.70, 0.72, 0.055), frame, 0.035)
    face = cube("Solar photovoltaic surface", (0, -0.015, 0.07), (0.62, 0.65, 0.018), panel, 0.015)
    move_to_collection(back)
    move_to_collection(face)
    back.parent = wing
    face.parent = wing
    back.location = (0, 0, 0)
    face.location = (0, -0.015, 0.07)
    for line in (-0.31, 0.0, 0.31):
        strip = cube("Solar cell divider", (line, -0.038, 0.095), (0.012, 0.62, 0.008), cell_line)
        move_to_collection(strip)
        strip.parent = wing
        strip.location = (line, -0.038, 0.095)

for part in parts:
    move_to_collection(part)
    part.parent = root
    part.matrix_parent_inverse = root.matrix_world.inverted()

# Export only this collection as a self-contained Godot GLB.
bpy.ops.object.select_all(action="DESELECT")
for obj in collection.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.context.view_layer.objects.active = next(obj for obj in collection.objects if obj.type == "MESH")
bpy.ops.export_scene.gltf(
    filepath=EXPORT_PATH,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_materials="EXPORT",
)
print("Exported", EXPORT_PATH)
