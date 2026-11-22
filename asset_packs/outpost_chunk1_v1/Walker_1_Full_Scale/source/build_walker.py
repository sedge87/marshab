"""Build the full-size Walker 1 and underslung General Module."""
from pathlib import Path
from math import pi, cos, sin, acos, atan2
import argparse
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))

import bpy
from mathutils import Matrix, Vector
from field_mesh import initialize, anchor, block, cyl, rod, sweep, bolt, mesh, slab, glass_quad, wear, v
import field_mesh as f

parser=argparse.ArgumentParser()
parser.add_argument('--textures',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
package=Path(__file__).resolve().parents[1]
root=initialize('Walker1',args.textures)
root['forward_axis']='-Z'
body=anchor('Body',parent=root)
module=anchor('Module',(0,1.25,0),root)
ride=anchor('RideDeckFold',(0,5.37,-4.80),body)
berth=anchor('Berth',(0,.35,0),body)

# Perimeter load frame with a clear aperture for the grounded core.
# The four rails form one named mesh without capping the aperture.
def ring_frame():
    outer=f.octagon(8.4,11.2,.34)
    inner=f.octagon(7.04,9.20,.075)
    points=[v((x,h,z)) for h,profile in [(5.0,outer),(5.0,inner),(5.6,outer),(5.6,inner)] for x,z in profile]
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,j+8,i+8),(i,i+16,j+16,j),(i+8,j+8,j+24,i+24),(i+16,i+24,j+24,j+16)])
    return mesh('frame',points,faces,'rover_white',body,.043)

frame=ring_frame()
for s in (-1,1):
    for h in (5.107,5.502):
        block('Outer_frame_chord',(s*4.12,h,0),(.154,.100,10.45),'dark_alloy',body,.020,.065)
    for i in range(10):
        z=-4.74+i*1.05
        block('Structural_lightening_recess',(s*4.21,5.301,z),(.028,.303,.801),'graphite',body,.019,.022)
        rod('Diagonal_frame_web',(s*4.235,5.170,z-.344),(s*4.235,5.430,z+.344),.052,'alloy',body)
    for z in (-5.,0.,5.):
        block('Hip_structural_hardpoint',(s*4.112,5.172,z),(.214,.468,.728),'orange',body,.030,.052)
        for zz in (z-.229,z+.229):
            bolt('Hip_hardpoint_fastener',(s*4.228,5.324,zz),(s,0,0),.049,body)
    sweep('Recessed_frame_loom',[(s*4.05,4.991,i) for i in (-5.18,-4.50,-3.55,-1.20,1.60,3.85,5.18)],
           .042,'black_rubber',body)
    for z in (-4.30,-2.42,0,2.42,4.30):
        block('Loom_saddle',(s*4.051,4.982,z),(.149,.10,.115),'alloy',body,.012)
    for z in (-5.23,5.22):
        block('Chassis_corner_guard',(s*3.98,5.336,z),(.307,.471,.365),'orange',body,.035,.056)
    block('Outer_pipe_cover',(s*3.823,5.624,0),(.20,.073,8.53),'slate_panel',body,.021)
for z in (-5.45,5.45):
    for x in (-2.8,-1.42,0,1.42,2.8):
        block('Bumper_access_recess',(x,5.203,z),(.92,.195,.287),'graphite',body,.024,.055)
        for j in range(3):
            block('Bumper_service_fin',(x,5.160+j*.051,z+(-.151 if z<0 else .151)),
                  (.76,.016,.030),'alloy',body,.004)
block('Rear_ladder_landing',(0,5.52,5.073),(1.64,.154,1.046),'alloy',body,.037)
for i in range(8):
    block('Rear_deck_traction_rib',(-.644+i*.18,5.605,5.082),(.039,.025,.892),'graphite',body,.006)

# Rider shelf folds towards the nose after the payload touches down.
block('Ride_deck_platform',(0,5.297,-3.731),(2.185,.123,1.735),'slate_panel',ride,.025)
for s in (-1,1):
    rod('Deck_fold_hinge',(0,5.37,-4.80),(s*.972,5.37,-4.80),.066,'satin_steel',body)
    block('Deck_hinge_leaf',(s*.74,5.36,-4.656),(.183,.075,.327),'alloy',ride,.016)
    for z in (-4.337,-2.984):
        rod('Safety_rail_stanchion',(s*.982,5.404,z),(s*.982,6.085,z),.044,'alloy',ride)
    sweep('Safety_rail',[(s*.982,6.078,-4.398),(s*.982,6.078,-3.564),
                         (s*.982,6.078,-2.881),(s*.820,6.078,-2.881)],.042,'orange',ride)
    bolt('Deck_anchor_bolt',(s*.892,5.370,-4.329),(0,1,0),.031,ride)
