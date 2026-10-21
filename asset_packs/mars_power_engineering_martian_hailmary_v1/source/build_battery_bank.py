#!/usr/bin/env python3
"""Six-cartridge modular battery bank sharing the cabinet's bright utility palette.
Removable cartridge faces are grouped by name for simple Godot animation.
"""
from pathlib import Path
src=Path(__file__).resolve().with_name('build_power_cabinet.py')
# Reuse geometry/material helpers, without executing the other cabinet's model builder.
header=src.read_text().split('\nA=Cabinet()')[0]
scope={'__file__':str(__file__),'__name__':'__asset_helpers__'}
exec(compile(header,str(src),'exec'),scope)
A=scope['Cabinet']()
import math, types
# Only the demonstration/service cartridge moves independently; five fixed packs
# batch by material to reduce the number of draw calls without losing appearance.
_original_put = A.put
def _optimized_put(self, mesh, material, group=None, pivot=None):
    if group and group.startswith('Battery_Cassette_') and group!='Battery_Cassette_R1_L':
        group,pivot=None,None
    return _original_put(mesh, material, group, pivot)
A.put=types.MethodType(_optimized_put,A)

# Frame and broad structural chassis: remains lighter than the power cabinet but feels manufactured.
A.b((1.39,.145,.79),(0,.138,0),'dark',r=.038,b=.009)
A.b((1.30,.063,.74),(0,.075,0),'steel',r=.02)
for xx in (-.58,.58):
 for zz in (-.285,.285):
  A.b((.13,.075,.15),(xx,.045,zz),'rubber',r=.025)
  A.b((.10,.02,.12),(xx,.010,zz),'shadow',r=.01)
# Back panel and corner carrying rails.
A.b((1.34,1.65,.09),(0,1.05,.329),'lightgrey',r=.025)
for xx in (-.655,0,.655):
 A.b((.083,1.71,.075),(xx,1.06,-.337),'aluminium',r=.012)
 A.b((.055,1.64,.043),(xx,1.065,-.367),'white',r=.008)
for xx in (-.65,.65):
 A.b((.071,1.66,.07),(xx,1.065,.342),'aluminium',r=.012)
 A.b((.030,1.46,.04),(xx,1.072,.307),'warmwhite',r=.007)
# Side skins with cutline treatment, backed by rails.
for xx in (-.69,.69):
 A.b((.030,1.53,.58),(xx,1.065,0),'white',r=.019)
 for yy in (.59,1.39):
  A.b((.028,.027,.46),(xx+(.019 if xx>0 else -.019),yy,0),'aluminium',r=.006)
# Lower housing / breaker bar
A.b((1.34,.14,.78),(0,.297,-.005),'white',r=.028)
A.b((1.27,.033,.076),(0,.340,-.362),'aluminium',r=.012)
# Steel reinforcing cross rails under each battery row, with inner shelf lips.
rows=(.605,1.090,1.570)
for i,yy in enumerate(rows):
 A.b((1.18,.056,.61),(0,yy-.233,-.014),'steel',r=.012)
 A.b((1.18,.033,.085),(0,yy-.208,-.345),'lightgrey',r=.008)
 A.b((1.18,.023,.056),(0,yy+.206,-.314),'aluminium',r=.007)
 # black inner bay behind both packs
 A.b((1.15,.388,.024),(0,yy,-.209),'shadow',r=.012)
