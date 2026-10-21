"""Two independently editable, original high-detail exterior Mars habitat machines.
Shared styling with interior: off-white engineering shells, aluminium, teal service lines, orange safety hardware.
Each machine is non-functional art with component names for Godot.
"""
from pathlib import Path
import math,json
import numpy as np
import trimesh
from geometry_core import Model,ROOT

def helix_flight(turns=5.5, outer=.135, inner=.048, height=1.42, width=.018, x=-.35,z=-.10,y0=.46):
    sections=int(turns*32)
    vertices=[]
    for i in range(sections+1):
        t=2*math.pi*turns*i/sections
        h=height*i/sections+y0
        for rr,dy in [(inner,-width/2),(outer,-width/2),(outer,width/2),(inner,width/2)]:
            vertices.append([x+rr*math.cos(t),h+dy,z+rr*math.sin(t)])
    faces=[]
    for j in range(sections):
        k=4*j;l=4*(j+1)
        for a,b in ((0,1),(1,2),(2,3),(3,0)):
            faces.extend([[k+a,k+b,l+b],[k+a,l+b,l+a]])
    faces.extend([[0,1,2],[0,2,3],[4*sections,4*sections+2,4*sections+1],[4*sections,4*sections+3,4*sections+2]])
    return trimesh.Trimesh(vertices=vertices,faces=faces,process=True)

def drill():
 a=Model('exterior_ice_water_drill')
 # broad sled undercarriage, feet, level pads, bolts
 for x in (-.85,.85):
  a.box('base_skids','dark_alloy',(.205,.16,1.50),(x,.10,0))
  a.box('skid_overlay','satin_steel',(.23,.055,1.40),(x,.20,0))
  for z in (-.60,.60):
   a.box('skid_stabilizers','black_rubber',(.24,.045,.28),(x,.025,z))
 for z in (-.58,.58):a.box('cross_base','satin_steel',(1.73,.105,.12),(0,.24,z))
 a.box('equipment_deck','white_painted',(2.12,.165,1.32),(0,.335,0))
 for x in (-1.07,1.07):a.box('deck_edge','alloy',(.035,.15,1.30),(x,.34,0))
 # mast and cross bracing with skid mounts
 for x in (-.58,-.12):
  a.box('drill_mast','alloy',(.083,2.10,.11),(x,1.34,-.1))
  for y in (.64,1.34,2.03):a.box('mast_slide_blocks','dark_alloy',(.14,.095,.15),(x,y,-.125))
 for y in (.52,2.38):a.box('mast_crossbar','satin_steel',(.62,.075,.13),(-.35,y,-.10))
 for x in (-.58,-.12):
  a.bar('mast_braces','dark_alloy',(x,.40,.50),(x,1.71,-.07),.026,sections=16)
  a.box('base_bracket','alloy',(.16,.13,.16),(x,.42,.43))
 # drill motor + guide carriage
 a.box('motor_carriage','dark_alloy',(.54,.43,.43),(-.35,2.19,-.08))
 a.box('motor_shroud','white_ceramic',(.60,.42,.45),(-.35,2.43,-.08))
 for z in (-.315,.155):a.box('motor_safety_lip','satin_steel',(.62,.042,.05),(-.35,2.60,z))
 for i in range(7):
  a.box('motor_vents','dark_alloy',(.038,.22,.01),(-.55+i*.067,2.41,-.313))
 a.cyl('motor_coupling','orange',.135,.17,(-.35,2.115,-.10),sections=30)
 a.cyl('drill_shaft','dark_alloy',.054,1.82,(-.35,1.21,-.10),sections=24)
 a.add('auger_flight','satin_steel',helix_flight(x=-.35,z=-.10))
 a.cyl('drill_bushing','alloy',.145,.09,(-.35,.48,-.10),sections=26)
 a.cyl('drill_tip','dark_alloy',.045,.19,(-.35,.23,-.10),sections=22)
 # hydraulic guide side piston, clear supported endpoints
 a.cyl('guide_hydraulic','dark_alloy',.045,1.39,(-.70,1.315,-.30),sections=18)
 a.cyl('guide_hydraulic','satin_steel',.025,.92,(-.70,1.78,-.30),sections=18)
 a.cyl('guide_hydraulic','orange',.064,.09,(-.70,.60,-.30),sections=20)
 # extraction separation tank and reinforced mounting on right side
 a.box('water_reservoir_cradle','dark_alloy',(.68,.10,.88),(.68,.55,-.03))
 for x in (.39,.94):a.box('tank_cradle','satin_steel',(.065,.50,.52),(x,.79,-.03))
 a.cyl('water_reservoir','white_ceramic',.27,.67,(.67,1.055,-.06),sections=32)
 a.cyl('water_reservoir','teal',.269,.05,(.67,1.375,-.06),sections=32)
 a.cyl('water_reservoir','satin_steel',.277,.06,(.67,.72,-.06),sections=32)
 a.cyl('tank_fill_lid','dark_alloy',.074,.047,(.67,1.43,-.06),sections=20)
 for z in (-.27,.15):a.box('tank_retaining_straps','satin_steel',(.56,.045,.043),(.67,1.14,z))
 a.box('pump_chassis','dark_alloy',(.50,.22,.38),(.74,.62,-.40))
 a.cyl('pump_motor','alloy',.11,.26,(.71,.65,-.45),axis='x',sections=28)
 a.cyl('pump_rotor_guard','teal',.095,.035,(.87,.65,-.45),axis='x',sections=26)
 a.hose('extraction_hose','rubber_gasket',[(-.31,.47,-.30),(-.31,.40,-.59),(.24,.40,-.59),(.55,.56,-.47)],.019)
 a.hose('recovery_pipe','teal',[(.88,.73,-.36),(1.02,.75,-.30),(1.02,1.11,-.27),(.90,1.18,-.16)],.022)
 a.cyl('recovery_valve','orange',.045,.048,(1.035,1.03,-.28),axis='x',sections=18)
 a.box('control_box','white_ceramic',(.36,.44,.19),(-.80,1.16,.29))
 a.box('switch_recess','dark_alloy',(.30,.26,.02),(-.80,1.18,.182))
 for x in (-.88,-.72):
  a.cyl('physical_switches','satin_steel',.030,.035,(x,1.14,.17),axis='z',sections=16)
  a.box('physical_switches','orange',(.028,.064,.031),(x,1.14,.145))
 a.cyl('state_light','bright_green',.021,.014,(-.80,1.30,.16),axis='z')
 # jack outriggers braces anchored to skids
 for x in (-1.06,1.06):
  a.bar('outriggers','dark_alloy',(x*.84,.31,.43),(x,.23,.83),.035)
  a.cyl('outrigger_pads','satin_steel',.135,.047,(x,.075,.86),sections=20)
 return a.finish()


