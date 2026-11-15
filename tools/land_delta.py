"""The sculpt layer's file (B5 step 6, docs/terrain-design.md §13 "As built"): height differences on the
region's 2 m grid, kept in tiles so only the edited parts are stored, gzipped. The same format is read and
written by scripts/land_delta.gd (MHLandDelta) in the Godot editor and the exported game, and the per-save
layer (C-phase) reuses it.

Layout, little-endian, the whole file gzipped:
    4 bytes   b"LDLT"
    u16       version (1)
    u32       size: grid points a side (3072)
    f32       spacing: metres between grid points (2.0)
    u16       tile: grid points a tile side (64)
    u32       tile count
    then for each tile:
        u16 tx, u16 tz            tile column and row (grid point = tx * tile + i)
        tile * tile float16       the height differences, row by row (z then x), metres

Usage:
    python tools/land_delta.py --info data/region_sculpt.landdelta
    python tools/land_delta.py --selftest
"""
import gzip
import struct
import sys

import numpy as np

MAGIC = b"LDLT"
VERSION = 1
TILE = 64
EPSILON = 0.005   # differences smaller than this (m) don't keep a tile


class LandDelta:
    def __init__(self, size, spacing=2.0, tile=TILE):
        self.size = int(size); self.spacing = float(spacing); self.tile = int(tile)
        self.tiles = {}   # (tx, tz) -> float32 array tile x tile

    @classmethod
    def from_array(cls, delta, spacing=2.0, tile=TILE):
        out = cls(delta.shape[0], spacing, tile)
        n = (out.size + tile - 1) // tile
        for tz in range(n):
            for tx in range(n):
                block = np.zeros((tile, tile), dtype=np.float32)
                part = delta[tz * tile:(tz + 1) * tile, tx * tile:(tx + 1) * tile]
                block[:part.shape[0], :part.shape[1]] = part
                if np.abs(block).max() > EPSILON:
                    out.tiles[(tx, tz)] = block
        return out

    def to_array(self):
        out = np.zeros((self.size, self.size), dtype=np.float32)
        t = self.tile
        for (tx, tz), block in self.tiles.items():
            part = out[tz * t:(tz + 1) * t, tx * t:(tx + 1) * t]
            part[:] = block[:part.shape[0], :part.shape[1]]
        return out

    def apply(self, h, keep_out=None):
        """Add the differences to heights `h` (size x size), except where `keep_out` (a mask, 1 = untouched:
        caves and the ground over them) says not to. Returns h."""
        d = self.to_array()
        if keep_out is not None:
            d *= 1.0 - np.clip(keep_out, 0.0, 1.0)
        h += d
        return h

    def to_bytes(self):
        head = MAGIC + struct.pack("<HIfHI", VERSION, self.size, self.spacing, self.tile, len(self.tiles))
        body = [struct.pack("<HH", tx, tz) + block.astype("<f2").tobytes() for (tx, tz), block in sorted(self.tiles.items())]
        return gzip.compress(head + b"".join(body), mtime=0)

    @classmethod
    def from_bytes(cls, data):
        raw = gzip.decompress(data)
        if raw[:4] != MAGIC:
            raise ValueError("not a .landdelta file")
        version, size, spacing, tile, count = struct.unpack_from("<HIfHI", raw, 4)
        if version != VERSION:
            raise ValueError(f".landdelta version {version} (this reads {VERSION})")
        out = cls(size, spacing, tile)
        at = 4 + struct.calcsize("<HIfHI")
        n = tile * tile * 2
        for _ in range(count):
            tx, tz = struct.unpack_from("<HH", raw, at); at += 4
            out.tiles[(tx, tz)] = np.frombuffer(raw[at:at + n], dtype="<f2").astype(np.float32).reshape(tile, tile); at += n
        return out


def read(path):
    with open(path, "rb") as f:
        return LandDelta.from_bytes(f.read())


def write(path, delta):
    with open(path, "wb") as f:
        f.write(delta.to_bytes())


def _selftest():
    rng = np.random.default_rng(1)
    d = np.zeros((300, 300), dtype=np.float32)
    d[10:40, 100:180] = rng.normal(0.0, 2.0, (30, 80))
    d[250:, 250:] = 3.25
    ld = LandDelta.from_array(d, 2.0)
    back = LandDelta.from_bytes(ld.to_bytes()).to_array()
    err = float(np.abs(back - d).max())
    assert len(ld.tiles) == 6, len(ld.tiles)   # only the edited tiles are kept
    assert err < 0.01, err                      # float16: millimetres
    h = np.ones_like(d); keep = np.zeros_like(d); keep[250:270, 250:270] = 1.0
    ld.apply(h, keep)
    assert abs(h[260, 260] - 1.0) < 1e-6 and abs(h[280, 280] - 4.25) < 0.01
    print(f"land_delta selftest: PASS ({len(ld.tiles)} tiles, worst error {err * 1000:.1f} mm)")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    elif "--info" in sys.argv:
        ld = read(sys.argv[sys.argv.index("--info") + 1])
        d = ld.to_array()
        print(f"{ld.size}^2 at {ld.spacing} m, {len(ld.tiles)} tiles of {ld.tile}; changes {d.min():.2f}..{d.max():.2f} m")
    else:
        print(__doc__)
