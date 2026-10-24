#!/usr/bin/env python3
"""Generate every sprite, tile and the pixel font for Ratings Kill.

All art is drawn from one fixed 16-color palette, so everything matches.
Pure standard library: run `python3 tools/gen_art.py` from the project root.
Sprites are written as horizontal strips of equal-size frames.
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
TILES = os.path.join(ROOT, "assets", "tiles")
FONTS = os.path.join(ROOT, "assets", "fonts")

# The one palette. Index -> RGB. Keep in sync with scripts/autoload/art.gd.
PALETTE = [
    (0x0B, 0x0B, 0x14),  # 0 K black / outline
    (0x22, 0x20, 0x3B),  # 1 N deep navy
    (0x3C, 0x3A, 0x63),  # 2 S slate
    (0x6C, 0x6F, 0x9E),  # 3 P dusty blue
    (0xB3, 0xBB, 0xD9),  # 4 L pale steel
    (0xF4, 0xF1, 0xE8),  # 5 W off-white
    (0xF2, 0xC1, 0x4E),  # 6 Y gold
    (0xE0, 0x7A, 0x32),  # 7 O orange
    (0xB8, 0x32, 0x40),  # 8 R red
    (0x5E, 0x1F, 0x3A),  # 9 M maroon
    (0x2F, 0x7A, 0x4A),  # 10 G green
    (0x8F, 0xD1, 0x4F),  # 11 g lime
    (0x2C, 0x6E, 0x85),  # 12 T teal
    (0x66, 0xD6, 0xE8),  # 13 C cyan
    (0xC7, 0x5B, 0xB0),  # 14 V magenta
    (0xF0, 0xB0, 0x8C),  # 15 F peach
]
CH = {"K": 0, "N": 1, "S": 2, "P": 3, "L": 4, "W": 5, "Y": 6, "O": 7,
      "R": 8, "M": 9, "G": 10, "g": 11, "T": 12, "C": 13, "V": 14, "F": 15}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[-1] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return -1

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def ascii(self, rows, ox=0, oy=0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in CH:
                    self.put(ox + x, oy + y, CH[ch])

    def outline(self, c=0):
        """Wrap every filled pixel in a 1px outline (4-neighborhood)."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != -1:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    v = self.get(x + dx, y + dy)
                    if v != -1 and v != c:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = c
        return self

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                v = other.px[y][x]
                if v != -1:
                    self.put(ox + x, oy + y, v)


def sprite(w, h, rows, outline=True, oy=0, ox=0):
    c = Canvas(w, h)
    c.ascii(rows, ox, oy)
    if outline:
        c.outline()
    return c


def strip(frames):
    w = sum(f.w for f in frames)
    h = max(f.h for f in frames)
    out = Canvas(w, h)
    x = 0
    for f in frames:
        out.blit(f, x, 0)
        x += f.w
    return out


def save(canvas, path):
    raw = bytearray()
    for row in canvas.px:
        raw.append(0)
        for v in row:
            if v == -1:
                raw += b"\x00\x00\x00\x00"
            else:
                r, g, b = PALETTE[v]
                raw += bytes((r, g, b, 255))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", canvas.w, canvas.h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


# ---------------------------------------------------------------- Rex (16x32)

