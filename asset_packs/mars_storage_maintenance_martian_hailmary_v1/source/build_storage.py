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
  scene.metadata={'name':name,'asset_id':self.asset_id,'scale':'metres','up':'+Y','forward':'-Z','interactions':sorted(set([g for g,_ in self.dynamic])),'theme':'Mars habitat maintenance logistics'}
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
           'placement':'free within permitted Storage & Maintenance zone; actual clearance must be tested in Godot', 'base_footprint_m':list(footprint)}
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


# ---- New room assets: fully supported equipment, no decorative floating objects ----
def screw_panel(a,x,y,z,front=-1):
    for dx in [-.022,.022]:
        a.c((x+dx,y,z),(x+dx,y,z-.007),.006,'steel',n=10)

def sturdy_leg(a,x,z,y_top):
    a.b((.074,y_top-.055,.072),(x,(y_top+.055)/2,z),'aluminium',r=.013)
    a.b((.122,.045,.12),(x,.035,z),'graphite',r=.014)
    a.b((.108,.012,.10),(x,.008,z),'rubber',r=.008)


def make_tool_bench():
    a=Model('tool_bench')
    # welded foundation and genuinely supported bench top
    for x in (-.665,.665):
        for z in (-.36,.36): sturdy_leg(a,x,z,.865)
    for z in (-.355,.355):
        a.b((1.31,.072,.058),(0,.18,z),'steel',r=.013)
        a.b((1.31,.050,.058),(0,.73,z),'silver',r=.012)
    a.b((1.45,.060,.82),(0,.842,0),'graphite',r=.032)
    a.b((1.48,.068,.86),(0,.895,-.02),'aluminium',r=.032)
    a.b((1.385,.030,.76),(0,.951,-.02),'ivory',r=.026)
    a.b((1.47,.026,.045),(0,.929,-.443),'steel',r=.008)
    # tall rear fixture: sturdy columns with removable perforated tool panel
    for x in (-.668,.668):
        a.b((.072,1.14,.085),(x,1.48,.350),'silver',r=.014)
        a.b((.104,.078,.13),(x,.995,.349),'graphite',r=.016)
    a.b((1.395,.875,.068),(0,1.54,.347),'graphite',r=.029)
    a.b((1.34,.815,.034),(0,1.54,.300),'shell',r=.026)
    # tool mount slat channels, avoiding hundreds of needless fake holes
    for y in (1.20,1.45,1.71):
        a.b((1.28,.043,.021),(0,y,.270),'aluminium',r=.006)
        a.b((1.22,.015,.014),(0,y+.018,.256),'recess',r=.005)
    # strong shelf with under-braces; all stored props rest on surface
    a.b((1.38,.043,.258),(0,1.995,.255),'aluminium',r=.012)
    a.b((1.29,.015,.237),(0,2.025,.255),'shell',r=.008)
    for x in (-.585,.585):
        a.t([(x,1.77,.320),(x,1.96,.150),(x,1.99,.15)],.020,'silver')
    a.b((1.38,.060,.047),(0,2.04,.365),'graphite',r=.008)
    # Underbench cupboards: genuine door assembly with hinge pivot and latching handle
    for x,side in [(-.45,-1),(.45,1)]:
        a.b((.515,.605,.67),(x,.480,-.01),'graphite',r=.034)
        a.b((.47,.55,.055),(x,.485,-.365),'recess',r=.016)
        pivot=(x+side*.23,.49,-.399)
        group='Tool_Cupboard_Left' if side<0 else 'Tool_Cupboard_Right'
        a.b((.437,.51,.052),(x,.495,-.394),'ivory',group=group,pivot=pivot,r=.027)
        a.b((.395,.065,.019),(x,.710,-.429),'aluminium',group=group,pivot=pivot,r=.012)
        a.b((.062,.167,.033),(x-side*.152,.47,-.438),'steel',group=group,pivot=pivot,r=.013)
        a.b((.028,.126,.014),(x-side*.152,.47,-.46),'orange',group=group,pivot=pivot,r=.007)
        for yy in (.32,.72):
            a.c((pivot[0],yy,-.350),(pivot[0],yy,-.441),.018,'aluminium',n=16)
        for yy in (.32,.38,.44):
            a.b((.22,.012,.010),(x,.0+yy,-.445),'aluminium',group=group,pivot=pivot,r=.004)
    # center open service bay with individually slideable spares tray
    a.b((.30,.60,.61),(0,.47,-.004),'recess',r=.012)
    for z in (-.27,.225): a.b((.275,.025,.035),(0,.20,z),'silver')
    a.b((.285,.047,.54),(0,.26,-.02),'aluminium',group='Spares_Tray',pivot=(0,.25,-.29),r=.012)
    for x in (-.097,0,.097):
        a.c((x,.285,-.12),(x,.32,-.12),.035,'graphite',group='Spares_Tray',pivot=(0,.25,-.29),n=16)
        a.c((x,.320,-.12),(x,.329,-.12),.022,'orange' if x==0 else 'silver',group='Spares_Tray',pivot=(0,.25,-.29),n=16)
    # left physical engineering bench vise with steel jaws connected to anchored screw shaft
    a.b((.265,.06,.23),(-.46,.995,-.13),'steel',r=.022)
    a.b((.25,.100,.13),(-.46,1.058,-.105),'graphite',r=.015)
    a.b((.26,.14,.057),(-.46,1.110,-.04),'aluminium',r=.016)
    p=(-.46,1.08,-.13)
    a.b((.254,.125,.058),(-.46,1.10,-.257),'silver',group='Vise_Moving_Jaw',pivot=p,r=.014)
    a.c((-.46,1.07,-.275),(-.46,1.07,-.36),.017,'steel',group='Vise_Moving_Jaw',pivot=p,n=16)
    a.t([(-.567,1.066,-.355),(-.353,1.066,-.355)],.010,'orange',group='Vise_Moving_Jaw',pivot=p)
    # right work mat and socket-like small spare components that actually rest on the bench
    a.b((.46,.009,.38),(.405,.976,-.153),'rubber',r=.016)
    for i,xx in enumerate((.24,.35,.46,.57)):
        a.c((xx,.990,-.04),(xx,1.032,-.04),.025,'silver',n=18)
        a.c((xx,1.031,-.04),(xx,1.038,-.04),.018,'graphite',n=12)
    # tool rack is mechanically mounted: each tool hangs from fixed pegs or hooks
    for x in (-.52,-.33,-.14,.13,.35,.55):
        a.c((x,1.68,.264),(x,1.68,.215),.012,'steel',n=12)
        a.c((x,1.68,.218),(x,1.68,.210),.017,'aluminium',n=12)
    # straight combination wrenches (shaft, ring, open-end cap) fixed to their hooks
    for x,yy in [(-.52,1.47),(-.33,1.43),(-.14,1.50)]:
        a.b((.027,.275,.020),(x,yy,.195),'silver',r=.011)
        a.r((x,yy-.120,.191),.028,.008,'steel',axis='z')
        a.r((x,yy+.122,.191),.021,.007,'aluminium',axis='z')
    # screwdriver bit and pair of pliers, both with supported tops
    a.b((.038,.175,.023),(.13,1.51,.195),'orange',r=.012)
    a.c((.13,1.58,.19),(.13,1.66,.19),.008,'steel',n=12)
    a.c((.13,1.43,.19),(.13,1.37,.19),.009,'steel',n=12)
    for dx in (-.016,.016):
        a.t([(.35+dx,1.43,.20),(.35+dx*.2,1.57,.20),(.35+dx*.2,1.64,.20)],.010,'steel')
    a.c((.35,1.57,.19),(.35,1.57,.205),.020,'orange',n=14)
    # cordless drill: clipped into shaped holder, supported by two retaining hooks
    a.b((.20,.077,.052),(.54,1.475,.204),'teal',r=.020)
    a.b((.055,.120,.048),(.53,1.385,.198),'graphite',r=.013)
    a.c((.64,1.474,.202),(.72,1.474,.202),.020,'steel',n=14)
    a.b((.26,.024,.035),(.53,1.365,.205),'silver',r=.008)
    # task light on fixed rear arm, not hovering: warm lamp diffuser with physical toggle
    a.b((.10,.14,.10),(.56,1.982,.29),'steel',r=.018)
    a.t([(.56,1.95,.27),(.56,1.96,.01),(.26,1.96,-.08)],.017,'silver')
    a.b((.28,.060,.105),(.27,1.936,-.09),'ivory',r=.024)
    a.b((.25,.010,.084),(.27,1.899,-.09),'light',r=.018)
    a.b((.050,.025,.043),(.59,1.996,.232),'orange',group='Bench_Light_Switch',pivot=(.59,1.996,.232),r=.008)
    # front metal rail secured with four bolts
    for x in (-.62,-.22,.22,.62):
        a.c((x,.917,-.45),(x,.917,-.462),.010,'steel',n=10)
    return a.save('Maintenance Tool Bench','Rugged service bench with anchored hand tools, vice, slide-out spares tray and cupboards.',
        ['Maintenance','Spare parts','Habitat equipment repairs'],
        'Open a tool cupboard, retrieve spares and use the vise to service equipment.',footprint=(1.5,1.5))


