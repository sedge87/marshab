from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import trimesh,numpy as np,vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray
from build_heaters import COLORS
ROOT=Path(__file__).resolve().parents[1]
PREV=ROOT/'previews';PREV.mkdir(exist_ok=True)

def actor(mesh):
    verts=np.asarray(mesh.vertices,dtype=np.float64);faces=np.asarray(mesh.faces,dtype=np.int64)
    pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(verts,deep=True));cells=np.hstack([np.full((len(faces),1),3,dtype=np.int64),faces]).ravel()
    cs=vtk.vtkCellArray();cs.SetCells(len(faces),numpy_to_vtkIdTypeArray(cells,deep=True))
    pd=vtk.vtkPolyData();pd.SetPoints(pts);pd.SetPolys(cs)
    n=vtk.vtkPolyDataNormals();n.SetInputData(pd);n.SplittingOff();n.ConsistencyOn();n.ComputePointNormalsOn();n.Update()
    mapper=vtk.vtkPolyDataMapper();mapper.SetInputConnection(n.GetOutputPort());act=vtk.vtkActor();act.SetMapper(mapper)
    name=getattr(mesh.visual.material,'name','warm_panel');col,met,rough=COLORS.get(name,COLORS['warm_panel'])
    prop=act.GetProperty();prop.SetColor(*col[:3]);prop.SetAmbient(.40);prop.SetDiffuse(.72);prop.SetSpecular(.18+met*.32);prop.SetSpecularPower(20+met*45)
    if name in ('amber_glow','light_diffuser','bright_green'):prop.SetAmbient(.70)
    return act

def preview(id,slug,camera=(2.6,2.0,-3.1)):
    sc=trimesh.load(ROOT/'models'/f'{id}.glb',force='scene')
    items=sc.dump();vs=np.vstack([m.vertices for m in items]);mn=vs.min(0);mx=vs.max(0);ctr=(mn+mx)/2
    span=max((mx-mn).tolist());ren=vtk.vtkRenderer()
    ren.SetBackground(.78,.83,.85);ren.SetBackground2(.96,.98,.98);ren.GradientBackgroundOn()
    for m in items:ren.AddActor(actor(m))
    if id=='portable_utility_heater':
        plane=vtk.vtkPlaneSource();plane.SetOrigin(-3,-.014,-3);plane.SetPoint1(3,-.014,-3);plane.SetPoint2(-3,-.014,3)
        m=vtk.vtkPolyDataMapper();m.SetInputConnection(plane.GetOutputPort());aa=vtk.vtkActor();aa.SetMapper(m);aa.GetProperty().SetColor(.83,.86,.87);ren.AddActor(aa)
    for xyz,inten in [((4,6,-6),1.15),((-4,5,5),.48)]:
        light=vtk.vtkLight();light.SetPosition(*xyz);light.SetFocalPoint(*ctr);light.SetIntensity(inten);ren.AddLight(light)
    cam=ren.GetActiveCamera();cam.SetPosition(*(ctr+np.array(camera)));cam.SetFocalPoint(*ctr);cam.SetViewUp(0,1,0);cam.ParallelProjectionOn();cam.SetParallelScale((span*1.40)/2)
    ren.ResetCameraClippingRange()
    win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.AddRenderer(ren);win.SetSize(900,850);win.SetMultiSamples(4);win.Render()
    im=vtk.vtkWindowToImageFilter();im.SetInput(win);im.SetInputBufferTypeToRGB();im.ReadFrontBufferOff();im.Update()
    fn=PREV/f'{id}_{slug}.png';w=vtk.vtkPNGWriter();w.SetFileName(str(fn));w.SetInputConnection(im.GetOutputPort());w.Write();win.Finalize()
    print('rendered',fn,flush=True)

for id in ('wall_cabin_heater','portable_utility_heater'):
    preview(id,'three_quarter',(2.1,1.5,-3.2))
    preview(id,'front',(.1,.3,-3.4))
    preview(id,'side',(3.5,1.5,-2.0))

W,H=1520,1830;canvas=Image.new('RGB',(W,H),'#eff3f2');draw=ImageDraw.Draw(canvas)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
ft=ImageFont.truetype(font,31);ft2=ImageFont.truetype(font,19);title=ImageFont.truetype(font,48)
draw.text((45,24),'INDOOR HEATING EQUIPMENT',fill='#273d45',font=title)
draw.text((48,85),'MARS HABITAT  /  GENERAL EQUIPMENT  /  2 MODELS',fill='#60747b',font=ft2)
for idx,(id,name,caption) in enumerate([('wall_cabin_heater','01  WALL-MOUNTED CABIN HEATER','Wall anchored  |  OFF / LOW / HIGH'),('portable_utility_heater','02  PORTABLE UTILITY HEATER','Free placement  |  OFF / LOW / HIGH')]):
    y=144+idx*817
    draw.rounded_rectangle((24,y,1496,y+790),radius=18,fill='#ffffff',outline='#d0dada',width=2)
    draw.text((48,y+16),name,font=ft,fill='#31474e');draw.text((49,y+66),caption,font=ft2,fill='#617c80')
    for j,suf in enumerate(('three_quarter','front','side')):
        pic=Image.open(PREV/f'{id}_{suf}.png').convert('RGB');pic.thumbnail((470,638))
        canvas.paste(pic,(44+j*490,y+117))
canvas.save(PREV/'indoor_heaters_contact_sheet.jpg',quality=94)
print('saved contact sheet')
