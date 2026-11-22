"""Model modular landing-site props and loose rocks for the Collapse pit lip."""
import argparse
from math import cos, pi, sin
from pathlib import Path
import random
import sys

from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import field_mesh as f

parser=argparse.ArgumentParser()
parser.add_argument('kit',choices=('Pad_Site','Pit_Lip'))
parser.add_argument('--textures',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
package=Path(__file__).resolve().parents[1]
master=f.initialize(args.kit.replace('_','')+'Layout',args.textures)
assets=[]


def asset(name):
    root=f.anchor(name)
    assets.append(root)
    return root


def stone_faces(name, rings, material, parent, bevel=0):
    count=len(rings[0])
    vertices=[f.v(coordinate) for ring in rings for coordinate in ring]
    faces=[tuple(reversed(range(count)))]
    for i in range(len(rings)-1):
        a,b=i*count,(i+1)*count
        for j in range(count):
            k=(j+1)%count
            faces.append((a+j,a+k,b+k,b+j))
    faces.append(tuple(range(len(vertices)-count,len(vertices))))
    return f.mesh(name,vertices,faces,material,parent,bevel)


def fractured_slab(name, width, depth, seed, stepped=False):
    root=asset(name)
    rng=random.Random(seed)
    crack=[(rng.uniform(-.145,.145)+(t-.5)*.24,depth*(t-.5))
           for t in (0,.08,.15,.24,.33,.40,.48,.57,.66,.72,.83,.92,1)]
    gap=[rng.uniform(.014,.038) for _ in crack]
    h=.133 if stepped else .114
    for i, side in enumerate((-1,1)):
        if stepped:
            group=f.anchor('Half_A' if i==0 else 'Half_B',(side*.61,0,0),root)
        else:
            group=root
        seam=[(x+side*offset,z) for (x,z),offset in zip(crack,gap)]
        x=side*width*.5
        rim=[(x-side*.100,depth*.5),(x,depth*.5-.087),
             (x-side*.012,-depth*.5+.088),(x-side*.091,-depth*.5)]
        outline=[*seam,*rim]
        width_center=side*width*.25
        rings=[]
        for j,(elev,shrink) in enumerate(((0,.964),(.026,.992),(h-.021,1.),(h,.993))):
            section=[]
            for k,(a,z) in enumerate(outline):
                edge_shift=rng.uniform(-.018,.017) if k<len(seam) and j in (1,2) else 0
                b=width_center+(a-width_center)*shrink+edge_shift
                d=z*(.998 if k==0 or k==len(seam)-1 else shrink)
                shift=rng.uniform(-.006,.004) if j>=2 and k<len(seam) else 0
                section.append((b,elev+shift,d))
            rings.append(section)
        slab=stone_faces('Sintered_regolith',rings,'warm_panel',group,.003)
        slab.data.materials.append(f.mats['slate_panel'])
        slab.data.materials.append(f.mats['white_painted'])
        slab.data.update()
        for face in slab.data.polygons:
            indices=[p%len(outline) for p in face.vertices]
            if face.normal.z<-.65 or (
                max(indices)<len(seam) and abs(face.normal.z)<.60):
                face.material_index=1
            elif face.normal.z<.5 and rng.random()<.10:
                face.material_index=2
        # Pits and broken aggregate stay close to the fracture without adding a second seam.
        for j in range(23):
            x0,z0=rng.choice(crack[1:-1])
            center=x0+side*rng.uniform(.048,.123)
            z0+=rng.uniform(-.057,.057)
            r=rng.uniform(.008,.026)
            p=[(center+cos(t*pi/2)*r*rng.uniform(.65,1.3),z0+sin(t*pi/2)*r*.7*rng.uniform(.8,1.1))
               for t in range(4)]
            f.slab('Exposed_aggregate',p,h-.001,h+.0006,
                   'white_painted' if j%3==0 else 'slate_panel',group,.0004)
    return root


def marker():
    root=asset('PadCornerMarker')
    f.loft('Driven_anchor_spike',[[f.v((r*cos(i*pi/3),h,r*sin(i*pi/3))) for i in range(6)]
           for h,r in ((0,.0003),(.022,.008),(.144,.012),(.205,.012))],'satin_steel',root)
    f.cyl('Depth_stop_plate',(0,.126,0),.061,.024,'dark_alloy',root,n=20,bevel=.006)
    f.cyl('Lower_bung',(0,.158,0),.027,.038,'black_rubber',root,n=20,bevel=.004)
    f.cyl('Reflector_post',(0,.280,0),.021,.247,'rover_white',root,n=20,bevel=.004)
    f.cyl('Optic_protection_skirt',(0,.383,0),.056,.049,'graphite',root,n=28,bevel=.007)
    f.cyl('Lamp',(0,.438,0),.050,.079,'lamp_amber',root,n=24,bevel=.004,exact=True)
    for i in range(5):
        f.cyl('Lens_prism',(0,.407+i*.0148,0),.052,.006,'lamp_amber',root,n=24,bevel=.002)
    f.cyl('Gasketed_beacon_lid',(0,.481,0),.062,.025,'orange',root,n=28,bevel=.006)
    f.cyl('Sacrificial_striker_plate',(0,.500,0),.034,.013,'dark_alloy',root,n=20,bevel=.004)
    for a in (.45,.45+2*pi/3,.45+4*pi/3):
        x,z=.054*cos(a),.054*sin(a)
        f.rod('Lamp_crush_guard',(x,.390,z),(x,.483,z),.0041,'satin_steel',root,12)
        f.bolt('Captive_lamp_fastener',(x*.61,.505,z*.61),(0,1,0),.004,root)
    return root


def edge_strip():
    root=asset('PadCrackEdgeStrip')
    rng=random.Random(29)
    full=3.05
    broken=[(.075+rng.uniform(-.035,.044),full*(i/42-.5)) for i in range(43)]
    rear=[(-.147,-full/2),(-.224,-full/2+.083),(-.210,full/2-.054),(-.127,full/2)]
    outline=broken+list(reversed(rear))
    rings=[[(x+((.031 if k<len(broken) else .008)*rate),h+
            (rng.uniform(-.025,.019) if k<len(broken) and h>0 else 0),z)
            for k,(x,z) in enumerate(outline)]
           for rate,h in ((-.8,-.07),(1,.011),(0,.115))]
    cut=stone_faces('Exposed_step_edge',rings,'warm_panel',root,.002)
    cut.data.materials.append(f.mats['slate_panel'])
    for face in cut.data.polygons:
        if face.normal.z<.63:
            face.material_index=1
    for z in (-1.24,-.67,-.24,.39,.97,1.41):
        f.slab('Broken_surface_flake',[(.03,z-.061),(.128,z-.091),(.213,z+.034),(.059,z+.082)],
               .086,.113,'white_painted',root,.005)
    return root


def volume_centroid(data):
    data.calc_loop_triangles()
    total=0.
    weighted=Vector()
    for tri in data.loop_triangles:
        a,b,c=[data.vertices[i].co for i in tri.vertices]
        volume=a.dot(b.cross(c))/6
        total+=volume
        weighted+=(a+b+c)*(volume/4)
    if abs(total)<1e-8:
        raise ValueError('Loose rubble must form a closed solid')
    return weighted/total


def rubble(index,width,height,depth,seed):
    root=asset(f'PitLipRubble_{index:02d}')
    rng=random.Random(seed)
    divisions=9
    foot_shape=[(cos(i*2*pi/divisions)*rng.uniform(.72,1.04),
                 sin(i*2*pi/divisions)*rng.uniform(.77,1.02)) for i in range(divisions)]
    vertices=[]
    for layer,(base,spread) in enumerate(((0,.60),(.22,1.0),(.67,.92),(1,.48))):
        for x,z in foot_shape:
            y=(base+rng.uniform(-.075,.048))*height
            u=(x*spread+(layer-1)*.043+rng.uniform(-.09,.09))*width*.5
            w=(z*spread+rng.uniform(-.08,.08))*depth*.5
            vertices.append(f.v((u,y,w)))
    faces=[tuple(reversed(range(divisions)))]
    for level in range(3):
        start,end=level*divisions,(level+1)*divisions
        for i in range(divisions):
            j=(i+1)%divisions
            faces.extend(((start+i,start+j,end+i),(start+j,end+j,end+i)))
    faces.append(tuple(range(divisions*3,divisions*4)))
    rock=f.mesh('Fractured_crust',vertices,faces,'warm_panel',root,.0023)
    center=volume_centroid(rock.data)
    for vert in rock.data.vertices:
        vert.co-=center
    rock.data.materials.append(f.mats['slate_panel'])
    rock.data.materials.append(f.mats['white_painted'])
    for face in rock.data.polygons:
        if face.normal.z<-.42 or (abs(face.normal.z)<.37 and rng.random()<.58):
            face.material_index=1
        elif rng.random()<.22:
            face.material_index=2
    f.bpy.context.view_layer.update()
    bottom=min(v.co.z for v in rock.data.vertices)
    return root,-bottom


def overhang():
    root=asset('PitLipUndercut')
    rng=random.Random(499)
    face_line=[(-1.18,-.71),(-.93,-.91),(-.43,-1.02),(-.16,-.93),
               (.07,-1.13),(.38,-.98),(.61,-.83),(.91,-.72),(1.20,-.79)]
    outline=face_line+[(1.37,-.40),(1.32,.68),(.86,.88),(-.84,.88),(-1.37,.60),(-1.39,-.22)]
    rings=[]
    for layer,(base,spread,resess) in enumerate(((-.63,.65,.36),(-.37,.88,.22),(-.15,1,.05),(.065,1,0))):
        ring=[]
        for i,(x,z) in enumerate(outline):
            relief=rng.uniform(-.086,.081) if layer!=3 else rng.uniform(-.023,.045)
            ring.append((x*spread,base+relief,z+(resess if i<len(face_line) else -.10*resess)))
        rings.append(ring)
    rock=stone_faces('Layered_undercut',rings,'warm_panel',root,.008)
    rock.data.materials.append(f.mats['slate_panel'])
    rock.data.materials.append(f.mats['warm_shell'])
    for face in rock.data.polygons:
        if face.normal.z<.18:
            face.material_index=1 if face.center.z<-.23 else 2
    # The upper ledge has sparse broken bedding fragments.
    for i in range(12):
        x=rng.uniform(-1.10,1.08)
        z=rng.uniform(-.53,.70)
        r=rng.uniform(.037,.113)
        points=[(x+r*cos(t*pi/2),z+r*.66*sin(t*pi/2)) for t in range(4)]
        f.slab('Bedding_surface_flake',points,.070,.076,'warm_shell' if i%3==0 else 'warm_panel',
               root,.0015)
    return root


if args.kit=='Pad_Site':
    marker()
    fractured_slab('CrackedSlabA',2.51,2.37,163)
    fractured_slab('CrackedSlabB',2.42,2.24,564)
    fractured_slab('CrackedSlabStep',2.69,2.56,961,True)
    edge_strip()
    display=[(-2.90,0,1.60),(-1.36,0,0.93),(1.26,0,1.28),
             (.06,0,-1.78),(2.90,0,-.83)]
else:
    display=[]
    for i,spec in enumerate(((.35,.19,.28,681),(.53,.29,.42,228),(.74,.34,.58,106),(.98,.51,.70,465)),1):
        rock,lift=rubble(i,*spec)
        display.append(((-1.40,-.65,.32,1.42)[i-1],lift,-1.65+(i%2)*.35))
    overhang()
    display.append((0,.02,.42))

f.uv_maps(f.collection.objects,scale=2.8)
for root in assets:
    f.bpy.ops.object.select_all(action='DESELECT')
    for node in [root,*root.children_recursive]:
        node.select_set(True)
    f.bpy.context.view_layer.objects.active=root
    f.bpy.ops.export_scene.gltf(filepath=str(package/'original'/f'{root.name}.glb'),
                               export_format='GLB',use_selection=True,export_apply=True,export_extras=True)
for root,position in zip(assets,display):
    root.parent=master
    root.location=f.v(position)
for screen in f.bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.overlay.show_extras=False
            space.shading.color_type='MATERIAL'
            space.region_3d.view_location=f.v((0,0,0))
            space.region_3d.view_rotation=Vector((-5,7,-6)).to_track_quat('-Z','Y')
            space.region_3d.view_distance=7
f.bpy.context.preferences.filepaths.save_version=0
f.bpy.ops.wm.save_as_mainfile(filepath=str(package/'source'/f'{args.kit}.blend'),compress=True)
