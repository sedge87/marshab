"""Build one landing beacon form for the Chunk 2 comparison."""
from pathlib import Path
from math import cos, sin, pi
import argparse
from collections import defaultdict
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector


def inputs():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--form', choices=('Survey','Guarded','Folding'), required=True)
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('Landing Beacon')
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


solar = material('solar_cell','233C51',.32,.26)
amber = material('lamp_amber','B07442',.28,.10)
optic = material('lamp_white','B1AFA2',.31,.06)
root = object_with_data('LandingBeacon')
root['front_axis_godot']='-Z'
root['nominal_height_m']=2.2
mast=object_with_data('Mast',parent=root,point=(0,0,.41))
lead=object_with_data('Lead',parent=mast)
lead_torn=object_with_data('LeadTorn',parent=mast)
carry=object_with_data('CarryPoints',parent=mast)
feet=[]


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


from math import radians

form=args.form
alternatives={
    'Survey': (.626,.251,.231,.355,.260,.456,.323,.226,1.486,.113),
    'Guarded': (.606,.293,.264,.411,.306,.505,.331,.246,1.525,.150),
    'Folding': (.620,.222,.211,.306,.275,.359,.463,.234,1.429,.089),
}
radius,pad_w,pad_l,battery_w,battery_h,pv_w,pv_d,pv_offset,solar_z,lens_r=alternatives[form]
root['option']=form
angles=(pi/6,5*pi/6,-pi/2)
for index,angle in enumerate(angles,1):
    u=Vector((cos(angle),sin(angle),0))
    perp=Vector((-sin(angle),cos(angle),0))
    pivot=u*.085+Vector((0,0,.334))
    foot=object_with_data(f'Foot_{index}',parent=root,point=pivot)
    foot['depression_axis']=list(perp)
    feet.append((foot,perp))
    toe=u*radius+Vector((0,0,.064))
    shoe=block('Ballast_ground_rubber',toe-Vector((0,0,.052)),(pad_l,pad_w,.024),rubber,.009,foot,corner=.021)
    shoe.rotation_euler.z=angle
    bed=block('Replaceable_ballast_shoe',toe,(pad_l,pad_w,.098),dark,.012,foot,corner=.025)
    bed.rotation_euler.z=angle
    top=block('High_visibility_plate',toe+Vector((0,0,.054)),(pad_l-.021,pad_w-.024,.025),orange,.008,foot)
    top.rotation_euler.z=angle
    lever=object_with_data(f'LeverPoint_{index}',parent=foot,point=(u*(radius+.12)))
    lever.rotation_euler.z=angle-pi/2
    pocket=block('Lever_socket_reinforced_face',u*(radius+.054)+Vector((0,0,.142)),
                 (.063,pad_w*.52,.048),alloy,.007,foot)
    pocket.rotation_euler.z=angle
    cut=block('Lever_socket_dark_recess',u*(radius+.064)+Vector((0,0,.159)),
              (.018,pad_w*.33,.020),graphite,.002,foot)
    cut.rotation_euler.z=angle
    rod('Tripod_leg_link',pivot+u*.019,toe+Vector((0,0,.072)),
        .034 if form!='Guarded' else .045,alloy,foot)
    if form=='Folding':
        a=pivot+perp*.049
        b=toe-perp*.052+Vector((0,0,.103))
        c=pivot-perp*.049
        d=toe+perp*.052+Vector((0,0,.103))
        rod('Folding_braced_strut',a,b,.019,steel,foot)
        rod('Folding_braced_strut',c,d,.019,dark,foot)
        block('Fold_stop',u*.38+Vector((0,0,.252)),(.062,.094,.030),orange,.005,foot)
    else:
        rod('Lower_telescoping_sleeve',pivot.lerp(toe,.43),toe+Vector((0,0,.040)),
            .046,dark,foot)
        rod('Foot_anti_rotation_brace',pivot*.91+perp*.044,toe+perp*.050,.014,steel,foot)
    cylinder('Leg_pin_boss',pivot,.057,.151,dark,perp,foot,n=26)
    for p in (-1,1):
        bolt('Leg_pivot_pin',pivot+perp*p*.079,perp*p,.013,foot)
        bolt('Ballast_upper_captive_bolt',toe+perp*p*(pad_w*.28)+Vector((0,0,.069)),
            r=.008,parent=foot)
    cylinder('Ballast_level_jack',toe+Vector((0,0,.117)),.041,.067,steel,parent=foot,n=24)
cylinder('Tripod_spider_hub',(0,0,.371),.139,.107,dark,parent=root,n=42)
cylinder('Tripod_mast_socket',(0,0,.421),.111,.063,orange,parent=root,n=34)
for k in range(6):
    a=k*pi/3
    bolt('Tripod_clamp_bolt',(.088*cos(a),.088*sin(a),.457),r=.009,parent=root)

