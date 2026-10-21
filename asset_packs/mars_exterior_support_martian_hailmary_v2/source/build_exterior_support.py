"""Original surface operations supporting assets for Mars Habitat / Godot 4.
All Y-up, forward -Z, dimensions in metres, floor origin. Each part is attached
by explicit joints/struts/latches rather than unsupported visual floats.
Run: python source/build_exterior_support.py
"""
import math,json
from pathlib import Path
import numpy as np
import trimesh
from geometry_core import Model,ROOT

P=ROOT

def rail(a, name, mat, x1,y1,z1,x2,y2,z2,r=.022):
 a.bar(name,mat,(x1,y1,z1),(x2,y2,z2),r,sections=12)

def bezel(a,node,x,y,z,w,h,th=.025,color='dark_alloy'):
 for xx in (x-w/2,x+w/2):a.box(node,color,(th,h,th),(xx,y,z))
 for yy in (y-h/2,y+h/2):a.box(node,color,(w+th,th,th),(x,yy,z))

def mount_bolt(a,x,y,z,axis='z',node='mount_bolts'):
 a.cyl(node,'satin_steel',.014,.012,(x,y,z),axis=axis,sections=10)

def dish_mesh(radius=.52,deep=.165,steps=40,rings=9):
 # Parabolic dish, opens towards -Z. solid back and concave face held by rim.
 verts=[];faces=[]
 for layer in (0,1):
  for i in range(rings+1):
   r=radius*i/rings
   z=(deep*(1-(i/rings)**2)) +(.016 if layer==1 else 0)
   for j in range(steps):
    t=2*math.pi*j/steps
    verts.append([r*math.cos(t), r*math.sin(t),z])
 off=(rings+1)*steps
 for i in range(rings):
  for j in range(steps):
   j2=(j+1)%steps
   a=i*steps+j;b=i*steps+j2;c=(i+1)*steps+j;d=(i+1)*steps+j2
   faces.extend([(a,c,b),(b,c,d)])
   aa=off+a;bb=off+b;cc=off+c;dd=off+d
   faces.extend([(aa,bb,cc),(bb,dd,cc)])
 for j in range(steps):
  j2=(j+1)%steps
  a=rings*steps+j;b=rings*steps+j2
  faces.extend([(a,b,b+off),(a,b+off,a+off)])
 m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
 return m

