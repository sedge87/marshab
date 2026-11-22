"""Build and export the Landing Site. Run with Blender from any directory."""
from pathlib import Path
from collections import defaultdict
from math import cos, sin, pi, radians, hypot, acos, atan2
import argparse
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector


def inputs():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('Walker 1')
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


amber = material('lamp_amber','D08A42',.32,.05)
white_lamp = material('lamp_white','E3DACC',.31,.04)
slate = material('slate_panel','5E6464',.67,.12)
paint = material('white_painted','C9C7B8',.54,.05)
root = object_with_data('Walker1')
root['front_axis_godot']='-Z'
body = object_with_data('Body',parent=root)
module = object_with_data('HabitatModule',parent=body)
socket = object_with_data('PowerSocket',parent=body,point=(-1.02,2.225,.745))
socket['purpose']='Align to the Power Module SocketFace with opposing outward normals'
lamp = object_with_data('Lamp',parent=body,point=(1.76,1.77,2.70))


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


# Load-bearing deck and triangulated chassis frame.
frame=block('frame',(0,0,1.38),(3.31,4.42,.235),white,.047,body,corner=.167)
frame.name='frame_rover_white'
block('Tapered_skid_belly',(0,-.02,1.151),(2.57,3.93,.329),dark,.058,body,corner=.18)
block('Habitat_floor',(0,-.021,1.542),(2.75,3.85,.130),slate,.029,module,corner=.046)
for side in (-1,1):
    x=side*1.583
    for z in (1.306,1.500):
        block('Continuous_chassis_capped_chord',(x,0,z),(.124,4.22,.065),alloy,.014,body)
    for i in range(8):
        y=-1.82+i*.515
        rod('Diagonal_side_web',(x-side*.012,y-.184,1.332),(x-side*.012,y+.171,1.477),.033,steel,body)
        block('Chassis_technical_inset',(side*1.512,y,1.398),(.027,.392,.165),graphite,.016,body)
    for y in (-1.626,-.006,1.631):
        block('Hip_frame_shear_plate',(side*1.644,y,1.383),(.128,.338,.277),orange,.024,body)
        for dz in (-.092,.089):
            bolt('Shear_plate_captive_bolt',(side*1.714,y,1.389+dz),(side,0,0),.022,body)
    for y in (-1.95,-.9,.9,1.95):
        block('Deck_corner_footprint_runner',(side*1.464,y,1.553),(.19,.167,.059),graphite,.014,body)
    sweep('Chassis_braided_power_feed',[(side*1.423,-1.84,1.136),(side*1.413,-1.44,1.047),
          (side*1.420,-.54,1.026),(side*1.423,.54,1.030),(side*1.410,1.40,1.052),
          (side*1.419,1.84,1.141)],.027,rubber,body)
    for y in (1.57,.55,-.55,-1.57):
        block('Chassis_feed_retainers',(side*1.428,y,1.070),(.081,.060,.060),alloy,.010,body)
    for y in (-1.45,1.46):
        block('Body_park_load_jack',(side*1.00,y,.674),(.227,.263,.537),dark,.023,body)
        block('Spring_ground_plate',(side*1.00,y,.451),(.288,.324,.062),graphite,.016,body)
block('Front_impact_apron',(0,2.152,1.228),(3.02,.156,.296),white,.030,body,corner=.095)
block('Raised_front_interface_spine',(0,2.222,1.190),(2.69,.074,.185),graphite,.020,body)
for x in (-.67,.03,.56):
    for i in range(4):
        block('Forward_service_air_relief',(x,2.263,1.135+i*.031),(.216,.009,.009),alloy,.002,body)
block('Rear_field_junction',(0,-2.18,1.308),(2.66,.103,.283),graphite,.024,body,corner=.076)
for x in (-1.32,1.32):
    for y in (-2.11,2.11):
        block('Replaceable_deck_edge_endcap',(x,y,1.469),(.238,.169,.184),orange,.023,body)
        bolt('Endcap_socket',(x,y,1.565),r=.021,parent=body)
for y in (-1.714,1.713):
    for x in (-1.131,1.131):
        bolt('Footing_anchor',(x,y,1.615),r=.016,parent=body)

