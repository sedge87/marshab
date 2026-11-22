"""Render the same landing site as found and commissioned."""
from pathlib import Path
from math import radians, pi
import random
import os

import bpy
from mathutils import Vector, noise


package=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
part=os.environ.get('OUTPOST_SITE_VIEW','commissioned')
views={
    'commissioned': ((20.5,-27.6,25.4),(.6,-.25,.08),26.5,1440,1000,'commissioned_pad.jpg',True),
    'found': ((20.5,-27.6,25.4),(.6,-.25,.08),26.5,1250,868,'survey_site_as_found.jpg',False),
    'beacon': ((13.3,-8.1,2.36),(10.99,-4.84,.94),2.45,1060,1140,'beacon_commissioned.jpg',True),
    'damage': ((13.0,-8.0,2.47),(10.97,-4.73,.82),2.48,1040,1050,'beacon_as_found.jpg',False),
}
pos,target,scale,width,height,filename,powered=views[part]

if not powered:
    bpy.data.objects['BeaconTilt'].rotation_euler.x=-radians(17)
    for name in ['LandingPad','RepairedLead']:
        for o in bpy.data.objects[name].children_recursive:
            o.hide_render=True
    for name in ['BrokenLead','BrokenMastTail']:
        for o in bpy.data.objects[name].children_recursive:
            o.hide_set(False)
            o.hide_render=False
else:
    for material,color,power in [
         ('lamp_amber',(1,.38,.045,1),2.45),
         ('lamp_white',(1,.80,.56,1),1.45)]:
        shader=bpy.data.materials[material].node_tree.nodes.get('Principled BSDF')
        shader.inputs['Emission Color'].default_value=color
        shader.inputs['Emission Strength'].default_value=power

rng=random.Random(1285)
def height_at(x,y):
    edge=max(abs(x),abs(y))
    deck=min(1.0,max(0.0,(edge-12.0)/12.0))
    broad=noise.fractal(Vector((x*.051,y*.060,7.00)),.95,2.,4)
    detail=noise.noise(Vector((x*.32,y*.34,2.23)))
    return -.010+broad*2.9*deck+detail*(.008+.14*deck)

grid=112
step=1.25
points=[]
faces=[]
for j in range(grid+1):
    for i in range(grid+1):
        x=(i-grid/2)*step
        y=(j-grid/2)*step
        points.append((x,y,height_at(x,y)))
for j in range(grid):
    for i in range(grid):
        a=j*(grid+1)+i
        faces.append((a,a+1,a+grid+2,a+grid+1))
ground=bpy.data.meshes.new('Field site terrain')
ground.from_pydata(points,[],faces)
ground.update()
for face in ground.polygons:
    face.use_smooth=True
ground_obj=bpy.data.objects.new('Field site ground for renders',ground)
scene.collection.objects.link(ground_obj)
soil=bpy.data.materials.new('Oxide regolith for renders')
soil.use_nodes=True
nodes=soil.node_tree.nodes
link=soil.node_tree.links
shader=nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.92
coord=nodes.new('ShaderNodeTexCoord')
cloud=nodes.new('ShaderNodeTexNoise')
cloud.inputs['Scale'].default_value=.37
cloud.inputs['Detail'].default_value=5
link.new(coord.outputs['Object'],cloud.inputs['Vector'])
color=nodes.new('ShaderNodeValToRGB')
color.color_ramp.elements[0].position=.18
color.color_ramp.elements[0].color=(.161,.074,.043,1)
color.color_ramp.elements[1].position=.83
color.color_ramp.elements[1].color=(.372,.208,.137,1)
link.new(cloud.outputs['Fac'],color.inputs['Fac'])
link.new(color.outputs['Color'],shader.inputs['Base Color'])
fine=nodes.new('ShaderNodeTexNoise')
fine.inputs['Scale'].default_value=27
fine.inputs['Detail'].default_value=2.5
link.new(coord.outputs['Object'],fine.inputs['Vector'])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value=.32
bump.inputs['Distance'].default_value=.066
link.new(fine.outputs['Fac'],bump.inputs['Height'])
link.new(bump.outputs['Normal'],shader.inputs['Normal'])
ground.materials.append(soil)
rock=bpy.data.materials.new('Basalt field fragments for renders')
rock.use_nodes=True
principled=rock.node_tree.nodes.get('Principled BSDF')
principled.inputs['Base Color'].default_value=(.222,.114,.070,1)
principled.inputs['Roughness'].default_value=.95
for i in range(440):
    x,y=rng.uniform(-24,24),rng.uniform(-22,22)
    if max(abs(x),abs(y))<10.7 or abs(x-10.8)<1.6 and abs(y+4.85)<1.35:
        continue
    r=rng.uniform(.025,.225)*rng.uniform(.60,1.0)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,
                                           location=(x,y,height_at(x,y)+r*.025))
    thing=bpy.context.object
    thing.scale=(rng.uniform(.75,1.85),rng.uniform(.65,1.2),rng.uniform(.24,.70))
    thing.rotation_euler.z=rng.uniform(0,2*pi)
    thing.data.materials.append(rock)

def aim(obj,where):
    obj.rotation_euler=(Vector(where)-obj.location).to_track_quat('-Z','Y').to_euler()


sun_data=bpy.data.lights.new('Low Mars sun','SUN')
sun_data.energy=2.35
sun_data.color=(1,.80,.65)
sun_data.angle=.105
sun=bpy.data.objects.new('Low Mars sun',sun_data)
scene.collection.objects.link(sun)
sun.location=(-9,-13,12)
aim(sun,(0,0,0))
sky=bpy.data.worlds.new('Dusty sky ambient')
sky.use_nodes=True
sky.node_tree.nodes.get('Background').inputs['Color'].default_value=(.50,.57,.69,1)
sky.node_tree.nodes.get('Background').inputs['Strength'].default_value=.55
scene.world=sky

data=bpy.data.cameras.new('Site inspection camera')
data.type='ORTHO'
data.ortho_scale=scale
camera=bpy.data.objects.new('Site inspection camera',data)
scene.collection.objects.link(camera)
camera.location=pos
aim(camera,target)
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=34
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.055
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=width
scene.render.resolution_y=height
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.31
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=95
scene.render.filepath=str(package/'previews'/filename)
bpy.ops.render.render(write_still=True)