def mast():
 a=Model('exterior_comms_mast')
 # Low wide tripod, compact reinforced mast with a functional antenna carriage
 a.cyl('central_foot','black_rubber',.32,.045,(0,.035,0),sections=32)
 a.cyl('base_socket','alloy',.19,.20,(0,.16,0),sections=28)
 for i in range(3):
  t=2*math.pi*i/3+.30;x,z=math.cos(t),math.sin(t)
  a.bar('tripod_struts','satin_steel',(0,.35,0),(x*.92,.16,z*.92),.042,sections=14)
  a.bar('tripod_braces','dark_alloy',(0,.87,0),(x*.72,.28,z*.72),.025,sections=12)
  a.box('tripod_foot','black_rubber',(.24,.065,.23),(x*.95,.042,z*.95))
  a.cyl('tripod_foot_clamp','orange',.055,.045,(x*.92,.16,z*.92),sections=16)
 # aligned truss sections with real junctions
 a.cyl('telescopic_main','alloy',.093,2.57,(0,1.60,0),sections=20)
 a.cyl('telescopic_inner','satin_steel',.067,1.38,(0,3.43,0),sections=20)
 for y in (.55,1.35,2.14,2.85):
  a.cyl('mast_collars','dark_alloy',.12,.078,(0,y,0),sections=24)
  for ang in (0,math.pi/2):
   a.box('mast_clamps','satin_steel',(.21,.028,.08) if ang==0 else (.08,.028,.21),(0,y,0))
 # antenna offset carriage 1.5m up, dish faces -Z
 a.box('dish_yoke','dark_alloy',(.52,.10,.16),(.06,2.69,-.22))
 a.bar('dish_yoke','alloy',(.05,2.68,-.19),(.05,2.70,-.46),.061,sections=18)
 for x in (-.21,.21):rail(a,'dish_brackets','satin_steel',x,2.68,-.30,x,2.83,-.40,.026)
 d=dish_mesh(radius=.47,deep=.13)
 d.apply_transform(trimesh.transformations.rotation_matrix(math.pi,[0,1,0]))
 d.apply_translation([.05,2.74,-.54])
 a.add('dish_reflector','white_painted',d)
 a.ring('dish_rim','satin_steel',.484,.469,.022,(.05,2.74,-.54),axis='z',sections=44)
 # feed horn on 3 permanently connected bracing rods, no floating pickup
 a.cyl('receiver_feed','dark_alloy',.052,.10,(.05,2.74,-.84),axis='z',sections=16)
 for angle in (0,2*math.pi/3,4*math.pi/3):
  x=.05+.43*math.cos(angle);y=2.74+.43*math.sin(angle)
  rail(a,'receiver_struts','dark_alloy',x,y,-.54,.05,2.74,-.85,.012)
 # telemetry whip and panel antennas mechanically fixed to mast
 a.cyl('top_beacon','orange',.073,.065,(0,4.18,0),sections=16)
 a.cyl('top_beacon','light_diffuser',.055,.065,(0,4.22,0),sections=14)
 a.bar('antenna_whip','satin_steel',(0,4.2,0),(0,4.75,0),.012)
 for x in (-.37,.37):
  a.box('side_panel_mounts','dark_alloy',(.40,.055,.07),(x,3.52,-.06))
  a.box('side_survey_panels','white_ceramic',(.29,.46,.045),(x,3.59,-.10))
  for k in range(3):a.box('side_panel_ribs','alloy',(.24,.012,.05),(x,3.41+k*.17,-.125))
 # lower electronics: mounted to rail, sun shields, power/instrument connectors
 a.box('mast_electronics','white_ceramic',(.42,.43,.27),(.20,1.06,-.21))
 a.box('electronic_seal','dark_alloy',(.36,.30,.025),(.20,1.07,-.365))
 for x in (.07,.33):
  a.cyl('signal_port','teal',.025,.025,(x,1.14,-.38),axis='z',sections=14)
  a.cyl('signal_port','amber_glow',.019,.015,(x,1.04,-.38),axis='z',sections=14)
 a.hose('power_cable','rubber_gasket',[(.26,.88,-.24),(.26,.65,-.24),(.10,.50,-.13),(0,.32,0)],.018,sections=10)
 a.hose('antenna_cable','rubber_gasket',[(.12,1.26,-.26),(.14,2.50,-.12),(.07,2.68,-.37),(.05,2.74,-.75)],.012,sections=10)
 return a.finish()

