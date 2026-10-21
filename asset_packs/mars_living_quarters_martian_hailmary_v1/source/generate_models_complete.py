"""Original retro-industrial Mars habitat furniture (not replicas of franchise props).
Generated geometry in metric Godot coordinates: +Y up, -Z forward, floor at Y=0.
Requires trimesh, numpy, Pillow. Re-run from any directory.
"""
import os, math, json, random
from collections import defaultdict
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for p in ('models','preview','textures','godot'): os.makedirs(os.path.join(ROOT,p),exist_ok=True)

COL={
'bone':((0.67,0.65,0.57,1),.21,.69),
'cream':((0.83,0.79,0.67,1),.13,.78),
'graphite':((0.112,0.142,0.151,1),.42,.52),
'deep':((0.044,0.063,0.067,1),.21,.67),
'steel':((0.42,0.47,0.46,1),.82,.34),
'satinsteel':((0.60,0.62,0.56,1),.77,.36),
'rubber':((0.095,0.109,0.103,1),.00,.94),
'olive':((0.27,0.36,0.30,1),.0,.94),
'fabric':((0.54,0.52,0.43,1),.0,.98),
'fabricdark':((0.32,0.35,0.31,1),.0,.98),
'ochre':((0.85,0.48,0.20,1),.14,.51),
'warning':((0.94,0.69,0.23,1),.12,.63),
'lamp':((1,.78,.43,1),.0,.4),
'display':((0.023,0.09,0.105,1),.0,.22),
'screenline':((0.28,0.73,0.65,1),.0,.32),
'blackglass':((0.047,0.067,0.070,1),.12,.13),
}
MATS={k:trimesh.visual.material.PBRMaterial(name=k,baseColorFactor=list(map(float,v[0])),metallicFactor=v[1],roughnessFactor=v[2],doubleSided=True,emissiveFactor=([.95,.57,.22] if k=='lamp' else ([.04,.18,.14] if k=='screenline' else [0,0,0]))) for k,v in COL.items()}

def colour(mesh,mat):
    mesh.visual=trimesh.visual.TextureVisuals(material=MATS[mat]); return mesh

def matrix_rotate(vec_from, vec_to):
    a=np.asarray(vec_from,dtype=float);a/=np.linalg.norm(a)
    b=np.asarray(vec_to,dtype=float);b/=np.linalg.norm(b)
    return trimesh.geometry.align_vectors(a,b)

def rounded_profile(w,h,r,seg=4):
    r=max(.0001,min(r,w*.48,h*.48))
    corners=[(w/2-r,-h/2+r,-math.pi/2,0),(w/2-r,h/2-r,0,math.pi/2),(-w/2+r,h/2-r,math.pi/2,math.pi),(-w/2+r,-h/2+r,math.pi,3*math.pi/2)]
    return np.array([(cx+r*math.cos(a),cy+r*math.sin(a)) for cx,cy,aa,ab in corners for a in np.linspace(aa,ab,seg+1)])

def rounded_box(size,center=(0,0,0),radius=.012,bevel=.004,axis='z',seg=3):
    sx,sy,sz=np.asarray(size,dtype=float)
    if axis=='z': w,h,d=sx,sy,sz
    elif axis=='y': w,h,d=sx,sz,sy
    elif axis=='x': w,h,d=sz,sy,sx
    else: raise ValueError(axis)
    bevel=min(bevel,w*.19,h*.19,d*.25)
    profiles=[]
    for zz,off in [(-d/2,bevel),(-d/2+bevel,0),(d/2-bevel,0),(d/2,bevel)]:
        pt=rounded_profile(w-2*off,h-2*off,max(radius-off*.5,.001),seg)
        profiles.append(np.c_[pt,np.full(len(pt),zz)])
    N=len(profiles[0]); vertices=np.concatenate(profiles)
    faces=[]
    for k in range(3):
        for i in range(N):
            j=(i+1)%N;a=k*N+i;b=k*N+j;c=(k+1)*N+j;d0=(k+1)*N+i
            faces.extend([[a,b,c],[a,c,d0]])
    bottom=len(vertices);top=bottom+1
    vertices=np.vstack([vertices,[0,0,-d/2],[0,0,d/2]])
    for i in range(N):
        j=(i+1)%N
        faces.append([bottom,j,i]); faces.append([top,3*N+i,3*N+j])
    v=vertices
    if axis=='y': v=np.c_[v[:,0],v[:,2],-v[:,1]]
    elif axis=='x': v=np.c_[v[:,2],v[:,1],-v[:,0]]
    m=trimesh.Trimesh(vertices=v+np.asarray(center),faces=np.array(faces),process=False)
    m.fix_normals()
    return m

