"""Build and export the Site Plan Terminal. Run with Blender from any directory."""
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
model = bpy.data.collections.new('Site Plan Terminal')
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
    obj.location = Vector(point) if parent is None else Vector(point) - parent.location
    return obj


root = object_with_data('SitePlanTerminal')
root['front_axis_godot'] = '+Z (operator side)'
use_point = object_with_data('UsePoint',parent=root,point=(0,-.640,0))
use_point['purpose'] = 'Floor reference for operator approach'
feet = object_with_data('Feet',parent=root)


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


# Weighted split base with replaceable heel and toe pads.
for side in (-1,1):
    x=side*.190
    block('Ground_isolation_pad',(x,0,.011),(.145,.445,.022),rubber,.009,feet,corner=.027)
    chassis=[(.020,.167,.453,.034),(.049,.172,.448,.036),(.067,.137,.389,.034)]
    loft('Formed_base_runner',[[(a+x,b,z) for a,b in octagon(w,l,c)] for z,w,l,c in chassis],
         dark,.008,feet)
    for y in (-.134,.134):
        block('Replaceable_foot_tread',(x,y,.066),(.109,.111,.013),graphite,.005,feet,corner=.012)
        for k in range(4):
            block('Recessed_tread_slot',(x,y-.034+k*.022,.073),(.073,.005,.002),rubber,.001,feet)
        bolt('Base_captive_screw',(x+side*.038,y+.031,.073),r=.0058,parent=feet)
    block('Floor_level_shock_guard',(x,-.190,.058),(.127,.076,.043),orange,.012,feet,corner=.017)
block('Crosshead_mount',(0,.042,.062),(.391,.245,.084),dark,.012,feet,corner=.025)
block('Column_base_gasket',(0,.052,.109),(.238,.206,.024),rubber,.007,feet,corner=.018)
for x in (-.093,.093):
    for y in (-.027,.130):
        bolt('Column_base_captive_bolt',(x,y,.128),r=.0068,parent=feet)

# Twin housings over a load-bearing spine. The spine leans away from the operator.
def column(label,sections,material,radius=.008):
    rings=[[(x,y+shift,z) for x,y in octagon(w,d,c)] for z,w,d,c,shift in sections]
    return loft(label,rings,material,radius)


column('Pedestal_structure',[(.096,.214,.198,.022,.040),(.149,.227,.200,.021,.046),
       (.281,.195,.168,.019,.057),(.684,.174,.155,.023,.096),(.798,.240,.184,.022,.098)],dark)
column('Insulated_column_panels',[(.141,.204,.149,.018,.019),(.192,.223,.155,.018,.023),
       (.636,.203,.147,.017,.077),(.749,.234,.150,.024,.082)],white,.010)
column('Front_pedestal_rebate',[(.176,.143,.029,.012,-.066),(.239,.144,.028,.012,-.062),
       (.645,.133,.026,.012,-.007),(.702,.128,.026,.012,.003)],graphite,.007)
column('Pedestal_front_access_cover',[(.193,.121,.019,.010,-.079),(.231,.127,.020,.010,-.074),
       (.638,.115,.020,.010,-.021),(.682,.096,.017,.010,-.013)],white,.007)
for z in (.222,.622):
    y=-.087+(z-.222)*.137
    for x in (-.041,.041):
        bolt('Pedestal_panel_screw',(x,y,z),(0,-1,0),.0048)
for side in (-1,1):
    profile=[(.004,.112),(.126,.112),(.122,.245),(.084,.314),(.059,.224)]
    loft('Pedestal_load_gusset',[[(side*.117+dx,y,z) for y,z in profile] for dx in (-.011,.011)],alloy,.004)
    for z in (.225,.283,.341,.399,.457,.515,.573):
        y=.069+(z-.34)*.14
        block('Pedestal_side_air_relief',(side*.102,y,z),(.014,.071,.012),dark,.004)
# A keyed service inlet and a clipped loom on the rear of the spine.
block('Rear_service_cover',(0,.168,.450),(.142,.025,.275),graphite,.008,corner=.013)
for x in (-.052,.052):
    for z in (.341,.559):
        bolt('Rear_cover_fastener',(x,.184,z),(0,1,0),.0048)
