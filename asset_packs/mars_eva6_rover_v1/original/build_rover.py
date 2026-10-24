import numpy as np, trimesh, math, os
from trimesh.transformations import rotation_matrix
ROOT=os.path.dirname(__file__)
OUT=os.path.join(ROOT,'models')
os.makedirs(OUT,exist_ok=True)
M={
'ceramic':(218,225,224,255),'white':(242,241,229,255),'shadow':(55,65,72,255),
'dark':(22,30,36,255),'gunmetal':(78,87,91,255),'titanium':(145,155,159,255),
'glass':(37,80,98,255),'glasslight':(80,144,158,255),'orange':(225,107,48,255),
'red':(186,45,39,255),'green':(70,179,135,255),'yellow':(239,192,79,255),
'rubber':(28,31,34,255),'tread':(49,53,54,255),'steel':(177,187,188,255),
'blue':(66,132,173,255),'solar':(29,55,90,255),'light':(245,246,215,255)}
parts=[]
def add(mesh,mat):
 mesh.visual=trimesh.visual.ColorVisuals(mesh,vertex_colors=np.tile(np.array(M[mat],dtype=np.uint8),(len(mesh.vertices),1)))
 parts.append(mesh)
def box(pos,size,mat):
 b=trimesh.creation.box(extents=size);b.apply_translation(pos);add(b,mat)
def cyl(a,b,r,mat,n=16):
 a=np.array(a,float);b=np.array(b,float);v=b-a
 mesh=trimesh.creation.cylinder(radius=r,height=np.linalg.norm(v),sections=n)
 mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],v));mesh.apply_translation((a+b)/2);add(mesh,mat)
def tube(a,b,r,mat):cyl(a,b,r,mat,10)
def ell(pos,radii,mat,subdiv=1):
 m=trimesh.creation.icosphere(subdivisions=subdiv,radius=1);m.apply_scale(radii);m.apply_translation(pos);add(m,mat)
def polygon_prism_xz(points,ymin,ymax,mat):
 # shape on XZ plane extruded Y via triangulation fan (convex)
 p=np.array(points,float); n=len(p); v=np.vstack([np.c_[p[:,0],np.full(n,ymin),p[:,1]],np.c_[p[:,0],np.full(n,ymax),p[:,1]]]);faces=[]
 for i in range(1,n-1):faces.extend([[0,i+1,i],[n,n+i,n+i+1]])
 for i in range(n):j=(i+1)%n;faces.extend([[i,j,n+j],[i,n+j,n+i]])
 add(trimesh.Trimesh(vertices=v,faces=faces,process=False),mat)
def plate(p,mat,thickness=.02):
 # vertical planar quad with tiny thickness by convex hull
 pts=np.array(p,float);center=pts.mean(axis=0);normal=np.cross(pts[1]-pts[0],pts[2]-pts[0]);normal/=np.linalg.norm(normal)
 vs=np.vstack([pts+normal*thickness/2,pts-normal*thickness/2]);add(trimesh.convex.convex_hull(vs),mat)
# Deck, exoskeletal space frame, front faces - vehicle forward is -Z
box((0,1.32,0),(2.68,.24,5.65),'shadow')
box((0,1.46,0),(2.62,.13,5.35),'titanium')
for x in [-1.25,1.25]:
 for y in [1.11,1.64]:box((x,y,0),(.12,.12,6.05),'gunmetal')
 for z in [-2.65,0,2.65]:box((x,y,z),(.23,.15,.40),'steel')
