"""Offline preview rendering, uses VTK (not part of game)."""
import os, json, math
import numpy as np, trimesh
from PIL import Image,ImageDraw,ImageFont
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray
R=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
PRE=os.path.join(R,'previews');os.makedirs(PRE,exist_ok=True)
DATA=json.load(open(os.path.join(R,'asset_manifest.json')))['assets']
CAM={
'grow_tray':((1.75,.9,-2.8),(.5,.45,-2.7)),
'seedling_station':((1.7,1.0,-2.8),(.45,.7,-2.5)),
'nutrient_mixer':((1.5,.7,-2.8),(-.3,.3,-2.9)),
'harvest_cart':((1.75,1.15,-2.8),(-.3,.6,-2.5)),
'hydroponics_sensor_panel':((.9,.3,-3.5),(.0,.0,-3.5)),
}

def render_asset(md,variant='hero',size=(820,820)):
    scene=trimesh.load(os.path.join(R,'models',md['id']+'.glb'),force='scene')
    ren=vtk.vtkRenderer()
    ren.SetBackground(.09,.12,.14)
    ren.SetBackground2(.23,.27,.28)
    ren.GradientBackgroundOn()
    # light sources
    ren.AutomaticLightCreationOff()
    for pos,intensity,col in [([2.7,5.5,-4.3],.90,[1,.94,.83]),([-3.0,3.2,2.5],.62,[.76,.91,1]),([1,2,3],.30,[1,1,1])]:
        l=vtk.vtkLight();l.SetPosition(*pos);l.SetFocalPoint(0,.7,0);l.SetLightTypeToSceneLight();l.SetIntensity(intensity);l.SetColor(*col);ren.AddLight(l)
    mn=np.array([1000.,1000.,1000.]);mx=-mn.copy()
    for node in scene.graph.nodes_geometry:
        tf,gn=scene.graph[node];mesh=scene.geometry[gn].copy();mesh.apply_transform(tf)
        if len(mesh.vertices)==0:continue
        mn=np.minimum(mn,mesh.vertices.min(axis=0));mx=np.maximum(mx,mesh.vertices.max(axis=0))
        arr=np.ascontiguousarray(mesh.vertices.astype(np.float32))
        f=np.ascontiguousarray(np.column_stack((np.full(len(mesh.faces),3,dtype=np.int64),mesh.faces)).reshape(-1))
        points=vtk.vtkPoints();points.SetData(numpy_to_vtk(arr,deep=True))
        cells=vtk.vtkCellArray();cells.SetCells(len(mesh.faces),numpy_to_vtkIdTypeArray(f,deep=True))
        pd=vtk.vtkPolyData();pd.SetPoints(points);pd.SetPolys(cells)
        if hasattr(mesh.visual,'uv') and mesh.visual.uv is not None:
            tc=numpy_to_vtk(np.ascontiguousarray(mesh.visual.uv.astype('float32')),deep=True)
            tc.SetNumberOfComponents(2);tc.SetName('TCoords');pd.GetPointData().SetTCoords(tc)
        normals=vtk.vtkPolyDataNormals();normals.SetInputData(pd);normals.ComputePointNormalsOn();normals.SplittingOn();normals.SetFeatureAngle(45);normals.Update()
        mapper=vtk.vtkPolyDataMapper();mapper.SetInputConnection(normals.GetOutputPort());mapper.ScalarVisibilityOff()
        act=vtk.vtkActor();act.SetMapper(mapper)
        mat=mesh.visual.material
        rgba=np.array(mat.baseColorFactor if mat.baseColorFactor is not None else [255]*4)/255
        act.GetProperty().SetColor(*rgba[:3]);act.GetProperty().SetInterpolationToPhong()
        if mat.alphaMode=='BLEND':
            act.GetProperty().SetOpacity(rgba[3])
            act.GetProperty().SetAmbient(.45)
        act.GetProperty().SetAmbient(.28);act.GetProperty().SetDiffuse(.72)
        act.GetProperty().SetSpecular(.30 if mat.metallicFactor and mat.metallicFactor>.5 else .13)
        act.GetProperty().SetSpecularPower(36 if mat.roughnessFactor and mat.roughnessFactor<.5 else 15)
        if mat.baseColorTexture is not None:
            # use image embedded in GLB; enable wrap for seamless procedural textures
            im=np.array(mat.baseColorTexture.convert('RGB'))
            im=np.flipud(im)
            vid=vtk.vtkImageData();vid.SetDimensions(im.shape[1],im.shape[0],1)
            pix=numpy_to_vtk(np.ascontiguousarray(im.reshape(-1,3)),deep=True,array_type=vtk.VTK_UNSIGNED_CHAR)
            pix.SetNumberOfComponents(3);vid.GetPointData().SetScalars(pix)
            tex=vtk.vtkTexture();tex.SetInputData(vid);tex.RepeatOn();tex.InterpolateOn()
            act.SetTexture(tex)
        ren.AddActor(act)
    # show simple stage unless wall-mounted
    if md['placement']=='floor':
        stage=vtk.vtkCubeSource(); stage.SetXLength(3.0);stage.SetYLength(.045);stage.SetZLength(2.35);stage.SetCenter(0,-.067,0)
        mp=vtk.vtkPolyDataMapper();mp.SetInputConnection(stage.GetOutputPort());act=vtk.vtkActor();act.SetMapper(mp)
        act.GetProperty().SetColor(.22,.26,.28);act.GetProperty().SetSpecular(.05)
        ren.AddActor(act)
    win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.SetSize(*size);win.AddRenderer(ren);win.SetMultiSamples(0)
    cam=ren.GetActiveCamera()
    center=(mn+mx)/2
    vec=np.array(CAM[md['id']][0 if variant=='hero' else 1])
    if md['id']=='hydroponics_sensor_panel':center=np.array([0,0,-.32])
    extent=mx-mn
    cam.ParallelProjectionOn();cam.SetFocalPoint(*center);cam.SetPosition(*(center+vec*max(1.5,extent.max())))
    cam.SetViewUp(0,1,0)
    scale=.58*max(extent[1],extent[0]*1.15,extent[2]*1.45,.85)
    if md['id']=='hydroponics_sensor_panel':scale=.59
    if md['id']=='harvest_cart':scale=.82
    if md['id']=='seedling_station':scale=.88
    cam.SetParallelScale(scale)
    ren.ResetCameraClippingRange()
    win.Render()
    writer=vtk.vtkPNGWriter();w2i=vtk.vtkWindowToImageFilter();w2i.SetInput(win);w2i.ReadFrontBufferOff();w2i.Update()
    fname=f"{md['id']}_{variant}.png";writer.SetFileName(os.path.join(PRE,fname));writer.SetInputConnection(w2i.GetOutputPort());writer.Write()
    win.Finalize()