anchor('Seat',(0,5.36,-3.15),ride)
block('Ride_seat_mount',(0,5.51,-3.15),(.32,.315,.31),'dark_alloy',ride,.025)
block('Seat_base',(0,5.742,-3.161),(.587,.154,.478),'graphite',ride,.050)
back=block('Seat_back',(0,6.043,-2.930),(.553,.552,.119),'slate_panel',ride,.047)
block('Harness_buckle',(0,5.821,-3.26),(.082,.063,.123),'orange',ride,.012)
for s in (-1,1):
    rod('Seat_support',(s*.21,5.382,-3.38),(s*.20,5.724,-3.03),.034,'alloy',ride)
block('Readout_mount_post',(0,5.813,-3.984),(.109,.858,.142),'dark_alloy',ride,.022)
block('Readout_front_case',(0,6.260,-4.003),(.499,.314,.091),'rover_white',ride,.022,.041)
block('Readout_rubber_bezel',(0,6.260,-3.967),(.453,.275,.030),'black_rubber',ride,.009)
glass_quad('DeckScreen',(0,6.26,-3.95),.416,.234,ride)

# Optical mast and separate light attachment markers for the paired headlights.
mast=anchor('CameraMast',(3.31,5.60,-4.97),body)
cyl('Mast_elevation_column',(3.31,6.106,-4.97),.088,1.108,'rover_white',mast)
for h in (5.671,6.308):
    cyl('Mast_lock_ring',(3.31,h,-4.97),.119,.075,'orange',mast,n=30)
block('Sensor_head',(3.31,6.687,-4.97),(.522,.207,.258),'rover_white',mast,.035)
for x in (3.176,3.448):
    cyl('Sensor_housing',(x,6.689,-5.104),.080,.076,'dark_alloy',mast,(0,0,-1),32)
    cyl('Navigation_optic',(x,6.689,-5.148),.051,.018,'dark_glass',mast,(0,0,-1),34)
lamp=anchor('Lamp',(3.31,6.886,-4.97),mast)
cyl('Lamp_sealed_foot',(3.31,6.852,-4.97),.093,.056,'graphite',lamp,n=30)
cyl('lamp_glow_lamp_amber',(3.31,6.898,-4.97),.074,.075,'lamp_amber',lamp,n=36,exact=True)
cyl('Beacon_glare_cap',(3.31,6.949,-4.97),.095,.028,'alloy',lamp,n=32)
for s,name in [(-1,'L'),(1,'R')]:
    anchor('Headlamp_'+name,(s*2.,5.2,-5.62),body)
    block('Headlamp_impact_housing',(s*2.,5.205,-5.528),(.437,.241,.210),'graphite',body,.026,.036)
    block('Headlamp_lens',(s*2.,5.204,-5.627),(.325,.141,.032),'lamp_white',body,.015,.025)

# The core carries its own origin at its floor, independent of the moving frame.
block('General_Module_outer_shell',(0,2.90,0),(6.,3.30,9.0),'rover_white',module,.112,.198)
block('Graphite_touchdown_skirt',(0,1.406,0),(5.999,.311,8.996),'graphite',module,.067,.195)
for s in (-1,1):
    for z in (-4.155,-3.06,-1.96,.45,1.72,2.86,4.155):
        block('Pressed_side_panel_joint',(s*2.997,3.03,z),(.019,2.868,.039),'slate_panel',module,.008)
    for z in (-3.84,-1.61,1.93,3.81):
        block('Longitudinal_shell_load_rib',(s*2.981,2.967,z),(.079,2.64,.097),'white_painted',module,.025)
    for z in (-4.13,-2.53,-.88,.88,2.53,4.13):
        block('Skirt_replaceable_shoe',(s*2.973,1.474,z),(.086,.178,.443),'dark_alloy',module,.030)
    sweep('Weather_seam_trim',[(s*2.997,4.362,z) for z in (-4.24,-3.00,0,3,4.24)],.022,'graphite',module)
