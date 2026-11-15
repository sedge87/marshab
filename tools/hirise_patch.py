"""Cut a patch of real Mars from a HiRISE elevation model (DTM) for tools/generate_region.py.

Downloads stay out of git (keep them in .claude_tmp/dtm/); only the patches (assets/terrain/patches/*.npz) are
committed. Credit: NASA/JPL-Caltech/UArizona (HiRISE), with the DTM's id in each patch's `source`.

Usage:
  python tools/hirise_patch.py in.IMG out.npz preview.png [centre_x centre_y axis_degrees]      (the yardangs, as cut)
  python tools/hirise_patch.py --dtm in.IMG --out out.npz --preview p.png [options]

Options:
  --mode relief|detrend   relief: what stands over the local low ground (landforms on a plain: yardangs, raised
                          riverbeds); detrend: the whole relief with the regional slope taken off (a glacier, a scarp)
  --size L W              the patch in metres, along and across its axis (default 1200 760)
  --centre X Y            its centre in source pixels (default: the densest window of relief is searched for)
  --axis DEG              its long axis, degrees from the image's +x (y down) (default: the ridges' own trend)
  --spacing M             metres a point in the patch (default 2)
  --clip M                cap the relief at this many metres (default 48)
  --low R                 relief mode: the radius (m) of the local low ground (default 160)
  --trend R               detrend mode: the radius (m) of the regional slope taken off (default 400)
  --name TEXT             what the DTM shows, for the patch's credit

The yardang patch (assets/terrain/patches/yardangs_arabia.npz) was cut from DTEED_061610_1895_061887_1895_A01.IMG
("Yardangs in Arabia Terra", 2 m a point) with: 1800 2300 -65.
"""
import re
import sys

import numpy as np
from PIL import Image


def read_dtm(path):
    head = open(path, 'rb').read(30000).decode('latin-1')

    def key(name):
        return re.search(r'^\s*' + re.escape(name) + r'\s*=\s*(\S+)', head, re.M).group(1)
    record = int(key('RECORD_BYTES')); first = int(key('^IMAGE')); lines = int(key('LINES')); samples = int(key('LINE_SAMPLES'))
    scale = float(re.search(r'MAP_SCALE\s*=\s*([\d.]+)', head).group(1))
    a = np.fromfile(path, dtype='<f4', count=lines * samples, offset=record * (first - 1)).reshape(lines, samples)
    a = a.astype(np.float64)
    a[a < -1e30] = np.nan
    return a, scale


def blur(a, r):
    out = a.copy()
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]; pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(out, pad, mode='edge'), axis=axis)
        hi = [slice(None), slice(None)]; lo = [slice(None), slice(None)]
        hi[axis] = slice(2 * r + 1, None); lo[axis] = slice(0, -2 * r - 1)
        out = (c[tuple(hi)] - c[tuple(lo)]) / (2 * r + 1)
    return out


def opt(name, n=1, default=None, kind=float):
    if name not in sys.argv:
        return default
    k = sys.argv.index(name)
    vals = [kind(v) for v in sys.argv[k + 1:k + 1 + n]]
    return vals[0] if n == 1 else vals


