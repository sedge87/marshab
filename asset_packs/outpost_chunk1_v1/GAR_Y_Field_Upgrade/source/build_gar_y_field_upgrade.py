"""Upgrade GAR-Y while retaining the supplied model hierarchy."""
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
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
bpy.ops.import_scene.gltf(filepath=str(args.input))
model = bpy.data.collections.new('GAR-Y field hardware')
scene.collection.children.link(model)


def rgb(hex_color):
    srgb = [int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)]
    return (*[c/12.92 if c<.04045 else ((c+.055)/1.055)**2.4 for c in srgb], 1)


def material(role, hue, roughness, metalness=0):
    result = bpy.data.materials.get(role) or bpy.data.materials.new(role)
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
paint=material('white_painted','D6CCB2',.51,.05)
slate=material('slate_panel','455960',.72,.07)
solar=material('solar_cell','27405C',.35,.29)
root=bpy.data.objects['GarY']
body=bpy.data.objects['Body']
panel=bpy.data.objects['SolarPanel']
head=bpy.data.objects['Head']


def object_with_data(name, data=None, parent=None, point=(0,0,0)):
    obj=bpy.data.objects.new(name,data)
    model.objects.link(obj)
    obj.parent=parent
    obj.matrix_world=Matrix.Translation(Vector(point))
    return obj


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


# The additions are local to the original articulated parts. Glass, eyes and
# working pivots remain separate, and the photoelectric panel receives traces.
bpy.context.view_layer.update()
for side in (-1,1):
    for y in (-.296,.123,.269):
        bolt('Deck_edge_quarter_turn', (side*.299,y,.526), r=.0054, parent=body)
    block('Chassis_protective_sill',(side*.319,.008,.328),(.020,.511,.037),graphite,.006,body)
    for y in (-.199,.202):
        bolt('Sill_captive_screw',(side*.331,y,.329),(side,0,0),.0048,body)
    block('Forward_service_louvre_recess',(side*.320,.222,.379),(.009,.133,.066),graphite,.006,body)
    for row in range(4):
        block('Forward_service_louvre',(side*.326,.223,.355+row*.014),(.009,.114,.0047),alloy,.0017,body)
    block('Bumper_corner_wear_shoe',(side*.224,.447,.315),(.063,.028,.030),dark,.006,body)
    bolt('Bumper_captive_fastener',(side*.231,.468,.313),(0,1,0),.006,body)
    block('Lamp_recessed_bezel_bar',(side*.172,.462,.326),(.087,.010,.009),dark,.0025,body)
    for z in (.829,.945):
        bolt('Camera_housing_captive_screw',(side*.133,.286,z),(0,1,0),.0033,head)
    for j in range(3):
        block('Camera_side_passive_cooling',(side*.133,.162+j*.009,.882),
              (.018,.005,.056),graphite,.002,head)

# Panel collector traces align with the original cell breaks and follow its hinge.
for x in (-.230,-.134,-.045,.046,.134,.229):
    for y in (-.365,-.271,-.181,-.091):
        for offset in (-.012,.012):
            block('Solar_cell_collector',(x+offset,y,.551),(.0018,.052,.0013),steel,.00025,panel)
for x in (-.271,.271):
    for y in (-.390,-.045):
        bolt('Solar_frame_captive_screw',(x,y,.549),r=.0033,parent=panel)

# Retain the orange centres and wheel outer envelope. Machine and mark the
# annulus around each existing hub, with the detail parented to the wheel.
def hub_ring(parent,axle,side):
    ax,ay,z=axle
    verts=[]
    for shift,r in [(0,.076),(0,.044),(.004,.076),(.004,.044)]:
        x=ax+side*(.064+shift)
        verts.extend((x,ay+r*cos(i*2*pi/40),z+r*sin(i*2*pi/40)) for i in range(40))
    faces=[]
    for i in range(40):
        j=(i+1)%40
        faces.extend([(i,j,j+40,i+40),(i,i+80,j+80,j),
                      (i+40,j+40,j+120,i+120),(i+80,i+120,j+120,j+80)])
    geom('Wheel_machined_hub_ring',verts,faces,steel,.0006,parent)
    for i in range(6):
        a=i*pi/3
        x=ax+side*.068
        y=ay+.060*cos(a)
        height=z+.060*sin(a)
        cylinder('Wheel_hub_socket_mark',(x,y,height),.0053,.0014,dark,
                 (side,0,0),parent,n=8,fillet=.00035)
    for i in (0,2):
        q=i*pi/2+.32
        a=(ax+side*.0687,ay+.068*cos(q),z+.068*sin(q))
        b=(ax+side*.0687,ay+.074*cos(q+.20),z+.074*sin(q+.20))
        rod('Wheel_hub_torque_witness',a,b,.0011,orange,parent)


for i in range(1,7):
    wheel=bpy.data.objects[f'Wheel_{i}']
    axle=wheel.matrix_world.translation.copy()
    hub_ring(wheel,axle,1 if axle.x>0 else -1)

# Hinge collars and neat flex protection stay on their respective arm links.
shoulder=bpy.data.objects['ArmShoulder']
elbow=bpy.data.objects['ArmElbow']
wrist=bpy.data.objects['ArmWrist']
for zz in (.484,.608):
    block('Upper_link_service_band',(.204,.430,zz),(.049,.049,.015),dark,.004,shoulder)
    bolt('Upper_link_band_screw',(.229,.430,zz),(1,0,0),.0036,shoulder)