for z in (-4.481,4.481):
    for x in (-2.47,-1.254,0,1.254,2.47):
        block('Transverse_shell_forming_rib',(x,2.945,z),(.082,2.236,.062),'white_painted',module,.023)
    for x in (-2.38,2.38):
        block('Module_corner_impact_block',(x,1.597,z),(.199,.223,.090),'warm_panel',module,.022)
for x in (-2.6,2.6):
    for z in (-4.0,4.0):
        block('Lift_load_spreader',(x,4.507,z),(.391,.064,.438),'alloy',module,.022)
        sweep('Forged_lifting_lug',[(x-.091,4.536,z),(x-.091,4.604,z),
                (x-.060,4.667,z),(x+.060,4.667,z),(x+.091,4.604,z),(x+.091,4.536,z)],
              .026,'satin_steel',module)
        for t in (-.124,.124):
            bolt('Lift_spreader_captive_bolt',(x+t,4.547,z),(0,1,0),.019,module)
for x in (-1.89,0,1.89):
    block('Roof_stiffener',(x,4.526,0),(.132,.089,7.04),'white_painted',module,.020)
# Airlock hatch and folded fabric kit on +X, inside the frame opening.
block('Hatch_rim',(3.030,2.730,-.71),(.142,2.08,1.537),'graphite',module,.044,.085)
block('Pressed_pressure_hatch',(3.117,2.725,-.710),(.095,1.859,1.323),'rover_white',module,.031,.077)
cyl('Hatch_porthole_housing',(3.180,3.091,-.710),.252,.049,'dark_alloy',module,(1,0,0),40)
cyl('Hatch_porthole_glass',(3.207,3.091,-.710),.190,.012,'dark_glass',module,(1,0,0),40)
for yy in (2.14,3.27):
    cyl('Hatch_pin',(3.183,yy,-1.35),.049,.231,'satin_steel',module)
rod('Pressure_latch',(3.19,2.493,-.241),(3.19,2.493,-.444),.031,'orange',module)
block('Airlock_transport_tray',(3.036,2.716,1.242),(.123,.879,1.431),'graphite',module,.027)
for i in range(5):
    block('Folded_airlock_fabric_layer',(3.125,2.716+i*.112-.225,1.242),(.209,.108,1.268),
          'warm_shell' if i%2==0 else 'slate_panel',module,.034,.045)
for z in (.855,1.629):
    sweep('Airlock_webbing',[(3.029,2.334,z),(3.205,2.355,z),(3.253,2.505,z),
                           (3.253,2.957,z),(3.188,3.090,z),(3.008,3.091,z)],.024,'black_rubber',module)
    block('Airlock_buckle',(3.251,2.768,z),(.058,.128,.095),'orange',module,.014)

# Cantilever winches withdraw outside the module footprint before the kneel.
for i,(x,z) in enumerate([(-2.6,-4.0),(2.6,-4.0),(-2.6,4.0),(2.6,4.0)],1):
    s=1 if x>0 else -1
    winch=anchor(f'WinchArm_{i}',(x,4.985,z),body)
    block('Winch_track_bearer',(s*3.826,5.032,z),(.60,.217,.373),'dark_alloy',body,.024)
    rod('Winch_cantilever_track',(x,5.068,z),(s*4.023,5.068,z),.071,'alloy',winch)
    block('Winch_motor_shield',(x,5.076,z),(.371,.243,.353),'graphite',winch,.029)
    cyl('Winch_drum',(x,5.029,z),.104,.239,'satin_steel',winch,(1,0,0),28)
    for s2 in (-1,1):
        cyl('Winch_flange',(x+s2*.133,5.029,z),.143,.035,'orange',winch,(1,0,0),28)
    cable=anchor(f'Cable_{i}',(x,4.985,z),winch)
    cyl('Braided_winch_line',(x,4.485,z),.018,1.0,'black_rubber',cable,(0,1,0),16,.0)

# Ladder sections slide along the pitched rails, with a hinged bottom heel.
def rail_z(y):
    return 7.40-(1.66/5.51)*y