if form=='Survey':
    cylinder('Telescoping_mast_outer',(0,0,.984),.048,1.037,white,parent=mast,n=32)
    cylinder('Telescoping_steel_insert',(0,0,1.639),.030,.574,steel,parent=mast,n=30)
elif form=='Guarded':
    block('Square_instrument_mast',(0,0,1.182),(.111,.101,1.487),white,.017,mast)
    block('Raised_side_channel',(-.052,0,1.155),(.032,.067,.847),dark,.006,mast)
    for h in (.623,.970,1.314):
        bolt('Spine_channel_fastener',(-.070,0,h),(-1,0,0),.0055,mast)
else:
    cylinder('Lightweight_mast_core',(0,0,1.128),.036,1.402,dark,parent=mast,n=30)
    for side in (-1,1):
        rod('Twin_exposed_mast_guide',(side*.063,0,.480),(side*.063,0,1.811),.018,steel,mast)
    for height in (.535,.872,1.221,1.651):
        block('Twin_mast_clip',(0,0,height),(.169,.095,.066),graphite,.009,mast)
for height in (.50,1.31,1.793):
    cylinder('Mast_height_lock_collar',(0,0,height),.068,.050,orange,parent=mast,n=30)
    cylinder('Height_lock_bolt',(.071,0,height),.013,.041,steel,(1,0,0),mast,n=18)
    block('Glove_lock_lever',(.103,0,height),(.024,.057,.021),graphite,.005,mast)
# External top tow eye is sized for GAR-Y's clip.
eye=object_with_data('HitchPoint',parent=mast,point=(0,.138,1.839))
eye['purpose']='GAR-Y pull point'
sweep('Forged_mast_tow_eye',[(-.050,.048,1.839),(-.052,.103,1.839),(-.035,.145,1.839),
       (0,.160,1.839),(.034,.148,1.839),(.051,.103,1.839),(.049,.047,1.839)],.012,steel,mast)
for x in (-.048,.048):
    bolt('Tie_eye_boss',(x,.046,1.857),r=.008,parent=mast)

# Recharge panel off the mast, with raised individual cells and conductor traces.
panel_y=-.042 if form!='Folding' else .015
panel_rot=Matrix.Rotation(-radians(37 if form=='Folding' else 18),3,'X') @ Matrix.Rotation(radians(15),3,'Y')
panel_center=Vector((-pv_offset,panel_y,solar_z))
def pv(x,y,z):
    return panel_center+panel_rot@Vector((x,y,z))
def pv_panel(name,x,y,z,size,material,bevel=.004):
    o=block(name,pv(x,y,z),size,material,bevel,mast)
    o.rotation_euler=panel_rot.to_euler()
    return o
rod('Cantilever_solar_arm',(0,-.021,solar_z-.122),pv(.062,-.080,-.019),
    .024 if form=='Guarded' else .018,alloy,mast)
rod('Folding_solar_backstay',(.004,-.033,solar_z-.276),pv(-.104,-.029,-.021),
    .015,dark,mast)
pv_panel('Solar_perimeter_carrier',0,0,0,(pv_w,pv_d,.034),alloy,.008)
pv_panel('Solar_cell_carrier',0,0,.020,(pv_w-.029,pv_d-.025,.008),graphite,.003)
columns=5 if form!='Folding' else 4
rows=4 if form!='Folding' else 6
for c in range(columns):
    for r in range(rows):
        dx=(pv_w-.047)/columns
        dy=(pv_d-.041)/rows
        u=(c-(columns-1)/2)*dx
        v=(r-(rows-1)/2)*dy
        pv_panel('Solar_cell',u,v,.026,(dx-.004,dy-.005,.006),solar,.001)
        pv_panel('Cell_collector_trace',u-dx*.15,v,.030,(.0016,dy-.010,.001),steel,.0002)
if form=='Guarded':
    for side in (-1,1):
        rod('Solar_outer_impact_rail',pv(side*(pv_w/2+.006),-.126,.017),
             pv(side*(pv_w/2+.006),.126,.017),.011,orange,mast)

# Electronics are low on the mast. The panel feeds a visible, replaceable plug.
box_center=Vector((.021,.108,.725))
y=box_center.y
z=box_center.z
depth=.195 if form!='Guarded' else .218
box_front=y+depth/2
block('Electronics_mount_box',(0,.011,z),(.215,.136,.247),dark,.011,mast)
block('Battery_flight_housing',box_center,(battery_w,depth,battery_h),white,.017,mast,corner=.030)
block('Battery_case_seam',(box_center.x,y,z+battery_h*.35),(battery_w+.008,depth+.005,.021),
      rubber,.009,mast,corner=.024)
