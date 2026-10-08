"""Original tiny pixel material maps; no image or texture downloaded."""
from pathlib import Path
from PIL import Image
import random
random.seed(1826)
p=Path(__file__).parent
for name in ('roof','plaster','wood'):
    im=Image.new('RGB',(32,32))
    for y in range(32):
        for x in range(32):
            if name=='roof':
                row=y//8; seam=(x+(row%2)*8)%16
                v=202 if y%8==7 or seam==15 else (242 if y%8==0 else 228)
                if random.random()<.035: v-=10
            elif name=='plaster':
                v=244+random.choice((0,0,0,-8,-3,1))
            else:
                v=232+(5 if x%7==0 else -12 if x%7==6 else 0)
                if random.random()<.045: v-=18
            im.putpixel((x,y),(max(0,min(255,v)),)*3)
    im.save(p/(name+'_pixel.png'))
