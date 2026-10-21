#!/usr/bin/env python3
"""Original, Godot-ready Mars geology and ice research furniture.
Physical stage detail and shared PBR materials; no baked lettering or mock screens.
Godot coordinates: X across, Y up, -Z to viewing/front side; units metres.
"""
from pathlib import Path
from collections import defaultdict
import math, json
import numpy as np
import trimesh

ROOT=Path(__file__).resolve().parent.parent
DEST=ROOT/'models'; DEST.mkdir(exist_ok=True)

PALETTE={
'ceramic':('#F5F4ED',.02,.60), 'shell':('#E8EBE7',.03,.66), 'ivory':('#FFFAF0',.02,.72),
'silver':('#B9C7C9',.74,.38), 'aluminium':('#8FABB3',.76,.38), 'steel':('#687F88',.82,.52),
'graphite':('#3C525B',.20,.68), 'recess':('#23343D',.04,.87), 'rubber':('#2B3D44',0,.87),
'orange':('#D99253',.07,.51), 'amber':('#FFC97A',0,.34), 'teal':('#5A9CA8',.12,.55),
'blue':('#6FADBD',.13,.45), 'light':('#ECF5ED',0,.39), 'glass':('#B8DEE0',.02,.13),
'clear':('#D4ECEE',.04,.22), 'ice':('#B0DCE7',.08,.25), 'frost':('#C4E2E9',.02,.38),
'rock_ochre':('#A77C60',0,.95),'rock_red':('#905C51',0,.93),
'rock_sand':('#D1AC7F',0,.97),'rock_dark':('#605955',0,.94),
'rock_grey':('#8D928B',0,.98), 'rock_yellow':('#B79F6D',0,.93),
'wood':('#B8A18A',0,.82), 'neutral':('#DFE2DC',.03,.76),
}
MATERIALS={}
for name,(rgb,metal,rough) in PALETTE.items():
    emissive = [0,0,0]
    if name=='amber':emissive=[.85,.36,.08]
    if name=='light':emissive=[.48,.58,.49]
    rgbvals=[int(rgb[i:i+2],16) for i in [1,3,5]]
    alpha=105 if name=='clear' else (155 if name=='glass' else 255)
    MATERIALS[name]=trimesh.visual.material.PBRMaterial(name=f'Science_{name}',baseColorFactor=np.array(rgbvals+[alpha],dtype=np.uint8),metallicFactor=metal,roughnessFactor=rough,emissiveFactor=emissive,alphaMode='BLEND' if alpha<255 else 'OPAQUE',doubleSided=name in ['glass','clear'])

# Rounded extruded enclosures (all dimensions are X/Y/Z)
def cube(size,pos):
 m=trimesh.creation.box(extents=size); m.apply_translation(pos); return m

def rounded(size,pos,r=.025,bev=.005,detail=3):
 w,h,d=map(float,size);r=min(r,w*.4,h*.4);bevel=min(bev,w*.12,h*.12,d*.18)
 corners=[(w/2-r,-h/2+r,-math.pi/2,0),(w/2-r,h/2-r,0,math.pi/2),(-w/2+r,h/2-r,math.pi/2,math.pi),(-w/2+r,-h/2+r,math.pi,1.5*math.pi)]
 def profile(b):
  rr=max(.0001,r-b/2)
  return np.array([(cx+rr*math.cos(ang),cy+rr*math.sin(ang)) for cx,cy,aa,bb in corners for ang in np.linspace(aa,bb,detail+1)])
 n=len(profile(0)); verts=[]
 for z,be in [(-d/2,bevel),(-d/2+bevel,0),(d/2-bevel,0),(d/2,bevel)]:
  verts.extend(np.c_[profile(be),np.full(n,z)])
 faces=[]
 for k in range(3):
  for i in range(n):
   j=(i+1)%n; faces+= [[k*n+i,k*n+j,(k+1)*n+j],[k*n+i,(k+1)*n+j,(k+1)*n+i]]
 verts.extend([[0,0,-d/2],[0,0,d/2]])
 for i in range(n):
  j=(i+1)%n;faces.extend([[n*4,i,j],[n*4+1,3*n+j,3*n+i]])
 m=trimesh.Trimesh(vertices=np.asarray(verts)+np.asarray(pos),faces=np.array(faces),process=False)
 m.fix_normals();return m

