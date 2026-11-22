"""Model hardware in metres. Public helpers take Godot coordinates."""
from pathlib import Path
from math import sin, cos, pi
import random

import bpy
import bmesh
from mathutils import Matrix, Vector, Quaternion


def v(co):
    x,y,z=co
    return Vector((x,-z,y))


def initialize(root_name, texture_dir):
    global scene, collection, mats, root
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC'
    collection=bpy.data.collections.new(root_name+' asset')
    scene.collection.children.link(collection)
    mats={}
    for name,color,rough,metal in [
        ('rover_white','D4CDBC',.52,.04),('white_painted','C6BDAA',.53,.03),
        ('orange','C96032',.45,.08),('graphite','333635',.58,.03),
        ('dark_alloy','4B5555',.43,.70),('alloy','7A8583',.37,.73),
        ('satin_steel','929B97',.36,.77),('warm_panel','B0A086',.62,.07),
        ('slate_panel','576365',.66,.08),('warm_shell','BFB29B',.62,.02),
        ('black_rubber','323430',.77,.01),('dark_glass','131C20',.24,.09),
        ('solar_cell','2B415C',.34,.24),('lamp_white','DAD8C8',.32,.05),
        ('lamp_amber','B7773C',.34,.04),('eye_glow','C7EAED',.31,.02)]:
        mat=bpy.data.materials.new(name)
        mat.use_nodes=True
        def linear(c):
            a=int(c,16)/255
            return a/12.92 if a<.04045 else ((a+.055)/1.055)**2.4
        color=tuple(linear(color[i:i+2]) for i in (0,2,4))+(1,)
        mat.diffuse_color=color
        p=mat.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=color
        p.inputs['Metallic'].default_value=metal
        p.inputs['Roughness'].default_value=rough
        if (texture_dir/f'{name}_color.png').exists():
            nodes,links=mat.node_tree.nodes,mat.node_tree.links
            def img(kind,space):
                node=nodes.new('ShaderNodeTexImage')
                node.image=bpy.data.images.load(str(texture_dir/f'{name}_{kind}.png'),check_existing=True)
                node.image.colorspace_settings.name=space
                node.image.pack()
                return node
            rgb=img('color','sRGB')
            rm=img('orm','Non-Color')
            split=nodes.new('ShaderNodeSeparateColor')
            norm=nodes.new('ShaderNodeNormalMap')
            norm.inputs['Strength'].default_value=.65
            links.new(rgb.outputs['Color'],p.inputs['Base Color'])
            links.new(rm.outputs['Color'],split.inputs[0])
            links.new(split.outputs['Green'],p.inputs['Roughness'])
            links.new(split.outputs['Blue'],p.inputs['Metallic'])
            links.new(img('normal','Non-Color').outputs['Color'],norm.inputs['Color'])
            links.new(norm.outputs['Normal'],p.inputs['Normal'])
        mats[name]=mat
    root=anchor(root_name)
    return root


def anchor(name, at=(0,0,0), parent=None, frame=None):
    obj=bpy.data.objects.new(name,None)
    collection.objects.link(obj)
    obj.empty_display_size=.10
    obj.parent=parent
    rotation=frame.to_4x4() if frame is not None else Matrix.Identity(4)
    rotation.translation=v(at)
    obj.matrix_world=rotation
    bpy.context.view_layer.update()
    return obj


def mesh(name,verts,faces,role,parent,bevel=0,world_at=None, exact=False):
    data=bpy.data.meshes.new(name+'_'+role)
    data.from_pydata(verts,[],faces)
    data.materials.append(mats[role])
    data.update()
    bm=bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj=bpy.data.objects.new(name if exact else name+'_'+role,data)
    collection.objects.link(obj)
    obj.parent=parent
    obj.matrix_world=Matrix.Translation(Vector() if world_at is None else world_at)
    if bevel:
        b=obj.modifiers.new('Machined edge radius','BEVEL')
        b.width=bevel
        b.segments=2
        b.limit_method='ANGLE'
        n=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
        n.keep_sharp=True
        for poly in data.polygons:
            poly.use_smooth=True
    obj['material_role']=role
    return obj


def octagon(w,h,c):
    x,y=w/2,h/2
    c=min(c,x*.44,y*.44)
    return [(-x+c,-y),(x-c,-y),(x,-y+c),(x,y-c),(x-c,y),(-x+c,y),(-x,y-c),(-x,-y+c)]


def loft(name,rings,role,parent,bevel=0,at=None,exact=False):
    n=len(rings[0])
    points=[vec for ring in rings for vec in ring]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(len(points)-n,len(points)))]
    for a in range(0,len(points)-n,n):
        for i in range(n):
            j=(i+1)%n
            faces.append((a+i,a+j,a+j+n,a+i+n))
    return mesh(name,points,faces,role,parent,bevel,at,exact)


def block(name,at,size,role,parent,bevel=.012,corner=.018,exact=False):
    w,h,d=size
    profile=octagon(w,d,corner)
    rings=[[(x,z,y) for x,z in profile] for y in (-h/2,h/2)]
    return loft(name,rings,role,parent,bevel,v(at),exact)


def slab(name,coords,y0,y1,role,parent,bevel=.015):
    return loft(name,[[v((x,y,z)) for x,z in coords] for y in (y0,y1)],role,parent,bevel)


def cyl(name,at,radius,depth,role,parent,axis=(0,1,0),n=24,bevel=.008,exact=False):
    ring=[(radius*cos(i*2*pi/n),radius*sin(i*2*pi/n)) for i in range(n)]
    q=v(axis).normalized().to_track_quat('Z','Y')
    return loft(name,[[q@Vector((x,y,z)) for x,y in ring] for z in (-depth/2,depth/2)],
                role,parent,bevel,v(at),exact)


