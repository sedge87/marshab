"""Build the grounded Mars Habitat interior first batch in Blender.

Run from Blender 4.x/5.x: blender --background --python blender/generate_interior_first_batch.py
Exports editable source data and runtime GLBs.  The generated collection is isolated so it
never alters existing rover or exterior-habitat source collections.
"""
from __future__ import annotations

import math
import os
import bpy
from mathutils import Vector


PROJECT = r"C:\Users\10049781\Documents\MarsHabitat"
EQUIPMENT_OUT = os.path.join(PROJECT, "assets", "equipment")
STRUCTURE_OUT = os.path.join(PROJECT, "assets", "interior_kit")
SOURCE_OUT = os.path.join(PROJECT, "blender", "interior_first_batch_source.blend")
COLLECTION_NAME = "MH_InteriorFirstBatch"


def material(name, color, metallic=0.0, roughness=0.55, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 1.5
    return mat


PANEL = material("MH_PaintedWarmWhite", (0.738, 0.738, 0.706), 0.08, 0.48)
FRAME = material("MH_GraphiteFrame", (0.055, 0.075, 0.078), 0.55, 0.30)
ALLOY = material("MH_BrushedAluminium", (0.37, 0.40, 0.39), 0.72, 0.33)
SEAL = material("MH_EVASeal", (0.018, 0.023, 0.025), 0.0, 0.78)
ORANGE = material("MH_ServiceOrange", (0.55, 0.19, 0.055), 0.16, 0.43)
CYAN = material("MH_StatusCyan", (0.20, 0.52, 0.56), 0.05, 0.30, (0.20, 0.52, 0.56))
GREEN = material("MH_SystemGreen", (0.31, 0.48, 0.28), 0.0, 0.62, (0.20, 0.36, 0.18))
AMBER = material("MH_WarningAmber", (0.62, 0.38, 0.14), 0.0, 0.36, (0.54, 0.28, 0.05))
PLANT = material("MH_Crops", (0.13, 0.34, 0.10), 0.0, 0.82)
GLASS = material("MH_ObservationGlass", (0.45, 0.66, 0.67), 0.08, 0.16)


def clear_collection():
    old = bpy.data.collections.get(COLLECTION_NAME)
    if old:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)
    coll = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(coll)
    return coll


COLL = clear_collection()


def link(obj, parent=None):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    COLL.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def root(name):
    obj = bpy.data.objects.new(name, None)
    COLL.objects.link(obj)
    return obj


def box(name, loc, dims, mat, parent=None, bevel=0.018):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("EdgeRadius", 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return link(obj, parent)


def cylinder(name, loc, radius, depth, mat, parent=None, rotation=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return link(obj, parent)


def pipe(name, start, end, radius, mat, parent=None):
    sx, sy, sz = start
    ex, ey, ez = end
    dx, dy, dz = ex - sx, ey - sy, ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = ((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)))
    obj.rotation_mode = 'XYZ'
    return link(obj, parent)


def bolt(name, x, y, z, parent):
    return cylinder(name, (x, y, z), 0.032, 0.025, ALLOY, parent, rotation=(math.pi / 2, 0, 0), vertices=8)


def service_label(x, y, z, w, h, parent, colour=ORANGE):
    plate = box("ServiceLabel", (x, y, z), (w, h, 0.016), colour, parent, 0.004)
    return plate


def inspect_point(parent, location):
    marker = bpy.data.objects.new("InspectPoint", None)
    marker.empty_display_type = 'PLAIN_AXES'
    marker.empty_display_size = 0.12
    marker.location = location
    COLL.objects.link(marker)
    marker.parent = parent
    return marker


def export(root_obj, path):
    selected = [root_obj] + list(root_obj.children_recursive)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root_obj
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_animations=True)


def build_partition(name="partition_solid_3m", width=3.0):
    r = root(name)
    half = width * .5
    box("FrameTop", (0, 2.75, 0), (width, .12, .16), FRAME, r)
    box("FrameBottom", (0, .08, 0), (width, .16, .16), FRAME, r)
    upright_x = (-half + .08, half - .08) if width <= 1.6 else (-half + .08, 0, half - .08)
    for x in upright_x:
        box("FrameUpright", (x, 1.42, 0), (.12, 2.72, .15), FRAME, r)
    panel_width = (width - .28) / (len(upright_x) - 1)
    panel_x = [(-half + .14) + panel_width * (index + .5) for index in range(len(upright_x) - 1)]
    for x in panel_x:
        box("ReplaceablePanel", (x, 1.42, -.025), (panel_width - .05, 2.45, .075), PANEL, r, .025)
        service_label(x - panel_width * .30, .35, -.075, min(.22, panel_width * .3), .11, r)
        for y in (.28, 2.50):
            bolt("PanelBolt", x - panel_width * .38, y, -.085, r)
            bolt("PanelBolt", x + panel_width * .38, y, -.085, r)
    return r