def cyl(p,q,r,n=20):
 p=np.asarray(p,dtype=float); q=np.asarray(q,dtype=float); v=q-p; length=np.linalg.norm(v)
 if length<1e-5:raise ValueError((p,q))
 m=trimesh.creation.cylinder(radius=r,height=length,sections=n)
 m.apply_transform(trimesh.geometry.align_vectors([0,0,1],v));m.apply_translation((p+q)*.5)
 return m

def tube(points,r,n=14):
 return trimesh.util.concatenate([cyl(p,q,r,n) for p,q in zip(points[:-1],points[1:])])

def ring(center,R=.07,r=.009,axis='z',n=30,k=8):
 xyz=[]; ff=[]
 for i in range(n):
  t=math.tau*i/n
  for j in range(k):
   th=math.tau*j/k
   xyz.append(((R+r*math.cos(th))*math.cos(t),(R+r*math.cos(th))*math.sin(t),r*math.sin(th)))
 for i in range(n):
  for j in range(k):
   a=i*k+j;b=((i+1)%n)*k+j;c=((i+1)%n)*k+(j+1)%k;d=i*k+(j+1)%k
   ff.extend([[a,b,c],[a,c,d]])
 m=trimesh.Trimesh(vertices=np.array(xyz),faces=np.array(ff),process=False)
 if axis=='x':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
 if axis=='y':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
 m.apply_translation(center)
 return m

def tapered(p,q,r0,r1,sections=16):
 # cone frustum by explicit triangulation, axis local z
 a=np.array(p,float);b=np.array(q,float);v=b-a;length=np.linalg.norm(v)
 verts=[];f=[]
 for z,r in [(0,r0),(length,r1)]:
  for i in range(sections):
   th=math.tau*i/sections;verts.append((r*math.cos(th),r*math.sin(th),z))
 for i in range(sections):
  j=(i+1)%sections
  f.extend([[i,j,sections+j],[i,sections+j,sections+i]])
 verts.extend([[0,0,0],[0,0,length]])
 for i in range(sections):
  j=(i+1)%sections
  f.extend([[2*sections,j,i],[2*sections+1,sections+i,sections+j]])
 mesh=trimesh.Trimesh(vertices=np.array(verts),faces=np.array(f),process=False)
 mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],v));mesh.apply_translation(a)
 return mesh