def cyl_between(a,b,r,section=14):
    a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float)
    vec=b-a;norm=np.linalg.norm(vec)
    if norm<1e-5: raise ValueError((a,b))
    m=trimesh.creation.cylinder(radius=r,height=norm,sections=section)
    m.apply_transform(matrix_rotate([0,0,1],vec))
    m.apply_translation((a+b)/2)
    return m

def tube(points,r=.009,sections=10):
    return trimesh.util.concatenate([cyl_between(a,b,r,sections) for a,b in zip(points[:-1],points[1:])])

def box(size,center): return trimesh.creation.box(extents=size,transform=trimesh.transformations.translation_matrix(center))

def screw(center,normal=[0,0,-1],r=.007):
    normal=np.array(normal,dtype=float);normal/=np.linalg.norm(normal)
    return cyl_between(np.array(center)-normal*.0015,np.array(center)+normal*.0015,r,10)

FONT='/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf'
BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'

def label_texture(fname,title,sub='',tone='warning',ratio=3.3):
    w,h=768,int(768/ratio)
    im=Image.new('RGBA',(w,h),(35,46,47,255));d=ImageDraw.Draw(im)
    d.rounded_rectangle((8,8,w-9,h-9),radius=13,fill=(44,54,54,255),outline=(180,171,140,255),width=7)
    d.rectangle((22,22,43,h-23),fill=(206,146,64,255))
    font=ImageFont.truetype(BOLD,55 if len(title)<17 else 40)
    small=ImageFont.truetype(FONT,32)
    d.text((65,25),title,font=font,fill=(225,218,183,255),stroke_width=0)
    if sub: d.text((66,112),sub,font=small,fill=(140,187,169,255))
    p=os.path.join(ROOT,'textures',fname)
    im.save(p)
    return im

def panel_screen_texture(fname,title,lines):
    im=Image.new('RGBA',(640,392),(11,27,29,255));d=ImageDraw.Draw(im)
    d.rectangle((11,11,629,380),outline=(63,100,98,255),width=4)
    d.rectangle((24,23,616,82),fill=(36,65,64,255))
    d.text((40,34),title,font=ImageFont.truetype(BOLD,34),fill=(229,196,119,255))
    for i,text in enumerate(lines):
        y=104+i*57
        d.text((41,y),text,font=ImageFont.truetype(FONT,28),fill=(121,210,173,255))
        d.rectangle((395,y+4,572,y+19),outline=(72,105,94),width=2)
        d.rectangle((397,y+6,418+((i*53+131)%153),y+17),fill=(132,191,157,255))
    d.line((30,352,612,352),fill=(70,126,116),width=3)
    d.text((36,355),'ARES  |  HABITAT SYSTEMS',font=ImageFont.truetype(FONT,18),fill=(155,150,111))
    im.save(os.path.join(ROOT,'textures',fname))
    return im

def quad_xy(x,y,z,w,h,im,front=True):
    # Explicit triangle winding and UVs with top left PIL texel oriented correctly.
    verts=np.array([[x-w/2,y-h/2,z],[x+w/2,y-h/2,z],[x+w/2,y+h/2,z],[x-w/2,y+h/2,z]],dtype=float)
    faces=[[0,2,1],[0,3,2]] if front else [[0,1,2],[0,2,3]]
    uv=np.array([[1,0],[0,0],[0,1],[1,1]],dtype=float)
    # GLTF export and PIL image require flip to display correctly on front for our vtk preview handling
    mat=trimesh.visual.material.PBRMaterial(name='label',baseColorTexture=im,metallicFactor=.02,roughnessFactor=.72,doubleSided=True)
    m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
    m.visual=trimesh.visual.TextureVisuals(uv=uv,material=mat)
    return m