for md in DATA:
    for variant in ('hero','detail'):
        print('RENDER',md['id'],variant,flush=True)
        render_asset(md,variant)

font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
F=ImageFont.truetype(font_path,21)
FB=ImageFont.truetype(font_path.replace('.ttf','-Bold.ttf'),31)
LONG={'grow_tray':'GROW TRAY / CROP RACK','seedling_station':'SEEDLING STATION','nutrient_mixer':'NUTRIENT MIXER','harvest_cart':'HARVEST CART','hydroponics_sensor_panel':'HYDROPONICS SENSOR PANEL'}
cardw=525;cardh=620
sheet=Image.new('RGB',(cardw*3,cardh*2+160),(234,238,235));d=ImageDraw.Draw(sheet)
d.text((37,24),'MARS HABITAT  /  HYDROPONICS  /  PHASE 02',font=FB,fill=(30,57,63))
d.text((38,73),'Game-ready model candidates  |  separate parts + embedded PBR textures  |  1 unit = 1 metre',font=F,fill=(82,104,103))
for i,md in enumerate(DATA):
    x=i%3*cardw;y=i//3*cardh+114
    im=Image.open(os.path.join(PRE,md['id']+'_hero.png')).convert('RGB').resize((cardw-24,cardw-24))
    sheet.paste(im,(x+12,y+4))
    d.text((x+21,y+cardw-5),LONG[md['id']],font=(ImageFont.truetype(font_path.replace('.ttf','-Bold.ttf'),24) if len(LONG[md['id']])>20 else FB),fill=(33,58,64))
    d.text((x+22,y+cardw+37),f"{md['triangles']:,} triangles  /  {md['mesh_nodes']} mesh groups",font=F,fill=(89,106,106))
x=cardw*2;y=cardh+114
box=(x+13,y+8,x+cardw-15,y+cardh-14)
d.rounded_rectangle(box,18,fill=(214,225,220))
d.text((x+36,y+56),'PHASE 02',font=FB,fill=(35,61,68))
for j,line in enumerate(['Five hydroponic asset types','Structural kit stays separate','Crop foliage uses shaped leaf meshes','Screens show example readings','Gameplay effects are not altered','Awaiting real Godot review']):
    d.text((x+37,y+135+j*56),'- '+line,font=F,fill=(57,81,86))
sheet.save(os.path.join(PRE,'hydroponics_phase2_contact_sheet.png'))
print('PREVIEWS COMPLETE')
