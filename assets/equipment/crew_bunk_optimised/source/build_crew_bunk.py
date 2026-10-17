#!/usr/bin/env python3
"""Performance-minded, Y-up 3D crew berth for Godot 4. Requires trimesh, numpy, Pillow."""
from __future__ import annotations
import math, json, os, shutil
from pathlib import Path
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import trimesh
from trimesh.visual import TextureVisuals
from trimesh.visual.material import PBRMaterial

ROOT=Path(__file__).resolve().parents[1]
MODEL=ROOT/'model'
PREVIEW=ROOT/'preview'
MODEL.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
RNG=np.random.default_rng(937)

# Every dimension is in metres. X = berth length, Y = height, -Z = open face.
W=2.24
DEPTH=1.12
HEIGHT=1.84

def tx(x=0,y=0,z=0):
 t=np.eye(4); t[:3,3]=[x,y,z]; return t

def ry(a): return trimesh.transformations.rotation_matrix(a,[0,1,0])
def rx(a): return trimesh.transformations.rotation_matrix(a,[1,0,0])
def rz(a): return trimesh.transformations.rotation_matrix(a,[0,0,1])

def diffuse_noise(base, name, scale=5, seed=7, tile_roughness=0):
 rng=np.random.default_rng(seed)
 width=512
 pix=rng.normal(0,scale,(width,width,1))
 noise=np.tile(pix,(1,1,3))
 b=np.asarray(base).reshape(1,1,3)
 image=np.clip(b + noise, 0,255).astype(np.uint8)
 # subtle panel micro-lines
 if tile_roughness:
  image[::tile_roughness,:,:] = np.clip(image[::tile_roughness,:,:].astype(int)-2,0,255).astype(np.uint8)
 im=Image.fromarray(image,'RGB')
 im.save(MODEL/f'{name}.png',optimize=True)
 return im

def textile(base,name,seed):
 rng=np.random.default_rng(seed)
 n=512
 img=np.full((n,n,3),base,dtype=np.float32)
 fine=rng.normal(0,4.2,size=(n,n,1))
 weave=(np.sin(np.arange(n)[:,None]*np.pi/2)*1.5 + np.cos(np.arange(n)[None,:]*np.pi/2)*1.5)[:,:,None]
 img += fine+weave
 im=Image.fromarray(np.clip(img,0,255).astype('uint8'),'RGB')
 im.save(MODEL/f'{name}.png',optimize=True)
 return im

shell_img=diffuse_noise([184,191,186],'shell_composite_albedo',scale=3.5,seed=13)
metal_img=diffuse_noise([120,132,136],'anodised_frame_albedo',scale=2.5,seed=14,tile_roughness=7)
polymer_img=diffuse_noise([44,53,58],'polymer_trim_albedo',scale=3,seed=15)
fabric_img=textile([165,171,154],'fabric_mattress_albedo',16)
duvet_img=textile([77,114,105],'fabric_blanket_albedo',17)

# Display texture is a static initial state; simulator can override as needed.
screen=Image.new('RGB',(512,256),(14,30,35))
d=ImageDraw.Draw(screen)
try:
 f1=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',26)
 f2=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22)
except OSError:
 f1=ImageFont.load_default();f2=f1
teal=(128,218,195)
d.rectangle((8,8,504,248),outline=(57,105,100),width=4)
d.text((24,20),'CREW BERTH / 01',font=f1,fill=(221,230,220))
d.line((22,62,480,62),fill=(53,112,103),width=2)
d.text((24,86),'AIR  21.0 C',font=f2,fill=teal)
d.text((24,127),'LIGHT  20 %',font=f2,fill=teal)
d.text((24,168),'SLEEP MODE  READY',font=f2,fill=(225,189,111))
screen.save(MODEL/'crew_display.png',optimize=True)

# Stencilled service label atlas (1 quad, almost no extra geometry).
decals=Image.new('RGBA',(512,256),(0,0,0,0)); dd=ImageDraw.Draw(decals)
try:
 f3=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',34)
 f4=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22)
except OSError:
 f3=ImageFont.load_default();f4=f3