def reactor():
 a=Model('exterior_surface_reactor')
 # protected base, stabilising feet and skid rails
 for x in (-1.0,1.0):
  a.box('ground_skids','dark_alloy',(.225,.17,1.67),(x,.106,0))
  for z in (-.67,.67):a.box('anti_vibration_feet','black_rubber',(.26,.05,.34),(x,.031,z))
 for z in (-.68,.68):a.box('subframe','satin_steel',(2.03,.13,.14),(0,.29,z))
 a.box('support_platform','alloy',(2.28,.16,1.50),(0,.365,0))
 a.box('power_core_rear','dark_alloy',(1.32,1.41,.95),(0,1.15,.03))
 a.box('power_core_shell','white_ceramic',(1.46,1.53,.91),(0,1.19,0))
 a.box('top_module','white_painted',(1.58,.20,1.04),(0,2.02,0))
 for y in (.56,1.97):a.box('corner_belt','satin_steel',(1.55,.065,.995),(0,y,0))
 for x in (-.69,.69):a.box('main_vertical_rails','alloy',(.058,1.52,1.05),(x,1.19,0))
 # frontal shielded central service housing: not generic flat panel, layer recess and protective frame
 a.box('front_service_back','dark_alloy',(1.11,1.03,.025),(0,1.28,-.485))
 a.box('front_service_plate','white_painted',(.93,.82,.065),(0,1.33,-.535))
 for x in (-.51,.51):a.box('service_rails','satin_steel',(.052,1.10,.075),(x,1.29,-.53))
 for y in (.73,1.84):a.box('service_rails','satin_steel',(1.10,.05,.078),(0,y,-.53))
 # shielded access hatch has front panel with handles and gasket
 a.box('access_hatch','rubber_gasket',(.66,.53,.020),(-.15,1.33,-.576))
 a.box('access_hatch','white_painted',(.61,.48,.030),(-.15,1.33,-.60))
 for x in (-.41,.11):a.cyl('access_hatch_fasteners','dark_alloy',.015,.020,(x,1.33,-.621),axis='z',sections=12)
 a.box('access_handle','dark_alloy',(.12,.035,.041),(-.15,1.31,-.637))
 a.box('access_handle','satin_steel',(.06,.075,.035),(-.15,1.31,-.662))
 # chunky right-side control pocket
 a.box('isolation_recess','dark_alloy',(.24,.55,.030),(.385,1.28,-.58))
 a.cyl('master_isolator','orange',.082,.068,(.39,1.40,-.62),axis='z',sections=20)
 a.bar('master_handle','dark_alloy',(.33,1.41,-.71),(.45,1.41,-.71),.018)
 for y,mat in ((1.12,'bright_green'),(1.02,'amber_glow')):a.cyl('power_indicators',mat,.027,.014,(.39,y,-.603),axis='z',sections=16)
 # side radiator assembly (each fin genuinely supported at top and bottom) on both sides
 for s in (-1,1):
  x=s*.85
  for z in (-.42,.42):a.bar('radiator_uprights','dark_alloy',(x,.52,z),(x,1.87,z),.046,sections=16)
  for i in range(7):
   z=-.45+i*.15
   a.box('radiator_fins','alloy',(.06,1.17,.055),(s*(.90+i%2*.025),1.18,z))
   a.box('fin_edge','satin_steel',(.077,.03,.064),(s*(.90+i%2*.025),1.79,z))
  for yy in (.65,1.80):a.box('radiator_manifold','dark_alloy',(.16,.09,1.05),(s*.90,yy,0))
  a.hose('coolant_loop','teal',[(s*.61,.75,.26),(s*.80,.75,.26),(s*.91,.90,.26),(s*.91,1.58,.26)],.019)
 # rear service exhaust / cooling fan cylinder, physically inset from rear
 a.box('rear_vent_back','dark_alloy',(.75,.57,.035),(0,1.29,.54))
 a.cyl('cooling_fan_shroud','alloy',.24,.11,(0,1.29,.595),axis='z',sections=36)
 for i in range(6):
  angle=math.pi*2*i/6
  x=.10*math.cos(angle);y=1.29+.10*math.sin(angle)
  a.box('fan_blades','dark_alloy',(.11,.035,.02),(x,y,.653))
 a.cyl('fan_hub','satin_steel',.050,.035,(0,1.29,.673),axis='z',sections=22)
 # grounded cable panel with believable thick terminations and sockets
 a.box('power_output_panel','dark_alloy',(.76,.23,.13),(0,.67,-.71))
 for x,mat in ((-.25,'teal'),(0,'orange'),(.25,'alloy')):
  a.cyl('cable_sockets',mat,.052,.095,(x,.68,-.80),axis='z',sections=20)
  a.cyl('socket_collar','black_rubber',.064,.022,(x,.68,-.775),axis='z',sections=20)
 # accessible external coolant service canister at right, plumbed to radiator
 a.cyl('coolant_service_canister','white_painted',.125,.51,(1.17,.95,.38),sections=25)
 a.cyl('coolant_service_canister','teal',.135,.055,(1.17,1.22,.38),sections=25)
 a.box('service_mount','dark_alloy',(.32,.09,.28),(1.17,.69,.38))
 a.hose('coolant_return','teal',[(1.17,1.20,.35),(1.05,1.28,.35),(.94,1.43,.26)],.016)
 # status / warning indicators, practical small indicator lamps only
 for x,mat in ((-.19,'bright_green'),(0,'amber_glow'),(.19,'safety_red')):a.cyl('external_lamps',mat,.032,.018,(x,2.045,-.539),axis='z',sections=20)
 return a.finish()



