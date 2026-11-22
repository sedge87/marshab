"""Build and export the Landing Site. Run with Blender from any directory."""
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
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('Landing Site')
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


slate = material('slate_panel','676966',.78,.03)
paint = material('white_painted','C5BCA5',.68,.02)
solar = material('solar_cell','233C51',.32,.26)
amber = material('lamp_amber','B07442',.28,.10)
optic = material('lamp_white','B1AFA2',.31,.06)
root = object_with_data('LandingSite')
root['front_axis_godot'] = '+Z (approach)'
pad = object_with_data('LandingPad',parent=root)
mark_set = object_with_data('SurveyKit',parent=root)
beacon = object_with_data('BeaconStation',parent=root,point=(10.78,-4.85,0))
point = object_with_data('OperateBeacon',parent=beacon,point=(10.15,-5.70,0))
tilt = object_with_data('BeaconTilt',parent=beacon,point=(10.78,-4.85,.29))
lead_broken = object_with_data('BrokenLead',parent=beacon)
lead_ready = object_with_data('RepairedLead',parent=beacon)


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


# The reference pad is 18 metres across the flats. The game can hide the whole
# assembly until construction or reveal its eight sectors independently.
half_span=9.0
radius=half_span/cos(pi/8)
vertices=[Vector((radius*cos(pi/8+i*pi/4),radius*sin(pi/8+i*pi/4))) for i in range(8)]


def paver(name,outline,z0,z1,material,parent,bevel=.017):
    return loft(name,[[(p.x,p.y,z) for p in outline] for z in (z0,z1)],material,bevel,parent)


def inset(points,clearance):
    mid=sum(points,Vector((0,0)))/len(points)
    return [point + (mid-point).normalized()*clearance for point in points]


def ring_tile(a,b,inner,outer,u0=0,u1=1):
    left=a.lerp(b,u0)
    right=a.lerp(b,u1)
    return [left*inner,left*outer,right*outer,right*inner]


paver('Prepared_graded_subbase',[v*.998 for v in vertices],.018,.081,graphite,pad,.022)
paver('Inset_touchdown_centre',[v*.288 for v in vertices],.086,.231,slate,pad,.023)
sectors=[]
for i,a in enumerate(vertices):
    b=vertices[(i+1)%8]
    center=(a+b)*.34
    sector=object_with_data(f'Sector_{i+1:02d}',parent=pad,point=(*center,0))
    sectors.append(sector)
    for inner,outer,split in [(.294,.535,2),(.537,.765,3),(.769,.912,3)]:
        for j in range(split):
            outline=inset(ring_tile(a,b,inner,outer,j/split,(j+1)/split),.018)
            mat=graphite if (i+3*j+int(inner*10))%11==0 else slate
            paver('Interlocking_surface_slab',outline,.085,.231,mat,sector,.017)
    for j in range(3):
        outline=inset(ring_tile(a,b,.914,.956,j/3,(j+1)/3),.018)
        paver('Perimeter_load_rail',outline,.086,.230,alloy,sector,.014)
        mid=a.lerp(b,(j+.5)/3)*.937
        cylinder('Recessed_pad_fastener',(*mid,.229),.054,.016,dark,parent=sector,n=16,fillet=.003)
        cylinder('Fastener_drive',(*mid,.237),.020,.005,graphite,parent=sector,n=6,fillet=.001)
    for j in range(4):
        outline=inset(ring_tile(a,b,.959,.999,j/4,(j+1)/4),.013)
        mat=orange if (i+j)%3==1 else warm
        paver('Low_edge_transition',outline,.045,.185,mat,sector,.022)
    # White paint strips are split by edge seams around the exterior.
    stripe=inset(ring_tile(a,b,.925,.94,.315,.683),.014)
    paver('Edge_visibility_stripe',stripe,.230,.232,paint,sector,.0)

# Flat markings for the touchdown area use a solid centre dot and a segmented ring.
markings=object_with_data('TouchdownMarkings',parent=pad)
for i in range(24):
    a=2*pi*i/24+.026
    b=2*pi*(i+1)/24-.026
    steps=7
    pa=[(2.68*cos(a+(b-a)*j/steps),2.68*sin(a+(b-a)*j/steps)) for j in range(steps+1)]
    pb=[(2.51*cos(a+(b-a)*j/steps),2.51*sin(a+(b-a)*j/steps)) for j in reversed(range(steps+1))]
    paver('Segmented_touchdown_ring',[Vector(p) for p in pa+pb],.2300,.2330,paint,markings,0)
