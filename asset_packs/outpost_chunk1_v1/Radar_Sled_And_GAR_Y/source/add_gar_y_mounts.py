"""Add the three fitting anchors and rear backing plate to the supplied GAR-Y GLB."""
import argparse
from math import cos, pi, sin, sqrt
from pathlib import Path
import json
import struct


def read_glb(path):
    data=path.read_bytes()
    magic,version,total,length,kind=struct.unpack_from('<5I',data)
    if (magic,version,total,kind)!=(0x46546c67,2,len(data),0x4e4f534a):
        raise ValueError(f'{path} is not a supported GLB')
    doc=json.loads(data[20:20+length])
    offset=20+length
    size,binary_kind=struct.unpack_from('<2I',data,offset)
    if binary_kind!=0x004e4942 or len(doc['buffers'])!=1:
        raise ValueError('Expected one embedded GLB buffer')
    return doc,bytearray(data[offset+8:offset+8+size])


def sub(a,b):
    return tuple(x-y for x,y in zip(a,b))


def face_normal(a,b,c):
    x,y,z=sub(b,a)
    u,v,w=sub(c,a)
    vector=(y*w-z*v,z*u-x*w,x*v-y*u)
    norm=sqrt(sum(x*x for x in vector))
    return tuple(x/norm for x in vector)


def prism(outline,z_start,z_end):
    n=len(outline)
    points=[(x,y,z) for z in (z_start,z_end) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    rows=[]
    for face in faces:
        a,b,c=(points[i] for i in face[:3])
        normal=face_normal(a,b,c)
        for i in range(1,len(face)-1):
            rows.extend((points[j],normal) for j in (face[0],face[i],face[i+1]))
    return rows


def add_array(doc,blob,vecs,include_bounds=False):
    offset=len(blob)
    for vec in vecs:
        blob.extend(struct.pack('<3f',*vec))
    view=len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(blob)-offset,'target':34962})
    accessor={'bufferView':view,'componentType':5126,'count':len(vecs),'type':'VEC3'}
    if include_bounds:
        accessor.update(min=[min(v[i] for v in vecs) for i in range(3)],
                        max=[max(v[i] for v in vecs) for i in range(3)])
    doc['accessors'].append(accessor)
    return len(doc['accessors'])-1


def patch(source,output):
    doc,blob=read_glb(source)
    nodes=doc['nodes']
    original={node['name']:i for i,node in enumerate(nodes)}
    required={'Body','Mast','GarY','bumper_rear_graphite'}
    if not required.issubset(original):
        raise ValueError('The input is missing the expected GAR-Y chassis nodes')
    if original.keys() & {'RearMount','MastMount','FrontMount'}:
        raise ValueError('This GAR-Y already has fitting markers')

    def append_node(parent,**fields):
        nodes[parent].setdefault('children',[]).append(len(nodes))
        nodes.append(fields)
        return len(nodes)-1

    body,mast=original['Body'],original['Mast']
    # The supplied chassis ends at +0.420 m; its rear bumper reaches +0.465 m
    # at a lower elevation. The mating face here is flush with the backing plate.
    append_node(body,name='RearMount',translation=[0,.446,.450],rotation=[0,1,0,0])
    append_node(body,name='FrontMount',translation=[0,.343,-.476])
    append_node(mast,name='MastMount',translation=[0,.459,.035])

    corners=[(-.119,-.042),(.119,-.042),(.134,-.027),(.134,.027),
             (.119,.042),(-.119,.042),(-.134,.027),(-.134,-.027)]
    primitives=[]
    materials={m.get('name'):i for i,m in enumerate(doc['materials'])}

    def add_primitive(rows,role):
        points,normals=zip(*rows)
        pos=add_array(doc,blob,points,True)
        normal=add_array(doc,blob,normals)
        primitives.append({'attributes':{'POSITION':pos,'NORMAL':normal},'material':materials[role]})

    add_primitive(prism(corners,-.030,0.0),'dark_alloy')
    bolt_rows=[]
    for side in (-1,1):
        for lift in (-1,1):
            outline=[(side*.116+.007*cos(k*pi/4),lift*.027+.007*sin(k*pi/4)) for k in range(8)]
            bolt_rows.extend(prism(outline,0,.004))
    add_primitive(bolt_rows,'alloy')
    index=len(doc['meshes'])
    doc['meshes'].append({'name':'rear_hitch_backing_dark_alloy','primitives':primitives})
    append_node(body,name='rear_hitch_backing_dark_alloy',mesh=index,translation=[0,.446,.450])

    doc['buffers'][0]['byteLength']=len(blob)
    meta=json.dumps(doc,separators=(',',':'),ensure_ascii=True).encode()
    meta+=b' '*(-len(meta)%4)
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('wb') as out:
        out.write(struct.pack('<5I',0x46546c67,2,28+len(meta)+len(blob),len(meta),0x4e4f534a))
        out.write(meta)
        out.write(struct.pack('<2I',len(blob),0x004e4942))
        out.write(blob)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    patch(args.source,args.output)
