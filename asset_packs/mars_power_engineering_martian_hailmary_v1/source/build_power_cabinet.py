#!/usr/bin/env python3
"""High-quality, physically grounded Mars habitat power distribution cabinet.
Original asset. Godot axes: +Y up, -Z forward; origin floor centre.
The static components are batched by PBR material. Moving components keep
unique named nodes with local origins at meaningful pivots.
"""
from pathlib import Path
from collections import defaultdict
import json, math, numpy as np, trimesh

ROOT=Path(__file__).resolve().parent.parent
(ROOT/'models').mkdir(exist_ok=True)

COLORS={
 'white': ('#F3F4EE',0.06,0.61),
 'warmwhite': ('#FAF9F3',0.025,0.67),
 'lightgrey': ('#CFD9D9',0.33,0.53),
 'aluminium': ('#A8B8BE',0.78,0.35),
 'steel': ('#73858D',0.77,0.45),
 'dark': ('#394C55',0.21,0.68),
 'shadow': ('#1C2C33',0.05,0.82),
 'rubber': ('#27373F',0.00,0.91),
 'orange': ('#E9A15B',0.08,0.52),
 'copper': ('#BA845D',0.74,0.37),
 'yellow': ('#E9C46D',0.08,0.58),
 'teal': ('#599FA9',0.12,0.53),
 'greenlight': ('#96E4B4',0.0,0.36),
 'amberlight': ('#FFE3A2',0.0,0.39),
 'glass': ('#4D6770',0.10,0.23),
}


def pbr(name):
    hexa,metal,rough=COLORS[name]
    rgb=[int(hexa[i:i+2],16) for i in (1,3,5)]
    emissive=([0.28,.73,.48] if name=='greenlight' else ([.95,.52,.12] if name=='amberlight' else [0,0,0]))
    return trimesh.visual.material.PBRMaterial(name=name,baseColorFactor=np.array(rgb+[255],dtype=np.uint8),metallicFactor=metal,roughnessFactor=rough,emissiveFactor=emissive,doubleSided=False)

MATERIALS={name:pbr(name) for name in COLORS}

def box(size,center):
    m=trimesh.creation.box(extents=size)
    m.apply_translation(center)
    return m

def roundbox(size,center,r=.014,bev=.004,quality=3):
    """Extrusion with soft radii on one face and shallow bevels on front/back."""
    w,h,d=[float(s) for s in size]
    r=min(r,.45*w,.45*h)
    b=min(bev,.19*w,.19*h,.25*d)
    corners=[(w/2-r,-h/2+r,-math.pi/2,0),(w/2-r,h/2-r,0,math.pi/2),(-w/2+r,h/2-r,math.pi/2,math.pi),(-w/2+r,-h/2+r,math.pi,3*math.pi/2)]
    def prof(scale):
        rr=max(.0001,r-scale*.5)
        return np.array([(cx+(rr)*math.cos(theta),cy+(rr)*math.sin(theta))
         for cx,cy,aa,bb in corners for theta in np.linspace(aa,bb,quality+1)])
    vertices=[]
    for z,off in [(-d/2,b),(-d/2+b,0),(d/2-b,0),(d/2,b)]:
        arr=prof(off)
        vertices.extend(np.c_[arr,np.full(len(arr),z)])
    n=len(prof(0));face=[]
    for k in range(3):
        for j in range(n):
            q=(j+1)%n
            face.extend([[k*n+j,k*n+q,(k+1)*n+q],[k*n+j,(k+1)*n+q,(k+1)*n+j]])
    # caps triangulation center
    vertices.extend([[0,0,-d/2],[0,0,d/2]])
    for j in range(n):
        q=(j+1)%n
        face.extend([[n*4,j,q],[n*4+1,n*3+q,n*3+j]])
    mesh=trimesh.Trimesh(vertices=np.asarray(vertices)+np.asarray(center),faces=face,process=False)
    mesh.fix_normals()
    return mesh

def cylinder(p,q,r,seg=16):
    p=np.asarray(p,dtype=float);q=np.asarray(q,dtype=float);v=q-p
    L=np.linalg.norm(v)
    if L < 1e-6: raise ValueError([p,q])
    mesh=trimesh.creation.cylinder(radius=r,height=L,sections=seg)
    mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],v))
    mesh.apply_translation((p+q)/2)
    return mesh

