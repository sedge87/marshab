"""Mars Habitat - Hydroponics Phase 2: five optimised game assets.
Uses Python, trimesh, Pillow. Geometry in metres, +Y up / -Z forward.
Meshes grouped by material and/or interactive group. All textures are procedurally created.
Copyright: generated for the user; license to use and modify as needed.
"""
from __future__ import annotations
import os, math, json, random, zlib
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual import TextureVisuals

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
MODEL=os.path.join(ROOT,'models');TEX=os.path.join(ROOT,'textures')
os.makedirs(MODEL,exist_ok=True);os.makedirs(TEX,exist_ok=True)

PAL={
    'shell':('#D9DED7',.13,.67,'ceramic'),
    'cream':('#D9D0BB',.02,.73,'polymer'),
    'graphite':('#354248',.08,.67,'polymer'),
    'carbon':('#1D292F',.12,.83,'polymer'),
    'alloy':('#93A5AC',.80,.31,'brushed'),
    'trim':('#657981',.69,.42,'brushed'),
    'amber':('#D88D4E',.22,.51,'polymer'),
    'safety':('#F2B257',.04,.55,'polymer'),
    'rubber':('#343A39',.01,.95,'rubber'),
    'fabric':('#748C7F',.0,.94,'fabric'),
    'fabricwarm':('#9D9584',.0,.96,'fabric'),
    'seat':('#526468',.01,.91,'fabric'),
    'bamboo':('#BDA687',.03,.71,'wood'),
    'glow':('#FFEAC4',.0,.32,'emissive'),
    'cyan':('#6FD5D8',.0,.41,'emissive'),
    'mint':('#81C69A',.01,.4,'emissive'),
    'red':('#DA6A59',.02,.6,'polymer'),
    'screen':('#142832',.05,.36,'polymer'),
}

PAL.update({
 'leaf1':('#63A354',0.0,.92,'fabric'),
 'leaf2':('#8EBB61',0.0,.92,'fabric'),
 'leaf3':('#386F4E',0.0,.93,'fabric'),
 'substrate':('#615B49',0.0,.98,'rubber'),
 'tank':('#B2C3C5',.10,.49,'polymer'),
 'fluid':('#4D9DA6',.0,.39,'polymer'),
 'clear':('#B1D6DC',.0,.18,'ceramic'),
 'lime':('#ACC76F',0.0,.68,'polymer'),
})

def colorhex(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))

def font(size=25,bold=False):
    p='/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if bold else '')+'.ttf'
    return ImageFont.truetype(p,size) if os.path.isfile(p) else ImageFont.load_default()


def texture(name,size=256):
    h,metal,rough,kind=PAL[name]
    base=np.array(colorhex(h),dtype=np.float32)
    rng=np.random.default_rng(600+zlib.adler32(name.encode()))
    g=np.indices((size,size))
    y,x=g[0],g[1]
    noise=rng.normal(0,1,(size,size))
    if kind=='brushed':
        lines=np.sin(y*.46)*.75+np.sin(y*.09)*.45
        pat=3.5*lines+2.4*noise
    elif kind=='fabric':
        pat=4.5*((x%5==0)*1-(x%5==3)*.6+(y%5==0)*1-(y%5==3)*.6)+1.2*noise
    elif kind=='wood':
        pat=5*np.sin(y*.13+2*np.sin(x*.011))+2.2*np.sin(y*.65)+2*noise
    elif kind=='rubber':
        pat=3.5*noise+1.1*np.sin(x*.32)*np.sin(y*.28)
    elif kind=='ceramic':
        pat=2.2*noise+0.8*np.sin(x*.07)
    elif kind=='polymer':
        pat=2.7*noise+0.5*np.sin(y*.32)
    else:pat=0.8*noise
    arr=np.clip(base[None,None,:]+pat[:,:,None],0,255).astype('uint8')
    img=Image.fromarray(arr,'RGB')
    img.save(os.path.join(TEX,f'{name}_albedo.png'))
    return img

TEXTURES={name:texture(name) for name in PAL}

