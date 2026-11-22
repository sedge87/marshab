"""Standalone state previews for the production scale Walker."""
from math import acos, atan2, cos, sin, pi
import bpy
from mathutils import Matrix, Vector


def clamp(x):
    return max(0.,min(1.,x))


def apply_pose(state='standing',*,unit_cables=False,stage=None):
    o=bpy.data.objects
    bpy.context.view_layer.update()
    lowering,packing,kneel={
        'standing':(0.,0.,0.),'walking':(0.,1.,0.),
        'lowering':(.65,0.,0.),'kneeling':(1.,1.,1.)
    }[state] if stage is None else stage
    drop=kneel*3.2
    o['Body'].location.z=-drop
    o['Module'].location.z=1.25*(1.-lowering)
    dy=.62-(5.05-drop)
    dx=3.60
    l1,l2=3.0,3.10
    b=-acos(max(-1.,min(1.,(dx*dx+dy*dy-l1*l1-l2*l2)/(2*l1*l2))))
    a=atan2(dy,dx)-atan2(l2*sin(b),l1+l2*cos(b))
    for i in range(1,7):
        s=-1 if i<=3 else 1
        base=Matrix((Vector((0,s,0)),Vector((0,0,1)),Vector((s,0,0)))).transposed()
        hip=o[f'Hip_{i}']; knee=o[f'Knee_{i}']; cb=o[f'AxleCarrier_{i}']
        hip.rotation_mode=knee.rotation_mode=cb.rotation_mode='QUATERNION'
        hip.rotation_quaternion=(base@Matrix.Rotation(-a,3,'X')).to_quaternion()
        knee.rotation_quaternion=Matrix.Rotation(-b,3,'X').to_quaternion()
        cb.rotation_quaternion=(Matrix.Rotation(a+b,3,'X')@base.inverted()).to_quaternion()

    o['RideDeckFold'].rotation_euler.x=-pi*.515 if kneel>0 else 0.
    o['Berth'].location.z=.35+drop
    o['BerthStrut'].scale.z=(4.621-drop)/4.621

    slope=1.66/5.51
    for i,high,travel in [(2,4.033,1.9),(3,2.165,3.6)]:
        vertical=high+travel*packing
        o[f'Ladder_{i}'].location.z=vertical
        o[f'Ladder_{i}'].location.y=-(7.40-slope*vertical)
    o['LadderShoe'].rotation_euler.x=pi*.58*packing

    for i in range(1,5):
        axis=-1 if i in (1,3) else 1
        group=o[f'WinchArm_{i}']
        group.location.x=axis*(2.6+(.94 if kneel>0 else 0.))
        cable=o[f'Cable_{i}']
        cable.scale.z=1. if unit_cables else (.010 if kneel>0 else 4.985-(4.659-1.25*lowering))
        for child in cable.children_recursive:
            child.hide_render=kneel>0
    bpy.context.view_layer.update()
