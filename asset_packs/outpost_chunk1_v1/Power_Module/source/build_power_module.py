"""Build and export the Power Module. Run with Blender from any directory."""
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
model = bpy.data.collections.new('Power Module')
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
lamp = material('lamp_white','41403A',.30,.02)


def object_with_data(name, data=None, parent=None, point=(0,0,0)):
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(point) if parent is None else Vector(point) - parent.location
    return obj


root = object_with_data('PowerModule')
root['front_axis_godot'] = '+Z'
root['attachment_axis_godot'] = '-Z (local outward normal)'
socket = object_with_data('SocketFace',parent=root,point=(0,.484,.268))
tow = object_with_data('TowPoint',parent=root,point=(0,-.472,.146))
tow.rotation_euler.z = pi
handles = object_with_data('Handles',parent=root)
skid = object_with_data('Skid',parent=root)


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


def ring(label,center,outer,inner,depth,mat,parent=root):
    cx,cy,cz=center
    verts=[]
    for y, contour in [(cy-depth/2,outer),(cy-depth/2,inner),(cy+depth/2,outer),(cy+depth/2,inner)]:
        verts.extend((x+cx,y,z+cz) for x,z in contour)
    n=len(outer)
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i),(i,2*n+i,2*n+j,j),
                  (n+i,n+j,3*n+j,3*n+i),(2*n+i,3*n+i,3*n+j,2*n+j)]
    return geom(label,verts,faces,mat,.003,parent)


def bolt(label,point,axis=(0,0,1),r=.006, parent=root):
    axis = Vector(axis)
    pos = Vector(point)
    cylinder(label+'_washer',pos-axis*.0013,r*1.38,.003,dark,axis,parent,n=18,fillet=.0006)
    cylinder(label,pos+axis*.0014,r,.0048,steel,axis,parent,n=8,fillet=.00065)
    cylinder(label+'_drive',pos+axis*.004,r*.43,.0013,graphite,axis,parent,n=6,fillet=.00025)


# Pressed enclosure, shock frame and gasket joint.
deck('Battery_chassis',[(.104,.477,.744,.068),(.145,.518,.783,.056),
                        (.332,.518,.783,.056),(.361,.495,.752,.057)],dark,.012)
deck('Thermal_shell',[(.151,.492,.750,.062),(.171,.528,.787,.057),
                     (.350,.528,.787,.057),(.366,.511,.772,.065)],white,.013)
deck('Continuous_cover_gasket',[(.354,.519,.784,.061),(.371,.519,.784,.061)],rubber,.004)
deck('Power_conditioning_cover',[(.368,.528,.797,.061),(.395,.542,.804,.065),
                                (.431,.513,.765,.063),(.447,.475,.725,.068)],white,.011)