def interface_texture(kind):
    im=Image.new('RGB',(640,384),(10,26,36));d=ImageDraw.Draw(im)
    d.rounded_rectangle((8,8,632,376),radius=14,outline=(62,116,127),width=5)
    title='CREW COMMON // 04' if kind=='table' else 'TRAINING // ACTIVE'
    d.text((32,27),title,font=font(27,True),fill=(174,223,227))
    d.line((30,75,610,75),fill=(53,94,109),width=3)
    if kind=='table':
        d.text((32,96),'HABITAT DAILY PLAN',font=font(19),fill=(128,159,161))
        for i,x in enumerate([34,194,354]):
            d.rounded_rectangle((x,148,x+134,290),radius=8,fill=(24,55,66),outline=(42,103,113),width=2)
            d.text((x+13,164),['O2 LEVEL','WATER','CREW'][i],font=font(16),fill=(112,185,193))
            d.text((x+13,210),['98.4%','82%','06/06'][i],font=font(26,True),fill=(226,229,216))
        d.rounded_rectangle((511,149,606,289),radius=8,outline=(76,113,119),width=2)
        for i in range(6):d.ellipse((528+i%3*24,183+i//3*35,542+i%3*24,197+i//3*35),fill=(111,185,140))
        d.text((35,329),'SYSTEMS NOMINAL',font=font(18,True),fill=(123,204,159))
    else:
        d.text((32,93),'RESISTANCE',font=font(19),fill=(128,159,161))
        d.text((32,125),'12.5',font=font(60,True),fill=(214,233,226))
        d.text((205,146),'KG / SIDE',font=font(18),fill=(131,180,186))
        for i in range(9):
            x=34+i*64
            height=int(26+28*math.sin((i+1)*.27)**2+13*i/9)
            d.rounded_rectangle((x,248-height,x+38,248),radius=6,fill=(38,125,134) if i!=6 else (213,152,73))
        d.text((33,288),'SET  02/04',font=font(26,True),fill=(211,219,212))
        d.text((33,336),'READY   •   GRIP TO START',font=font(18),fill=(110,195,158))
    im.save(os.path.join(TEX,f'{kind}_display.png'))
    return im
INTERFACE={'table':interface_texture('table'),'exercise':interface_texture('exercise')}

def id_texture(code):
    im=Image.new('RGB',(512,152),(216,219,207));d=ImageDraw.Draw(im)
    d.rectangle((0,0,511,151),outline=(81,102,111),width=8)
    d.rectangle((10,9,27,142),fill=(213,133,71))
    d.text((50,19),'CREW STORAGE',font=font(27,True),fill=(61,78,85))
    d.text((50,67),code,font=font(47,True),fill=(37,58,67))
    im.save(os.path.join(TEX,f'crew_{code.replace(" ","_")}.png'))
    return im
TAGS={'L01':id_texture('L01'),'L02':id_texture('L02')}


def transf_mesh(mesh,pos,rot=None):
    if rot is not None:mesh.apply_transform(rot)
    mesh.apply_translation(pos)
    return mesh

def uv_planar(m,scale=.28):
    """Per triangle dominant-axis UVs, preserving tangent orientation at planar details."""
    verts=m.vertices[m.faces].reshape(-1,3)
    tri_normals=m.face_normals
    a=np.argmax(np.abs(tri_normals),axis=1)
    base=np.empty((len(m.faces),3,2),dtype='float32')
    for f,axis in enumerate(a):
        xyz=m.vertices[m.faces[f]]
        if axis==0: uv=xyz[:,[2,1]]
        elif axis==1:uv=xyz[:,[0,2]]
        else:uv=xyz[:,[0,1]]
        base[f]=uv/scale
    return verts,base.reshape(-1,2)

def prepared_mesh(mesh,material,scale=.28):
    # split vertices for UV mapping; geometry unchanged; GLB exports per-material PBR textures
    verts,uv=uv_planar(mesh,scale)
    faces=np.arange(len(verts),dtype=int).reshape(-1,3)
    clean=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
    clean.visual=TextureVisuals(uv=uv,material=material)
    return clean


def pbr(name):
    h,met,rough,kind=PAL[name]
    kw={'name':name, 'baseColorFactor':[255,255,255,255], 'baseColorTexture':TEXTURES[name],
        'metallicFactor':met,'roughnessFactor':rough}
    if kind=='emissive':kw['emissiveFactor']=[.82,.65,.43] if name=='glow' else ([.07,.75,.84] if name=='cyan' else [.10,.62,.34])
    return PBRMaterial(**kw)

MATS={name:pbr(name) for name in PAL}
# Transparent polycarbonate cover and protective liquid-level tube.
MATS['clear']=PBRMaterial(name='transparent_polycarbonate',baseColorFactor=[197,228,234,65],
    metallicFactor=0,roughnessFactor=.23,alphaMode='BLEND',doubleSided=True)
MATS['fluid']=PBRMaterial(name='nutrient_solution',baseColorFactor=[79,170,182,245],
    metallicFactor=0,roughnessFactor=.3,alphaMode='BLEND',doubleSided=True)
MATS['tablet_screen']=PBRMaterial(name='tablet_UI',baseColorFactor=[255]*4,baseColorTexture=INTERFACE['table'],metallicFactor=0,roughnessFactor=.28,emissiveFactor=[.11,.16,.17],doubleSided=True)
MATS['exercise_screen']=PBRMaterial(name='exercise_UI',baseColorFactor=[255]*4,baseColorTexture=INTERFACE['exercise'],metallicFactor=0,roughnessFactor=.28,emissiveFactor=[.12,.16,.16],doubleSided=True)
for n,img in TAGS.items():MATS['tag_'+n]=PBRMaterial(name='CREW_'+n,baseColorFactor=[255]*4,baseColorTexture=img,metallicFactor=0,roughnessFactor=.73,doubleSided=True)

class Asset:
    def __init__(self,name,desc,placement='floor',interactive=()):
        self.name=name;self.desc=desc;self.placement=placement;self.interactive=list(interactive)
        self.parts=defaultdict(list);self.extras=[]
    def add(self,m,mat='shell',group='static'):
        if m is not None:self.parts[(group,mat)].append(m)
        return m
    def box(self,p,d,mat='shell',group='static'):
        m=trimesh.creation.box(extents=d)
        return self.add(transf_mesh(m,p),mat,group)
    def chamfer_y(self,p,w,h,d,c=.045,mat='shell',group='static'):
        x,y,z=p;a=w/2;b=d/2;c=min(c,.45*a,.45*b)
        poly=[(-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),(a-c,b),(-a+c,b),(-a,b-c),(-a,-b+c)]
        vertices=np.asarray([[xx+x,y-h/2,zz+z] for xx,zz in poly]+[[xx+x,y+h/2,zz+z] for xx,zz in poly])
        faces=[]
        for i in range(1,7):faces.append([0,i+1,i]);faces.append([8,8+i,8+i+1])
        for i in range(8):
            j=(i+1)%8;faces.extend([[i,j,8+j],[i,8+j,i+8]])
        m=trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
        return self.add(m,mat,group)
    def chamfer_z(self,p,w,h,d,c=.045,mat='shell',group='static'):
        x,y,z=p;a=w/2;b=h/2;c=min(c,.45*a,.45*b)
        poly=[(-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),(a-c,b),(-a+c,b),(-a,-b+c),(-a,-b+c)]
        poly[-1]=(-a,-b+c)
        v=np.asarray([[xx+x,yy+y,z-d/2] for xx,yy in poly]+[[xx+x,yy+y,z+d/2] for xx,yy in poly])
        faces=[]
        for i in range(1,7):faces.extend([[0,i,i+1],[8,8+i+1,8+i]])
        for i in range(8):
            j=(i+1)%8;faces.extend([[i,i+8,j+8],[i,j+8,j]])
        return self.add(trimesh.Trimesh(vertices=v,faces=faces,process=False),mat,group)
    def cyl(self,p,r,length,axis='y',mat='alloy',group='static',n=20):
        m=trimesh.creation.cylinder(radius=r,height=length,sections=n)
        if axis=='y':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
        if axis=='x':m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
        return self.add(transf_mesh(m,p),mat,group)
    def sphere(self,p,scale,mat='graphite',group='static',sub=2):
        m=trimesh.creation.icosphere(subdivisions=sub,radius=1)
        m.apply_scale(scale)
        return self.add(transf_mesh(m,p),mat,group)
    def tube(self,a,b,r=.018,mat='alloy',group='static',n=12):
        a=np.asarray(a,float);b=np.asarray(b,float);v=b-a
        if np.linalg.norm(v)<1e-8:return
        m=trimesh.creation.cylinder(radius=r,height=np.linalg.norm(v),sections=n)
        m.apply_transform(trimesh.geometry.align_vectors([0,0,1],v))
        return self.add(transf_mesh(m,(a+b)/2),mat,group)
    def curve(self,pts,r=.009,mat='rubber',group='static',n=10):
        for a,b in zip(pts[:-1],pts[1:]):self.tube(a,b,r,mat,group,n)
    def torus(self,p,R=.065,r=.009,mat='alloy',group='static',maj=22,minseg=8,rot=None):
        verts=[];faces=[]
        for i in range(maj):
            t=i*math.tau/maj
            for j in range(minseg):
                s=j*math.tau/minseg
                xx=(R+r*math.cos(s))*math.cos(t)
                yy=(R+r*math.cos(s))*math.sin(t)
                zz=r*math.sin(s)
                verts.append([xx,yy,zz])
        for i in range(maj):
            for j in range(minseg):
                a=i*minseg+j;b=((i+1)%maj)*minseg+j;c=((i+1)%maj)*minseg+(j+1)%minseg;d=i*minseg+(j+1)%minseg
                faces.extend([[a,b,c],[a,c,d]])
        m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
        if rot is not None:m.apply_transform(rot)
        return self.add(transf_mesh(m,p),mat,group)
    def decal(self,p,w,h,which='tag_L01',orient='front',group='static'):
        x,y,z=p
        if orient=='front':
            vert=np.asarray([[x-w/2,y-h/2,z],[x+w/2,y-h/2,z],[x+w/2,y+h/2,z],[x-w/2,y+h/2,z]])
        elif orient=='top':
            vert=np.asarray([[x-w/2,y,z+h/2],[x+w/2,y,z+h/2],[x+w/2,y,z-h/2],[x-w/2,y,z-h/2]])
        m=trimesh.Trimesh(vertices=vert,faces=[[0,1,2],[0,2,3]],process=False)
        uvs=np.asarray([[1,0],[0,0],[0,1],[1,1]] if orient=='front' else [[0,0],[1,0],[1,1],[0,1]])
        m.visual=TextureVisuals(uv=uvs,material=MATS[which])
        self.extras.append((group,which,m))
    def export(self):
        scene=trimesh.Scene()
        for (group,mat),ls in self.parts.items():
            merged=trimesh.util.concatenate(ls)
            obj=prepared_mesh(merged,MATS[mat],scale=.32 if mat in ('alloy','trim','shell') else .22)
            key=f'{group}__{mat}'
            scene.add_geometry(obj,node_name=key,geom_name=key)
        for group,mat,m in self.extras:
            key=f'{group}__{mat}'
            scene.add_geometry(m,node_name=key,geom_name=key)
        dest=os.path.join(MODEL,self.name+'.glb')
        scene.export(dest)
        chk=trimesh.load(dest,force='scene')
        tri=sum(len(m.faces) for m in chk.geometry.values());count=len(chk.geometry)
        verts=np.concatenate([m.vertices for m in chk.geometry.values()],axis=0)
        bb=np.round(np.array([verts.min(axis=0),verts.max(axis=0)]),3)
        mats=sorted(set([key[1] for key in self.parts]+[x[1] for x in self.extras]))
        md=dict(id=self.name,description=self.desc,category='hydroponics',placement=self.placement,
                bounds_m=bb.tolist(),dimensions_m=np.round(bb[1]-bb[0],3).tolist(),triangles=tri,
                mesh_nodes=count,materials=mats,interactive_mesh_prefixes=self.interactive,
                asset_catalog_id=self.name,origin='floor centre' if self.placement=='floor' else 'wall-plate centre',
                coordinate_system='Godot +Y up, local -Z forward; 1 unit = 1 metre',
                review_status='mesh validated, not yet tested inside actual game')
        with open(os.path.join(MODEL,self.name+'.json'),'w') as f:json.dump(md,f,indent=2)
        print('EXPORTED',self.name,tri,'triangles',count,'meshes',len(mats),'materials')
        return md


# ---------------------------------------------------------------------------
# Hydroponics-specific sheet labels, diagnostic graphics and plant geometry
# ---------------------------------------------------------------------------

def label_texture(tag,top,sub,accent=(176,185,136)):
    im=Image.new('RGB',(600,260),(210,216,206));d=ImageDraw.Draw(im)
    d.rectangle((0,0,599,259), outline=(44,67,73),width=9)
    d.rectangle((10,10,34,250),fill=accent)
    d.text((55,23),top,font=font(29,True),fill=(42,71,80))
    d.text((55,83),tag,font=font(57,True),fill=(26,48,56))
    d.text((55,172),sub,font=font(23),fill=(61,78,79))
    im.save(os.path.join(TEX,f'hydro_{tag.lower().replace(" ","_")}.png'))
    return im

def screen_texture(kind):
    im=Image.new('RGB',(760,520),(10,27,35));d=ImageDraw.Draw(im)
    d.rounded_rectangle((7,7,752,511),radius=24,outline=(55,103,108),width=6)
    if kind=='rack':
        top='CROP RACK // STATUS';data=[('LIGHT','ON'),('FLOW','NOMINAL'),('EC','1.8'),('pH','6.1')]
    elif kind=='mixer':
        top='NUTRIENT DOSING // SYSTEM';data=[('TANK A','72%'),('TANK B','64%'),('FLOW','2.3'),('EC','1.8')]
    elif kind=='sensor':
        top='HYDROPONICS // ENVIRONMENT';data=[('AIR TEMP','22.4 C'),('HUMIDITY','64%'),('WATER pH','6.1'),('EC','1.8')]
    else:top='GERMINATION // STATUS';data=[('HUMIDITY','78%'),('AIR TEMP','23.0 C'),('LIGHT','18 H'),('DAY','04')]
    d.text((35,28),top,font=font(31,True),fill=(180,228,225))
    d.line((32,93,730,93),fill=(55,101,104),width=4)
    for i,(k,v) in enumerate(data):
        row=i//2;col=i%2;x=34+col*355;y=115+row*160
        d.rounded_rectangle((x,y,x+333,y+140),radius=12,fill=(19,48,57),outline=(46,95,104),width=2)
        d.text((x+18,y+16),k,font=font(22),fill=(119,168,172))
        d.text((x+18,y+64),v,font=font(43,True),fill=(222,236,217))
        d.rectangle((x+18,y+123,x+175,y+128),fill=(123,190,142))
    d.text((38,458),'RESEARCH HABITAT  /  SIMULATION READOUT',font=font(21),fill=(116,166,161))
    im.save(os.path.join(TEX,f'{kind}_ui.png'))
    return im

for kind in ['rack','mixer','sensor','seedling']:
    MATS[kind+'_ui']=PBRMaterial(name=kind+'_screen_ui',baseColorFactor=[255,255,255,255],
      baseColorTexture=screen_texture(kind),roughnessFactor=.31,metallicFactor=0,
      emissiveFactor=[.26,.35,.32],doubleSided=True)
for tag,top,sub,accent in [
    ('GR-01','PLANT SYSTEMS','HYDROPONIC GROW RACK',(111,171,113)),
    ('GM-01','LIFE SCIENCES','NUTRIENT BLEND UNIT',(228,154,81)),
    ('GS-01','LIFE SCIENCES','SEEDLING STATION',(117,177,107)),
    ('HC-01','HARVEST MODULE','SANITISE BEFORE USE',(218,167,96)),
    ('ENV-01','ENVIRONMENT','GROW SYSTEM TELEMETRY',(92,165,172))]:
    MATS['label_'+tag]=PBRMaterial(name='label_'+tag,baseColorFactor=[255]*4,
        baseColorTexture=label_texture(tag,top,sub,accent),metallicFactor=0,roughnessFactor=.8,doubleSided=True)

# UV planar helper in Asset gives all hard-surface meshes consistent material texture tiling.
# Leaves are actual shaped geometry, not box placeholders or hundreds of loose cylinders.

def add_leaf(a,base,direction,length,width,mat='leaf1',group='Crop_Canopy'):
    base=np.array(base,float);direction=np.array(direction,float)
    direction[1]=0
    norm=np.linalg.norm(direction)
    if norm<.01:direction=np.array([1,0,0]);norm=1
    direction/=norm
    side=np.array([-direction[2],0,direction[0]])
    # Three-segment sculpted leaf with modest midrib, softened leading/tip edges.
    coords=[]
    rows=[(0.03,.14,0.0),(.37,.70,.10),(.72,1.0,.17),(1.0,.03,.06)]
    for t,k,bend in rows:
        cen=base+direction*length*t+np.array([0,(.02+length*.56*t + bend*length),0])
        coords += [cen-side*width*k/2, cen, cen+side*width*k/2]
    faces=[]
    for r in range(3):
        for c in range(2):
            ii=r*3+c;faces.extend([[ii,ii+1,ii+4],[ii,ii+4,ii+3]])
    mesh=trimesh.Trimesh(vertices=np.array(coords),faces=np.array(faces),process=False)
    return a.add(mesh,mat,group)

def lettuce(a,pos,scale=1,group='Crop_Canopy',seedling=False):
    rng=random.Random(int((pos[0]*1000+pos[2]*940+pos[1]*777)*12345)&0xffffffff)
    x,y,z=pos
    # Subtle, low-cost socket. Plant roots are inside the tray: no floating stems.
    if not seedling:
        a.cyl((x,y+.009,z),.040*scale,.024*scale,mat='graphite',n=10,group='Crop_Pods')
    a.cyl((x,y+.04*scale,z),.007*scale,.065*scale,mat='leaf3',n=8,group=group)
    for i in range(7 if not seedling else 4):
        ang=(2*math.pi*i)/(7 if not seedling else 4) + rng.uniform(-.18,.18)
        d=[math.cos(ang),0,math.sin(ang)]
        length=(.08 if not seedling else .035)*scale*rng.uniform(.85,1.28)
        width=(.075 if not seedling else .027)*scale*rng.uniform(.8,1.18)
        mat=['leaf1','leaf2','leaf3','leaf1','leaf2','leaf1','leaf3'][i]
        add_leaf(a,(x,y+.027*scale,z),d,length,width,mat,group)

def frame_post(a,x,z,y_low,y_high,mat='alloy',w=.039):
    a.box((x,(y_low+y_high)/2,z),(w,y_high-y_low,w),mat)

def gauge(a,p,r=.032,group='Gauge'):
    x,y,z=p
    a.cyl((x,y,z),r,.018,axis='z',mat='graphite',group=group,n=22)
    a.cyl((x,y,z-.013),r*.78,.004,axis='z',mat='cream',group=group,n=20)
    a.box((x+r*.13,y+r*.10,z-.021),(.008,r*.85,.006),'red',group)

def valve(a,p,axis='z',group='Valves',color='amber'):
    x,y,z=p
    a.cyl(p,.033,.048,axis=axis,mat='trim',group=group,n=16)
    if axis=='z':
        a.cyl((x,y,z-.039),.019,.025,'z','graphite',group,n=14)
        a.box((x,y,z-.059),(.105,.015,.017),color,group)
        for q in [-.044,.044]:a.cyl((x+q,y,z-.059),.012,.012,'z',color,group,n=10)
    else:
        a.cyl((x,y+.033,z),.021,.032,'y','graphite',group,n=14)
        a.box((x,y+.058,z),(.11,.015,.016),color,group)

DATA=[]
# A — GROWT TRAY / rack. +Y up / visible front points -Z.
a=Asset('grow_tray','Three-tier controlled-environment crop rack with hydroponic channels, warm-white LEDs, recirculating reservoir, valves and maintenance display',interactive=('Crop_Canopy','LED_Diffusers','Reservoir','Water_Pump','Valve_Controls','Control_Display'))
# structure: 1.35 wide x .73 deep x 2.12 high, reservoir under lower tray
for x in [-.646,.646]:
 for z in [-.326,.326]:
    frame_post(a,x,z,.062,2.065)
    a.cyl((x,.03,z),.037,.055,'y','rubber',n=14)
for y in [.11,2.02]:
 for z in [-.326,.326]:a.box((0,y,z),(1.30,.031,.035),'trim')
 for x in [-.646,.646]:a.box((x,y,0),(.035,.031,.652),'trim')
# closed extrusion rails on rear improve real functional silhouette
for y in [.37,.93,1.49]:
 for z in [-.30,.30]:a.box((0,y,z),(1.23,.034,.036),'alloy')
 for x in [-.63,.63]:a.box((x,y,0),(.029,.034,.60),'alloy')
 # hydroponic tray: dark channels + growing medium with visible individual green net pots
 a.chamfer_y((0,y+.045,0),1.26,.085,.646,.028,'graphite')
 a.chamfer_y((0,y+.095,0),1.18,.018,.561,.02,'substrate')
 # recess separators across crop rows
 for rz in [-.139,.139]:
    a.box((0,y+.108,rz),(1.13,.017,.01),'trim')
 # channel end caps + water supply fitting at right
 a.box((.614,y+.076,0),(.041,.12,.54),'carbon')
 a.cyl((.634,y+.07,.225),.032,.018,'x','alloy',n=16)
 for i in range(6):
  for j,z in enumerate([-.14,.14]):
   x=-.49+i*.195
   lettuce(a,(x,y+.109,z),scale=.95+(i+j)%3*.05)
 # suspended modular horticultural LED fixtures, tucked under next shelf
 led=y+.378
 for z in [-.163,.163]:
    a.chamfer_y((0,led,z),1.15,.030,.075,.016,'alloy',group='LED_Light_Housing')
    a.box((0,led-.021,z),(1.08,.009,.055),'glow',group='LED_Diffusers')
 for x in [-.50,.50]:a.tube((x,led+.045,-.163),(x,led+.018,-.163),.008,'trim')
# support beams for LED wiring
for x in [-.54,.54]:a.box((x,1.12,.325),(.026,1.75,.027),'graphite')
# side supply line and branching solenoid valves; hose on right behind viewing plane
feedx=.58
for yy in [.2,.47,1.02,1.58]:a.cyl((feedx,yy,.350),.026,.037,'y','graphite',n=14)
a.curve([(.57,.25,.35),(.59,.70,.35),(.59,1.34,.35),(.59,1.62,.35)],.011,'rubber',group='Water_Pipe',n=10)
for y in [.37,.93,1.49]:
 a.curve([(.59,y+.06,.36),(.59,y+.06,.26),(.53,y+.06,.24)],.009,'rubber',group='Water_Pipe')
 valve(a,(.58,y+.07,-.294),group='Valve_Controls',color='amber')
# drain line on left
x=-.58
a.curve([(x,1.50,.28),(x,.94,.28),(x,.38,.28),(x,.18,.18)],.014,'graphite',group='Return_Line')
# reservoir in bottom equipment bay
# shell, main front panel, liquid sight strip, lid seam; visible at waist
#a storage tank is a proper closed casing with mount brackets
for x in [-.48,.48]:a.box((x,.195,.12),(.06,.19,.365),'trim')
a.chamfer_y((0,.196,.13),1.03,.25,.46,.045,'tank',group='Reservoir')
a.box((0,.319,.13),(1.03,.027,.46),'graphite',group='Reservoir')
a.box((-.30,.200,-.114),(.075,.165,.008),'fluid',group='Reservoir')
a.box((-.30,.206,-.121),(.083,.184,.008),'clear',group='Reservoir')
a.box((0,.224,-.111),(.39,.10,.008),'carbon',group='Reservoir')
a.decal((0,.225,-.118),.335,.07,'label_GR-01',group='Reservoir')
# pump motor and external manifold
for px in [.37,.47]:
 a.cyl((px,.166,-.239),.055,.086,'x','graphite',group='Water_Pump',n=18)
a.cyl((.52,.166,-.239),.063,.030,'x','alloy',group='Water_Pump')
a.curve([(.52,.16,-.25),(.64,.18,-.22),(.66,.30,-.24)],.015,'rubber',group='Water_Pump')
# small controller mounted front right upright
a.chamfer_z((.507,1.81,-.352),.218,.25,.051,.021,'graphite',group='Control_Display')
a.chamfer_z((.507,1.834,-.386),.183,.144,.008,.012,'screen',group='Control_Display')
a.decal((.507,1.834,-.391),.169,.131,'rack_ui','front',group='Control_Display')
for ox in [.455,.512,.569]:a.cyl((ox,1.733,-.391),.012,.006,'z','mint' if ox==.455 else 'trim',group='Control_Display',n=12)
DATA.append(a.export())

# B — SEEDLING STATION — real transparent humidity cover, 3 plug trays, compact lower cabinet.
a=Asset('seedling_station','Benchtop propagation station with removable plug trays, young plants, semi-transparent humidity cover, vents, LED strip and compact service reservoir',interactive=('Humidity_Dome','Seed_Tray_A','Seed_Tray_B','Seed_Tray_C','LED_Diffusers','Seedling_Display','Lid_Latch'))
# Under-bench footprint ~1.27 x .67, 1.36m tall including illumination gantry
for x in [-.57,.57]:
 for z in [-.27,.27]:frame_post(a,x,z,.065,.82,w=.036)
a.chamfer_y((0,.82,0),1.28,.071,.68,.044,'alloy')
a.chamfer_y((0,.865,0),1.22,.021,.63,.037,'cream')
a.chamfer_y((0,.187,.075),.91,.24,.45,.04,'tank',group='Seedling_Reservoir')
a.box((0,.323,.08),(.91,.018,.45),'graphite',group='Seedling_Reservoir')
a.box((-.25,.19,-.156),(.06,.11,.008),'fluid',group='Seedling_Reservoir')
# lower drawer with pulls and vented filter
a.chamfer_z((0,.57,-.303),.99,.25,.037,.028,'graphite')
a.chamfer_z((0,.59,-.325),.93,.19,.014,.026,'shell')
a.box((0,.592,-.336),(.18,.020,.012),'alloy')
for i in range(9):a.box((-.31+i*.077,.513,-.338),(.035,.012,.008),'trim')
# three removable propagation inserts, separate trays and seedlings
for b,cx in enumerate([-.385,0,.385]):
 group=['Seed_Tray_A','Seed_Tray_B','Seed_Tray_C'][b]
 a.chamfer_y((cx,.911,-.02),.34,.067,.46,.025,'carbon',group)
 a.chamfer_y((cx,.955,-.02),.296,.017,.421,.018,'substrate',group)
 for u in range(3):
  for v in range(3):lettuce(a,(cx+(u-1)*.092,.965,-.02+(v-1)*.128),.72,group=group,seedling=True)
 # corner marks
 for x in [cx-.156,cx+.156]:a.box((x,.955,-.234),(.012,.022,.05),'lime',group)
# Transparent domed protective panels: only panels, not an opaque box
# front/back panels, side ends, clear top roof
for z in [-.255,.255]:a.box((0,1.08,z),(1.17,.290,.006),'clear',group='Humidity_Dome')
for x in [-.585,.585]:a.box((x,1.08,0),(.006,.290,.50),'clear',group='Humidity_Dome')
a.box((0,1.229,0),(1.17,.008,.514),'clear',group='Humidity_Dome')
for z in [-.255,.255]:
 for y in [.947,1.231]:a.box((0,y,z),(1.19,.016,.021),'trim',group='Humidity_Dome')
for x in [-.584,.584]:
 for z in [-.255,.255]:a.box((x,1.09,z),(.021,.302,.021),'trim',group='Humidity_Dome')
# dome opening hinge strip at back and latches at front
for x in [-.42,.42]:
 a.cyl((x,1.233,.263),.025,.08,'x','graphite',group='Humidity_Dome',n=14)
 a.box((x,1.084,-.274),(.062,.045,.035),'amber',group='Lid_Latch')
# LED shelf above dome carried by gantry
a.box((0,1.46,.27),(1.20,.055,.049),'alloy')
for x in [-.54,.54]:a.box((x,1.331,.269),(.035,.255,.048),'trim')
a.chamfer_y((0,1.48,0),1.18,.049,.42,.02,'alloy',group='LED_Housing')
for z in [-.12,.12]:a.box((0,1.450,z),(1.10,.009,.047),'glow',group='LED_Diffusers')
# bench front control pod / digital temp reading
a.chamfer_z((.46,.738,-.35),.24,.132,.041,.017,'graphite',group='Seedling_Display')
a.decal((.46,.746,-.373),.203,.094,'seedling_ui',group='Seedling_Display')
a.decal((-.38,.729,-.354),.24,.070,'label_GS-01')
DATA.append(a.export())

# C — NUTRIENT MIXER, thick central working surface and twin chemical dosing tanks.
a=Asset('nutrient_mixer','Precision nutrient-dosing station with twin concentrate tanks, recirculation manifold, analog gauges, manual shutoff valves and dosing telemetry',interactive=('Tank_A','Tank_B','Pump_Assembly','Dosing_Valves','Flow_Gauges','Mixer_Display','Hose_Connections'))
# cabinet + sloped face, inset trim, vent and service access
for x in [-.52,.52]:
 for z in [-.252,.252]:
  frame_post(a,x,z,.068,1.55,w=.038)
  a.cyl((x,.033,z),.032,.05,'y','rubber',n=12)
a.chamfer_y((0,.44,.05),1.10,.71,.51,.068,'shell')
a.chamfer_z((0,.44,-.214),.99,.51,.026,.047,'graphite')
a.chamfer_z((0,.45,-.236),.91,.42,.015,.04,'cream')
a.box((0,.258,-.25),(.75,.035,.012),'alloy')
for i in range(10):a.box((-.35+i*.078,.43,-.248),(.027,.117,.010),'trim')
a.chamfer_y((0,.813,.06),1.15,.068,.58,.045,'graphite')
a.chamfer_y((0,.856,.06),1.10,.021,.54,.043,'alloy')
# fluid concentrate tanks, twin transparent cylinders standing above worktop
for suffix,x,mat in [('A',-.26,'fluid'),('B',.26,'lime')]:
    g=f'Tank_{suffix}'
    a.cyl((x,1.143,.06),.183,.56,'y','tank',g,n=28) # industrial opaque body
    a.cyl((x,1.15,-.124),.048,.405,'y','fluid',g,n=14) # visible gauge stripe
    a.box((x,1.15,-.176),(.076,.44,.012),'clear',g)
    for y in [1.006,1.120,1.234]:a.box((x,y,-.185),(.079,.007,.014),'alloy',g)
    a.cyl((x,1.424,.06),.196,.052,'y','graphite',g,n=28)
    a.cyl((x,1.463,.06),.062,.032,'y','alloy',g,n=16)
    a.cyl((x,1.501,.06),.040,.068,'y','carbon',g,n=16)
    a.box((x,1.055,-.132),(.26,.026,.012),mat,g)
# upper instrument bridge
for x in [-.51,.51]:frame_post(a,x,.25,1.17,1.88,w=.032)
a.chamfer_z((0,1.73,.26),1.08,.31,.095,.04,'alloy')
a.chamfer_z((0,1.73,.204),1.01,.255,.016,.032,'graphite')
a.chamfer_z((.22,1.725,.178),.46,.20,.013,.025,'screen',group='Mixer_Display')
a.decal((.22,1.726,.168),.426,.18,'mixer_ui',group='Mixer_Display')
for i,x in enumerate([-.43,-.31,-.19]):gauge(a,(x,1.72,.163),.047,group='Flow_Gauges')
# lower pump motor + pressure bypass tubing
for x in [-.35,.35]:
 a.cyl((x,.682,-.33),.087,.136,'x','graphite',group='Pump_Assembly',n=24)
 a.cyl((x+.075,.682,-.33),.044,.043,'x','alloy',group='Pump_Assembly',n=20)
 a.box((x,.618,-.311),(.12,.07,.15),'trim',group='Pump_Assembly')
# visible pipes and valves under tank fronts, flexible feed lines from outlets
for i,x in enumerate([-.26,.26]):
 a.curve([(x,1.00,-.16),(x,.88,-.34),(x,.80,-.35),(x,.74,-.35)],.013,'rubber',group='Hose_Connections')
 valve(a,(x,.862,-.345),group='Dosing_Valves',color='amber' if i==0 else 'mint')
# cross manifold and drain port
a.curve([(-.42,.586,-.315),(-.16,.586,-.315),(.16,.586,-.315),(.42,.586,-.315)],.020,'alloy',group='Hose_Connections')
for x in [-.35,.35]:a.cyl((x,.585,-.345),.023,.04,'z','carbon',group='Hose_Connections',n=14)
a.decal((0,.31,-.257),.42,.13,'label_GM-01')
DATA.append(a.export())

# D — Harvest cart, restrained trolley, two vented harvest containers, leafy produce.
a=Asset('harvest_cart','Lightweight wheeled harvest trolley with two removable ventilated produce totes, lockable castors and sanitation equipment',interactive=('Harvest_Bin_Top','Harvest_Bin_Lower','Caster_Wheels','Cart_Handle','Produce'))
# thin-tube trolley frame and generous clear visual silhouettes
for x in [-.46,.46]:
 for z in [-.23,.23]:frame_post(a,x,z,.16,1.03,'alloy',w=.037)
for y in [.31,.79]:
 for z in [-.25,.25]:a.box((0,y,z),(1.06,.042,.036),'trim')
 for x in [-.46,.46]:a.box((x,y,0),(.033,.040,.50),'trim')
# foot base side flanges, rail, push-handle with grips
for x in [-.45,.45]:
 a.tube((x,.94,.20),(x,1.12,.38),.023,'alloy',group='Cart_Handle',n=14)
 a.tube((x,1.12,.38),(-x if x>0 else x,1.12,.38),.022,'alloy',group='Cart_Handle',n=14) if x>0 else None
a.tube((-.46,1.12,.38),(.46,1.12,.38),.025,'rubber',group='Cart_Handle',n=16)
# two physical wheeled trays with open face and ventilation slots (keep removable bins groups)
for name,y in [('Harvest_Bin_Top',.815),('Harvest_Bin_Lower',.345)]:
 a.chamfer_y((0,y+.015,0),.97,.11,.51,.045,'graphite',name)
 a.box((0,y-.006,0),(.88,.016,.42),'carbon',name)
 for z in [-.245,.245]:a.box((0,y+.105,z),(.92,.16,.026),'cream',name)
 for x in [-.475,.475]:a.box((x,y+.105,0),(.026,.16,.49),'cream',name)
 for x in [-.31,-.155,0,.155,.31]:
  for z in [-.258,.258]:a.box((x,y+.115,z),(.085,.023,.008),'carbon',name)
 a.box((0,y+.118,-.266),(.22,.039,.012),'trim',name)
 # produce carefully localized to containers, not empty placeholder boxes
 for x,z,sc in [(-.30,-.12,1.20),(-.1,.12,1.15),(.22,-.10,1.10),(.36,.13,1.0)]:
  lettuce(a,(x,y+.02,z),sc,'Produce')
# caster wheels and orange foot brake tabs
for i,x in enumerate([-.45,.45]):
 for z in [-.25,.25]:
  a.cyl((x,.087,z),.075,.04,'x','rubber',group='Caster_Wheels',n=20)
  a.cyl((x,.087,z),.039,.047,'x','alloy',group='Caster_Wheels',n=18)
  a.cyl((x,.087,z),.017,.059,'x','graphite',group='Caster_Wheels',n=12)
  if z<0:a.box((x,.17,z-.01),(.12,.020,.11),'amber',group='Caster_Wheels')
# side cart hygiene bottle + emergency gloves pocket (non-detachable cosmetic)
a.box((.495,.62,.02),(.048,.28,.19),'graphite')
a.cyl((.515,.67,.02),.061,.18,'y','tank',n=18)
a.cyl((.515,.765,.02),.025,.028,'y','alloy',n=14)
a.decal((0,.433,-.280),.30,.085,'label_HC-01')
DATA.append(a.export())

# E — Hydroponic telemetry / sensor panel: WALL MOUNT: origin centred on mounting plate.
a=Asset('hydroponics_sensor_panel','Wall-mounted hydroponic telemetry unit with legible enviro display, protected selector buttons, alarms and probe connectors',placement='wall_mount_z0_faces_negative_z',interactive=('Screen_UI','Alarm_Lights','Selector_Buttons','Sensor_Connectors'))
a.chamfer_z((0,0,-.055),.86,.73,.105,.065,'alloy')
a.chamfer_z((0,0,-.113),.78,.655,.028,.056,'graphite')
a.chamfer_z((0,.045,-.143),.735,.495,.018,.033,'carbon',group='Screen_UI')
a.chamfer_z((0,.05,-.154),.699,.452,.007,.023,'screen',group='Screen_UI')
a.decal((0,.05,-.161),.675,.432,'sensor_ui','front',group='Screen_UI')
# shaped orange service flange / connector base
for x in [-.38,.38]:a.box((x,0,-.138),(.027,.51,.021),'amber')
a.box((0,-.310,-.12),(.73,.043,.04),'trim')
for i,x in enumerate([-.31,-.235,-.16,-.085]):
 a.cyl((x,-.312,-.172),.019,.011,'z','mint' if i==0 else ('amber' if i==1 else 'trim'),group='Alarm_Lights',n=14)
for i,x in enumerate([.12,.21,.30]):
 a.cyl((x,-.313,-.166),.026,.019,'z','graphite',group='Selector_Buttons',n=18)
 a.cyl((x,-.313,-.179),.015,.012,'z','amber' if i==1 else 'alloy',group='Selector_Buttons',n=14)
# service cable glands under cabinet + sockets without literal infrastructure geometry
for x in [-.28,-.12,.12,.28]:
 a.cyl((x,-.388,-.045),.033,.039,'y','graphite',group='Sensor_Connectors',n=16)
 a.cyl((x,-.416,-.045),.020,.020,'y','alloy',group='Sensor_Connectors',n=12)
# side handles and vent slots
for sx in [-1,1]:
 for j in range(6):a.box((sx*.436,-.08+j*.053,-.067),(.011,.015,.052),'carbon')
a.decal((-.22,.300,-.139),.22,.065,'label_ENV-01')
DATA.append(a.export())

MANIFEST={
 'project':'Mars Habitat — Hydroponics — Phase 2 (equipment only)',
 'version':'1.0.0-review',
 'room':'hydroponics',
 'asset_count':len(DATA),
 'assets':DATA,
 'in_scope':['grow_tray','seedling_station','nutrient_mixer','harvest_cart','hydroponics_sensor_panel'],
 'out_of_scope':['interior structural parts','windows','doors','grid snapping','greenhouse assets','gameplay systems replacement'],
 'source_of_truth':'data/equipment_catalog.json in original Godot project; do not invent power, water or food values',
 'validation':'GLB re-export/reload validation only; in-engine placement, collision, visual appearance and simulation hooks not yet verified'
}
with open(os.path.join(ROOT,'asset_manifest.json'),'w') as f:json.dump(MANIFEST,f,indent=2)
print('DONE',len(DATA),'assets',sum(m['triangles'] for m in DATA),'triangles')