class Model:
 def __init__(self,asset_id):
  self.asset_id=asset_id;self.stat=defaultdict(list);self.dynamic=defaultdict(list);self.pivots={};self.interactions=[]
 def add(self,m,mat,group=None,pivot=None):
  if group is None:self.stat[mat].append(m)
  else:
   self.dynamic[(group,mat)].append(m)
   if pivot is not None:
    pv=np.array(pivot,float)
    if group in self.pivots and not np.allclose(pv,self.pivots[group]):raise ValueError(group)
    self.pivots[group]=pv
 def bx(self,sz,pos,mat,group=None,pivot=None):self.add(cube(sz,pos),mat,group,pivot)
 def b(self,sz,pos,mat,group=None,pivot=None,r=.014):self.add(rounded(sz,pos,r),mat,group,pivot)
 def c(self,p,q,r,mat,group=None,pivot=None,n=20):self.add(cyl(p,q,r,n),mat,group,pivot)
 def t(self,pts,r,mat,group=None,pivot=None):self.add(tube(pts,r),mat,group,pivot)
 def r(self,pos,R,r,mat,axis='z',group=None,pivot=None):self.add(ring(pos,R,r,axis),mat,group,pivot)
 def cone(self,p,q,r0,r1,mat,group=None,pivot=None):self.add(tapered(p,q,r0,r1),mat,group,pivot)
 def save(self,name,desc,systems,role,footprint=(1.5,1.5)):
  scene=trimesh.Scene()
  scene.metadata={'name':name,'asset_id':self.asset_id,'scale':'metres','up':'+Y','forward':'-Z','interactions':sorted(set([g for g,_ in self.dynamic])),'theme':'Mars water ice and geological history'}
  for mat,objs in self.stat.items():
   if not objs:continue
   mesh=trimesh.util.concatenate(objs);mesh.visual=trimesh.visual.TextureVisuals(material=MATERIALS[mat])
   scene.add_geometry(mesh,geom_name='Fixed__'+mat,node_name='Fixed__'+mat)
  for (group,mat),objs in self.dynamic.items():
   mesh=trimesh.util.concatenate(objs)
   pivot=self.pivots.get(group,np.array([0.,0.,0.]))
   mesh.apply_translation(-pivot);mesh.visual=trimesh.visual.TextureVisuals(material=MATERIALS[mat])
   pose=np.eye(4);pose[:3,3]=pivot
   node=group+'__'+mat
   scene.add_geometry(mesh,geom_name=node,node_name=node,transform=pose)
  fn=DEST/(self.asset_id+'.glb'); scene.export(fn)
  opened=trimesh.load(fn,force='scene')
  bounds=opened.bounds; dims=bounds[1]-bounds[0]
  summary={'id':self.asset_id,'name':name,'file':fn.name,'description':desc,'connected_systems':systems,'classroom_role':role,'triangle_count':sum(len(x.faces) for x in opened.geometry.values()),'mesh_groups':len(opened.graph.nodes_geometry),'material_count':len(set([x.visual.material.name for x in opened.geometry.values()])),
           'dimensions_xyz_m':np.round(dims,3).tolist(),'bounds_min_m':np.round(bounds[0],3).tolist(),'bounds_max_m':np.round(bounds[1],3).tolist(),
           'interaction_components':sorted({g for g,m in self.dynamic}),'baked_text':False,'static_screen_data':False,'active_simulation':False,
           'placement':'free within permitted Science Laboratory zone; collision and walking clearance verified in Godot', 'base_footprint_m':list(footprint)}
  if bounds[0][1]<-.008:raise ValueError('Below floor '+str(summary))
  if dims[0]>footprint[0]+.025 or dims[2]>footprint[1]+.025:raise ValueError('Footprint too large '+str(summary))
  (ROOT/(self.asset_id+'_manifest.json')).write_text(json.dumps(summary,indent=2))
  print(json.dumps(summary,indent=2),flush=True)
  return summary

# Shared furniture details: feet, framed lower plinth, mounting fasteners, louvres.
def feet(a,width,depth):
 for x in (-width/2+.095,width/2-.095):
  for z in (-depth/2+.095,depth/2-.095):
   a.b((.11,.055,.105),(x,.055,z),'graphite',r=.024)
   a.b((.09,.018,.085),(x,.016,z),'rubber',r=.017)

def slots(a,xmin,xmax,y,z,number,mat='graphite'):
 for i in range(number):
  x=xmin+(xmax-xmin)*(i+.5)/number
  a.b((.030,.008,.013),(x,y,z),mat,r=.004)

def bolts(a,points,axis='z'):
 for p in points:
  x,y,z=p
  if axis=='z':a.c((x,y,z),(x,y,z-.007),.009,'steel',n=10)
  else:a.c((x,y,z),(x,y+.007,z),.009,'steel',n=10)

