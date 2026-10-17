#!/usr/bin/env python3
"""Deterministic depth-buffered CPU preview of the actual exported GLB, without Blender."""
from pathlib import Path
import numpy as np, trimesh
from PIL import Image,ImageDraw,ImageFont,ImageFilter
from numba import njit

R=Path(__file__).resolve().parents[1]
s=trimesh.load(R/'model/crew_bunk_optimised.glb',force='scene')
BASENAMES=['composite','metal','trim','mattress','duvet','light','screen','decal','safety']
COLORS={'composite':(184,193,187),'metal':(128,145,151),'trim':(46,57,61),'mattress':(175,177,158),'duvet':(83,126,113),'light':(247,230,170),'screen':(20,65,70),'decal':(47,58,57),'safety':(203,122,66)}
imgs=[]
for k in BASENAMES:
 p={'composite':'shell_composite_albedo.png','metal':'anodised_frame_albedo.png','trim':'polymer_trim_albedo.png','mattress':'fabric_mattress_albedo.png','duvet':'fabric_blanket_albedo.png','light':None,'screen':'crew_display.png','decal':'berth_identification_label.png','safety':None}[k]
 if p:
  a=np.array(Image.open(R/'model'/p).convert('RGB').resize((512,512)))
 else:a=np.ones((512,512,3),dtype=np.uint8)*np.array(COLORS[k],dtype=np.uint8)
 imgs.append(a)
TEX=np.stack(imgs)

@njit(cache=True)
def paint(vertices,faces,uv,ids,width,height,texture):
    image=np.zeros((height,width,3),dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            image[y,x,0]=242-int(8*y/height)
            image[y,x,1]=244-int(8*y/height)
            image[y,x,2]=241-int(8*y/height)
    zbuffer=np.ones((height,width),dtype=np.float32)*1e9
    for i in range(len(faces)):
        i0,i1,i2=faces[i]; a=vertices[i0];b=vertices[i1];c=vertices[i2]
        x0,y0=a[0],a[1];x1,y1=b[0],b[1];x2,y2=c[0],c[1]
        xmin=max(0,int(min(x0,x1,x2)));xmax=min(width-1,int(max(x0,x1,x2))+1)
        ymin=max(0,int(min(y0,y1,y2)));ymax=min(height-1,int(max(y0,y1,y2))+1)
        if xmin>xmax or ymin>ymax:continue
        denom=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
        if abs(denom)<0.000001:continue
        shade=a[3]
        mat_id=ids[i]
        for y in range(ymin,ymax+1):
            for x in range(xmin,xmax+1):
                px=x+.5;py=y+.5
                ba=((y1-y2)*(px-x2)+(x2-x1)*(py-y2))/denom
                bb=((y2-y0)*(px-x2)+(x0-x2)*(py-y2))/denom
                bc=1.-ba-bb
                if ba<0 or bb<0 or bc<0:continue
                z=ba*a[2]+bb*b[2]+bc*c[2]
                if z>=zbuffer[y,x]:continue
                u=ba*uv[i0,0]+bb*uv[i1,0]+bc*uv[i2,0]
                v=ba*uv[i0,1]+bb*uv[i1,1]+bc*uv[i2,1]
                tx=int((u%1)*511);ty=int(((1.-v)%1)*511)
                if mat_id==7:
                    # decal's graphic is stored with alpha, but preview shows its RGB plate
                    tx=min(511,max(0,tx));ty=min(511,max(0,ty))
                r=texture[mat_id,ty,tx,0];g=texture[mat_id,ty,tx,1];bcol=texture[mat_id,ty,tx,2]
                if mat_id==5:shade=1.05
                if mat_id==6:shade=1.0
                image[y,x,0]=min(255,int(r*shade));image[y,x,1]=min(255,int(g*shade));image[y,x,2]=min(255,int(bcol*shade))
                zbuffer[y,x]=z
    return image

def view(file,camera,focus=(0,0.95,0),width=1000,height=900):
 eye=np.asarray(camera,dtype=np.float64); at=np.asarray(focus,dtype=np.float64)
 forward=(at-eye);forward/=np.linalg.norm(forward)
 right=np.cross(forward,[0,1,0]);right/=np.linalg.norm(right)
 up=np.cross(right,forward);up/=np.linalg.norm(up)
 # orthographic pixels per metre
 scale=min((width-120)/3.1,(height-100)/2.28)
 views=[];faces=[];uvs=[];ids=[];offset=0
 lp=np.array([-0.50,0.80,0.48]);lp/=np.linalg.norm(lp)
 for name,mesh in s.geometry.items():
  verts=np.asarray(mesh.vertices,dtype=np.float64)
  t=verts-eye
  screenx=(t @ right)*scale+width/2
  screeny=height/2-(t @ up)*scale
  screenz=t @ forward
  tri=mesh.faces
  a=verts[tri[:,1]]-verts[tri[:,0]];b=verts[tri[:,2]]-verts[tri[:,0]]
  ns=np.cross(a,b);ns/=np.maximum(np.linalg.norm(ns,axis=1)[:,None],1e-8)
  shades=(0.70 + 0.24*np.abs(ns@lp))
  shades=np.clip(shades,.62,.99)
  # vertices duplicated per face to transmit flat normal lightness
  pts=[];vuv=[];newfaces=[]
  orig_uv=np.asarray(mesh.visual.uv)
  for k,tidx in enumerate(tri):
   for p in tidx:
    pts.append([screenx[p],screeny[p],screenz[p],shades[k]])
    vuv.append(orig_uv[p])
   start=offset+len(pts)-3
   newfaces.append([start,start+1,start+2])
  views.append(np.asarray(pts,np.float64));uvs.append(np.asarray(vuv,np.float64));faces.append(np.asarray(newfaces,dtype=np.int64))
  ids.extend([BASENAMES.index(name.split('__')[-1])]*len(newfaces))
  offset+=len(pts)
 verts=np.concatenate(views); uv=np.concatenate(uvs);fs=np.concatenate(faces)
 rendered=paint(verts,fs,uv,np.asarray(ids,dtype=np.int32),width,height,TEX)
 im=Image.fromarray(rendered)
 im.save(file,optimize=True)
 return im

left=view(R/'preview'/'berth_front_3q.png',(-3.5,2.45,-4.4))
right=view(R/'preview'/'berth_opposite_3q.png',(3.4,2.4,-4.5))
front=view(R/'preview'/'berth_front_elevation.png',(0,1.5,-5.0),width=1100,height=800)

canvas=Image.new('RGB',(2040,1100),'#f5f6f3')
canvas.paste(left,(20,155));canvas.paste(right,(1020,155))
d=ImageDraw.Draw(canvas)
try:
 f1=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',53)
 f2=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',24)
except OSError:f1=ImageFont.load_default();f2=f1
d.text((40,25),'CREW BUNK  /  BUILT-IN SLEEPING BERTH',font=f1,fill=(38,54,54))
d.text((44,103),'Model inspection render • 2.24 × 1.12 × 1.84 m • 2,076 triangles • PBR texture maps included in GLB',font=f2,fill=(70,91,89))
canvas.save(R/'preview'/'crew_bunk_optimised_preview.png',optimize=True)
print('Rendered 3 genuine-model preview angles.')