block('Power_inlet_guard',(0,.185,.338),(.077,.030,.053),orange,.007)
cylinder('Power_inlet_body',(0,.202,.338),.022,.018,dark,(0,1,0),n=24)
cylinder('Inlet_sealed_face',(0,.214,.338),.014,.012,rubber,(0,1,0),n=24)
cylinder('Inlet_cable_gland',(0,.219,.338),.009,.011,steel,(0,1,0),n=18)
sweep('Power_loom',[(0,.225,.338),(0,.243,.362),(0,.243,.412),(0,.225,.458),
     (0,.200,.535),(0,.194,.605),(0,.192,.685),(0,.172,.735),(0,.166,.773)],.008,rubber)
for z,y in [(.462,.228),(.599,.196),(.685,.191)]:
    block('Cable_saddle',(0,y,z),(.053,.019,.016),alloy,.004)
    for x in (-.016,.016):
        bolt('Cable_saddle_screw',(x,y+.011,z),(0,1,0),.0032)

# The head, single planar display, glare hood and control shelf.
center=Vector((0,.012,.938))
horizontal=Vector((1,0,0))
up=Vector((0,.640,.768)).normalized()
normal=horizontal.cross(up).normalized()
screen_width=.440
screen_height=.2475
face_rotation=Matrix((horizontal,up,normal)).transposed().to_quaternion()


def face_point(u,v,depth):
    return center + u*horizontal + v*up + depth*normal


def face_loft(label, sections, material, rounding=.004):
    return loft(label,[[face_point(u,v,depth) for u,v in octagon(w,h,c)]
                      for depth,w,h,c in sections],material,rounding)


def face_block(label,u,v,d,size,material,radius=.004):
    obj=block(label,face_point(u,v,d),size,material,radius)
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=face_rotation
    return obj


def face_ring(label,outer,inner,d0,d1,material):
    pts=[face_point(x,y,z) for z,poly in [(d0,outer),(d0,inner),(d1,outer),(d1,inner)]
         for x,y in poly]
    n=len(outer)
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(i,2*n+i,2*n+j,j),
                      (n+i,n+j,3*n+j,3*n+i),(2*n+i,3*n+i,3*n+j,2*n+j)])
    return geom(label,pts,faces,material,.003)


face_loft('Display_rear_housing',[(-.113,.486,.285,.034),(-.087,.546,.309,.031),
          (-.029,.574,.321,.031),(-.004,.570,.313,.028)],white,.011)
face_loft('Gasketed_display_carrier',[(-.014,.542,.294,.022),(-.006,.550,.298,.022)],rubber,.004)
face_ring('Recessed_display_bezel',octagon(.558,.313,.027),octagon(.449,.257,.001),
          -.008,.014,graphite)
face_ring('Rubber_display_isolator',octagon(.485,.286,.010),octagon(.441,.2485,.0004),
          -.005,.005,rubber)
screen=geom('display_surface',[(-screen_width/2,-screen_height/2,0),(screen_width/2,-screen_height/2,0),
           (screen_width/2,screen_height/2,0),(-screen_width/2,screen_height/2,0)],[(0,1,2,3)],
           glass,point=face_point(0,0,.001),object_name='Screen')
# One quad and four UV corners keep live viewport textures undistorted.
screen.rotation_mode='QUATERNION'
screen.rotation_quaternion=face_rotation
screen.data.polygons[0].flip() if screen.data.polygons[0].normal.z<0 else None
uv=screen.data.uv_layers.new(name='Screen UV')
for loop in screen.data.loops:
    point=screen.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv=(point.x/screen_width+.5,point.y/screen_height+.5)
screen['viewport_aspect'] = '16:9'

hood_side=[]
for side in (-1,1):
    # Deep at top, relieved at the controls so the operator can see the screen off-axis.
    contour=[(-.124,-.003),(.144,-.005),(.154,.070),(.121,.081),(-.085,.032),(-.120,.022)]
    hood_side.append(loft('Formed_glare_hood_cheek',[[face_point(side*u,v,d) for v,d in contour]
                          for u in (.257,.273)],graphite,.005))
    face_block('Orange_head_shock_guard',side*.276,-.094,-.006,(.049,.107,.077),
               orange,.011)
    for v in (-.106,.110):
        bolt('Screen_head_captive_fastener',face_point(side*.244,v,.016),normal,.0048)
    for v in (-.083,.078):
        bolt('Rear_display_service_fastener',face_point(side*.225,v,-.107),-normal,.0059)
    face_block('Display_heat_sink_base',side*.162,.035,-.103,(.111,.142,.025),alloy,.005)
    for j in range(6):
        face_block('Display_cooling_fin',side*.162,.080-j*.019,-.120,(.098,.007,.021),
                   dark,.002)
