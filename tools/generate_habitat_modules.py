"""Creates the five low-poly M1 habitat GLBs. Run with Blender --background --python."""
import bpy, os

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "habitat_modules"))
os.makedirs(OUT, exist_ok=True)

def mat(name, colour):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*colour, 1)
    return m
WHITE, ORANGE, DARK = mat("Structural white", (.72,.75,.76)), mat("Safety orange", (.85,.20,.035)), mat("Dark seals", (.045,.06,.07))

def cube(name, loc, scale, material, bevel=.06):
    # Calls use Godot axes (X right, Y up, Z forward). Blender is X/Y ground,
    # Z up, so convert before exporting glTF back to Godot.
    blender_loc = (loc[0], loc[2], loc[1])
    blender_scale = (scale[0], scale[2], scale[1])
    bpy.ops.mesh.primitive_cube_add(location=blender_loc)
    o=bpy.context.object; o.name=name; o.scale=[v*.5 for v in blender_scale]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new("Soft panel edges", "BEVEL"); mod.width=bevel; mod.segments=2
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def shell(length, width, openings, airlock=False):
    # Ground-level hollow shell: floor, roof, side walls and end walls split around doors.
    cube("floor", (0,.1,0), (width,.2,length), DARK, .03)
    cube("ceiling", (0,2.9,0), (width,.18,length), WHITE)
    cube("left_wall", (-width/2+.08,1.5,0), (.16,2.8,length), WHITE)
    cube("right_wall", (width/2-.08,1.5,0), (.16,2.8,length), WHITE)
    for sign in (-1,1):
        z=sign*length/2
        if ("N" if sign>0 else "S") in openings:
            for x in (-width*.37,width*.37): cube("door_jamb",(x,1.2,z),(.48,2.35,.16),WHITE)
            cube("door_lintel",(0,2.55,z),(width,.16,.16),ORANGE)
        else: cube("end_wall",(0,1.5,z),(width,2.8,.16),WHITE)
    # orange lower rails make the pieces readable in Mars light
    cube("orange_rail",(-width/2-.01,.6,0),(.10,.18,length),ORANGE,.02)
    cube("orange_rail",(width/2+.01,.6,0),(.10,.18,length),ORANGE,.02)

def build(name):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    if name == "foundation":
        cube("foundation_deck",(0,.12,0),(6,.24,6),DARK); cube("orange_trim",(0,.28,0),(6.15,.12,6.15),ORANGE)
    elif name == "habitat_module": shell(6,6,{"N","S"})
    elif name == "corridor": shell(6,3.4,{"N","S"})
    elif name == "t_junction":
        shell(6,6,{"N","S"}); cube("branch_floor",(3,.1,0),(3,.2,3.4),DARK,.03); cube("branch_roof",(3,2.9,0),(3,.18,3.4),WHITE)
        cube("branch_side",(4.42,1.5,0),(.16,2.8,3.4),WHITE); cube("branch_lintel",(4.5,2.55,0),(.16,.16,3.4),ORANGE)
    elif name == "airlock": shell(4,3.4,{"N","S"}, True); cube("airlock_band",(0,1.7,0),(3.55,.28,4.15),ORANGE,.03)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name+".glb"), export_format='GLB', use_selection=True, export_apply=True)

for module in ("foundation","habitat_module","corridor","t_junction","airlock"): build(module)
print("Exported M1 habitat modules to", OUT)