deck('Lower_perimeter_rail',[(.109,.513,.784,.069),(.153,.537,.816,.069)],graphite,.009)
for sx in (-1,1):
    for sy in (-1,1):
        corner = block('Corner_impact_guard',(sx*.244,sy*.346,.382),(.098,.135,.120),orange,.012,corner=.020)
        corner.rotation_euler.z = sx*sy*.14
        block('Lower_corner_buffer',(sx*.245,sy*.347,.140),(.099,.112,.076),rubber,.012,corner=.015)
        for yy in (.337,.365):
            bolt('Captive_guard_screw',(sx*.260,sy*yy,.442),r=.006)
    # Outward use of the right and left grab bars is mirrored.
    pts = [(sx*.216,-.244,.420),(sx*.216,-.244,.444),(sx*.227,-.235,.461),
           (sx*.247,-.212,.476),(sx*.254,-.173,.480),(sx*.254,.173,.480),
           (sx*.247,.212,.476),(sx*.227,.235,.461),(sx*.216,.244,.444),(sx*.216,.244,.420)]
    sweep('Glove_lift_handle',pts,.0165,steel,handles)
    rod('Textured_handle_sleeve',(sx*.254,-.138,.480),(sx*.254,.138,.480),.020,rubber,handles)
    for k in range(10):
        cylinder('Moulded_grip_rib',(sx*.254,-.126+k*.028,.480),.0208,.0040,graphite,(0,1,0),handles,n=20,fillet=.0009)
    for y in (-.244,.244):
        block('Load_spreader',(sx*.215,y,.442),(.090,.090,.015),dark,.006,handles)
        for dy in (-.028,.028):
            bolt('Handle_bracket_screw',(sx*.209,y+dy,.451),r=.0055,parent=handles)
    # Welded skid runners rise at the ends, leaving a flat deck datum.
    profile=[(-.500,.068),(-.445,.018),(-.377,.001),(.375,.001),(.441,.019),(.500,.073),
             (.495,.093),(.412,.063),(.355,.055),(-.376,.055),(-.443,.078),(-.490,.105)]
    loft('Skid_runner',[[(sx*.242+dx,y,z) for y,z in profile] for dx in (-.054,.054)],dark,.008,skid)
    shoe=[(-.451,.027),(-.389,0),(.389,0),(.447,.027),(.423,.035),(.385,.023),(-.385,.023),(-.424,.035)]
    loft('Replaceable_wear_shoe',[[(sx*.242+dx,y,z) for y,z in shoe] for dx in (-.048,.048)],alloy,.005,skid)
    for y in (-.249,.239):
        block('Shock_isolation_biscuit',(sx*.232,y,.091),(.089,.108,.037),rubber,.008,skid)
        block('Screened_runner_boss',(sx*.245,y,.071),(.100,.125,.016),graphite,.004,skid)
        for dxy in (-.035,.035):
            bolt('Runner_mounting_bolt',(sx*.245,y+dxy,.080),r=.006,parent=skid)
        gusset=[(y-.064,.049),(y+.063,.050),(y+.049,.095),(y-.025,.126)]
        loft('Welded_runner_gusset',[[(sx*.276+dx,yy,z) for yy,z in gusset] for dx in (-.012,.012)],alloy,.0025,skid)
    # External connector thermal rejection and protected side seams.
    block('Heat_spreader_gasket',(sx*.262,.032,.270),(.013,.394,.145),rubber,.005)
    block('Heat_spreader_plate',(sx*.270,.032,.270),(.018,.376,.127),alloy,.006)
    for j in range(7):
        z=.221+j*.016
        block('Passive_cooling_fin',(sx*.282,.031,z),(.027,.321-.014*abs(j-3),.0065),dark,.0025)
    for y in (-.139,.203):
        for z in (.222,.318):
            bolt('Heat_spreader_bolt',(sx*.279,y,z),(sx,0,0),.005)
    block('Formed_impact_side_rail',(sx*.272,.014,.184),(.027,.568,.036),graphite,.008)
    for y in (-.238,.250):
        bolt('Rub_strip_fastener',(sx*.287,y,.183),(sx,0,0),.005)

# Two-piece service lid and a protected flush indicator.
cover = block('Cover_seam',(0,.075,.448),(.327,.342,.006),graphite,.004,corner=.022)
block('Recessed_service_lid',(0,.075,.452),(.316,.331,.012),white,.005,corner=.019)
for x in (-.135,.135):
    for y in (-.064,.211):
        bolt('Captive_cover_screw',(x,y,.459),r=.0052)
for x in (-.082,0,.082):
    block('Pressed_lid_stiffener',(x,.060,.462),(.027,.197,.011),white,.004,corner=.008)
for x in (-.091,.091):
    block('Pallet_strap_saddle',(x,-.202,.447),(.047,.054,.016),dark,.005)
    for dy in (-.022,.022):
        block('Strap_keeper',(x,-.202+dy,.457),(.047,.008,.014),alloy,.002)
block('Indicator_gasket',(0,-.297,.444),(.117,.065,.016),rubber,.005)
block('Indicator_guard',(0,-.297,.451),(.103,.058,.015),dark,.0058)
block('Indicator_lens_recess',(0,-.297,.459),(.074,.028,.005),glass,.003)
block('Status_lens',(0,-.298,.461),(.064,.020,.005),lamp,.0025,object_name='StatusLamp')
for x in (-.043,.043):
    bolt('Indicator_guard_screw',(x,-.296,.459),r=.0038)
    block('Raised_indicator_brow',(x,-.295,.465),(.010,.039,.012),orange,.003)

# Tow-side shear plate and through-bored cable eye.
block('Tow_end_shear_plate',(0,-.394,.240),(.390,.039,.150),graphite,.010,corner=.022)
for x in (-.152,.152):
    for z in (.202,.288):
        bolt('Tow_end_shear_bolt',(x,-.416,z),(0,-1,0),.0068)
for x in (-.071,.071):
    block('Tow_lug_cheek',(x,-.425,.143),(.025,.102,.068),orange,.007)
    bolt('Tow_lug_clevis_pin',(x,-.455,.147),(1 if x>0 else -1,0,0),.008)
block('Tow_steel_mount',(0,-.436,.120),(.170,.067,.031),dark,.006)
tow_outer=[(.056*cos(2*pi*i/32),.040*sin(2*pi*i/32)) for i in range(32)]
tow_inner=[(.029*cos(2*pi*i/32),.022*sin(2*pi*i/32)) for i in range(32)]
ring('Tow_eye',(0,-.472,.146),tow_outer,tow_inner,.026,steel)
for x in (-.120,.120):
    block('Mechanical_shock_pad',(x,-.428,.190),(.039,.025,.078),rubber,.006)