REX_HEAD = [
    "",
    ".....YYYYY......",
    "....YYYYYYYY....",
    "....YYYYYYYYY...",
    "....YYFFFFFF....",
    "....YFFFFFFFF...",
    "....FFKKKKKKK...",
    "....FFFKCKKCK...",
    "....FFFFFFFFF...",
    ".....FFFFFKKF...",
    ".....FFFFFFF....",
    "......FFFF......",
]
REX_TORSO = [
    ".....RRWWRR.....",
    "....RRRRWRRRR...",
    "....RRRRWRRRR...",
    "....RRRRWRRRR...",
    "....RRRRWRRRR...",
    "....RRRRWRRRFSSS",
    "....RRRRRRRRFSSC",
    "....MMMYYMMM.SS.",
    "....TTTTTTTT....",
]
REX_LEGS = {
    "stand": [
        "....TTTTTTTT....",
        "....TTT..TTT....",
        "....TTT..TTT....",
        "....TTT..TTT....",
        "....TTT..TTT....",
        "....TTT..TTT....",
        "....NNN..NNN....",
        "...NNNN..NNNN...",
    ],
    "stride": [
        "....TTTTTTTT....",
        "...TTT...TTTT...",
        "..TTT.....TTT...",
        "..TT.......TTT..",
        ".TTT.......TTT..",
        ".TT.........TT..",
        "NNN.........NNN.",
        "NN..........NNNN",
    ],
    "pass": [
        "....TTTTTTTT....",
        ".....TTTTTT.....",
        ".....TTT.TTT....",
        ".....TTT..TTT...",
        ".....TTT..NNN...",
        ".....TTT..NN....",
        ".....NNN........",
        ".....NNNN.......",
    ],
    "stride2": [
        "....TTTTTTTT....",
        "...TTT..TTTT....",
        "...TTT...TTT....",
        "..TTT....TTT....",
        "..TTT.....TTT...",
        "..TT......TTT...",
        ".NNN......NNN...",
        ".NN.......NNNN..",
    ],
    "jump": [
        "....TTTTTTTT....",
        "...TTTT.TTTTT...",
        "...TTT....TTT...",
        "..NNN....TTT....",
        "..NNN....NNNN...",
        "................",
        "................",
        "................",
    ],
    "fall": [
        "....TTTTTTTT....",
        "...TTT...TTT....",
        "...TTT....TTT...",
        "..TTT.....TTT...",
        "..TTT......TTT..",
        "..NNN......NNN..",
        ".NNNN......NNNN.",
        "................",
    ],
}


def rex_frame(legs, bob=0, arms_up=False):
    c = Canvas(16, 32)
    c.ascii(REX_HEAD, 0, bob)
    torso = list(REX_TORSO)
    if arms_up:
        torso[5] = "....RRRRWRRR...."
        torso[6] = "....RRRRRRRR...."
        torso[7] = "....MMMYYMMM...."
        c.ascii(["...F........F...", "...R........R..."], 0, 10 + bob)
    c.ascii(torso, 0, 12 + bob)
    c.ascii(REX_LEGS[legs], 0, 21 + bob)
    return c.outline()


def gen_rex():
    frames = [
        rex_frame("stand"),            # 0 idle a
        rex_frame("stand", 1),         # 1 idle b (breathing)
        rex_frame("stride"),           # 2 run
        rex_frame("pass", 1),          # 3 run
        rex_frame("stride2"),          # 4 run
        rex_frame("pass", 1),          # 5 run
        rex_frame("jump"),             # 6 jump
        rex_frame("fall"),             # 7 fall
        rex_frame("fall", 0, True),    # 8 hurt
    ]
    save(strip(frames), os.path.join(SPRITES, "rex.png"))


# ---------------------------------------------------------------- Boom (14x14)

def gen_boom():
    body = [
        "",
        "",
        "......SS......",
        "....PPPPPP....",
        "...PPLLPPPR...",
        "..PPPPPCCCC...",
        "..PPPPCWCCCC..",
        "..PPPPCCCCCC..",
        "..PPPPPCCCC...",
        "...PPPPPPPP...",
        "....SSSSSS....",
    ]
    a = Canvas(14, 14)
    a.ascii(["..LLLL..LLLL.."] + body[1:])
    b = Canvas(14, 14)
    b.ascii([".....LLLL....."] + body[1:])
    save(strip([a.outline(), b.outline()]), os.path.join(SPRITES, "boom.png"))


# ---------------------------------------------------------- Rat drone (16x14)

def gen_rat():
    walk_a = [
        "",
        "",
        "",
        "...........LL...",
        "..........PPP...",
        "....PPPPPPPPPRP.",
        "..PPPPPPPPPPPPPS",
        "S.PPLLLLPPPPPPP.",
        ".SPPPPPPPPPPPP..",
        "..SPPPPPPPPPP...",
        "...SS.S...S.S...",
        "",
    ]
    walk_b = list(walk_a)
    walk_b[10] = "....S.SS..SS....".replace(".", ".")
    walk_b[7] = ".SPPLLLLPPPPPPP."
    walk_b[8] = "S.PPPPPPPPPPPP.."
    squashed = [
        "", "", "", "", "", "", "", "",
        "..........PRP...",
        "..PPPPPPPPPPPPP.",
        "SPPLLLLLPPPPPPPS",
        "",
    ]
    frames = [sprite(16, 14, walk_a), sprite(16, 14, walk_b), sprite(16, 14, squashed)]
    save(strip(frames), os.path.join(SPRITES, "rat.png"))