# Reinforced active socket at the front apron. The battery attaches face to face
# and its skid meets the two low support rails in both vehicle poses.
sx,sy,sz=-1.02,2.225,.745
def ring_y(name,center,outer,inner,depth,mat,parent):
    x,y,z=center
    coords=[(x+u,y+offset,z+v) for offset,c in [(-depth/2,outer),(-depth/2,inner),
                                              (depth/2,outer),(depth/2,inner)] for u,v in c]
    n=len(outer)
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(i,2*n+i,2*n+j,j),
                   (n+i,n+j,3*n+j,3*n+i),(2*n+i,3*n+i,3*n+j,2*n+j)])
    return geom(name,coords,fs,mat,.004,parent)

block('Socket_reinforced_backplate',(sx,sy-.115,sz+.165),(.658,.149,.672),graphite,.023,body,corner=.045)
block('Receiver_back_wall',(sx,sy-.057,sz),(.601,.068,.366),dark,.023,body)
ring_y('Orange_keyed_receiver_surround',(sx,sy-.056,sz),octagon(.585,.366,.043),
       octagon(.481,.272,.022),.057,orange,body)
ring_y('Receiver_inner_guide',(sx,sy-.020,sz),octagon(.467,.263,.025),
       octagon(.449,.244,.020),.036,steel,body)
for x in (-.265,.265):
    for z in (-.110,.110):
        bolt('Receiver_frame_captive_screw',(sx+x,sy+.006,sz+z),(0,1,0),.012,body)
for x,z,r in [(-.066,.002,.018),(.021,.012,.018),(.070,-.015,.015)]:
    cylinder('Receiver_contact_guard',(sx+x,sy-.014,sz+z),r+.008,.018,rubber,(0,1,0),body,n=26)
    cylinder('Recessed_receiver_contact',(sx+x,sy-.002,sz+z),r*.53,.010,steel,(0,1,0),body)
for side in (-1,1):
    x=sx+side*.241
    block('Power_cassette_bridge_rail',(x,sy+.492,.444),(.084,.969,.064),alloy,.011,body)
    rod('Battery_rack_stiffener',(x,sy+.012,.597),(x,sy+.711,.434),.028,dark,body)
    block('Rack_end_wear_pad',(x,sy+.921,.461),(.087,.098,.027),orange,.006,body)
    for y in (sy+.095,sy+.87):
        bolt('Battery_rack_end_bolt',(x,y,.473),r=.010,parent=body)

# Human-scale ladder and reader carried by the original chassis.
for x in (.811,1.286):
    sweep('Boarding_ladder_stile',[(x,2.41,.472),(x,2.38,.552),(x,2.28,1.35),
          (x,2.213,1.620),(x,2.126,1.702)],.035,steel,body)
for i in range(5):
    z=.625+i*.221
    y=2.398-i*.039
    block('Ribbed_ladder_tread',(1.048,y,z),(.448,.153,.035),graphite,.009,body)
    for x in (.847,1.25):
        bolt('Ladder_tread_captive_pin',(x,y,z+.021),r=.010,parent=body)
block('Boarding_apron',(1.024,2.085,1.567),(.663,.488,.095),alloy,.019,body)
for j in range(7):
    block('Boarding_apron_grip',(1.026,1.895+j*.056,1.618),(.560,.027,.012),graphite,.004,body)
sweep('Top_ladder_handrail',[(1.329,2.253,1.562),(1.346,2.268,1.914),
       (1.353,2.180,1.996),(1.353,1.947,1.993),(1.349,1.882,1.848),
       (1.337,1.870,1.594)],.022,orange,body)
block('Deck_reader_mast',(.568,2.014,1.754),(.109,.118,.287),dark,.015,body)
reader=Vector((.589,2.115,1.924))
u=Vector((1,0,0))
v=Vector((0,-.388,.922)).normalized()
# The normal faces forward and is inclined into the operator's sight.
screen_normal=-u.cross(v).normalized()
v=-v
screen_q=Matrix((u,v,screen_normal)).transposed().to_quaternion()
for name,d,w,h,t,mat in [('Reader_impact_shell',-.035,.405,.262,.080,white),
        ('Reader_inset_bezel',.008,.375,.232,.027,graphite)]:
    o=block(name,reader+screen_normal*d,(w,h,t),mat,.012,body)
    o.rotation_mode='QUATERNION'
    o.rotation_quaternion=screen_q
