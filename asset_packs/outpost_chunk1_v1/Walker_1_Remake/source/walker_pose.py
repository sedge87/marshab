"""Set the authored travel or habitat pose on a Walker 1 Blender hierarchy."""
from math import acos, atan2, cos, pi, sin


def smooth(value):
    f=max(0.,min(1.,value))
    return f*f*(3-2*f)


def between(a,b,t):
    return a+(b-a)*t


def pose_walker(objects,t):
    body=objects['Body']
    body.location.z=-.42*t
    reach=between(1.55,1.27,t)
    rise=.414 - (1.39 + body.location.z)
    l1,l2=1.15,.96
    lower=-acos(max(-1.,min(1.,(reach*reach+rise*rise-l1*l1-l2*l2)/(2*l1*l2))))
    upper=atan2(rise,reach)-atan2(l2*sin(lower),l1+l2*cos(lower))
    for i in range(1,7):
        objects[f'Leg_{i}'].rotation_euler.z=pi if i%2 else 0
        objects[f'UpperLeg_{i}'].rotation_euler.y=-upper
        objects[f'LowerLeg_{i}'].rotation_euler.y=-lower
        objects[f'AxleCarrier_{i}'].rotation_euler.y=upper+lower
    roof_z=between(2.649,3.817,smooth(t/.38))
    objects['Roof'].location.z=roof_z
    for i in range(1,5):
        objects[f'LiftPost_{i}'].scale.z=(roof_z-1.707)/(3.817-1.707)
    for name,z,start,end,axis,sign in [
            ('RearWall',2.330,.23,.53,'x',-1),('EntryWall',2.027,.39,.70,'x',1),
            ('SideWall_R',1.835,.56,.88,'y',-1),('SideWall_L',1.648,.70,1.0,'y',1)]:
        phase=max(0.,min(1.,(t-start)/(end-start)))
        wall=objects[name]
        wall.location.z=between(z,1.609,smooth(phase*1.9))
        setattr(wall.rotation_euler,axis,sign*pi/2*(1-smooth(phase)))