def main():
    legacy = '--dtm' not in sys.argv
    if legacy:   # the original call: in out preview [cx cy axis]
        dtm, out, preview = sys.argv[1], sys.argv[2], sys.argv[3]
        centre = (float(sys.argv[4]), float(sys.argv[5])) if len(sys.argv) > 6 else None
        axis_deg = float(sys.argv[6]) if len(sys.argv) > 6 else None
        mode, size, spacing, clip, low_r, trend_r = 'relief', (1200.0, 760.0), 2.0, 48.0, 160.0, 400.0
        name = 'DTEED_061610_1895_061887_1895_A01 (yardangs in Arabia Terra)'
    else:
        dtm, out, preview = opt('--dtm', kind=str), opt('--out', kind=str), opt('--preview', kind=str)
        centre = tuple(opt('--centre', 2)) if '--centre' in sys.argv else None
        axis_deg = opt('--axis')
        mode = opt('--mode', kind=str, default='relief')
        size = tuple(opt('--size', 2, default=[1200.0, 760.0]))
        spacing = opt('--spacing', default=2.0); clip = opt('--clip', default=48.0)
        low_r = opt('--low', default=160.0); trend_r = opt('--trend', default=400.0)
        name = opt('--name', kind=str, default=dtm.replace('\\', '/').split('/')[-1])
    a, scale = read_dtm(dtm)
    print(f'DTM {a.shape[1]} x {a.shape[0]} at {scale:.2f} m')
    valid = np.isfinite(a)
    fill = np.where(valid, a, np.nanmedian(a))
    k4 = 4   # work the broad ground out on a grid 4 points coarser
    small = fill[::k4, ::k4]
    if mode == 'relief':
        # The plain is the local low (a wide minimum, smoothed), the relief what stands over it.
        r = max(2, int(low_r / (scale * k4)))
        low = small.copy()
        for ax in (0, 1):
            low = np.min([np.roll(low, k, ax) for k in range(-r, r + 1, 2)], axis=0)
        for ax in (0, 1):   # and back up again (an opening), so a sloping plain isn't read low
            low = np.max([np.roll(low, k, ax) for k in range(-r, r + 1, 2)], axis=0)
        low = blur(blur(low, max(1, int(r * 0.6))), max(1, int(r * 0.6)))
        base = np.asarray(Image.fromarray(low.astype(np.float32), 'F').resize((fill.shape[1], fill.shape[0]), Image.BILINEAR))
        relief = np.clip(fill - base, 0.0, None) * valid
    else:
        r = max(2, int(trend_r / (scale * k4)))
        trend = blur(blur(small, r), r)
        base = np.asarray(Image.fromarray(trend.astype(np.float32), 'F').resize((fill.shape[1], fill.shape[0]), Image.BILINEAR))
        relief = (fill - base) * valid
    print('relief: max %.1f m, 99th %.1f' % (np.nanmax(relief), np.percentile(relief[valid], 99)))
    # The trend of the ridges (structure tensor of the relief), unless given.
    gy, gx = np.gradient(blur(relief, 2), scale)
    jxx, jyy, jxy = (gx * gx).sum(), (gy * gy).sum(), (gx * gy).sum()
    theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy)
    axis = np.array([-np.sin(theta), np.cos(theta)])
    if axis[0] < 0:
        axis = -axis
    if axis_deg is not None:
        axis = np.array([np.cos(np.radians(axis_deg)), np.sin(np.radians(axis_deg))])
    side = np.array([-axis[1], axis[0]])
    print('axis (image x, y):', axis.round(3), 'angle from +x %.1f deg' % np.degrees(np.arctan2(axis[1], axis[0])))
    L = int(size[0] / spacing); W = int(size[1] / spacing)
    step = spacing / scale   # source pixels per patch point
    uu, vv = np.meshgrid((np.arange(L) - L / 2) * step, (np.arange(W) - W / 2) * step)
    if centre is None:
        # The densest window of relief, searched on a coarse grid of centres.
        dense = blur((relief > 4.0).astype(float), int(120 / scale))
        best = None
        margin = int(max(L, W) * step * 0.75) + 2
        for cy in range(margin, a.shape[0] - margin, max(1, int(120 / scale))):
            for cx in range(margin, a.shape[1] - margin, max(1, int(120 / scale))):
                sx = cx + uu[::12, ::12] * axis[0] + vv[::12, ::12] * side[0]; sy = cy + uu[::12, ::12] * axis[1] + vv[::12, ::12] * side[1]
                ix = sx.astype(int); iy = sy.astype(int)
                if ix.min() < 0 or iy.min() < 0 or ix.max() >= a.shape[1] or iy.max() >= a.shape[0] or not valid[iy, ix].all():
                    continue
                score = dense[iy, ix].mean()
                if best is None or score > best[0]:
                    best = (score, cx, cy)
        if best is None:
            sys.exit('no window of that size fits inside the DTM: give --centre or a smaller --size')
        print('best window centre', best)
        centre = (best[1], best[2])
    cx, cy = centre
    relief = np.nan_to_num(relief)
    if mode == 'relief':
        relief = np.minimum(relief, clip)
    sx = cx + uu * axis[0] + vv * side[0]; sy = cy + uu * axis[1] + vv * side[1]
    if sx.min() < 0 or sy.min() < 0 or sx.max() >= a.shape[1] - 1 or sy.max() >= a.shape[0] - 1:
        sys.exit('the patch runs off the DTM: move --centre or shrink --size')
    x0 = np.floor(sx).astype(int); y0 = np.floor(sy).astype(int); fx = sx - x0; fy = sy - y0
    patch = (relief[y0, x0] * (1 - fx) * (1 - fy) + relief[y0, x0 + 1] * fx * (1 - fy) + relief[y0 + 1, x0] * (1 - fx) * fy + relief[y0 + 1, x0 + 1] * fx * fy)
    if mode == 'detrend':   # the patch's own ground at 0, the relief either side of it capped
        patch = np.clip(patch - np.median(patch), -clip, clip)
    print('patch', patch.shape, 'max %.1f m' % patch.max(), 'share over 3 m %.3f' % float((patch > 3).mean()))
    np.savez_compressed(out, relief=patch.astype(np.float16), spacing=spacing,
                        source=f'HiRISE DTM {name}, NASA/JPL-Caltech/UArizona/USGS; rows across the axis, columns along it; '
                               f'mode {mode}, centre {cx:.0f},{cy:.0f} px, axis {np.degrees(np.arctan2(axis[1], axis[0])):.1f} deg')
    g = np.gradient(patch, spacing)
    img = np.clip(0.5 + (-g[1] - g[0]) * 0.8, 0, 1) * 0.6 + 0.4 * (patch - patch.min()) / max(np.ptp(patch), 1e-3)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype('uint8')).save(preview)


if __name__ == '__main__':
    main()
