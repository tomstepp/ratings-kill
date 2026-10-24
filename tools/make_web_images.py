#!/usr/bin/env python3
"""Build the website's images from a 320x180 title-screen capture:
web/title.png (the page's start screen) and web/og.png (1200x630 link preview).

Usage: python3 tools/make_web_images.py path/to/title_capture.png
(capture one with: Godot --path . -- --capture=DIR --every=100 --shots=1)
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAVY = (0x14, 0x1B, 0x33, 255)


def load(path):
    data = open(path, "rb").read()
    i, idat = 8, b""
    while i < len(data):
        n = struct.unpack(">I", data[i:i + 4])[0]
        kind, body = data[i + 4:i + 8], data[i + 8:i + 8 + n]
        i += 12 + n
        if kind == b"IHDR":
            w, h, _, ctype = struct.unpack(">IIBB", body[:10])
        elif kind == b"IDAT":
            idat += body
    bpp = {6: 4, 2: 3}[ctype]
    raw, stride, rows, prev, p = zlib.decompress(idat), w * bpp, [], bytearray(w * bpp), 0
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x:x + bpp]) + ((255,) if bpp == 3 else ()) for x in range(0, stride, bpp)])
        prev = line
    return w, h, rows


def save(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in r for v in px) for r in rows)

    def chunk(k, d):
        return struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main(src):
    w, h, rows = load(src)
    save(os.path.join(ROOT, "web", "title.png"), w, h, rows)
    # Link preview: the title screen at 3x, centered on the backdrop navy.
    W, H, S = 1200, 630, 3
    ox, oy = (W - w * S) // 2, (H - h * S) // 2
    out = [[NAVY] * W for _ in range(H)]
    for y in range(h * S):
        src_row = rows[y // S]
        out[oy + y][ox:ox + w * S] = [src_row[x // S] for x in range(w * S)]
    save(os.path.join(ROOT, "web", "og.png"), W, H, out)
    print("wrote web/title.png and web/og.png")


if __name__ == "__main__":
    main(sys.argv[1])