def build_window():
    r = root("interior_window")
    # 1.5 m wide framed view panel, floor centre anchor for future partition placement.
    box("WindowSill", (0, .56, 0), (1.54, .13, .18), FRAME, r)
    box("WindowLintel", (0, 2.12, 0), (1.54, .13, .18), FRAME, r)
    for x in (-.70, .70):
        box("WindowSideFrame", (x, 1.34, 0), (.14, 1.70, .18), FRAME, r)
    box("ObservationPane", (0, 1.34, -.02), (1.23, 1.45, .03), GLASS, r, .005)
    # Four discrete gasket strips leave the observation pane visible.
    for x in (-.61, .61): box("GasketSide", (x, 1.34, -.07), (.045, 1.50, .018), SEAL, r, .003)
    for y in (.61, 2.07): box("GasketEdge", (0, y, -.07), (1.24, .045, .018), SEAL, r, .003)
    return r


def build_bulkhead():
    r = root("pressure_bulkhead_door")
    # 1.5 m opening; closed default and an exportable SlideOpen action.
    box("DoorFrameLeft", (-.78, 1.42, 0), (.16, 2.84, .25), FRAME, r)
    box("DoorFrameRight", (.78, 1.42, 0), (.16, 2.84, .25), FRAME, r)
    box("DoorFrameTop", (0, 2.76, 0), (1.72, .18, .25), FRAME, r)
    door = box("PressureDoor_Closed", (0, 1.34, -.03), (1.42, 2.48, .12), PANEL, r, .035)
    box("DoorSeal", (0, 1.34, -.105), (1.27, 2.32, .026), SEAL, door, .012)
    cylinder("PortholeRim", (0, 1.60, -.13), .27, .05, FRAME, door, rotation=(math.pi/2,0,0), vertices=24)
    cylinder("PortholeGlass", (0, 1.60, -.16), .205, .022, GLASS, door, rotation=(math.pi/2,0,0), vertices=24)
    box("DoorHandle", (.44, 1.18, -.15), (.12, .40, .08), ALLOY, door, .018)
    service_label(-.38, .48, -.12, .25, .12, door)
    for x in (-.55, .55):
        for y in (.36, 2.30): bolt("DoorBolt", x, y, -.13, door)
    door.keyframe_insert(data_path="location", frame=1)
    door.location.x = 1.52
    door.keyframe_insert(data_path="location", frame=20)
    if door.animation_data and door.animation_data.action:
        door.animation_data.action.name = "SlideOpen"
    door.location.x = 0
    return r


def build_interior_sliding_door():
    """Non-pressure interior divider door.  It is a visual kit item only, not gameplay logic."""
    r = root("interior_sliding_door")
    box("TrackHousing", (0, 2.54, 0), (1.86, .16, .18), FRAME, r)
    box("FrameLeft", (-.83, 1.28, 0), (.12, 2.56, .14), FRAME, r)
    box("FrameRight", (.83, 1.28, 0), (.12, 2.56, .14), FRAME, r)
    panel = box("SlidingDoorPanel", (0, 1.22, -.025), (1.46, 2.28, .075), PANEL, r, .03)
    box("DoorKickPlate", (0, .28, -.08), (1.22, .30, .02), ALLOY, panel, .006)
    box("DoorWindow", (0, 1.55, -.08), (.62, .40, .02), GLASS, panel, .004)
    box("DoorPull", (.48, 1.08, -.10), (.08, .38, .05), ALLOY, panel, .012)
    service_label(-.49, .52, -.08, .20, .09, panel, AMBER)
    panel.keyframe_insert(data_path="location", frame=1)
    panel.location.x = .82
    panel.keyframe_insert(data_path="location", frame=20)
    if panel.animation_data and panel.animation_data.action:
        panel.animation_data.action.name = "InteriorSlideOpen"
    panel.location.x = 0
    return r


def build_crew_bunk():
    r = root("crew_bunk")
    # Single adult berth: tray, modest privacy surround, equipment drawer and reading light.
    box("BunkFrameBase", (0, .18, 0), (1.34, .16, 2.72), FRAME, r)
    box("Mattress", (0, .36, -.05), (1.22, .22, 2.20), PANEL, r, .065)
    box("Pillow", (0, .52, .82), (1.02, .13, .42), PANEL, r, .055)
    box("HeadServicePanel", (0, 1.10, 1.08), (1.30, 1.36, .16), FRAME, r, .025)
    box("PersonalShelf", (0, .83, .94), (1.12, .08, .28), ALLOY, r, .012)
    box("StorageDrawer", (0, .20, -.95), (1.13, .22, .54), PANEL, r, .025)
    box("DrawerHandle", (0, .22, -1.23), (.36, .05, .06), ALLOY, r, .01)
    for x in (-.58,.58):
        pipe("SafetyRail", (x,.48,-1.06), (x,.48,.48), .028, ALLOY, r)
    pipe("ReadingLampArm", (-.48, 1.28, .95), (-.48, .92, .63), .022, ALLOY, r)
    box("Light_Reading", (-.48, .90, .56), (.26,.07,.08), CYAN, r, .01)
    box("PrivacyCurtainRail", (0, 1.40, -.38), (1.30,.05,.06), ALLOY, r, .008)
    box("PrivacyCurtain", (.52, .90, -.38), (.04,.86,1.42), GREY if 'GREY' in globals() else PANEL, r, .008)
    service_label(.30, 1.10, .98, .20, .10, r, AMBER)
    inspect_point(r, (0, 1.12, -1.38))
    return r


