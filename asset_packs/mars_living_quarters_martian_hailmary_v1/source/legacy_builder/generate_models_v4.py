"""Build original retro-industrial Mars habitat furniture for Godot 4.
Coordinates: metres; Y up; -Z front; world origin at floor centre.
Dependencies: trimesh, numpy, pillow, vtk (preview only).
Models: task_light, privacy_divider, exercise_station.
"""
from __future__ import annotations
import os, math, json, io, copy
from collections import defaultdict
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from trimesh.visual.material import PBRMaterial

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT,'models'); os.makedirs(MODEL,exist_ok=True)

PAL = {
 'graphite':([29,36,39,255],.42,.52),
 'deep':([11,16,17,255],.21,.67),
 'steel':([107,120,117,255],.82,.34),
 'bone':([171,166,145,255],.21,.69),
 'satinsteel':([153,158,143,255],.77,.36),
 'cream':([212,201,171,255],.13,.78),
 'ochre':([217,122,51,255],.14,.51),
 'fabric':([138,133,110,255],0,.96),
 'fabricdark':([82,89,79,255],0,.96),
 'olive':([69,92,76,255],0,.94),
 'rubber':([35,42,41,255],0,.91),
 'blackglass':([12,17,18,255],.12,.13),
 'lamp':([255,199,110,255],0,.42),
 'lamp_off':([165,157,122,255],0,.62),
 'warning':([246,197,83,255],0,.72),
 'pale_blue':([109,164,157,255],0,.52),
}
MATS={}
for n,(rgba,metal,rough) in PAL.items():
 kwargs={'name':n,'baseColorFactor':np.array(rgba,dtype=np.uint8),'metallicFactor':metal,'roughnessFactor':rough,'doubleSided':True}
 if n=='lamp': kwargs['emissiveFactor']=[0.8,0.53,0.22]
 MATS[n]=PBRMaterial(**kwargs)

FONT_BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_MONO='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'


def image_text(title,sub='',w=512,h=170, dark=True):
 im=Image.new('RGBA',(w,h),(22,30,31,255) if dark else (198,184,153,255))
 d=ImageDraw.Draw(im)
 d.rectangle((5,5,w-6,h-6), outline=(171,144,88,255),width=3)
 d.rectangle((17,17,23,h-18),fill=(226,140,51,255))
 try:
  ft=ImageFont.truetype(FONT_BOLD, min(35,int(w*.07)))
  fs=ImageFont.truetype(FONT_MONO, min(20,int(w*.04)))
 except: ft=fs=ImageFont.load_default()
 d.text((35,20),title,font=ft,fill=(229,221,194,255))
 d.line((36,h-52,w-28,h-52),fill=(118,157,132,255),width=2)
 d.text((36,h-42),sub,font=fs,fill=(142,179,159,255))
 return im


def fabric_texture():
 r=np.random.default_rng(78); w=h=256
 ar=np.zeros((h,w,4),dtype=np.uint8)
 noise=r.normal(0,3,(h,w))
 for y in range(h):
  for x in range(w):
   pat = (math.sin(x*2.3)+math.sin(y*1.9))*1.8 + noise[y,x]
   ar[y,x,:3]=np.clip(np.array([132,129,108])+pat,0,255)
   ar[y,x,3]=255
 return Image.fromarray(ar,'RGBA')
FAB_IM=fabric_texture()
MATS['woven'] = PBRMaterial(name='woven',baseColorFactor=np.array([255]*4,dtype=np.uint8),baseColorTexture=FAB_IM,metallicFactor=0.0,roughnessFactor=0.99,doubleSided=True)


def label_material(name,title,subtitle,w=512,h=170):
 mat=PBRMaterial(name=name,baseColorTexture=image_text(title,subtitle,w,h),baseColorFactor=np.array([255]*4,dtype=np.uint8), metallicFactor=0.03,roughnessFactor=.66,doubleSided=True)
 MATS[name]=mat
 return name

