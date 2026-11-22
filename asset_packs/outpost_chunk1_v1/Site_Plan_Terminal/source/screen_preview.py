"""Draw the sample 16:9 site plan used in the renders."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys

image=Image.new('RGB',(1280,720),'#0c2025')
draw=ImageDraw.Draw(image)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
def font(size):
    return ImageFont.truetype(font_path,size)

mint='#afdfd9'
subtle='#83a8a7'
amber='#f4b975'
draw.rectangle((0,0,1279,95),fill='#112b31')
draw.line((36,95,1244,95),fill='#508483',width=2)
draw.text((38,29),'SITE PLAN',fill=mint,font=font(41))
draw.text((1245,40),'WALKER 1 / CORE',fill=subtle,font=font(24),anchor='ra')
for x in range(43,1026,31):
    draw.line((x,112,x,621),fill='#18383d',width=1)
for y in range(124,628,31):
    draw.line((30,y,995,y),fill='#18383d',width=1)
draw.rectangle((30,112,995,621),outline='#327171',width=2)
draw.rectangle((1018,112,1251,621),fill='#132e34',outline='#327171',width=2)
draw.text((1040,145),'LAYOUT',font=font(25),fill=mint)
for y,name,col in [(201,'Placed',mint),(256,'Planned',amber)]:
    draw.rounded_rectangle((1040,y,1064,y+24),radius=4,outline=col,width=3)
    draw.text((1083,y+2),name,font=font(18),fill=col)
draw.line((1038,316,1232,316),fill='#4e7474',width=2)
draw.text((1040,340),'Footprint',font=font(18),fill=subtle)
draw.text((1040,376),'CORE',font=font(28),fill=mint)
draw.text((1040,447),'1 cell',font=font(18),fill=amber)

def fitted(rect,label):
    x0,y0,x1,y1=rect
    draw.rounded_rectangle(rect,radius=18,outline=mint,fill='#204349',width=5)
    draw.rounded_rectangle((x0+10,y0+10,x1-10,y1-10),radius=10,outline='#518385',width=2)
    draw.text(((x0+x1)//2,(y0+y1)//2),label,font=font(23),fill=mint,anchor='mm')

def dashed(rect,step=24):
    a,b,c,d=rect
    for x in range(a,c,step):
        for y in (b,d):
            draw.line((x,y,min(c,x+12),y),fill=amber,width=3)
    for y in range(b,d,step):
        for x in (a,c):
            draw.line((x,y,x,min(d,y+12)),fill=amber,width=3)

# Top-down footprint with the core, working airlock and an expansion preview.
draw.rectangle((615,303,700,384),fill='#204349',outline=mint,width=4)
fitted((350,228,622,455),'CORE')
fitted((690,274,841,415),'AIRLOCK')
draw.rectangle((439,449,525,492),fill='#342e29')
dashed((434,455,531,492),20)
draw.rectangle((376,494,584,584),fill='#2c302d')
dashed((376,494,584,584))
draw.text((480,536),'EXPANSION',font=font(20),fill=amber,anchor='mm')
draw.polygon([(98,169),(83,199),(113,199)],fill=mint)
draw.text((98,139),'N',font=font(19),fill=mint,anchor='mm')
draw.line((40,652,1240,652),fill='#508483',width=2)
draw.text((43,675),'STRUCTURE VIEW',font=font(19),fill=subtle)
draw.text((1238,675),'1 CELL / GRID',font=font(19),fill=subtle,anchor='ra')
image.save(Path(sys.argv[1]))
