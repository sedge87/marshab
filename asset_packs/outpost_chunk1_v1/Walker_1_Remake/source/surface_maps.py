"""Build tiled PBR maps for the Outpost One Walker 1."""
from pathlib import Path
import argparse

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, zoom


SIZE = 512
# Base, oxide dust, roughness, metalness, substrate, dust coverage.
ROLES = {
    'rover_white': ('D2CBB6', 'AF7957', .52, .05, 'enamel', .17),
    'orange': ('C76136', '9E7256', .50, .05, 'enamel', .19),
    'graphite': ('373A38', '9E7053', .67, .08, 'enamel', .29),
    'dark_alloy': ('4C5656', '9B6A50', .49, .72, 'metal', .23),
    'alloy': ('727C7A', '9E6D4F', .46, .78, 'metal', .15),
    'satin_steel': ('9B9F96', '946D56', .36, .82, 'metal', .09),
    'warm_panel': ('BDAA8C', '987458', .61, .10, 'enamel', .12),
    'slate_panel': ('5E6464','986748',.67,.12,'enamel',.20),
    'white_painted': ('C9C7B8', 'A67E5F', .54, .05, 'enamel', .18),
    'black_rubber': ('343734', '9C7457', .79, .01, 'rubber', .37),
}


def channels(code):
    return np.array([int(code[i:i+2], 16) for i in (0, 2, 4)], dtype=float)


def save(path, values):
    Image.fromarray(np.uint8(np.clip(values, 0, 255))).save(path, optimize=True)


def generate(out):
    out.mkdir(parents=True, exist_ok=True)
    for i, (role, (base, dust, rough, metal, substrate, coverage)) in enumerate(ROLES.items()):
        rng = np.random.default_rng(1801+i)

        def field(grid):
            vals = np.pad(rng.random((grid, grid)), 1, mode='wrap')
            step = SIZE//grid
            return zoom(vals, step, order=3, grid_mode=True, mode='grid-wrap')[step:step+SIZE, step:step+SIZE]

        broad, medium, small, fine = field(8), field(32), field(128), rng.random((SIZE, SIZE))
        oxide = np.clip((broad*.58 + medium*.32 + small*.10 - .29)*1.7, 0, 1)*coverage
        height = (small-.5)*.055 + (medium-.5)*.074 + (fine-.5)*.009
        tint = (small-.5)*9 + (medium-.5)*15 + (fine-.5)*3
        scratch_map = Image.new('L', (SIZE, SIZE))
        draw = ImageDraw.Draw(scratch_map)
        for j in range(175 if substrate == 'metal' else 74):
            x,y = rng.integers(0,SIZE,2)
            dx = rng.uniform(6,53)
            dy = rng.normal(0,1.9 if substrate == 'metal' else 8)
            draw.line((x,y,x+dx,y+dy), fill=int(rng.uniform(15,138)), width=1 if j%9 else 2)
        scratches = np.array(scratch_map, dtype=float)/255
        height -= scratches*.034
        tint += scratches*(31 if substrate == 'metal' else 24)
        if substrate == 'metal':
            brush = gaussian_filter(fine,(.62,8),mode='wrap')
            height += (brush-.5)*.29
            tint += (brush-.5)*72
        elif substrate == 'rubber':
            pitting = np.clip((small-.55)*1.8,0,1)
            tint -= pitting*16
            height -= pitting*.08
        rgb = channels(base)*(1-oxide[...,None]) + channels(dust)*oxide[...,None] + tint[...,None]
        dx = (np.roll(height,-1,1)-np.roll(height,1,1))*4.6
        dy = (np.roll(height,-1,0)-np.roll(height,1,0))*4.6
        normal = np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
        normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
        ao = 1 - (small*.56+medium*.44)*.18
        orm = np.stack((ao,rough+(broad-.5)*.18+oxide*.32-scratches*.17,metal*(1-oxide*.73)),axis=-1)
        save(out / f'{role}_color.png',rgb)
        save(out / f'{role}_normal.png',(normal*.5+.5)*255)
        save(out / f'{role}_orm.png',orm*255)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    generate(parser.parse_args().output)