# ---------------------------------------------------------- Spark bot (16x16)

def gen_spark():
    base = [
        "",
        "",
        "",
        "",
        "",
        ".......TT.......",
        "......TTTT......",
        ".....SPPPPS.....",
        "....SPPPPPPS....",
        "...SPPRRRPPPS...",
        "...SPPRWRPPPS...",
        "...SPPPPPPPPS...",
        "..SSSSSSSSSSSS..",
        "..PLPLPLPLPLPL..",
        "..SSSSSSSSSSSS..",
    ]
    a = sprite(16, 16, base[:3] + ["......C..C......", ".......CC......."] + base[5:])
    b = sprite(16, 16, base[:3] + [".......C..C.....", "......CC........"] + base[5:])
    fire = list(base)
    fire[2] = ".....W.CC.W....."
    fire[3] = "......WCCW......"
    fire[4] = ".......WW......."
    fire[10] = "...SPPRWWPPPS..."
    c = sprite(16, 16, fire)
    save(strip([a, b, c]), os.path.join(SPRITES, "spark.png"))


# --------------------------------------------------------------- Projectiles

def gen_bolts():
    p = Canvas(10, 6)
    p.ascii(["", ".CCCCCWW.", ".CCWWWWWW", ".CCCCCWW."])
    save(p.outline(), os.path.join(SPRITES, "bolt.png"))
    e = Canvas(8, 8)
    e.ascii(["", "..VV...", ".VWWV..", ".VWWV..", "..VV..."], 0, 1)
    save(e.outline(), os.path.join(SPRITES, "enemy_bolt.png"))


# ------------------------------------------------------------------- Pickups

def gen_pickups():
    soda = sprite(12, 14, [
        "",
        "....LLL.....",
        "...RRRRR....",
        "...RWWWR....",
        "...RRRRR....",
        "...RWRWR....",
        "...RRRRR....",
        "...RYYYR....",
        "...RRRRR....",
        "...RRRRR....",
        "....LLL.....",
    ], ox=1)
    burger = sprite(14, 14, [
        "",
        "",
        "....OOOOO.....",
        "...OOYOOYO....",
        "..OOOOOOOOO...",
        "..gGgGgGgGg...",
        "..RRRRRRRRR...",
        "..MMMMMMMMM...",
        "..YYYYYYYYY...",
        "...OOOOOOO....",
    ])
    chip = sprite(14, 14, [
        "",
        "..L.L.L.L.....",
        ".GGGGGGGGG....",
        "LGgggggggGL...",
        ".GggYYgggG....",
        "LGggYgggGGL...",
        ".GgYYYYggG....",
        "LGgggYggGGL...",
        ".GggYYgggG....",
        "LGgggggggGL...",
        ".GGGGGGGGG....",
        "..L.L.L.L.....",
    ], ox=1)
    token = sprite(12, 12, [
        "",
        "....YYYY....",
        "...YOOOOY...",
        "..YOVVVVOY..",
        "..YOVCCVOY..",
        "..YOVCCVOY..",
        "..YOVVVVOY..",
        "...YOOOOY...",
        "....YYYY....",
    ])
    save(strip([soda, burger, chip, token]), os.path.join(SPRITES, "pickups.png"))

    # Keycards: red, blue, yellow (each 14x14)
    cards = []
    for col in ("R", "T", "Y"):
        rows = [
            "",
            "",
            "",
            "..XXXXXXXXXX..",
            "..XWWXXXXXXX..",
            "..XWWXXLLLXX..",
            "..XXXXXXXXXX..",
            "..XKKKKKKKKX..",
            "..XXXXXXXXXX..",
        ]
        cards.append(sprite(14, 14, [r.replace("X", col) for r in rows]))
    save(strip(cards), os.path.join(SPRITES, "keycards.png"))


# ------------------------------------------------------------------- Objects

