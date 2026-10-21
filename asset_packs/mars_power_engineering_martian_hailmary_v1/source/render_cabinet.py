"""Render the exported GLBs in VTK (not concept art)."""
import os, sys, math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import trimesh
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'previews');os.makedirs(OUT,exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT2='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

def mat_rgba(m):
 base=getattr(m,'baseColorFactor',None)
 if base is None:
  return (190,190,190,255)
 return tuple(int(v) for v in base)

def to_poly(mesh):
 poly=vtk.vtkPolyData();p=vtk.vtkPoints()
 p.SetData(numpy_to_vtk(np.asarray(mesh.vertices,dtype=np.float64),deep=True))
 poly.SetPoints(p)
 f=np.hstack((np.full((len(mesh.faces),1),3,dtype=np.int64),np.asarray(mesh.faces,dtype=np.int64))).ravel()
 vtk_cells=vtk.vtkCellArray(); vtk_cells.SetCells(len(mesh.faces),numpy_to_vtkIdTypeArray(f,deep=True));poly.SetPolys(vtk_cells)
 normals=vtk.vtkPolyDataNormals();normals.SetInputData(poly);normals.ConsistencyOn();normals.AutoOrientNormalsOff();normals.SplittingOff();normals.Update();poly=normals.GetOutput()
 uv=getattr(mesh.visual,'uv',None)
 if uv is not None and len(uv)==len(mesh.vertices):
  arr=numpy_to_vtk(np.asarray(uv,dtype=np.float32),deep=True);arr.SetNumberOfComponents(2);arr.SetName('TextureCoordinates');poly.GetPointData().SetTCoords(arr)
 return poly

def render(glb,out,width=960,height=800,view='main'):
 s=trimesh.load(glb,force='scene')
 ren=vtk.vtkRenderer();ren.SetBackground(.095,.13,.14)
 ren.SetBackground2(.22,.26,.25);ren.GradientBackgroundOn()
 win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.AddRenderer(ren);win.SetSize(width,height)
 win.SetMultiSamples(4)
 ren.SetUseDepthPeeling(True)
 ren.SetMaximumNumberOfPeels(20)
 ren.SetOcclusionRatio(0.1)
 win.SetAlphaBitPlanes(1)
 ambient = vtk.vtkLight();ambient.SetLightTypeToSceneLight();ambient.SetPosition(-3,6,-7);ambient.SetFocalPoint(0,1,0);ambient.SetIntensity(.9);ren.AddLight(ambient)
 fill=vtk.vtkLight();fill.SetLightTypeToSceneLight();fill.SetPosition(4,3,4);fill.SetFocalPoint(0,1,0);fill.SetIntensity(.7);ren.AddLight(fill)
 for node in s.graph.nodes_geometry:
  pose,name = s.graph[node]
  g = s.geometry[name].copy()
  g.apply_transform(pose)
  actor=vtk.vtkActor(); mapper=vtk.vtkPolyDataMapper(); mapper.SetInputData(to_poly(g));actor.SetMapper(mapper)
  mat=getattr(g.visual,'material',None)
  r,gc,b,a=mat_rgba(mat)
  prop=actor.GetProperty();prop.SetColor(r/255,gc/255,b/255);prop.SetOpacity(a/255 if a<250 else 1.0);prop.SetDiffuse(.8);prop.SetSpecular(.23 if getattr(mat,'metallicFactor',0)>.5 else .12);prop.SetSpecularPower(18);prop.SetAmbient(.16)
  tex=getattr(mat,'baseColorTexture',None)
  if tex is not None:
   img=tex.convert('RGBA')
   ia=np.asarray(img)
   from vtk.util.numpy_support import numpy_to_vtk
   imgdata=vtk.vtkImageData();imgdata.SetDimensions(img.width,img.height,1)
   vta=numpy_to_vtk(np.ascontiguousarray(np.flipud(ia)).reshape(-1,4),deep=True,array_type=vtk.VTK_UNSIGNED_CHAR);vta.SetNumberOfComponents(4);imgdata.GetPointData().SetScalars(vta)
   texture=vtk.vtkTexture();texture.SetInputData(imgdata);texture.InterpolateOn();actor.SetTexture(texture);prop.SetColor(1,1,1)
  ren.AddActor(actor)
 bounds=s.bounds;center=bounds.mean(axis=0)
 xmin,ymin,zmin=bounds[0]; xmax,ymax,zmax=bounds[1]
 # pale base plinth ensures groundedness even for wall-light preview (mounted on wall)
 if 'task_light' in os.path.basename(glb):
  wall=vtk.vtkCubeSource();wall.SetCenter(0,1.32,.138);wall.SetXLength(2.0);wall.SetYLength(2.05);wall.SetZLength(.05)
  m=vtk.vtkPolyDataMapper();m.SetInputConnection(wall.GetOutputPort());a=vtk.vtkActor();a.SetMapper(m);a.GetProperty().SetColor(.31,.34,.32);ren.AddActor(a)
 else:
  ground=vtk.vtkCubeSource();ground.SetCenter(0,-.04,0);ground.SetXLength(4.6);ground.SetYLength(.08);ground.SetZLength(3.6)
  m=vtk.vtkPolyDataMapper();m.SetInputConnection(ground.GetOutputPort());a=vtk.vtkActor();a.SetMapper(m);a.GetProperty().SetColor(.22,.245,.245);ren.AddActor(a)
 cam=ren.GetActiveCamera();look=[center[0],center[1],center[2]]
 span=max(bounds[1]-bounds[0])
 if view=='main':eye=[center[0]+2.1*span,center[1]+1.35*span,center[2]-2.5*span]
 elif view=='right':eye=[center[0]-2.0*span,center[1]+1.15*span,center[2]-2.5*span]
 elif view=='front':eye=[center[0]+.3*span,center[1]+.9*span,center[2]-2.75*span]
 else:eye=[center[0]+1.7*span,center[1]+2.35*span,center[2]-1.7*span]
 cam.SetPosition(*eye);cam.SetFocalPoint(*look);cam.SetViewUp(0,1,0);cam.SetViewAngle(30)
 ren.ResetCameraClippingRange();win.Render()
 w=vtk.vtkWindowToImageFilter();w.SetInput(win);w.SetInputBufferTypeToRGB();w.ReadFrontBufferOff();w.Update()
 writer=vtk.vtkPNGWriter();writer.SetFileName(out);writer.SetInputConnection(w.GetOutputPort());writer.Write()
 win.Finalize()
 print('Rendered',out, os.path.getsize(out),flush=True)


if __name__ == '__main__':
    for name,prefix in [('power_distribution_cabinet_martian_hailmary.glb','cabinet'),('battery_bank_martian_hailmary.glb','battery')]:
        model=os.path.join(ROOT,'models',name)
        for view in ('main','front','right'):
            render(model,os.path.join(ROOT,'previews',prefix+'_'+view+'.png'),width=920,height=780,view=view)
