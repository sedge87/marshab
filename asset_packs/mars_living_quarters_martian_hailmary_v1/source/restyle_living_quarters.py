#!/usr/bin/env python3
"""Restyle high-detail Living Quarters GLBs into bright Mars science-habitat finishes.

Rebuild exported GLBs from unchanged original geometry, preserving every node/transform.
No baked words, fixed data displays or original label maps survive. Designed to run
with the included local backups: python source/restyle_living_quarters.py
"""
from pathlib import Path
import json
import numpy as np
import trimesh
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCES = {
 'crew_bunk': 'crew_bunk_retro.glb',
 'locker': 'locker_retro.glb',
 'common_table': 'common_table_retro.glb',
 'task_light': 'task_light_retro.glb',
 'privacy_divider': 'privacy_divider_retro.glb',
 'exercise_station': 'exercise_station_retro.glb',
}
# (RGBA, metallic, roughness) -- low-distraction white composite hardware palette.
P = {
 'bone': ((240,243,237,255),0.035,0.67),
 'cream': ((249,248,241,255),0.025,0.69),
 'graphite': ((158,177,183,255),0.38,0.56),
 'deep': ((77,95,102,255),0.23,0.73),
 'steel': ((194,206,207,255),0.72,0.41),
 'satinsteel': ((214,222,220,255),0.72,0.41),
 'ochre': ((228,156,79,255),0.12,0.58),
 'warning': ((225,156,85,255),0.11,0.59),
 'rubber': ((47,61,68,255),0.015,0.89),
 'lamp': ((251,247,227,255),0.0,0.36),
 'blackglass': ((42,69,81,255),0.10,0.23),
 'fabric': ((235,236,224,255),0.0,0.96),
 'fabricdark': ((160,174,175,255),0.0,0.96),
 'olive': ((99,143,151,255),0.0,0.94),
 'woven': ((255,255,255,255),0.0,0.97),
}
# Remove stale static data artwork, fake unreadable labels and screen drawings.
DYNAMIC_OR_LABEL = {'label','planning_screen','exercise_display','exercise_label','task_nameplate','divider_label_0','divider_label_1','divider_label_2'}

def woven_texture():
  n=256
  yy, xx = np.mgrid[0:n,0:n]
  # Tightly woven light-grey cloth, visible up close but unobtrusive in room view.
  cross=(xx%6==0).astype(float)*-9 + (yy%6==0).astype(float)*-11
  noise=(np.sin(xx*.88)*np.cos(yy*.73))*3.0
  base=np.stack([np.full((n,n),219),np.full((n,n),230),np.full((n,n),224)],axis=-1)
  result=np.uint8(np.clip(base + (cross+noise)[...,None],0,255))
  return Image.fromarray(result,'RGB')

manifest=[]
for id,basename in SOURCES.items():
 orig=ROOT/'source_originals'/basename
 assert orig.is_file(), f'Missing source {orig}'
 scene=trimesh.load(orig,force='scene')
 before={'triangles':sum(len(m.faces) for m in scene.geometry.values()),
         'meshes':len(scene.geometry),'bounds':np.asarray(scene.bounds).copy(),
         'nodes':sorted(scene.graph.nodes_geometry)}
 cleared=[]
 for key,mesh in scene.geometry.items():
  material=getattr(mesh.visual,'material',None)
  if material is None: continue
  name=material.name
  if name in DYNAMIC_OR_LABEL:
   if 'screen' in name or 'display' in name:
    rgba,metal,rough=((43,68,77,255),0.08,0.27)
   else:
    rgba,metal,rough=((193,210,210,255),0.13,0.69)
   # Remove baked text/diagram images. Godot can add live text to these surfaces later.
   material.baseColorTexture=None
   if hasattr(material,'emissiveTexture'):material.emissiveTexture=None
   material.emissiveFactor=np.array([0.0,0.0,0.0])
   cleared.append(name)
  elif name in P:
   rgba,metal,rough=P[name]
   if name=='woven': material.baseColorTexture=woven_texture()
   if name=='lamp':material.emissiveFactor=np.array([.78,.75,.60])
  else:
   print('UNKNOWN',id,key,name)
   continue
  material.baseColorFactor=np.array(rgba,dtype=np.uint8)
  material.metallicFactor=float(metal)
  material.roughnessFactor=float(rough)
 out=ROOT/'models'/f'{id}_martian_hailmary.glb'
 scene.export(out)
 result=trimesh.load(out,force='scene')
 after={'triangles':sum(len(m.faces) for m in result.geometry.values()),
        'meshes':len(result.geometry),'bounds':np.asarray(result.bounds).copy(),
        'nodes':sorted(result.graph.nodes_geometry)}
 assert before['triangles']==after['triangles']
 assert before['meshes']==after['meshes']
 assert before['nodes']==after['nodes']
 assert np.allclose(before['bounds'],after['bounds'],atol=.0001)
 # No legacy text or data display textures present after export.
 for mesh in result.geometry.values():
  mat=getattr(mesh.visual,'material',None)
  if mat and mat.name in DYNAMIC_OR_LABEL: assert getattr(mat,'baseColorTexture',None) is None,(id,mat.name)
 material_count=len({m.visual.material.name for m in result.geometry.values() if getattr(m.visual,'material',None)})
 bounds=after['bounds']
 record={'id':id, 'model':str(out.relative_to(ROOT)),
         'triangles':after['triangles'],'mesh_groups':after['meshes'],
         'material_count':material_count,
         'size_m':[round(float(v),3) for v in bounds[1]-bounds[0]],
         'min_bounds_m':[round(float(v),3) for v in bounds[0]],
         'max_bounds_m':[round(float(v),3) for v in bounds[1]],
         'removed_baked_content':sorted(set(cleared)),
         'source_geometry_preserved':True, 'interactions_in_live_game':False}
 manifest.append(record)
 print(id,after['triangles'],'triangles',after['meshes'],'mesh groups,',len(cleared),'fixed screens/labels',flush=True)
(ROOT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))
print('DONE',len(manifest),'assets')