dot=[Vector((.56*cos(2*pi*i/64),.56*sin(2*pi*i/64))) for i in range(64)]
paver('Touchdown_centre_dot',dot,.230,.233,paint,markings,0)
for y in (-7.05,-6.38):
    poly=[(-1.00,y-.17),(0,y+.32),(1.00,y-.17),(.83,y-.32),(0,y+.075),(-.83,y-.32)]
    paver('Approach_chevron',[Vector(p) for p in poly],.229,.234,paint,markings,0)

guide_glass=object_with_data('PadGuideLenses',parent=pad)
for i,a in enumerate(vertices):
    b=vertices[(i+1)%8]
    point2=a.lerp(b,.5)*.955
    x,y=point2
    theta=(b-a).angle_signed(Vector((1,0)))*-1
    for desc,h,z,mat,w,d in [
        ('Guide_marker_mount',.046,.204,graphite,.47,.31),
        ('Guide_marker_guard',.072,.255,orange,.40,.24),
        ('Guide_marker_lens',.030,.301,optic,.26,.105),
    ]:
        part=block(desc,(x,y,z),(w,d,h),mat,.010,guide_glass if mat is optic else pad)
        part.rotation_euler.z=theta
    for u in (-.181,.181):
        bolt('Guide_marker_fastener',(x+u*cos(theta),y+u*sin(theta),.282),r=.019,parent=pad)

# Survey equipment can remain visible before any landing surface exists.
for i,a in enumerate(vertices):
    x,y=a*1.046
    cylinder('Survey_stake_lower',(x,y,.237),.031,.474,dark,parent=mark_set)
    cylinder('Survey_stake_high_visibility',(x,y,.428),.034,.201,orange,parent=mark_set)
    cylinder('Survey_stake_top_cap',(x,y,.550),.046,.043,white,parent=mark_set)
    for z in (.387,.491):
        cylinder('Survey_stake_reflective_band',(x,y,z),.035,.019,paint,parent=mark_set)
    block('Survey_stake_ground_plate',(x,y,.029),(.198,.177,.058),graphite,.010,mark_set)

bx,by=10.78,-4.85
def at(x,y,z):
    return (bx+x,by+y,z)


# Fold-resistant tripod and individually bolted ballast shoes.
for angle in (-pi/2,pi/6,5*pi/6):
    dx,dy=cos(angle),sin(angle)
    toe=block('Tripod_ballast_shoe',at(dx*.742,dy*.742,.068),(.28,.24,.136),dark,.015,beacon)
    toe.rotation_euler.z=angle
    wear_plate=block('Removable_ballast_cap',at(dx*.750,dy*.750,.136),(.235,.191,.041),orange,.009,beacon)
    wear_plate.rotation_euler.z=angle
    start=at(dx*.082,dy*.082,.376)
    end=at(dx*.715,dy*.715,.155)
    rod('Telescoping_tripod_leg',start,end,.034,alloy,beacon)
    u=Vector(start).lerp(Vector(end),.48)
    v=Vector(start).lerp(Vector(end),.86)
    rod('Leg_lower_impact_sleeve',u,v,.041,dark,beacon)
    rod('Foot_brace',at(dx*.114,dy*.114,.267),at(dx*.572,dy*.572,.165),.016,steel,beacon)
    for t in (-.075,.075):
        bolt('Ballast_captive_bolt',at(dx*.750-dy*t,dy*.750+dx*t,.161),r=.009,parent=beacon)
    cylinder('Tripod_anchor_pin',at(dx*.733,dy*.733,.178),.040,.034,steel,parent=beacon,n=20)
cylinder('Mast_base_plinth',at(0,0,.236),.147,.133,dark,parent=beacon,n=32)
cylinder('Mast_reseat_socket',at(0,0,.308),.115,.091,orange,parent=beacon,n=32)
cylinder('Mast_socket_lock_ring',at(0,0,.358),.123,.026,graphite,parent=beacon,n=32)
for i in range(5):
    a=i*2*pi/5
    bolt('Mast_socket_fastener',at(.100*cos(a),.100*sin(a),.376),r=.009, parent=beacon)

# Mast collar, power lead socket and armature rotate together during reseating.
cylinder('Mast_lower_insert',at(0,0,.570),.051,.518,steel,parent=tilt,n=32)
cylinder('Mast_outer_sleeve',at(0,0,.942),.049,.754,white,parent=tilt,n=32)
cylinder('Mast_upper_section',at(0,0,1.431),.034,.473,alloy,parent=tilt,n=32)
for z in (.395,.704,1.153,1.609):
    cylinder('Mast_index_collar',at(0,0,z),.062,.046,orange if z<.75 else dark,parent=tilt,n=28)
    cylinder('Indexed_locking_lever',at(.061,-.004,z),.015,.043,steel,(1,0,0),tilt,n=16)
    block('Glove_lock_tab',at(.091,-.003,z),(.028,.049,.021),orange,.004,tilt)
