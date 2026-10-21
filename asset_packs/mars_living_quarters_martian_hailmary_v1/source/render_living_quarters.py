from pathlib import Path
import json, sys, os
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent.parent
RENDER_SCRIPT=Path('/mnt/data/Mars_Habitat_Martian_HailMary_Style_Reference/source/render_models.py')
# Reuse renderer developed for the GLB library, omitting its automatic batch execution.
header=RENDER_SCRIPT.read_text().split('\n\nmodels = ')[0]
header=header.replace("elif view=='front':eye=[center[0]+.3*span,center[1]+.9*span,center[2]-2.75*span]", "elif view=='front':eye=[center[0]+.3*span,center[1]+.9*span,center[2]-2.75*span]\n elif view=='rear':eye=[center[0]+1.7*span,center[1]+1.05*span,center[2]+2.5*span]")
scope={'__file__':str(RENDER_SCRIPT),'__name__':'__render_utils__'}
exec(compile(header,str(RENDER_SCRIPT),'exec'),scope)
render=scope['render']
assets=json.loads((ROOT/'asset_manifest.json').read_text())
for a in assets:
 p=ROOT/'previews'/f"{a['id']}_main.png"
 render(str(ROOT/a['model']),str(p),width=820,height=740,view='main')
 if a['id'] in ('crew_bunk','locker','common_table'):
  p2=ROOT/'previews'/f"{a['id']}_front.png"
  render(str(ROOT/a['model']),str(p2),width=760,height=650,view='front')
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
small='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font=ImageFont.truetype(font_path,21)
smallfont=ImageFont.truetype(small,14)
canvas=Image.new('RGB',(1260,1110),(237,243,241))
d=ImageDraw.Draw(canvas)
d.text((36,20),'MARS HABITAT  /  LIVING QUARTERS',font=ImageFont.truetype(font_path,33),fill=(30,54,61))
d.text((36,65),'THE MARTIAN  +  PROJECT HAIL MARY    •    WHITE-COMPOSITE EQUIPMENT RESTYLE',font=ImageFont.truetype(small,19),fill=(70,99,109))
for i,a in enumerate(assets):
 x=20+(i%3)*415;y=112+(i//3)*494
 im=Image.open(ROOT/'previews'/f"{a['id']}_main.png").convert('RGB');im.thumbnail((393,400))
 canvas.paste(im,(x+(393-im.width)//2,y))
 d.text((x+14,y+406),a['id'].replace('_',' ').upper(),font=font,fill=(25,48,54))
 d.text((x+14,y+439),f"{a['triangles']:,} triangles  |  {a['mesh_groups']} groups",font=smallfont,fill=(80,105,112))
canvas.save(ROOT/'previews'/'living_quarters_contact_sheet.jpg',quality=91)
print('Contact sheet finished',flush=True)
