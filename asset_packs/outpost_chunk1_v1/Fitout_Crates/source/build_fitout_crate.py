"""Build and export the Fit-Out Crate. Run with Blender from any directory."""
from pathlib import Path
from collections import defaultdict
from math import cos, sin, pi
import argparse
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector


def inputs():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--size', choices=('Small','Medium','Large'), required=True)
    parser.add_argument('--terminal', type=Path)
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('Fit-Out Crate')
scene.collection.children.link(model)


def rgb(hex_color):
    srgb = [int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)]
    return (*[c/12.92 if c<.04045 else ((c+.055)/1.055)**2.4 for c in srgb], 1)


def material(role, hue, roughness, metalness=0):
    result = bpy.data.materials.new(role)
    result.diffuse_color = rgb(hue)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = result.diffuse_color
    shader.inputs['Metallic'].default_value = metalness
    shader.inputs['Roughness'].default_value = roughness
    if (args.textures / f'{role}_color.png').is_file():
        nodes = result.node_tree.nodes
        links = result.node_tree.links
        def tile(channel, colorspace):
            node = nodes.new('ShaderNodeTexImage')
            node.image = bpy.data.images.load(str(args.textures / f'{role}_{channel}.png'))
            node.image.colorspace_settings.name = colorspace
            node.image.pack()
            return node
        color = tile('color', 'sRGB')
        orm = tile('orm', 'Non-Color')
        split = nodes.new('ShaderNodeSeparateColor')
        normal = nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .78
        links.new(orm.outputs['Color'],split.inputs['Color'])
        links.new(tile('normal','Non-Color').outputs['Color'],normal.inputs['Color'])
        links.new(color.outputs['Color'],shader.inputs['Base Color'])
        links.new(split.outputs['Green'],shader.inputs['Roughness'])
        links.new(split.outputs['Blue'],shader.inputs['Metallic'])
        links.new(normal.outputs['Normal'],shader.inputs['Normal'])
        ao = bpy.data.node_groups.get('glTF Material Output')
        if ao is None:
            ao = bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
            ao.interface.new_socket(name='Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
        group = nodes.new('ShaderNodeGroup')
        group.node_tree = ao
        links.new(split.outputs['Red'],group.inputs['Occlusion'])
    return result


white = material('rover_white','D2CBB6',.52,.05)
orange = material('orange','C76136',.50,.05)
graphite = material('graphite','373A38',.67,.08)
dark = material('dark_alloy','4C5656',.49,.72)
alloy = material('alloy','727C7A',.46,.78)
steel = material('satin_steel','9B9F96',.36,.82)
warm = material('warm_panel','BDAA8C',.61,.10)
rubber = material('black_rubber','2E3030',.77,.01)
glass = material('dark_glass','242D2D',.27,.08)
def object_with_data(name, data=None, parent=None, point=(0,0,0)):
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    obj.parent = parent
    world = Vector(point)
    current = parent
    while current is not None:
        world -= current.location
        current = current.parent
    obj.location = world
    return obj


slate = material('slate_panel','53616A',.76,.03)
lamp = material('lamp_white','D9D6BE',.35,.04)
root = object_with_data(f'FitoutCrate{args.size}')
root['front_axis_godot'] = '+Z (latch side)'


def geom(label, points, faces, mat, fillet=0, parent=root, point=(0,0,0), object_name=None):
    name = f'{label}_{mat.name}'
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points,[],faces)
    mesh.materials.append(mat)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = object_with_data(object_name or name, mesh, parent, point)
    if fillet:
        bevel = obj.modifiers.new('Machined edge radius','BEVEL')
        bevel.width = fillet
        bevel.segments = 3
        bevel.limit_method = 'ANGLE'
        normals = obj.modifiers.new('Face normals','WEIGHTED_NORMAL')
        normals.keep_sharp = True
        for face in mesh.polygons:
            face.use_smooth = True
    obj['material_role'] = mat.name
    return obj