def crate(a,x,y,z,w,h,d,group,color='shell',type='case'):
    pv=(x,y,z)
    # shaped polymer cargo crate, reinforced from below; y denotes crate CENTER
    a.b((w,h,d),(x,y,z),color,group=group,pivot=pv,r=.035)
    a.b((w*.91,h*.74,.022),(x,y,z-d*.505),'graphite',group=group,pivot=pv,r=.020)
    a.b((w*.85,h*.66,.025),(x,y,z-d*.52),'shell' if color=='ivory' else 'aluminium',group=group,pivot=pv,r=.014)
    for xx in (-w*.36,w*.36):
        a.b((.032,h*.77,.032),(x+xx,y,z-d*.537),'steel',group=group,pivot=pv,r=.008)
    for xx in (-w*.33,w*.33):
        a.b((.072,.022,.028),(x+xx,y+h*.27,z-d*.55),'orange',group=group,pivot=pv,r=.007)
    a.b((w*.56,.034,.040),(x,y+h*.17,z-d*.55),'graphite',group=group,pivot=pv,r=.010)
    a.b((w*.48,.014,.010),(x,y+h*.17,z-d*.575),'aluminium',group=group,pivot=pv,r=.004)
    # inset grip, crossbars, side corner reinforcement - each tied to shell
    a.b((w*.73,.030,d*.74),(x,y+h*.48,z),'aluminium',group=group,pivot=pv,r=.011)
    for xx in (-w*.44,w*.44):
        a.b((.034,h*.92,d*.11),(x+xx,y,z-d*.45),'steel',group=group,pivot=pv,r=.008)