block('Mast_receiver_enclosure',at(-.076,-.029,.862),(.131,.137,.209),graphite,.011,tilt)
block('Receiver_service_cover',at(-.082,-.110,.872),(.092,.033,.154),white,.007,tilt)
for z in (.815,.932):
    bolt('Receiver_captive_screw',at(-.085,-.129,z),(0,-1,0),.006,tilt)
rod('Uplink_antenna_whip',at(-.051,.022,1.696),at(-.115,.062,1.973),.006,steel,tilt)
rod('Antenna_insulated_tip',at(-.105,.055,1.936),at(-.116,.062,1.977),.008,orange,tilt)

# Solar panel mounts beneath the head. Each small cell is part of the panel,
# with dark inter-cell seams and metallic collector traces.
solar_pose=Matrix.Rotation(-.40,3,'X') @ Matrix.Rotation(.15,3,'Y')
solar_center=Vector(at(.262,.065,1.451))
def solar_at(x,y,z):
    return solar_center+solar_pose@Vector((x,y,z))
def solar_block(name,x,y,z,size,mat,b=.003):
    o=block(name,solar_at(x,y,z),size,mat,b,tilt)
    o.rotation_euler=solar_pose.to_euler()
    return o

rod('Solar_hinged_support',at(.025,.028,1.333),solar_at(-.025,-.101,-.024),.024,dark,tilt)
solar_block('Solar_carrier_frame',0,0,0,(.478,.339,.037),alloy,.007)
solar_block('Solar_cell_substrate',0,0,.020,(.447,.310,.009),graphite,.003)
for x in range(6):
    for y in range(4):
        a=(x-2.5)*.072
        b=(y-1.5)*.075
        solar_block('Solar_photovoltaic_cell',a,b,.027,(.064,.066,.006),solar,.0018)
        for shear in (-.016,.016):
            solar_block('Solar_cell_collector',a+shear,b,.031,(.0018,.058,.0012),steel,.0003)

lamp_glass=object_with_data('BeaconLens',parent=tilt)
cylinder('Beacon_lamp_bottom',at(0,0,1.661),.114,.071,dark,parent=tilt,n=36)
cylinder('Beacon_lamp_guard_base',at(0,0,1.691),.127,.035,orange,parent=tilt,n=36)
cylinder('Fresnel_beacon_optic',at(0,0,1.757),.096,.115,amber,parent=lamp_glass,n=44,fillet=.008)
for j in range(4):
    cylinder('Fresnel_lens_rib',at(0,0,1.722+j*.023),.099,.008,amber,parent=lamp_glass,n=44,fillet=.001)
cylinder('Beacon_lamp_top_cap',at(0,0,1.829),.112,.044,dark,parent=tilt,n=36)
cylinder('Beacon_flared_glare_cap',at(0,0,1.865),.131,.036,white,parent=tilt,n=36)
for j in range(5):
    a=j*2*pi/5
    rod('Impact_cage_strut',at(.113*cos(a),.113*sin(a),1.691),
        at(.113*cos(a),.113*sin(a),1.852),.008,steel,tilt)

# A carried battery satchel, landing-site tether, and the damaged-to-repaired lead.
block('Battery_ground_sled',at(.64,-.12,.036),(.450,.330,.072),graphite,.015,beacon)
block('Battery_flight_case',at(.64,-.12,.184),(.359,.265,.256),white,.020,beacon,corner=.023)
block('Battery_case_upper_seam',at(.64,-.12,.281),(.368,.275,.036),rubber,.012,beacon)
block('Battery_case_lid',at(.64,-.12,.312),(.340,.258,.038),white,.014,beacon)
for x in (.485,.793):
    for y in (-.227,-.015):
        guard=block('Battery_corner_bumper',at(x,y,.228),(.067,.072,.150),orange,.010,beacon)
        bolt('Battery_case_receiver',at(x,y,.324),r=.008,parent=beacon)
sweep('Battery_carry_handle',[at(.556,-.108,.321),at(.554,-.108,.373),
      at(.575,-.108,.387),at(.704,-.108,.387),at(.726,-.108,.369),at(.726,-.108,.319)],.011,steel,beacon)