def rod(name,start,end,rad,role,parent,n=16):
    a,b=Vector(start),Vector(end)
    return cyl(name,(a+b)*.5,rad,(a-b).length,role,parent,b-a,n,min(rad*.17,.012))


def sweep(name,points,rad,role,parent,n=12):
    points=[v(p) for p in points]
    rings=[]
    p_axis=None
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        if p_axis is None:
            a=Vector((0,0,1))
            if abs(tangent.dot(a))>.90:
                a=Vector((1,0,0))
            p_axis=tangent.cross(a).normalized()
        else:
            p_axis=(p_axis-tangent*p_axis.dot(tangent)).normalized()
        side=tangent.cross(p_axis)
        rings.append([p+rad*(p_axis*cos(j*2*pi/n)+side*sin(j*2*pi/n)) for j in range(n)])
    obj=loft(name,rings,role,parent)
    for f in obj.data.polygons:
        f.use_smooth=f.loop_total==4
    return obj


def bolt(name,point,axis,rad,parent):
    axis=Vector(axis).normalized()
    a=Vector(point)
    cyl(name+'_washer',a,rad*1.26,rad*.26,'dark_alloy',parent,axis,16,min(.002,rad*.1))
    cyl(name+'_cap',a+axis*rad*.22,rad,rad*.38,'satin_steel',parent,axis,8,min(.003,rad*.12))
    cyl(name+'_recess',a+axis*rad*.43,rad*.42,rad*.12,'graphite',parent,axis,6,min(.001,rad*.05))


def glass_quad(name,at,width,height,parent,normal=(0,0,1)):
    up=Vector((0,1,0))
    facing=Vector(normal)
    right=up.cross(facing)
    pts=[v(right*x+up*y) for x,y in [(-width/2,-height/2),(width/2,-height/2),
                                   (width/2,height/2),(-width/2,height/2)]]
    obj=mesh(name,pts,[(0,1,2,3)],'dark_glass',parent,world_at=v(at),exact=True)
    face=obj.data.polygons[0]
    if face.normal.dot(v(facing))<0:
        face.flip()
    uv=obj.data.uv_layers.new(name='Screen UV')
    for loop in obj.data.loops:
        uv.data[loop.index].uv=((0,0),(1,0),(1,1),(0,1))[loop.vertex_index]
    return obj


def uv_maps(objects,scale=2.7):
    bpy.context.view_layer.update()
    for obj in objects:
        if obj.type!='MESH' or obj.data.uv_layers:
            continue
        layers=obj.data.uv_layers.new(name='Field finish UV')
        values=random.Random(obj.name)
        u0,v0=values.random(),values.random()
        transform=obj.matrix_world
        for poly in obj.data.polygons:
            normal=transform.to_3x3()@poly.normal
            axis=max(range(3),key=lambda i:abs(normal[i]))
            u,w=[i for i in range(3) if i!=axis]
            flip=(1 if normal[axis]>=0 else -1)*(-1 if axis==1 else 1)
            for i in poly.loop_indices:
                point=transform@obj.data.vertices[obj.data.loops[i].vertex_index].co
                layers.data[i].uv=(u0+point[u]*scale*flip,v0+point[w]*scale)


def wear(obj,center,across_face,outward,spread,lengths,count,seed):
    """Project thin chipped paint marks onto the existing curved surface."""
    bpy.context.view_layer.update()
    eval_obj=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    world=obj.matrix_world
    inverse=world.inverted()
    n=v(outward).normalized()
    tangent=v(across_face).normalized()
    cross=n.cross(tangent)
    aim=(inverse.to_3x3()@-n).normalized()
    rng=random.Random(seed)
    convex=((-0.5,-.26),(-.22,.44),(.21,.47),(.48,.04),(.23,-.33),(-.14,-.47))
    by_role={'graphite':([],[]),'alloy':([],[])}
    for _ in range(count):
        center_pt=v(center)+tangent*rng.uniform(-spread[0],spread[0])+cross*rng.uniform(-spread[1],spread[1])
        length=rng.uniform(*lengths)
        width=length*rng.uniform(.22,.42)
        path=[]
        for a,b in convex:
            ray=center_pt+tangent*(a+rng.uniform(-.12,.12))*length+cross*(b+rng.uniform(-.10,.10))*width
            hit,p,direction,_=eval_obj.ray_cast(inverse@(ray+n*.052),aim,distance=.092)
            if not hit or direction.dot(-aim)<.3:
                break
            path.append(world@(p+direction*.0008))
        if len(path)==len(convex):
            pts,faces=by_role[rng.choice(('graphite','graphite','alloy'))]
            index=len(pts)
            pts.extend(path)
            faces.append(tuple(reversed(range(index,index+len(path)))))
    for role,(pts,faces) in by_role.items():
        if faces:
            mesh('Contact_wear',pts,faces,role,obj.parent)


def select_asset():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=root


def save_and_export(package,filename,view_at,view_distance,pose=None):
    select_asset()
    bpy.ops.export_scene.gltf(filepath=str(package/'original'/f'{filename}.glb'),export_format='GLB',
                             use_selection=True,export_apply=True,export_extras=True,export_tangents=False)
    if pose is not None:
        pose()
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                sp=area.spaces.active
                sp.overlay.show_extras=False
                sp.shading.color_type='MATERIAL'
                sp.region_3d.view_location=v(view_at)
                sp.region_3d.view_rotation=Vector((-5,8,-4)).to_track_quat('-Z','Y')
                sp.region_3d.view_distance=view_distance
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(package/'source'/f'{filename}.blend'),compress=True)
