"""Render travel, habitat and the actual docked Power Module in Blender."""
from pathlib import Path
from math import pi
import os
import sys

import bpy
from mathutils import Matrix, Vector


package=Path(__file__).resolve().parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from walker_pose import pose_walker

scene=bpy.context.scene
view=os.environ.get('OUTPOST_WALKER_VIEW','travel')
deployed=view=='habitat'
pose_walker(bpy.data.objects,1 if deployed else 0)
bpy.context.view_layer.update()
if view in {'habitat','power'}:
    original=os.environ['OUTPOST_WALKER_POWER_GLB']
    bpy.ops.import_scene.gltf(filepath=original)
    source_case=bpy.data.objects['PowerModule']
    socket=bpy.data.objects['PowerSocket']
    face=bpy.data.objects['SocketFace']
    source_case.matrix_world=socket.matrix_world @ Matrix.Rotation(pi,4,'Z') @ face.matrix_world.inverted() @ source_case.matrix_world
    shader=bpy.data.objects['lamp_glow_lamp_amber'].data.materials[0].node_tree.nodes.get('Principled BSDF')
    shader.inputs['Emission Color'].default_value=(1.0,.47,.12,1)
    shader.inputs['Emission Strength'].default_value=1.3
if deployed:
    bpy.data.objects['EntryHatch'].rotation_euler.z=1.72

shots={
 'travel': ((-6.6,8.0,4.3),(0,.10,1.43),8.9,1380,1030,'walker_1_travel.jpg'),
 'habitat': ((4.8,9.0,4.25),(0,.45,1.62),9.0,1380,1030,'walker_1_habitat.jpg'),
 'power': ((-3.0,5.9,2.62),(-.240,2.31,1.00),4.50,1260,880,'walker_1_power_berth.jpg'),
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
noise.inputs['Scale'].default_value=1.20
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
light.location=(position[0]*.52,4.1,5.7)
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
scene.cycles.samples=30
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.048
scene.cycles.use_denoising=False
scene.cycles.max_bounces=4
scene.render.resolution_x=width
scene.render.resolution_y=height
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.10
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=95
scene.render.filepath=str(Path(os.environ.get('OUTPOST_WALKER_PREVIEWS', package/'previews'))/filename)
bpy.ops.render.render(write_still=True)