class Asset:
    def __init__(self,name):self.name=name;self.groups=defaultdict(list);self.labels=[]
    def put(self,mesh,mat='bone',group=None):
        k=group or ('static_'+mat)
        self.groups[(k,mat)].append(mesh)
    def b(self,size,center,mat,group=None,r=.01,bev=.003,axis='z'):
        self.put(rounded_box(size,center,r,bev,axis=axis),mat,group)
    def bx(self,size,center,mat,group=None):self.put(box(size,center),mat,group)
    def c(self,p,q,r,mat,group=None,section=14):self.put(cyl_between(p,q,r,section),mat,group)
    def t(self,points,r,mat,group=None):self.put(tube(points,r),mat,group)
    def s(self,center,mat='steel',normal=(0,0,-1),r=.006,group=None):self.put(screw(center,normal,r),mat,group)
    def tag(self,x,y,z,w,h,title,sub='',name=None):
        nm=name or (self.name+'_'+''.join(c if c.isalnum() else '_' for c in title.lower())+'.png')
        im=label_texture(nm,title,sub,ratio=w/h)
        self.labels.append((title,quad_xy(x,y,z,w,h,im)))
    def screen(self,x,y,z,w,h,title,lines):
        im=panel_screen_texture(self.name+'_display.png',title,lines)
        self.labels.append(('Display',quad_xy(x,y,z,w,h,im)))
    def export(self):
        scene=trimesh.Scene(); scene.metadata={'asset':self.name,'axis_up':'Y','axis_forward':'-Z','units':'meters','style':'original retro industrial Mars habitat'}
        for (name,mat),meshes in self.groups.items():
            joined=trimesh.util.concatenate(meshes) if len(meshes)>1 else meshes[0]
            colour(joined,mat)
            scene.add_geometry(joined,node_name=f'{name}__{mat}',geom_name=f'{name}__{mat}')
        for i,(name,mesh) in enumerate(self.labels): scene.add_geometry(mesh,node_name=f'{name}_{i:02}',geom_name=f'{name}_{i:02}')
        path=os.path.join(ROOT,'models',self.name+'.glb');scene.export(path)
        out=trimesh.load(path,force='scene'); tris=sum(len(m.faces) for m in out.geometry.values());bounds=out.bounds
        return {'file':os.path.basename(path),'mesh_nodes':len(out.geometry),'triangles':tris,'bounds_min':bounds[0].round(4).tolist(),'bounds_max':bounds[1].round(4).tolist(),'dimensions_m':(bounds[1]-bounds[0]).round(3).tolist()}

def ribs(A,x_positions,y1,y2,z,mat='deep',r=.008):
    for x in x_positions:A.c((x,y1,z),(x,y2,z),r,mat)

# CREW BUNK — main human-size equipment module, half-enclosed, no unsupported detailing
A=Asset('crew_bunk_retro')
# footprint width 2.28m, depth 1.06m. Main structure sides supported to floor.
W=2.28; zback=.48; zfront=-.52
# base continuous boxed chassis, rocker feet and four vertical corner structures
A.b((2.23,.15,1.04),(0,.128,0),'graphite',r=.04,bev=.008,axis='y')
A.b((2.22,.08,1.04),(0,.055,0),'deep',r=.024,bev=.008,axis='y')
for x in [-1.055,1.055]:
  for z in [-.455,.455]:
    A.b((.075,.29,.09),(x,.145,z),'steel',r=.013,bev=.003,axis='y')
# Structural shell: left and right composite bulkheads supported by steel chassis
for x in (-1.095,1.095):
    A.b((.09,1.68,1.00),(x,1.09,-.002),'graphite',r=.023,bev=.006,axis='z')
    A.b((.051,1.51,.91),(x+(.028 if x<0 else -.028),1.115,.002),'bone',r=.032,bev=.005,axis='z')
    # anti-skuff side split horizontal ribs, physically on panel
    for y in (.37,1.81): A.b((.075,.033,1.00),(x,y,0),'satinsteel',r=.005,axis='z')
# rear bulkhead, backed by side posts and top canopy
A.b((2.12,1.58,.075),(0,1.055,.445),'graphite',r=.025,bev=.004,axis='z')
A.b((1.99,1.37,.028),(0,1.085,.391),'bone',r=.02,bev=.003,axis='z')
# Interior segmentation of rear wall separated by proper seams
for x in (-.62,.62):
    A.b((.69,1.16,.017),(x,1.18,.371),'cream',r=.026,axis='z')
    A.b((.62,.012,.02),(x,1.675,.357),'satinsteel',r=.004)
    for sx in (x-.28,x+.28):A.s((sx,1.52,.358),'steel',r=.008)