rod('Battery_grip_sleeve',at(.583,-.108,.387),at(.695,-.108,.387),.016,rubber,beacon)
block('Battery_recessed_access',at(.650,-.260,.183),(.218,.020,.118),graphite,.009,beacon)
for i in range(5):
    block('Battery_passive_cooling_slot',at(.591+i*.027,-.272,.210),(.006,.004,.051),dark,.002,beacon)
block('Battery_cable_gland',at(.451,-.099,.176),(.028,.069,.079),dark,.006,beacon)
cylinder('Battery_gland_hex',at(.430,-.099,.175),.022,.031,steel,(-1,0,0),beacon,n=8)
cylinder('Mast_power_socket',at(.057,-.009,.514),.022,.034,graphite,(1,0,0),tilt,n=20)
complete=[at(.415,-.099,.175),at(.379,-.123,.160),at(.310,-.188,.107),
          at(.237,-.212,.103),at(.157,-.186,.123),at(.106,-.138,.207),
          at(.083,-.077,.329),at(.081,-.027,.480),at(.070,-.009,.514)]
sweep('Repaired_ground_power_lead',complete,.010,rubber,lead_ready)
cylinder('Repaired_connector_boot',at(.079,-.009,.514),.017,.034,orange,(1,0,0),lead_ready,n=20)
sweep('Battery_side_torn_lead',complete[:5]+[at(.126,-.186,.120)],.010,rubber,lead_broken)
for i,col in enumerate((steel,orange,alloy)):
    a=at(.127,-.184+i*.003,.120+i*.003)
    b=at(.103,-.186+i*.009,.109+i*.010)
    rod('Torn_conductor',a,b,.0017,col,lead_broken)
# This tail follows the mast in both poses. The repaired lead mates to its inlet.
tail=object_with_data('BrokenMastTail',parent=tilt)
sweep('Mast_side_torn_lead',[at(.070,-.009,.514),at(.087,-.065,.459),
       at(.107,-.089,.406),at(.113,-.107,.359)],.009,rubber,tail)
for i,col in enumerate((steel,orange)):
    rod('Mast_torn_conductor',at(.110+i*.005,-.106,.360),at(.113+i*.008,-.113,.335),.0018,col,tail)

# Wear goes where operators handle the equipment and where the shoes meet the dirt.
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
for i,obj in enumerate(list(beacon.children)):
    if obj.name.startswith(('Removable_ballast_cap','Battery_corner_bumper')):
        world=obj.matrix_world.translation
        scuffs(obj,world+Vector((0,0,.034)),(1,0,0),(0,0,1),
               (.030,.042),(.002,.013),55,31+i,(graphite,alloy,graphite))


def surface_uv(p,n,offset,scale):
    axis=max(range(3),key=lambda i:abs(n[i]))
    u,v=[i for i in range(3) if i!=axis]
    sign=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u]*scale*sign+offset[0],p[v]*scale+offset[1])


pad_objects=set(pad.children_recursive)
for obj in model.objects:
    if obj.type!='MESH':
        continue
    seed=random.Random(obj.name)
    obj['uv_offset']=(seed.random(),seed.random())
    obj['uv_scale']=.82 if obj in pad_objects else 5.0
    uv=obj.data.uv_layers.new(name='Surface UV')
    for poly in obj.data.polygons:
        for k in poly.loop_indices:
            vertex=obj.data.vertices[obj.data.loops[k].vertex_index].co
            uv.data[k].uv=surface_uv(vertex,poly.normal,obj['uv_offset'],obj['uv_scale'])


def export_game():
    # Meshes share material batches inside the each placement group.
    stage=bpy.data.collections.new('Game export')
    scene.collection.children.link(stage)
    copies={}
    originals={}
    anchors=[root,*[obj for obj in root.children_recursive if obj.type=="EMPTY"]]
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
    for group in (lead_broken,tail):
        # glTF has no portable node-visibility field. The Godot controller
        # restores unit scale when these prototype parts are shown.
        copies[group].scale=(.00001,.00001,.00001)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in stage.objects:
        o.select_set(True)
    path=args.package/'original'/'Landing_Pad_And_Beacon.glb'
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
for obj in lead_broken.children_recursive+tail.children_recursive:
    obj.hide_render=True
    obj.hide_set(True)
for ui in bpy.data.screens:
    for area in ui.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.color_type='MATERIAL'
            space.overlay.show_extras=False
            space.region_3d.view_location=(.5,0,.4)
            space.region_3d.view_rotation=Vector((-15,22,-17)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=28
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/'Landing_Pad_And_Beacon.blend'),compress=True)