hood=face_block('Glare_hood_bridge',0,.151,.031,(.552,.020,.096),graphite,.005)
face_block('Hood_front_lip',0,.146,.080,(.545,.013,.013),dark,.003)
for u in (-.221,.221):
    bolt('Hood_assembly_screw',face_point(u,.163,.072),up,.005)

block('Head_pedestal_bridge',(0,.057,.756),(.246,.193,.097),dark,.017,corner=.025)
for x in (-.083,.083):
    bolt('Head_mount_fastener',(x,.033,.711),(0,0,-1),.007)

# Angled, inset keypad within reach from the interaction point.
deck_center=Vector((0,-.161,.799))
deck_up=Vector((0,.981,.194)).normalized()
deck_normal=horizontal.cross(deck_up).normalized()
deck_rotation=Matrix((horizontal,deck_up,deck_normal)).transposed().to_quaternion()


def deck_at(x,y,z):
    return deck_center+horizontal*x+deck_up*y+deck_normal*z


def key_block(name,x,y,z,w,length,thick,mat,bevel=.005):
    obj=block(name,deck_at(x,y,z),(w,length,thick),mat,bevel)
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=deck_rotation
    return obj


key_block('Keypad_ledge_backing',0,0,-.036,.550,.202,.094,dark,.014)
key_block('Keypad_ledge_shell',0,-.003,-.020,.571,.206,.071,white,.014)
key_block('Keypad_inlay',-.004,-.006,.021,.529,.169,.017,graphite,.007)
key_block('Keypad_gasket',-.008,-.006,.029,.509,.151,.006,rubber,.003)
for i in range(5):
    for j in range(2):
        x=-.185+i*.053
        y=-.034+j*.051
        key_block('Key_stem',x,y,.034,.041,.040,.013,dark,.003)
        key_block('Glove_keycap',x,y,.045,.038,.037,.012,white if j else alloy,.005)
        key_block('Raised_key_ridge',x-.002,y,.051,.017,.0035,.003,
                  graphite if j else dark,.0012)
for x in (-.234,.237):
    for y in (-.064,.059):
        bolt('Keypad_captive_screw',deck_at(x,y,.035),deck_normal,.0045)
knob_at=deck_at(.158,.001,.041)
cylinder('Jog_dial_socket',knob_at,.046,.020,dark,deck_normal,n=32,fillet=.0025)
cylinder('Jog_dial_grip',deck_at(.158,.001,.059),.037,.028,rubber,deck_normal,n=40,fillet=.003)
cylinder('Jog_dial_satin_thumb',deck_at(.158,.001,.076),.028,.004,alloy,deck_normal,n=36,fillet=.0012)
for i in range(16):
    angle=i*pi/8
    p=deck_at(.158+.034*cos(angle),.001+.034*sin(angle),.060)
    rod('Jog_dial_grip_flute',p-deck_normal*.009,p+deck_normal*.009,.004,graphite)
key_block('Recessed_confirm_switch',.073,-.044,.043,.044,.028,.015,orange,.006)
key_block('Recessed_cancel_switch',.073,.047,.043,.043,.023,.014,alloy,.005)
for side in (-1,1):
    key_block('Ledge_edge_protector',side*.270,-.066,.010,.049,.068,.045,orange,.009)
    key_block('Padded_ledge_rest',side*.181,-.088,.028,.146,.021,.011,rubber,.005)

# Small carry handles sit clear of the hood and bolt into the display chassis.
for side in (-1,1):
    pts=[face_point(side*u,v,d) for u,v,d in
         [(.263,-.070,-.075),(.277,-.073,-.089),(.284,-.048,-.120),
          (.284,.042,-.120),(.277,.064,-.096),(.263,.069,-.077)]]
    sweep('Display_service_grab_loop',pts,.010,steel)

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
        geom('Contact_wear_'+target.name,verts,faces,mat,parent=target.parent)