# Angular hood
polygon_prism_xz([(-1.2,-3.22),(1.2,-3.22),(1.30,-2.26),(-1.30,-2.26)],1.54,1.92,'ceramic')
box((0,1.91,-2.79),(2.22,.08,.56),'white')
for x in [-.9,-.45,0,.45,.9]:box((x,1.965,-2.81),(.065,.02,.43),'titanium')
# Cab lower foundation
box((0,1.79,-.61),(2.64,.62,3.45),'white')
# Large polygon cab upper volume (sloped front/rear); cross extrusion X manually
cab_outline=[(-2.23,1.87),(-1.95,2.90),(-1.65,3.32),(0.9,3.32),(1.52,2.98),(1.55,1.87)] # z,y
verts=[]
for x in [-1.24,1.24]:verts += [[x,y,z] for z,y in cab_outline]
n=len(cab_outline);f=[]
for i in range(1,n-1):f += [[0,i,i+1],[n,n+i+1,n+i]]
for i in range(n): j=(i+1)%n;f +=[[i,j,n+j],[i,n+j,n+i]]
add(trimesh.Trimesh(vertices=verts,faces=f,process=False),'ceramic')
# roof taper and roof protection rail
box((0,3.36,-.34),(2.16,.115,2.68),'white')
for x in [-1.09,1.09]:tube((x,3.48,-1.55),(x,3.48,.92),.052,'titanium')
for z in [-1.55,.92]:tube((-1.09,3.48,z),(1.09,3.48,z),.052,'titanium')
# Cab windscreen and broad windows: four corners of front quadrilateral
plate([[-1.04,2.37,-2.12],[1.04,2.37,-2.12],[.95,3.05,-1.88],[-.95,3.05,-1.88]],'glass',.04)
for x in [-.65,0,.65]:tube((x,2.40,-2.145),(x*.92,3.065,-1.91),.028,'dark')
# side view windows + portal door trim
for s in [-1,1]:
 x=1.255*s
 plate([[x,2.49,-1.64],[x,3.12,-1.49],[x,3.12,-.18],[x,2.47,-.18]],'glass',.045)
 plate([[x,2.49,.03],[x,3.12,.03],[x,3.12,.85],[x,2.49,1.07]],'glass',.045)
 for z in [-1.53,-.12,.97]:tube((x+s*.016,2.28,z),(x+s*.016,3.17,z),.038,'gunmetal')
 tube((x+s*.016,2.46,-1.63),(x+s*.016,2.46,1.03),.045,'gunmetal')
 tube((x+s*.016,3.13,-1.51),(x+s*.016,3.13,.82),.045,'gunmetal')
 box((s*1.315,2.05,.45),(.06,.12,.29),'dark');box((s*1.36,2.05,.45),(.03,.035,.19),'steel')
 # round technical hatch, external grab handles
 for z in [-1.45,.7]:tube((s*1.36,1.78,z),(s*1.36,2.12,z),.035,'orange')
 # exposed perimeter armor panels
 box((s*1.30,1.67,-.6),(.055,.27,2.65),'ceramic')
 for z in [-1.65,-.98,-.31,.36]:box((s*1.34,1.76,z),(.025,.11,.36),'shadow')
# rear payload section modular backpack
box((0,1.89,2.03),(2.36,.91,1.86),'white')
for x in [-1.01,1.01]:
 box((x,2.28,2.01),(.15,.18,1.66),'titanium')
box((0,2.37,1.99),(2.06,.12,1.69),'titanium')
for z in [1.28,1.62,1.96,2.30,2.64]:box((0,2.442,z),(1.77,.022,.03),'shadow')
# radiator side
for s in [-1,1]:
 box((s*1.23,2.00,2.08),(.055,.57,1.15),'shadow')
 for z in np.linspace(1.62,2.55,9):box((s*1.274,2.00,z),(.018,.44,.045),'steel')
# rear airlock heavy rectangular frame, docking details
box((0,2.21,3.012),(1.48,1.43,.16),'gunmetal')
box((0,2.21,3.105),(1.22,1.17,.07),'white')
box((0,2.19,3.151),(.73,.70,.04),'dark')
box((0,2.19,3.178),(.54,.52,.023),'glass')
for x in [-.66,.66]:tube((x,1.57,3.21),(x,2.85,3.21),.055,'orange')
for y in [1.58,2.85]:tube((-.68,y,3.21),(.68,y,3.21),.055,'orange')
# front push bumper / skid reinforcements
for y in [1.02,1.39]:tube((-1.28,y,-3.24),(1.28,y,-3.24),.085,'gunmetal')
for x in [-1.12,1.12]:tube((x,1.05,-3.28),(x,1.52,-3.12),.085,'steel')
# hazard markers, spot lamps
for s in [-1,1]:
 box((s*1.06,1.72,-3.223),(.32,.155,.05),'dark');box((s*1.06,1.72,-3.256),(.26,.10,.023),'light')
 box((s*1.06,1.45,3.105),(.3,.12,.06),'red')
 # antennas, camera pod
 tube((s*.9,3.48,.64),(s*.95,4.11,.70),.03,'steel');ell((s*.95,4.12,.70),(.07,.07,.07),'orange')
 box((s*1.36,2.70,-1.98),(.22,.25,.24),'shadow');box((s*1.37,2.70,-2.11),(.15,.13,.035),'glasslight')