def screen_material(name,lines,w=512,h=310):
 im=Image.new('RGBA',(w,h),(10,25,26,255)); d=ImageDraw.Draw(im)
 d.rectangle((4,4,w-5,h-5), outline=(67,107,100,255),width=3)
 for y in range(17,h,11): d.line((12,y,w-15,y),fill=(14,33,33,255),width=1)
 try: title=ImageFont.truetype(FONT_BOLD,31); text=ImageFont.truetype(FONT_MONO,22)
 except: title=text=ImageFont.load_default()
 d.text((24,22),lines[0],fill=(196,216,189,255),font=title)
 d.line((24,68,w-26,68), fill=(224,141,50,255),width=3)
 for i,line in enumerate(lines[1:]):
  d.text((24,94+i*40),line, fill=(121,208,167,255),font=text)
 MATS[name]=PBRMaterial(name=name,baseColorTexture=im,baseColorFactor=np.array([255]*4,dtype=np.uint8), metallicFactor=0,roughnessFactor=.36,doubleSided=True,emissiveFactor=[.2,.3,.24]); return name

class Maker:
 def __init__(self): self.parts=defaultdict(list)
 def add(self, mesh, mat='graphite', group='static'):
  if mesh is None: return
  if not isinstance(mesh,list): meshes=[mesh]
  else: meshes=mesh
  for x in meshes:
   if x is not None and len(x.faces)>0: self.parts[(group,mat)].append(x)
 def box(self,w,h,d,x,y,z,mat='graphite',group='static',angle=None):
  mesh=trimesh.creation.box(extents=[w,h,d]);
  if angle is not None: mesh.apply_transform(trimesh.transformations.rotation_matrix(angle,[0,1,0]));
  mesh.apply_translation([x,y,z]); self.add(mesh,mat,group);return mesh
 def bevel(self,w,h,d,x,y,z,rad=.018,mat='graphite',group='static',angle=None):
  # rectangle prism with 45deg trims at its four XY silhouette corners, smooth facet-free
  rr=min(rad,w*.22,h*.22); hw=w/2;hh=h/2
  pts=[(-hw+rr,-hh),(hw-rr,-hh),(hw,-hh+rr),(hw,hh-rr),(hw-rr,hh),(-hw+rr,hh),(-hw,hh-rr),(-hw,-hh+rr)]
  v=np.array([[a,b,-d/2] for a,b in pts]+[[a,b,d/2] for a,b in pts],dtype=float)
  faces=[]
  for i in range(1,7):faces.append([0,i+1,i]); faces.append([8,8+i,8+i+1])
  for i in range(8): j=(i+1)%8; faces+= [[i,j,8+j],[i,8+j,8+i]]
  mesh=trimesh.Trimesh(vertices=v,faces=faces,process=False)
  if angle is not None: mesh.apply_transform(trimesh.transformations.rotation_matrix(angle,[0,1,0]))
  mesh.apply_translation([x,y,z]); self.add(mesh,mat,group);return mesh
 def cyl(self,r,h,x,y,z,mat='steel',group='static',axis='y',sections=20):
  mesh=trimesh.creation.cylinder(radius=r,height=h,sections=sections)
  if axis=='y': mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
  if axis=='x': mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
  mesh.apply_translation([x,y,z]);self.add(mesh,mat,group);return mesh
 def seg(self,a,b,r=.014,mat='steel',group='static',sections=16):
  a=np.array(a,float);b=np.array(b,float);dv=b-a;L=np.linalg.norm(dv)
  if L<1e-8:return
  mesh=trimesh.creation.cylinder(radius=r,height=L,sections=sections)
  mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],dv/L))
  mesh.apply_translation((a+b)/2);self.add(mesh,mat,group);return mesh
 def tube_path(self,pts,r=.009,mat='rubber',group='static',sections=12):
  for a,b in zip(pts[:-1],pts[1:]):self.seg(a,b,r,mat,group,sections)
  for q in pts[1:-1]:self.sphere(r*1.1,*q,mat=mat,group=group,sub=1)
 def sphere(self,r,x,y,z,mat='steel',group='static',sub=1,scale=None):
  mesh=trimesh.creation.icosphere(subdivisions=sub,radius=r)
  if scale: mesh.apply_scale(scale) # scale per vertex if non-uniform
  mesh.apply_translation([x,y,z]); self.add(mesh,mat,group)
 def plane(self,w,h,x,y,z,mat='woven',group='static',angle=0):
  mesh=trimesh.Trimesh(vertices=[[-w/2,-h/2,0],[w/2,-h/2,0],[w/2,h/2,0],[-w/2,h/2,0]],faces=[[0,2,1],[0,3,2]],process=False)
  mesh.visual=trimesh.visual.TextureVisuals(uv=np.array([[0,0],[1,0],[1,1],[0,1]],dtype=float),material=MATS[mat])
  if angle:mesh.apply_transform(trimesh.transformations.rotation_matrix(angle,[0,1,0]))
  mesh.apply_translation([x,y,z]);self.parts[(group,mat)].append(mesh)
 def fastener(self,x,y,z,group='static',radius=.009):
  self.cyl(radius,.005,x,y,z,mat='satinsteel',group=group,axis='z',sections=12)
  self.box(radius*1.1,.002,.006,x,y,z-.003,mat='deep',group=group)
 def export(self,path):
  sc=trimesh.Scene();count=0
  for (grp,mat), meshes in self.parts.items():
   # Keep moving/interactive components named; merge static geometry per material.
   chunk=trimesh.util.concatenate(meshes)
   # Cannot concatenate textured label planes with separate material names? All same material yes.
   if any(getattr(z.visual,'kind',None)=='texture' for z in meshes):
    uvs=[]
    for z in meshes:
     if getattr(z.visual,'kind',None)=='texture':uvs.append(np.array(z.visual.uv))
     else:uvs.append(np.zeros((len(z.vertices),2)))
    chunk.visual=trimesh.visual.TextureVisuals(uv=np.concatenate(uvs,axis=0),material=MATS[mat])
   else:chunk.visual=trimesh.visual.TextureVisuals(material=MATS[mat])
   sc.add_geometry(chunk,node_name=f'{grp}__{mat}',geom_name=f'{grp}__{mat}')
   count+=1
  sc.export(path)
  check=trimesh.load(path,force='scene')
  faces=sum(len(g.faces) for g in check.geometry.values())
  assert len(check.geometry)==count
  if 'task_light' not in path: assert abs(check.bounds[0][1])<.06, f'floor origin mismatch {check.bounds}'
  return {'meshes':count,'triangles':faces,'bounds_m':np.round(check.bounds,3).tolist(),'materials':len(set(getattr(x.visual.material,'name','') for x in check.geometry.values()))}