def torus(center,major=.08,minor=.01,axis='z',n1=26,n2=8):
    v=[];faces=[]
    for i in range(n1):
        t=i*2*math.pi/n1
        for j in range(n2):
            p=j*2*math.pi/n2
            x=(major+minor*math.cos(p))*math.cos(t)
            y=(major+minor*math.cos(p))*math.sin(t)
            z=minor*math.sin(p)
            v.append((x,y,z))
    for i in range(n1):
        for j in range(n2):
            a=i*n2+j;b=((i+1)%n1)*n2+j
            c=((i+1)%n1)*n2+(j+1)%n2;d=i*n2+(j+1)%n2
            faces.extend([(a,b,c),(a,c,d)])
    mesh=trimesh.Trimesh(vertices=np.asarray(v),faces=np.asarray(faces),process=False)
    if axis=='x':mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
    elif axis=='y':mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
    mesh.apply_translation(center)
    return mesh

class Cabinet:
  def __init__(self):
    self.stat=defaultdict(list)
    self.mobile=defaultdict(list)
    self.pivots={}
  def put(self,m,mat,group=None,pivot=None):
    if group is None: self.stat[mat].append(m)
    else:
      self.mobile[(group,mat)].append(m)
      if pivot is not None:
        if group in self.pivots and not np.allclose(self.pivots[group],pivot): raise ValueError('Pivot mismatch')
        self.pivots[group]=np.array(pivot,dtype=float)
  def b(self,size,pos,mat,group=None,pivot=None,r=.014,b=.003):
    self.put(roundbox(size,pos,r,b),mat,group,pivot)
  def bx(self,size,pos,mat,group=None,pivot=None):self.put(box(size,pos),mat,group,pivot)
  def c(self,p,q,r,mat,group=None,pivot=None,n=16):self.put(cylinder(p,q,r,n),mat,group,pivot)
  def tor(self,pos,major,minor,mat,group=None,pivot=None):self.put(torus(pos,major,minor),mat,group,pivot)
  def export(self, filename='power_distribution_cabinet_martian_hailmary.glb', equipment_id='power_distribution_panel'):
    scene=trimesh.Scene()
    scene.metadata={'name':'Power Distribution Cabinet','equipment_id':equipment_id,'scale':'metres','up':'+Y','forward':'-Z','artist_style':'practical white-composite Mars habitat','interactive_nodes':sorted(self.pivots.keys())}
    for mat,meshes in self.stat.items():
      item=trimesh.util.concatenate(meshes)
      item.visual=trimesh.visual.TextureVisuals(material=MATERIALS[mat])
      name=f'Chassis_and_Static_Details__{mat}'
      scene.add_geometry(item,geom_name=name,node_name=name)
    for (group,mat),meshes in self.mobile.items():
      item=trimesh.util.concatenate(meshes)
      pv=self.pivots.get(group,np.array([0.,0.,0.]))
      item.apply_translation(-pv)
      item.visual=trimesh.visual.TextureVisuals(material=MATERIALS[mat])
      pose=np.eye(4);pose[:3,3]=pv
      name=f'{group}__{mat}'
      scene.add_geometry(item,geom_name=name,node_name=name,transform=pose)
    path=ROOT/'models'/filename
    scene.export(path)
    check=trimesh.load(path,force='scene')
    records={'asset_id':equipment_id,'filename':path.name,'triangles':sum(len(mesh.faces) for mesh in check.geometry.values()),'mesh_nodes':len(check.graph.nodes_geometry),
      'materials':len({m.visual.material.name for m in check.geometry.values()}),
      'bounds_min_m':check.bounds[0].round(4).tolist(), 'bounds_max_m':check.bounds[1].round(4).tolist(),'dimensions_m':(check.bounds[1]-check.bounds[0]).round(3).tolist(),
      'interactive_nodes':[n for n in check.graph.nodes_geometry if any(x in n for x in ['Main_Isolator','Emergency_Stop','BreakerBank','Inspect_Door','Test_Button'])],
      'baked_text':False,'functional_simulation_implemented':False}
    assert records['dimensions_m'][0]<=1.5,records
    assert records['bounds_min_m'][1]>=-0.001
    (ROOT/(filename.replace('.glb','_manifest.json'))).write_text(json.dumps(records,indent=2))
    print(json.dumps(records,indent=2))
    return path

A=Cabinet()
# structural backbone, a genuinely hollow framed enclosure rather than a single cube.
# 1.46 wide x .82 deep x 2.04 m high, centred on X/Z, +Y from floor.
A.b((1.39,.13,.75),(0,.14,.025),'dark',r=.044,b=.013)
A.b((1.30,.06,.73),(0,.105,.025),'steel',r=.025)
for x in (-.57,.57):
    for z in (-.265,.284):
        A.b((.14,.09,.16),(x,.047,z),'rubber',r=.025)
        A.b((.095,.025,.10),(x,.012,z),'shadow',r=.013)
# four corner vertical members, frame stitched to base and ceiling
for x in (-.66,.66):
  for z in (-.317,.323):
    A.b((.078,1.66,.086),(x,1.06,z),'aluminium',r=.014,b=.004)
    A.b((.046,1.52,.040),(x,1.025,z-.036),'lightgrey',r=.007)