A.b((.44,1.17,.02),(0,1.17,.365),'graphite',r=.014)
for x in (-.95,.95):
    A.b((.045,1.46,.065),(x,1.06,-.375),'steel',r=.008,axis='y')
# overhead boxed superstructure with chamfered front header + segmented insets
A.b((2.27,.16,1.10),(0,1.854,0),'graphite',r=.045,bev=.013,axis='y')
A.b((2.14,.045,1.00),(0,1.936,-.01),'bone',r=.036,bev=.006,axis='y')
A.b((2.10,.095,.065),(0,1.795,-.515),'satinsteel',r=.013)
A.b((1.53,.020,.032),(.15,1.783,-.554),'lamp',group='Overhead_Light_Emitter',r=.006)
A.b((.32,.055,.073),(-.87,1.801,-.537),'deep',r=.012)
# rail around bed at y .68 with full width material foundation
A.b((2.03,.115,.865),(0,.59,-.014),'graphite',r=.048,bev=.01,axis='y')
A.b((2.01,.065,.87),(0,.651,-.015),'satinsteel',r=.036,bev=.006,axis='y')
A.b((1.91,.19,.77),(0,.744,-.01),'fabric',r=.055,bev=.014,axis='y')
# mattress piping above base and side piping not floating
A.b((1.86,.012,.75),(0,.853,-.01),'cream',r=.032,bev=.003,axis='y')
# pillow right side with impression via flattened ellipsoids
pill=trimesh.creation.icosphere(subdivisions=2,radius=1.0)
pill.apply_scale([.285,.065,.297]);pill.apply_translation([.67,.91,-.00]);A.put(pill,'fabric')
# blanket - actual surface with hangover and coherent top silhouette
xs=np.linspace(-.915,.30,26); zs=np.linspace(-.345,.334,16)
verts=[]
for xx in xs:
  for zz in zs:
    yy=.887 + .011*math.sin((xx+.92)*10) + .003*math.sin((zz+.36)*24)
    if zz<-.300: yy-=.017*((-.300-zz)/.045)
    verts.append([xx,yy,zz])
nz=len(zs);faces=[]
for ii in range(len(xs)-1):
 for jj in range(nz-1):
  q=ii*nz+jj;faces.extend([[q,q+nz,q+1],[q+1,q+nz,q+nz+1]])
blank=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
A.put(blank,'olive',group='Bedding_Blanket')
A.b((.023,.015,.69),(.286,.866,-.009),'fabricdark',group='Bedding_Blanket',r=.005)
# Underbed housing + real bordered drawer apertures, fronts recessed into surrounding cutout visually
A.b((2.07,.33,.925),(0,.328,-.008),'deep',r=.025,bev=.003,axis='y')
for i,cx in enumerate((-.662,0,.662),1):
    A.b((.626,.255,.035),(cx,.312,-.506),'graphite',group=f'Drawer_{i:02}_Frame',r=.013)
    A.b((.580,.209,.025),(cx,.314,-.529),'bone',group=f'Drawer_{i:02}_Face',r=.018,bev=.003)
    A.b((.23,.022,.018),(cx,.297,-.547),'deep',group=f'Drawer_{i:02}_Handle',r=.010)
    A.c((cx-.085,.304,-.563),(cx+.085,.304,-.563),.005,'steel',group=f'Drawer_{i:02}_Handle')
    A.b((.08,.035,.008),(cx-.219,.385,-.545),'ochre',group=f'Drawer_{i:02}_Face',r=.003)
    for sx in [cx-.25,cx+.25]:
        for yy in (.23,.403): A.s((sx,yy,-.545),'steel',r=.004)
# Curtain track is suspended between actual frame posts, partial curtain with rolled section
A.c((-1.017,1.684,-.536),(1.017,1.684,-.536),.018,'satinsteel',group='Curtain_Track')
for x in (-1.014,1.014):A.b((.035,.07,.06),(x,1.722,-.532),'graphite',r=.009)
# partly stowed curtain at left, with multiple visible folds and edge bar
for i in range(8):
    xx=-.985+i*.029
    A.b((.041,1.035,.011),(xx,1.112,-.559+(i%2)*.008),'fabricdark',group='Privacy_Curtain',r=.004,bev=.002)
