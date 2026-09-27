#!/usr/bin/env python3
"""Tiny PNG helper with no dependencies (the Mac has no Pillow): strips the alpha channel from an
8-bit RGBA PNG, or reports a file's size, colour type and whether any pixel is transparent.

  python3 pngtool.py info   <file.png>
  python3 pngtool.py opaque <in.png> <out.png>             # RGBA -> RGB; fails if any pixel is not opaque
  python3 pngtool.py crop   <in.png> <out.png> x y w h     # crop, then the same RGB conversion
  python3 pngtool.py rgba   <in.png> <out.png>             # RGB -> RGBA with every pixel opaque

Play Store art must not rely on transparency, and Quick Look always writes RGBA, so the render
script runs the feature graphic through `opaque` after cropping it. The store icon goes the other
way: Play asks for a 32-bit PNG, so `rgba` adds an alpha channel that is opaque everywhere.
"""
import struct
import sys
import zlib


def chunks(data):
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        yield kind, data[pos + 8:pos + 8 + length]
        pos += 12 + length


def read(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    idat, header = b"", None
    for kind, body in chunks(data):
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
    w, h, depth, ctype, _, _, interlace = header
    assert depth == 8 and interlace == 0, "only 8-bit non-interlaced PNGs are handled"
    bpp = {2: 3, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    pos = 0
    for _ in range(h):
        ftype, line = raw[pos], bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ftype == 1:
                line[i] = (line[i] + a) & 255
            elif ftype == 2:
                line[i] = (line[i] + b) & 255
            elif ftype == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    return w, h, bpp, rows


def write_rgb(path, w, h, rows):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + r for r in rows)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def write_rgba(path, w, h, rows):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + r for r in rows)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    cmd = sys.argv[1]
    w, h, bpp, rows = read(sys.argv[2])
    transparent = bpp == 4 and any(r[i] != 255 for r in rows for i in range(3, len(r), 4))
    if cmd == "info":
        print(f"{sys.argv[2]}: {w}x{h} {'RGBA' if bpp == 4 else 'RGB'}"
              f"{' with transparent pixels' if transparent else ', every pixel opaque'}")
        return
    if cmd == "crop":
        x, y, cw, ch = (int(v) for v in sys.argv[4:8])
        assert 0 <= x and 0 <= y and x + cw <= w and y + ch <= h, "crop rectangle is outside the image"
        rows = [r[x * bpp:(x + cw) * bpp] for r in rows[y:y + ch]]
        w, h = cw, ch
        transparent = bpp == 4 and any(r[i] != 255 for r in rows for i in range(3, len(r), 4))
    if cmd in ("opaque", "crop"):
        if transparent:
            sys.exit("refusing: the image has transparent pixels, so dropping alpha would change it")
        rgb = rows if bpp == 3 else [bytes(b for i, b in enumerate(r) if i % 4 != 3) for r in rows]
        write_rgb(sys.argv[3], w, h, rgb)
        print(f"wrote {sys.argv[3]}: {w}x{h} RGB")
        return
    if cmd == "rgba":
        if bpp == 4:
            rgba = rows
        else:
            rgba = [bytes(b for i in range(0, len(r), 3) for b in (r[i], r[i + 1], r[i + 2], 255)) for r in rows]
        write_rgba(sys.argv[3], w, h, rgba)
        print(f"wrote {sys.argv[3]}: {w}x{h} RGBA, every pixel opaque")
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