# ---- TASK LIGHT: 1.25m high wall bracket with double-link articulating mechanism ----
def make_task_light():
 b=Maker()
 # steel wall mount base is physically attached to rear plate; back surface +Z
 b.bevel(.29,.40,.075,0,1.42,.025,rad=.022,mat='graphite')
 b.bevel(.248,.34,.015,0,1.42,-.020,rad=.014,mat='cream')
 b.bevel(.232,.074,.021,0,1.554,-.032,rad=.009,mat='deep')
 m=label_material('task_nameplate','ARES / TASK-07','24V   /   CREW LIGHT')
 b.plane(.202,.060,0,1.556,-.044,mat=m)
 # ventilation grille at bottom of plate
 for xx in np.linspace(-.095,.095,7):b.box(.012,.028,.008,xx,1.289,-.034,'graphite')
 for x in [-.112,.112]:
  for y in [1.267,1.575]:b.fastener(x,y,-.041)
 # wall protruding pivot castle into arm
 b.cyl(.082,.11,0,1.42,-.088,mat='graphite',axis='z',sections=24,group='Root_Pivot')
 b.cyl(.058,.119,0,1.42,-.090,mat='satinsteel',axis='z',group='Root_Pivot')
 b.cyl(.032,.126,0,1.42,-.090,mat='deep',axis='z',group='Root_Pivot')
 # double structural linkage, paired rails in two Z offsets, actual connected endpoints
 P0=np.array([0.,1.42,-.11]);P1=np.array([-.27,1.57,-.31]);P2=np.array([-.58,1.40,-.53])
 for zshift in [-.026,.026]:
  q0=P0+np.array([0,0,zshift]);q1=P1+np.array([0,0,zshift]);q2=P2+np.array([0,0,zshift])
  b.seg(q0,q1,.026,'steel','Arm_Assembly',sections=14)
  b.seg(q1,q2,.025,'steel','Arm_Assembly',sections=14)
  b.seg(q0+np.array([.01,.035,0]),q1+np.array([.01,.035,0]),.008,'satinsteel','Arm_Assembly',sections=12)
 for p in [P1,P2]:
  b.cyl(.067,.101,*p,mat='graphite',axis='z',group='Arm_Assembly',sections=24)
  b.cyl(.044,.108,*p,mat='satinsteel',axis='z',group='Arm_Assembly')
  b.cyl(.024,.116,*p,mat='ochre',axis='z',group='Arm_Assembly')
 # physically connected cable along underside + clipped to linkage
 b.tube_path([P0+[0,-.057,0],[-.11,1.40,-.18],P1+[0,-.063,0],[-.40,1.39,-.44],P2+[0,-.044,0]],.010,'rubber','Arm_Assembly')
 for p in [(-.13,1.435,-.227),(-.40,1.475,-.4)]: b.box(.041,.021,.092,*p,mat='deep',group='Arm_Assembly')
 # bolted thick lamp head; pivot is physically anchored to arm P2.
 x,y,z=-.64,1.34,-.59
 b.seg(P2,(-.62,1.36,-.56),.045,'graphite','Lamp_Head',sections=18)
 b.bevel(.32,.15,.215,x,y,z,rad=.037,mat='graphite',group='Lamp_Head')
 b.bevel(.294,.116,.219,x,y,z,rad=.028,mat='cream',group='Lamp_Head')
 b.box(.27,.029,.22,x,y+.081,z,mat='steel',group='Lamp_Head')
 # face/luminaire pointed towards viewer with bottom lip and frosted panels
 b.bevel(.266,.086,.012,x,y-.012,z-.117,rad=.015,mat='deep',group='Lamp_Head')
 b.bevel(.222,.055,.014,x,y-.01,z-.127,rad=.010,mat='lamp',group='Lamp_Emitter')
 for dx in [-.088,-.044,0,.044,.088]:b.box(.006,.054,.004,x+dx,y-.01,z-.138,'satinsteel','Lamp_Head')
 b.box(.234,.018,.019,x,y-.070,z-.12,'ochre','Lamp_Head')
 # metal side grills and end screws
 for xx in [-.125,.125]:
  b.cyl(.011,.01,x+xx,y+.027,z-.125,'steel','Lamp_Head',axis='z',sections=10)
  b.fastener(x+xx,y+.027,z-.134,group='Lamp_Head',radius=.007)
 # local button on lamp housing
 b.cyl(.016,.016,x+.122,y+.077,z-.05,'ochre','Lamp_Head',axis='y')
 # note no standalone floating screen or free-hanging parts
 return b

