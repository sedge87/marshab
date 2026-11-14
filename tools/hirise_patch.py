"""Cut a patch of real yardangs from a HiRISE elevation model (DTM) for tools/generate_region.py.

The source is DTEED_061610_1895_061887_1895_A01.IMG ("Yardangs in Arabia Terra", 2 m a point, 51 MB), from
https://www.uahirise.org/PDS/DTM/ESP/ORB_061600_061699/ESP_061610_1895_ESP_061887_1895/ . Keep the download
out of git; only the patch it makes (assets/terrain/patches/yardangs_arabia.npz) is committed.

Usage: python tools/hirise_patch.py in.IMG out.npz preview.png [centre_x centre_y axis_degrees]
The committed patch was cut with: 1800 2300 -65 (chosen by eye from the preview: a dense stretch, its ridges
running up and to the right in the image).
"""
import re
import sys

import numpy as np
from PIL import Image


def read_dtm(path):
    head = open(path, 'rb').read(20000).decode('latin-1')
    def key(name):
        return re.search(r'^\s*' + re.escape(name) + r'\s*=\s*(\S+)', head, re.M).group(1)
    record = int(key('RECORD_BYTES')); first = int(key('^IMAGE')); lines = int(key('LINES')); samples = int(key('LINE_SAMPLES'))
    a = np.fromfile(path, dtype='<f4', count=lines * samples, offset=record * (first - 1)).reshape(lines, samples)
    a = a.astype(np.float64)
    a[a < -1e30] = np.nan
    return a

sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from dtm_read import read_dtm


def blur(a, r):
    out = a.copy()
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]; pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(out, pad, mode='edge'), axis=axis)
        hi = [slice(None), slice(None)]; lo = [slice(None), slice(None)]
        hi[axis] = slice(2 * r + 1, None); lo[axis] = slice(0, -2 * r - 1)
        out = (c[tuple(hi)] - c[tuple(lo)]) / (2 * r + 1)
    return out


a = read_dtm(sys.argv[1])
valid = np.isfinite(a)
fill = np.where(valid, a, np.nanmedian(a))
# The yardangs stand on a plain: the plain is the local low (a wide minimum, smoothed), the relief what stands over it.
small = fill[::4, ::4]
low = small.copy()
r = 20   # 160 m
for axis in (0, 1):
    stack = [np.roll(low, k, axis) for k in range(-r, r + 1, 2)]
    low = np.min(stack, axis=0)
for axis in (0, 1):   # and back up again (an opening), so a sloping plain isn't read low
    stack = [np.roll(low, k, axis) for k in range(-r, r + 1, 2)]
    low = np.max(stack, axis=0)
low = blur(blur(low, 12), 12)
base = np.asarray(Image.fromarray(low.astype(np.float32), 'F').resize((fill.shape[1], fill.shape[0]), Image.BILINEAR))
relief = np.clip(fill - base, 0.0, None) * valid
print('relief: max %.1f m, 99th %.1f, share over 3 m %.3f' % (relief.max(), np.percentile(relief[valid], 99), float((relief[valid] > 3).mean())))
# Dominant trend of the ridges (structure tensor of the relief).
gy, gx = np.gradient(blur(relief, 2), 2.0)
jxx, jyy, jxy = (gx * gx).sum(), (gy * gy).sum(), (gx * gy).sum()
theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy)          # direction of strongest gradient
axis = np.array([-np.sin(theta), np.cos(theta)])       # along the ridges (x, y in image pixels)
if axis[0] < 0:
    axis = -axis                                         # tails towards +x (up and to the right in the image)
print('ridge axis (image x, y):', axis.round(3), 'angle from +x %.1f deg' % np.degrees(np.arctan2(axis[1], axis[0])))
# Densest window, 1200 m along by 760 m across, searched on a coarse grid of centres.
L, W = 600, 380   # samples at 2 m
side = np.array([-axis[1], axis[0]])
uu, vv = np.meshgrid(np.arange(L) - L / 2, np.arange(W) - W / 2)
best = None
dense = blur((relief > 4.0).astype(float), 60)
for cy in range(500, a.shape[0] - 500, 60):
    for cx in range(500, a.shape[1] - 500, 60):
        sx = cx + uu[::12, ::12] * axis[0] + vv[::12, ::12] * side[0]; sy = cy + uu[::12, ::12] * axis[1] + vv[::12, ::12] * side[1]
        ix = sx.astype(int); iy = sy.astype(int)
        if ix.min() < 0 or iy.min() < 0 or ix.max() >= a.shape[1] or iy.max() >= a.shape[0] or not valid[iy, ix].all():
            continue
        score = dense[iy, ix].mean()
        if best is None or score > best[0]:
            best = (score, cx, cy)
print('best window centre', best)
_, cx, cy = best
if len(sys.argv) > 4:   # chosen by eye: centre x, y (source pixels) and the ridge axis angle (degrees from image +x, y down)
    cx, cy = float(sys.argv[4]), float(sys.argv[5])
    axis = np.array([np.cos(np.radians(float(sys.argv[6]))), np.sin(np.radians(float(sys.argv[6])))]); side = np.array([-axis[1], axis[0]])
relief = np.minimum(relief, 48.0)
sx = cx + uu * axis[0] + vv * side[0]; sy = cy + uu * axis[1] + vv * side[1]
x0 = np.floor(sx).astype(int); y0 = np.floor(sy).astype(int); fx = sx - x0; fy = sy - y0
patch = (relief[y0, x0] * (1 - fx) * (1 - fy) + relief[y0, x0 + 1] * fx * (1 - fy) + relief[y0 + 1, x0] * (1 - fx) * fy + relief[y0 + 1, x0 + 1] * fx * fy)
print('patch', patch.shape, 'max %.1f m' % patch.max(), 'share over 3 m %.3f' % float((patch > 3).mean()))
np.savez_compressed(sys.argv[2], relief=patch.astype(np.float16), spacing=2.0,
                    source='HiRISE DTM DTEED_061610_1895_061887_1895_A01 (yardangs in Arabia Terra), NASA/JPL-Caltech/UArizona/USGS; rows across the wind, columns along it')
g = np.gradient(patch, 2.0)
img = np.clip(0.5 + (-g[1] - g[0]) * 0.8, 0, 1) * 0.6 + 0.4 * patch / patch.max()
Image.fromarray((np.clip(img, 0, 1) * 255).astype('uint8')).save(sys.argv[3])
