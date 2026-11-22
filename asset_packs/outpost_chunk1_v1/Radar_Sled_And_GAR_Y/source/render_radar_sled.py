"""Render the actual game exports and a scaled GAR-Y towing fit preview."""
from pathlib import Path
import os

import bpy
from mathutils import Vector


package=Path(__file__).resolve().parents[1]
source=package/'original'
scene=bpy.context.scene
view=os.environ.get('OUTPOST_RADAR_VIEW','fit')


def load(name,root_name):
    bpy.ops.import_scene.gltf(filepath=str(source/name))
    return bpy.data.objects[root_name]


sled=None
if view!='hitch':
    sled=load('Radar_Sled.glb','RadarSled')
tow=bpy.data.objects.get('TowPoint')

if view in {'fit','hitch'}:
    gary=load('GAR_Y_with_mounts.glb','GarY')
    hitch=load('GAR_Y_Tow_Hitch.glb','GAR_Y_TowHitch')
    rear=bpy.data.objects['RearMount']
    hitch.matrix_world=rear.matrix_world.copy()
    bpy.context.view_layer.update()
    if view=='fit':
        cable=bpy.data.objects['CableOut']
        clip=bpy.data.objects['Clip']
        start=cable.matrix_world.translation.copy()
        current=tow.matrix_world.translation.copy()
        end_guess=start+Vector((0,-.681,0))
        sled.location+=Vector((end_guess.x-current.x,end_guess.y-current.y,0))
        bpy.context.view_layer.update()
        end=tow.matrix_world.translation.copy()
        clip.location+=hitch.matrix_world.inverted().to_3x3() @ (end-clip.matrix_world.translation+Vector((0,.020,.040)))
        for obj in clip.children:
            if obj.name.endswith('black_rubber'):
                obj.hide_render=True
        path=bpy.data.curves.new('Illustrative towing cable','CURVE')
        path.dimensions='3D'
        path.bevel_depth=.005
        path.bevel_resolution=4
        spline=path.splines.new('POLY')
        spline.points.add(32)
        for i,point in enumerate(spline.points):
            t=i/32
            coordinate=start.lerp(end,t)
            coordinate.z-=.036*4*t*(1-t)
            point.co=(*coordinate,1)
        obj=bpy.data.objects.new('Preview towing cable',path)
        scene.collection.objects.link(obj)
        path.materials.append(bpy.data.materials['black_rubber'])
        print('Illustrative tow segment length', (end-start).length)
elif view=='antenna':
    sled.rotation_mode='XYZ'
    sled.rotation_euler.y=3.1415926536
    sled.location.z=.432

if view in {'fit','sled'}:
    for material in bpy.data.materials:
        if material.name.startswith('lamp_amber'):
            p=material.node_tree.nodes.get('Principled BSDF')
            if p:
                p.inputs['Emission Color'].default_value=(1,.50,.13,1)
                p.inputs['Emission Strength'].default_value=1.15

shots={
    'fit': ((3.13,1.17,1.77),(0,-.875,.31),3.32,1370,940,'gar_y_survey_rig.jpg'),
    'sled': ((1.38,1.66,1.00),(0,.034,.18),1.55,1240,925,'radar_sled_3q.jpg'),
    'hitch': ((.63,-1.20,.91),(0,-.533,.41),.58,1080,810,'rear_hitch_fit.jpg'),
    'antenna': ((.72,-1.20,1.38),(0,0,.245),1.45,1110,830,'radar_antenna_underbody.jpg'),
}
position,target,scale,width,height,filename=shots[view]

def aim(o,t):
    o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()


bpy.ops.mesh.primitive_plane_add(size=180,location=(0,0,-.011))
floor=bpy.context.object
soil=bpy.data.materials.new('Regolith inspection ground')
soil.use_nodes=True
nodes=soil.node_tree.nodes
links=soil.node_tree.links
bs=nodes.get('Principled BSDF')
bs.inputs['Base Color'].default_value=(.254,.144,.090,1)
bs.inputs['Roughness'].default_value=.94
coords=nodes.new('ShaderNodeTexCoord')
noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=8
noise.inputs['Detail'].default_value=3
links.new(coords.outputs['Object'],noise.inputs[0])
color=nodes.new('ShaderNodeValToRGB')
color.color_ramp.elements[0].position=.17
color.color_ramp.elements[0].color=(.146,.069,.039,1)
color.color_ramp.elements[1].position=.79
color.color_ramp.elements[1].color=(.321,.170,.103,1)
links.new(noise.outputs['Fac'],color.inputs['Fac'])
links.new(color.outputs['Color'],bs.inputs['Base Color'])
fine=nodes.new('ShaderNodeTexNoise')
fine.inputs['Scale'].default_value=86
fine.inputs['Detail'].default_value=2
links.new(coords.outputs['Object'],fine.inputs[0])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.009
bump.inputs['Strength'].default_value=.32
links.new(fine.outputs['Fac'],bump.inputs['Height'])
links.new(bump.outputs[0],bs.inputs['Normal'])
floor.data.materials.append(soil)

sun=bpy.data.lights.new('Filtered Mars daylight','SUN')
sun.energy=2.3
sun.color=(1,.81,.68)
sun.angle=.15
light=bpy.data.objects.new('Filtered Mars daylight',sun)
scene.collection.objects.link(light)
light.location=(2,2.7,4.2)
aim(light,(0,-.48,0))
world=bpy.data.worlds.new('Dusty daylight')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.52,.62,.77,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.50
scene.world=world

data=bpy.data.cameras.new('Inspection camera')
data.type='ORTHO'
data.ortho_scale=scale
camera=bpy.data.objects.new('Inspection camera',data)
scene.collection.objects.link(camera)
camera.location=position
aim(camera,target)
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=35
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.052
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=width
scene.render.resolution_y=height
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.05
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=95
scene.render.filepath=str(package/'previews'/filename)
bpy.ops.render.render(write_still=True)
