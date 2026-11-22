"""Build a damaged supply canopy and three independently releasable lines."""
from pathlib import Path
from math import cos, sin, pi, exp
import argparse
import random
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy

from field_mesh import initialize, anchor, mesh, sweep, v
import field_mesh as tools

parser=argparse.ArgumentParser()
parser.add_argument('--textures',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
package=Path(__file__).resolve().parents[1]
root=initialize('CanopySnag',args.textures)
cloth=anchor('Cloth',parent=root)
rng=random.Random(581)

# Nine sewn sectors flare out from the front tear to the remnant skirt.
# Two torn canopy pieces read as a crown remnant and separated band.
def fabric(u,t):
    x=(u-.5)*(1.71+.66*t)+.088*sin(t*3.6)
    z=.81+t*1.73 + .18*cos((u-.48)*pi)*(.42-t)
    fold=.042*(1+cos(u*39+sin(t*7)*1.1))*(.23+.7*sin(pi*t)**2)
    ridge=.118*exp(-((u-.56)**2/.016+(t-.47)**2/.081))
    y=.014+fold+ridge+.019*(1+sin(t*38+u*12))
    return (x,y,z)


def gore(index,is_band):
    count=9
    rows=15 if not is_band else 7
    strips=8
    pts=[]
    for j in range(rows+1):
        w=j/rows
        for k in range(strips+1):
            u=(index+k/strips)/count
            if is_band:
                start=.857+.016*sin(u*46)+.017*sin(u*21)
                far=1.0+.044*sin(u*65)+.023*sin(u*97)
            else:
                start=.039+.040*sin(u*54)+.024*sin(u*105)
                start+=.179*exp(-((u-.356)**2/.0038))
                far=.826+.019*cos(u*63)+.011*sin(u*70)
                far-=.104*exp(-((u-.715)**2/.0028))
            t=start+(far-start)*w
            pts.append(v(fabric(u,t)))
    f=[]
    for row in range(rows):
        for k in range(strips):
            a=row*(strips+1)+k
            f.append((a,a+1,a+strips+2,a+strips+1))
    role='orange' if (index in (0,4,7) and not is_band or is_band and index in (0,1,7,8)) else 'white_painted'
    obj=mesh('Nylon_gore' if not is_band else 'Separated_canopy_band',pts,f,role,cloth)
    for face in obj.data.polygons:
        face.use_smooth=True


for index in range(9):
    gore(index,False)
    gore(index,True)
for j in range(1,9):
    u=j/9
    for start,end in [(.104,.761),(.887,.982)]:
        points=[]
        for i in range(29):
            x,y,z=fabric(u,start+(end-start)*i/28)
            points.append((x,y+.0019,z))
        sweep('Sewn_tape_seam',points,.0048,'warm_shell',cloth,8)
for u in (.093,.468,.839):
    points=[fabric(u,t) for t in (.780,.810,.856,.891)]
    sweep('Retained_band_sewing_tab',points,.010,'warm_panel',cloth,8)
# Torn edges have narrow loose filaments, rather than printed markings.
for i in range(31):
    u=rng.uniform(.05,.95)
    t=.039+.040*sin(u*54)+.024*sin(u*105)+.179*exp(-((u-.356)**2/.0038))
    x,y,z=fabric(u,t)
    sweep('Frayed_nylon_thread',[(x,y,z),(x+rng.uniform(-.016,.015),y+.006,z-.018),
        (x+rng.uniform(-.034,.034),max(y-.003,.01),z-rng.uniform(.041,.091))],.0018,
        'orange' if i%5==0 else 'warm_shell',cloth,6)

snags=[(-.42,.18,-.38),(.42,.18,.40),(0,.90,.05)]
lines=[anchor(f'Line_{i}',parent=root) for i in (1,2,3)]
for i,at in enumerate(snags,1):
    anchor(f'Snag_{i}',at,root)
# The actual wheel rims sit near x +/-0.50. Snag empties indicate the targets;
# the wrapped fibres run outside the wheels so they read in the rover render.
def wraps(x,y,z,sign,turns=1.20):
    result=[]
    for i in range(75):
        a=pi*1.10+i*(2*pi*turns/74)
        result.append((x+sign*(.016+i*.015/74),y+.174*sin(a),z+.173*cos(a)))
    return result

takeoff=[fabric(.166,.109),fabric(.778,.08),fabric(.54,.07)]
paths=[
    [takeoff[0],(-.94,.027,.77),(-.69,.046,.69),(-.59,.045,.26),
        (-.591,.038,-.10),(-.551,.060,-.303)]+wraps(-.505,.176,-.361,-1),
    [takeoff[1],(.87,.032,.84),(.649,.033,.766),(.584,.045,.662),
        (.533,.088,.608)]+wraps(.502,.176,.382,1),
    [takeoff[2],(.336,.041,.769),(.224,.124,.653),(.139,.353,.584),
        (.093,.528,.479),(.063,.564,.412),(.030,.565,.329),(.005,.585,.244),
        (-.034,.694,.146),(-.090,.849,.051),
        (-.075,.943,-.057),(-.015,.971,-.135),(.088,.964,-.179),
        (.118,.923,-.170),(.092,.866,-.120),(-.01,.825,-.082),
        (-.071,.853,-.146),(-.036,.933,-.230),(.030,.950,-.247),
        (.089,.909,-.234),(.035,.859,-.202)],
]
for i,path in enumerate(paths):
    sweep('Braided_suspension_line',path,.0074 if i<2 else .0065,'warm_shell',lines[i],10)
    x,y,z=path[0]
    sweep('Reinforced_line_webbing',[(x-.024,y+.002,z+.064),(x,y+.011,z+.021),path[0]],
           .012,'orange',lines[i],10)

tools.uv_maps(tools.collection.objects,scale=3.0)
tools.save_and_export(package,'GAR_Y_Canopy_Snag',(0,.33,1.02),5.0)
