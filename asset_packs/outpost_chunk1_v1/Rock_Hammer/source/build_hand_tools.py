"""Build either of two hand tools in the shared suit-grip coordinate system."""
import argparse
from math import cos, sin, pi
from pathlib import Path
import sys

from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
import field_mesh as f

package = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--textures', type=Path, required=True)
parser.add_argument('--tool', choices=('Rock_Hammer', 'Sample_Scoop'), default=package.name)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])

hammer = args.tool == 'Rock_Hammer'
root = f.initialize(args.tool.replace('_', ''), args.textures)
f.anchor('Grip', parent=root)

def section(z, width, height, y=0):
    return [f.v((x, y + h, z)) for x, h in f.octagon(width, height, min(width, height)*.26)]

f.loft('Through_tang', [section(z,w,h) for z,w,h in [
    (.094,.024,.036), (.04,.025,.035),(-.065,.025,.032),(-.086,.022,.024),
    (-.166,.017,.018),(-.197,.019,.018)
] + ([(-.264,.028,.026)] if hammer else [])], 'dark_alloy', root, .0014)
f.loft('Pressure_glove_grip', [section(z,w,h) for z,w,h in [
    (.092,.038,.043),(.086,.043,.048),(.066,.043,.048),(.039,.039,.043),
    (-.026,.040,.044),(-.059,.044,.047),(-.073,.042,.043),(-.080,.036,.039)
]], 'black_rubber', root, .0018)
for z in (.063,.048,.033,.018,.003,-.012,-.027,-.042,-.057):
    for side in (-1,1):
        f.sweep('Overmould_grip_ridge', [(side*.016,-.013,z+.003),
            (side*.0205,0,z),(side*.016,.013,z-.003)], .002, 'black_rubber', root, 8)
f.loft('Machined_butt_plate',[section(z,.036,.041) for z in (.092,.100)],'graphite',root,.0024)
f.loft('Orange_grip_collar',[section(z,.034,.039) for z in (-.078,-.088)],'orange',root,.0012)
for side in (-1,1):
    f.loft('Shaft_flat', [[f.v((side*(width*.50+x),y,z)) for x,y in f.octagon(.002,.009,.0006)]
           for z,width in [(-.096,.021),(-.147,.018),(-.180,.017)]], 'graphite',root,.00045)

if hammer:
    z0=-.254
    head = f.loft('Head', [[f.v((x,y+h,z0+z)) for z,y in f.octagon(w,d,c)] for x,w,d,h,c in [
        (-.085,.004,.004,-.011,.001),(-.076,.011,.007,-.011,.002),
        (-.054,.018,.012,-.007,.003),(-.028,.026,.019,-.002,.003),
        (-.014,.042,.030,0,.006),(.015,.042,.032,0,.006),(.029,.035,.027,0,.004),
        (.047,.030,.026,0,.004),(.058,.047,.039,0,.005),(.078,.050,.043,0,.005),
        (.085,.046,.039,0,.004)
    ]], 'satin_steel', root, .00145, exact=True)
    head.data.transform(f.Matrix.Translation(-f.v((0,0,z0))))
    head.location=f.v((0,0,z0))
    f.bpy.context.view_layer.update()
    head['material_role']='satin_steel'
    outward=f.v((1,0,0)).to_track_quat('Y','Z').to_matrix()
    f.anchor('StrikePoint',(.085,0,z0),head,outward)
    f.block('Forged_handle_eye',(0,0,-.228),(.037,.031,.043),'dark_alloy',root,.0022,.005)
    f.cyl('Tang_lock_pin',(0,.016,-.229),.007,.004,'alloy',root,(0,1,0),20,.0006)
    f.wear(head,(.069,.021,z0),(0,0,1),(0,1,0),(.018,.009),(.003,.012),18,191)
else:
    joint=(0,.004,-.180)
    bearing=f.anchor('ScoopJoint',joint,root)
    # Rim flares at the mouth. The two steel skins share thick side, heel and front edges.
    profile=[(0,.033,.030),(.16,.041,.033),(.38,.046,.035),(.62,.048,.030),
             (.82,.049,.024),(1,.050,.015)]
    n=15
    vertices=[]
    for below in (0,.0018):
        for t,width,depth in profile:
            for i in range(n):
                q=-1+2*i/(n-1)
                x=width*q
                y=-.013+depth*(.77*abs(q)**3+.23*abs(q)**8)+.008*(1-t)-below
                z=-.12*t+.008*abs(q)**6*t*t
                vertices.append(f.v((x,y,z)))
    one=n*len(profile)
    faces=[]
    for layer in (0,one):
        for row in range(len(profile)-1):
            for col in range(n-1):
                i=layer+row*n+col
                face=(i,i+1,i+n+1,i+n)
                faces.append(face if layer else face[::-1])
    perimeter=[*range(n),*[row*n+n-1 for row in range(1,len(profile))],
               *range(one-2,one-n-1,-1),*[row*n for row in range(len(profile)-2,0,-1)]]
    for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):
        faces.append((a,b,b+one,a+one))
    pan=f.mesh('Pan',vertices,faces,'satin_steel',bearing,.0006,f.v(joint),exact=True)
    for face in pan.data.polygons:
        face.use_smooth=True
    for side in (-1,1):
        rim=[(side*w,.004-.013+d+.008*(1-t),-.180-.12*t+.008*t*t) for t,w,d in profile]
        f.sweep('Rolled_pan_rim',rim,.00155,'satin_steel',pan,10)
    back=[(x,.016+.019*abs(x/.033)**2,-.178) for x in (-.033,-.025,-.012,0,.012,.025,.033)]
    f.sweep('Reinforced_heel_rim',back,.0027,'alloy',pan,10)
    f.block('Stamped_pan_heel',(0,.004,-.185),(.051,.030,.026),'satin_steel',pan,.0022,.004)
    f.cyl('Tilt_pin',joint,.0071,.072,'satin_steel',root,(1,0,0),26,.0011)
    for side in (-1,1):
        f.block('Yoke_cheek',(side*.030,.003,-.165),(.008,.026,.050),'dark_alloy',root,.0025,.003)
        f.cyl('Tilt_pin_retainer',(side*.036,.004,-.180),.010,.0042,'alloy',root,(1,0,0),14,.0011)
    f.block('Yoke_bridge',(0,.0,-.145),(.063,.025,.018),'dark_alloy',root,.002,.004)
    f.anchor('PanTip',(0,-.009,-.300),pan)

# Scale the field texture for close first-person views.
f.uv_maps(list(f.collection.objects), scale=12)
f.save_and_export(package,args.tool,view_at=(0,0,-.07),view_distance=.53)