bpy.context.view_layer.update()
for i,part in enumerate(list(model.objects)):
    if part.name.startswith(('Floor_level_shock_guard','Ledge_edge_protector','Orange_head_shock_guard')):
        side=1 if part.location.x>0 else -1
        scuffs(part,part.location+Vector((side*.011,-.030,.014)),(1,0,0),(0,-1,.38),
               (.023,.022),(.0016,.009),50,39+i,(graphite,alloy,graphite))
        direction=deck_normal if 'Ledge' in part.name else normal if 'head' in part.name else Vector((0,0,1))
        scuffs(part,part.location+direction*.030,(1,0,0),direction,
               (.025,.023),(.0013,.009),42,550+i,(graphite,alloy))
    if part.name.startswith('Formed_base_runner'):
        side=1 if sum(v.co.x for v in part.data.vertices)>0 else -1
        scuffs(part,(side*.275,0,.041),(0,1,0),(side,0,0),(.193,.019),
               (.002,.019),100,112+i,(alloy,graphite,warm))
    if part.name.startswith('Keypad_ledge_shell'):
        scuffs(part,deck_at(.008,-.106,-.021),(1,0,0),(0,-1,.10),(.244,.022),
               (.002,.013),117,286,(graphite,alloy,graphite))
scuffs(hood,face_point(.012,.162,.073),(1,0,0),up,(.244,.013),(.002,.012),
       65,120,(alloy,dark,graphite))


def uv_point(p,n,offset=(0,0)):
    axis=max(range(3),key=lambda i:abs(n[i]))
    u,v=[i for i in range(3) if i!=axis]
    flip=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u]*4.9*flip+offset[0],p[v]*4.9+offset[1])


for obj in model.objects:
    if obj.type!='MESH' or obj==screen:
        continue
    layer=obj.data.uv_layers.new(name='Surface UV')
    seed=random.Random(obj.name)
    offset=(seed.random(),seed.random())
    obj['uv_offset']=offset
    for face in obj.data.polygons:
        for index in face.loop_indices:
            point=obj.data.vertices[obj.data.loops[index].vertex_index].co
            layer.data[index].uv=uv_point(point,face.normal,offset)


def export_game():
    # Batch stationary hardware by house role. Keep live glass a separate mesh.
    export=bpy.data.collections.new('Game export')
    scene.collection.children.link(export)
    copies={}
    names={}
    for source in [root,feet,use_point,screen]:
        names[source]=source.name
        source.name='Source__'+source.name
        copy=bpy.data.objects.new(names[source],source.data if source==screen else None)
        export.objects.link(copy)
        copy.parent=copies.get(source.parent)
        copy.matrix_basis=source.matrix_basis.copy()
        for key in source.keys():
            copy[key]=source[key]
        copies[source]=copy
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for parent in [root,feet]:
        anchor=copies[parent]
        bins=defaultdict(list)
        for obj in parent.children:
            if obj.type=='MESH' and obj!=screen:
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
            data=bpy.data.meshes.new(name)
            data.from_pydata(verts,[],triangles)
            data.update()
            data.materials.append(mat)
            data.normals_split_custom_set(normals)
            for poly in data.polygons:
                poly.use_smooth=True
            layer=data.uv_layers.new(name='Surface UV')
            for loop,uv in zip(layer.data,uvs):
                loop.uv=uv
            node=bpy.data.objects.new(name,data)
            export.objects.link(node)
            node.parent=anchor
            node['material_role']=mat.name
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in export.objects:
        o.select_set(True)
    path=args.package/'original'/'Site_Plan_Terminal.glb'
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                             export_extras=True,export_yup=True,export_tangents=True)
    for o in list(export.objects):
        bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.collections.remove(export)
    for part,name in names.items():
        part.name=name
    for data in list(bpy.data.meshes):
        if data.users==0:
            bpy.data.meshes.remove(data)


export_game()
for view in bpy.data.screens:
    for area in view.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.color_type='MATERIAL'
            space.overlay.show_extras=False
            space.region_3d.view_location=(0,0,.57)
            space.region_3d.view_rotation=Vector((-1,1.8,-.65)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=2.1
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/'Site_Plan_Terminal.blend'),compress=True)
