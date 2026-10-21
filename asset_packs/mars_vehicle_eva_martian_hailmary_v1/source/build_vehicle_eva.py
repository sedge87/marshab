#!/usr/bin/env python3
"""Original Mars habitat storage and maintenance 3D models.
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
    MATERIALS[name]=trimesh.visual.material.PBRMaterial(name=f'Storage_{name}',baseColorFactor=np.array(rgbvals+[alpha],dtype=np.uint8),metallicFactor=metal,roughnessFactor=rough,emissiveFactor=emissive,alphaMode='BLEND' if alpha<255 else 'OPAQUE',doubleSided=name in ['glass','clear'])

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
  scene.metadata={'name':name,'asset_id':self.asset_id,'scale':'metres','up':'+Y','forward':'-Z','interactions':sorted(set([g for g,_ in self.dynamic])),'theme':'Mars habitat EVA and rover servicing'}
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
           'placement':'Vehicle Bay / EVA zone; placement and clearance need testing in Godot', 'base_footprint_m':list(footprint)}
  if bounds[0][1]<-.008:raise ValueError('Below floor '+str(summary))
  if dims[0]>footprint[0]+.025 or dims[2]>footprint[1]+.025:raise ValueError('Footprint too large '+str(summary))
  (ROOT/(self.asset_id+'_manifest.json')).write_text(json.dumps(summary,indent=2))
  print(json.dumps(summary,indent=2),flush=True)
  return summary


def bolt_row(a,y,z,xs):
 for x in xs:a.c((x,y,z-.006),(x,y,z+.004),.009,'steel',n=12)

def suit_rack():
 a=Model('suit_rack')
 # weighted upright cabinet frame and rails
 a.b((1.43,.14,.93),(0,.11,.02),'graphite',r=.04)
 for x in (-.64,.64):
  for z in (-.37,.37):a.b((.068,1.93,.073),(x,1.08,z),'silver')
 for y in (.25,1.22,2.01):
  a.b((1.33,.068,.08),(0,y,-.38),'aluminium')
  a.b((1.33,.068,.08),(0,y,.37),'aluminium')
 for x in (-.68,.68):a.b((.06,1.62,.63),(x,1.12,.0),'shell',r=.013)
 a.b((1.30,.24,.09),(0,1.93,.34),'shell')
 for ix,x in enumerate((-.315,.315)):
  # backed equipment dock and clamped shoulders
  a.b((.54,1.69,.085),(x,1.08,.26),'recess',r=.045)
  a.b((.49,.08,.30),(x,.33,-.04),'graphite',r=.03)
  a.b((.46,.095,.29),(x,.39,-.03),'rubber',r=.025)
  a.b((.49,.10,.12),(x,1.75,.25),'aluminium',r=.025)
  # restrained torso garment with arm, boot and helmet volumes, not floating
  group=f'suit_{ix+1}_service'
  a.b((.32,.56,.25),(x,1.25,-.09),'ivory',group=group,pivot=(x,.79,-.12),r=.085)
  a.b((.33,.13,.255),(x,1.53,-.09),'aluminium',group=group,r=.035)
  a.b((.26,.23,.20),(x,.88,-.08),'shell',group=group,r=.055)
  for side in (-1,1):
   sx=x+side*.215
   a.b((.095,.43,.15),(sx,1.30,-.055),'shell',group=group,r=.044)
   a.b((.12,.13,.15),(sx,1.05,-.055),'graphite',group=group,r=.037)
   lx=x+side*.105
   a.b((.135,.40,.17),(lx,.60,-.06),'shell',group=group,r=.049)
   a.b((.145,.13,.235),(lx,.32,-.105),'graphite',group=group,r=.032)
  # helmet: tapered crown, dark visor face front (-z)
  a.cone((x,1.62,-.08),(x,1.88,-.08),.155,.09,'ivory',group=group)
  a.b((.23,.145,.035),(x,1.73,-.215),'graphite',group=group,r=.04)
  a.b((.21,.105,.018),(x,1.74,-.238),'glass',group=group,r=.03)
  a.c((x,1.75,.04),(x,1.75,.24),.035,'steel',group=group)
  # rigid shoulder stabilisers
  a.c((x-.22,1.58,-.09),(x+.22,1.58,-.09),.027,'steel',n=16)
  # actual suit supply hose onto back connection
  a.t([(x+.12,.43,.23),(x+.2,.63,.23),(x+.18,1.15,.23),(x+.06,1.40,.0)],.017,'teal')
  for y in (.60,1.25):
   a.b((.11,.055,.035),(x,y,-.245),'orange',group=group,r=.012)
  a.b((.25,.075,.04),(x,1.95,-.393),'light')
 a.b((.35,.11,.08),(0,.13,-.46),'graphite')
 return a.save('Dual EVA Suit Service Rack','Two secured suit docks with service umbilicals, boots, helmets and storage restraints', ['power','EVA'], 'Inspect and prepare the EVA suits')

def rover_charger():
 a=Model('rover_charger')
 # low pad floor plinth and angled service housing
 a.b((1.42,.12,.99),(0,.10,0),'graphite',r=.05)
 for x in (-.61,.61):
  for z in (-.39,.39):a.b((.12,.045,.12),(x,.03,z),'rubber')
 a.b((1.20,1.14,.62),(0,.76,.16),'shell',r=.065)
 a.b((1.24,.09,.66),(0,1.36,.16),'silver')
 for x in (-.46,.46):
  a.b((.17,.85,.068),(x,.84,-.18),'aluminium',r=.025)
 # charger hub physical connector face
 a.b((.89,.66,.042),(0,.95,-.181),'recess',r=.05)
 a.b((.82,.47,.048),(0,.98,-.218),'steel',r=.04)
 for i,x in enumerate((-.26,0,.26)):
  a.b((.13,.20,.065),(x,.99,-.259),'aluminium',r=.025)
  for y in (.91,1.0,1.09):a.b((.055,.029,.016),(x,y,-.299),'orange' if i==1 else 'teal',r=.006)
 # substantial removable cable cassette and spool
 a.b((.48,.55,.20),(.33,.48,-.34),'graphite',r=.08)
 a.c((.33,.47,-.49),(.33,.47,-.65),.18,'steel',n=28)
 a.c((.33,.47,-.65),(.33,.47,-.68),.145,'rubber',n=28)
 a.r((.33,.47,-.684),.118,.012,'orange',axis='z')
 a.c((.33,.47,-.69),(.33,.47,-.735),.048,'graphite',n=20)
 # dockable cable runs physically from spool to plug at front lower left
 a.t([(.22,.45,-.66),(.10,.25,-.74),(-.25,.22,-.75),(-.43,.31,-.64),(-.43,.49,-.48)],.028,'rubber')
 group='charging_plug'
 a.b((.17,.12,.17),(-.43,.49,-.50),'ivory',group=group,pivot=(-.43,.49,-.50),r=.028)
 a.b((.115,.075,.055),(-.43,.49,-.62),'graphite',group=group,r=.014)
 for x in (-.464,-.396):a.c((x,.49,-.65),(x,.49,-.68),.012,'steel',group=group,n=12)
 # lower service hatch and hinged door
 a.b((.42,.22,.043),(-.35,.42,-.205),'aluminium',r=.026)
 a.b((.36,.15,.02),(-.35,.42,-.237),'shell',group='service_hatch',pivot=(-.53,.42,-.24),r=.026)
 a.b((.10,.028,.027),(-.18,.42,-.265),'graphite',group='service_hatch')
 for x in (-.48,-.22):a.b((.055,.019,.025),(x,1.28,-.185),'amber')
 return a.save('Rover Charging Station','Charging cabinet with cable reel, detachable plug, status indicators and service compartment',['power','rover'], 'Connect charging plug to prepare a rover')

def eva_tools():
 a=Model('eva_tool_station')
 a.b((1.43,.13,.87),(0,.12,0),'graphite',r=.04)
 for x in (-.62,.62):
  for z in (-.35,.34):a.b((.085,1.65,.076),(x,.91,z),'aluminium')
 a.b((1.32,.11,.84),(0,.87,-.005),'ivory',r=.045)
 a.b((1.27,.045,.78),(0,.95,-.005),'steel')
 a.b((1.39,.84,.10),(0,1.49,.34),'shell',r=.05)
 a.b((1.24,.64,.02),(0,1.51,.278),'graphite',r=.022)
 # mounted tools with obvious physical attachment fixtures
 for i,x in enumerate((-.43,-.16,.13,.40)):
  a.b((.085,.05,.065),(x,1.79,.235),'aluminium')
  a.b((.085,.05,.065),(x,1.25,.235),'aluminium')
  if i==0: # wrench
   a.c((x,1.30,.19),(x,1.73,.19),.020,'steel')
   a.r((x,1.78,.19),.051,.014,'steel',axis='z')
  elif i==1: # brush
   a.c((x,1.30,.18),(x,1.67,.18),.022,'orange')
   a.b((.11,.095,.12),(x,1.74,.18),'graphite')
  elif i==2: # sample scraper
   a.c((x,1.32,.18),(x,1.60,.18),.018,'aluminium')
   a.b((.16,.075,.075),(x,1.67,.18),'steel')
  else: # torque handle
   a.c((x,1.30,.18),(x,1.69,.18),.022,'steel')
   a.c((x-.08,1.68,.18),(x+.08,1.68,.18),.026,'orange')
 # worktop recessed cleaning dish and equipment case
 a.b((.31,.04,.27),(-.40,1.00,-.16),'recess',r=.055)
 a.b((.26,.025,.22),(-.40,1.025,-.16),'silver',r=.048)
 a.b((.47,.25,.29),(.30,1.09,-.10),'graphite',r=.035)
 a.b((.43,.19,.27),(.30,1.27,-.11),'shell',group='case_lid',pivot=(.30,1.19,.015),r=.033)
 a.b((.135,.038,.024),(.30,1.15,-.26),'orange')
 a.b((1.18,.51,.67),(0,.53,.02),'shell',r=.045)
 for x in (-.34,.34):
  a.b((.50,.39,.055),(x,.56,-.345),'ivory',group=f'cabinet_door_{"left" if x<0 else "right"}',pivot=(x+(-.24 if x<0 else .24),.56,-.35),r=.025)
  a.b((.08,.025,.042),(x+(.16 if x<0 else -.16),.55,-.385),'graphite',group=f'cabinet_door_{"left" if x<0 else "right"}')
 # small wall-mounted task emitter with physical support
 a.c((.53,1.93,.29),(.53,1.98,.11),.026,'aluminium')
 a.b((.23,.06,.14),(.53,1.98,.02),'silver',r=.027)
 a.b((.17,.013,.09),(.53,1.944,.02),'light',r=.007)
 return a.save('EVA Tool and Dust Service Station','Secured tools, sample cleaning tray, enclosed supplies and task light',['maintenance','EVA','samples'],'Prepare and clean tools before surface work')

if __name__=='__main__':
 summaries=[suit_rack(),rover_charger(),eva_tools()]
 (ROOT/'asset_manifest.json').write_text(json.dumps({'phase':'Vehicle Bay and EVA','assets':summaries},indent=2))
