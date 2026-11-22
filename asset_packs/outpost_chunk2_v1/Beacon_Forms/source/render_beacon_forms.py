"""Render each editable beacon option at the same scale and damage state."""
from pathlib import Path
from math import exp, pi
import os
import random

import bpy
from mathutils import Vector, noise


package=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
form=bpy.data.objects['LandingBeacon']['option']
detail=os.environ.get('OUTPOST_BEACON_SHOT','main')=='detail'
rng=random.Random(79)
# A shallow regolith berm fills part of the sunken ballast shoe in the preview.
def height(x,y):
    return -.012+noise.noise(Vector((x*2.75,y*2.75,9)))*.022 + .037*exp(-((x-.56)**2+(y-.34)**2)/.065)

n=68
terrain=[]
faces=[]
for j in range(n+1):
    for i in range(n+1):
        x=(i-n/2)*.22
        y=(j-n/2)*.22
        terrain.append((x,y,height(x,y)))
for j in range(n):
    for i in range(n):
        q=j*(n+1)+i
        faces.append((q,q+1,q+n+2,q+n+1))
ground=bpy.data.meshes.new('Preview field ground')
ground.from_pydata(terrain,[],faces)
ground.update()
for f in ground.polygons:
    f.use_smooth=True
obj=bpy.data.objects.new('Mars surface for preview',ground)
scene.collection.objects.link(obj)

soil=bpy.data.materials.new('Regolith for the preview')
soil.use_nodes=True
nodes=soil.node_tree.nodes
links=soil.node_tree.links
shader=nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.96
coords=nodes.new('ShaderNodeTexCoord')
coarse=nodes.new('ShaderNodeTexNoise')
coarse.inputs['Scale'].default_value=4.7
coarse.inputs['Detail'].default_value=3
links.new(coords.outputs['Object'],coarse.inputs['Vector'])
ramp=nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].position=.16
ramp.color_ramp.elements[0].color=(.108,.054,.034,1)
ramp.color_ramp.elements[1].position=.82
ramp.color_ramp.elements[1].color=(.318,.175,.118,1)
links.new(coarse.outputs['Fac'],ramp.inputs['Fac'])
links.new(ramp.outputs['Color'],shader.inputs['Base Color'])
detail_noise=nodes.new('ShaderNodeTexNoise')
detail_noise.inputs['Scale'].default_value=74
detail_noise.inputs['Detail'].default_value=2
links.new(coords.outputs['Object'],detail_noise.inputs['Vector'])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.014
bump.inputs['Strength'].default_value=.29
links.new(detail_noise.outputs['Fac'],bump.inputs['Height'])
links.new(bump.outputs[0],shader.inputs['Normal'])
ground.materials.append(soil)
stone=bpy.data.materials.new('Preview small angular stones')
stone.use_nodes=True
bs=stone.node_tree.nodes.get('Principled BSDF')
bs.inputs['Base Color'].default_value=(.161,.080,.052,1)
bs.inputs['Roughness'].default_value=.96
for i in range(127):
    x,y=rng.uniform(-4.3,4.3),rng.uniform(-4.4,3.3)
    if x*x+y*y<.94:
        continue
    r=rng.uniform(.014,.073)*rng.uniform(.46,1.1)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x,y,height(x,y)))
    pebble=bpy.context.object
    pebble.scale=(rng.uniform(.8,1.6),rng.uniform(.64,1.4),rng.uniform(.42,.88))
    pebble.rotation_euler.z=rng.uniform(0,2*pi)
    pebble.data.materials.append(stone)


def aim(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()


sun=bpy.data.lights.new('Low dusty daylight','SUN')
sun.energy=2.30
sun.color=(1,.865,.732)
sun.angle=.19
sun_obj=bpy.data.objects.new('Low dusty daylight',sun)
scene.collection.objects.link(sun_obj)
sun_obj.location=(-2.4,4.5,6.0)
aim(sun_obj,(0,0,.43))
world=bpy.data.worlds.new('Mars sky bounce')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.57,.66,.78,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.52
scene.world=world


def camera_at(location,point,scale):
    data=bpy.data.cameras.new('Beacon inspection')
    data.type='ORTHO'
    data.ortho_scale=scale
    camera=bpy.data.objects.new('Beacon inspection',data)
    scene.collection.objects.link(camera)
    camera.location=location
    aim(camera,point)
    scene.camera=camera


if detail:
    camera_at((.78,2.68,1.68),(.02,.14,.70),.88)
    width,height=1180,880
else:
    camera_at((1.47,4.40,2.37),(.109,.031,1.052),2.61)
    width,height=900,1180
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.047
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=width
scene.render.resolution_y=height
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.16
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=94
filename=f'beacon_{form.lower()}{"_repair_detail" if detail else ""}.jpg'
scene.render.filepath=str(package/'previews'/filename)
bpy.ops.render.render(write_still=True)