def workbench():
 a=Model('exterior_workbench')
 # Welded frame, chassis, worktop and wind/dust shield. Front toward -Z.
 for x in (-.74,.74):
  for z in (-.32,.32):
   a.box('bench_frame','satin_steel',(.068,.91,.077),(x,.49,z))
   a.box('rubber_foot','black_rubber',(.11,.044,.12),(x,.033,z))
 for z in (-.32,.32):
  for y in (.22,.91):a.box('bench_frame','alloy',(1.55,.058,.06),(0,y,z))
 for x in (-.74,.74):
  a.box('bench_frame','alloy',(.068,.058,.72),(x,.91,0))
  rail(a,'corner_braces','dark_alloy',x,.36,-.30,x-.18*(1 if x>0 else -1),.85,-.30,.027)
 a.box('worktop_core','dark_alloy',(1.73,.105,.86),(0,1.02,0))
 a.box('worktop_surface','satin_steel',(1.68,.038,.80),(0,1.096,-.005))
 for x in (-.84,.84):a.box('worktop_trim','white_painted',(.035,.10,.90),(x,1.03,0))
 # Rear weather hood: roof with 2 triangular braces, backboard
 a.box('splash_plate','white_ceramic',(1.67,.46,.055),(0,1.38,.40))
 for x in (-.76,.76):
  a.box('weather_support','alloy',(.042,.53,.08),(x,1.39,.37))
  a.bar('weather_support','dark_alloy',(x,1.62,.40),(x,1.78,.19),.019)
 a.box('weather_shelter','white_painted',(1.80,.065,.45),(0,1.80,.22))
 a.box('weather_lip','black_rubber',(1.80,.032,.030),(0,1.76,-.005))
 # lockable bottom drawers and support rails visible
 a.box('storage_cabinet','white_ceramic',(.85,.55,.62),(-.25,.55,.01))
 for i in range(3):
  yy=.42+i*.17
  a.box('drawer_rail','dark_alloy',(.74,.145,.018),(-.25,yy,-.316))
  a.box('drawer_front','warm_panel',(.69,.117,.025),(-.25,yy,-.333))
  a.box('drawer_handle','satin_steel',(.19,.021,.029),(-.25,yy,-.352))
 for x in (-.59,.09):
  for yy in (.42,.59,.76):mount_bolt(a,x,yy,-.35)
 a.box('lower_shelf','dark_alloy',(1.50,.050,.58),(0,.27,.07))
 a.box('service_crate','olive',(.42,.30,.41),(.47,.47,.045))
 a.box('service_crate_lid','satin_steel',(.44,.038,.43),(.47,.64,.045))
 # working vise on top, physically bolted to workbench
 a.box('vise_base','dark_alloy',(.28,.10,.22),(.48,1.17,-.14))
 for x in (.37,.59):a.box('vise_jaw','satin_steel',(.053,.17,.22),(x,1.27,-.14))
 a.cyl('vise_screw','dark_alloy',.024,.37,(.60,1.26,-.14),axis='x',sections=16)
 a.cyl('vise_handle','orange',.018,.25,(.77,1.25,-.14),axis='y',sections=12)
 # bolted tool rail with hooks and distinctly supported wrenches
 a.box('tool_mount_rail','dark_alloy',(1.38,.057,.052),(0,1.50,.346))
 for x in (-.58,-.30,-.02,.28):
  a.bar('tool_hooks','satin_steel',(x,1.49,.34),(x,1.49,.28),.010)
  a.box('hanging_tool_shaft','alloy',(.046,.26,.03),(x,1.34,.26))
  a.box('hanging_tool_grip','black_rubber',(.059,.105,.041),(x,1.30,.26))
  if x<-.2:
   a.ring('wrench_head','satin_steel',.059,.028,.022,(x,1.50,.26),axis='z',sections=16)
  else:a.box('tool_head','satin_steel',(.13,.037,.04),(x,1.49,.26))
 # right-mounted power bay, actual brackets connecting to frame
 a.box('service_power_box','white_ceramic',(.23,.28,.20),(.71,1.40,.36))
 a.box('service_power_panel','dark_alloy',(.16,.20,.012),(.71,1.40,.244))
 a.cyl('power_switch','orange',.030,.033,(.71,1.44,.229),axis='z',sections=14)
 a.cyl('power_indicator','bright_green',.017,.012,(.71,1.37,.231),axis='z',sections=12)
 a.hose('power_cable','rubber_gasket',[(.71,1.27,.36),(.75,1.12,.36),(.72,.92,.31)],.012)
 return a.finish()

def crate(name,width,depth,height):
 a=Model(name)
 # Heavy rugged moulded case, raised base, chamfer-like multi-layer silhouette.
 w,d,h=width,depth,height
 a.box('case_inner','dark_alloy',(w-.13,h-.15,d-.13),(0,.12+(h-.15)/2,0))
 a.box('case_shell','white_ceramic',(w-.035,h-.12,d-.035),(0,.105+(h-.12)/2,0))
 a.box('upper_lid','warm_panel',(w+.02,.070,d+.02),(0,h-.068,0))
 a.box('lid_gasket','black_rubber',(w+.025,.024,d+.025),(0,h-.114,0))
 for x in (-w/2+.050,w/2-.050):
  a.box('vertical_frame','alloy',(.050,h-.11,.055),(x,.085+(h-.11)/2,-d/2+.04))
  a.box('vertical_frame','alloy',(.050,h-.11,.055),(x,.085+(h-.11)/2,d/2-.04))
 for z in (-d/2+.045,d/2-.045):
  for y in (.14,h-.14):a.box('case_struts','satin_steel',(w-.045,.040,.049),(0,y,z))
 for x in (-w*.35,w*.35):
  a.box('liftable_handles','dark_alloy',(.22,.13,.055),(x,h*.56,-d/2-.008))
  a.bar('liftable_handles','satin_steel',(x-.075,h*.57,-d/2-.047),(x+.075,h*.57,-d/2-.047),.017)
 # latches on front, hinge-blocks at back, collars are physically coupled
 for x in (-w*.31,w*.31):
  a.box('lid_latches','dark_alloy',(.13,.115,.05),(x,h-.12,-d/2-.015))
  a.box('lid_latches','orange',(.065,.043,.052),(x,h-.09,-d/2-.045))
  a.cyl('rear_hinge','satin_steel',.023,.115,(x,h-.105,d/2+.028),axis='x',sections=12)
 for x in (-w*.36,w*.36):
  for z in (-d*.33,d*.33):a.box('stacking_feet','black_rubber',(.13,.041,.13),(x,.028,z))
 # two recessed label holders with blank face, never reversed text
 a.box('blank_identification_holder','dark_alloy',(w*.27,.11,.008),(0,.26,-d/2-.020))
 a.box('blank_identification_insert','teal_soft',(w*.23,.070,.010),(0,.26,-d/2-.027))
 return a.finish()

