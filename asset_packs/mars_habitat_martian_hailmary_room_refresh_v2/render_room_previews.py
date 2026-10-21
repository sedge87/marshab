from pathlib import Path
import json, os
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent
source=Path('/mnt/data/Mars_Habitat_Martian_HailMary_Style_Reference/source/render_models.py').read_text()
header=source.split('\n\nmodels = ')[0]
module={'__file__':'/mnt/data/Mars_Habitat_Martian_HailMary_Style_Reference/source/render_models.py','__name__':'render_utils'}
exec(compile(header,'render_utils.py','exec'),module)
render=module['render']
assets=json.loads((ROOT/'asset_manifest.json').read_text())
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
font=ImageFont.truetype(FONT,24)
font_small=ImageFont.truetype(FONT,19)
for a in assets:
 out=ROOT/a['room']/'previews';out.mkdir(exist_ok=True)
 p=out/(a['id']+'.png')
 render(str(ROOT/a['glb']),str(p),width=820,height=710,view='main')
 a['preview']=str(p.relative_to(ROOT))
for room in ('hydroponics','life_support'):
 room_assets=[a for a in assets if a['room']==room]
 cols=3 if len(room_assets)>4 else 2
 tw,th=430,420
 rows=(len(room_assets)+cols-1)//cols
 canvas=Image.new('RGB',(cols*tw,rows*th+92),(237,242,241))
 dr=ImageDraw.Draw(canvas)
 title='HYDROPONICS' if room=='hydroponics' else 'LIFE SUPPORT'
 dr.text((24,24),title,fill=(27,49,55),font=ImageFont.truetype(FONT,31))
 dr.text((24,61),'The Martian + Project Hail Mary | Room review',fill=(72,99,108),font=ImageFont.truetype(FONT,16))
 for i,a in enumerate(room_assets):
  x=(i%cols)*tw;y=92+(i//cols)*th
  im=Image.open(ROOT/a['preview']).convert('RGB');im.thumbnail((tw-18,th-73))
  canvas.paste(im,(x+(tw-im.width)//2,y+8))
  name=a['id'].replace('_',' ').title()
  dr.text((x+16,y+th-55),name,fill=(22,44,50),font=font)
  dr.text((x+16,y+th-26),f"{a['triangles']:,} triangles · {a['mesh_groups']} mesh groups",fill=(75,98,106),font=font_small)
 dst=ROOT/room/'room_contact_sheet.jpg';canvas.save(dst,quality=91)
 print('CONTACT',dst,flush=True)
(ROOT/'asset_manifest.json').write_text(json.dumps(assets,indent=2))