def build_grow_tray():
    r = root("grow_tray")
    # Three removable cultivation trays; plumbing and service access remain visible.
    for x in (-1.28,1.28):
        for z in (-.48,.48): cylinder("RackPost", (x,.90,z), .045,1.80,FRAME,r,vertices=12)
    for y in (.26,.82,1.38):
        box("TraySupport", (0,y,.0), (2.64,.07,1.12), FRAME,r,.01)
        box("RemovableGrowTray", (0,y+.10,-.06), (2.38,.12,.70), PANEL,r,.025)
        box("Light_Grow", (0,y+.32,.33), (2.20,.045,.07), CYAN,r,.008)
        for x in (-.86,-.43,0,.43,.86):
            for z in (-.21,.05):
                cylinder("PlantCluster", (x,y+.20,z), .075,.18,PLANT,r,vertices=8)
                cylinder("PlantLeaf", (x+.05,y+.26,z), .045,.22,PLANT,r,rotation=(0,.55,0),vertices=6)
    box("Reservoir", (0,.13,.06), (2.38,.23,.94), ALLOY,r,.028)
    cylinder("NutrientFilter", (1.04,.46,.25), .15,.62,PANEL,r,vertices=16)
    pipe("FeedLine", (-1.10,.55,.25), (1.06,.55,.25), .026, GREEN,r)
    pipe("ReturnLine", (-1.10,.40,-.36), (1.05,.40,-.36), .026, ALLOY,r)
    box("Status_GrowPanel", (-1.02,.67,-.52), (.34,.24,.025), CYAN,r,.012)
    service_label(.96,.68,-.52,.23,.10,r)
    inspect_point(r, (0,.95,-.72))
    return r


def build_air_recycler():
    r = root("air_recycler")
    box("RecyclerCabinet", (0,1.02,.05), (2.58,2.04,.92), PANEL,r,.05)
    box("ServiceBay", (-.70,.60,-.44), (.84,.72,.05), FRAME,r,.014)
    # Fan grille uses a rim, hub, and radial slats; it is visibly an air machine.
    cylinder("FanRim", (-.70,1.42,-.46), .39,.05,FRAME,r,rotation=(math.pi/2,0,0),vertices=24)
    cylinder("FanHub", (-.70,1.42,-.50), .08,.065,ALLOY,r,rotation=(math.pi/2,0,0),vertices=16)
    fan = root("FanBladeAssembly")
    fan.parent = r
    fan.location = (-.70,1.42,-.51)
    for angle in range(0,360,45):
        blade=box("FanBlade", (0,.13,0), (.06,.26,.025), ALLOY, fan,.006)
        blade.rotation_euler[2]=math.radians(angle)
    fan.rotation_euler[1]=0
    fan.keyframe_insert(data_path="rotation_euler", frame=1)
    fan.rotation_euler[1]=math.tau*3
    fan.keyframe_insert(data_path="rotation_euler", frame=36)
    if fan.animation_data and fan.animation_data.action: fan.animation_data.action.name="FanIdle"
    fan.rotation_euler[1]=0
    for x in (.08,.48,.88):
        cylinder("FilterCartridge", (x,1.27,-.48), .125,.70, ALLOY,r,vertices=12)
        box("FilterBand", (x,1.27,-.61), (.22,.08,.018), ORANGE,r,.004)
    box("Screen_Status", (.73,1.72,-.46), (.68,.34,.024), CYAN,r,.008)
    box("WarningStrip", (.73,1.44,-.46), (.68,.07,.020), AMBER,r,.004)
    for x in (-.92,.92):
        cylinder("DuctPort", (x,2.12,.04), .20,.28,FRAME,r,rotation=(math.pi/2,0,0),vertices=16)
    pipe("UpperDuct", (-.92,2.12,.17), (-.92,2.52,.17), .13, ALLOY,r)
    pipe("UpperDuct", (.92,2.12,.17), (.92,2.52,.17), .13, ALLOY,r)
    service_label(-.96,.42,-.47,.22,.10,r)
    inspect_point(r, (0,1.45,-.78))
    return r


