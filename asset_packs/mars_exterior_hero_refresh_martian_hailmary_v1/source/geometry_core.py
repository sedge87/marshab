"""Original exterior machinery for a classroom Mars habitat game.
Units: metres; Y vertical; -Z faces player. Requires numpy + trimesh.
Scene contains named independently identifiable components, with mesh batching for static elements.
"""
from pathlib import Path
import json,math
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual import TextureVisuals

ROOT=Path(__file__).resolve().parents[1]
MODEL=ROOT/'models';MODEL.mkdir(exist_ok=True,parents=True)
COLORS={
 'white_ceramic':([0.88,0.91,0.90,1],.05,.65),
 'white_painted':([0.94,0.95,0.92,1],.03,.57),
 'warm_panel':([0.78,0.82,0.80,1],.06,.62),
 'alloy':([0.59,0.67,0.69,1],.76,.38),
 'satin_steel':([0.77,0.81,0.79,1],.83,.27),
 'dark_alloy':([0.28,0.35,0.38,1],.66,.5),
 'black_rubber':([0.10,0.14,0.16,1],.03,.83),
 'rubber_gasket':([0.17,0.24,0.26,1],.02,.84),
 'teal':([0.22,0.47,0.51,1],.17,.45),
 'teal_soft':([0.42,0.63,0.64,1],.06,.69),
 'orange':([0.84,0.42,0.18,1],.20,.51),
 'safety_red':([0.78,0.19,0.14,1],.14,.44),
 'bright_green':([0.35,0.76,0.48,1],.03,.43),
 'amber_glow':([1.0,.73,.35,1],.01,.34),
 'light_diffuser':([0.99,0.99,0.86,1],0,.34),
 'glass':([0.69,.86,.88,.35],0,.16),
 'cool_blue':([0.38,.62,.76,1],.13,.48),
 'olive':([0.48,.55,.46,1],.12,.66),
 'sand':([0.70,.68,.57,1],.10,.69),
}
MATS={name:PBRMaterial(name=name,baseColorFactor=c, metallicFactor=met,roughnessFactor=r,alphaMode='BLEND' if c[3]<1 else 'OPAQUE',doubleSided=True) for name,(c,met,r) in COLORS.items()}

def rot_to_z(vector):
 v=np.asarray(vector,float);v=v/np.linalg.norm(v)
 return trimesh.geometry.align_vectors([0,0,1],v)

def addcyl_geom(p0,p1,r=.01,sections=14):
 p0,p1=np.array(p0,float),np.array(p1,float);vec=p1-p0;L=np.linalg.norm(vec)
 if L<1e-6:raise ValueError('zero-length part')
 m=trimesh.creation.cylinder(radius=r,height=L,sections=sections)
 m.apply_transform(rot_to_z(vec))
 m.apply_translation((p0+p1)/2)
 return m

class Model:
 def __init__(self,id):self.id=id;self.parts={};self.links=[]
 def add(self,node,mat,mesh):
  self.parts.setdefault((node,mat),[]).append(mesh)
  return mesh
 def box(self,node,mat,size,p):
  m=trimesh.creation.box(extents=size);m.apply_translation(p);self.add(node,mat,m);return m
 def bar(self,node,mat,start,end,r=.012,sections=12):return self.add(node,mat,addcyl_geom(start,end,r,sections))
 def cyl(self,node,mat,r,h,pos,axis='y',sections=24):
  m=trimesh.creation.cylinder(radius=r,height=h,sections=sections)
  if axis=='y':m.apply_transform(rot_to_z([0,1,0]))
  elif axis=='x':m.apply_transform(rot_to_z([1,0,0]))
  elif axis=='z':pass
  else:raise ValueError(axis)
  m.apply_translation(pos);return self.add(node,mat,m)
 def sphere(self,node,mat,r,pos,scale=(1,1,1),subdivisions=2):
  m=trimesh.creation.icosphere(subdivisions=subdivisions,radius=r)
  m.apply_scale(scale);m.apply_translation(pos)
  return self.add(node,mat,m)
 def ring(self,node,mat,outer,inner,h,pos,axis='y',sections=28):
  m=trimesh.creation.annulus(r_min=inner,r_max=outer,height=h,sections=sections)
  if axis=='y':m.apply_transform(rot_to_z([0,1,0]))
  elif axis=='x':m.apply_transform(rot_to_z([1,0,0]))
  m.apply_translation(pos);return self.add(node,mat,m)
 def hose(self,node,mat,pts,r=.012,sections=10):
  for a,b in zip(pts[:-1],pts[1:]):self.bar(node,mat,a,b,r,sections)
 def cross(self,node,mat,center,size=.11,depth=.012,normal='z'):
  x,y,z=center
  if normal=='z':
   self.box(node,mat,(size*.28,size,depth),(x,y,z))
   self.box(node,mat,(size,size*.28,depth),(x,y,z))
  else:
   self.box(node,mat,(size*.28,depth,size),(x,y,z))
   self.box(node,mat,(size,depth,size*.28),(x,y,z))
 def finish(self):
  scene=trimesh.Scene()
  for (node,mat),items in self.parts.items():
   if len(items)==1:merged=items[0]
   else:merged=trimesh.util.concatenate(items)
   merged.visual=TextureVisuals(material=MATS[mat])
   scene.add_geometry(merged,geom_name=f'{node}_{mat}',node_name=f'{node}_{mat}')
  out=MODEL/f'{self.id}.glb';scene.export(out)
  loaded=trimesh.load(out,force='scene')
  geos=list(loaded.dump())
  allverts=np.vstack([x.vertices for x in geos]);mins=allverts.min(axis=0);maxs=allverts.max(axis=0)
  return {'id':self.id,'triangles':sum(len(x.faces) for x in geos),'mesh_groups':len(geos),'materials':len(set(getattr(x.visual.material,'name','') for x in geos)),'dimensions_xyz_m':[round(float(a),3) for a in (maxs-mins)],'bounds_m':[[round(float(a),3) for a in mins],[round(float(a),3) for a in maxs]],'named_components':sorted(set(n for n,m in self.parts)),'file':out.name}

