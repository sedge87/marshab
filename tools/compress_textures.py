"""Shrink the game's model textures (22 Nov): lossless model textures become
lossy WebP (quality 0.8, normal maps 0.9), and the old 2048 px interior
furniture textures (mars_hq_v1) are capped at 1024 px.

The .import files are git-ignored, so new models from the asset packs come in
lossless again: run this after adding models, then let Godot re-import
(open the editor, or `godot --headless --path . --import`).

Terrain textures (assets/terrain) and materials are left alone.

Run from the project root:  python tools/compress_textures.py
"""
import os,re
changed=hq=0
for root,dirs,files in os.walk('assets'):
    if os.path.exists(os.path.join(root,'.gdignore')): dirs[:]=[]; continue
    r=root.replace(os.sep,'/')
    if r.startswith('assets/terrain') or r.startswith('assets/materials') or r.startswith('assets/audio'): continue
    for f in files:
        if not f.endswith(('.png.import','.jpg.import','.jpeg.import','.webp.import')): continue
        p=os.path.join(root,f)
        raw=open(p,'rb').read(); crlf=b'\r\n' in raw
        t=raw.decode('utf-8').replace('\r\n','\n')
        if '\ncompress/mode=0\n' in t:
            q='0.9' if 'normal' in f.lower() else '0.8'
            t=t.replace('\ncompress/mode=0\n','\ncompress/mode=1\n',1)
            t=re.sub(r'\ncompress/lossy_quality=[0-9.]+\n','\ncompress/lossy_quality=%s\n'%q,t,count=1)
            changed+=1
        elif r.startswith('assets/equipment/mars_hq_v1') and '\ncompress/mode=2\n' in t:
            t=re.sub(r'\nprocess/size_limit=\d+\n','\nprocess/size_limit=1024\n',t,count=1); hq+=1
        else: continue
        if crlf: t=t.replace('\n','\r\n')
        open(p,'w',encoding='utf-8',newline='').write(t)
print('lossy',changed,'hq halved',hq)