# solar / rooftop panel and sensor station
box((0,3.49,-.26),(1.4,.08,1.25),'dark')
for x in np.linspace(-.56,.56,5):
 for z in np.linspace(-.71,.18,4):box((x,3.541,z),(.235,.01,.19),'solar')
cyl((0,3.47,-1.28),(0,3.79,-1.28),.08,'steel');box((0,3.86,-1.28),(.33,.18,.33),'white')
for s in [-1,1]:box((s*.17,3.86,-1.45),(.1,.065,.022),'dark')
# underchassis cable, suspension struts, rock guards
for z in [-2.08,0,2.08]:
 for s in [-1,1]:
  tube((s*1.05,1.24,z),(s*1.59,.89,z),.09,'titanium')
  tube((s*1.05,1.42,z+.24),(s*1.59,.89,z),.055,'gunmetal')
  box((s*1.40,1.34,z),(.32,.18,1.16),'white')
  box((s*1.44,1.32,z),(.34,.035,.85),'orange')
  # hinge bolts
  cyl((s*1.39,1.19,z),(s*1.54,1.19,z),.12,'steel')
# equipment stowage and exterior detail
for s in [-1,1]:
 box((s*1.13,2.48,2.55),(.16,.20,.48),'orange')
 for z in [-2.70,2.58]:
  box((s*1.25,1.05,z),(.20,.16,.32),'dark')
# make roll-cage/pillars with visible white frame
for s in [-1,1]:
 tube((s*1.18,2.39,-2.16),(s*1.08,3.23,-1.88),.09,'white')
 tube((s*1.26,2.42,1.18),(s*1.08,3.25,.94),.08,'white')
# chassis output
scene=trimesh.Scene()
by_color={}
for m in parts:
 color=tuple(m.visual.vertex_colors[0]);by_color.setdefault(color,[]).append(m)
for i,(color,meshes) in enumerate(by_color.items()):scene.add_geometry(trimesh.util.concatenate(meshes),node_name=f'rover_material_{i:02d}',geom_name=f'body_material_{i:02d}')
scene.export(os.path.join(OUT,'rover_chassis.glb'))
print('chassis',len(parts),'pieces')
# build independent wheel at (0,0,0), wheel axle along X; visual meshes have center origin.
parts=[]
# tire cylinder main radius .59, width .32
cyl((-.18,0,0),(.18,0,0),.59,'rubber',32)
# outer tyre side cheeks
for x in [-.185,.185]:
 cyl((x-.018,0,0),(x+.018,0,0),.49,'tread',32)
 cyl((x-.025,0,0),(x+.025,0,0),.32,'gunmetal',32)
 cyl((x-.033,0,0),(x+.033,0,0),.255,'titanium',32)
 cyl((x-.049,0,0),(x+.049,0,0),.10,'dark',24)
 for t in range(10):
  a=2*math.pi*t/10
  px=.17*math.cos(a);py=.17*math.sin(a)
  cyl((x-.051,px,py),(x+.051,px,py),.035,'dark',10)
# aggressive sculpted crosshatch block tread cylinders on circumference
for t in range(28):
 a=(2*math.pi*t/28); y=.59*math.cos(a);z=.59*math.sin(a)
 for xx in [-.115,.115]:
  b=trimesh.creation.box(extents=[.145,.072,.16])
  b.apply_transform(rotation_matrix(-a,[1,0,0]));b.apply_translation([xx,y,z]);add(b,'tread')
# radial rim spoke faces
for side in [-1,1]:
 for j in range(8):
  a=j*2*math.pi/8
  c=trimesh.creation.box(extents=[.025,.10,.22]);c.apply_transform(rotation_matrix(-a,[1,0,0]));c.apply_translation([side*.233,.25*math.cos(a),.25*math.sin(a)]);add(c,'steel')
wheel=trimesh.Scene()
by_color={}
for m in parts:
 color=tuple(m.visual.vertex_colors[0]);by_color.setdefault(color,[]).append(m)
for i,(color,meshes) in enumerate(by_color.items()):wheel.add_geometry(trimesh.util.concatenate(meshes),node_name=f'wheel_material_{i:02d}',geom_name=f'wheel_material_{i:02d}')
wheel.export(os.path.join(OUT,'rover_wheel.glb'))
print('wheel',len(parts),'pieces')