A.c((-.995,.59,-.567),(-.764,.59,-.567),.012,'steel',group='Privacy_Curtain')
# Stationary reading light mounted to back bulkhead; fully connected via articulated arm
A.b((.15,.11,.07),(-.82,1.49,.336),'deep',group='Reading_Light_Assembly',r=.02)
for sx in (-.87,-.77):A.s((sx,1.49,.295),r=.006)
A.c((-.82,1.49,.297),(-.67,1.43,.12),.017,'satinsteel',group='Reading_Light_Assembly')
A.c((-.67,1.43,.12),(-.59,1.39,-.04),.016,'satinsteel',group='Reading_Light_Assembly')
A.c((-.59,1.39,-.06),(-.42,1.39,-.06),.037,'graphite',group='Reading_Light_Assembly')
A.b((.15,.024,.065),(-.42,1.355,-.06),'lamp',group='Reading_Light_Emitter',r=.02)
# recessed display with actual surrounding flange, under shelf attached to rear bulkhead
A.b((.39,.27,.042),(.43,1.36,.338),'deep',r=.022)
A.b((.32,.20,.012),(.43,1.36,.306),'blackglass',r=.009)
A.screen(.43,1.36,.297,.297,.17,'BERTH / 01',['LIGHT  AUTO','AIR     21 C','PRIVACY READY'])
# supported shelf opposite light with attached brackets and inner lip
A.b((.37,.023,.18),(.77,1.18,.255),'steel',group='Personal_Shelf',r=.01)
for x in (.63,.91): A.b((.022,.14,.022),(x,1.10,.307),'graphite',group='Personal_Shelf',r=.005)
A.b((.37,.026,.020),(.77,1.190,.165),'graphite',group='Personal_Shelf',r=.003)
# climate ventilation grille on headboard, frame and recessed slots
A.b((.63,.16,.035),(.0,1.69,.340),'deep',r=.013)
for ix in range(13):A.b((.014,.104,.007),(-.27+ix*.045,1.69,.318),'satinsteel',r=.003)
# upper main stencilled plate flush to exterior front header
A.tag(-.70,1.866,-.554,.37,.092,'HAB-01','CREW BERTH')
bunk_meta=A.export()

# LOCKER — reinforced cabinet, split doors, grounded hinges, flush labels
L=Asset('locker_retro')
# footprint width 1.16, 2.04 tall, depth .66. Floor legs concealed by plinth
L.b((1.155,.11,.68),(0,.105,0),'deep',r=.035,bev=.006,axis='y')
for x in (-.48,.48):
 for z in (-.22,.22):L.b((.07,.11,.09),(x,.065,z),'graphite',r=.007,axis='y')