def gen_objects():
    crate = Canvas(16, 16)
    crate.rect(0, 0, 16, 16, CH["O"])
    crate.rect(0, 0, 16, 1, CH["K"])
    crate.rect(0, 15, 16, 1, CH["K"])
    crate.rect(0, 0, 1, 16, CH["K"])
    crate.rect(15, 0, 1, 16, CH["K"])
    crate.rect(1, 1, 14, 2, CH["M"])
    crate.rect(1, 13, 14, 2, CH["M"])
    for i in range(1, 15):
        crate.put(i, i, CH["M"])
        crate.put(i, 15 - i, CH["M"])
    crate.put(2, 4, CH["Y"])
    crate.put(3, 5, CH["Y"])
    save(crate, os.path.join(SPRITES, "crate.png"))

    def tv_block(active):
        c = Canvas(16, 16)
        frame = "V" if active else "S"
        screen = "C" if active else "N"
        c.rect(0, 0, 16, 16, CH["K"])
        c.rect(1, 1, 14, 14, CH[frame])
        c.rect(3, 3, 10, 8, CH[screen])
        c.rect(2, 12, 2, 2, CH["K"])
        c.rect(12, 12, 2, 2, CH["K"])
        if active:
            c.ascii([
                ".WWW.",
                "W...W",
                "...W.",
                "..W..",
                ".....",
                "..W..",
            ], 6, 4)
        return c
    save(strip([tv_block(True), tv_block(False)]), os.path.join(SPRITES, "tvblock.png"))

    # Doors 16x32: red, blue, yellow, then exit
    doors = []
    for col in ("R", "T", "Y"):
        d = Canvas(16, 32)
        d.rect(0, 0, 16, 32, CH["K"])
        d.rect(1, 1, 14, 31, CH["S"])
        d.rect(2, 2, 12, 29, CH["P"])
        d.rect(2, 8, 12, 3, CH[col])
        d.rect(2, 22, 12, 3, CH[col])
        d.rect(6, 14, 4, 5, CH["K"])
        d.rect(7, 15, 2, 2, CH[col])
        d.rect(7, 17, 2, 1, CH[col])
        for y in range(3, 30, 4):
            d.put(3, y, CH["L"])
            d.put(12, y, CH["L"])
        doors.append(d)
    ex = Canvas(16, 32)
    ex.rect(0, 0, 16, 32, CH["K"])
    ex.rect(1, 9, 14, 23, CH["S"])
    ex.rect(3, 11, 10, 21, CH["N"])
    ex.rect(1, 1, 14, 7, CH["G"])
    ex.ascii([
        "gggg.g.g.ggg.ggg",
        "g.....g...g...g.",
        "ggg...g...g...g.",
        "g.....g...g...g.",
        "gggg.g.g.ggg..g.",
    ], 0, 2)
    ex.rect(10, 20, 2, 2, CH["Y"])
    doors.append(ex)
    save(strip(doors), os.path.join(SPRITES, "doors.png"))

    sw_off = sprite(16, 16, [
        "", "", "", "", "",
        "..R.............",
        "...R............",
        "....R...........",
        ".....R..........",
        "......R.........",
        "....SSSSSSS.....",
        "...SPPPPPPPS....",
        "...SPPPPPPPS....",
        "...SSSSSSSSS....",
    ], ox=1)
    sw_on = sprite(16, 16, [
        "", "", "", "", "",
        "..........g.....",
        ".........g......",
        "........g.......",
        ".......g........",
        "......g.........",
        "....SSSSSSS.....",
        "...SPPPPPPPS....",
        "...SPgPPPPPS....",
        "...SSSSSSSSS....",
    ], ox=1)
    save(strip([sw_off, sw_on]), os.path.join(SPRITES, "switch.png"))

    sponsor = Canvas(16, 16)
    sponsor.rect(0, 0, 16, 16, CH["K"])
    sponsor.rect(1, 1, 14, 14, CH["V"])
    sponsor.rect(1, 6, 14, 4, CH["Y"])
    sponsor.rect(6, 1, 4, 14, CH["Y"])
    sponsor.rect(7, 7, 2, 2, CH["W"])
    save(sponsor, os.path.join(SPRITES, "sponsor_crate.png"))

    chute = sprite(26, 14, [
        "",
        ".......WWWWWWWWWWW.......",
        ".....WWVVVWWWWWVVVWW.....",
        "....WVVVVVWWWWWVVVVVW....",
        "...WVVVVVVWWWWWVVVVVVW...",
        "...W.L.....L.L.....L.W...",
        ".....L.....L.L.....L.....",
        "......L....L.L....L......",
        ".......L...L.L...L.......",
        "........L..L.L..L........",
        ".........L.L.L.L.........",
        "..........LLLLL..........",
    ], outline=False)
    save(chute, os.path.join(SPRITES, "chute.png"))

    light = sprite(16, 16, [
        "",
        ".......SS.......",
        ".......SS.......",
        ".....SSSSSS.....",
        "....SPPPPPPS....",
        "...SPPPPPPPPS...",
        "...SPPPPPPPPS...",
        "...SYYYYYYYYS...",
        "...YWWWWWWWWY...",
        "....YYYYYYYY....",
    ])
    save(light, os.path.join(SPRITES, "stage_light.png"))