def pallet():
 a=Model('exterior_cargo_pallet')
 # deep transport pallet with real forklift gaps and corner retention anchors
 W=1.68;D=1.30
 for x in (-.67,0,.67):
  a.box('forklift_skids','dark_alloy',(.25,.18,D),(x,.105,0))
  a.box('skid_wear_strips','satin_steel',(.26,.035,D),(x,.206,0))
 for z in (-.54,-.25,.04,.33,.58):
  a.box('deck_slats','warm_panel',(W,.066,.22),(0,.26,z))
 for x in (-.81,.81):
  a.box('rim_rails','alloy',(.058,.13,D),(x,.265,0))
  for z in (-.53,.53):
   a.box('tie_down_anchors','dark_alloy',(.115,.13,.16),(x,.36,z))
   a.ring('tie_down_loops','satin_steel',.061,.039,.022,(x,.42,z),axis='z',sections=16)
 # supported nested cases (visible separate pieces), retaining straps wrap over cases
 for i,(x,z,w,h,d) in enumerate([(-.44,-.25,.67,.62,.60),(.36,-.25,.79,.79,.62),(-.42,.40,.71,.44,.52),(.39,.40,.74,.46,.53)]):
  y=.305+h/2
  a.box('cargo_case_body','white_ceramic',(w,h-.055,d),(x,y,z))
  a.box('cargo_case_lid','warm_panel',(w+.013,.060,d+.015),(x,.305+h-.028,z))
  a.box('cargo_case_gasket','black_rubber',(w+.02,.018,d+.016),(x,.305+h-.066,z))
  for xx in (x-w*.43,x+w*.43):
   a.box('cargo_case_frame','satin_steel',(.036,h-.10,.042),(xx,.35+(h-.10)/2,z-d/2+.03))
  a.box('cargo_case_latch','orange',(.075,.082,.024),(x,.305+h-.074,z-d/2-.016))
 # Cargo retention: each strap rests on its own box lid and connects to fixed deck anchors.
 for x,z,w,h,d in [(-.44,-.25,.67,.62,.60),(.36,-.25,.79,.79,.62),(-.42,.40,.71,.44,.52),(.39,.40,.74,.46,.53)]:
  top=.305+h+.010
  a.box('pallet_straps','teal',(.034,.020,d+.035),(x,top,z))
  for edge in (-1,1):
   zz=z+edge*(d/2+.012)
   a.box('pallet_straps','teal',(.034,(top-.385),.022),(x,(top+.385)/2,zz))
  a.box('ratchet_housing','dark_alloy',(.11,.105,.055),(x,.415,z-d/2-.03))
  a.cyl('ratchet_lever','orange',.020,.09,(x,.47,z-d/2-.068),axis='y',sections=12)
 return a.finish()