def build_science_workbench():
    r = root("science_workbench")
    box("BenchFrame", (0,.36,.05), (2.62,.68,1.08), FRAME,r,.035)
    box("SteelWorktop", (0,.76,.02), (2.78,.12,1.30), ALLOY,r,.02)
    for x in (-1.14,1.14): pipe("BenchLeg", (x,.10,.34), (x,.68,.34), .055, FRAME,r)
    box("DrawerBank", (-.77,.40,-.47), (.92,.44,.08), PANEL,r,.015)
    for y in (.30,.48): box("DrawerSeam", (-.77,y,-.52), (.82,.025,.022), SEAL,r,.003)
    box("ContainmentTray", (-.28,.90,-.12), (.78,.09,.48), PANEL,r,.015)
    for x in (-.50,-.28,-.06): cylinder("SampleVial", (x,.99,-.12), .055,.19, GLASS,r,vertices=12)
    box("InstrumentScreen", (.74,1.22,.40), (.72,.50,.08), FRAME,r,.018)
    box("Screen_Display", (.74,1.22,.345), (.58,.34,.016), CYAN,r,.004)
    pipe("TaskLampArm", (1.12,.88,-.32),(1.12,1.42,-.10),.025,ALLOY,r)
    box("Light_Task", (1.00,1.42,-.10),(.30,.06,.08),CYAN,r,.008)
    box("ToolRail", (-.96,1.12,.43), (.62,.07,.07), ORANGE,r,.006)
    service_label(-1.05,.70,-.55,.21,.10,r)
    inspect_point(r, (0,1.10,-.78))
    return r


def build_cargo_rack():
    r = root("cargo_rack")
    for x in (-1.25,1.25):
        for z in (-.48,.48): pipe("RackUpright", (x,.06,z),(x,2.06,z),.052,FRAME,r)
    for y in (.18,.72,1.28,1.84):
        box("RackShelf", (0,y,0), (2.62,.065,1.14), ALLOY,r,.008)
    bin_data=[(-.76,.44,.32,.46,.44),(-.18,.42,.46,.52,.46),(.52,.46,.38,.46,.54),(-.70,1.02,.52,.40,.48),(.12,1.02,.44,.42,.50),(.78,1.02,.30,.38,.46)]
    for i,(x,y,w,h,d) in enumerate(bin_data):
        box("CargoBin", (x,y,-.02), (w,h,d), PANEL if i%2 else ALLOY,r,.025)
        box("CargoStrap", (x,y,-d*.52-.02), (w+.02,.05,.018), ORANGE,r,.003)
        service_label(x-w*.24,y+h*.16,-d*.52-.04,min(.19,w*.45),.07,r,AMBER)
    box("TieDownRail", (0,2.00,-.52),(2.42,.05,.06),ORANGE,r,.006)
    inspect_point(r, (0,1.05,-.78))
    return r


def build_all():
    os.makedirs(EQUIPMENT_OUT, exist_ok=True)
    os.makedirs(STRUCTURE_OUT, exist_ok=True)
    assets = {
        "partition_solid_3m": (build_partition(), os.path.join(STRUCTURE_OUT, "partition_solid_3m.glb")),
        "partition_solid_1p5m": (build_partition("partition_solid_1p5m", 1.5), os.path.join(STRUCTURE_OUT, "partition_solid_1p5m.glb")),
        "interior_window": (build_window(), os.path.join(STRUCTURE_OUT, "interior_window.glb")),
        "interior_sliding_door": (build_interior_sliding_door(), os.path.join(STRUCTURE_OUT, "interior_sliding_door.glb")),
        "pressure_bulkhead_door": (build_bulkhead(), os.path.join(STRUCTURE_OUT, "pressure_bulkhead_door.glb")),
        "crew_bunk": (build_crew_bunk(), os.path.join(EQUIPMENT_OUT, "crew_bunk.glb")),
        "grow_tray": (build_grow_tray(), os.path.join(EQUIPMENT_OUT, "grow_tray.glb")),
        "air_recycler": (build_air_recycler(), os.path.join(EQUIPMENT_OUT, "air_recycler.glb")),
        "science_workbench": (build_science_workbench(), os.path.join(EQUIPMENT_OUT, "science_workbench.glb")),
        "cargo_rack": (build_cargo_rack(), os.path.join(EQUIPMENT_OUT, "cargo_rack.glb")),
    }
    for name, (asset_root, path) in assets.items():
        export(asset_root, path)
        print("EXPORTED", name, path)
    # A library write produces an editable source without replacing the active Blender file.
    bpy.data.libraries.write(SOURCE_OUT, {COLL}, path_remap='RELATIVE_ALL', fake_user=True, compress=True)
    print("SOURCE", SOURCE_OUT)


if __name__ == "__main__":
    build_all()