# ----------------------------------------------------------------- Portraits

def gen_portraits():
    show = Canvas(24, 24)
    show.rect(2, 3, 20, 17, CH["K"])
    show.rect(3, 4, 18, 15, CH["V"])
    show.rect(5, 6, 14, 11, CH["W"])
    show.ascii([
        "..KK....KK..",
        "..KK....KK..",
        "............",
        ".K........K.",
        "..K......K..",
        "...KKKKKK...",
    ], 6, 8)
    show.rect(6, 1, 1, 3, CH["L"])
    show.rect(17, 1, 1, 3, CH["L"])
    show.put(5, 0, CH["R"])
    show.put(18, 0, CH["R"])
    show.rect(8, 20, 8, 2, CH["S"])
    show.rect(6, 22, 12, 1, CH["S"])
    boom = Canvas(24, 24)
    boom.ascii([
        "",
        "",
        "...LLLLLL....LLLLLL.....",
        ".........SSSS...........",
        "......PPPPPPPPPP........",
        ".....PPLLPPPPPPPPR......",
        "....PPPPPPPPCCCCCC......",
        "....PPPPPPPCCCCCCCC.....",
        "....PPPPPPCCWWCCCCCC....",
        "....PPPPPPCCWWCCCCCC....",
        "....PPPPPPCCCCCCCCCC....",
        "....PPPPPPPCCCCCCCC.....",
        "....PPPPPPPPCCCCCC......",
        ".....PPPPPPPPPPPPP......",
        "......PPPPPPPPPPP.......",
        ".......SSSSSSSSS........",
    ], 0, 3)
    boom.outline()
    rex = Canvas(24, 24)
    rex.ascii([
        "",
        "......YYYYYYYY..........",
        ".....YYYYYYYYYYY........",
        "....YYYYYYYYYYYYY.......",
        "....YYYYYYYYYYYYYY......",
        "....YYYFFFFFFFFFF.......",
        "....YYFFFFFFFFFFFF......",
        "....YFFFFFFFFFFFFF......",
        "....FFFKKKKKKKKKKKK.....",
        "....FFFKKCKKKKKCKKK.....",
        "....FFFFKKKFFFKKKF......",
        "....FFFFFFFFFFFFFF......",
        ".....FFFFFFFFFFFFF......",
        ".....FFFFFFFKKKKFF......",
        "......FFFFFFFFFFF.......",
        ".......FFFFFFFFF........",
        "........FFFFFF..........",
        "......RRRWWWWRRR........",
        "....RRRRRRWWRRRRRR......",
        "...RRRRRRRWWRRRRRRR.....",
        "...RRRRRRRWWRRRRRRR.....",
    ], 0, 2)
    rex.outline()
    save(strip([show, boom, rex]), os.path.join(SPRITES, "portraits.png"))


# ------------------------------------------------------------------------ UI

def gen_ui():
    full = sprite(8, 8, ["", ".RR.RR.", "RWRRRRR", "RRRRRRR", ".RRRRR.", "..RRR..", "...R..."])
    empty = sprite(8, 8, ["", ".SS.SS.", "SNSSSSS", "SNNNNNS", ".SNNNS.", "..SNS..", "...S..."])
    live = sprite(8, 8, ["", "..RR...", ".RRRR..", ".RRRR..", "..RR..."])
    save(strip([full, empty, live]), os.path.join(SPRITES, "ui.png"))


# --------------------------------------------------------------------- Tiles