ww,hh=.320,.180
screen=geom('Deck_reader_glass',[(-ww/2,-hh/2,0),(ww/2,-hh/2,0),(ww/2,hh/2,0),(-ww/2,hh/2,0)],
        [(0,1,2,3)],glass,0,body,point=reader+screen_normal*.024,object_name='DeckScreen')
screen.rotation_mode='QUATERNION'
screen.rotation_quaternion=screen_q
screen.data.update()
if screen.data.polygons[0].normal.z<0:
    screen.data.polygons[0].flip()
uv=screen.data.uv_layers.new(name='Screen UV')
for loop in screen.data.loops:
    co=screen.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(.5-co.x/ww,.5-co.y/hh)

# Beacon, cameras and short aerial clear the packed panel stack.
mast_x,mast_y=1.76,1.77
block('Outrigged_sensor_foot',(mast_x,mast_y,1.536),(.349,.321,.154),dark,.033,body)
cylinder('Sensor_mast', (mast_x,mast_y,2.004),.083,.888,white,parent=body,fillet=.012)
for z in (1.672,2.015,2.355):
    cylinder('Sensor_mast_strap',(mast_x,mast_y,z),.097,.065,orange,parent=body)
block('Navigation_head',(mast_x,mast_y,2.476),(.471,.272,.184),white,.024,body,corner=.045)
for x in (mast_x-.133,mast_x+.133):
    cyl_axis=(0,1,0)
    cylinder('Navigation_camera_guard',(x,mast_y+.135,2.477),.076,.049,dark,cyl_axis,body,n=36)
    cylinder('Navigation_camera_optic',(x,mast_y+.165,2.477),.050,.012,glass,cyl_axis,body,n=38)
cylinder('Lamp_base',(mast_x,mast_y,2.655),.092,.066,graphite,parent=lamp,n=32)
glow=cylinder('lamp_glow',(mast_x,mast_y,2.704),.071,.071,amber,parent=lamp,n=36)
glow.name='lamp_glow_lamp_amber'
cylinder('Lamp_dust_cap',(mast_x,mast_y,2.753),.087,.033,white,parent=lamp,n=32)
rod('Navigation_whip',(1.948,1.627,2.523),(2.021,1.609,3.068),.012,steel,body)

