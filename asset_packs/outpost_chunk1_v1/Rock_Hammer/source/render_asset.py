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
parser.add_argument('--gary', type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
kind=package.name
scene=bpy.context.scene

def vec(p):
    x,y,z=p
    return Vector((x,-z,y))

def aim(obj,target):
    obj.rotation_euler=(vec(target)-obj.location).to_track_quat('-Z','Y').to_euler()

gary=None
if kind=='Canopy_Snag' and args.gary:
    # Only in this render scene. The stand-alone canopy export remains independent.
    original=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(args.gary.resolve()))
    gary=[o for o in bpy.data.objects if o not in original]
    for obj in gary:
        if obj.type=='MESH':
            for material in obj.data.materials:
                if material and material.name.startswith('eye_glow') and material.use_nodes:
                    bs=next((n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                    if bs is not None:
                        bs.inputs['Emission Strength'].default_value=.75

scene_poses={
    # camera in Godot coordinates, target, horizontal scale, pose or release count
    'Walker_1': {
        'walker_standing':((-11,10,18),(0,2.63,0),20.0,'standing'),
        'walker_walking':((-11,10,-18),(0,2.83,0),20.0,'walking'),
        'walker_lowering':((13,8,-19),(0,2.35,0),20.0,'lowering'),
        'walker_kneeling':((13,8,-19),(0,2.35,0),20.0,'kneeling'),
        'walker_leg_knee_and_wheel':((-13,3,-9),(-6.59,2.37,-4.88),6.3,'standing'),
        'walker_ride_deck_screen_and_mast':((4.30,9.2,-.4),(1.07,5.95,-3.94),5.8,'standing'),
        'walker_cables_and_module_lugs':((9.4,4.1,6.0),(1.9,3.76,1.49),7.4,'lowering'),
        'walker_ladder_sections_and_shoe':((4,4,15),(0,2.62,5.97),7.2,'standing'),
        'walker_power_socket_and_strut':((-8.3,2.7,-2.8),(-3.59,1.93,.09),4.9,'standing'),
        'walker_wheel_1_seal_ring':((-11,1.65,-6.67),(-7.72,.66,-5.03),1.68,'standing')
    },
    'Canopy_Snag': {
        'gary_snagged':((-2.9,3.3,4.4),(0,.19,1.04),4.14,0),
        'gary_line_1_front_left':((-1.8,.73,.04),(-.48,.23,-.17),.98,0),
        'gary_line_2_back_right':((1.75,.87,1.33),(.38,.25,.48),1.0,1),
        'gary_line_3_mast':((.97,1.6,1.75),(0,.71,.19),1.19,2),
        'canopy_freed':((-2.9,3.3,4.4),(0,.22,1.04),4.14,3)
    },
    'Rock_Hammer': {
        'rock_hammer_three_quarter':((.39,.38,-.44),(0,0,-.085),.48,None),
        'rock_hammer_strike_face_and_pick':((.30,.25,-.42),(0,0,-.233),.225,None)
    },
    'Sample_Scoop': {
        'sample_scoop_three_quarter':((.33,.43,-.40),(0,-.002,-.096),.49,0),
        'sample_scoop_pan_joint_tipped':((.252,.36,-.40),(0,-.025,-.201),.235,42)
    }
}

floor_height=-.004
if kind in ('Rock_Hammer','Sample_Scoop'):
    floor_height=-.064
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
grain.inputs['Scale'].default_value=8 if floor_height>-.01 else 24
grain.inputs['Detail'].default_value=3
links.new(coords.outputs['Object'],grain.inputs[0])
colors=nodes.new('ShaderNodeValToRGB')
colors.color_ramp.elements[0].position=.16
colors.color_ramp.elements[1].position=.84
colors.color_ramp.elements[0].color=(.122,.061,.038,1) if floor_height>-.01 else (.043,.050,.050,1)
colors.color_ramp.elements[1].color=(.273,.142,.092,1) if floor_height>-.01 else (.099,.115,.118,1)
links.new(grain.outputs['Fac'],colors.inputs['Fac'])
links.new(colors.outputs['Color'],bs.inputs['Base Color'])
fine=nodes.new('ShaderNodeTexNoise')
fine.inputs['Scale'].default_value=78 if floor_height>-.01 else 340
fine.inputs['Detail'].default_value=2
links.new(coords.outputs['Object'],fine.inputs[0])
bump=nodes.new('ShaderNodeBump')
bump.inputs['Distance'].default_value=.007 if floor_height>-.01 else .00055
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
if kind in ('Rock_Hammer','Sample_Scoop'):
    for label,location,color,energy,size in [
        ('Key',(.10,.42,-.30),(.92,.96,1),9,.36),
        ('Edge',(-.19,.31,.16),(1,.85,.73),7,.27)
    ]:
        panel=bpy.data.lights.new(label,'AREA')
        panel.energy,panel.size,panel.color=energy,size,color
        source=bpy.data.objects.new(label,panel)
        scene.collection.objects.link(source)
        source.location=vec(location)
        aim(source,(0,0,-.08))
data=bpy.data.cameras.new('Inspection camera')
data.type='ORTHO'
data.clip_start=.005
camera=bpy.data.objects.new('Inspection camera',data)
scene.collection.objects.link(camera)
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=int(os.environ.get('OUTPOST_RENDER_SAMPLES','25'))
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

for view in args.views:
    position,target,scale,state=scene_poses[kind][view]
    if kind=='Walker_1':
        from walker_pose import apply_pose
        apply_pose(state)
        material=bpy.data.materials['lamp_white'].node_tree.nodes.get('Principled BSDF')
        material.inputs['Emission Color'].default_value=(1,.88,.72,1)
        material.inputs['Emission Strength'].default_value=2.1 if state=='walking' else 0
        for marker in ('Headlamp_L','Headlamp_R'):
            name=marker+' render light'
            lamp=bpy.data.objects.get(name)
            if lamp is None:
                spot=bpy.data.lights.new(name,'SPOT')
                spot.spot_size=.86
                spot.shadow_soft_size=.085
                lamp=bpy.data.objects.new(name,spot)
                scene.collection.objects.link(lamp)
            lamp.data.energy=130 if state=='walking' else 0
            lamp.data.color=(1,.87,.67)
            lamp.location=bpy.data.objects[marker].matrix_world.translation+vec((0,0,-.058))
            aim(lamp,(lamp.location.x,.2,-13))
    elif kind=='Canopy_Snag':
        for i in (1,2,3):
            line=bpy.data.objects[f'Line_{i}']
            for obj in line.children_recursive:
                obj.hide_render=i<=state
        if view=='canopy_freed' and gary is not None:
            for obj in gary:
                obj.hide_render=True
            position,target,scale=(-1.95,2.9,4.2),(0,.12,1.68),2.90
    elif kind=='Sample_Scoop':
        bpy.data.objects['Pan'].rotation_euler.x=-state*3.14159265/180.
    camera.location=vec(position)
    data.ortho_scale=scale
    aim(camera,target)
    scene.render.resolution_x=1280 if view in ('walker_standing','walker_walking','walker_lowering',
        'walker_kneeling','gary_snagged','canopy_freed') else 1040
    scene.render.resolution_y=910 if scene.render.resolution_x==1280 else 770
    scene.render.filepath=str(package/'previews'/f'{view}.jpg')
    bpy.ops.render.render(write_still=True)