def portable_floodlight():
 a=Model('exterior_portable_floodlight')
 a.box('battery_base','dark_alloy',(.69,.23,.46),(0,.15,0))
 a.box('upper_casing','white_ceramic',(.66,.065,.42),(0,.295,0))
 for x in (-.27,.27):
  a.box('ground_feet','black_rubber',(.15,.055,.49),(x,.027,0))
  a.box('base_brackets','alloy',(.058,.21,.47),(x,.155,0))
 a.box('service_lid','warm_panel',(.34,.13,.018),(0,.145,-.247))
 a.box('service_latch','orange',(.046,.032,.019),(0,.14,-.258))
 a.cyl('power_switch','orange',.032,.018,(-.20,.285,-.21),axis='z',sections=18)
 a.cyl('charge_light','bright_green',.016,.013,(-.12,.285,-.218),axis='z',sections=14)
 # telescoping mast and physically connected braces
 a.cyl('telescoping_pole','alloy',.038,.93,(0,.79,0),sections=20)
 a.cyl('telescoping_pole','satin_steel',.028,.64,(0,1.57,0),sections=20)
 a.cyl('locking_collar','orange',.055,.058,(0,1.24,0),sections=19)
 for x in (-.30,.30):
  a.bar('pole_braces','dark_alloy',(0,.57,0),(x,.33,-.15),.018)
 a.box('light_yoke','dark_alloy',(.84,.057,.062),(0,1.83,0))
 a.box('center_bracket','satin_steel',(.075,.15,.095),(0,1.78,0))
 for x in (-.238,.238):
  a.bar('head_support','satin_steel',(x,1.84,0),(x,1.915,-.067),.026)
  a.cyl('head_tilt_pin','dark_alloy',.025,.062,(x,1.912,-.050),axis='x')
  a.box('light_housing','white_painted',(.37,.20,.095),(x,1.966,-.12))
  a.box('light_gasket','black_rubber',(.346,.181,.018),(x,1.966,-.176))
  a.box('led_emitter','light_diffuser',(.326,.16,.015),(x,1.966,-.189))
  for dx in (-.17,.17):a.box('housing_endcaps','alloy',(.022,.201,.113),(x+dx,1.966,-.121))
 a.hose('power_cable','black_rubber',[(.24,.29,.17),(.24,.7,.14),(.075,1.1,.10),(.075,1.82,.05),(0,1.84,.05)],.011)
 a.hose('head_cables','black_rubber',[(0,1.84,.05),(-.23,1.85,.04),(-.23,1.94,-.10)],.007)
 a.hose('head_cables','black_rubber',[(0,1.84,.05),(.23,1.85,.04),(.23,1.94,-.10)],.007)
 a.bar('carry_handle','satin_steel',(-.19,.34,.23),(.19,.34,.23),.018)
 return a.finish()