def loft(label, rings, mat, fillet=0, parent=root, point=(0,0,0), object_name=None):
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    faces = [tuple(range(n-1,-1,-1)),tuple(range(len(verts)-n,len(verts)))]
    for a in range(0,len(verts)-n,n):
        for i in range(n):
            j = (i+1)%n
            faces.append((a+i,a+j,a+j+n,a+i+n))
    return geom(label,verts,faces,mat,fillet,parent,point,object_name)


def octagon(width, length, corner):
    x,y = width/2,length/2
    return [(-x+corner,-y),(x-corner,-y),(x,-y+corner),(x,y-corner),
            (x-corner,y),(-x+corner,y),(-x,y-corner),(-x,-y+corner)]


def block(label,point,size,mat,fillet=.004, parent=root,corner=.009, object_name=None):
    contour = octagon(size[0],size[1], min(corner, size[0]*.22,size[1]*.22))
    return loft(label,[[(x,y,z) for x,y in contour] for z in (-size[2]/2,size[2]/2)],
                mat,fillet,parent,point,object_name)


def deck(label,sections,mat,fillet=.004):
    return loft(label,[[(x,y,z) for x,y in octagon(w,l,corner)] for z,w,l,corner in sections],
                mat,fillet)


def cylinder(label,point,r,d,mat,axis=(0,0,1),parent=root,n=24,fillet=.002,object_name=None):
    contour = [(r*cos(i*2*pi/n),r*sin(i*2*pi/n)) for i in range(n)]
    obj = loft(label,[[(x,y,z) for x,y in contour] for z in (-d/2,d/2)],mat,fillet,parent,point,object_name)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector(axis).to_track_quat('Z','Y')
    return obj


def rod(label,start,end,r,mat,parent=root):
    a,b = Vector(start),Vector(end)
    return cylinder(label,(a+b)/2,r,(a-b).length,mat,b-a,parent,n=20,fillet=min(.003,r*.2))


def sweep(label, points, radius, mat, parent=root):
    points = [Vector(v) for v in points]
    rings = []
    for i,p in enumerate(points):
        tangent = points[min(i+1,len(points)-1)]-points[max(i-1,0)]
        rotation = tangent.to_track_quat('Z','Y')
        rings.append([p+rotation@Vector((radius*cos(j*2*pi/20),radius*sin(j*2*pi/20),0)) for j in range(20)])
    obj = loft(label,rings,mat,parent=parent)
    for face in obj.data.polygons:
        face.use_smooth = face.loop_total==4
    return obj


def bolt(label,point,axis=(0,0,1),r=.006, parent=root):
    axis = Vector(axis)
    pos = Vector(point)
    cylinder(label+'_washer',pos-axis*.0013,r*1.38,.003,dark,axis,parent,n=18,fillet=.0006)
    cylinder(label,pos+axis*.0014,r,.0048,steel,axis,parent,n=8,fillet=.00065)
    cylinder(label+'_drive',pos+axis*.004,r*.43,.0013,graphite,axis,parent,n=6,fillet=.00025)


# The external dimensions are clear of the packed equipment.
width,depth,rim,wall,base = {
    'Small': (.50,.326,.185,.013,.031),
    'Medium': (.81,.542,.259,.018,.043),
    'Large': (1.23,.722,.643,.026,.057),
}[args.size]
lid_depth={'Small':.050,'Medium':.063,'Large':.061}[args.size]
lid=object_with_data('Lid',parent=root,point=(0,depth/2+.010,rim))
contents=object_with_data('Contents',parent=root)
contents['purpose']='Packed props can be removed individually from this floor-relative group'


def shell(label,sections,mat,rounding,parent=root):
    """Join inner and outer wall profiles with a solid floor and a rim."""
    n=8
    points=[(x,y,z) for z,w,d,c in sections for x,y in octagon(w,d,c)]
    faces=[tuple(range(n-1,-1,-1))]
    for start in range(0,len(points)-n,n):
        for i in range(n):
            j=(i+1)%n
            faces.append((start+i,start+j,start+n+j,start+n+i))
    faces.append(tuple(range(len(points)-n,len(points))))
    return geom(label,points,faces,mat,rounding,parent)


