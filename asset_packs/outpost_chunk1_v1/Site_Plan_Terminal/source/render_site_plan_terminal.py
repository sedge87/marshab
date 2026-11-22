"""Render the packaged terminal and an optional sample image on its live screen."""
import bpy
from mathutils import Vector
from pathlib import Path
import os

package=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
part=os.environ.get('OUTPOST_TERMINAL_VIEW','module')
views={
    'module': ((.92,-1.88,1.50),(0,-.025,.540),1.250,1200,1320,'terminal_3q.jpg',True),
    'desk': ((.42,-1.12,1.62),(0,-.089,.933),.746,1280,880,'screen_and_controls.jpg',True),
    'rear': ((-.90,1.67,1.25),(0,.027,.540),1.277,1040,1150,'rear_service_access.jpg',False),
}
pos,target,width,xres,yres,name,powered=views[part]


def look_at(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name,location,power,size,color,target):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.color=color
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=location
    look_at(obj,target)


bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001))
floor=bpy.context.object
floor.name='Habitat floor backdrop'
mat=bpy.data.materials.new('Inspection backdrop')
mat.use_nodes=True
nodes=mat.node_tree.nodes
shader=nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.080,.095,.095,1)
shader.inputs['Roughness'].default_value=.77
noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=68
noise.inputs['Detail'].default_value=2
coord=nodes.new('ShaderNodeTexCoord')
mat.node_tree.links.new(coord.outputs['Object'],noise.inputs['Vector'])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.003
bump.inputs['Strength'].default_value=.18
mat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
mat.node_tree.links.new(bump.outputs['Normal'],shader.inputs['Normal'])
floor.data.materials.append(mat)

light('Habitat key',(-1.35,-1.44,2.06),100,.82,(1,.90,.76),(0,0,.62))
light('Glare raking light',(1.24,.79,1.83),114,.93,(.81,.91,1),(0,0,.70))
light('Floor bounce',(.93,-1.1,.73),25,.82,(.83,.95,1),(0,0,.53))
light('Rear overhead',(0,1.55,2.03),40,1.11,(1,.79,.63),(0,0,.62))
world=bpy.data.worlds.new('Habitat neutral ambient')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.46,.49,.53,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.22
scene.world=world

if powered:
    preview=os.environ['OUTPOST_TERMINAL_SCREEN']
    display=bpy.data.objects['Screen']
    ms=display.data.materials[0]
    nodes=ms.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(preview)
    tex.extension='EXTEND'
    emission=nodes.new('ShaderNodeEmission')
    emission.inputs['Strength'].default_value=.94
    output=nodes.get('Material Output')
    ms.node_tree.links.new(tex.outputs['Color'],emission.inputs['Color'])
    ms.node_tree.links.new(emission.outputs['Emission'],output.inputs['Surface'])

data=bpy.data.cameras.new('Inspection camera')
data.type='ORTHO'
data.ortho_scale=width
camera=bpy.data.objects.new('Inspection camera',data)
scene.collection.objects.link(camera)
camera.location=pos
look_at(camera,target)
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=43
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.038
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=xres
scene.render.resolution_y=yres
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.15
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=95
scene.render.filepath=str(package/'previews'/name)
bpy.ops.render.render(write_still=True)