block('Battery_box_recessed_face',(box_center.x,box_front+.004,z),(.252,.025,.175),graphite,.009,mast)
for i in range(4):
    s=-1 if i<2 else 1
    hh=z+(-1 if i%2 else 1)*battery_h*.358
    block('Electronics_case_corner_guard',(box_center.x+s*battery_w*.409,box_front-.036,hh),
          (.073,.088,.078),orange,.010,mast)
    bolt('Faceplate_captive_screw',(box_center.x+s*.121,box_front+.018,hh),(0,1,0),.0055,mast)
for i in range(5):
    block('Front_receiver_relief',(-.082+i*.032,box_front+.019,z-.047),
          (.015,.002,.005),dark,.001,mast)
for s in (-1,1):
    x=box_center.x+s*(battery_w*.51+.004)
    span=.122 if form=='Survey' else .146
    sweep('Insulated_carry_handle',[(x,.033,z-.055),(x+s*.041,.038,z-.052),
        (x+s*.045,.061,z-.041),(x+s*.045,.058,z+span-.12),
        (x+s*.038,.034,z+span-.08),(x,.032,z+span-.075)],.009,steel,carry)
    grip=object_with_data(f'CarryPoint_{1 if s<0 else 2}',parent=carry,point=(x+s*.038,.057,z+.022))
    if form=='Guarded':
        sweep('Impact_protection_battery_bail',[(x,.009,z-.128),(x+s*.020,.124,z-.132),
          (x+s*.020,.238,z-.093),(x+s*.02,.250,z+.096),
          (x+s*.017,.189,z+.148),(x,.028,z+.149)],.014,orange,mast)

# A rectangular screen surface is separate from its weather gasket.
screen_w,screen_h=.164,.09225
screen_x=.040
screen_z=z+.027
block('Tilt_reader_rain_gasket',(screen_x,box_front+.020,screen_z),(.188,.012,.111),rubber,.005,mast)
screen=geom('tilt_display_glass',[(-screen_w/2,0,-screen_h/2),(-screen_w/2,0,screen_h/2),
           (screen_w/2,0,screen_h/2),(screen_w/2,0,-screen_h/2)],[(0,1,2,3)],glass,
           parent=mast,point=(screen_x,box_front+.027,screen_z),object_name='TiltScreen')
if screen.data.polygons[0].normal.y<0:
    screen.data.polygons[0].flip()
uv=screen.data.uv_layers.new(name='Display UV')
for loop in screen.data.loops:
    point=screen.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(.5-point.x/screen_w,.5+point.z/screen_h)

socket_pos=Vector((-.091,box_front+.028,z-.012))
socket=object_with_data('Socket',parent=mast,point=socket_pos)
connector=object_with_data('Connector',parent=mast,point=socket_pos+Vector((0,.038,0)))
cylinder('External_socket_reinforcement',socket_pos,.032,.025,dark,(0,1,0),mast,n=28)
cylinder('Socket_keyed_rim',socket_pos+Vector((0,.013,0)),.026,.010,steel,(0,1,0),mast,n=24)
cylinder('Socket_open_interior',socket_pos+Vector((0,.020,0)),.017,.006,graphite,(0,1,0),mast,n=24)
cylinder('Replaceable_connector_shell',socket_pos+Vector((0,.039,0)),.023,.043,orange,
         (0,1,0),connector,n=20)
cylinder('Connector_flexible_boot',socket_pos+Vector((0,.067,0)),.015,.032,rubber,
         (0,1,0),connector,n=20)
begin=pv(.132,.075,-.026)
cable_path=[begin,(-.15,.083,solar_z-.102),(-.123,.171,1.27),
            (-.137,.202,1.158),(-.123,.227,1.020)]
good_end=socket_pos+Vector((0,.083,0))
sweep('Reconnected_panel_lead',cable_path+[(-.151,.263,.891),(-.147,.277,.796),good_end],
      .012,rubber,lead)
torn_path=object_with_data('DisplacedLead',parent=mast)
tail_end=Vector((-.322,.281,.688))
sweep('Dangling_panel_lead',cable_path+[(-.197,.253,.890),(-.263,.272,.780),tail_end],
      .012,rubber,torn_path)
sweep('Torn_socket_cable_stub',[socket_pos+Vector((0,.025,0)),socket_pos+Vector((.009,.070,-.018)),
       socket_pos+Vector((.020,.100,-.026))],.011,rubber,lead_torn)
for node,point,direction in [
        (torn_path,tail_end,Vector((-.62,.03,-.83))),
        (lead_torn,socket_pos+Vector((.020,.100,-.026)),Vector((.32,.89,-.33))),
    ]:
    for j,mt in enumerate((orange,alloy,steel)):
        a=point+Vector(((j-1)*.004,0,(j-1)*.004))
        b=a+direction*(.022+j*.004)+Vector((-.011+j*.009,.008*j,.005*j))
        rod('Frayed_visible_conductor',a,b,.0019,mt,node)