# ------ ASSET 1: CORE AND ICE ASSAY WORKBENCH ------
def make_workbench():
 a=Model('science_workbench')
 # substantial lower chassis, undercounter inset tool cabinets
 a.b((1.47,.095,.84),(0,.13,.02),'graphite',r=.032)
 feet(a,1.47,.84)
 for x in (-.65,.65):
  a.b((.072,.71,.67),(x,.49,.03),'aluminium')
  a.b((.055,.70,.36),(x,.49,.02),'shell')
 a.b((1.33,.66,.055),(0,.46,.33),'graphite')
 a.b((1.34,.035,.70),(0,.16,-.015),'steel',r=.010)
 # undercounter cold-pump cabinet on right: mounting plate, fan, hose and front door
 a.b((.51,.59,.071),(.388,.495,-.34),'recess',r=.018)
 a.b((.47,.53,.052),(.388,.498,-.395),'ceramic',r=.021)
 a.b((.40,.095,.021),(.388,.71,-.431),'aluminium',r=.011)
 for yy in [.33,.38,.43]:slots(a,.23,.54,yy,-.434,6,mat='graphite')
 for x in (.18,.60):
  for y in (.30,.70):bolts(a,[(x,y,-.433)])
 # compact specimen drawer on left, visible runners and handle
 for y in (.35,.51,.67):
  a.b((.51,.147,.068),(-.35,y,-.350),'shell',group='Specimen_Drawer',pivot=(-.35,.44,-.34),r=.016)
  a.b((.32,.024,.019),(-.35,y,-.395),'aluminium',group='Specimen_Drawer',pivot=(-.35,.44,-.34))
 # work surface is deliberately layered and edged, not a blank slab
 a.b((1.49,.075,.91),(0,.873,-.035),'aluminium',r=.045)
 a.b((1.39,.038,.82),(0,.928,-.038),'ceramic',r=.045)
 a.b((1.12,.019,.62),(0,.955,-.053),'ivory',r=.022)
 a.b((1.49,.035,.055),(0,.922,-.48),'steel',r=.006)
 # rear backsplashes: proper panel bracket with curved corners and fixed hinge lip
 a.b((1.40,.25,.055),(0,1.067,.382),'shell',r=.030)
 a.b((1.31,.035,.047),(0,1.19,.352),'aluminium',r=.008)
 for x in (-.59,.59):a.b((.057,.28,.072),(x,1.066,.374),'steel')
 # left: stratigraphic sample core secured by 2 pairs of V-rollers; variable layer colours are real 3D segments
 for x in (-.47,-.07):
  for z in (-.183,.055):
   a.c((x,1.003,z),(x,1.035,z),.032,'rubber',n=18)
   a.b((.12,.022,.08),(x,.994,z),'steel')
 # core is horizontal X axis and shows a clear cross-section of alternating sediment layers
 colors=['rock_red','rock_sand','rock_grey','rock_ochre','rock_dark','rock_yellow','rock_red','rock_sand']
 xs=np.linspace(-.59,.03,len(colors)+1)
 for i,mat in enumerate(colors):
  a.c((xs[i],1.087,-.064),(xs[i+1],1.087,-.064),.055,mat,n=28)
  if i<len(colors)-1:a.c((xs[i+1]-.002,1.087,-.064),(xs[i+1]+.002,1.087,-.064),.055,'rock_dark',n=28)
 for xx in (-.62,.048):
  a.r((xx,1.087,-.064),.061,.008,'aluminium',axis='x')
 # core clamp with padded moveable jaw (actual specimen in cradle)
 for xx in (-.52,-.025):
  a.b((.022,.10,.115),(xx,1.115,-.069),'graphite',group='Core_Clamp',pivot=(-.27,1.07,-.065),r=.009)
 a.c((-.28,1.133,-.18),(-.28,1.133,-.10),.012,'aluminium',n=12)
 a.r((-.28,1.133,-.20),.031,.008,'orange',axis='z',group='Core_Clamp',pivot=(-.27,1.07,-.065))
 # right: sealed sample warming/ice phase chamber with transparent observation porthole
 a.b((.55,.068,.45),(.37,.978,.088),'graphite',r=.028)
 a.b((.48,.275,.37),(.37,1.15,.10),'shell',r=.055)
 a.b((.435,.035,.33),(.37,1.30,.10),'aluminium',r=.021)
 # top hatch perimeter, light grey transparent window. pivots along back edge
 a.b((.402,.021,.294),(.37,1.331,.083),'glass',group='Ice_Chamber_Hatch',pivot=(.37,1.33,.24),r=.035)
 a.b((.37,.012,.263),(.37,1.348,.080),'clear',group='Ice_Chamber_Hatch',pivot=(.37,1.33,.24),r=.035)
 for x in (.20,.54):a.c((x,1.343,.252),(x,1.355,.252),.014,'steel',group='Ice_Chamber_Hatch',pivot=(.37,1.33,.24),n=12)
 a.b((.13,.026,.034),(.37,1.35,-.076),'orange',group='Ice_Chamber_Hatch',pivot=(.37,1.33,.24),r=.012)
 # visible cold specimen and tray lip, no fake data graphic
 a.b((.29,.023,.21),(.37,1.282,.085),'steel')
 a.b((.15,.033,.096),(.34,1.318,.08),'ice',r=.024)
 # vacuum / ice equipment pump below, physically connected to chamber by elbow
 a.c((.50,.82,.32),(.50,.96,.32),.032,'teal',n=16)
 a.t([(.5,.96,.32),(.56,1.04,.32),(.56,1.12,.27)],.011,'teal')
 # analogue gauge is cylinder dial and needle, not screen
 a.c((.39,1.11,-.102),(.39,1.11,-.14),.052,'aluminium',n=30)
 a.c((.39,1.11,-.141),(.39,1.11,-.151),.040,'ivory',n=30)
 a.c((.39,1.11,-.155),(.407,1.137,-.158),.004,'orange',n=8)
 # physical temperature setpoint knob + pump toggle with mounted bezel
 a.c((.57,1.02,-.112),(.57,1.02,-.146),.028,'graphite',n=20)
 a.c((.57,1.02,-.144),(.57,1.02,-.166),.021,'orange',group='Heater_Set_Knob',pivot=(.57,1.02,-.144),n=20)
 a.b((.09,.045,.019),(.25,1.025,-.112),'silver')
 a.b((.06,.038,.039),(.25,1.038,-.137),'teal',group='Pump_Toggle',pivot=(.25,1.03,-.13),r=.012)
 # tool rail with clamped pipettes / probe holders, credible support
 a.b((.78,.041,.052),(-.16,1.17,.331),'aluminium')
 for x in (-.44,-.3,-.16,-.02):
  a.c((x,1.16,.303),(x,1.05,.305),.006,'steel',n=10)
  a.c((x,1.065,.308),(x,1.038,.309),.013,'graphite',n=10)
 # additional anchored gooseneck examination light
 a.b((.12,.034,.12),(-.58,1.22,.31),'steel')
 a.t([(-.58,1.22,.30),(-.58,1.40,.29),(-.50,1.58,.18),(-.36,1.63,.12)],.013,'aluminium')
 a.b((.23,.070,.14),(-.34,1.64,.105),'ceramic',r=.025)
 a.b((.18,.012,.11),(-.34,1.602,.105),'light',group='Worklight_Emitter',pivot=(-.34,1.64,.105),r=.014)
 # earthing rail and genuine rear hose run
 a.c((-.61,.52,.325),(.54,.52,.325),.014,'steel',n=12)
 a.t([(.50,.50,.325),(.61,.50,.325),(.61,.75,.325),(.57,.83,.33)],.019,'rubber')
 desc='Bench for comparing sediment layers in returned cores and examining water ice in a sealed chamber.'
 return a.save('Core and Ice Analysis Workbench',desc,['Rover sampling','Electricity','Research missions'],'Open chamber, inspect layered core, adjust physical pump controls',footprint=(1.5,1.5))

