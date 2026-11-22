"""Make in-context JPG previews of the actual Chunk 2 source models."""
import argparse
from math import exp
import os
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector, noise

package=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('views',nargs='+')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
scene=bpy.context.scene
objects=bpy.data.objects


def v(p):
    return Vector((p[0],-p[2],p[1]))


def aim(obj,target):
    obj.rotation_euler=(v(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def terrain_material():
    soil=bpy.data.materials.new('Preview regolith')
    soil.use_nodes=True
    nodes,links=soil.node_tree.nodes,soil.node_tree.links
    surface=nodes.get('Principled BSDF')
    surface.inputs['Roughness'].default_value=.93
    coord=nodes.new('ShaderNodeTexCoord')
    roughness=nodes.new('ShaderNodeTexNoise')
    roughness.inputs['Scale'].default_value=5.1
    roughness.inputs['Detail'].default_value=4
    links.new(coord.outputs['Object'],roughness.inputs['Vector'])
    color=nodes.new('ShaderNodeValToRGB')
    color.color_ramp.elements[0].position=.17
    color.color_ramp.elements[0].color=(.104,.046,.028,1)
    color.color_ramp.elements[1].position=.85
    color.color_ramp.elements[1].color=(.306,.160,.103,1)
    links.new(roughness.outputs['Fac'],color.inputs[0])
    links.new(color.outputs['Color'],surface.inputs['Base Color'])
    grain=nodes.new('ShaderNodeTexNoise')
    grain.inputs['Scale'].default_value=83
    grain.inputs['Detail'].default_value=2.6
    links.new(coord.outputs['Object'],grain.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump')
    bump.inputs['Distance'].default_value=.006
    bump.inputs['Strength'].default_value=.26
    links.new(grain.outputs['Fac'],bump.inputs['Height'])
    links.new(bump.outputs['Normal'],surface.inputs['Normal'])
    return soil


soil=terrain_material()
shots={
    'beacon_as_found': ((1.42,2.29,-4.30),(.120,1.05,-.04),2.62,940,1080),
    'beacon_reseated': ((1.42,2.29,-4.30),(.080,1.05,-.04),2.62,940,1080),
    'beacon_running': ((1.42,2.29,-4.30),(.080,1.05,-.04),2.62,940,1080),
    'beacon_sunk_foot_and_lever': ((1.36,.66,-1.62),(.416,.190,-.29),.95,1040,780),
    'beacon_connector_and_blank_display': ((.64,1.33,-1.81),(.175,.76,-.28),.76,1080,820),
    'beacon_hitch_and_lamp': ((.71,2.43,-1.93),(0,1.993,-.069),.680,1050,810),
    'beacon_carry_handles': ((1.33,1.21,-1.53),(.115,.751,-.132),.69,1030,780),
    'pad_site_layout': ((5.5,6.2,-7.1),(0,.03,-.03),9.20,1240,910),
    'pad_corner_marker': ((.52,.46,-.76),(0,.204,0),.542,920,890),
    'pad_slab_step': ((1.64,1.08,-2.60),(0,.045,-.36),2.63,1100,820),
    'pad_crack_edge_strip': ((1.93,1.18,-2.88),(0,.01,0),2.99,1100,825),
    'pit_rubble_set': ((1.01,1.87,-3.7),(0,.105,-1.5),3.88,1120,790),
    'pit_undercut_detail': ((2.34,.52,-3.93),(0,-.235,.18),3.90,1220,880),
}

camera_data=bpy.data.cameras.new('Inspection camera')
camera_data.type='ORTHO'
camera_data.clip_start=.007
camera=bpy.data.objects.new('Inspection camera',camera_data)
scene.collection.objects.link(camera)
scene.camera=camera
sun_data=bpy.data.lights.new('Filtered daylight','SUN')
sun_data.color=(1,.865,.76)
sun_data.angle=.19
sun=bpy.data.objects.new('Filtered daylight',sun_data)
scene.collection.objects.link(sun)
sun.location=v((-3,6,-4))
aim(sun,(0,.31,0))
world=bpy.data.worlds.new('Filtered sky')
world.use_nodes=True
sky=world.node_tree.nodes.get('Background')
sky.inputs['Color'].default_value=(.59,.69,.83,1)
scene.world=world
scene.render.engine='CYCLES'
scene.cycles.samples=int(os.environ.get('OUTPOST_RENDER_SAMPLES','17'))
scene.cycles.use_adaptive_sampling=True
scene.cycles.adaptive_threshold=.061
scene.cycles.use_denoising=False
scene.cycles.max_bounces=3
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.10
scene.render.image_settings.file_format='JPEG'
scene.render.image_settings.quality=93
preview_nodes=[]


def ground_height(x,z,view):
    fine=noise.noise(Vector((1.6*x,1.6*z,4)))*.008
    if view in ('beacon_as_found','beacon_sunk_foot_and_lever'):
        # Soil partially covers the lowered shoe without filling the toe pocket.
        return -.008+fine+.025*exp(-((x-.62)**2+(z+.35)**2)/.025)
    if view=='pad_site_layout':
        return -.040+fine
    if view=='pad_slab_step':
        return -.027+fine if x<-.050 else -.106+fine
    if view=='pit_undercut_detail':
        return (-.99 if z<.38 else -.048)+fine*4.3
    return -.009+fine


def make_ground(view):
    n=78
    step=.16 if view!='pad_corner_marker' else .047
    vertices=[]
    for j in range(n+1):
        for i in range(n+1):
            x,z=(i-n/2)*step,(j-n/2)*step
            vertices.append(v((x,ground_height(x,z,view),z)))
    faces=[]
    for j in range(n):
        for i in range(n):
            k=j*(n+1)+i
            faces.append((k,k+1,k+n+2,k+n+1))
    data=bpy.data.meshes.new('Preview ground')
    data.from_pydata(vertices,[],faces)
    data.materials.append(soil)
    data.update()
    node=bpy.data.objects.new('Preview ground',data)
    scene.collection.objects.link(node)
    preview_nodes.append(node)
    if view.startswith('beacon_') or view=='pad_site_layout':
        backdrop_height=-.075 if view=='pad_site_layout' else -.038
        bpy.ops.mesh.primitive_plane_add(size=160,location=(0,0,backdrop_height))
        backdrop=bpy.context.object
        backdrop.data.materials.append(soil)
        preview_nodes.append(backdrop)


def show(root,visible):
    children=[root,*root.children_recursive]
    for node in children:
        node.hide_render=not visible


def light_material(name,strength):
    material=bpy.data.materials.get(name)
    if material is None:
        return
    shader=next(node for node in material.node_tree.nodes if node.type=='BSDF_PRINCIPLED')
    shader.inputs['Emission Color'].default_value=(1,.40,.079,1)
    shader.inputs['Emission Strength'].default_value=strength


def pose_beacon(view):
    from math import radians
    damaged=view in ('beacon_as_found','beacon_sunk_foot_and_lever','beacon_connector_and_blank_display')
    connected=view=='beacon_running'
    objects['Mast'].rotation_euler.y = radians(12) if damaged else 0
    foot=objects['Foot_1']
    foot.rotation_mode='QUATERNION'
    foot.rotation_quaternion=Quaternion(Vector(foot['depression_axis']),radians(9 if damaged else 0))
    for name in ('Lead','Connector'):
        show(objects[name],connected)
    for name in ('LeadLoose','LeadTorn'):
        show(objects[name],not connected)
    light_material('lamp_amber',3.1 if connected else 0.)


def duplicate_marker(root,point):
    for mesh in root.children_recursive:
        if mesh.type!='MESH':
            continue
        copy=mesh.copy()
        copy.hide_render=False
        scene.collection.objects.link(copy)
        temp=mesh.matrix_world.copy()
        temp.translation-=root.matrix_world.translation
        temp.translation+=v(point)
        copy.parent=None
        copy.matrix_world=temp
        preview_nodes.append(copy)


def pose_pad(view):
    layout=objects['PadSiteLayout']
    marker=objects['PadCornerMarker']
    slabs=[objects[n] for n in ('CrackedSlabA','CrackedSlabB','CrackedSlabStep')]
    spill=objects['PadCrackEdgeStrip']
    for node in layout.children:
        show(node,False)
    step=objects['Half_B']
    step.location.z=-.085 if view in ('pad_slab_step','pad_site_layout') else 0.
    light_material('lamp_amber',2.1 if view!='pad_slab_step' and view!='pad_crack_edge_strip' else 0.)
    if view=='pad_site_layout':
        for slab,position in zip(slabs,((-1.29,0,1.33),(1.23,0,1.26),(-1.26,0,-1.30))):
            slab.location=v(position)
            show(slab,True)
        spill.location=v((.24,-.004,-1.48))
        spill.rotation_euler.z=-.11
        show(spill,True)
        positions=[(-2.93,-.122,-2.81),(2.82,-.122,-2.81),(-2.93,-.122,2.81),(2.82,-.122,2.81)]
        marker.location=v(positions[0])
        show(marker,True)
        bpy.context.view_layer.update()
        for point in positions[1:]:
            duplicate_marker(marker,point)
    elif view=='pad_corner_marker':
        marker.location=v((0,-.106,0))
        show(marker,True)
    elif view=='pad_slab_step':
        slabs[2].location=v((0,0,0))
        show(slabs[2],True)
    else:
        spill.location=v((0,.011,0))
        spill.rotation_euler.z=-.10
        show(spill,True)


def pose_pit(view):
    root=objects['PitLipLayout']
    undercut=objects['PitLipUndercut']
    for node in root.children:
        show(node,(node==undercut)==(view=='pit_undercut_detail'))
    if view=='pit_undercut_detail':
        undercut.location=v((0,-.115,.27))


for view in args.views:
    for node in preview_nodes:
        bpy.data.objects.remove(node,do_unlink=True)
    preview_nodes.clear()
    make_ground(view)
    if package.name=='Pad_Beacon':
        pose_beacon(view)
    elif package.name=='Pad_Site':
        pose_pad(view)
    else:
        pose_pit(view)
    pos,target,zoom,width,height=shots[view]
    camera.location=v(pos)
    camera_data.ortho_scale=zoom
    aim(camera,target)
    dusk=view=='beacon_running'
    sun_data.energy=1.13 if dusk else 2.44
    sky.inputs['Strength'].default_value=.29 if dusk else .53
    scene.render.resolution_x=width
    scene.render.resolution_y=height
    scene.render.filepath=str(package/'previews'/f'{view}.jpg')
    bpy.ops.render.render(write_still=True)
