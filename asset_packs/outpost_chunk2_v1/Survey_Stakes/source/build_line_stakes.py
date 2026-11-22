"""Build one hand-planted stake and the six-stake stores bundle."""
import argparse
from math import cos, sin, pi
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parent))
import field_mesh as f

package=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('model', choices=('Survey_Stake','Survey_Stake_Bundle'))
parser.add_argument('--textures', type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bundled=args.model.endswith('_Bundle')
root=f.initialize('SurveyStakeBundle' if bundled else 'SurveyStake',args.textures)

def pole(parent,name,sections,role,segments=12):
    return f.loft(name, [[f.v((radius*cos(i*2*pi/segments),height,radius*sin(i*2*pi/segments)))
            for i in range(segments)] for height,radius in sections], role,parent,
            min(.0009,min(radius for _,radius in sections)*.08))

def flag(parent, folded):
    pivot=(.025,.718,0)
    n,m=15,10
    points=[]
    for row in range(m):
        for col in range(n):
            s,t=col/(n-1),row/(m-1)
            if folded:
                radius=.023+(.0005*row)
                x=radius*cos(2.0*s)-pivot[0]
                y=-.088*t+.010*sin(s*pi)
                z=radius*sin(2.0*s)
            else:
                x=.151*s*(1-.17*t**2)
                y=-.084*t-.022*s+.007*sin(2*pi*s)*t
                z=.014*sin(s*7.0)*s + .004*sin(8*t+12*s)*s
            points.append(f.v((x,y,z)))
    faces=[(i,i+1,i+n+1,i+n) for i in range(n*(m-1)) if i%n!=n-1]
    ob=f.mesh('Flag',points,faces,'slate_panel',parent,world_at=f.v(pivot),exact=True)
    solid=ob.modifiers.new('Woven fabric thickness','SOLIDIFY')
    solid.thickness=.00065
    solid.offset=0
    ob.data.materials.append(f.mats['warm_shell'])
    for face in ob.data.polygons:
        face.use_smooth=True
        rows=[i//n for i in face.vertices]
        columns=[i%n for i in face.vertices]
        if min(rows)==0 or max(rows)==m-1 or max(columns)==n-1:
            face.material_index=1
    f.bpy.context.view_layer.update()
    hem=[]
    for i in range(n):
        x,z,y=points[i]+f.v(pivot)
        hem.append((x,y,-z))
    f.sweep('Flag_stitched_hem',hem,.0012,'warm_shell',ob,7)
    return ob

def make_stake(parent,folded=False,number=None):
    stake=f.anchor('Stake' if number is None else f'Stored_stake_{number}',parent=parent)
    pole(stake,'Hardened_planting_tip',[(.0,.00015),(.013,.0055),(.169,.0103),(.188,.0112)],'alloy',10)
    pole(stake,'Reinforced_shaft',[(.170,.010),(.237,.0105),(.782,.0105),(.818,.0095)],'slate_panel',12)
    f.cyl('Lower_impact_collar',(0,.179,0),.0147,.036,'dark_alloy',stake,n=18,bevel=.0022)
    f.cyl('Collar_ridge',(0,.19,0),.0156,.009,'satin_steel',stake,n=16,bevel=.0017)
    f.cyl('Upper_ferrule',(0,.792,0),.0144,.041,'alloy',stake,n=18,bevel=.0028)
    pole(stake,'Pressure_glove_grip',[(.418,.012),(.434,.0165),(.451,.0174),(.567,.0174),(.580,.0165),(.591,.012)],'black_rubber',12)
    for height in (.453,.469,.485,.501,.517,.533,.549,.565):
        f.cyl('Moulded_grip_rib',(0,height,0),.0183,.0036,'black_rubber',stake,n=16,bevel=.00065)
    if not folded:
        f.anchor('GripPoint',(0,.506,0),stake)
    # The cylinder is the independently addressable amber signal lens.
    f.cyl('Reflector_base',(0,.824,0),.024,.025,'graphite',stake,n=22,bevel=.0032)
    f.cyl('Head',(0,.852,0),.0194,.048,'lamp_amber',stake,n=20,bevel=.002,exact=True)
    f.cyl('Reflector_bumper',(0,.883,0),.025,.018,'graphite',stake,n=22,bevel=.0030)
    f.cyl('Strike_plate',(0,.896,0),.018,.007,'alloy',stake,n=18,bevel=.0012)
    for a in (.35,.35+2*pi/3,.35+4*pi/3):
        x,z=.022*cos(a),.022*sin(a)
        f.rod('Lens_guard',(x,.822,z),(x,.884,z),.0032,'alloy',stake,8)
    f.cyl('Flag_upper_swivel',(0,.728,0),.0131,.011,'dark_alloy',stake,n=16,bevel=.0012)
    f.cyl('Flag_lower_swivel',(0,.637,0),.0131,.011,'dark_alloy',stake,n=16,bevel=.0012)
    f.rod('Flag_halyard',(.017,.638,0),(.023,.727,0),.0021,'warm_shell',stake,8)
    flag(stake,folded)
    return stake

if not bundled:
    make_stake(root)
    f.uv_maps(f.collection.objects,scale=5.9)
    f.save_and_export(package,args.model,(0,.46,0),1.35,compact=True)
else:
    for index in range(6):
        body=make_stake(root,True,index+1)
        row,col=divmod(index,3)
        origin=((col-1)*.062,.053+row*.058,.450-.011*(col+row))
        body.location=f.v(origin)
        body.rotation_euler.x=-pi/2
        f.bpy.context.view_layer.update()
    # Shock-resistant end shoes keep the tips and beacons out of the webbing.
    f.block('Point_protection_tray',(0,.031,.348),(.216,.062,.243),'graphite',root,.016,.025)
    f.block('Point_protection_nose',(0,.067,.443),(.211,.116,.071),'graphite',root,.012,.018)
    f.block('Head_protection_tray',(0,.031,-.389),(.228,.062,.123),'graphite',root,.013,.018)
    f.block('Head_protection_nose',(0,.074,-.462),(.227,.131,.043),'graphite',root,.010,.018)
    for x in (-.075,0,.075):
        f.block('Tip_cushion',(x,.061,.397),(.040,.021,.077),'black_rubber',root,.004,.006)
    for z in (-.260,.238):
        # Flat strap follows a rounded rectangle around the load.
        x,y,c=.101,.062,.018
        profile=f.octagon(x*2,y*2,c)
        rings=[[f.v((u,.073+w,z+side*.014)) for u,w in profile] for side in (-1,1)]
        for side in (-1,1):
            rings.append([f.v((u*.98,.073+w*.977,z+side*.014)) for u,w in profile])
        bands=[]
        for k in range(8):
            j=(k+1)%8
            bands.extend([(k,j,j+8,k+8),(k,k+16,j+16,j),(k+8,j+8,j+24,k+24),(k+16,k+24,j+24,j+16)])
        f.mesh('Cargo_retention_webbing',sum(rings,[]),bands,'graphite',root,.001)
        f.block('Cam_buckle_frame',(.056,.141,z),(.064,.025,.048),'dark_alloy',root,.004,.008)
        f.block('Cam_buckle_release',(.055,.157,z),(.039,.012,.031),'orange',root,.0025,.004)
        for px in (.031,.079):
            f.cyl('Cam_buckle_pin',(px,.150,z+.008),.0036,.0036,'satin_steel',root,n=10,bevel=.00045)
    f.sweep('Webbing_carry_handle',[(.021,.133,-.25),(.021,.162,-.174),
        (.021,.198,-.101),(.021,.202,.106),(.021,.164,.179),(.021,.134,.232)],.0094,'graphite',root,10)
    f.rod('Padded_carry_sleeve',(.021,.202,-.085),(.021,.202,.087),.0155,'black_rubber',root,16)
    f.anchor('BundleGrip',(.021,.202,0),root)
    f.uv_maps(f.collection.objects,scale=5.9)
    f.save_and_export(package,args.model,(0,.096,0),1.65,compact=True)