# ----- ASSET 2: STEREO MICROSCOPE / GEOLOGICAL IMAGING STATION ------
def make_microscope():
 a=Model('microscope_station')
 # Workbench-mounted microscope with integrated illumination and physical depth; 1.30m wide
 feet(a,1.30,.78)
 a.b((1.30,.08,.78),(0,.13,0),'graphite',r=.034)
 for x in (-.56,.56):
  a.b((.09,.69,.56),(x,.49,0),'aluminium')
  a.b((.060,.58,.31),(x,.51,-.012),'shell')
 a.b((1.21,.048,.72),(0,.85,-.020),'aluminium',r=.025)
 a.b((1.15,.036,.66),(0,.886,-.034),'ceramic',r=.021)
 # rear equipment duct and rigid mounting cage
 a.b((1.18,.27,.08),(0,1.03,.316),'ivory',r=.025)
 a.b((1.08,.028,.035),(0,1.16,.275),'silver')
 # underbench sample drawer with visible sides
 a.b((.48,.24,.085),(.31,.66,-.300),'shell',group='Sample_Drawer',pivot=(.31,.66,-.30),r=.020)
 a.b((.27,.022,.020),(.31,.69,-.351),'steel',group='Sample_Drawer',pivot=(.31,.66,-.30))
 for x in (-.03,.63):
  a.b((.025,.12,.12),(x,.665,-.28),'steel')
 # massive microscope base, purposeful components
 a.b((.48,.072,.44),(-.28,.94,-.034),'graphite',r=.037)
 a.b((.42,.036,.38),(-.28,.996,-.028),'ceramic',r=.024)
 a.c((-.28,1.005,-.005),(-.28,1.024,-.005),.09,'steel',n=32)
 a.b((.31,.039,.28),(-.28,1.056,-.01),'graphite',r=.022)
 a.b((.225,.018,.182),(-.28,1.08,-.012),'neutral',r=.015)
 # rough specimen inside a removable low-profile examination tray
 for xx,yy,zz,rr,mat in [(-.345,1.107,-.016,.040,'rock_red'),(-.265,1.108,-.028,.045,'rock_grey'),(-.222,1.105,.030,.033,'rock_sand')]:
  rock=trimesh.creation.icosphere(subdivisions=1,radius=rr);rock.apply_scale([1.2,.60,.9]);rock.apply_translation((xx,yy,zz));a.add(rock,mat,group='Mineral_Sample_Tray',pivot=(-.28,1.075,-.01))
 a.b((.29,.014,.26),(-.28,1.076,-.014),'steel',group='Mineral_Sample_Tray',pivot=(-.28,1.075,-.01))
 # rigid C-arm column, attached to base and top optical housing
 a.b((.095,.55,.105),(-.09,1.26,.135),'aluminium')
 a.c((-.09,1.36,.14),(-.09,1.77,.14),.048,'steel',n=22)
 for yy in (1.43,1.67):a.r((-.09,yy,.14),.052,.009,'aluminium',axis='y')
 a.b((.34,.095,.16),(-.23,1.726,.09),'steel')
 a.b((.31,.19,.22),(-.25,1.66,-.015),'ivory',r=.057)
 a.b((.30,.062,.20),(-.25,1.550,-.015),'graphite',r=.024)
 # twin angled optical tubes with actual lens barrels and toroidal seals
 for xx in (-.335,-.18):
  a.c((xx,1.60,-.120),(xx,1.72,-.230),.038,'graphite',n=24)
  a.c((xx,1.72,-.230),(xx,1.76,-.267),.049,'rubber',n=24)
  a.r((xx,1.761,-.27),.047,.008,'steel',axis='z')
 # objective optics are on microscope axis, supported via column
 a.c((-.25,1.545,-.01),(-.25,1.30,-.01),.056,'aluminium',n=24)
 a.c((-.25,1.303,-.01),(-.25,1.24,-.01),.074,'graphite',n=28)
 a.c((-.25,1.23,-.01),(-.25,1.20,-.01),.040,'glass',n=24)
 # paired physical focus wheels separately rotating around z-facing pins
 for side in (-1,1):
  xx=-.09+side*.079
  a.c((xx,1.42,.138),(xx,1.42,.138+side*.07),.052,'steel',group='Focus_Knob',pivot=(-.09,1.42,.138),n=28)
  a.r((xx,1.42,.138+side*.07),.043,.010,'graphite',axis='z',group='Focus_Knob',pivot=(-.09,1.42,.138))
 # illumination light from arm: base and side lamp with warm emitter under scope
 a.c((-.47,1.01,.12),(-.52,1.28,.12),.016,'aluminium',n=14)
 a.c((-.52,1.28,.12),(-.34,1.26,.035),.015,'aluminium',n=14)
 a.b((.16,.050,.13),(-.35,1.26,.026),'ivory',r=.021)
 a.b((.13,.014,.094),(-.35,1.231,.024),'light',group='Sample_Illuminator',pivot=(-.35,1.26,.025),r=.014)
 # adjacent comparison fixture: layered circular/polished slices on a fixed aluminium rail
 a.b((.34,.035,.24),(.39,.935,-.06),'graphite',r=.017)
 a.b((.29,.017,.18),(.39,.96,-.06),'steel',r=.013)
 for idx,mat in enumerate(['rock_red','rock_sand','rock_grey']):
  x=.26+.132*idx
  a.c((x,.971,-.06),(x,.984,-.06),.043,mat,n=24)
  a.r((x,.978,-.06),.044,.004,'aluminium',axis='y')
 # physical graduated dial with colour segments; not a screen
 a.c((.40,1.07,.269),(.40,1.07,.229),.068,'silver',n=30)
 a.c((.40,1.07,.222),(.40,1.07,.207),.051,'ivory',n=28)
 a.c((.40,1.07,.205),(.417,1.090,.201),.004,'orange',n=8)
 # material sample container vials in actual gripping holders on rear shelf
 a.b((.47,.039,.125),(.355,1.20,.256),'aluminium',r=.015)
 for i in range(4):
  xx=.18+i*.115
  a.c((xx,1.211,.253),(xx,1.295,.253),.018,'glass',n=16)
  a.c((xx,1.295,.253),(xx,1.309,.253),.022,'graphite',n=16)
 # magnification changer mechanical lever and physical isolation toggle
 a.c((-.42,1.61,-.06),(-.51,1.61,-.06),.026,'steel',group='Magnification_Lever',pivot=(-.42,1.61,-.06),n=16)
 a.b((.056,.028,.040),(-.51,1.61,-.06),'orange',group='Magnification_Lever',pivot=(-.42,1.61,-.06),r=.009)
 # low-profile rear power plug and cable to base (no floating)
 a.t([(-.1,.92,.27),(-.1,.78,.28),(.57,.78,.28),(.57,.58,.28)],.010,'rubber')
 desc='An imaging station for studying rock grains, sediment textures and the effects of erosion.'
 return a.save('Geology Imaging and Microscope Station',desc,['Rover sampling','Research missions','Electricity'],'Inspect samples, focus microscope, illuminate tray',footprint=(1.5,1.5))