def gen_tiles():
    tiles = []

    def brick(fake=False):
        t = Canvas(16, 16)
        t.rect(0, 0, 16, 16, CH["S"])
        for y in (0, 8):
            t.rect(0, y, 16, 1, CH["N"])
        for x in (0, 8):
            t.rect(x, 1, 1, 7, CH["N"])
        for x in (4, 12):
            t.rect(x, 9, 1, 7, CH["N"])
        for (x, y) in ((1, 1), (9, 1), (5, 9), (13, 9)):
            t.put(x, y, CH["P"])
            t.put(x + 1, y, CH["P"])
        if fake:
            t.put(10, 4, CH["N"])
            t.put(11, 5, CH["N"])
        return t

    floor_top = Canvas(16, 16)
    floor_top.rect(0, 0, 16, 16, CH["P"])
    floor_top.rect(0, 0, 16, 1, CH["L"])
    floor_top.rect(0, 1, 16, 2, CH["Y"])
    for x in range(0, 16, 6):
        floor_top.rect(x, 1, 3, 2, CH["K"])
    floor_top.rect(0, 3, 16, 1, CH["S"])
    for (x, y) in ((3, 7), (11, 9), (6, 12), (14, 13), (1, 11)):
        floor_top.put(x, y, CH["S"])

    fill = Canvas(16, 16)
    fill.rect(0, 0, 16, 16, CH["S"])
    for (x, y) in ((2, 3), (9, 1), (13, 6), (5, 9), (11, 12), (1, 14), (7, 14)):
        fill.put(x, y, CH["P"])
    for (x, y) in ((4, 5), (12, 2), (8, 10), (14, 14)):
        fill.put(x, y, CH["N"])

    grate = Canvas(16, 16)
    grate.rect(0, 0, 16, 1, CH["L"])
    grate.rect(0, 1, 16, 3, CH["P"])
    grate.rect(0, 4, 16, 1, CH["K"])
    for x in range(1, 16, 3):
        grate.put(x, 2, CH["K"])
    grate.rect(2, 5, 1, 3, CH["S"])
    grate.rect(13, 5, 1, 3, CH["S"])

    bridge = Canvas(16, 16)
    bridge.rect(0, 0, 16, 6, CH["Y"])
    for x in range(-6, 16, 4):
        for i in range(6):
            bridge.put(x + i, i, CH["K"])
            bridge.put(x + i + 1, i, CH["K"])
    bridge.rect(0, 0, 16, 1, CH["W"])
    bridge.rect(0, 6, 16, 1, CH["K"])

    bg = Canvas(16, 16)
    bg.rect(0, 0, 16, 16, CH["N"])
    for y in (0, 8):
        bg.rect(0, y, 16, 1, CH["K"])
    for x in (0, 8):
        bg.rect(x, 0, 1, 16, CH["K"])

    bg_band = Canvas(16, 16)
    bg_band.blit(bg, 0, 0)
    bg_band.rect(0, 5, 16, 6, CH["T"])
    bg_band.rect(0, 5, 16, 1, CH["C"])
    bg_band.rect(0, 10, 16, 1, CH["K"])

    pillar = Canvas(16, 16)
    pillar.blit(bg, 0, 0)
    pillar.rect(4, 0, 8, 16, CH["S"])
    pillar.rect(5, 0, 1, 16, CH["P"])
    pillar.rect(11, 0, 1, 16, CH["N"])

    poster = Canvas(16, 16)
    poster.blit(bg, 0, 0)
    poster.rect(2, 1, 12, 14, CH["K"])
    poster.rect(3, 2, 10, 12, CH["M"])
    poster.ascii([
        "PP.P.P",
        "P.PPP.",
        "PP.P..",
        "P.PP.P",
    ], 5, 4)
    poster.rect(3, 10, 10, 1, CH["S"])
    poster.rect(4, 12, 8, 1, CH["P"])

    rail_off = Canvas(16, 16)
    rail_off.rect(0, 12, 16, 2, CH["L"])
    rail_off.rect(0, 14, 16, 2, CH["S"])
    for x in (2, 10):
        rail_off.rect(x, 13, 3, 3, CH["N"])

    rail_on = Canvas(16, 16)
    rail_on.blit(rail_off, 0, 0)
    rail_on.rect(0, 12, 16, 1, CH["W"])
    rail_on.ascii([
        "..C.......C.....",
        ".C.C.....C.W....",
        "C...C...C...C..W",
        ".....C.C.....CW.",
        "......W.........",
    ], 0, 7)

    tiles = [brick(), floor_top, fill, grate, bridge, brick(True), bg, bg_band, pillar, poster, rail_off, rail_on]
    save(strip(tiles), os.path.join(TILES, "subway.png"))


# ---------------------------------------------------------------------- Font