def tall_light_post():
 a=Model('exterior_tall_light_post')
 a.box('ground_base','dark_alloy',(.71,.13,.67),(0,.09,0))
 a.box('foundation_plate','alloy',(.63,.055,.60),(0,.191,0))
 for x in (-.27,.27):
  for z in (-.24,.24):
   a.cyl('anchor_bolts','satin_steel',.03,.065,(x,.215,z),sections=14)
 a.cyl('main_mast','alloy',.065,2.75,(0,1.61,0),sections=24)
 a.cyl('upper_mast','satin_steel',.046,1.10,(0,3.06,0),sections=20)
 a.cyl('locking_collar','orange',.085,.10,(0,2.55,0),sections=20)
 for x in (-.26,.26):a.bar('base_braces','dark_alloy',(0,.73,0),(x,.25,-.14),.027)
 # overhead pair, every lamp connected to crossarm via side brackets
 a.box('head_spreader','dark_alloy',(1.34,.083,.081),(0,3.54,0))
 a.box('mast_yoke','satin_steel',(.19,.18,.18),(0,3.49,0))
 for x in (-.47,.47):
  a.bar('head_support','alloy',(x,3.55,0),(x,3.61,-.11),.035)
  a.box('light_heads','white_painted',(.59,.23,.14),(x,3.665,-.155))
  a.box('light_seal','rubber_gasket',(.565,.210,.012),(x,3.665,-.231))
  a.box('led_emitter','light_diffuser',(.52,.18,.012),(x,3.665,-.244))
  for k in range(4):a.box('rear_heat_fins','alloy',(.027,.20,.09),(x-.2+k*.13,3.665,-.066))
 # utilitarian control and utility junction on mast
 a.box('junction_box','white_ceramic',(.24,.37,.15),(0,1.19,-.11))
 a.box('junction_cover','warm_panel',(.194,.29,.022),(0,1.19,-.201))
 a.cyl('service_switch','orange',.027,.026,(0,1.12,-.219),axis='z')
 a.hose('supply_cable','black_rubber',[(0,.29,.08),(.11,.49,.07),(.11,1.15,.055),(.075,2.54,.055),(.075,3.46,.03)],.011)
 return a.finish()