def barrier():
 a=Model('exterior_safety_barrier')
 # heavy but portable rigid 1.62m safety fence, with actual feet/crossbars
 for x in (-.75,.75):
  a.box('posts','satin_steel',(.068,.94,.076),(x,.51,0))
  a.box('weighted_feet','black_rubber',(.28,.086,.46),(x,.067,0))
  a.box('foot_collar','orange',(.115,.09,.12),(x,.155,0))
  for y in (.20,.80):
   rail(a,'support_braces','dark_alloy',x,y,0,x+( .12 if x<0 else -.12),.13,-.21,.019)
 for y in (.23,.88):a.box('cross_rails','alloy',(1.52,.053,.060),(0,y,0))
 # panel inset with alternating geometric hazard blocks, no label textures
 a.box('panel_frame','dark_alloy',(1.35,.48,.040),(0,.55,-.025))
 a.box('panel_insert','white_painted',(1.27,.40,.020),(0,.55,-.051))
 for i in range(8):
  x=-.54+i*.155
  a.box('reflective_segments','orange',(.078,.17,.010),(x,.55,-.067))
 for x in (-.65,.65):
  for y in (.34,.75): mount_bolt(a,x,y,-.066)
 # lightweight top beacon with a real support base
 a.cyl('barrier_light_socket','dark_alloy',.08,.065,(-.75,1.02,0),sections=18)
 a.cyl('barrier_light_diffuser','amber_glow',.06,.075,(-.75,1.09,0),sections=18)
 return a.finish()

def hazard_marker():
 a=Model('exterior_hazard_bollard')
 a.box('anchored_base','black_rubber',(.35,.09,.35),(0,.055,0))
 a.box('base_plate','dark_alloy',(.29,.055,.29),(0,.125,0))
 for x in (-.105,.105):
  for z in (-.105,.105):mount_bolt(a,x,.166,z,axis='y')
 a.cyl('bollard_post','white_painted',.076,.72,(0,.52,0),sections=20)
 for y in (.34,.56,.77):a.cyl('visibility_band','orange',.079,.052,(0,y,0),sections=20)
 a.cyl('top_light_socket','dark_alloy',.11,.055,(0,.91,0),sections=20)
 a.cyl('top_light_diffuser','light_diffuser',.078,.080,(0,.974,0),sections=18)
 a.cyl('top_guard','satin_steel',.11,.030,(0,1.023,0),sections=20)
 return a.finish()

def beacon():
 a=Model('exterior_path_beacon')
 a.box('ground_foot','black_rubber',(.37,.07,.37),(0,.043,0))
 a.box('metal_base','satin_steel',(.30,.060,.30),(0,.105,0))
 for x in (-.12,.12):
  for z in (-.12,.12):mount_bolt(a,x,.138,z,axis='y')
 a.cyl('beacon_mast','white_painted',.056,.74,(0,.47,0),sections=18)
 a.cyl('beacon_lower_collars','dark_alloy',.075,.057,(0,.23,0),sections=18)
 a.cyl('beacon_upper_collars','dark_alloy',.076,.055,(0,.84,0),sections=18)
 a.box('beacon_lamp_body','white_ceramic',(.25,.25,.22),(0,.95,-.005))
 for x in (-.105,.105):a.box('beacon_lamp_protective_cage','satin_steel',(.022,.22,.235),(x,.95,0))
 for z in (-.107,.107):a.box('beacon_lamp_protective_cage','satin_steel',(.24,.22,.022),(0,.95,z))
 a.box('beacon_light_diffuser','light_diffuser',(.175,.152,.018),(0,.95,-.122))
 a.box('beacon_solar_tile','teal',(.17,.018,.13),(0,1.088,.015))
 for x in (-.05,.05):a.box('solar_cell_seams','black_rubber',(.008,.020,.130),(x,1.099,.015))
 a.box('beacon_cap','warm_panel',(.27,.035,.25),(0,1.119,0))
 return a.finish()

if __name__=='__main__':
 records=[]
 for fn in [mast,workbench,pallet,lambda:crate('exterior_cargo_crate_large',.98,.72,.68),lambda:crate('exterior_cargo_crate_small',.62,.47,.43),barrier,hazard_marker,beacon]:
  rec=fn();records.append(rec)
  print(rec['id'],rec['triangles'],rec['mesh_groups'],rec['dimensions_xyz_m'],flush=True)
 (P/'asset_manifest.json').write_text(json.dumps({'version':'2.0','style':'Bright The Martian / Project Hail Mary inspired original assets','scale':'1 Godot unit = 1m, Y up, -Z forward, ground origin','assets':records},indent=2))