# True stepped connector recess on the docking end, with an asymmetric key.
connector_profile=[(-.148,-.081),(.115,-.081),(.148,-.049),(.148,.055),
                   (.106,.087),(-.092,.087),(-.148,.047)]
def scaled(profile,x,z):
    return [(a*x,b*z) for a,b in profile]

block('Docking_load_frame',(0,.397,.267),(.431,.043,.231),dark,.013,socket,corner=.024)
ring('Docking_gasket',(0,.423,.268),scaled(connector_profile,1.20,1.20),
     scaled(connector_profile,.86,.83),.020,rubber,socket)
ring('Keyed_plug_guard',(0,.447,.268),scaled(connector_profile,1.11,1.10),
     scaled(connector_profile,.83,.79),.057,orange,socket)
ring('Connector_inner_shield',(0,.463,.268),scaled(connector_profile,.91,.89),
     scaled(connector_profile,.74,.71),.042,steel,socket)
block('Connector_insulator',(0,.433,.269),(.230,.026,.129),glass,.009,socket,corner=.021)
for x,z,r in [(-.068,.270,.017),(.019,.279,.018),(.068,.256,.014)]:
    cylinder('Recessed_contact_insulator',(x,.448,z),r+.006,.014,rubber,(0,1,0),socket,n=24)
    cylinder('Contact_shoulder',(x,.458,z),r,.014,dark,(0,1,0),socket,n=20)
    cylinder('Recessed_power_contact',(x,.465,z),r*.51,.017,steel,(0,1,0),socket,n=20)
for i in range(6):
    x=-.066+i*.021
    cylinder('Signal_contact_surround',(x,.450,.230),.008,.005,rubber,(0,1,0),socket,n=16,fillet=.001)
    cylinder('Signal_contact',(x,.456,.230),.0033,.011,steel,(0,1,0),socket,n=16,fillet=.00075)
block('Asymmetric_alignment_key',(-.040,.471,.321),(.090,.029,.023),dark,.005,socket)
for x in (-.193,.193):
    for z in (.191,.344):
        bolt('Connector_frame_screw',(x,.422,z),(0,1,0),.0071,socket)
    block('Floating_guide_shoe',(x,.442,.265),(.037,.061,.084),alloy,.006,socket)
    block('Guide_shoe_wear_face',(x,.473,.265),(.026,.014,.051),steel,.005,socket)


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
targets = list(model.objects)
for index,obj in enumerate(targets):
    if obj.name.startswith('Corner_impact_guard_'):
        x,y,z=obj.location
        scuffs(obj,(x+(.040 if x>0 else -.04),y,z+.024),(0,1,0),
               (1 if x>0 else -1,0,.65),(.055,.026),(.0016,.014),74,17+index,(graphite,alloy,graphite))
        scuffs(obj,(x,y,z+.059),(0,1,0),(0,0,1),(.047,.034),(.0018,.015),45,72+index,(alloy,graphite))
    elif obj.name.startswith('Replaceable_wear_shoe_'):
        mean_x = sum(v.co.x for v in obj.data.vertices)/len(obj.data.vertices)
        side = 1 if mean_x>0 else -1
        scuffs(obj,(mean_x+side*.048,.017,.016),(0,1,0),(side,0,0),
               (.397,.012),(.006,.040),181,54+index,(warm,graphite,steel,alloy,graphite))
    elif obj.name.startswith('Lower_corner_buffer_'):
        x,y,z=obj.location
        side=1 if x>0 else -1
        scuffs(obj,(x+side*.049,y,z-.013),(0,1,0),(side,0,0),
               (.050,.018),(.002,.014),55,31+index,(warm,graphite,graphite))
    elif obj.name.startswith('Floating_guide_shoe_'):
        x,y,z=obj.location+socket.location
        scuffs(obj,(x,y+.031,z),(0,0,1),(0,1,0),(.033,.013),(.003,.012),28,53+index,(graphite,steel))
scuffs(cover,(.116,.070,.451),(0,1,0),(0,0,1),(.144,.013),(.002,.014),36,966,(graphite,alloy))
scuffs(bpy.data.objects['Recessed_service_lid_rover_white'],(-.145,.09,.458),(0,1,0),(0,0,1),
       (.124,.010),(.002,.012),49,141,(graphite,alloy,graphite))
scuffs(bpy.data.objects['Tow_eye_satin_steel'],(0,-.484,.146),(1,0,0),(0,-1,0),
       (.054,.039),(.003,.011),42,307,(graphite,warm,alloy))