# Wheel-ended legs, each with the same two-link rig and a coaxial wheel.
upper_length,lower_length,hip_z,wheel_r=1.15,.96,1.39,.414
legs=[]
for row,y in enumerate((1.626,0,-1.626)):
    for side in (-1,1):
        index=row*2+(1 if side<0 else 2)
        x=side*1.668
        knee=x+upper_length
        axle=knee+lower_length
        hip=object_with_data(f'Leg_{index}',parent=body,point=(x,y,hip_z))
        upper=object_with_data(f'UpperLeg_{index}',parent=hip,point=(x,y,hip_z))
        lower=object_with_data(f'LowerLeg_{index}',parent=upper,point=(knee,y,hip_z))
        carrier=object_with_data(f'AxleCarrier_{index}',parent=lower,point=(axle,y,hip_z))
        wheel=object_with_data(f'Wheel_{index}',parent=carrier,point=(axle,y,hip_z))
        legs.append((hip,upper,lower,carrier,wheel,side))
        for anchor,start,length,thick in ((upper,x,upper_length,.234),(lower,knee,lower_length,.190)):
            avg=start+length/2
            block('Vented_structural_link',(avg,y,hip_z),(length-.086,thick,.173),white,.030,anchor,corner=.058)
            block('Link_recess_dark',(avg,y,hip_z+.086),(length*.66,thick*.57,.044),graphite,.012,anchor)
            for u in (-.18,.12):
                block('Load_web_crossmember',(avg+u,y,hip_z+.114),(.062,thick*.80,.037),
                      alloy,.009,anchor)
            rod('Hydraulic_cylinder_housing',(start+.092,y+.107,hip_z-.102),
                (start+length*.65,y+.107,hip_z-.104),.069,dark,anchor)
            rod('Polished_piston_rod',(start+length*.54,y+.107,hip_z-.104),
                (start+length-.071,y+.107,hip_z-.106),.032,steel,anchor)
            sweep('Link_cable_guard',[(start+.08,y-.10,hip_z+.081),
                   (start+.15,y-.149,hip_z+.108),(start+length*.49,y-.159,hip_z+.108),
                   (start+length*.76,y-.140,hip_z+.114),
                   (start+length-.066,y-.057,hip_z+.117)],.020,rubber,anchor)
            for distance in (.25,length*.62):
                block('Cable_clamp_orange',(start+distance,y-.143,hip_z+.110),(.042,.049,.038),
                      orange,.007,anchor)
        for node,xx,r in ((upper,x,.166),(lower,knee,.147)):
            cylinder('Link_pin_boss',(xx,y,hip_z),r,.284,dark,(0,1,0),node,n=32,fillet=.012)
            for t in (-1,1):
                cylinder('Pin_service_face',(xx,y+t*.151,hip_z),r*.82,.029,alloy,(0,t,0),node,n=32)
                bolt('Link_pin_centre',(xx,y+t*.170,hip_z),(0,t,0),.024,node)
        block('Wheel_hub_outboard_carrier',(axle-.02,y,hip_z+.146),(.207,.269,.277),
              white,.026,carrier,corner=.042)
        block('Wheel_hub_upper_guard',(axle+.099,y,hip_z+.188),(.088,.229,.108),orange,.013,carrier)
        cylinder('Wheel_compliant_tyre',(axle,y,hip_z),.389,.229,rubber,(1,0,0),wheel,n=44,fillet=.032)
        for k in range(24):
            a=k*pi/12
            for right in (-1,1):
                angle=a+right*.037
                r=.388
                center=(axle+right*.066,y+r*cos(angle),hip_z+r*sin(angle))
                tread_part=block('Wheel_tread_block',center,(.117,.052,.074),rubber,.009,wheel,corner=.013)
                tread_part.rotation_euler.x=angle
        for t in (-1,1):
            xx=axle+t*.117
            cylinder('Wheel_hub',(xx,y,hip_z),.236,.038,dark,(t,0,0),wheel,n=36)
            cylinder('Wheel_hub_face',(xx+t*.027,y,hip_z),.206,.035,alloy,(t,0,0),wheel,n=36)
            cylinder('Wheel_hub_core',(xx+t*.048,y,hip_z),.109,.034,graphite,(t,0,0),wheel,n=32)
            for q in range(8):
                a=q*pi/4
                bolt('Wheel_hub_captive_screw',(xx+t*.050,y+.159*cos(a),hip_z+.159*sin(a)),
                     (t,0,0),.013,wheel)
        if index==1:
            seal=cylinder('Fault_seal',(axle+.182,y,hip_z),.128,.026,rubber,(1,0,0),wheel,
                         n=40,fillet=.004,object_name='SealRing')
            seal['purpose']='Front-left wheel hub seal for dust, frost and patch VFX'
            # The cap inside the annulus reads as a separate metal centre.
            cylinder('Seal_inner_axle_face',(axle+.200,y,hip_z),.096,.019,alloy,(1,0,0),wheel,n=34)

# The habitat travels as layered panels and raises into a compact weather shell.
wall_floor=1.609
wall_top=3.739
walls={}
for name,x,y,z in [('SideWall_L',-1.377,0,wall_floor),('SideWall_R',1.377,0,wall_floor),
                   ('EntryWall',0,1.863,wall_floor),('RearWall',0,-1.906,wall_floor),
                   ('Roof',0,-.020,3.817)]:
    walls[name]=object_with_data(name,parent=module,point=(x,y,z))

for side in (-1,1):
    wall=walls['SideWall_L' if side<0 else 'SideWall_R']
    x=side*1.377
    block('Formed_thermal_wall',(x,-.019,2.660),(.125,3.719,2.102),white,.036,wall)
    block('Panel_outer_press_pearl',(x+side*.070,-.028,2.662),(.033,3.504,1.902),paint,.020,wall)
    for y in (-1.725,1.699):
        for z in (1.712,3.634):
            block('Wall_folding_corner_guard',(x+side*.052,y,z),(.157,.217,.160),orange,.017,wall)
            bolt('Panel_corner_pin',(x+side*.142,y,z),(side,0,0),.012,wall)
    for y in (-1.128,1.146):
        block('Wall_outer_forming_spine',(x+side*.092,y,2.645),(.043,.063,1.632),graphite,.012,wall)
    for y in (-1.481,.012,1.469):
        block('Folded_panel_recess_pull',(x+side*.089,y,2.11),(.028,.220,.078),graphite,.014,wall)
    for y in (-1.512,1.510):
        cylinder('Deployable_wall_pin',(x,y,1.661),.072,.217,dark,(0,1,0),wall,n=24)
    block('Cabin_port_frame',(x+side*.092,-.231,2.799),(.078,.715,.521),
          graphite,.026,wall)
    block('Cabin_port_glass',(x+side*.137,-.231,2.798),(.025,.579,.396),glass,.021,wall)
    for y in (-.557,.095):
        for z in (2.583,3.016):
            bolt('Window_bezel_pin',(x+side*.139,y,z),(side,0,0),.009,wall)
    block('Interior_lower_wall_insulation',(x-side*.075,-.014,2.015),(.043,3.318,.620),
          warm,.018,wall)
    rod('Interior_service_grab_rail',(x-side*.107,-1.360,2.958),(x-side*.108,1.280,2.956),
        .021,alloy,wall)