def collar(label,z0,z1,w,d,inner_w,inner_d,mat,parent=root):
    outer=octagon(w,d,min(d*.08,.043))
    inner=octagon(inner_w,inner_d,min(d*.062,.028))
    points=[(x,y,z) for z,contour in [(z0,outer),(z0,inner),(z1,outer),(z1,inner)] for x,y in contour]
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,8+j,8+i),(i,16+i,16+j,j),
                      (8+i,8+j,24+j,24+i),(16+i,24+i,24+j,16+j)])
    return geom(label,points,faces,mat,.0024,parent)


corner=depth*.076
base_panel=shell('Moulded_cargo_shell',[
    (.012,width-.049,depth-.040,corner),(.035,width-.019,depth-.015,corner),
    (rim-.032,width-.017,depth-.016,corner),(rim-.014,width,depth,corner),
    (rim,width,depth,corner),(rim,width-wall*2,depth-wall*2,corner*.69),
    (base+.009,width-wall*2-.016,depth-wall*2-.014,corner*.76),
    (base,width-wall*2-.028,depth-wall*2-.026,corner*.70),
],white,min(.006,wall*.29))
collar('Base_pallet_rail',.014,base*.92,width-.005,depth-.004,width-.079,depth-.060,graphite)
collar('Split_line_rim',rim-.024,rim-.002,width+.004,depth+.005,width-wall*2-.004,depth-wall*2-.004,dark)
collar('Compression_gasket',rim-.004,rim+.003,width-.009,depth-.011,width-wall*2+.002,depth-wall*2+.002,rubber)
lid_panel=shell('Ribbed_lid_skin',[
    (rim+lid_depth,width-.063,depth-.046,corner*.80),
    (rim+lid_depth*.80,width-.024,depth-.020,corner),
    (rim+.023,width-.008,depth-.009,corner),
    (rim+.006,width-.020,depth-.020,corner),
    (rim+.006,width-.074,depth-.061,corner*.79),
    (rim+lid_depth-.020,width-.102,depth-.095,corner*.73),
],white,.006,lid)
# A shallow interior liner seats behind the lid membrane.
block('Recessed_lid_liner',(0,0,rim+lid_depth-.026),(width-.104,depth-.097,.012),graphite,.005,lid,corner=.030)
for y_factor in (-.28,0,.28):
    y=depth*y_factor
    block('Pressed_lid_stiffener',(0,y,rim+lid_depth+.0005),(width*.72,depth*.092,.013),white,.006,lid,corner=.007)
    block('Liner_stiffener',(0,y,rim+lid_depth-.032),(width*.70,.021,.013),dark,.004,lid)
for side in (-1,1):
    for back in (-1,1):
        x=side*(width/2-.042)
        y=back*(depth/2-.040)
        block('Stacking_foot',(x,y,.012),(min(.091,width*.13),min(.094,depth*.21),.024),rubber,.008,corner=.009)
        block('Corner_impact_rail',(x,y,rim*.48),(.077,.061,rim*.79),orange,.009,corner=.012)
        block('Lid_corner_cap',(x,y,rim+lid_depth*.61),(.079,.066,lid_depth*.68),orange,.008,lid,corner=.010)
        for z in (rim*.26,rim*.68):
            bolt('Corner_captive_fastener',(x,y+back*.030,z),(0,back,0),.0046)
        bolt('Lid_corner_fastener',(x,y,rim+lid_depth*.98),r=.0049,parent=lid)
    # Exterior side handles.
    x=side*(width*.49)
    z=rim*.51
    for y in (-depth*.19,depth*.19):
        block('Metal_haul_handle_socket',(x,y,z),(.028,.056,.061),dark,.005)
        bolt('Haul_handle_socket_bolt',(x+side*.016,y,z+.016),(side,0,0),.004)
    sweep('Haul_handle_frame',[(x,-depth*.19,z),(x+side*.029,-depth*.165,z-.010),
          (x+side*.035,-depth*.104,z-.017),(x+side*.035,depth*.104,z-.017),
          (x+side*.029,depth*.165,z-.010),(x,depth*.19,z)],.0075,steel)
    rod('Replaceable_haul_grip',(x+side*.035,-depth*.102,z-.017),
        (x+side*.035,depth*.102,z-.017),.012,rubber)