# ---- PRIVACY DIVIDER: foldable acoustic screen with structural feet and hinges ----
def make_privacy_divider():
 b=Maker();panel_w=.77; h=1.61; yc=.94; z=0
 # Three physical frame leaves attached to adjacent hinge posts, with fold angles.
 # centre x =0, wings hinged at ±0.393. Use rotation about hinge Y axis.
 for side,(x0,ang,name) in enumerate([(-.78,math.radians(-24),'Panel_Left'),(0,0,'Panel_Centre'),(.78,math.radians(24),'Panel_Right')]):
  # panel local plane supports Y-axis rotation, x0 is centre of frame
  # transform world around hinge positions at ±.391: local center -+.39, rotate via Y axis
  hinge_x= -panel_w/2 if side==0 else panel_w/2 if side==2 else 0
  def xf(localx,localy,localz):
   if side==1:return (localx,localy,localz)
   # left panel local frame extends left of hinge by panel width; right extends right
   # use 0 at hinge for localx. panel centre offset +/- panel_w/2
   xx = localx + (-panel_w/2 if side==0 else panel_w/2)
   xr=xx*math.cos(ang)+localz*math.sin(ang)
   zr=-xx*math.sin(ang)+localz*math.cos(ang)
   return (hinge_x+xr,localy,zr)
  def pp(localx,localy,localz):return xf(localx,localy,localz)
  def box(w,hh,dd,x,y,z,mat,grp=name):
   xx,yy,zz=xf(x,y,z)
   geom=trimesh.creation.box(extents=[w,hh,dd]);geom.apply_transform(trimesh.transformations.rotation_matrix(ang,[0,1,0]));geom.apply_translation([xx,yy,zz]);b.add(geom,mat,grp)
  def bevel(w,hh,dd,x,y,z,rad,mat,grp=name):
   mm=Maker();mm.bevel(w,hh,dd,0,0,0,rad,mat,grp)
   for mesh in mm.parts[(grp,mat)]:
    mesh.apply_transform(trimesh.transformations.rotation_matrix(ang,[0,1,0]));mesh.apply_translation(xf(x,y,z));b.add(mesh,mat,grp)
  def plane(w,hh,x,y,z,mat,grp=name):
   mm=Maker();mm.plane(w,hh,0,0,0,mat,grp)
   for mesh in mm.parts[(grp,mat)]:mesh.apply_transform(trimesh.transformations.rotation_matrix(ang,[0,1,0]));mesh.apply_translation(xf(x,y,z));b.add(mesh,mat,grp)
  # structural frame, center skin and padded insert, nested not floating
  bevel(.777,1.68,.092,0,yc,0,.028,'graphite')
  bevel(.726,1.555,.100,0,yc+.01,-.002,.022,'bone')
  bevel(.681,1.410,.104,0,yc+.008,-.005,.034,'fabricdark')
  bevel(.651,1.378,.105,0,yc+.008,-.010,.038,'woven')
  # tinted fabric with real material texture on mesh surface, not standalone decal
  plane(.63,1.36,0,yc+.008,-.065,'woven')
  # fabric stitched channels, subtle ribbing inside the inset
  for row in range(1,7):
   box(.622,.004,.003,0,.265+row*.195,-.069,'fabricdark')
  # hard side channels and reinforced top rail
  for sx in [-.367,.367]:
   box(.032,1.64,.11,sx,yc,.004,'satinsteel')
   for yy in [.26,1.62]:
    # protruding round fastener sitting on frame not fabric
    xx,yyy,zz=pp(sx,yy,-.060)
    b.cyl(.011,.008,xx,yyy,zz,'steel',name,axis='z',sections=12)
  box(.69,.044,.115,0,1.764,0,'cream')
  box(.69,.043,.116,0,.127,0,'steel')
  # protective moulding and area numbering at top
  label_material('divider_label_'+str(side),'ARES / PRIVACY',f'SCREEN - {side+1:02d}',512,170)
  plane(.174,.06,-.22,1.719,-.062,'divider_label_'+str(side))
  # hardware feet securely cross braced to the panel frame in each leaf
  for sx in [-.29,.29]:
   box(.046,.15,.068,sx,.13,.016,'graphite')
   box(.10,.042,.54,sx,.042,.02,'steel')
   for zz in [-.224,.26]: box(.107,.02,.11,sx,.015,zz,'rubber')
 # Solid hinges on both left/right, connecting both leaves across gap
 for x,group in [(-panel_w/2,'Hinges_Left'),(panel_w/2,'Hinges_Right')]:
  b.seg((x,.25,0),(x,1.70,0),.018,'satinsteel',group)
  for yy in [.38,.91,1.46]:
   b.cyl(.032,.11,x,yy,-.006,'graphite',group,axis='y',sections=16)
   b.cyl(.020,.116,x,yy,-.006,'ochre',group,axis='y',sections=16)
 return b