# ----- ASSET 3: STRATIGRAPHY / CORE SAMPLES ARCHIVE -----
def make_archive():
 a=Model('sample_storage_cabinet')
 feet(a,1.47,.78)
 a.b((1.47,.11,.78),(0,.15,0),'graphite',r=.038)
 for x in (-.65,.65):
  for z in (-.31,.31):a.b((.086,1.56,.09),(x,1.02,z),'aluminium')
 a.b((1.32,1.54,.055),(0,1.035,.338),'steel',r=.015)
 a.b((1.47,.12,.77),(0,1.845,0),'ivory',r=.027)
 a.b((1.37,.050,.65),(0,1.920,0),'aluminium',r=.016)
 a.b((1.34,.042,.68),(0,.259,0),'silver')
 # two compartment front panels; specimen cooling on left and dry core drawer bank on right
 # recess backing stays behind the specimen rack so the window genuinely shows the contents
 a.b((.67,1.36,.026),(-.324,1.048,.288),'recess',r=.019)
 a.b((.52,1.32,.09),(.357,1.058,-.278),'recess',r=.023)
 # cream inner insulation liner makes stored sample tubes visible through the hatch
 a.b((.53,1.16,.020),(-.317,1.11,.22),'ivory',r=.012)
 for yy in (.56,1.64):
  a.b((.52,.023,.040),(-.317,yy,.175),'frost',r=.006)
 # left chilled specimen door with hinge+big inset window -- closed behind transparent window
 door_pivot=(-.625,1.04,-.39)
 # frame is genuinely open behind glazing so students can see stored samples
 for xx in (-.605,-.029):
  a.b((.055,1.34,.073),(xx,1.048,-.352),'shell',group='Cold_Archive_Door',pivot=door_pivot,r=.015)
 for yy in (.405,1.690):
  a.b((.61,.056,.075),(-.317,yy,-.353),'shell',group='Cold_Archive_Door',pivot=door_pivot,r=.013)
 a.b((.50,.42,.065),(-.317,.625,-.362),'shell',group='Cold_Archive_Door',pivot=door_pivot,r=.014)
 # framed transparent upper observation panel with actual space behind it
 for xx in (-.536,-.099):
  a.b((.028,.680,.038),(xx,1.264,-.389),'aluminium',group='Cold_Archive_Door',pivot=door_pivot,r=.008)
 for yy in (.927,1.601):
  a.b((.47,.026,.038),(-.317,yy,-.390),'aluminium',group='Cold_Archive_Door',pivot=door_pivot,r=.007)
 a.b((.425,.65,.009),(-.317,1.264,-.404),'glass',group='Cold_Archive_Door',pivot=door_pivot,r=.016)
 a.b((.10,.30,.034),(-.06,.995,-.40),'steel',group='Cold_Archive_Door',pivot=door_pivot,r=.019)
 a.b((.037,.21,.027),(-.07,1.001,-.428),'orange',group='Cold_Archive_Door',pivot=door_pivot,r=.010)
 for y in (.49,1.64):
  a.c((-.638,y,-.30),(-.638,y,-.40),.018,'aluminium',group='Cold_Archive_Door',pivot=door_pivot,n=14)
 # layered insulated chambers in behind door, secure circular sample containers/tube beds
 for yy in (.69,.94,1.19,1.44):
  a.b((.53,.027,.32),(-.322,yy,-.233),'aluminium')
  for xx in (-.50,-.33,-.16):
   a.c((xx,yy+.032,-.19),(xx,yy+.052,-.19),.043,'graphite',n=20)
   a.c((xx,yy+.047,-.19),(xx,yy+.060,-.19),.033,'frost',n=20)
 # multi-drawer right-side core archive with slides and specimen cartridges, individually accessible
 for j,yy in enumerate((.48,.73,.98,1.23,1.48)):
  pivot=(.35,yy,-.37); grp=f'Core_Archive_Drawer_{j+1}'
  a.b((.478,.196,.061),(.346,yy,-.373),'ivory',group=grp,pivot=pivot,r=.023)
  a.b((.42,.027,.014),(.346,yy+.055,-.415),'aluminium',group=grp,pivot=pivot,r=.008)
  a.b((.19,.021,.029),(.346,yy-.011,-.425),'steel',group=grp,pivot=pivot,r=.010)
  a.b((.13,.011,.013),(.346,yy-.011,-.446),'orange',group=grp,pivot=pivot,r=.005)
  # fitted specimen tube with rock layer palette behind drawer, place in recess (avoid poking through drawer facade)
  for i,x in enumerate((.22,.33,.44)):
   a.c((x,yy+.07,-.23),(x,yy+.07,.16),.023,['rock_sand','rock_grey','rock_red'][i],n=14)
 # upper overhang vent faces, backed by recess
 a.b((1.22,.067,.056),(0,1.790,-.341),'graphite',r=.009)
 slots(a,-.56,.56,1.78,-.375,16,'silver')
 # front status lights: illuminated dots on actual stalked mounts, no false readout panel
 for j,xx in enumerate((-.19,-.09,.02)):
  a.c((xx,.332,-.4),(xx,.332,-.42),.020,'steel',n=18)
  a.c((xx,.332,-.423),(xx,.332,-.432),.010,'teal' if j<2 else 'amber',n=16)
 # analogue dial on fixed service strip
 a.b((1.28,.11,.08),(0,.342,-.328),'shell',r=.016)
 a.c((-.45,.34,-.39),(-.45,.34,-.422),.055,'aluminium',n=26)
 a.c((-.45,.34,-.424),(-.45,.34,-.430),.039,'ivory',n=26)
 a.c((-.45,.34,-.431),(-.436,.363,-.436),.004,'orange',n=10)
 # machine exterior panels on sides, edge screws genuinely embedded
 for xx in (-.676,.676):
  a.b((.033,1.35,.50),(xx,1.044,.005),'shell',r=.019)
  for yy in (.47,.95,1.52):
   a.b((.036,.027,.18),(xx,yy,.006),'silver',r=.008)
 # visible right side service cooling line with supported clamps
 a.t([(.54,.46,.30),(.58,.46,.30),(.58,1.70,.30)],.011,'teal')
 for yy in (.60,1.33):a.b((.12,.033,.042),(.60,yy,.30),'aluminium',r=.009)
 desc='Secure cold/dry sample storage for ice, drilled sediment cores and geological specimens.'
 return a.save('Ice and Geological Sample Archive',desc,['Sample analysis','Habitat power','Mission research'],'Open storage door and drawers to retrieve and compare samples',footprint=(1.5,1.5))

if __name__=='__main__':
 results=[make_workbench(),make_microscope(),make_archive()]
 (ROOT/'asset_manifest.json').write_text(json.dumps({'room':'Science Laboratory','theme':'Martian water ice and changing surface geology','status':'modelled / Godot integration pending','models':results},indent=2))