for i in range(6 if args.size=='Large' else 4):
    x=width*((i-(2.5 if args.size=='Large' else 1.5))*(.129 if args.size=='Large' else .177))
    height=rim*.63
    for y in (-depth/2+.023,depth/2-.023):
        block('External_formed_rib',(x,y,rim*.445),(.031,.039,height),white,.005,corner=.006)

# Lid hinge pins sit on the pivot axis. Latches are modelled in the released position.
for x in [-width*.28,width*.28]:
    y=depth/2+.010
    block('Rear_hinge_leaf',(x,y-.002,rim-.029),(.081,.021,.068),dark,.006)
    block('Lid_hinge_leaf',(x,y-.002,rim+.025),(.080,.020,.056),dark,.005,lid)
    for offset,parent in [(-.032,root),(-.013,lid),(.006,root),(.025,lid),(.038,root)]:
        cylinder('Hinge_knuckle',(x+offset,y,rim),.013,.015,alloy,(1,0,0),parent,n=22)
    rod('Hinge_pin',(x-.047,y,rim),(x+.047,y,rim),.0053,steel)
    for xx in (x-.024,x+.024):
        bolt('Hinge_leaf_fastener',(xx,y+.011,rim-.046),(0,1,0),.004)
        bolt('Lid_leaf_fastener',(xx,y+.010,rim+.037),(0,1,0),.004,lid)
    y=-depth/2
    block('Quick_release_latch_mount',(x,y-.011,rim-.044),(.069,.028,.078),graphite,.006)
    block('Latch_lever',(x,y-.028,rim-.040),(.043,.020,.058),orange,.007)
    for j in range(3):
        block('Latch_finger_ridge',(x,y-.039,rim-.057+.011*j),(.024,.005,.005),graphite,.0015)
    bolt('Latch_axle_boss',(x-.030,y-.017,rim-.035),(-1,0,0),.0047)
    block('Lid_latch_receiver',(x,y+.002,rim+.017),(.070,.023,.029),dark,.004,lid)
    rod('Latch_receiver_bar',(x-.023,y-.016,rim+.014),(x+.023,y-.016,rim+.014),.005,steel,lid)