# individual battery cartridges, two in each of three rows.
for row,yy in enumerate(rows,1):
 for side,xx in (('L',-.315),('R',.315)):
  name=f'Battery_Cassette_R{row}_{side}'
  pv=(xx,yy,-.026)
  # Heavy composite cartridge slides over rails and is anchored by face locks.
  A.b((.523,.348,.455),(xx,yy,-.015),'lightgrey',group=name,pivot=pv,r=.023,b=.006)
  A.b((.481,.315,.045),(xx,yy,-.266),'warmwhite',group=name,pivot=pv,r=.022)
  A.b((.46,.054,.030),(xx,yy+.133,-.294),'white',group=name,pivot=pv,r=.012)
  A.b((.446,.047,.024),(xx,yy-.131,-.291),'dark',group=name,pivot=pv,r=.009)
  # elongated recessed handle: behind inner carry rail with two rooted supports
  A.b((.258,.080,.025),(xx,yy+.008,-.298),'dark',group=name,pivot=pv,r=.014)
  A.b((.21,.025,.053),(xx,yy+.008,-.342),'aluminium',group=name,pivot=pv,r=.009)
  for dx in (-.128,.128):
   A.b((.038,.076,.032),(xx+dx,yy+.008,-.331),'steel',group=name,pivot=pv,r=.006)
  # Two captive mechanical latches with recognisable orange releases
  for dx in (-.204,.204):
   A.c((xx+dx,yy-.060,-.301),(xx+dx,yy-.060,-.322),.025,'steel',group=name,pivot=pv,n=16)
   A.b((.017,.064,.028),(xx+dx,yy-.060,-.349),'orange',group=name,pivot=pv,r=.006)
  # Ventilation slots: shallow channels have a real dark backing strip.
  A.b((.353,.066,.014),(xx,yy-.100,-.301),'shadow',group=name,pivot=pv,r=.009)
  for k in range(8):
   xpos=xx-.154+k*.044
   A.b((.024,.033,.008),(xpos,yy-.100,-.313),'aluminium',group=name,pivot=pv,r=.004,b=.001)
  # Charge indicator: clear physical light pipe, no fixed numbers/screens
  A.b((.08,.017,.012),(xx-.155,yy+.115,-.304),'greenlight',
      group=f'Battery_ChargeIndicator_R{row}_{side}',pivot=(xx-.155,yy+.115,-.304),r=.005,b=.001)
# Top cooling plenum with two removable blower housings and fan grilles.
A.b((1.43,.170,.82),(0,1.975,.012),'white',r=.034,b=.007)
A.b((1.35,.06,.76),(0,2.049,.014),'lightgrey',r=.018)
A.b((1.28,.075,.080),(0,1.890,-.355),'aluminium',r=.015)
for x in (-.37,.37):
 A.b((.54,.047,.025),(x,1.968,-.396),'shadow',r=.012)
 for k in range(8):
  A.b((.035,.016,.010),(x-.19+k*.054,1.969,-.414),'steel',r=.003,b=.001)
# Rear coolant supply and return manifold: physical connections to bottom assembly.
for x,color in ((-.45,'teal'),(.45,'steel')):
 for start,end in [((x,.35,.372),(x,1.78,.372)),((x,1.78,.372),(x*.92,1.845,.300))]:
  A.c(start,end,.021,color,n=16)
 for y in (.49,1.03,1.56):
  A.b((.077,.05,.058),(x,y,.365),'aluminium',r=.010)
  A.c((x,y,.346),(x*.8,y,.268),.012,'rubber',n=12)
# Side utility channel and analogue mechanical disconnect knob at lower front.
A.b((.16,.158,.048),(.474,.318,-.384),'dark',r=.017)
A.c((.474,.317,-.396),(.474,.317,-.429),.049,'orange',group='Battery_Main_Disconnect',pivot=(.474,.317,-.396),n=26)
A.b((.105,.023,.028),(.474,.317,-.442),'warmwhite',group='Battery_Main_Disconnect',pivot=(.474,.317,-.396),r=.007)
for xx in (-.57,-.45,-.32):
 A.b((.065,.023,.020),(xx,.326,-.386),'greenlight' if xx<-.4 else 'amberlight',r=.007)
# Front frame fasteners, seated flush rather than suspended knobs.
for xx in (-.615,.615):
 for y in (.385,1.83):
  A.c((xx,y,-.391),(xx,y,-.396),.009,'steel',n=10)
# Back exhaust grill is covered by a frame, not free-floating blades.
A.b((.73,.17,.025),(0,1.72,.390),'white',r=.011)
A.b((.64,.112,.012),(0,1.72,.406),'shadow',r=.008)
for k in range(10):
 x=-.28+k*.062
 A.b((.035,.068,.010),(x,1.72,.413),'steel',r=.003,b=.001)

A.export(filename='battery_bank_martian_hailmary.glb',equipment_id='battery_bank')