# The game export batches fixed parts by attachment and house material.
# The Blender source keeps each bolt, fin and guard individually editable.
def uv_point(p,n,offset=(0,0)):
    axis = max(range(3),key=lambda i:abs(n[i]))
    u,v = [i for i in range(3) if i!=axis]
    flip = (1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u]*4.9*flip+offset[0],p[v]*4.9+offset[1])


for obj in model.objects:
    if obj.type != 'MESH':
        continue
    layer = obj.data.uv_layers.new(name='Surface UV')
    shift = random.Random(obj.name)
    offset=(shift.random(),shift.random())
    obj['uv_offset'] = offset
    for poly in obj.data.polygons:
        for index in poly.loop_indices:
            vert = obj.data.vertices[obj.data.loops[index].vertex_index].co
            layer.data[index].uv = uv_point(vert,poly.normal,offset)


def export_game():
    staging=bpy.data.collections.new('Game export')
    scene.collection.children.link(staging)
    anchors=[root,socket,tow,handles,skid]
    original_names={}
    export_anchors={}
    for source in anchors:
        original_names[source]=source.name
        source.name='Source__'+source.name
        node=bpy.data.objects.new(original_names[source],None)
        staging.objects.link(node)
        node.parent=export_anchors.get(source.parent)
        node.matrix_basis=source.matrix_basis.copy()
        node.empty_display_size=.06
        for key in source.keys():
            node[key]=source[key]
        export_anchors[source]=node
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for parent, anchor in export_anchors.items():
        bins=defaultdict(list)
        for obj in parent.children:
            if obj.type!='MESH':
                continue
            mat=obj.data.materials[0]
            key='Indicator' if obj.name=='StatusLamp' else mat.name
            bins[key].append(obj)
        for key,parts in bins.items():
            positions, normals, uvs, triangles = [], [], [], []
            indices={}
            m=parts[0].data.materials[0]
            keep_lamp=key=='Indicator'
            if keep_lamp:
                original_names[parts[0]]=parts[0].name
                parts[0].name='Source__StatusLamp'
            for obj in parts:
                evaluated=obj.evaluated_get(dg)
                mesh=evaluated.to_mesh()
                mesh.calc_loop_triangles()
                xf=Matrix.Identity(4) if keep_lamp else anchor.matrix_world.inverted() @ obj.matrix_world
                norm_mat=xf.to_3x3().inverted().transposed()
                for tri in mesh.loop_triangles:
                    xyz=[xf @ mesh.vertices[i].co for i in tri.vertices]
                    if (xyz[1]-xyz[0]).cross(xyz[2]-xyz[0]).length_squared<1e-20:
                        continue
                    ids=[]
                    for point in xyz:
                        coordinate=tuple(round(c,7) for c in point)
                        if coordinate not in indices:
                            indices[coordinate]=len(positions)
                            positions.append(point)
                        ids.append(indices[coordinate])
                    if len(set(ids))<3:
                        continue
                    triangles.append(ids)
                    normals.extend((norm_mat @ mesh.corner_normals[i].vector).normalized() for i in tri.loops)
                    uvs.extend(uv_point(mesh.vertices[i].co,tri.normal,obj['uv_offset']) for i in tri.vertices)
                evaluated.to_mesh_clear()
            data=bpy.data.meshes.new(f'{anchor.name}_{m.name}' if not keep_lamp else 'status_lens_lamp_white')
            data.from_pydata(positions,[],triangles)
            data.materials.append(m)
            data.update()
            for poly in data.polygons:
                poly.use_smooth=True
            data.normals_split_custom_set(normals)
            uv=data.uv_layers.new(name='Surface UV')
            for loop,st in zip(uv.data,uvs):
                loop.uv=st
            node=bpy.data.objects.new('StatusLamp' if keep_lamp else f'{anchor.name}_{m.name}',data)
            staging.objects.link(node)
            node.parent=anchor
            if keep_lamp:
                node.matrix_basis=parts[0].matrix_basis.copy()
            node['material_role']=m.name
    for item in bpy.context.selected_objects:
        item.select_set(False)
    for item in staging.objects:
        item.select_set(True)
    target=args.package / 'original' / 'Power_Module.glb'
    target.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                             export_extras=True,export_yup=True,export_tangents=True)
    for item in list(staging.objects):
        bpy.data.objects.remove(item,do_unlink=True)
    bpy.data.collections.remove(staging)
    for item,name in original_names.items():
        item.name=name
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
            space.region_3d.view_location=(0,0,.25)
            space.region_3d.view_rotation=Vector((-1,-1.35,-.78)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=1.55
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/'Power_Module.blend'), compress=True)