dd.rounded_rectangle((8,8,503,247),radius=15,fill=(49,58,59,255))
dd.text((29,27),'HAB / CREW 01',font=f3,fill=(235,235,215,255))
dd.rectangle((28,98,475,102),fill=(193,130,78,255))
dd.text((29,120),'RESEARCH STATION    HABITATION',font=f4,fill=(224,222,206,255))
dd.text((29,163),'BUNKS   /   LIFE SUPPORT',font=f4,fill=(168,185,180,255))
decals.save(MODEL/'berth_identification_label.png',optimize=True)

# Distinct PBR materials; large details use physically based surface response.
MAT={
 'composite': PBRMaterial(name='M_Habitat_SatinComposite',baseColorTexture=shell_img,metallicFactor=0.02,roughnessFactor=0.73),
 'metal': PBRMaterial(name='M_Anodised_Aluminium',baseColorTexture=metal_img,metallicFactor=0.78,roughnessFactor=0.42),
 'trim': PBRMaterial(name='M_Rubber_MouldedPolymer',baseColorTexture=polymer_img,metallicFactor=0.02,roughnessFactor=0.83),
 'mattress': PBRMaterial(name='M_Soft_Knit_Mattress',baseColorTexture=fabric_img,metallicFactor=0,roughnessFactor=0.96),
 'duvet': PBRMaterial(name='M_Fabric_SageBlanket',baseColorTexture=duvet_img,metallicFactor=0,roughnessFactor=0.93),
 'light': PBRMaterial(name='M_Warm_LED_Emissive',baseColorFactor=[255,248,219,255],emissiveFactor=[1.0,0.84,0.55],metallicFactor=0,roughnessFactor=0.45),
 'screen': PBRMaterial(name='M_CrewInfoDisplay_Replaceable',baseColorTexture=screen,emissiveTexture=screen,emissiveFactor=[0.42,0.42,0.42],metallicFactor=0,roughnessFactor=0.45),
 'decal': PBRMaterial(name='M_ID_Decal',baseColorTexture=decals,metallicFactor=0,roughnessFactor=0.72,doubleSided=True,alphaMode='BLEND'),
 'safety': PBRMaterial(name='M_Safety_Copper',baseColorFactor=[207,135,74,255],metallicFactor=0.32,roughnessFactor=0.58)
}
# Eight main finishes plus a small safety accent, with reused material instances.
BATCH=defaultdict(list)

def textured(mesh, mat, uv=None):
 if uv is None:
  verts=np.asarray(mesh.vertices)
  uv=np.stack([(verts[:,0]+1.7)*0.58,(verts[:,2]+0.8)*0.8],axis=1)
 mesh.visual=TextureVisuals(uv=np.array(uv,float),material=MAT[mat])
 return mesh

def add(mesh, group, mat):
 BATCH[(group,mat)].append(textured(mesh,mat))

def box(size, xyz, group, mat):
 m=trimesh.creation.box(extents=size)
 m.apply_translation(xyz)
 add(m,group,mat)

def cylinder(radius, height, pos, group, mat, sections=12,axis='y'):
 m=trimesh.creation.cylinder(radius=radius,height=height,sections=sections)
 if axis=='y': m.apply_transform(rx(math.pi/2))
 elif axis=='x': m.apply_transform(ry(math.pi/2))
 m.apply_translation(pos)
 add(m,group,mat)

def bar(p,q,r, group, mat, sections=8):
 v=np.asarray(q)-np.asarray(p)
 m=trimesh.creation.cylinder(radius=r,height=float(np.linalg.norm(v)),sections=sections)
 m.apply_transform(trimesh.geometry.align_vectors([0,0,1],v))
 m.apply_translation((np.asarray(p)+np.asarray(q))*0.5)
 add(m,group,mat)

def rounded_y(width, depth, height, pos, radius, group, mat, steps=3):
 # Low-poly rounded-corner rectangular extrusion, Y aligned, flat top/bottom.
 w=width/2;d=depth/2
 corners=[(w-radius,d-radius,0),(-w+radius,d-radius,90),(-w+radius,-d+radius,180),(w-radius,-d+radius,270)]
 ring=[]
 for cx,cz,angle in corners:
  for j in range(steps+1):
   theta=math.radians(angle+j*90/steps)
   ring.append([cx+radius*math.cos(theta),cz+radius*math.sin(theta)])
 # ring might winding? convex hull surfaces can use.
 n=len(ring); vertices=[]
 for y in (-height/2,height/2):
  for x,z in ring:
   vertices.append([x,y,z])
 vertices += [[0,-height/2,0],[0,height/2,0]]
 faces=[]
 for i in range(n):
  k=(i+1)%n
  faces += [[i,k,n+k],[i,n+k,n+i]]
  faces += [[2*n,k,i],[2*n+1,n+i,n+k]]
 m=trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
 m.apply_translation(pos)
 add(m,group,mat)