# side casing with extruded edge ribs
L.b((1.17,1.86,.68),(0,1.085,.0),'graphite',r=.045,bev=.009,axis='y')
L.b((1.075,1.73,.598),(0,1.11,.00),'bone',r=.033,bev=.009,axis='y')
# split door enclosure (dark reveal) back sits toward negative Z
L.b((1.08,1.66,.044),(0,1.115,-.336),'deep',r=.020)
for i,cx in enumerate((-.276,.276)):
    g=f'Locker_Door_{"L" if i==0 else "R"}'
    L.b((.514,1.595,.064),(cx,1.108,-.374),'graphite',group=g,r=.017)
    L.b((.464,1.536,.041),(cx,1.113,-.418),'bone',group=g,r=.035,bev=.006)
    # recessed shaped centre service panel with layered lip, bottom flush
    L.b((.369,.485,.021),(cx,1.18,-.448),'satinsteel',group=g,r=.015)
    L.b((.341,.457,.019),(cx,1.18,-.461),'graphite',group=g,r=.012)
    L.b((.30,.395,.007),(cx,1.18,-.475),'cream',group=g,r=.012)
    # vertically recessed industrial pull & lock with actual protective bracket
    handle_x=cx+(0.151 if i==0 else -.151)
    L.b((.055,.253,.023),(handle_x,.922,-.467),'deep',group=g,r=.014)
    L.c((handle_x,.85,-.506),(handle_x,1.012,-.506),.012,'satinsteel',group=g)
    L.c((handle_x,.87,-.481),(handle_x,.87,-.508),.01,'steel',group=g)
    L.c((handle_x,.996,-.481),(handle_x,.996,-.508),.01,'steel',group=g)
    # mechanical lock face beneath handle, not floating
    L.b((.051,.062,.012),(handle_x,.788,-.476),'warning',group=g,r=.007)
    L.s((handle_x,.788,-.485),r=.007,group=g)
    # maintenance vents in actual top recess
    L.b((.343,.162,.025),(cx,1.72,-.444),'deep',group=g,r=.007)
    for xx in np.linspace(cx-.148,cx+.148,9):L.b((.016,.108,.008),(float(xx),1.72,-.464),'steel',group=g,r=.003)
    # hinges attached to door and cabinet side, visible at front
    hx=-.547 if i==0 else .547
    for yy in (.405,1.745):
        L.b((.043,.12,.074),(hx,yy,-.372),'satinsteel',group=g,r=.010)
        L.c((hx,yy-.043,-.424),(hx,yy+.043,-.424),.009,'graphite',group=g)
    # reinforced lower panel
    L.b((.40,.27,.014),(cx,.467,-.447),'graphite',group=g,r=.016)
    L.b((.373,.240,.006),(cx,.467,-.458),'bone',group=g,r=.012)
    L.tag(cx,1.505,-.463,.35,.087,'CREW '+str(i+1).zfill(2),'PERSONAL LOCKER',name='locker_tag_'+str(i)+'.png')
# top instrument housing, label and integrated warning band
L.b((1.155,.16,.68),(0,1.972,.0),'graphite',r=.035,bev=.007,axis='y')
L.b((1.05,.045,.57),(0,2.045,.01),'cream',r=.015,axis='y')
L.b((1.13,.077,.034),(0,1.937,-.357),'ochre',r=.009)
for x in np.linspace(-.505,.505,12):L.b((.024,.03,.038),(float(x),1.938,-.380),'deep',r=.003)
# cabinet rear service rails and recessed foot skirting, robust physically connected
for x in (-.55,.55):
 L.b((.035,1.68,.70),(x,1.07,0),'satinsteel',r=.005,axis='y')
for y in (.25,1.83):
 L.b((1.12,.025,.70),(0,y,0),'steel',r=.004)
L.tag(0,1.967,-.382,.41,.08,'ARES | LOCKERS','SUPPLY / STORAGE')
locker_meta=L.export()

# COMMON TABLE — four load-bearing foot assemblies, integrated terminal and useful details
T=Asset('common_table_retro')
# tabletop oriented x/z, upper surface y=.82
T.b((1.86,.105,.98),(0,.805,0),'graphite',r=.11,bev=.020,axis='y')
T.b((1.765,.058,.896),(0,.877,0),'cream',r=.083,bev=.009,axis='y')
# rugged segmented bumper around rim front and side, attached not hovering
T.b((1.71,.019,.026),(0,.826,-.491),'satinsteel',r=.007)
T.b((1.71,.019,.026),(0,.826,.491),'satinsteel',r=.007)
for x in (-.921,.921):T.b((.026,.033,.73),(x,.82,0),'satinsteel',r=.006,axis='y')
# full-length central underframe rail and V braced table ends
for z in (-.31,.31): T.b((1.53,.085,.06),(0,.682,z),'steel',r=.015,axis='y')
for x in (-.74,.74):
    for z in (-.32,.32):
        T.b((.07,.64,.075),(x,.39,z),'graphite',r=.023,bev=.004,axis='y')
        T.b((.105,.036,.15),(x,.048,z),'satinsteel',r=.012,axis='y')
        T.b((.116,.047,.11),(x,.69,z),'steel',r=.012,axis='y')
    # cross brace between foot structure along z
    T.c((x,.28,-.32),(x,.52,.32),.022,'satinsteel')
    T.c((x,.28,.32),(x,.52,-.32),.022,'satinsteel')
    T.b((.09,.065,.76),(x,.086,0),'graphite',r=.015,axis='y')