# Crate-specific protective liners and recognizable, individually removable items.
if args.size=='Small':
    block('Equipment_tray',(0,0,.032),(width-.050,depth-.047,.019),slate,.007,corner=.020)
    for y in (-.120,.120):
        block('Load_guard_insert',(-.103,y,.072),(.220,.030,.064),slate,.007)
    for x in (.024,.208):
        block('Cable_caddy_retainer',(x,.003,.062),(.017,.177,.050),slate,.004)
    light_item=object_with_data('WorkLight',parent=contents,point=(-.105,-.018,.085))
    lead=object_with_data('CoiledPowerLead',parent=contents,point=(.112,.012,.061))
    block('Work_light_cooling_body',(-.107,-.019,.101),(.202,.142,.073),dark,.011,light_item,corner=.015)
    for i in range(6):
        block('Work_light_rear_fin',(-.181+i*.030,-.017,.068),(.009,.118,.014),alloy,.002,light_item)
    block('Work_light_orange_frame',(-.107,-.019,.141),(.210,.150,.030),orange,.010,light_item,corner=.019)
    block('Work_light_recess',(-.107,-.019,.157),(.169,.111,.012),graphite,.006,light_item,corner=.010)
    block('Work_light_diffuser',(-.107,-.019,.163),(.139,.086,.006),lamp,.004,light_item)
    for x in (-.161,-.133,-.106,-.079,-.052):
        block('Work_light_lens_flute',(x,-.019,.166),(.003,.080,.0013),steel,.0004,light_item)
    for side in (-1,1):
        bolt('Work_light_tilt_pin',(-.107+side*.113,-.019,.112),(side,0,0),.006,light_item)
    sweep('Work_light_folded_stand',[(-.221,-.020,.110),(-.222,.077,.080),(-.203,.101,.074),
          (-.010,.101,.074),(.007,.080,.080),(.006,-.020,.110)],.0075,steel,light_item)
    block('Stand_grip',(-.106,.101,.075),(.091,.025,.023),rubber,.005,light_item)
    # One continuous cable in a shallow winding, with plugs at the ends.
    def cable_point(t):
        a=t*2*pi
        return (.111+(.071-.006*t)*cos(a),.013+(.098-.006*t)*sin(a),.067+.0065*t)
    coil=[cable_point(i/50) for i in range(201)]
    sweep('Wound_service_lead',coil,.0049,rubber,lead)
    for i,point in enumerate((coil[0],coil[-1])):
        x,y,z=point
        gland_y=y+(.012 if i==0 else -.013)
        cylinder('Plug_strain_relief',(x,gland_y,z),.009,.024,rubber,(0,1,0),lead,n=18)
        block('Keyed_lead_plug',(x,gland_y+(.017 if i==0 else -.019),z),(.026,.034,.023),
              orange if i==0 else dark,.004,lead)
        cylinder('Shrouded_plug_nose',(x,gland_y+(.036 if i==0 else -.037),z),.010,.013,
                 alloy,(0,1,0),lead,n=16)
    for y in (-.063,.076):
        block('Cable_bundle_strap',(.106,y,.095),(.147,.020,.014),slate,.004,lead)
        block('Bundle_strap_tab',(.168,y,.104),(.026,.019,.006),orange,.002,lead)
elif args.size=='Medium':
    block('Modular_fabric_lined_tray',(0,0,.047),(.748,.478,.022),slate,.008,corner=.025)
    for y in (-.213,.096):
        block('Seat_pack_foam_bolster',(-.084,y,.073),(.526,.036,.057),slate,.009)
    for x in (-.304,.307):
        block('Rack_rail_foam_saddle',(x,.173,.071),(.074,.132,.046),slate,.009)
    chair=object_with_data('FoldedChair',parent=contents,point=(-.091,-.062,.080))
    rails=object_with_data('RackRails',parent=contents,point=(.013,.174,.112))
    # Folded chair with a distinct padded seat, articulated back frame and crossed legs.
    block('Chair_padded_seat',(-.123,-.062,.146),(.331,.261,.061),slate,.015,chair,corner=.034)
    block('Seat_edge_binding',(-.123,-.062,.137),(.340,.269,.021),rubber,.007,chair,corner=.034)
    block('Chair_folded_backrest',(.139,-.061,.127),(.155,.210,.050),slate,.013,chair,corner=.027)
    for k in range(6):
        block('Backrest_stitched_rib',(.099+k*.016,-.061,.154),(.003,.174,.002),graphite,.0007,chair)
    for y in (-.194,.070):
        sweep('Seat_transport_frame',[(-.301,y,.110),(-.282,y,.147),(-.245,y,.153),(.021,y,.153),
                (.062,y,.139),(.084,y,.127)],.012,alloy,chair)
        sweep('Backrest_hinge_frame',[(.057,y,.124),(.083,y,.120),(.202,y,.122),(.234,y*.79,.126)],
                .011,steel,chair)
        bolt('Seat_hinge_boss',(.063,y,.124),(0,-1 if y<0 else 1,0),.009,chair)
    for y in (-.169,.047):
        rod('Folded_cross_leg_a',(-.286,y,.088),(.166,y,.108),.011,dark,chair)
        rod('Folded_cross_leg_b',(.177,y,.082),(-.242,y,.107),.011,alloy,chair)
        for x in (-.275,.176):
            block('Folded_chair_rubber_foot',(x,y,.084),(.040,.030,.030),rubber,.005,chair)
    rod('Folded_leg_crossbar',(-.271,-.171,.079),(-.271,.051,.079),.011,steel,chair)
    block('Folded_chair_retainer',(.022,-.060,.183),(.032,.245,.012),graphite,.004,chair)
    block('Chair_release_tab',(.023,-.168,.189),(.042,.049,.007),orange,.003,chair)
    # Two open-channel rails and small mounting brackets in the same removable item.
    for y in (.145,.204):
        block('Slotted_rack_channel_floor',(.000,y,.101),(.661,.040,.013),alloy,.004,rails)
        for dy in (-.016,.016):
            block('Rack_channel_flange',(0,y+dy,.114),(.657,.007,.026),dark,.002,rails)
        for j in range(10):
            block('Rail_mounting_slot',(-.279+j*.062,y,.108),(.027,.010,.002),graphite,.0008,rails)
        for x in (-.318,.318):
            block('Rack_channel_end_cap',(x,y,.117),(.027,.043,.030),orange,.003,rails)
    for x in (-.181,.182):
        block('Rack_angle_base',(x,.175,.134),(.058,.100,.008),steel,.003,rails)
        block('Rack_angle_return',(x,.208,.148),(.057,.011,.027),alloy,.003,rails)
        for y in (.151,.185):
            bolt('Rack_fixing_hardware',(x,y,.138),r=.0042,parent=rails)