for index,(top,bottom) in enumerate([(5.51,3.90),(4.033,2.04),(2.165,.30)],1):
    group=anchor(f'Ladder_{index}',(0,top,rail_z(top)),body)
    width=(.79,.69,.59)[index-1]
    for s in (-1,1):
        rod('Ladder_slide_stile',(s*width/2,bottom,rail_z(bottom)),
            (s*width/2,top,rail_z(top)),.038 if index==1 else .031,'satin_steel',group)
    for y in [bottom+.18+q*.294 for q in range(int((top-bottom-.18)/.294)+1)]:
        tread=block('Knurled_ladder_rung',(0,y,rail_z(y)),(width,.062,.126),'alloy',group,.013)
        for s in (-1,1):
            bolt('Rung_end_retainer',(s*width*.437,y+.033,rail_z(y)),(0,1,0),.013,group)
    for s in (-1,1):
        block('Telescoping_guide_block',(s*width/2,top-.051,rail_z(top-.051)),(.128,.151,.128),'graphite',group,.018)
    if index==3:
        heel=anchor('LadderShoe',(0,.30,rail_z(.30)),group)
        for s in (-1,1):
            rod('Ladder_fold_out_ground_heel',(s*.292,.30,rail_z(.30)),(s*.303,.058,7.4),.033,'alloy',heel)
            block('Ladder_ground_pad',(s*.303,.033,7.4),(.148,.066,.17),'black_rubber',heel,.016)

# The power tray remains at ground work height while the strut retracts.
strut=anchor('BerthStrut',(-3.60,.35,.15),berth)
for z in (-.311,.631):
    rod('Power_berth_telescoping_support',(-3.60,.372,z),(-3.60,4.971,z),.052,'alloy',strut)
    block('Berth_strut_guide',(-3.60,4.918,z),(.227,.201,.191),'dark_alloy',body,.025)
for x in (-3.841,-3.359):
    block('Power_runner_rail',(x,.313,.124),(.106,.074,1.118),'alloy',berth,.021)
    for z in (-.325,.572):
        bolt('Tray_runner_pin',(x,.346,z),(0,1,0),.012,berth)
block('Berth_cross_member',(-3.6,.293,.41),(.778,.113,.197),'graphite',berth,.020)
psx,psy,psz=-3.60,.618,.649
anchor('PowerSocket',(psx,psy,psz),berth)
block('Black_connector_backplate',(psx,psy,psz+.088),(.585,.379,.138),'graphite',berth,.023)
def power_rim():
    outer=f.octagon(.58,.373,.057)
    inner=f.octagon(.48,.273,.023)
    # Front-facing mating plane at z=0.649, collar recessed behind it.
    pts=[v((psx+u,psy+w,z)) for z,path in [(psz+.014,outer),(psz+.014,inner),
                                           (psz+.071,outer),(psz+.071,inner)] for u,w in path]
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,j+8,i+8),(i,i+16,j+16,j),(i+8,j+8,j+24,i+24),(i+16,i+24,j+24,j+16)])
    mesh('Keyed_receiver_surround',pts,faces,'orange',berth,.009)
power_rim()
for dx in (-.071,0,.069):
    cyl('Receiver_window_contact',(psx+dx,psy-.011,psz+.019),.018,.019,'satin_steel',berth,(0,0,-1),22)