T.b((1.45,.060,.40),(0,.37,0),'graphite',r=.01,axis='y')
# centre embedded screen: cast border deeper than top, textured readout sits inside cavity
T.b((.87,.033,.492),(0,.916,0),'graphite',group='Table_Planning_Console',r=.055,bev=.005,axis='y')
T.b((.793,.022,.409),(0,.936,0),'blackglass',group='Table_Planning_Console',r=.039,bev=.003,axis='y')
# Screen graphics are several inset flush-light guides on y upward; draw into 2d texture then use XZ surface with explicit winding
im=Image.new('RGBA',(900,480),(12,33,36,255));d=ImageDraw.Draw(im)
d.rounded_rectangle((18,15,882,465),radius=20,outline=(88,131,125),width=8)
d.text((47,35),'ARES / CREW OPERATIONS',font=ImageFont.truetype(BOLD,39),fill=(228,187,101))
for j,line in enumerate(['MISSION BRIEFING','SYSTEMS / NOMINAL','SURFACE CONDITIONS']):
 yy=112+j*95;d.text((54,yy),line,font=ImageFont.truetype(FONT,32),fill=(158,219,177))
 d.line((410,yy+30,823,yy+30),fill=(63,126,112),width=5)
 d.rectangle((414,yy+15,500+j*100,yy+28),fill=(106,183,153))
d.text((55,419),'SOL 014     -     ARES HABITAT',font=ImageFont.truetype(FONT,22),fill=(211,198,146))
im.save(os.path.join(ROOT,'textures','table_planning_display.png'))
# make quad in XZ plane on surface upward (+Y); with UV orientation z+ top in screen plane
verts=np.array([[-.375,.949,-.186],[.375,.949,-.186],[.375,.949,.186],[-.375,.949,.186]])
# look from above with top toward z+; UV corners appropriately
m=trimesh.Trimesh(vertices=verts,faces=[[0,1,2],[0,2,3]],process=False)
m.visual=trimesh.visual.TextureVisuals(uv=np.array([[1,0],[0,0],[0,1],[1,1]],dtype=float),material=trimesh.visual.material.PBRMaterial(name='planning_screen',baseColorTexture=im,metallicFactor=0,roughnessFactor=.2,doubleSided=True))
T.labels.append(('Planning_Display',m))
# physical bevel edging around screen, cannot float: four trim rails embed onto rim
for xx in (-.438,.438):T.b((.015,.018,.39),(xx,.94,0),'satinsteel',group='Table_Planning_Console',r=.004,axis='y')
# colour-keyed tactile buttons integrated to both sides of display
for z in (-.29,.29):
 for idx,x in enumerate(np.linspace(-.33,.33,5)):
    T.b((.065,.010,.038),(float(x),.909,z),'ochre' if idx==0 else 'graphite',group='Table_Controls',r=.008,axis='y')
# cup holders as inset outlined docking stations on four corners: ring model sits flush, centre dark
for x in (-.689,.689):
 for z in (-.27,.27):
    T.c((x,.896,z),(x,.907,z),.075,'graphite',group='Cup_Retainers',section=22)
    T.c((x,.908,z),(x,.913,z),.058,'rubber',group='Cup_Retainers',section=22)
    T.c((x,.910,z),(x,.918,z),.042,'deep',group='Cup_Retainers',section=22)
# under table small drawer, rails, recessed pull
T.b((.44,.13,.43),(0,.629,-.20),'deep',group='Under_Table_Storage',r=.028,axis='y')
T.b((.37,.105,.022),(0,.629,-.433),'bone',group='Under_Table_Storage',r=.019)
T.b((.155,.014,.012),(0,.626,-.448),'steel',group='Under_Table_Storage',r=.006)
# side ID plaques and corner safety strips attached to base
T.tag(0,.802,-.502,.42,.083,'ARES / COMMON','CREW MESS & BRIEFING')
for x in (-.785,.785):
 for z in (-.416,.416):T.b((.065,.009,.025),(x,.910,z),'warning',r=.006,axis='y')
table_meta=T.export()

all_data={'bunk':bunk_meta,'locker':locker_meta,'table':table_meta}
with open(os.path.join(ROOT,'asset_manifest.json'),'w') as f:json.dump(all_data,f,indent=2)
for k,v in all_data.items():print(k, v)