sweep('Upper_link_flex_protection',[(.227,.423,.475),(.239,.422,.490),(.239,.421,.605),
         (.227,.424,.622)],.0047,rubber,shoulder)
for zz in (.711,.814):
    block('Forearm_seal_retainer',(.201,.430,zz),(.038,.040,.014),dark,.003,elbow)
    bolt('Forearm_retainer_pin',(.221,.430,zz),(1,0,0),.0038,elbow)
sweep('Forearm_service_conduit',[(.211,.445,.699),(.225,.444,.713),(.225,.444,.804),(.213,.445,.820)],
      .004,dark,elbow)
for side in (-1,1):
    block('Gripper_replaceable_jaw_pad',(.175 if side<0 else .225,.450,.937),
          (.011,.011,.036),rubber,.002,wrist)


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
targets=[
    ('chassis_rover_white',(.319,-.045,.332),(0,1,0),(1,0,0),(.340,.025),101,22),
    ('chassis_rover_white',(-.319,.053,.343),(0,1,0),(-1,0,0),(.335,.029),97,36),
    ('deck_white_painted',(.311,.144,.526),(0,1,0),(0,.10,1),(.181,.028),101,34),
    ('deck_white_painted',(-.308,.155,.524),(0,1,0),(0,0,1),(.195,.027),98,84),
    ('bumper_front_graphite',(0,.465,.319),(1,0,0),(0,1,0),(.244,.022),115,97),
    ('bumper_rear_graphite',(0,-.465,.321),(1,0,0),(0,-1,0),(.229,.026),93,138),
    ('head_rover_white',(-.124,.196,.965),(0,1,0),(-.51,0,1),(.100,.022),42,39),
    ('head_rover_white',(.125,.199,.963),(0,1,0),(.53,0,1),(.100,.018),40,44),
]
for name,point,axis,facing,spread,count,seed in targets:
    scuffs(bpy.data.objects[name],point,axis,facing,spread,(.0016,.0105),
           count,seed,(graphite,alloy,warm))

mapped={white,paint,graphite,orange,dark,alloy,steel,slate,solar,warm,rubber}
for obj in root.children_recursive:
    if obj.type!='MESH' or not any(m in mapped for m in obj.data.materials):
        continue
    if obj.data.users>1:
        obj.data=obj.data.copy()
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Surface UV')
    seed=random.Random(obj.name)
    u0,v0=seed.random(),seed.random()
    world=obj.matrix_world
    rotation=world.to_3x3()
    scale=7.25 if obj.name.startswith('wheel_') else 4.1
    for poly in obj.data.polygons:
        n=rotation@poly.normal
        axis=max(range(3),key=lambda i:abs(n[i]))
        u,v=[i for i in range(3) if i!=axis]
        flip=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
        for k in poly.loop_indices:
            point=world@obj.data.vertices[obj.data.loops[k].vertex_index].co
            layer.data[k].uv=(u0+point[u]*scale*flip,v0+point[v]*scale)

# Batch the added hardware for the game and retain individual parts in Blender.
def export_model():
    stage=bpy.data.collections.new('Game export details')
    scene.collection.children.link(stage)
    groups=defaultdict(list)
    for obj in model.objects:
        groups[obj.parent,obj.data.materials[0]].append(obj)
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for (parent,material),parts in groups.items():
        vertices,faces,normals,uvs=[],[],[],[]
        for obj in parts:
            evaluated=obj.evaluated_get(dg)
            mesh=evaluated.to_mesh()
            mesh.calc_loop_triangles()
            local=parent.matrix_world.inverted() @ obj.matrix_world
            normal_matrix=local.to_3x3().inverted().transposed()
            layer=mesh.uv_layers.active
            for tri in mesh.loop_triangles:
                pts=[local@mesh.vertices[k].co for k in tri.vertices]
                if (pts[1]-pts[0]).cross(pts[2]-pts[0]).length_squared<1e-20:
                    continue
                start=len(vertices)
                vertices.extend(pts)
                faces.append((start,start+1,start+2))
                normals.extend((normal_matrix @ mesh.corner_normals[k].vector).normalized() for k in tri.loops)
                uvs.extend(layer.data[k].uv.copy() for k in tri.loops)
            evaluated.to_mesh_clear()
        name=f'{parent.name}_field_detail_{material.name}'
        data=bpy.data.meshes.new(name)
        data.from_pydata(vertices,[],faces)
        data.update()
        data.materials.append(material)
        for face in data.polygons:
            face.use_smooth=True
        data.normals_split_custom_set(normals)
        layer=data.uv_layers.new(name='Surface UV')
        for i,uv in enumerate(uvs):
            layer.data[i].uv=uv
        node=bpy.data.objects.new(name,data)
        stage.objects.link(node)
        node.parent=parent

    scene.collection.children.unlink(model)
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in [root,*root.children_recursive]:
        if obj.name in bpy.context.view_layer.objects:
            obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    out=args.package/'original'/'GAR_Y_Field_Upgrade.glb'
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
                             export_extras=True,export_yup=True,export_tangents=True,
                             export_apply=True)
    for obj in list(stage.objects):
        data=obj.data
        bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(data)
    bpy.data.collections.remove(stage)
    scene.collection.children.link(model)


export_model()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active
            sp.shading.color_type='MATERIAL'
            sp.overlay.show_extras=False
            sp.region_3d.view_location=(0,0,.48)
            sp.region_3d.view_rotation=Vector((-1,-2.4,-.97)).to_track_quat('-Z','Y')
            sp.region_3d.view_distance=2.14
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/'GAR_Y_Field_Upgrade.blend'),compress=True)