front=walls['EntryWall']
back=walls['RearWall']
entry_y=1.863
ring_y('Shaped_front_pressure_panel',(0,entry_y,2.676),octagon(2.747,2.114,.112),
       octagon(1.264,1.761,.149),.137,white,front)
ring_y('Front_hatch_collar',(0,entry_y+.084,2.665),octagon(1.501,1.933,.192),
       octagon(1.207,1.728,.141),.108,graphite,front)
ring_y('Front_hatch_pressure_gasket',(0,entry_y+.137,2.665),octagon(1.247,1.753,.145),
       octagon(1.162,1.664,.138),.032,rubber,front)
hatch=object_with_data('EntryHatch',parent=front,point=(-.584,entry_y+.173,2.664))
def door_skin(label,y,base_width,height,depth,mat):
    ring=octagon(base_width,height,.138)
    return loft(label,[[(x,d,2.664+z) for x,z in ring] for d in (y-depth/2,y+depth/2)],
                mat,.024,hatch)
door_skin('Pressed_hatch_skin',entry_y+.157,1.172,1.684,.062,white)
door_skin('Recessed_hatch_outer_panel',entry_y+.200,1.065,1.568,.033,warm)
cylinder('Hatch_viewport_surround',(0,entry_y+.222,2.942),.218,.047,graphite,(0,1,0),hatch,n=42)
cylinder('Hatch_viewport_glass',(0,entry_y+.252,2.942),.176,.019,glass,(0,1,0),hatch,n=42)
block('Hatch_latch_cover',(.344,entry_y+.231,2.508),(.171,.052,.112),dark,.014,hatch)
rod('Hatch_crew_release_lever',(.285,entry_y+.275,2.510),(.425,entry_y+.275,2.510),
    .021,orange,hatch)
for z in (2.131,3.185):
    cylinder('Pressure_hatch_hinge',(-.596,entry_y+.183,z),.040,.124,dark,parent=hatch)
for x in (-1.216,1.216):
    for z in (1.727,3.598):
        block('Bulkhead_panel_corner_guard',(x,entry_y+.065,z),(.194,.131,.148),orange,.014,front)
        bolt('Bulkhead_foot_captive_screw',(x,entry_y+.137,z),(0,1,0),.013,front)
block('Rear_weather_bulkhead',(0,-1.904,2.663),(2.746,.137,2.109),white,.039,back)
block('Rear_umbilical_protective_skin',(0,-1.986,2.663),(2.521,.051,1.912),paint,.023,back)
for x in (-.989,0,.990):
    block('Rear_panel_forming_rib',(x,-2.020,2.672),(.105,.077,1.598),slate,.018,back)
for x in (-1.243,1.243):
    block('Rear_baffle_end_cap',(x,-2.016,1.761),(.183,.110,.218),orange,.016,back)
roof=walls['Roof']
block('Lifted_thermal_roof_tray',(0,-.019,3.829),(2.970,4.007,.180),white,.046,roof,corner=.109)
block('Roof_underside_liner',(0,-.019,3.733),(2.704,3.733,.031),warm,.014,roof,corner=.065)
for x in (-.78,-.264,.264,.78):
    block('Roof_press_stiffener',(x,-.018,3.926),(.060,3.589,.036),paint,.012,roof)
for x in (-1.366,1.366):
    for y in (-1.855,1.819):
        block('Roof_guide_shoe',(x,y,3.807),(.209,.228,.218),orange,.023,roof)
        bolt('Roof_guide_captive_screw',(x,y,3.931),r=.015,parent=roof)