# back chassis and raised side service rails
A.b((1.27,1.65,.066),(0,1.052,.324),'dark',r=.012,b=.004)
for x in (-.658,.658):
  A.b((.052,1.58,.53),(x,1.04,.020),'lightgrey',r=.018,b=.004)
  A.b((.017,1.43,.29),(x+(-.029 if x<0 else .029),1.05,-.026),'white',r=.008)
A.b((1.44,.12,.76),(0,1.95,.014),'white',r=.035,b=.012)
A.b((1.32,.048,.66),(0,2.018,.024),'lightgrey',r=.014)
# header with layered chamfered lip
A.b((1.34,.13,.084),(0,1.84,-.330),'white',r=.021,b=.006)
A.b((1.32,.027,.025),(0,1.789,-.374),'aluminium',r=.006)
# louvered upper vents in roof front edge
for i in range(11):
  x=-.47+i*.094
  A.b((.055,.010,.025),(x,1.917,-.367),'dark',r=.004,b=.001)
  A.b((.039,.006,.029),(x,1.927,-.365),'steel',r=.002,b=.001)
# frontal perimeter bolted frame, recesses formed by separate subassembly
A.b((1.34,.08,.10),(0,.254,-.32),'white',r=.020)
A.b((1.34,.064,.08),(0,1.702,-.324),'lightgrey',r=.012)
for x in (-.625,.625):
  A.b((.063,1.38,.080),(x,.971,-.342),'lightgrey',r=.010)
  for y in (.33,1.64):
     A.c((x,y,-.396),(x,y,-.389),.012,'steel',n=12)
# breaker housing left 0.90m wide: recessed *real* cavity with deep edges
A.b((.851,1.325,.071),(-.195,1.03,-.195),'shadow',r=.018)
A.b((.885,.033,.102),(-.195,1.677,-.306),'steel',r=.010)
A.b((.885,.035,.102),(-.195,.382,-.306),'steel',r=.010)
A.b((.044,1.27,.102),(-.618,1.033,-.306),'aluminium',r=.008)
A.b((.044,1.27,.102),(.226,1.033,-.306),'aluminium',r=.008)
# three evenly spaced DIN rails and backing separators; add visible material depth
for row, y in enumerate((1.453,1.112,.765)):
  A.b((.747,.040,.057),(-.193,y+.130,-.233),'steel',r=.008)
  A.b((.78,.018,.10),(-.193,y-.132,-.268),'dark',r=.004)
  for col in range(5):
    x=-.497+col*.1515
    # Actual breaker cassette: clipped rail, elongated moulded shell, recessed groove
    A.b((.131,.249,.105),(x,y,-.297),'warmwhite',r=.009,b=.002)
    A.b((.123,.027,.035),(x,y+.085,-.366),'lightgrey',r=.004)
    A.b((.100,.035,.023),(x,y-.095,-.363),'dark',r=.004)
    # Lever housing and cradle with exposed tactile toggling paddle
    A.b((.076,.084,.024),(x,y-.004,-.357),'dark',r=.009)
    A.b((.063,.052,.033),(x,y+.014,-.376),'aluminium',r=.006)
    A.b((.050,.061,.053),(x,y+.025,-.404),'orange' if (row==0 and col==0) else 'steel',
         group=f'BreakerBank_R{row+1}_C{col+1}_Handle',pivot=(x,y+.01,-.381),r=.008)
    # pin heads seated flush in breaker body (avoid floating parts)
    for yy in (y+.099,y-.102):
      A.c((x,yy,-.364),(x,yy,-.372),.007,'steel',n=10)
# Bottom cable-termination shroud closes the breaker bay with a separate, bolted service cover.
# Face is shallow and removable-looking; every grille slat has a supporting backing plate.
A.b((.769,.183,.049),(-.194,.514,-.309),'lightgrey',r=.018,b=.005)
A.b((.685,.111,.026),(-.194,.514,-.342),'warmwhite',r=.011)
for sx in (-.522,.134):
  for sy in (.458,.564):A.c((sx,sy,-.353),(sx,sy,-.360),.008,'steel',n=12)
for k in range(5):
  xx=-.437+k*.119
  A.b((.068,.018,.008),(xx,.514,-.360),'dark',r=.004,b=.001)
# Copper busbars behind protective low-profile cross rail at top left
for yy in (1.653,1.621):
  A.b((.75,.014,.027),(-.193,yy,-.315),'copper',r=.004)
  for xx in (-.55,-.23,.10): A.c((xx,yy,-.329),(xx,yy,-.334),.007,'steel',n=8)