def surface(x0,x1,z0,z1,height_fun,group,mat,nx=8,nz=6):
 verts=[]
 for iz in range(nz+1):
  z=z0+(z1-z0)*iz/nz
  for ix in range(nx+1):
   x=x0+(x1-x0)*ix/nx
   y=height_fun(ix/nx,iz/nz,x,z)
   verts.append([x,y,z])
 faces=[]
 for iz in range(nz):
  for ix in range(nx):
   k=iz*(nx+1)+ix
   faces.extend([[k,k+nx+1,k+1],[k+1,k+nx+1,k+nx+2]])
 m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
 # accurate UV tiling on top
 uv=[]
 for iz in range(nz+1):
  for ix in range(nx+1): uv.append((ix*2/nx,iz*1.5/nz))
 BATCH[(group,mat)].append(textured(m,mat,uv))

def quad_verts(pts,group,mat,uv=None):
 m=trimesh.Trimesh(vertices=pts,faces=[[0,1,2],[0,2,3]],process=False)
 if uv is None: uv=[[0,0],[1,0],[1,1],[0,1]]
 BATCH[(group,mat)].append(textured(m,mat,uv))

# --- Self-supporting alcove carcass, open front facing -Z ---
# shell: rear panel and side cheeks with bevelled reveal edges
box((2.14,1.67,0.048),(0,0.95,0.518),'Static_Shell','composite')
for sign in (-1,1):
 box((0.076,1.76,1.04),(sign*1.067,0.93,0.002),'Static_Shell','composite')
 box((0.102,0.10,1.11),(sign*1.056,1.76,0.0),'Static_Frame','metal')
 box((0.05,1.72,0.07),(sign*1.036,0.92,-0.515),'Static_Frame','metal')
box((2.22,0.082,1.11),(0,1.78,0),'Static_Shell','composite')
box((2.16,0.11,1.08),(0,0.145,0),'Static_Frame','metal')
box((2.15,0.032,0.06),(0,1.70,-0.504),'Static_Frame','metal')
box((2.12,0.029,0.068),(0,0.595,-0.5),'Static_Frame','metal')
# Interior trim and underside recess
box((2.0,0.013,0.9),(0,0.197,0),'Static_Hardware','trim')
box((1.99,0.02,0.052),(0,0.605,-0.481),'Static_Hardware','trim')
# metallic inset side strips and upper roof ventilation plenum
for side in (-1,1):
 box((0.015,1.18,0.05),(side*0.983,1.10,-0.477),'Static_Hardware','trim')
box((1.96,0.09,0.06),(0,1.67,0.463),'Static_Hardware','trim')

# --- Recessed underbed drawers: three separate interactable fronts ---
for i,x in enumerate((-0.666,0,0.666),1):
 group=f'Drawer_{i:02d}_Moveable'
 box((0.624,0.34,0.022),(x,0.395,-0.495),group,'composite')
 box((0.59,0.012,0.015),(x,0.405,-0.514),group,'trim')
 rounded_y(0.16,0.028,0.024,(x,0.420,-0.539),0.007,group,'metal',steps=2)
 # latch accent
 box((0.035,0.018,0.006),(x+0.225,0.485,-0.513),group,'safety')
 # dark aperture around the drawer, attached static
 box((0.65,0.36,0.011),(x,0.397,-0.474),'Static_Hardware','trim')

# --- Suspended mattress and cosy textile layers ---
rounded_y(1.92,0.89,0.14,(0,0.704,0.002),0.09,'Mattress','mattress',steps=4)
# tight welt piping along mattress sides
for z in (-0.435,0.438):
 bar((-0.88,0.735,z),(0.88,0.735,z),0.006,'Mattress','trim',sections=6)
