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
    parser.add_argument('--asset', choices=('Sled', 'Hitch'), required=True)
    parser.add_argument('--textures', type=Path, required=True)
    parser.add_argument('--package', type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


args = inputs()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
model = bpy.data.collections.new('Field Equipment')
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


indicator = material('lamp_amber','AB7444',.32,.06)
root = object_with_data('RadarSled' if args.asset=='Sled' else 'GAR_Y_TowHitch')
root['front_axis_godot'] = '-Z'


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


if args.asset=='Sled':
    # +Y in Blender is GAR-Y's -Z forward axis in Godot.
    tow=object_with_data('TowPoint',parent=root,point=(0,.602,.181))
    antenna=object_with_data('Antenna',parent=root)
    scan=object_with_data('ScanOrigin',parent=root,point=(0,-.017,.079))
    scan.rotation_euler.x=-pi/2
    status=object_with_data('StatusLens',parent=root)
    skids=object_with_data('Skids',parent=root)
    root['survey_envelope']='Underside radar origin; terrain scan results supplied by the game'
    for side in (-1,1):
        x=side*.251
        profile=[(-.562,.066),(-.507,.019),(-.413,0),(.349,0),
                 (.459,.029),(.532,.088),(.522,.113),(.439,.072),
                 (.348,.045),(-.410,.044),(-.508,.072),(-.551,.092)]
        loft('Swaged_skid_runner',[[(x+u,y,z) for y,z in profile] for u in (-.060,.060)],dark,.008,skids)
        shoe_profile=[(-.447,.018),(-.405,0),(.333,0),(.380,.010),(.379,.019),(-.406,.018)]
        loft('Replaceable_runner_wear_strip',[[(x+u,y,z) for y,z in shoe_profile] for u in (-.049,.049)],alloy,.004,skids)
        for y in (-.341,.298):
            gusset=[(y-.065,.039),(y+.077,.039),(y+.041,.133),(y-.025,.133)]
            loft('Machined_runner_riser',[[(x+u,t,z) for t,z in gusset] for u in (-.038,.038)],alloy,.007)
            block('Runner_isolation_pad',(x,y,.151),(.104,.132,.036),rubber,.008)
            for dy in (-.041,.041):
                bolt('Isolator_flange_bolt',(x,y+dy,.167),r=.008)
        for y in (-.392,.397):
            corner=block('Orange_skid_impact_shoe',(x,y,.070),(.132,.109,.062),orange,.009)
            bolt('Impact_shoe_captive_screw',(x,y,.101),r=.006)
        sweep('EVA_side_grab_handle',[(side*.292,-.155,.264),(side*.326,-.143,.284),
               (side*.335,-.105,.286),(side*.335,.105,.286),
               (side*.326,.143,.284),(side*.292,.155,.264)],.012,steel)
        rod('Grip_sleeve',(side*.335,-.087,.286),(side*.335,.087,.286),.017,rubber)
        for y in (-.143,.144):
            block('Grab_handle_spreader',(side*.292,y,.262),(.034,.064,.054),dark,.007)
            bolt('Handle_spreader_screw',(side*.313,y,.262),(side,0,0),.005)

    # Long broad, glass-free downward antenna housing held clear of the ground.
    deck('Radar_equipment_chassis',[(.138,.490,.771,.066),(.167,.566,.836,.058),
          (.272,.585,.836,.054),(.302,.544,.786,.066)],dark,.010)
    deck('Sealed_enclosure_gasket',[(.258,.555,.825,.060),(.277,.565,.829,.056)],rubber,.005)
    deck('Warm_white_weather_shell',[(.280,.572,.835,.058),(.316,.588,.837,.061),
          (.350,.553,.792,.066),(.365,.500,.738,.068)],white,.013)
    block('Downward_radar_radome',(0,-.020,.119),(.446,.621,.064),warm,.010,antenna,corner=.041)
    block('Composite_antenna_face',(0,-.020,.092),(.400,.571,.019),graphite,.007,antenna,corner=.036)
    for side in (-1,1):
        block('Radar_face_ground_guard',(side*.227,-.020,.113),(.028,.648,.031),alloy,.004)
        for y in (-.271,-.115,.100,.256):
            bolt('Antenna_retainers',(side*.220,y,.094),(0,0,-1),.0058)
        for y in (-.344,.344):
            cap=block('Corner_bumper',(side*.248,y,.313),(.115,.146,.116),orange,.013,corner=.026)
            bolt('Bumper_upper_fastener',(side*.258,y,.374),r=.0065)
        block('Cooling_shield_recess',(side*.285,-.060,.228),(.014,.376,.097),graphite,.004)
        for j in range(5):
            block('Cooling_shield_fins',(side*.300,-.060,.198+j*.015),(.022,.314-.017*abs(j-2),.006),
                  alloy if j in (1,3) else dark,.002)

    block('Electronics_service_cover_seam',(-.045,-.057,.365),(.397,.436,.009),graphite,.005,corner=.029)
    block('Raised_electronics_service_cover',(-.045,-.057,.372),(.378,.419,.012),white,.005,corner=.026)
    for x in (-.186,.096):
        for y in (-.220,.114):
            bolt('Electronics_captive_fastener',(x,y,.380),r=.0057)
    for x in (-.128,-.053,.022):
        block('Service_cover_press_ridge',(x,-.061,.382),(.025,.207,.010),white,.004)
    sweep('Low_profile_receiver_aerial',[(.176,-.225,.370),(.191,-.194,.399),
          (.208,-.166,.418),(.227,-.088,.418)],.0075,steel)
    block('Receiver_aerial_shock_mount',(.179,-.226,.361),(.061,.072,.025),graphite,.005)
    block('Scan_state_lens_gasket',(0,.248,.365),(.151,.074,.019),rubber,.006)
    block('Scan_state_indicator_guard',(0,.248,.374),(.134,.061,.017),dark,.005)
    block('Scan_state_lens',(0,.249,.385),(.093,.028,.005),indicator,.0025,status)
    for x in (-.056,.056):
        bolt('Status_lens_captive_screw',(x,.249,.383),r=.0036)
        block('Scan_lens_raised_ear',(x,.250,.390),(.015,.043,.014),orange,.004)

    # Y-shaped tow bridle clears the antenna and concentrates load into a steel eye.
    block('Tow_bridle_load_plate',(0,.419,.223),(.347,.040,.141),dark,.008,corner=.016)
    for side in (-1,1):
        bolt('Tow_bridle_load_bolt',(side*.141,.442,.229),(0,1,0),.009)
        sweep('Tow_bridle_arm',[(side*.123,.435,.222),(side*.098,.486,.204),
              (side*.062,.539,.184),(side*.041,.572,.177)],.023,alloy)
    block('Tow_eye_backer',(0,.564,.179),(.126,.061,.033),orange,.008)
    # A through-bore lets the quick-release clip engage a visible steel eye.
    def outline(rx,rz):
        return [(rx*cos(i*2*pi/32),rz*sin(i*2*pi/32)) for i in range(32)]
    outer,inner=outline(.058,.039),outline(.031,.019)
    pts=[(x,y,.181+z) for y,shape in [(.587,outer),(.587,inner),(.617,outer),(.617,inner)] for x,z in shape]
    faces=[]
    for i in range(32):
        j=(i+1)%32
        faces += [(i,j,32+j,32+i),(i,64+i,64+j,j),(32+i,32+j,96+j,96+i),(64+i,96+i,96+j,64+j)]
    geom('Tow_eye',pts,faces,steel,.004)
else:
    # Hitch origin mates to the GAR-Y RearMount contact plane. Local -Z in
    # Godot points outward, away from GAR-Y, when the two frames coincide.
    plate=object_with_data('MountPlate',parent=root)
    reel=object_with_data('Reel',parent=root,point=(0,.093,.014))
    clip=object_with_data('Clip',parent=root,point=(0,.176,-.035))
    cable=object_with_data('CableOut',parent=root,point=(0,.147,-.028))
    block('Bolt_on_adapter_plate',(0,.008,0),(.226,.019,.108),graphite,.009,plate)
    block('Adapter_load_spreader',(0,.025,.001),(.186,.033,.088),alloy,.007,plate)
    for x in (-.086,.086):
        for z in (-.032,.032):
            bolt('Adapter_plate_captive_bolt',(x,.022,z),(0,1,0),.006,plate)

    for side in (-1,1):
        profile=[(.025,-.047),(.128,-.041),(.151,-.015),(.138,.048),(.111,.077),(.043,.071)]
        loft('Reel_side_cheek',[[(side*.092+dx,y,z) for y,z in profile] for dx in (-.014,.014)],dark,.006)
        cylinder('Reel_bearing_seat',(side*.110,.093,.014),.033,.020,alloy,(side,0,0),n=26)
        cylinder('Reel_bearing_cap',(side*.124,.093,.014),.020,.015,orange,(side,0,0),n=22)
        bolt('Reel_bearing_fastener',(side*.132,.093,.014),(side,0,0),.007)
        block('Reel_side_protector',(side*.098,.137,.057),(.034,.042,.026),orange,.007)

    cylinder('Reel_drum',(0,.093,.014),.0358,.120,dark,(1,0,0),reel,n=36)
    for x in (-.063,.063):
        cylinder('Reel_Painted_flange',(x,.093,.014),.054,.016,orange,(1,0,0),reel,n=36)
        cylinder('Reel_flange_rim',(x,.093,.014),.055,.004,alloy,(1,0,0),reel,n=36)
    turns=[]
    for i in range(361):
        a=i*2*pi/45
        turns.append((-.053+i*.106/360,.093+.039*cos(a),.014+.039*sin(a)))
    sweep('Wound_Drum_Cable',turns,.0042,rubber,reel)
    rod('Lower_Fairlead_bar',(-.072,.145,-.038),(.072,.145,-.038),.008,steel)
    rod('Upper_Fairlead_bar',(-.072,.145,-.017),(.072,.145,-.017),.007,steel)
    for side in (-1,1):
        block('Exit_roller_end_bracket',(side*.071,.145,-.026),(.020,.024,.042),dark,.005)
        bolt('Fairlead_fastener',(side*.071,.160,-.024),(0,1,0),.0045)

    sweep('Reeved_Cable_Stowed',[(0,.149,-.026),(0,.158,-.026),(0,.168,-.028)],.0056,rubber,clip)
    block('Clip_swivel_body',(0,.179,-.035),(.034,.031,.043),dark,.007,clip)
    sweep('Quick_release_hook',[(0,.182,-.052),(-.009,.185,-.062),(-.017,.188,-.075),
          (-.010,.189,-.089),(.006,.189,-.088),(.013,.186,-.077)],.006,steel,clip)
    block('Clip_glove_release',(.017,.189,-.059),(.015,.029,.032),orange,.005,clip)


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
    if obj.name.startswith(('Corner_bumper','Orange_skid','Reel_side_protector')):
        center=obj.matrix_world.translation
        s=-1 if center.x<0 else 1
        scuffs(obj,center+Vector((s*.027,0,.028)),(0,1,0),(s,0,.75),
               (.038,.020),(.0015,.010),58,i+720,(graphite,alloy,graphite))
        scuffs(obj,center+Vector((0,0,.051)),(0,1,0),(0,0,1),
               (.040,.029),(.0014,.012),49,i+105,(graphite,alloy))
    if obj.name.startswith('Replaceable_runner_wear_strip'):
        center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
        s=-1 if center.x<0 else 1
        scuffs(obj,(center.x+s*.050,-.04,.010),(0,1,0),(s,0,0),
               (.35,.010),(.003,.026),122,i+34,(warm,graphite,steel))


def surface_uv(p,n,offset,scale):
    axis=max(range(3),key=lambda i:abs(n[i]))
    u,v=[i for i in range(3) if i!=axis]
    sign=(1 if n[axis]>=0 else -1)*(-1 if axis==1 else 1)
    return (p[u]*scale*sign+offset[0],p[v]*scale+offset[1])


for obj in model.objects:
    if obj.type!='MESH':
        continue
    seed=random.Random(obj.name)
    obj['uv_offset']=(seed.random(),seed.random())
    obj['uv_scale']=5 if args.asset=='Sled' else 8
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
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in stage.objects:
        o.select_set(True)
    path=args.package/'original'/('Radar_Sled.glb' if args.asset=='Sled' else 'GAR_Y_Tow_Hitch.glb')
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
for ui in bpy.data.screens:
    for area in ui.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.color_type='MATERIAL'
            space.overlay.show_extras=False
            space.region_3d.view_location=(0,0,.18 if args.asset=='Sled' else .02)
            space.region_3d.view_rotation=Vector((-1,-2,-1)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=2.0 if args.asset=='Sled' else .52
bpy.context.preferences.filepaths.save_version=0
name='Radar_Sled' if args.asset=='Sled' else 'GAR_Y_Tow_Hitch'
bpy.ops.wm.save_as_mainfile(filepath=str(args.package/'source'/f'{name}.blend'),compress=True)