# side control bay with actual material-backed recess
A.b((.310,1.325,.072),(.435,1.027,-.193),'dark',r=.016)
A.b((.29,1.265,.030),(.437,1.033,-.238),'white',r=.013)
for xx in (.276,.595):
   A.b((.020,1.31,.088),(xx,1.03,-.285),'aluminium',r=.007)
# upper analog gauge with concentric dial frame and meaningful needle
A.c((.432,1.455,-.293),(.432,1.455,-.321),.085,'steel',n=36)
A.c((.432,1.455,-.323),(.432,1.455,-.329),.070,'glass',n=36)
A.tor((.432,1.455,-.334),.068,.006,'lightgrey')
A.c((.432,1.455,-.339),(.432,1.455,-.346),.010,'orange',n=14)
A.c((.432,1.455,-.337),(.475,1.482,-.337),.003,'warmwhite',n=10)
# top right guarded light bars with actual bases
for i, color in enumerate(('greenlight','amberlight','greenlight')):
  y=1.272-i*.105
  A.b((.138,.047,.028),(.432,y,-.292),'shadow',r=.015)
  A.b((.094,.021,.010),(.432,y,-.311),color,r=.009,b=.001)
# Rotary isolator pivoted about -Z axis
pivot=(.431,.782,-.310)
A.c((.431,.782,-.296),(.431,.782,-.327),.101,'dark',n=32)
A.tor((.431,.782,-.336),.083,.013,'aluminium')
A.c((.431,.782,-.329),(.431,.782,-.360),.060,'orange',group='Main_Isolator_Rotary',pivot=pivot,n=32)
A.b((.145,.026,.057),(.431,.782,-.392),'white',group='Main_Isolator_Rotary',pivot=pivot,r=.012)
A.c((.431,.782,-.390),(.431,.782,-.409),.015,'steel',group='Main_Isolator_Rotary',pivot=pivot,n=16)
# emergency stop, red-orange domed mechanical plunger and recessed socket
A.c((.431,.551,-.299),(.431,.551,-.330),.054,'shadow',n=26)
A.c((.431,.551,-.322),(.431,.551,-.358),.038,'orange',group='Emergency_Stop_Plunger',pivot=(.431,.551,-.320),n=26)
# service access hatch with mounts and hinges on the cabinet's *right side*, flush and supported
A.b((.018,.79,.43),(.690,1.148,.015),'white',group='Inspection_Door',pivot=(.681,1.148,-.200),r=.015)
for yy in (.85,1.45):
  A.c((.701,yy,-.173),(.701,yy,-.105),.015,'steel',n=16)
  A.b((.028,.095,.06),(.703,yy,-.125),'aluminium',r=.006)
A.b((.028,.123,.075),(.706,1.17,.086),'dark',group='Inspection_Door',pivot=(.681,1.148,-.200),r=.012)
# side louver rows mounted to the side panel, under a service rim
for j in range(7):
  y=.81+j*.079
  A.b((.011,.025,.280),(.711,y,.055),'dark',r=.004)
  A.b((.010,.009,.271),(.719,y+.011,.055),'aluminium',r=.002)
# lower front cable bulkhead, a protruding reinforced rail with sealed glands
A.b((1.26,.125,.09),(0,.319,-.340),'white',r=.012)
A.b((1.17,.030,.040),(0,.27,-.396),'aluminium',r=.005)
for i, x in enumerate((-.47,-.27,-.07,.14,.35,.51)):
  # panel sockets have plausible backing and extruded collars
  A.c((x,.322,-.389),(x,.322,-.403),.038,'dark',n=18)
  A.c((x,.322,-.406),(x,.322,-.418),.025,'aluminium',n=18)
  A.c((x,.322,-.421),(x,.322,-.431),.013,'rubber',n=18)
# cable ducts: physically secured along right rear panel and into base glands
for ix, xx in enumerate((.57,.62)):
  path=[(xx,.37,.28),(xx,.44,.30),(xx,1.02,.30),(xx,1.06,.30)]
  for p,q in zip(path,path[1:]):A.c(p,q,.014+ix*.002,'rubber',n=12)
  for yy in (.51,.93): A.b((.045,.043,.050),(xx,yy,.303),'steel',r=.008)
# small service hatch front bottom, seam and hinge screws
A.b((.44,.07,.023),(-.355,.468,-.388),'lightgrey',r=.009)
for x in (-.565,-.147):
 A.c((x,.468,-.408),(x,.468,-.415),.008,'steel',n=12)
# corner fasteners and accents, all seated in larger panel surfaces
for xx in (-.61,.61):
  for yy in (.31,1.72):
     A.c((xx,yy,-.382),(xx,yy,-.391),.012,'steel',n=10)
# vertical front enamel service edge, no text, no fake data display
for xx in (-.588,.575):
  A.b((.015,1.05,.015),(xx,1.043,-.397),'warmwhite',r=.006)

A.export()