# pillow near head (-X), flattened curved surface
rounded_y(0.45,0.60,0.11,(-0.67,0.813,0.02),0.1,'Pillow','mattress',steps=4)
surface(-0.84,-0.49,-0.24,0.30,lambda u,v,x,z: 0.863+0.019*math.sin(math.pi*u)*math.sin(math.pi*v),'Pillow','mattress',nx=5,nz=5)
# sage blanket folded at foot, subtle wavy top surface
surface(-0.24,0.93,-0.413,0.41,lambda u,v,x,z:0.801 + 0.011*math.sin(4*math.pi*u+v*3)*math.sin(math.pi*v)+0.01*math.sin(math.pi*u),'Blanket','duvet',nx=14,nz=8)
# edge of folded blanket as dark double-fold face
box((1.175,0.034,0.040),(0.34,0.790,-0.414),'Blanket','duvet')
box((0.038,0.04,0.805),(-0.235,0.794,0),'Blanket','duvet')
# individual snugging straps (subtle, removable in engine if needed)
for x in (0.35,0.76):
 box((0.035,0.012,0.84),(x,0.820,-0.007),'Static_Hardware','trim')
 # small silver buckle on front
 box((0.050,0.014,0.026),(x,0.83,-0.406),'Static_Hardware','metal')

# --- Wall service shelf, control strip, reading task light ---
box((0.72,0.03,0.22),(-0.60,1.185,0.365),'Static_Shell','composite')
box((0.74,0.035,0.03),(-0.60,1.175,0.240),'Static_Frame','metal')
box((0.03,0.15,0.02),(-0.96,1.115,0.45),'Static_Frame','metal')
box((0.03,0.15,0.02),(-0.24,1.115,0.45),'Static_Frame','metal')
# Reading lamp: articulated puck with warm LED underside
cylinder(0.060,0.035,(-0.85,1.48,0.365),'ReadingLight_Housing','metal',sections=14)
bar((-0.85,1.47,0.365),(-0.74,1.39,0.28),0.010,'ReadingLight_Housing','metal',sections=8)
cylinder(0.061,0.032,(-0.74,1.39,0.28),'ReadingLight_Housing','trim',sections=18)
cylinder(0.055,0.008,(-0.74,1.367,0.28),'ReadingLight_Emissive','light',sections=18)
# display strip on right back wall (quad oriented towards -Z)
box((0.38,0.235,0.019),(0.680,1.277,0.470),'Control_Panel','trim')
quad_verts([[0.513,1.18,0.454],[0.847,1.18,0.454],[0.847,1.376,0.454],[0.513,1.376,0.454]],'Control_Display','screen')
# chunky physical buttons / dial
for j in range(3):
 cylinder(0.021,0.02,(0.53+0.10*j,1.127,0.44),'Control_Panel','safety' if j==1 else 'metal',sections=10,axis='z')
# backwall cargo net strip
box((0.45,0.17,0.013),(-0.30,0.99,0.489),'Static_Hardware','trim')
for k in range(6):
 box((0.010,0.13,0.009),(-0.50+0.08*k,0.99,0.480),'Static_Hardware','metal')

# --- Air system grille, deliberately not a solid dark rectangle ---
box((0.49,0.25,0.016),(0.63,1.58,0.477),'Vent_Frame','trim')
for i in range(9):
 box((0.423,0.009,0.022),(0.63,1.475+0.024*i,0.455),'Vent_Frame','metal')
for x in (0.42,0.84):
 cylinder(0.010,0.008,(x,1.595,0.45),'Vent_Frame','safety',sections=8,axis='z')

# --- Reflective front-top fascia and pullable privacy screen track ---
box((1.87,0.029,0.055),(0,1.715,-0.51),'Curtain_Track','metal')
for x in np.linspace(-0.91,0.91,9):
 cylinder(0.014,0.028,(float(x),1.680,-0.52),'Curtain_Track','trim',sections=8,axis='z')
# parked drape on right front. Pleated accordion made of fabric panels, NOT 100 separate meshes.
for k in range(5):
 xp=0.84+0.023*k
 z_front=-0.525+(-1)**k*0.024
 quad_verts([[xp,0.805,z_front],[xp+0.024,0.805,z_front+0.005],[xp+0.024,1.67,z_front+0.005],[xp,1.67,z_front]],'Curtain_Parked','mattress')