# ---- EXERCISE STATION: compact seated resistance system ----
def make_exercise_station():
 b=Maker();
 # structural base, front = -Z, back = +Z; high stability floor standing
 for x in [-.52,.52]:
  b.bevel(.12,.11,1.23,x,.10,-.055,.023,'graphite')
  b.box(.12,.025,.21,x,.028,-.57,'rubber')
  b.box(.12,.025,.21,x,.028,.47,'rubber')
 b.box(1.12,.10,.14,0,.12,.47,'steel')
 b.box(.95,.075,.16,0,.15,-.50,'steel')
 # rear structure: two square columns with central machine guarded by cream shell
 for x in [-.48,.48]:
  b.bevel(.105,1.97,.12,x,1.04,.38,.020,'graphite')
  b.bevel(.070,1.85,.015,x,1.07,.307,.010,'satinsteel')
 b.box(1.09,.115,.14,0,1.97,.37,'steel')
 b.bevel(.97,.075,.155,0,2.04,.36,.016,'cream')
 b.box(1.05,.095,.135,0,.47,.39,'steel')
 # integral lower panel blocks view of rear weight stack cavity
 b.bevel(.84,1.10,.19,0,1.03,.445,.025,'graphite')
 b.bevel(.77,1.01,.04,0,1.05,.334,.029,'cream')
 b.bevel(.69,.57,.05,0,.905,.305,.014,'deep')
 # weight stack: distinct stack layers housed behind front guard
 for i in range(7):
  yy=.67+i*.060
  b.bevel(.37,.044,.076,0,yy,.264,.007,'steel',group='Resistance_Stack')
  b.box(.016,.016,.010,.155,yy,.212,'ochre',group='Resistance_Stack')
 # selector pin physically keyed into slotted stack at bottom
 b.cyl(.013,.077,-.04,.825,.205,'ochre',group='Resistance_Stack',axis='z',sections=16)
 b.cyl(.026,.010,-.04,.825,.165,'graphite',group='Resistance_Stack',axis='z')
 # internal twin guide rods extend from anchored deck to reinforced top
 for x in [-.235,.235]:
  b.seg((x,.61,.23),(x,1.62,.23),.014,'satinsteel','Resistance_Stack')
 # upper mechanical pulley cowl (fixed to crossbeam via two brackets)
 for x in [-.32,.32]:
  b.box(.07,.18,.13,x,1.89,.25,'graphite')
  b.cyl(.071,.041,x,1.88,.169,'steel','Cable_Pulleys',axis='z',sections=24)
  b.cyl(.045,.046,x,1.88,.157,'deep','Cable_Pulleys',axis='z')
  b.cyl(.021,.050,x,1.88,.151,'ochre','Cable_Pulleys',axis='z')
 # rigid handle support pulleys to gooseneck cable route, anchored to frame
 for x in [-.32,.32]:
  b.seg((x,1.89,.15),(x,1.40,-.18),.011,'rubber','Cable_Run',sections=14)
  b.seg((x,1.40,-.18),(x,1.23,-.38),.011,'rubber','Cable_Run',sections=14)
  b.sphere(.016,x,1.40,-.18,'rubber','Cable_Run',sub=1)
  b.cyl(.029,.036,x,1.23,-.392,'satinsteel','Grip_L' if x<0 else 'Grip_R',axis='z',sections=14)
  b.seg((x,1.23,-.40),(x,1.10,-.43),.014,'steel','Grip_L' if x<0 else 'Grip_R')
  b.seg((x-.087,1.10,-.45),(x+.087,1.10,-.45),.023,'rubber','Grip_L' if x<0 else 'Grip_R',sections=20)
  for side_x in [x-.073,x+.073]:b.cyl(.029,.02,side_x,1.10,-.45,'ochre','Grip_L' if x<0 else 'Grip_R',axis='x')
 # compact forward seat and structural bracing (no disconnected floating cushion)
 b.seg((-.32,.63,.27),(-.32,.66,-.25),.036,'satinsteel','Seat_Frame')
 b.seg((.32,.63,.27),(.32,.66,-.25),.036,'satinsteel','Seat_Frame')
 b.seg((-.29,.14,-.32),(-.29,.64,-.19),.039,'steel','Seat_Frame')
 b.seg((.29,.14,-.32),(.29,.64,-.19),.039,'steel','Seat_Frame')
 b.bevel(.64,.072,.53,0,.68,-.18,.033,'graphite','Seat_Frame')
 b.bevel(.61,.077,.49,0,.741,-.18,.034,'olive','Seat_Cushion')
 # upholstered support/backrest, physically braced by mounts to rear panel
 for x in [-.23,.23]:
  b.seg((x,.68,.26),(x,1.26,.15),.029,'steel','Seat_Frame')
 b.bevel(.58,.53,.12,0,1.09,.13,.05,'graphite','Seat_Frame')
 b.bevel(.53,.48,.13,0,1.095,.055,.054,'olive','Backrest_Cushion')
 # large front non-slip footplate joined by two slanted braces to frame
 for x in [-.31,.31]:b.seg((x,.16,-.43),(x,.18,-.76),.040,'steel','Foot_Rest')
 b.bevel(.74,.035,.28,0,.203,-.72,.03,'graphite','Foot_Rest')
 for x in np.linspace(-.31,.31,8):b.box(.009,.006,.227,x,.227,-.72,'satinsteel','Foot_Rest')
 # integrated status control above head, framed and structurally on top beam
 b.bevel(.41,.245,.090,0,1.775,.268,.021,'graphite','Control_Console')
 b.bevel(.375,.207,.020,0,1.78,.212,.014,'deep','Control_Console')
 screen_material('exercise_display',['ARES / EXERCISE','RESISTANCE  06','DURATION    12:00','HAB-01 | READY'],512,310)
 b.plane(.348,.18,0,1.783,.199,'exercise_display','Control_Console')
 b.box(.35,.014,.02,0,1.651,.200,'ochre','Control_Console')
 # physical toggle panel at y1.56 with inset mechanical buttons
 b.box(.29,.055,.03,0,1.55,.311,'graphite')
 for xx in [-.10,0,.10]:b.cyl(.021,.013,xx,1.55,.284,'ochre' if xx==0 else 'steel',axis='z',sections=16)
 label_material('exercise_label','ARES / TRAINER','COMPACT RESISTANCE  /  01')
 b.plane(.26,.08,0,.40,.327,'exercise_label')
 # narrow cowl safety chevrons on front lower guards
 for xx in [-.46,.46]:
  for yy in [.74,.83,.92]:b.box(.027,.032,.013,xx,yy,.296,'ochre')
 return b

BUILDERS={'task_light':make_task_light,'privacy_divider':make_privacy_divider,'exercise_station':make_exercise_station}
if __name__=='__main__':
 manifest={'project':'ARES — Mars Habitat','style':'Original retro-industrial space habitat aesthetic','coordinate_system':'Godot / GLB metres, +Y up, -Z front, origin at floor centre','assets':{}}
 for name,builder in BUILDERS.items():
  print('Creating',name,flush=True)
  b=builder();path=os.path.join(MODEL,name+'_retro.glb');stats=b.export(path)
  manifest['assets'][name]= {'id':name,'file':os.path.relpath(path,ROOT),'stats':stats,
   'suggested_placement': 'wall mount at y=1.3-1.6m' if name=='task_light' else 'floor placement',
   'existing_catalogue_id':name,
   'interactive_parts':{'task_light':['Lamp_Head','Lamp_Emitter','Arm_Assembly'], 'privacy_divider':['Panel_Left','Panel_Right','Hinges_Left','Hinges_Right'],'exercise_station':['Grip_L','Grip_R','Seat_Cushion','Control_Console','Resistance_Stack']}[name]}
  print(name,stats,flush=True)
 with open(os.path.join(ROOT,'asset_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