def make_cargo_rack():
    a=Model('cargo_rack')
    # Rack chassis, welded and bolted, with thick base feet
    for x in (-.665,.665):
        for z in (-.39,.39):
            a.b((.066,1.985,.067),(x,1.065,z),'aluminium',r=.016)
            a.b((.132,.044,.117),(x,.043,z),'graphite',r=.016)
            a.b((.113,.014,.107),(x,.008,z),'rubber',r=.008)
            a.b((.092,.113,.09),(x,.103,z),'steel',r=.014)
    # heavy lower cradle and level shelves, with actual vertical side frame geometry
    a.b((1.44,.10,.86),(0,.142,0),'graphite',r=.026)
    for yy in (.33,1.03,1.71):
        a.b((1.37,.054,.81),(0,yy,0),'steel',r=.019)
        a.b((1.29,.026,.73),(0,yy+.039,.003),'shell',r=.014)
        for z in (-.382,.382):a.b((1.36,.042,.038),(0,yy+.020,z),'aluminium',r=.009)
        for x in (-.66,.66):
            a.b((.040,.090,.79),(x,yy,.002),'steel',r=.012)
    # top enclosure protects contents from dislodgement; rail with connected attachment loops
    a.b((1.44,.085,.87),(0,2.055,0),'ivory',r=.032)
    a.b((1.27,.040,.80),(0,2.005,0),'graphite',r=.016)
    a.b((1.36,.030,.060),(0,2.02,-.427),'aluminium',r=.008)
    # continuous diagonal stiffeners behind shelves (back is +Z)
    a.t([(-.65,.18,.409),(.65,1.99,.409)],.021,'silver')
    a.t([(.65,.18,.410),(-.65,1.99,.410)],.018,'aluminium')
    for y in (.64,1.35):
        for x in (-.66,.66):
            a.b((.09,.16,.065),(x,y,.39),'steel',r=.011)
    # first shelf: 2 equipment cases, each removable as a whole and resting firmly on shelf
    crate(a,-.320,.594,-.005,.58,.45,.62,'Cargo_Case_Lower_Left',color='ivory')
    crate(a,.320,.594,-.005,.58,.45,.62,'Cargo_Case_Lower_Right',color='shell')
    # mid shelf: larger white insulated supply crate (also a separate item)
    crate(a,0,1.322,-.01,1.12,.48,.65,'Supply_Container_Middle',color='ivory')
    # upper shelf: tool/food cases + small rigid canisters, always supported by shelf
    crate(a,-.36,1.882,-.015,.55,.24,.60,'Supply_Case_Upper_Left',color='shell')
    crate(a,.32,1.882,-.015,.54,.24,.60,'Supply_Case_Upper_Right',color='ivory')
    # webbing retaining straps - each mounted to rack at side front (not floating across nowhere)
    for yy in (.52,1.29,1.84):
        a.b((1.34,.020,.018),(0,yy,-.433),'rubber',r=.005)
        for xx in (-.59,.59):
            a.b((.082,.100,.039),(xx,yy,-.435),'graphite',r=.012)
            a.c((xx,yy,-.456),(xx,yy,-.473),.023,'steel',n=14)
            a.c((xx,yy,-.475),(xx,yy,-.482),.013,'orange',n=12)
    # cargo rack tie-down bar in front of bottom rail with explicit lock and hinge pivots
    pivot=(.64,.82,-.445)
    a.b((1.32,.044,.038),(0,.82,-.445),'silver',group='Cargo_Retainer_Bar',pivot=pivot,r=.009)
    for xx in (-.64,.64):
        a.c((xx,.82,-.42),(xx,.82,-.473),.023,'graphite',group='Cargo_Retainer_Bar',pivot=pivot,n=16)
    a.b((.078,.065,.037),(-.61,.82,-.489),'orange',group='Cargo_Retainer_Bar',pivot=pivot,r=.012)
    # in a real habitat, emergency supply cartridges may be stored alongside cargo
    for xx in (-.40,0,.40):
        a.b((.115,.065,.13),(xx,.239,.285),'steel',r=.014)
        a.c((xx,.245,.285),(xx,.308,.285),.037,'teal',n=16)
    # structural side location strips, not text labels or imaginary monitors
    for x in (-.690,.690):
        a.b((.017,.68,.15),(x,1.48,-.15),'shell',r=.005)
        for yy in (1.23,1.43,1.63):
            a.b((.022,.035,.12),(x,yy,-.15),'orange',r=.004)
    return a.save('Secured Cargo Rack','Three levels of strapped, removable cargo cases with reinforced frame and locking retainer.',
        ['Storage logistics','Maintenance spares','Mission resupply'],
        'Release cargo restraint and retrieve a stored case for repairs or mission preparation.',footprint=(1.5,1.5))

if __name__=='__main__':
    models=[make_tool_bench(),make_cargo_rack()]
    (ROOT/'asset_manifest.json').write_text(json.dumps({'room':'Storage & Maintenance','style':'The Martian + Project Hail Mary inspired; original design','state':'modelled, actual-game integration pending','models':models},indent=2))