box((0.05,0.04,0.014),(0.946,1.015,-0.545),'Curtain_Parked','safety')
# Station ID service decal 0.46 x 0.15 at front-left fascia. UV quad close to top.
quad_verts([[-0.965,1.757,-0.561],[-0.465,1.757,-0.561],[-0.465,1.815,-0.561],[-0.965,1.815,-0.561]],'Static_Label','decal')
# safety accent tabs
for x in (-0.99,0.99):
 box((0.032,0.10,0.006),(x,1.66,-0.554),'Static_Hardware','safety')
# Recessed toe trim / low running light unpowered visual
box((1.82,0.035,0.025),(0,0.099,-0.527),'Static_Hardware','trim')

# --- Scene batches ---
scene=trimesh.Scene()
# Batch fixed panels/housings by material to reduce draw calls; retain only
# curtain, bedding, drawers and control/emissive nodes where distinct identity matters.
remapped=defaultdict(list)
for (group, mat), parts in BATCH.items():
    if group.startswith('Static_') or group in ('Vent_Frame','Curtain_Track','ReadingLight_Housing','Control_Panel'):
        group = 'Static_Architecture'
    elif group == 'Pillow':
        group = 'Mattress'
    remapped[(group,mat)].extend(parts)
for (group,mat),parts in sorted(remapped.items()):
    combined=trimesh.util.concatenate(parts)
    # Concatenation merges all static geometry sharing one material, preserving moving parts.
    name=f'{group}__{mat}'
    scene.add_geometry(combined,geom_name=name,node_name=name)
output=MODEL/'crew_bunk_optimised.glb'
scene.export(output)
trimesh.util.concatenate([g for g in scene.geometry.values()]).export(MODEL/'crew_bunk_optimised_geometry_only.stl')

# Closed curtain is a separate optional model: prevents obscuring the asset in editors.
# Runtime scene can toggle this individual component without huge geometry / shader tricks.
secondary=trimesh.Scene()
mesh=trimesh.creation.box(extents=[1.80,0.90,0.014])
mesh.apply_translation((0.0,1.225,-0.561))
# low-profile vertical fabric panel folds, 10 triangles each not needed in standby
mesh.visual=TextureVisuals(uv=np.asarray([[0,0],[1,0],[1,1],[0,1],[0,0],[1,0],[1,1],[0,1]]),material=MAT['mattress'])
secondary.add_geometry(mesh,geom_name='Curtain_Closed_Fabric',node_name='Curtain_Closed_Fabric')
secondary.export(MODEL/'crew_bunk_privacy_closed.glb')

# Compact mesh / material / bounds report used for QA and asset build checks.
triangle_count=sum(len(g.faces) for g in scene.geometry.values())
vertex_count=sum(len(g.vertices) for g in scene.geometry.values())
bounds=np.round(scene.bounds,4)
asset={
 'asset_id':'crew_bunk',
 'name':'Crew Bunk / Built-in Sleeping Berth',
 'units':'metres',
 'axes':'+Y up, -Z front',
 'origin':'floor centre of nominal equipment footprint',
 'nominal_width_m': W,
 'nominal_depth_m': DEPTH,
 'nominal_height_m': HEIGHT,
 'mesh_nodes':len(scene.geometry),
 'triangles':triangle_count,
 'vertices':vertex_count,
 'materials':list(MAT.keys()),
 'bounds_xyz_min':bounds[0].tolist(),
 'bounds_xyz_max':bounds[1].tolist(),
 'gameplay':'No resource systems changed or invented. Wire against existing crew_bunk catalogue entry.',
 'interactions_available':['reading_light_on_off','privacy_curtain_open_close','storage_drawers_visual_hooks','control_display_override'],
 'notes':['Side/rear housing is built in; no hull mesh is cut.','GLB embeds PBR textures; external PNGs support editing.', 'Keep existing Godot placement and simulation behaviour until reviewed.']
}
with open(ROOT/'asset_report.json','w') as f: json.dump(asset,f,indent=2)
print(json.dumps(asset,indent=2))