posts=[]
for i,(x,y) in enumerate([(-1.342,-1.733),(1.342,-1.733),(-1.342,1.683),(1.342,1.683)],1):
    pole=object_with_data(f'LiftPost_{i}',parent=module,point=(x,y,1.61))
    posts.append(pole)
    block('Lower_lift_post_socket',(x,y,1.68),(.152,.150,.195),dark,.018,module)
    block('Lifting_telescopic_column',(x,y,2.674),(.074,.074,2.128),steel,.008,pole)
    block('Lift_post_top_guide',(x,y,3.724),(.113,.113,.067),alloy,.010,pole)


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
    if obj.name.startswith(('Hip_frame_shear_plate','Replaceable_deck_edge_endcap','Roof_guide_shoe')):
        pos=obj.matrix_world.translation
        s=1 if pos.x>0 else -1
        scuffs(obj,pos+Vector((s*.038,0,.069)),(0,1,0),(s,0,.52),
               (.080,.057),(.0022,.017),83,17+i,(graphite,alloy,graphite))
scuffs(frame,(0,2.195,1.408),(1,0,0),(0,1,0), (1.37,.075),
       (.004,.021),106,834,(graphite,alloy,warm))


def surface_uv(p,n,offset,scale):
    axis=max(range(3),key=lambda i:abs(n[i]))
    u_index,v_index=[i for i in range(3) if i!=axis]
    sign=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u_index]*scale*sign+offset[0],p[v_index]*scale+offset[1])


for obj in model.objects:
    if obj.type!='MESH' or obj==screen:
        continue
    seed=random.Random(obj.name)
    obj['uv_offset']=(seed.random(),seed.random())
    obj['uv_scale']=2.7 if obj.name.startswith('Wheel') else 2.0
    layer=obj.data.uv_layers.new(name='Surface UV')
    for poly in obj.data.polygons:
        for i in poly.loop_indices:
            point=obj.data.vertices[obj.data.loops[i].vertex_index].co
            layer.data[i].uv=surface_uv(point,poly.normal,obj['uv_offset'],obj['uv_scale'])

# Shared between Blender previews and game export.
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from walker_pose import pose_walker


def export_game():
    # Meshes share material batches inside the each placement group.
    stage=bpy.data.collections.new('Game export')
    scene.collection.children.link(stage)
    copies={}
    originals={}
    specials=[screen,seal,glow,frame]
    anchors=[root,*[obj for obj in root.children_recursive if obj.type=="EMPTY"],*specials]
    for part in anchors:
        originals[part]=part.name
        part.name='Source__'+part.name
        copy=bpy.data.objects.new(originals[part],part.data.copy() if part in specials else None)
        stage.objects.link(copy)
        copy.parent=copies.get(part.parent)
        copy.matrix_basis=part.matrix_basis.copy()
        for key in part.keys():
            copy[key]=part[key]
        if part in specials:
            for modifier in part.modifiers:
                added=copy.modifiers.new(modifier.name,modifier.type)
                if modifier.type=='BEVEL':
                    added.width=modifier.width
                    added.segments=modifier.segments
                    added.limit_method=modifier.limit_method
        copies[part]=copy
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for parent,anchor in copies.items():
        bins=defaultdict(list)
        for obj in parent.children:
            if obj.type=='MESH' and obj not in specials:
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
                    uvs.extend(surface_uv(mesh.vertices[k].co,tri.normal,obj['uv_offset'],obj['uv_scale']) for k in tri.vertices)
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
    pose_walker({originals[obj]:copy for obj,copy in copies.items()},0)
    bpy.context.view_layer.update()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in stage.objects:
        o.select_set(True)
    path=args.package/'original'/'Walker_1_Remake.glb'
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                             export_extras=True,export_yup=True,export_tangents=False,export_apply=True)
    for o in list(stage.objects):
        bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.collections.remove(stage)
    for part,name in originals.items():
        part.name=name
    for mesh in list(bpy.data.meshes):
        if mesh.users==0:
            bpy.data.meshes.remove(mesh)


export_game()
pose_walker(bpy.data.objects,0)
for ui in bpy.data.screens:
    for area in ui.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.color_type='MATERIAL'
            space.overlay.show_extras=False
            space.region_3d.view_location=(0,0,1.44)
            space.region_3d.view_rotation=Vector((-7,-9,-4.6)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=10
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/'Walker_1_Remake.blend'),compress=True)