for h in (1.073,1.266):
    block('Cable_management_coated_bail',(-.095,.070,h),(.061,.050,.021),alloy,.004,mast)

# Optics at the crown. All three heads stay within the same service envelope.
lens=object_with_data('Lamp',parent=mast,point=(0,0,2.000))
if form=='Guarded':
    block('Approach_light_reinforced_foot',(0,0,1.935),(.323,.208,.062),dark,.018,mast)
    block('Approach_lamp_orange_frame',(0,0,2.019),(.310,.195,.118),orange,.016,mast)
    block('Wide_prismatic_glass',(0,.107,2.022),(.258,.032,.080),amber,.008,lens)
    for i in range(8):
        rod('Prismatic_lens_flute',(-.107+i*.030,.126,1.988),(-.107+i*.030,.126,2.054),.0025,amber,lens)
    block('Wide_beacon_glare_hood',(0,.028,2.104),(.340,.231,.044),white,.010,mast)
    for s in (-1,1):
        sweep('Engineered_lamp_guard_rail',[(s*.174,-.053,1.909),(s*.178,.106,1.933),
               (s*.181,.143,2.010),(s*.179,.105,2.107),(s*.166,-.084,2.120)],.011,steel,mast)
else:
    lower=1.922 if form=='Survey' else 1.890
    upper=2.083 if form=='Survey' else 2.099
    cylinder('Lamp_alignment_base',(0,0,lower-.033),lens_r+.017,.064,graphite,parent=mast,n=36)
    cylinder('Fresnel_direction_lens',(0,0,(upper+lower)/2),lens_r,upper-lower,amber,parent=lens,n=48)
    for j in range(6 if form=='Folding' else 5):
        zf=lower+.019+j*(upper-lower-.032)/(5 if form=='Folding' else 4)
        cylinder('Fresnel_lens_edge',(0,0,zf),lens_r+.004,.006,amber,parent=lens,n=48,fillet=.0012)
    cylinder('Lamp_flared_glare_cap',(0,0,upper+.021),lens_r+.030,.039,
             white if form=='Survey' else orange,parent=mast,n=36)
    for j in range(4 if form=='Folding' else 5):
        a=j*2*pi/(4 if form=='Folding' else 5)
        r=lens_r+.014
        rod('Lamp_impact_cage_spine',(r*cos(a),r*sin(a),lower-.019),
            (r*cos(a),r*sin(a),upper+.015),.007,steel,mast)
rod('Short_comms_aerial',(0,-.047,2.091),(-.012,-.067,2.183),.006,steel,mast)
cylinder('Antenna_protective_tip',(-.012,-.067,2.187),.013,.025,orange,parent=mast,n=20)


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
    if obj.name.startswith(('High_visibility_plate','Electronics_case_corner_guard')):
        p=obj.matrix_world.translation
        scuffs(obj,p+Vector((0,0,.027)),(1,0,0),(0,0,1),(.037,.033),
               (.001,.012),58,241+i,(graphite,steel,graphite))

mapped={white,orange,graphite,dark,alloy,steel,warm,rubber,solar}
for obj in model.objects:
    if obj.type!='MESH' or not any(material in mapped for material in obj.data.materials):
        continue
    uv=obj.data.uv_layers.new(name='Field finish UV')
    rotation=obj.matrix_world.to_3x3()
    seed=random.Random(obj.name)
    a,b=seed.random(),seed.random()
    for poly in obj.data.polygons:
        normal=rotation @ poly.normal
        axis=max(range(3),key=lambda i:abs(normal[i]))
        u,v=[i for i in range(3) if i!=axis]
        flip=(1 if normal[axis]>0 else -1)*(-1 if axis==1 else 1)
        for k in poly.loop_indices:
            p=obj.matrix_world @ obj.data.vertices[obj.data.loops[k].vertex_index].co
            uv.data[k].uv=(p[u]*4.9*flip+a,p[v]*4.9+b)

# Save the scene in the common as-found pose. The connected and torn cable
# assemblies stay editable in the file so the selected form can be developed.
from mathutils import Quaternion
mast.rotation_euler.y=radians(12)
foot,axis=feet[0]
foot.rotation_mode='QUATERNION'
foot.rotation_quaternion=Quaternion(axis,radians(9))
for group in (lead,connector):
    for item in group.children_recursive:
        item.hide_render=True
        item.hide_set(True)
for viewport in bpy.data.screens:
    for area in viewport.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.overlay.show_extras=False
            space.shading.color_type='MATERIAL'
            space.region_3d.view_location=(.02,.02,1.04)
            space.region_3d.view_rotation=Vector((-1,-2.3,-.65)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=3.6
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/f'Beacon_{form}.blend'),compress=True)