def solar_floodlight():
 a=Model('exterior_solar_floodlight')
 a.box('battery_base','dark_alloy',(.52,.27,.45),(0,.16,0))
 a.box('battery_lid','white_ceramic',(.49,.067,.42),(0,.326,0))
 for x in (-.20,.20):a.box('ground_skids','black_rubber',(.12,.045,.45),(x,.025,0))
 a.cyl('support_mast','alloy',.05,2.02,(0,1.37,0),sections=22)
 a.cyl('upper_mast','satin_steel',.038,.56,(0,2.47,0),sections=20)
 for x in (-.20,.20):a.bar('base_support','dark_alloy',(0,.67,0),(x,.30,-.17),.024)
 # solar head tilted 22 deg, mounted on physically triangulated brackets
 def tilted_box(node,mat,size,position,angle=-23):
  m=trimesh.creation.box(extents=size)
  m.apply_transform(trimesh.transformations.rotation_matrix(math.radians(angle),[1,0,0]))
  m.apply_translation(position)
  a.add(node,mat,m)
 tilted_box('solar_backplate','white_painted',(.98,.056,.72),(0,2.80,.10))
 tilted_box('solar_cell_bed','dark_alloy',(.92,.015,.66),(0,2.834,.095))
 def rotcoords(v):
  t=math.radians(-23);x,y,z=v
  return (x,y*math.cos(t)-z*math.sin(t),y*math.sin(t)+z*math.cos(t))
 for ix in range(4):
  for iz in range(3):
   dx=-.345+ix*.23;dz=-.21+iz*.21
   rx,ry,rz=rotcoords((dx,.048,dz))
   tilted_box('solar_cells','cool_blue',(.19,.012,.17),(rx,2.80+ry,.10+rz))
 for x in (-.48,.48):
  a.bar('solar_supports','satin_steel',(0,2.54,0),(x,2.785,.10),.022)
 a.bar('solar_supports','satin_steel',(0,2.54,0),(0,2.64,-.29),.028)
 # a single forward-facing wash floodlight below panel
 a.box('lamp_frame','dark_alloy',(.54,.27,.115),(0,2.25,-.19))
 a.box('lamp_housing','white_painted',(.52,.245,.11),(0,2.25,-.21))
 a.box('lamp_gasket','black_rubber',(.49,.22,.011),(0,2.25,-.27))
 a.box('led_emitter','light_diffuser',(.45,.18,.013),(0,2.25,-.284))
 for x in (-.26,.26):a.bar('lamp_brace','alloy',(x,2.25,-.11),(0,2.34,.02),.022)
 # solar/battery cable and controls
 a.hose('solar_wiring','black_rubber',[(0,2.78,.16),(.07,2.61,.17),(.07,2.1,.09),(.07,.61,.09),(.18,.35,.06)],.009)
 a.box('switch_pocket','white_ceramic',(.20,.13,.025),(0,.18,-.24))
 a.cyl('switch','orange',.028,.026,(0,.18,-.26),axis='z')
 a.cyl('charged_status','bright_green',.018,.014,(.09,.19,-.26),axis='z')
 return a.finish()


def main():
 rec=[drill(),reactor(),portable_floodlight(),tall_light_post(),solar_floodlight()]
 (ROOT/'asset_manifest.json').write_text(json.dumps({'style':'Bright Mars exploration research hardware - The Martian / Project Hail Mary influence','placement':'freely on suitable near-level terrain; no structural snaps','models':rec},indent=2))
 for r in rec:print(r['id'],r['triangles'],'tris,',r['mesh_groups'],'groups',r['dimensions_xyz_m'])
if __name__=='__main__':main()
