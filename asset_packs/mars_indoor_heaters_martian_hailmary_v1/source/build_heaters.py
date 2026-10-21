"""Original practical 3D equipment designs for a classroom Mars habitat game.
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


# Conventions: metres; Y up; forward is -Z. Wall unit pivots about centre of back wall mount.
# No static text or fabricated displays; all controls are physical.


def chamfered_plate(width, height, chamfer, depth, at):
    """Extruded 8-point plate, so the profile is truly chamfered instead of piled boxes."""
    cx,cy,cz=at; w=width/2; h=height/2; c=chamfer
    shape=[(-w+c,-h),(w-c,-h),(w,-h+c),(w,h-c),(w-c,h),(-w+c,h),(-w,h-c),(-w,-h+c)]
    verts=[[cx+x,cy+y,cz+depth/2] for x,y in shape]+[[cx+x,cy+y,cz-depth/2] for x,y in shape]
    faces=[]
    for j in range(1,7): faces.append([0,j,j+1]); faces.append([8,8+j+1,8+j])
    for j in range(8):
        k=(j+1)%8
        faces.extend([[j,k,8+j],[k,8+k,8+j]])
    return trimesh.Trimesh(vertices=verts,faces=faces,process=True)


def plate(a,node,mat,width,height,chamfer,depth,at):
    return a.add(node,mat,chamfered_plate(width,height,chamfer,depth,at))



def finish_batched(a, independently_interactive):
    """Merge inert meshes by PBR material, preserving controls and status meshes."""
    batched={}
    for (node,mat), meshes in a.parts.items():
        output_node=node if node in independently_interactive else 'static_equipment'
        batched.setdefault((output_node,mat),[]).extend(meshes)
    a.parts=batched
    return a.finish()

def wall_heater():
    a=Model('wall_cabin_heater')
    # All parts connect mechanically back to the wall on a pair of slotted plates.
    # Back face near z=0, front at -0.196m. X footprint ~0.84m, Y +-0.25m.
    for x in (-.28,.28):
        a.box('wall_mounting_rails','dark_alloy',(.12,.40,.022),(x,0,-.008))
        for y in (-.158,.158):
            a.cyl('wall_mounting_bolts','satin_steel',.012,.016,(x,y,-.024),axis='z',sections=12)
        a.box('support_standoffs','alloy',(.058,.075,.065),(x,0,-.059))
    # Distinct rear plenum/backing pan, real metal side flanges, white top and bottom casing.
    plate(a,'heater_back_chassis','dark_alloy',.825,.455,.045,.055,(0,0,-.080))
    for x in (-.387,.387):
        a.box('side_uprights','satin_steel',(.020,.435,.075),(x,0,-.131))
        a.box('side_covers','white_ceramic',(.052,.401,.041),(x,0,-.161))
        for y in (-.135,-.060,.015,.090,.165):
            a.box('side_cooling_ribs','alloy',(.062,.009,.031),(x,y,-.183))
    for y in (-.215,.215):
        a.box('top_bottom_manifolds','white_painted',(.780,.044,.086),(0,y,-.140))
    plate(a,'corner_bezel','white_painted',.825,.470,.045,.022,(0,0,-.136))
    # Recessed central passage: dark shadow tray behind actual fins, then slim pale slats and grille trim.
    # The inset plate is on the FRONT of the chassis, so no broad panel hides the grille.
    a.box('heat_exchange_cavity','dark_alloy',(.685,.290,.010),(-.026, .012,-.157))
    for y in (-.140,.164):
        a.box('aperture_edge','satin_steel',(.70,.013,.031),(-.026,y,-.167))
    for x in (-.38,.326):
        a.box('aperture_edge','satin_steel',(.014,.313,.032),(x,.012,-.167))
    # Slanted internal aluminium exchanger fins, clearly nested inside surrounding framework.
    for i in range(17):
        x=-.338+i*.039
        a.box('fixed_exchanger_fins','alloy',(.009,.274,.028),(x,.010,-.178))
        a.box('fixed_exchanger_spine','warm_panel',(.006,.245,.008),(x+.009,.008,-.195))
    # Crisp lower air intake, with actual separation between its louvers.
    for i in range(2):
        y=-.187+i*.020
        a.box('lower_air_intake','dark_alloy',(.585,.012,.019),(-.065,y,-.184))
    # Small physical console on right, outside aperture.
    plate(a,'control_island','white_ceramic',.150,.285,.023,.027,(.341,.011,-.181))
    a.cyl('dial_mount','rubber_gasket',.052,.017,(.339,.075,-.202),axis='z',sections=28)
    a.cyl('heat_level_dial','satin_steel',.038,.019,(.339,.075,-.216),axis='z',sections=28)
    a.box('dial_pointer','orange',(.012,.038,.009),(.339,.099,-.230))
    a.cyl('on_off_switch_bezel','dark_alloy',.026,.017,(.339,-.064,-.206),axis='z',sections=20)
    a.box('on_off_switch','orange',(.040,.055,.028),(.339,-.064,-.221))
    a.cyl('indicator_low','amber_glow',.012,.010,(.311,-.119,-.208),axis='z',sections=16)
    a.cyl('indicator_high','bright_green',.012,.010,(.359,-.119,-.208),axis='z',sections=16)
    # Narrow upper thermal warning strip, on solid panel below top air exhaust.
    a.box('top_vent_mount','dark_alloy',(.55,.029,.028),(-.09,.212,-.172))
    for i in range(10):
        x=-.338+i*.055
        a.box('top_exhaust_dividers','alloy',(.008,.025,.024),(x,.211,-.189))
    a.box('thermal_trip_button','safety_red',(.034,.024,.025),(.343,-.177,-.198))
    # Rear service connector and a physically bracketed short loop.
    a.box('power_socket','rubber_gasket',(.055,.052,.037),(-.337,-.171,-.052))
    a.hose('protected_power_whip','black_rubber',[(-.337,-.18,-.037),(-.36,-.22,-.052),(-.37,-.232,-.100)],.010)
    return finish_batched(a, {"on_off_switch", "heat_level_dial", "dial_pointer", "indicator_low", "indicator_high", "thermal_trip_button"})


def portable_heater():
    a=Model('portable_utility_heater')
    # A heater designed to appear convincingly movable: low centre of gravity, handle, feet.
    # A front forced-air outlet and a separate removable side dust filter.
    for x in (-.223,.223):
        for z in (-.132,.132):
            a.box('non_slip_feet','black_rubber',(.088,.027,.086),(x,.014,z))
    plate(a,'base_plinth','dark_alloy',.548,.088,.035,.37,(0,.070,0)) # vertical profile y; depth= .37
    for x in (-.236,.236):
        a.box('tubular_chassis','alloy',(.027,.47,.284),(x,.347,.0))
    # Bulk housing, bevel/chamfer visual silhouette (back inset under the white frame)
    a.box('internal_heating_core','dark_alloy',(.480,.440,.292),(0,.345,.016))
    plate(a,'body_shell','white_ceramic',.515,.484,.042,.290,(0,.353,.015))
    # Side reveal / gasket bands align around opening on each face
    for x in (-.244,.244):
        a.box('side_edge_trim','satin_steel',(.018,.480,.312),(x,.352,.003))
    for y in (.122,.583):
        a.box('upper_lower_trim','warm_panel',(.505,.022,.316),(0,y,.004))
    # Front outlet: dark recessed cavity with 13 actual aluminium slats and left-right edge returns.
    a.box('front_air_cavity','dark_alloy',(.415,.292,.026),(-.030,.402,-.154))
    for y in (.250,.560):
        a.box('outlet_frame','satin_steel',(.438,.014,.029),(-.026,y,-.184))
    for x in (-.246,.191):
        a.box('outlet_frame','satin_steel',(.015,.317,.029),(x,.405,-.184))
    for j in range(12):
        y=.272+j*.025
        a.box('outlet_angled_louvres','satin_steel',(.420,.007,.027),(-.028,y,-.193))
    # Silhouette for fan impeller behind outlet, partly obscured by louvres.
    a.cyl('blower_hub','dark_alloy',.047,.016,(-.035,.405,-.170),axis='z',sections=24)
    for ang in (0,120,240):
        dx=.10*math.cos(math.radians(ang));dy=.09*math.sin(math.radians(ang))
        a.bar('blower_blades','alloy',(-.035,.405,-.170),(-.035+dx,.405+dy,-.170),r=.017,sections=10)
    # Upper tangible controls on a proper protruding bezel, not floating on a face.
    plate(a,'control_panel','warm_panel',.355,.086,.014,.025,(.025,.603,-.098))
    a.cyl('on_off_knob','dark_alloy',.033,.019,(-.084,.608,-.138),axis='z',sections=22)
    a.cyl('on_off_knob','orange',.021,.023,(-.084,.608,-.151),axis='z',sections=18)
    a.cyl('heat_level_dial','satin_steel',.036,.025,(.070,.608,-.149),axis='z',sections=24)
    a.box('dial_pointer','orange',(.011,.025,.009),(.07,.629,-.166))
    a.cyl('indicator_low','amber_glow',.012,.010,(.138,.614,-.150),axis='z',sections=14)
    a.cyl('indicator_high','bright_green',.012,.010,(.170,.614,-.150),axis='z',sections=14)
    # Braced carry handle with a cushioned cross-grip.
    for x in (-.145,.145):
        a.bar('handle_mounts','satin_steel',(x,.589,.075),(x,.718,.075),.016,sections=12)
    a.bar('carry_handle','black_rubber',(-.158,.724,.075),(.158,.724,.075),.021,sections=18)
    # Removable filter tray on right side, framed into chassis. No vague sticker.
    a.box('filter_recess','dark_alloy',(.016,.275,.210),(.263,.342,.015))
    a.box('filter_cartridge','warm_panel',(.019,.237,.182),(.278,.343,.016))
    for y in (.245,.303,.361,.419,.475):
        a.box('filter_slats','alloy',(.021,.009,.176),(.293,y,.016))
    a.box('filter_release_tab','orange',(.020,.055,.044),(.309,.482,.016))
    # Short captive safety power cable, mounted rear relief and cord hooks.
    a.box('power_inlet','dark_alloy',(.092,.078,.022),(-.139,.235,.164))
    a.hose('power_cable','black_rubber',[(-.139,.235,.181),(-.198,.184,.196),(-.201,.110,.190),(-.145,.086,.190)],.014)
    for y in (.18,.48):
        a.box('rear_vent_panel','dark_alloy',(.320,.094,.015),(.035,y,.168))
        for i in range(8):
            x=-.106+i*.042
            a.box('rear_vent_slats','alloy',(.010,.077,.022),(x,y,.181))
    for x in (-.24,.24):
        a.box('side_grips','rubber_gasket',(.035,.105,.24),(x,.51,.014))
    return finish_batched(a, {"on_off_knob", "heat_level_dial", "dial_pointer", "indicator_low", "indicator_high", "filter_cartridge", "filter_release_tab", "blower_hub", "blower_blades"})


if __name__=='__main__':
    data=[wall_heater(), portable_heater()]
    (ROOT/'asset_manifest.json').write_text(json.dumps({'style':'The Martian + Project Hail Mary inspired original functional sci-fi','units':'metres; Y up; -Z forward','assets':data},indent=2))
    for d in data: print(json.dumps(d,indent=2))
