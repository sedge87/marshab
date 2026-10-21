#!/usr/bin/env python3
"""Restyle the approved *existing* equipment meshes, preserving geometry and node identities.

Bright Martian / Project Hail Mary aesthetic.  Only named PBR material values change;
all scene graph nodes, mesh transforms, faces, and logical interactive groups survive.
Does NOT add gameplay or change collision, existing scene IDs, or live project files.
"""
from pathlib import Path
import json, shutil, copy
from collections import Counter
import numpy as np
import trimesh
ROOT=Path(__file__).resolve().parent
SOURCES={
 'hydroponics':{
  'grow_tray': '/mnt/data/Mars_Habitat_Martian_HailMary_Style_Reference/models/grow_tray_martian_hailmary_v1.glb',
  'seedling_station':'/mnt/data/Mars_Hydroponics_Seedling_Station_Retro_v3/models/seedling_station_retro_v3.glb',
  'nutrient_mixer':'/mnt/data/Mars_Hydroponics_Nutrient_Mixer_Retro_v4/models/nutrient_mixer_retro_v4.glb',
  'harvest_cart':'/mnt/data/Mars_Hydroponics_Harvest_Cart_Retro_v5/models/harvest_cart_retro_v5.glb',
  'large_planter':'/mnt/data/Mars_Hydroponics_Large_Planter_Retro_v6/models/large_planter_retro_v6.glb',
 },
 'life_support':{
  'air_recycler':'/mnt/data/Mars_Habitat_Martian_HailMary_Style_Reference/models/air_recycler_martian_hailmary_v1.glb',
  'water_reclaimer':'/mnt/data/Mars_Life_Support_Water_Reclaimer_Retro_v2/models/water_reclaimer_retro_v2.glb',
  'thermal_control_unit':'/mnt/data/Mars_Life_Support_Thermal_Control_Retro_v3/models/thermal_control_unit_retro_v3.glb',
  'oxygen_reserve':'/mnt/data/Mars_Life_Support_Oxygen_Reserve_Retro_v4/models/oxygen_reserve_retro_v4.glb',
 }
}
# PBR RGB, metalness and roughness: white polymer panels, matte ceramic,
# satin aluminium, darker flexible components, and restrained service colours.
COLORS={
 'bone':((235,238,232),.04,.65), 'cream':((242,243,235),.035,.67),
 'offwhite':((245,246,240),.04,.63), 'ivory':((240,241,231),.02,.69),
 'Aged_Ivory_Ceramic_Panels':((241,244,237),.02,.65),
 'Ceramic_Composite_Offwhite':((241,244,239),.03,.66),
 'Insulation_Ceramic':((234,238,234),.02,.78),
 'Settling_Tank_Paint':((224,231,228),.16,.66),
 'filter':((236,238,228),.02,.79), 'Filter_Ceramic':((239,240,235),.02,.75),
 'inner':((216,224,219),.08,.74),
 'frame':((148,165,169),.56,.47),
 'steel':((193,201,200),.76,.39), 'Brushed_Aluminium':((196,204,202),.77,.4),
 'darksteel':((112,133,139),.68,.54),
 'castiron':((113,129,135),.65,.58),
 'gunmetal':((126,145,149),.57,.52),
 'graphite':((76,95,103),.23,.66),
 'Graphite_Powdercoated_Steel':((88,107,113),.31,.61),
 'Powdercoated_Graphite':((94,114,118),.30,.62),
 'Service_Bay_Slate':((74,93,102),.24,.66),
 'Rubberized_Slate':((91,107,112),.05,.8),
 'rubber':((42,56,59),.02,.89),
 'hose':((52,88,96),.025,.81),
 'Industrial_Black_Rubber':((45,55,58),.02,.87),
 'Flexible_Rubber':((50,59,61),.015,.84),
 'seal':((42,54,58),.015,.85),
 'black':((32,45,49),.04,.84),
 'shadow':((37,47,52),.13,.83),
 'bronze':((173,160,126),.55,.47),
 'copper':((174,160,129),.61,.42), 'Copper_Fittings':((180,164,131),.58,.45),
 'Oxidized_Copper_Connectors':((176,172,148),.61,.42),
 'brick':((193,200,191),.10,.68),
 'red':((199,89,74),.18,.54), 'Hot_Loop_Brick_Red':((198,98,77),.21,.56),
 'ochre':((230,141,72),.10,.59), 'amber':((238,180,88),.02,.46),
 'Safety_Amber':((238,167,80),.03,.57),
 'green':((98,166,98),.01,.83), 'green_deep':((63,132,84),.01,.91),
 'green_light':((147,190,109),.01,.88),
 'leaf_dark':((63,120,81),0,.92), 'leaf_medium':((96,166,94),0,.89),
 'leaf_light':((145,199,108),0,.89),
 'blue_plastic':((101,164,181),.06,.49),
 'teal':((101,166,175),.11,.51),
 'wet':((56,120,140),.06,.39),
 'liquid':((70,140,166),.03,.35),
 'Water_Visible_Blue':((71,158,183),.01,.38),
 'Blue_Tinted_Water_Pipe':((76,146,177),.12,.49),
 'Cold_Loop_Desaturated_Blue':((77,146,182),.20,.48),
 'safetyblue':((71,150,185),.18,.52),
 'Pump_Housing_Petrol':((118,153,155),.35,.57),
 'Status_Indicator_Cyan':((78,181,191),.03,.37),
 'Green_Operating_Lamp':((88,193,133),.02,.37),
 'Indicator_Off':((133,143,141),.01,.77),
 'acrylic':((190,216,217),.03,.22),
 'white_light':((250,247,230),.0,.44),
 'light':((247,248,235),0,.44),
 'produce_orange':((219,147,67),.01,.91),
 'produce_red':((210,83,66),.01,.87),
}
# A few surfaces need special treatment to visually lighten *enclosures*, without
# turning necessary dark rubber, recessed hollows, gauges or gaskets white.
GROUP_OVERRIDES={
 ('nutrient_mixer','Static','graphite'):('new_white',(224,231,226),.07,.64),
 ('nutrient_mixer','Static','gunmetal'):('new_silver',(168,183,184),.48,.55),
 ('harvest_cart','Static','gunmetal'):('new_silver',(166,180,180),.48,.54),
 ('large_planter','Static','gunmetal'):('new_silver',(167,184,185),.49,.52),
}
manifest=[]
for room,mapping in SOURCES.items():
 d=ROOT/room; (d/'models').mkdir(parents=True,exist_ok=True)
 for id,filepath in mapping.items():
  local=ROOT/'source_originals'/f'{id}_source.glb'
  orig=local if local.is_file() else Path(filepath)
  assert orig.is_file(),filepath
  dst=d/'models'/f'{id}_martian_hailmary.glb'
  if id in ('grow_tray','air_recycler'):
   shutil.copy2(orig,dst)
   process='Previously approved style-reference model; copied without geometry/material changes'
  else:
   scene=trimesh.load(orig,force='scene')
   for node in scene.graph.nodes_geometry:
    _, geom_name=scene.graph[node]
    mesh=scene.geometry[geom_name]
    material=getattr(mesh.visual,'material',None)
    if material is None:continue
    name=material.name
    group=geom_name.split('__')[0]
    c=COLORS.get(name)
    override=GROUP_OVERRIDES.get((id,group,name))
    if override:
     _,rgb,metal,rough=override
    elif c:
     rgb,metal,rough=c
    else:
     # preserve unknown specialized material instead of blindly breaking it
     continue
    bc=np.array(getattr(material,'baseColorFactor',[255,255,255,255]),dtype=np.uint8)
    # Keep original opacity (incl. windows / translucent liquid).
    alpha=int(bc[3]) if len(bc)==4 else 255
    material.baseColorFactor=np.array([*rgb,alpha],dtype=np.uint8)
    material.metallicFactor=float(metal)
    material.roughnessFactor=float(rough)
    # Emissive status markers retain illumination but avoid neon aesthetics.
   scene.export(dst)
   process='Material-only restyle of approved detailed mesh; original geometry unchanged'
  old=trimesh.load(orig,force='scene'); new=trimesh.load(dst,force='scene')
  def stats(s):
   return {'triangles':sum(len(m.faces) for m in s.geometry.values()),'mesh_groups':len(s.geometry),
      'bounds_m':np.round(s.bounds,4).tolist(),
      'materials':len(set(getattr(m.visual.material,'name','') for m in s.geometry.values()))}
  os_=stats(old); ns=stats(new)
  assert os_['triangles']==ns['triangles'] and os_['mesh_groups']==ns['mesh_groups'],id
  assert np.allclose(old.bounds,new.bounds,rtol=0,atol=.0002),id
  old_nodes=sorted(old.graph.nodes_geometry);new_nodes=sorted(new.graph.nodes_geometry)
  assert old_nodes==new_nodes,(id,'changed nodes')
  info={'id':id,'room':room,'glb':str(dst.relative_to(ROOT)), 'original_source':str(orig),
        'triangles':ns['triangles'], 'mesh_groups':ns['mesh_groups'],
        'materials':ns['materials'], 'bounds_m':ns['bounds_m'],
        'restyle':process,'preserved_geometry_and_nodes':True,'working_in_game':False}
  manifest.append(info)
  print(id,ns['triangles'],'tri',ns['mesh_groups'],'groups',flush=True)
(ROOT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))
print('COMPLETE',len(manifest),'assets',flush=True)