else:
    block('Cradle_fabric_lined_tray',(0,0,.063),(1.147,.629,.021),slate,.009,corner=.042)
    # Foot stop, split pedestal cradle and screen-end bumpers. The connector and
    # keypad faces float above the liner with the terminal lying on its back.
    block('Base_end_energy_absorber',(-.569,0,.142),(.031,.548,.145),slate,.009)
    block('Display_end_energy_absorber',(.568,.0,.185),(.031,.532,.218),slate,.009)
    for side in (-1,1):
        block('Lower_runner_padded_bolster',(-.518,side*.195,.095),(.052,.097,.049),slate,.008)
        block('Pedestal_saddle_side',(-.313,side*.122,.112),(.133,.057,.078),slate,.008)
        block('Pedestal_saddle_pocket',(-.313,side*.066,.115),(.119,.044,.132),slate,.008)
        block('Display_head_padded_saddle',(.409,side*.207,.113),(.081,.088,.096),slate,.009)
        block('Display_guard_side_wall',(.325,side*.327,.154),(.299,.032,.168),slate,.009)
        block('Lift_access_webbing_loop',(-.343,side*.249,.097),(.148,.037,.011),graphite,.004)
        block('Webbing_release_tab',(-.282,side*.249,.105),(.026,.035,.009),orange,.003)
    block('Pedestal_low_side_clearance',(-.091,.0,.077),(.070,.133,.018),slate,.006)

    if not args.terminal or not args.terminal.is_file():
        raise ValueError('Supply the finished Site_Plan_Terminal.blend for the large crate.')
    with bpy.data.libraries.load(str(args.terminal),link=False) as (source, loaded):
        assert 'Site Plan Terminal' in source.collections
        loaded.collections=['Site Plan Terminal']
    terminal_col=loaded.collections[0]
    imported_root=terminal_col.objects['SitePlanTerminal']
    terminal_meshes=[obj for obj in terminal_col.objects if obj.type=='MESH']
    # Preserve the existing model as a rigid packed payload in its own node.
    packed=object_with_data('PackedSitePlanTerminal',parent=contents)
    packed.matrix_basis=Matrix(((0,0,1,-.5575),(-1,0,0,0),(0,-1,0,.350),(0,0,0,1)))
    packed['payload_scene']='Site_Plan_Terminal.glb'
    bpy.context.view_layer.update()
    for obj in terminal_meshes:
        chain=obj.matrix_basis.copy()
        current=obj.parent
        while current and current!=imported_root:
            chain=current.matrix_basis @ chain
            current=current.parent
        terminal_col.objects.unlink(obj)
        model.objects.link(obj)
        obj.parent=packed
        obj.matrix_basis=chain
        old=obj.data.materials[0]
        obj.data.materials[0]=bpy.data.materials[old.name.split('.')[0]]
        if obj.name=='Screen':
            obj.name='Packed_terminal_glass_dark_glass'
    for obj in list(terminal_col.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(terminal_col)

root['open_angle_degrees']=103.0


def scuffs(target, center, tangent, normal, spread, length_range, count, salt, finishes):
    """Project small irregular marks onto the evaluated surface."""
    evaluated = target.evaluated_get(bpy.context.evaluated_depsgraph_get())
    to_local = target.matrix_world.inverted()
    to_world = target.matrix_world
    along = Vector(tangent).normalized()
    outward = Vector(normal).normalized()
    across = outward.cross(along)
    direction = (to_local.to_3x3() @ -outward).normalized()
    rng = random.Random(salt)
    shapes = defaultdict(lambda: ([],[]))
    outline = [(-.50,-.24),(-.20,.50),(.25,.41),(.51,.06),(.23,-.37),(-.21,-.50)]
    for _ in range(count):
        mid = Vector(center) + along*rng.uniform(-spread[0],spread[0]) + across*rng.uniform(-spread[1],spread[1])
        length = rng.uniform(*length_range)
        width = length*rng.uniform(.11,.44)
        hits = []
        for sx,sy in outline:
            v = mid + along*length*(sx+rng.uniform(-.14,.14)) + across*width*(sy+rng.uniform(-.13,.13))
            hit, point, face_normal, _ = evaluated.ray_cast(to_local @ (v+outward*.023),direction,distance=.041)
            if not hit or face_normal.dot(-direction)<.37:
                break
            hits.append(to_world @ (point + face_normal*.00023))
        if len(hits)==len(outline):
            verts,faces = shapes[rng.choice(finishes)]
            start = len(verts)
            verts.extend(hits)
            faces.append(tuple(reversed(range(start,start+len(hits)))))
    for mat,(verts,faces) in shapes.items():
        origin=target.parent.matrix_world.translation
        geom('Contact_wear_'+target.name,[v-origin for v in verts],faces,mat,
             parent=target.parent,point=origin)


bpy.context.view_layer.update()
for i,obj in enumerate(list(model.objects)):
    if obj.name.startswith(('Corner_impact_rail','Lid_corner_cap','Latch_lever')):
        x,y,z=obj.matrix_world.translation
        side=-1 if y<0 else 1
        scuffs(obj,(x,y+side*.028,z),(0,0,1),(0,side,0),
               (min(rim*.28,.086),.028),(.0018,.012),59,i+13,(graphite,alloy,graphite))
        if 'Lid_corner' in obj.name:
            scuffs(obj,(x,y,z+lid_depth*.34),(1,0,0),(0,0,1),
                   (.032,.026),(.0018,.012),39,i+157,(graphite,alloy))
scuffs(base_panel,(0,-depth*.494,rim*.27),(1,0,0),(0,-1,.15),
       (width*.40,rim*.16),(.002,.014),138,124,(warm,graphite,alloy))
scuffs(lid_panel,(0,-depth*.415,rim+lid_depth*.84),(1,0,0),(0,0,1),
       (width*.41,depth*.035),(.002,.016),103,36,(graphite,alloy,graphite))


def uv_point(p,n,offset=(0,0)):
    axis=max(range(3),key=lambda i:abs(n[i]))
    u,v=[i for i in range(3) if i!=axis]
    sign=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u]*5.0*sign+offset[0],p[v]*5.0+offset[1])


