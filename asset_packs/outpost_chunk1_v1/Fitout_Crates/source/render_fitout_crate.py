"""Render fit-out cases closed, open with their cargo, or open and empty."""
from pathlib import Path
from math import radians
import os

import bpy
from mathutils import Vector


package=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
size=os.environ['OUTPOST_CRATE_SIZE']
state=os.environ['OUTPOST_CRATE_STATE']
width,depth,rim={'Small':(.50,.326,.185),'Medium':(.81,.542,.259),'Large':(1.23,.722,.643)}[size]
if state!='closed':
    bpy.data.objects['Lid'].rotation_euler.x=-radians(103)
if state=='empty':
    for obj in bpy.data.objects['Contents'].children_recursive:
        obj.hide_render=True


def aimed(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name,relative_location,power,diameter,color):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power*width**2
    data.color=color
    data.shape='DISK'
    data.size=diameter*width
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=Vector(relative_location)*width
    aimed(obj,(0,0,rim*.80))


bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001))
floor=bpy.context.object
ground=bpy.data.materials.new('Habitat floor only for renders')
ground.use_nodes=True
nodes=ground.node_tree.nodes
links=ground.node_tree.links
shader=nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.082,.102,.101,1)
shader.inputs['Roughness'].default_value=.84
noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=61
coord=nodes.new('ShaderNodeTexCoord')
links.new(coord.outputs['Object'],noise.inputs['Vector'])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.004
bump.inputs['Strength'].default_value=.24
links.new(noise.outputs['Fac'],bump.inputs['Height'])
links.new(bump.outputs['Normal'],shader.inputs['Normal'])
floor.data.materials.append(ground)
light('Warm work light',(-1.2,-1.2,1.9),116,.90,(1,.85,.69))
light('Broad white fill',(.7,-1.18,1.46),60,1.09,(.82,.91,1))
light('Far rim',(.75,1.35,1.85),142,.81,(1.0,.91,.79))
light('Overhead inspection',(0,-.1,2.45),41,.66,(.84,.93,1))
world=bpy.data.worlds.new('Habitat ambient')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.45,.49,.52,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.30
scene.world=world

cam=bpy.data.cameras.new('Inspection')
cam.type='ORTHO'
obj=bpy.data.objects.new('Inspection',cam)
scene.collection.objects.link(obj)
if state=='closed':
    obj.location=(width*.78,-width*1.58,rim+width*.97)
    aimed(obj,(0,0,rim*.55))
    cam.ortho_scale=width*1.43
    x,y=1100,810
elif state=='empty':
    obj.location=(width*.60,-width*1.60,rim+width*1.72)
    aimed(obj,(0,.01,rim*.74))
    cam.ortho_scale=width*1.46
    x,y=1070,920
else:
    obj.location=(width*.93,-width*1.06,rim+width*2.15) if size=='Large' else (width*.46,-width*1.42,rim+width*1.74)
    aim_z=rim*.99 if size=='Large' else rim*.96
    aimed(obj,(0,depth*.115,aim_z))
    cam.ortho_scale=width*(1.56 if size=='Large' else 1.31)
    x,y=(1360,1120) if size=='Large' else (1100,920)
scene.camera=obj
scene.render.engine='CYCLES'
scene.cycles.samples=34 if state=='loaded' else 27
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.052
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=x
scene.render.resolution_y=y
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.12
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=94
scene.render.filepath=str(package/'previews'/f'{size.lower()}_{state}.jpg')
bpy.ops.render.render(write_still=True)