# Positive local X is the flex axis. Each leg plane is turned outboard around
# the vehicle's vertical axis, while Wheel_n stays aligned to vehicle X.
hip_y,l1,l2=5.05,3.0,3.10
for s in (-1,1):
    plane=Matrix((Vector((0,s,0)),Vector((0,0,1)),Vector((s,0,0)))).transposed()
    for j,z in enumerate((-5.,0.,5.),1):
        i=j+(3 if s>0 else 0)
        hip_x=s*4.10
        knee_x=hip_x+s*l1
        wheel_x=knee_x+s*l2
        hip=anchor(f'Hip_{i}',(hip_x,hip_y,z),body,plane)
        knee=anchor(f'Knee_{i}',(knee_x,hip_y,z),hip,plane)
        carrier=anchor(f'AxleCarrier_{i}',(wheel_x,hip_y,z),knee)
        wheel=anchor(f'Wheel_{i}',(wheel_x,hip_y,z),carrier)
        for group,start,length,thick in [(hip,hip_x,l1,.54),(knee,knee_x,l2,.437)]:
            stop=start+s*length
            mid=(start+stop)*.5
            block('Machined_structural_link',(mid,hip_y,z),(length-.317,.344,thick),'rover_white',group,.048,.095)
            block('Structural_channel',(mid,hip_y+.173,z),(length*.69,.054,thick*.55),
                  'graphite',group,.019,.037)
            for ratio in (.27,.46,.69):
                block('Link_cross_member',(start+s*length*ratio,hip_y+.208,z),(.134,.060,thick*.76),'alloy',group,.015)
            for sign in (-1,1):
                side_z=z+sign*(thick*.55)
                rod('Hydraulic_cylinder',(start+s*.208,hip_y-.187,side_z),
                    (start+s*length*.64,hip_y-.179,side_z),.132,'dark_alloy',group)
                rod('Brushed_piston_rod',(start+s*length*.57,hip_y-.179,side_z),
                    (stop-s*.116,hip_y-.170,side_z),.066,'satin_steel',group)
            sweep('Service_cable_guard',[(start+s*.07,hip_y+.095,z-.113),
                (start+s*.37,hip_y+.279,z-.303),(mid,hip_y+.274,z-.313),
                (stop-s*.41,hip_y+.265,z-.266),(stop-s*.05,hip_y+.082,z-.120)],.039,'black_rubber',group)
            for ratio in (.27,.69):
                block('Line_clamp',(start+s*length*ratio,hip_y+.275,z-.284),(.105,.096,.105),'orange',group,.016)
        for node,px,r in ((hip,hip_x,.287),(knee,knee_x,.269)):
            cyl('Articulation_pin_body',(px,hip_y,z),r,.665,'dark_alloy',node,(0,0,1),40,.024)
            for sign in (-1,1):
                cyl('Pin_retention_plate',(px,hip_y,z+sign*.349),r*.83,.066,'satin_steel',node,(0,0,sign),36,.013)
                for angle in range(6):
                    a=angle*pi/3
                    bolt('Hinge_keeper_bolt',(px+r*.63*cos(a),hip_y+r*.63*sin(a),z+sign*.388),
                         (0,0,sign),.023,node)
        block('Spindle_upright',(wheel_x-s*.189,hip_y+.207,z),(.272,.599,.340),'white_painted',carrier,.041)
        block('Spindle_impact_guard',(wheel_x-s*.137,hip_y+.400,z),(.305,.163,.379),'orange',carrier,.024)
        cyl('Wheel_compliant_tyre',(wheel_x,hip_y,z),.585,.330,'black_rubber',wheel,(1,0,0),56,.048)
        for k in range(24):
            a=k*pi/12
            for row in (-1,1):
                rad=.580
                angle=a+row*.033
                c=(wheel_x+row*.089,hip_y+rad*cos(angle),z+rad*sin(angle))
                tread=block('Replaceable_tread_lug',c,(.148,.080,.126),'black_rubber',wheel,.017,.027)
                tread.rotation_euler.x=angle
        for sign in (-1,1):
            px=wheel_x+sign*.160
            cyl('Wheel_hub_bead',(px,hip_y,z),.382,.057,'dark_alloy',wheel,(sign,0,0),42,.016)
            cyl('Wheel_machined_hub',(px+sign*.033,hip_y,z),.297,.031,'alloy',wheel,(sign,0,0),42,.013)
            cyl('Wheel_axle_core',(px+sign*.050,hip_y,z),.159,.021,'graphite',wheel,(sign,0,0),36)
            for k in range(8):
                a=k*pi/4
                bolt('Hub_captive_fastener',(px+sign*.054,hip_y+.233*cos(a),z+.233*sin(a)),
                     (sign,0,0),.019,wheel)
        if i==1:
            cyl('SealRing',(wheel_x+s*.218,hip_y,z),.179,.021,'black_rubber',wheel,(s,0,0),40,.004,exact=True)
            cyl('Fault_hub_axle_face',(wheel_x+s*.232,hip_y,z),.125,.020,'satin_steel',wheel,(s,0,0),36)

# A few chips at working edges affect the solid paint while the maps carry dust.
wear(frame,(0,5.308,-5.600),(1,0,0),(0,0,-1),(3.7,.21),(.007,.042),123,521)
f.uv_maps(list(f.collection.objects),scale=1.14)
from walker_pose import apply_pose
apply_pose('standing',unit_cables=True)
f.save_and_export(package,'Walker_1',view_at=(0,2.85,0),view_distance=19,pose=apply_pose,compact=True)