for obj in model.objects:
    if obj.type!='MESH':
        continue
    rng=random.Random(obj.name)
    if 'uv_offset' not in obj:
        obj['uv_offset']=(rng.random(),rng.random())
    if obj.data.uv_layers:
        continue
    layer=obj.data.uv_layers.new(name='Surface UV')
    offset=obj['uv_offset']
    for face in obj.data.polygons:
        for index in face.loop_indices:
            point=obj.data.vertices[obj.data.loops[index].vertex_index].co
            layer.data[index].uv=uv_point(point,face.normal,offset)


def export_game():
    # Meshes share material batches inside the shell, lid and each payload.
    stage=bpy.data.collections.new('Game export')
    scene.collection.children.link(stage)
    copies={}
    originals={}
    anchors=[root,lid,contents,*sorted(contents.children,key=lambda obj:obj.name)]
    for part in anchors:
        originals[part]=part.name
        part.name='Source__'+part.name
        copy=bpy.data.objects.new(originals[part],None)
        stage.objects.link(copy)
        copy.parent=copies.get(part.parent)
        copy.matrix_basis=part.matrix_basis.copy()
        for key in part.keys():
            copy[key]=part[key]
        copies[part]=copy
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for parent,anchor in copies.items():
        bins=defaultdict(list)
        for obj in parent.children:
            if obj.type=='MESH':
                bins[obj.data.materials[0]].append(obj)
        for mat,parts in bins.items():
            verts,normals,uvs,triangles=[],[],[],[]
            indices={}
            for obj in parts:
                evaluated=obj.evaluated_get(dg)
                mesh=evaluated.to_mesh()
                mesh.calc_loop_triangles()
                xf=anchor.matrix_world.inverted() @ obj.matrix_world
                norm_mat=xf.to_3x3().inverted().transposed()
                for tri in mesh.loop_triangles:
                    points=[xf @ mesh.vertices[i].co for i in tri.vertices]
                    if (points[1]-points[0]).cross(points[2]-points[0]).length_squared<1e-20:
                        continue
                    face=[]
                    for point in points:
                        coordinate=tuple(round(c,7) for c in point)
                        if coordinate not in indices:
                            indices[coordinate]=len(verts)
                            verts.append(point)
                        face.append(indices[coordinate])
                    if len(set(face))<3:
                        continue
                    triangles.append(face)
                    normals.extend((norm_mat @ mesh.corner_normals[i].vector).normalized() for i in tri.loops)
                    uvs.extend(uv_point(mesh.vertices[k].co,tri.normal,obj['uv_offset']) for k in tri.vertices)
                evaluated.to_mesh_clear()
            name=f'{anchor.name}_{mat.name}'
            mesh=bpy.data.meshes.new(name)
            mesh.from_pydata(verts,[],triangles)
            mesh.update()
            mesh.materials.append(mat)
            for poly in mesh.polygons:
                poly.use_smooth=True
            mesh.normals_split_custom_set(normals)
            layer=mesh.uv_layers.new(name='Surface UV')
            for loop,st in zip(layer.data,uvs):
                loop.uv=st
            part=bpy.data.objects.new(name,mesh)
            stage.objects.link(part)
            part.parent=anchor
            part['material_role']=mat.name
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in stage.objects:
        o.select_set(True)
    path=args.package/'original'/f'Fitout_Crate_{args.size}.glb'
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                             export_extras=True,export_yup=True,export_tangents=True)
    for o in list(stage.objects):
        bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.collections.remove(stage)
    for part,name in originals.items():
        part.name=name
    for mesh in list(bpy.data.meshes):
        if mesh.users==0:
            bpy.data.meshes.remove(mesh)


export_game()
for view in bpy.data.screens:
    for area in view.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.color_type='MATERIAL'
            space.overlay.show_extras=False
            space.region_3d.view_location=(0,0,rim*.58)
            space.region_3d.view_rotation=Vector((-1,1.7,-1.2)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=width*2.32
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/f'Fitout_Crate_{args.size}.blend'),compress=True)
