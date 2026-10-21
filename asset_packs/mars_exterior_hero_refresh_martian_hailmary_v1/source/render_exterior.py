from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import trimesh,numpy as np,vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray
from geometry_core import COLORS
ROOT=Path(__file__).resolve().parents[1];PREV=ROOT/'previews';PREV.mkdir(exist_ok=True)
NAMES=[('exterior_ice_water_drill','ICE / WATER DRILL'),('exterior_surface_reactor','SURFACE REACTOR'),('exterior_portable_floodlight','PORTABLE FLOODLIGHT'),('exterior_tall_light_post','TALL LIGHT POST'),('exterior_solar_floodlight','SOLAR FLOODLIGHT')]

def actor(mesh):
    verts=np.asarray(mesh.vertices,dtype=np.float64);faces=np.asarray(mesh.faces,dtype=np.int64)
    pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(verts,deep=True));c=np.hstack([np.full((len(faces),1),3,dtype=np.int64),faces]).ravel()
    cs=vtk.vtkCellArray();cs.SetCells(len(faces),numpy_to_vtkIdTypeArray(c,deep=True))
    pd=vtk.vtkPolyData();pd.SetPoints(pts);pd.SetPolys(cs)
    n=vtk.vtkPolyDataNormals();n.SetInputData(pd);n.SplittingOff();n.ConsistencyOn();n.ComputePointNormalsOn();n.Update()
    mapper=vtk.vtkPolyDataMapper();mapper.SetInputConnection(n.GetOutputPort());act=vtk.vtkActor();act.SetMapper(mapper)
    name=getattr(mesh.visual.material,'name','warm_panel');col,met,rough=COLORS.get(name,COLORS['warm_panel']);pr=act.GetProperty();pr.SetColor(*col[:3]);pr.SetAmbient(.39);pr.SetDiffuse(.76);pr.SetSpecular(.22+met*.38);pr.SetSpecularPower(20+met*40)
    if name=='glass':pr.SetOpacity(.50)
    if name in ('amber_glow','light_diffuser','bright_green'):pr.SetAmbient(.76)
    return act

def preview(id,camera=(3.0,2.2,-3.7),detail=False):
    sc=trimesh.load(ROOT/'models'/f'{id}.glb',force='scene');items=sc.dump();vs=np.vstack([m.vertices for m in items]);mn=vs.min(0);mx=vs.max(0);ctr=(mn+mx)/2;span=max(mx[0]-mn[0],mx[1]-mn[1],mx[2]-mn[2]);size=(1080,990) if not detail else (950,950)
    ren=vtk.vtkRenderer();ren.SetBackground(.80,.86,.87);ren.SetBackground2(.96,.97,.98);ren.GradientBackgroundOn()
    for geo in items:ren.AddActor(actor(geo))
    ground=vtk.vtkPlaneSource();ground.SetOrigin(-5,-.024,-5);ground.SetPoint1(5,-.024,-5);ground.SetPoint2(-5,-.024,5)
    map=vtk.vtkPolyDataMapper();map.SetInputConnection(ground.GetOutputPort());ac=vtk.vtkActor();ac.SetMapper(map);ac.GetProperty().SetColor(.82,.85,.86);ren.AddActor(ac)
    light=vtk.vtkLight();light.SetPosition(4,8,-6);light.SetFocalPoint(*ctr);light.SetIntensity(1.2);ren.AddLight(light)
    light2=vtk.vtkLight();light2.SetPosition(-5,3,5);light2.SetFocalPoint(*ctr);light2.SetIntensity(.48);ren.AddLight(light2)
    cam=ren.GetActiveCamera();cam.SetPosition(*(ctr+np.array(camera)));cam.SetFocalPoint(*ctr);cam.SetViewUp(0,1,0);cam.ParallelProjectionOn();cam.SetParallelScale((span*1.50)/2);ren.ResetCameraClippingRange()
    win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.AddRenderer(ren);win.SetSize(*size);win.SetMultiSamples(4);win.Render()
    im=vtk.vtkWindowToImageFilter();im.SetInput(win);im.SetInputBufferTypeToRGB();im.ReadFrontBufferOff();im.Update()
    path=PREV/(id+('_front' if detail else '')+'.png');wr=vtk.vtkPNGWriter();wr.SetFileName(str(path));wr.SetInputConnection(im.GetOutputPort());wr.Write();win.Finalize();print('rendered',path.name,flush=True)

for id,name in NAMES:
 preview(id,camera=(3.4,2.7,-4.5))
 preview(id,camera=(-3.9,2.5,-3.5),detail=True)
from PIL import Image,ImageDraw,ImageFont
canvas=Image.new('RGB',(1820,2230),'#F2F5F6')
d=ImageDraw.Draw(canvas);font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
ft=ImageFont.truetype(font,22);fh=ImageFont.truetype(font,35)
d.text((40,22),'SURFACE OPERATIONS — REBUILT EXTERIOR EQUIPMENT',font=fh,fill='#293F49')
for idx,(id,name) in enumerate(NAMES):
 x=24+(idx%3)*602;y=90+(idx//3)*1040
 d.text((x+20,y),name,font=ft,fill='#293F49')
 for j,ext in enumerate(['.png','_front.png']):
  img=Image.open(PREV/(id+ext)).convert('RGB');img.thumbnail((582,474))
  canvas.paste(img,(x+2,y+40+j*482))
canvas.save(PREV/'exterior_hero_contact_sheet.jpg',quality=92)
print('contact sheet saved')