FONT = {
    "A": ".###." "#...#" "#...#" "#####" "#...#" "#...#" "#...#", "B": "####.#...##...#####.#...##...#####.",
    "C": ".###.#...##....#....#....#...#.###.", "D": "####.#...##...##...##...##...#####.",
    "E": "######....#....####.#....#....#####", "F": "######....#....####.#....#....#....",
    "G": ".###.#...##....#.####...##...#.####", "H": "#...##...##...#######...##...##...#",
    "I": ".###...#....#....#....#....#...###.", "J": "..###...#....#....#....#.#..#..##..",
    "K": "#...##..#.#.#..##...#.#..#..#.#...#", "L": "#....#....#....#....#....#....#####",
    "M": "#...###.###.#.##.#.##...##...##...#", "N": "#...##...###..##.#.##..###...##...#",
    "O": ".###.#...##...##...##...##...#.###.", "P": "####.#...##...#####.#....#....#....",
    "Q": ".###.#...##...##...##.#.##..#..##.#", "R": "####.#...##...#####.#.#..#..#.#...#",
    "S": ".#####....#.....###.....#....#####.", "T": "#####..#....#....#....#....#....#..",
    "U": "#...##...##...##...##...##...#.###.", "V": "#...##...##...##...##...#.#.#...#..",
    "W": "#...##...##...##.#.##.#.##.#.#.#.#.", "X": "#...##...#.#.#...#...#.#.#...##...#",
    "Y": "#...##...#.#.#...#....#....#....#..", "Z": "#####....#...#...#...#...#....#####",
    "0": ".###.#...##..###.#.###..##...#.###.", "1": "..#...##....#....#....#....#...###.",
    "2": ".###.#...#....#...#...#...#...#####", "3": "####.....#....#.###.....#....#####.",
    "4": "...#...##..#.#.#..#.#####...#....#.", "5": "######....####.....#....##...#.###.",
    "6": "..##..#...#....####.#...##...#.###.", "7": "#####....#...#...#...#....#....#...",
    "8": ".###.#...##...#.###.#...##...#.###.", "9": ".###.#...##...#.####....#...#..##..",
    " ": "." * 35, ".": "." * 25 + ".##...##..", ",": "." * 20 + ".##....#...#...",
    "!": "..#....#....#....#....#.........#..", "?": ".###.#...#....#...#...#.........#..",
    "'": "..#....#...#...." + "." * 19, '"': ".#.#..#.#." + "." * 25,
    ":": "......##...##.........##...##......", ";": "....." ".##.." ".##.." "....." ".##.." "..#.." ".#...",
    "-": "..........." + ".###." + "." * 19, "+": "....." "..#.." "..#.." "#####" "..#.." "..#.." ".....",
    "/": "....#...#....#...#...#....#...#....", "(": "...#...#...#....#....#.....#.....#.",
    ")": ".#.....#.....#....#....#...#...#...", "%": "##..###.#....#...#...#....#.###..##",
    "$": "..#...#####.#...###...#.#####...#..", "#": ".#.#..#.#.#####.#.#.#####.#.#..#.#.",
    "*": ".....#.#.#.###.#####.###.#.#.#.....", "=": "..........#####.....#####..........",
    "<": "...#...#...#...#.....#.....#.....#.", ">": ".#.....#.....#.....#...#...#...#...",
    "&": ".##..#..#.#.#...#...#.#.##..#..##.#", "_": "." * 30 + "#####",
}


def gen_font():
    cols = 16
    chars = [chr(c) for c in range(32, 96)]
    rows = (len(chars) + cols - 1) // cols
    c = Canvas(cols * 6, rows * 8)
    for i, ch in enumerate(chars):
        bits = FONT.get(ch)
        if bits is None:
            continue
        bits = bits.ljust(35, ".")
        ox, oy = (i % cols) * 6, (i // cols) * 8
        for j, b in enumerate(bits[:35]):
            if b == "#":
                c.put(ox + j % 5, oy + j // 5, CH["W"])
    save(c, os.path.join(FONTS, "pixel5x7.png"))


if __name__ == "__main__":
    gen_rex()
    gen_boom()
    gen_rat()
    gen_spark()
    gen_bolts()
    gen_pickups()
    gen_objects()
    gen_portraits()
    gen_ui()
    gen_tiles()
    gen_font()
    print("art generated")
