"""Render the packaged power module in Blender Cycles."""
import bpy
from mathutils import Vector
from pathlib import Path
import os

package = Path(__file__).resolve().parents[1]
scene=bpy.context.scene
part=os.environ.get('OUTPOST_POWER_VIEW','module')
views={
    'module': ((1.33,1.72,1.11),(0,.025,.244),1.42,1440,1010,'power_module_3q.jpg','off'),
    'tow': ((.90,-1.21,.77),(0,-.170,.226),.99,1300,900,'tow_eye_and_indicator.jpg','amber'),
    'dock': ((.52,1.31,.46),(0,.369,.252),.65,1300,890,'keyed_docking_face.jpg','off'),
    'running': ((.64,-.81,1.08),(0,-.257,.433),.365,900,550,'running_lamp.jpg','white'),
}
pos,target,width,xres,yres,name,state=views[part]

def set_view(o,look):
    o.rotation_euler=(Vector(look)-o.location).to_track_quat('-Z','Y').to_euler()


def light(name,pos,watts,size,color,target=(0,0,.22)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=watts
    data.color=color
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=pos
    set_view(obj,target)


bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001))
floor=bpy.context.object
floor.name='Preview ground'
ground=bpy.data.materials.new('Packed regolith display floor')
ground.use_nodes=True
nodes=ground.node_tree.nodes
links=ground.node_tree.links
shader=nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.88
coords=nodes.new('ShaderNodeTexCoord')
noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=3.7
noise.inputs['Detail'].default_value=5
links.new(coords.outputs['Object'],noise.inputs['Vector'])
fine=nodes.new('ShaderNodeTexNoise')
fine.inputs['Scale'].default_value=84
fine.inputs['Detail'].default_value=2
links.new(coords.outputs['Object'],fine.inputs['Vector'])
ramp=nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].position=.17
ramp.color_ramp.elements[0].color=(.092,.055,.039,1)
ramp.color_ramp.elements[1].position=.79
ramp.color_ramp.elements[1].color=(.230,.144,.098,1)
links.new(noise.outputs['Fac'],ramp.inputs['Fac'])
links.new(ramp.outputs['Color'],shader.inputs['Base Color'])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value=.22
bump.inputs['Distance'].default_value=.006
links.new(fine.outputs['Fac'],bump.inputs['Height'])
links.new(bump.outputs['Normal'],shader.inputs['Normal'])
floor.data.materials.append(ground)

light('Warm Mars key',(-1.45,1.04,1.85),96,.85,(1.0,.86,.72))
light('Cool sky fill',(1.40,-1.26,1.40),57,1.24,(.76,.88,1.0))
light('Rim',(-.25,-1.65,1.27),67,.68,(1.0,.74,.52))
light('Neutral contact fill',(1.41,1.34,.74),26,1.16,(.86,.94,1.0))
world=bpy.data.worlds.new('Hazy daylight')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.45,.48,.51,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.27
scene.world=world

if state!='off':
    lens=bpy.data.objects['StatusLamp'].data.materials[0]
    shader=lens.node_tree.nodes.get('Principled BSDF')
    color=(1,.46,.068,1) if state=='amber' else (1,.915,.805,1)
    shader.inputs['Base Color'].default_value=color
    shader.inputs['Emission Color'].default_value=color
    shader.inputs['Emission Strength'].default_value=1.25
    if state=='amber':
        light('Amber lens bounce',(0,-.300,.476),.09,.030,(1,.46,.068),(0,-.302,.442))

camera=bpy.data.cameras.new('Inspection camera')
camera.type='ORTHO'
camera.ortho_scale=width
camera_obj=bpy.data.objects.new('Inspection camera',camera)
scene.collection.objects.link(camera_obj)
camera_obj.location=pos
set_view(camera_obj,target)
scene.camera=camera_obj
scene.render.engine='CYCLES'
scene.cycles.samples=54 if part!='running' else 46
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.041
scene.cycles.use_denoising=False
scene.cycles.max_bounces=5
scene.render.resolution_x=xres
scene.render.resolution_y=yres
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.2
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=95
scene.render.filepath=str(package/'previews'/name)
bpy.ops.render.render(write_still=True)
