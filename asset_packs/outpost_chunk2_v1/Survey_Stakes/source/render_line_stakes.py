"""Render JPG views from the editable asset, including articulation checks."""
import argparse
import os
from pathlib import Path
import sys

import bpy
from mathutils import Vector

package=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
parser=argparse.ArgumentParser()
parser.add_argument('views', nargs='+')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
scene=bpy.context.scene

def vec(p):
    x,y,z=p
    return Vector((x,-z,y))

def aim(obj,target):
    obj.rotation_euler=(vec(target)-obj.location).to_track_quat('-Z','Y').to_euler()

shots={
    'survey_stake_three_quarter':((1.10,.91,-1.40),(.047,.459,0),.94,'neutral'),
    'survey_stake_glove_grip_and_flag':((.82,.80,-1.10),(.068,.651,0),.63,'tilted'),
    'survey_stake_signal_detail':((.38,1.14,-.64),(.021,.847,-.003),.205,'signal'),
    'stake_bundle_three_quarter':((1.51,.94,-1.34),(0,.080,-.013),1.12,'neutral'),
    'stake_bundle_handle_and_buckle':((.39,.59,-.59),(.021,.128,-.140),.61,'neutral'),
}

floor_height=-.004
bpy.ops.mesh.primitive_plane_add(size=120,location=(0,0,floor_height))
floor=bpy.context.object
soil=bpy.data.materials.new('Render ground')
soil.use_nodes=True
nodes=soil.node_tree.nodes
links=soil.node_tree.links
bs=nodes.get('Principled BSDF')
bs.inputs['Roughness'].default_value=.86
coords=nodes.new('ShaderNodeTexCoord')
grain=nodes.new('ShaderNodeTexNoise')
grain.inputs['Scale'].default_value=8
grain.inputs['Detail'].default_value=3
links.new(coords.outputs['Object'],grain.inputs[0])
colors=nodes.new('ShaderNodeValToRGB')
colors.color_ramp.elements[0].position=.16
colors.color_ramp.elements[1].position=.84
colors.color_ramp.elements[0].color=(.122,.061,.038,1)
colors.color_ramp.elements[1].color=(.273,.142,.092,1)
links.new(grain.outputs['Fac'],colors.inputs['Fac'])
links.new(colors.outputs['Color'],bs.inputs['Base Color'])
fine=nodes.new('ShaderNodeTexNoise')
fine.inputs['Scale'].default_value=78
fine.inputs['Detail'].default_value=2
links.new(coords.outputs['Object'],fine.inputs[0])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.004
bump.inputs['Strength'].default_value=.24
links.new(fine.outputs['Fac'],bump.inputs['Height'])
links.new(bump.outputs[0],bs.inputs['Normal'])
floor.data.materials.append(soil)

sun=bpy.data.lights.new('Filtered sunlight','SUN')
sun.energy=2.45
sun.color=(1,.88,.77)
sun.angle=.17
light=bpy.data.objects.new('Filtered sunlight',sun)
scene.collection.objects.link(light)
light.location=vec((-4,7,-3))
aim(light,(0,0,.5))
world=bpy.data.worlds.new('Dusty daylight')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.60,.72,.87,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.52
scene.world=world
data=bpy.data.cameras.new('Inspection camera')
data.type='ORTHO'
data.clip_start=.005
camera=bpy.data.objects.new('Inspection camera',data)
scene.collection.objects.link(camera)
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=int(os.environ.get('OUTPOST_RENDER_SAMPLES','18'))
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.047
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_percentage=int(os.environ.get('OUTPOST_RENDER_SCALE','100'))
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.05
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=93

stake=bpy.data.objects.get('SurveyStake')
for view in args.views:
    position,target,scale,state=shots[view]
    if stake is not None:
        from math import radians
        bpy.data.objects['Flag'].rotation_euler.z = radians(-28) if state=='tilted' else 0
        material=bpy.data.materials['lamp_amber'].node_tree.nodes.get('Principled BSDF')
        material.inputs['Emission Color'].default_value=(1,.35,.04,1)
        material.inputs['Emission Strength'].default_value=1.05 if state=='signal' else 0
    camera.location=vec(position)
    data.ortho_scale=scale
    aim(camera,target)
    scene.render.resolution_x=1080
    scene.render.resolution_y=1200 if view=='survey_stake_three_quarter' else 825
    scene.render.filepath=str(package/'previews'/f'{view}.jpg')
    bpy.ops.render.render(write_still=True)
