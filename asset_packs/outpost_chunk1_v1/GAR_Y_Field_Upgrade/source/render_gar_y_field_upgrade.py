"""Render the upgraded GLB as imported, with the optional fitted tow hitch."""
from pathlib import Path
import os

import bpy
from mathutils import Vector


package=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
view=os.environ.get('OUTPOST_GARY_VIEW','hero')
bpy.ops.import_scene.gltf(filepath=str(package/'original'/'GAR_Y_Field_Upgrade.glb'))
if view=='rear' and os.environ.get('OUTPOST_GARY_HITCH'):
    bpy.ops.import_scene.gltf(filepath=os.environ['OUTPOST_GARY_HITCH'])
    hitch=bpy.data.objects['GAR_Y_TowHitch']
    hitch.matrix_world=bpy.data.objects['RearMount'].matrix_world.copy()
    bpy.context.view_layer.update()

shots={
    'hero': ((1.42,2.06,1.50),(0,.011,.450),1.820,1420,1060,'gar_y_field_upgrade_3q.jpg'),
    'rear': ((1.52,-1.90,1.25),(0,-.15,.440),1.635,1220,940,'gar_y_rear_mount_detail.jpg'),
    'wheel': ((1.67,-.62,.72),(.319,-.068,.243),1.056,1140,820,'gar_y_wheel_and_chassis_detail.jpg'),
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
scene.cycles.samples=37
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
