#!/usr/bin/env python3
"""Generate every sprite, tile and the pixel font for Super Rex Live!.

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
    (0x14, 0x1B, 0x33),  # 1 N navy (backdrop)
    (0x26, 0x32, 0x58),  # 2 S midnight blue (backdrop mortar, dark metal)
    (0x5A, 0x64, 0x88),  # 3 P metal blue-grey
    (0xB3, 0xBB, 0xD9),  # 4 L pale steel
    (0xF6, 0xF1, 0xE7),  # 5 W off-white
    (0xF2, 0xC1, 0x4E),  # 6 Y gold
    (0xD9, 0x8A, 0x4A),  # 7 O terracotta (floor highlights)
    (0xE0, 0x47, 0x3F),  # 8 R red
    (0x8A, 0x4B, 0x2F),  # 9 M rust (floors and walls)
    (0x3F, 0x7D, 0x6A),  # 10 G pine green
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

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

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
    crate.rect(0, 0, 16, 16, CH["Y"])
    crate.rect(0, 0, 16, 1, CH["K"])
    crate.rect(0, 15, 16, 1, CH["K"])
    crate.rect(0, 0, 1, 16, CH["K"])
    crate.rect(15, 0, 1, 16, CH["K"])
    crate.rect(1, 1, 14, 2, CH["O"])
    crate.rect(1, 13, 14, 2, CH["O"])
    for i in range(1, 15):
        crate.put(i, i, CH["O"])
        crate.put(i, 15 - i, CH["O"])
    crate.put(2, 4, CH["W"])
    crate.put(3, 5, CH["W"])
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

    # Moving platform, 32x8: steel deck with hazard stripes and running lights.
    lift = Canvas(32, 8)
    lift.rect(0, 0, 32, 8, CH["K"])
    lift.rect(1, 1, 30, 2, CH["L"])
    lift.rect(1, 3, 30, 3, CH["P"])
    for x in range(1, 31, 4):
        lift.rect(x, 3, 2, 3, CH["Y"])
    lift.rect(2, 6, 2, 1, CH["C"])
    lift.rect(28, 6, 2, 1, CH["C"])
    save(lift, os.path.join(SPRITES, "lift.png"))

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


# ---------------------------------------------------- The Mascot (boss, 48x48)

def mascot_frame(pose):
    """Floor 1 boss: a giant foam rat costume with a cheese-wedge hat."""
    c = Canvas(48, 48)
    V, W, K, F, Y, O, R = CH["V"], CH["W"], CH["K"], CH["F"], CH["Y"], CH["O"], CH["R"]
    body_y = {"idle2": 31, "crouch": 33, "jump": 28}.get(pose, 30)
    head_y = body_y - 16 + (2 if pose == "crouch" else 0)
    # Feet
    if pose == "jump":
        c.ellipse(17, 41, 5, 3, R); c.ellipse(31, 41, 5, 3, R)
    elif pose == "walk1":
        c.ellipse(14, 44, 6, 3, R); c.ellipse(32, 45, 6, 3, R)
    elif pose == "walk2":
        c.ellipse(16, 45, 6, 3, R); c.ellipse(34, 44, 6, 3, R)
    else:
        c.ellipse(15, 45, 6, 3, R); c.ellipse(33, 45, 6, 3, R)
    # Tail
    for i in range(8):
        c.put(36 + i, body_y + 6 - (i * i) // 10, F)
    # Body and belly with the network star
    c.ellipse(24, body_y, 13, 12, V)
    c.ellipse(24, body_y + 2, 8, 8, W)
    c.ascii(["..Y..", ".YYY.", "YYYYY", ".Y.Y."], 22, body_y)
    # Arms and gloves
    if pose in ("jump", "crouch"):
        c.ellipse(8, body_y - 10, 4, 4, W); c.ellipse(40, body_y - 10, 4, 4, W)
        c.rect(10, body_y - 8, 3, 6, V); c.rect(35, body_y - 8, 3, 6, V)
    elif pose == "throw":
        c.ellipse(9, body_y + 1, 4, 4, W)
        c.ellipse(40, body_y - 14, 4, 4, W); c.rect(36, body_y - 12, 3, 8, V)
    else:
        c.ellipse(9, body_y + 1, 4, 4, W); c.ellipse(39, body_y + 1, 4, 4, W)
    # Head, ears, cheese hat
    c.ellipse(11, head_y - 7, 5, 5, V); c.ellipse(11, head_y - 7, 3, 3, F)
    c.ellipse(37, head_y - 7, 5, 5, V); c.ellipse(37, head_y - 7, 3, 3, F)
    c.ellipse(24, head_y, 12, 10, V)
    c.ascii(["....Y", "..YYY", "YYOYY", "YYYYY"], 21, head_y - 13)
    # Face
    if pose == "hurt":
        c.ascii(["K.K", ".K.", "K.K"], 17, head_y - 3)
        c.ascii(["K.K", ".K.", "K.K"], 28, head_y - 3)
        c.ellipse(24, head_y + 6, 3, 2, K)
    else:
        c.ellipse(19, head_y - 2, 3, 4, W); c.ellipse(29, head_y - 2, 3, 4, W)
        c.rect(20, head_y - 2, 2, 3, K); c.rect(30, head_y - 2, 2, 3, K)
        c.ellipse(24, head_y + 3, 2, 1, R)
        c.rect(16, head_y + 5, 17, 1, K)
        c.rect(17, head_y + 6, 15, 2, K)
        c.rect(19, head_y + 6, 11, 1, W)
        if pose in ("crouch", "throw"):
            # Angry brows
            c.ascii(["KK....", "..KK.."], 15, head_y - 7)
            c.ascii(["..KK", "KK.."], 28, head_y - 7)
    return c.outline()


def gen_mascot():
    poses = ["idle", "idle2", "walk1", "walk2", "crouch", "jump", "hurt", "throw"]
    save(strip([mascot_frame(p) for p in poses]), os.path.join(SPRITES, "mascot.png"))
    wave_a = sprite(16, 12, ["", "", "", "......WW........", ".....WCCW.......", "....WCCCCW......",
                             "...WCCCCCCW.....", "..WCCCCCCCCW....", ".WCCCCCCCCCCW...", "WCCCCCCCCCCCCW.."])
    wave_b = sprite(16, 12, ["", "", "", "", ".......WW.......", "......WCCW......",
                             ".....WCCCCW.....", "...WWCCCCCCWW...", ".WCCCCCCCCCCCCW.", "WCCCCCCCCCCCCCCW"])
    save(strip([wave_a, wave_b]), os.path.join(SPRITES, "shockwave.png"))
    bomb = sprite(12, 12, ["", "....LL......", "...YVVY.....", "..VVYVVV....", "..VYYYYV....",
                           "..VVYVVV....", "...VVVV....."], ox=1)
    save(bomb, os.path.join(SPRITES, "bomb.png"))


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
# One sheet per floor, same 14-tile layout:
#  0 wall  1 floor top  2 floor fill  3 grate  4 bridge  5 fake wall  6 backdrop
#  7 backdrop band  8 pillar  9 poster  10 rail off  11 rail on  12 belt left  13 belt right

THEMES = {
    # Floor 1: rusty subway, terracotta floors, dark navy backdrop.
    "subway": {"wall": "M", "mortar": "K", "hi": "O", "floor": "M", "stripe": "Y", "lip": "O",
               "bg": "N", "grout": "S", "band": "T", "band_hi": "C", "pillar": "S", "pillar_hi": "P"},
    # Floor 2: the mall after hours. Teal shopfront tiles, peach marble floors.
    "mall": {"wall": "T", "mortar": "S", "hi": "C", "floor": "F", "stripe": "V", "lip": "W",
             "bg": "S", "grout": "N", "band": "V", "band_hi": "F", "pillar": "P", "pillar_hi": "L"},
    # Floor 3: studio backlot. Plywood set flats, stage-board floors, black rigging.
    "backlot": {"wall": "O", "mortar": "M", "hi": "F", "floor": "M", "stripe": "W", "lip": "O",
                "bg": "K", "grout": "N", "band": "M", "band_hi": "Y", "pillar": "S", "pillar_hi": "P"},
    # Floor 4: Network HQ. Steel panels, midnight floors with cyan trim, server racks.
    "hq": {"wall": "P", "mortar": "S", "hi": "L", "floor": "T", "stripe": "C", "lip": "L",
           "bg": "N", "grout": "K", "band": "G", "band_hi": "g", "pillar": "K", "pillar_hi": "S"},
}


def gen_tiles(name):
    th = {k: CH[v] for k, v in THEMES[name].items()}

    def wall(fake=False):
        t = Canvas(16, 16)
        t.rect(0, 0, 16, 16, th["wall"])
        if name == "hq":
            # Riveted panels.
            t.rect(0, 0, 16, 1, th["hi"]); t.rect(0, 15, 16, 1, th["mortar"])
            t.rect(0, 0, 1, 16, th["hi"]); t.rect(15, 0, 1, 16, th["mortar"])
            for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
                t.put(x, y, th["mortar"])
            t.rect(4, 7, 8, 2, th["mortar"])
        elif name == "backlot":
            # Plywood flat with wood grain and a brace.
            for y in (3, 7, 12):
                for x in range(16):
                    if (x + y) % 5:
                        t.put(x, y, th["mortar"])
            t.rect(0, 0, 16, 1, th["hi"])
            t.rect(0, 15, 16, 1, CH["K"])
            for i in range(16):
                t.put(i, 15 - i, th["hi"])
        else:
            for y in (0, 8):
                t.rect(0, y, 16, 1, th["mortar"])
            for x in (0, 8):
                t.rect(x, 1, 1, 7, th["mortar"])
            for x in (4, 12):
                t.rect(x, 9, 1, 7, th["mortar"])
            for (x, y) in ((1, 1), (9, 1), (5, 9), (13, 9)):
                t.put(x, y, th["hi"])
                t.put(x + 1, y, th["hi"])
        if fake:
            t.put(10, 4, CH["K"])
            t.put(11, 5, CH["K"])
        return t

    floor_top = Canvas(16, 16)
    floor_top.rect(0, 0, 16, 16, th["floor"])
    floor_top.rect(0, 0, 16, 1, th["lip"])
    floor_top.rect(0, 1, 16, 2, th["stripe"])
    if name == "subway":
        for x in range(0, 16, 6):
            floor_top.rect(x, 1, 3, 2, CH["K"])
    floor_top.rect(0, 3, 16, 1, CH["K"])
    fill = Canvas(16, 16)
    fill.rect(0, 0, 16, 16, th["floor"])
    if name == "mall":
        # Marble checker.
        for y in range(4, 16):
            for x in range(16):
                if ((x // 4) + (y // 4)) % 2:
                    floor_top.put(x, y, CH["O"])
        for y in range(16):
            for x in range(16):
                if ((x // 4) + (y // 4)) % 2:
                    fill.put(x, y, CH["O"])
    elif name == "backlot":
        # Stage boards.
        for y in (8, 15):
            floor_top.rect(0, y, 16, 1, CH["K"])
        for y in (4, 11):
            fill.rect(0, y, 16, 1, CH["K"])
        floor_top.rect(5, 4, 1, 4, CH["K"]); floor_top.rect(12, 9, 1, 6, CH["K"])
        fill.rect(9, 0, 1, 4, CH["K"]); fill.rect(3, 5, 1, 6, CH["K"])
    elif name == "hq":
        floor_top.rect(0, 9, 16, 1, CH["N"])
        fill.rect(0, 7, 16, 1, CH["N"])
        for (x, y) in ((3, 12), (11, 5)):
            fill.put(x, y, CH["T"])
    else:
        for (x, y) in ((3, 7), (11, 9), (6, 12), (14, 13), (1, 11)):
            floor_top.put(x, y, CH["O"])
        for (x, y) in ((2, 3), (9, 1), (13, 6), (5, 9), (11, 12), (1, 14), (7, 14)):
            fill.put(x, y, CH["O"])
        for (x, y) in ((4, 5), (12, 2), (8, 10), (14, 14)):
            fill.put(x, y, CH["K"])

    grate = Canvas(16, 16)
    grate.rect(0, 0, 16, 1, CH["L"])
    grate.rect(0, 1, 16, 3, CH["P"] if name != "backlot" else CH["M"])
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
    bg.rect(0, 0, 16, 16, th["bg"])
    if name == "backlot":
        # Rigging grid in the dark.
        for x in (3, 11):
            for y in range(0, 16, 2):
                bg.put(x, y, th["grout"])
    elif name == "hq":
        # Server rack: vents and blinking lights.
        bg.rect(1, 0, 14, 16, CH["K"])
        for y in (2, 6, 10, 14):
            bg.rect(2, y, 12, 2, th["grout"] if y % 8 else CH["S"])
        bg.put(12, 2, CH["g"]); bg.put(12, 10, CH["C"])
    else:
        for y in (0, 8):
            bg.rect(0, y, 16, 1, th["grout"])
        for x in (0, 8):
            bg.rect(x, 0, 1, 16, th["grout"])

    bg_band = Canvas(16, 16)
    bg_band.blit(bg, 0, 0)
    bg_band.rect(0, 5, 16, 6, th["band"])
    bg_band.rect(0, 5, 16, 1, th["band_hi"])
    bg_band.rect(0, 10, 16, 1, CH["K"])
    if name == "mall":
        # Shop window glow.
        bg_band.rect(2, 7, 4, 2, CH["Y"]); bg_band.rect(10, 7, 4, 2, CH["C"])

    pillar = Canvas(16, 16)
    pillar.blit(bg, 0, 0)
    pillar.rect(4, 0, 8, 16, th["pillar"])
    pillar.rect(5, 0, 1, 16, th["pillar_hi"])
    pillar.rect(11, 0, 1, 16, CH["N"])

    poster = Canvas(16, 16)
    poster.blit(bg, 0, 0)
    poster.rect(2, 1, 12, 14, CH["K"])
    if name == "mall":
        poster.rect(3, 2, 10, 12, CH["R"])
        poster.ascii(["WWW.W.", "W..W.W", "WWW.WW", "..WW.W", "WWW.W."], 5, 4)  # SALE-ish
    elif name == "backlot":
        poster.rect(3, 4, 10, 7, CH["R"])
        poster.ascii(["W.W.W", "WWW.W", "W.W.W"], 5, 6)  # ON AIR light
        poster.rect(3, 4, 10, 1, CH["V"])
    elif name == "hq":
        poster.rect(3, 2, 10, 12, CH["T"])
        poster.ascii(["..YY..", ".Y..Y.", "YYYYYY", ".Y..Y.", "..YY.."], 5, 5)  # the network's star-eye
    else:
        poster.rect(3, 2, 10, 12, CH["S"])
        poster.ascii(["PP.P.P", "P.PPP.", "PP.P..", "P.PP.P"], 5, 4)
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

    def belt(right):
        t = Canvas(16, 16)
        t.rect(0, 0, 16, 16, CH["S"])
        t.rect(0, 0, 16, 1, CH["L"])
        t.rect(0, 1, 16, 5, CH["P"])
        # Chevrons point the way the tread moves.
        for x0 in (1, 9):
            for i in range(3):
                xx = x0 + (i if right else 2 - i)
                t.put(xx, 2 + i if i < 2 else 3, CH["Y"])
                t.put(xx, 4 - i if i < 2 else 3, CH["Y"])
        t.rect(0, 6, 16, 1, CH["K"])
        for x in (2, 7, 12):
            t.ellipse(x + 1, 10, 2, 2, CH["P"])
            t.put(x + 1, 10, CH["K"])
        t.rect(0, 15, 16, 1, CH["K"])
        return t

    tiles = [wall(), floor_top, fill, grate, bridge, wall(True), bg, bg_band, pillar, poster,
             rail_off, rail_on, belt(False), belt(True)]
    save(strip(tiles), os.path.join(TILES, name + ".png"))


# ------------------------------------------------------------ Floor 2-4 cast

def gen_guard():
    """Mall security bot, 16x24: a squat robot in a cop cap with a flashlight."""
    body = [
        "",
        ".....SSSSSS.....",
        "....SSSSSSSS....",
        "...KKKKKKKKKK...",
        ".....PPPPPP.....",
        "....PCCPPCCP....",
        "....PPPPPPPP....",
        ".....PPPPPP.....",
        "....SSSSSSSS....",
        "...SSSSYSSSSS...",
        "...SSSSSSSSSSYY.",
        "...SSSSSSSSSSYW.",
        "...SSSSSSSSSS...",
        "....SSSSSSSS....",
        "....KKKKKKKK....",
        "....PP....PP....",
    ]
    a = sprite(16, 24, body + ["....PP....PP....", "...KKK....KKK..."], oy=5)
    b = sprite(16, 24, body + ["...PP......PP...", "..KKK......KKK.."], oy=5)
    aim = list(body)
    aim[5] = "....PRRPPRRP...."
    aim[10] = "...SSSSSSSSSYYWW"
    aim[11] = "...SSSSSSSSSYYWW"
    c = sprite(16, 24, aim + ["....PP....PP....", "...KKK....KKK..."], oy=5)
    # Facing left by default: the sheet is drawn facing right, so mirror it.
    save(strip([mirror(a), mirror(b), mirror(c)]), os.path.join(SPRITES, "guard.png"))


def mirror(c):
    out = Canvas(c.w, c.h)
    for y in range(c.h):
        for x in range(c.w):
            out.px[y][c.w - 1 - x] = c.px[y][x]
    return out


def gen_mannequin():
    """A blank display mannequin, 16x32, in a sale sash."""
    def frame(step):
        c = Canvas(16, 32)
        W, L, V, K = CH["W"], CH["L"], CH["V"], CH["K"]
        c.ellipse(8, 5, 3, 4, W)
        c.rect(7, 9, 2, 2, L)
        c.rect(4, 11, 8, 9, W)
        c.rect(5, 19, 6, 2, L)
        for i in range(8):
            c.put(4 + i, 12 + i // 2, V)
            c.put(5 + i, 12 + i // 2, V)
        if step == 0:
            c.rect(2, 12, 2, 8, W); c.rect(12, 12, 2, 8, W)
            c.rect(5, 21, 2, 10, W); c.rect(9, 21, 2, 10, W)
        elif step == 1:
            c.rect(2, 11, 2, 7, W); c.rect(12, 13, 2, 7, W)
            c.rect(4, 21, 2, 10, W); c.rect(10, 21, 2, 9, W)
        else:
            c.rect(2, 13, 2, 7, W); c.rect(12, 11, 2, 7, W)
            c.rect(6, 21, 2, 9, W); c.rect(8, 21, 2, 10, W)
        c.put(7, 4, CH["P"]); c.put(9, 4, CH["P"])
        return c.outline()
    save(strip([frame(0), frame(1), frame(2)]), os.path.join(SPRITES, "mannequin.png"))


def gen_drones():
    mic_a = sprite(16, 16, [
        "",
        "LL.........LL...",
        ".SSSSSSSSSSSSS..",
        ".......SS.......",
        "....PPPPPPPP....",
        "...PPRPPPPPPP...",
        "...PPPPPPPPPP...",
        "....PPPPPPPP....",
        "......SSS.......",
        ".......S........",
        ".......S........",
        "......KKKK......",
        ".....KSKSKK.....",
        ".....KKSKSK.....",
        "......KKKK......",
    ])
    mic_b = sprite(16, 16, [
        "",
        "..LL.....LL.....",
    ] + [r for r in [
        ".SSSSSSSSSSSSS..",
        ".......SS.......",
        "....PPPPPPPP....",
        "...PPPPPPPPRP...",
        "...PPPPPPPPPP...",
        "....PPPPPPPP....",
        "......SSS.......",
        ".......S........",
        ".......S........",
        "......KKKK......",
        ".....KSKSKK.....",
        ".....KKSKSK.....",
        "......KKKK......",
    ]])
    save(strip([mic_a, mic_b]), os.path.join(SPRITES, "micdrone.png"))
    base = [
        "",
        "",
        "...SS......SS...",
        "..SPPS....SPPS..",
        "...SSKKKKKKSS...",
        ".....KTTTTK.....",
        "....KTTTTTTK....",
        "...KTTCCCCTTK...",
        "...KTTCWWCTTK...",
        "...KTTCCCCTTK...",
        "....KTTTTTTK....",
        ".....KKKKKK.....",
        "......S..S......",
    ]
    a = sprite(16, 16, base)
    b = list(base); b[2] = "..SS........SS.."; b = sprite(16, 16, b)
    ch = list(base); ch[7] = "...KTTRRRRTTK..."; ch[8] = "...KTTRWWRTTK..."; ch[9] = "...KTTRRRRTTK..."
    save(strip([a, b, sprite(16, 16, ch)]), os.path.join(SPRITES, "execdrone.png"))
    clip = sprite(12, 10, ["", "..PPPP......", ".SWWWWWS....", ".SWKKKWS....", ".SWWWWWS....",
                            ".SWKKWWS....", ".SWWWWWS....", ".SSSSSSS...."], ox=1)
    save(clip, os.path.join(SPRITES, "clipboard.png"))


def manager_frame(pose):
    """Floor 2 boss: the Floor Manager, tie and headset, on a motorized cart. 40x40."""
    c = Canvas(40, 40)
    K, W, F, R, S, P, Y, L, T = (CH[k] for k in "KWFRSPYLT")
    # Cart
    c.rect(4, 30, 32, 6, R)
    c.rect(4, 30, 32, 1, W)
    c.rect(6, 32, 6, 2, Y)
    wheel = 0 if pose != "drive2" else 1
    for x in (9, 30):
        c.ellipse(x, 37, 3, 2, K)
        c.put(x + wheel, 37, P)
    # Body: shirt, tie, blazer
    lean = 2 if pose in ("drive1", "drive2") else 0
    c.rect(12 - lean, 16, 16, 14, T)
    c.rect(17 - lean, 16, 6, 14, W)
    c.rect(19 - lean, 17, 2, 10, R)
    # Head
    c.ellipse(20 - lean, 10, 6, 6, F)
    c.rect(14 - lean, 3, 12, 3, K)  # slicked hair
    c.rect(14 - lean, 9, 2, 4, S)  # headset
    c.rect(15 - lean, 13, 4, 1, S)
    if pose == "hurt":
        c.ascii(["K.K", ".K.", "K.K"], 16 - lean, 8); c.ascii(["K.K", ".K.", "K.K"], 22 - lean, 8)
        c.ellipse(20 - lean, 14, 2, 1, K)
    else:
        c.rect(17 - lean, 9, 2, 2, K); c.rect(22 - lean, 9, 2, 2, K)
        c.rect(16 - lean, 7, 3, 1, K); c.rect(22 - lean, 7, 3, 1, K)
        c.rect(18 - lean, 13, 5, 1, K)
    # Arms
    if pose == "shout":
        # Megaphone held out front
        c.rect(26, 15, 6, 3, T)
        c.ascii(["....YY", "..YYYY", "YYYYYY", "YYYYYY", "..YYYY", "....YY"], 31, 11)
        c.rect(15, 13, 4, 2, K)  # open mouth
    elif pose == "throw":
        c.rect(26, 8, 3, 9, T)
        c.rect(26, 4, 6, 5, W); c.rect(27, 5, 4, 1, K)
    else:
        c.rect(8 - lean, 18, 4, 8, T); c.rect(28 - lean, 18, 4, 8, T)
        c.ellipse(10 - lean, 27, 2, 2, F); c.ellipse(30 - lean, 27, 2, 2, F)
    return c.outline()


def director_frame(pose):
    """Floor 3 boss: the Director in his crane seat, beret and megaphone. 40x32."""
    c = Canvas(40, 32)
    K, W, F, R, S, P, Y, V, M = (CH[k] for k in "KWFRSPYVM")
    # Crane seat
    c.rect(6, 24, 28, 5, P)
    c.rect(6, 24, 28, 1, CH["L"])
    c.rect(17, 2, 6, 2, S)  # arm mount (the arm itself is drawn in-game)
    c.rect(8, 18, 3, 6, P); c.rect(29, 18, 3, 6, P)
    # Body
    c.rect(12, 14, 16, 10, K)
    c.rect(18, 14, 4, 6, W)
    # Head with beret and shades
    c.ellipse(20, 9, 6, 5, F)
    c.ellipse(19, 4, 7, 2, R); c.put(19, 1, R)
    if pose == "hurt":
        c.ascii(["K.K", ".K.", "K.K"], 15, 7); c.ascii(["K.K", ".K.", "K.K"], 22, 7)
    else:
        c.rect(14, 7, 12, 3, K); c.put(16, 8, W); c.put(23, 8, W)
        c.rect(17, 12, 6, 1, K if pose != "shout" else R)
    if pose == "shout":
        c.ascii(["....YY", "..YYYY", "YYYYYY", "YYYYYY", "..YYYY", "....YY"], 28, 12)
        c.rect(25, 14, 4, 3, K)
    else:
        # Clapperboard in hand
        c.rect(27, 15 + (1 if pose == "idle2" else 0), 8, 6, K)
        c.rect(27, 14 + (1 if pose == "idle2" else 0), 8, 2, W)
        c.put(29, 14, K); c.put(32, 15, K)
    c.rect(5, 15, 7, 3, K); c.ellipse(5, 17, 2, 2, F)
    return c.outline()


def finale_frame(pose):
    """Floor 4 boss: the Showrunner as a giant broadcast screen, 48x56."""
    c = Canvas(48, 56)
    K, W, V, S, P, R, C, Y, N, L = (CH[k] for k in "KWVSPRCYNL")
    c.rect(2, 2, 44, 46, K)
    c.rect(3, 3, 42, 44, V)
    c.rect(4, 4, 40, 4, CH["F"])
    c.rect(6, 10, 36, 30, W if pose not in ("open", "open2") else N)
    # Antennae and stand
    c.rect(12, 0, 2, 3, L); c.rect(34, 0, 2, 3, L)
    c.rect(16, 48, 16, 4, S); c.rect(10, 52, 28, 4, S)
    c.put(4, 43, R); c.put(6, 43, Y); c.put(8, 43, C)
    if pose in ("open", "open2"):
        # The core behind the screen.
        r = 8 if pose == "open" else 9
        c.ellipse(24, 25, r, r, C)
        c.ellipse(24, 25, r - 3, r - 3, W)
        c.ellipse(24, 25, 2, 2, Y)
        for (x, y) in ((8, 12), (38, 14), (10, 36), (37, 37)):
            c.put(x, y, S)
    else:
        if pose == "hurt":
            c.ascii(["KK.KK", ".KKK.", "KK.KK"], 12, 17); c.ascii(["KK.KK", ".KKK.", "KK.KK"], 31, 17)
            c.ellipse(24, 32, 5, 3, K)
        else:
            eye_y = 16 if pose != "idle2" else 17
            c.rect(13, eye_y, 4, 5, K); c.rect(31, eye_y, 4, 5, K)
            if pose == "angry":
                c.ascii(["KKKK....", "..KKKK.."], 10, eye_y - 3)
                c.ascii(["....KKKK", "..KKKK.."], 30, eye_y - 3)
                c.rect(14, 30, 20, 4, K); c.rect(16, 31, 16, 2, R)
            else:
                c.ascii(["K..............K", ".K............K.", "..KKKKKKKKKKKK.."], 16, 28)
    return c.outline()


def gen_bosses():
    save(strip([manager_frame(p) for p in ["idle", "idle2", "drive1", "drive2", "shout", "throw", "hurt"]]),
         os.path.join(SPRITES, "manager.png"))
    save(strip([director_frame(p) for p in ["idle", "idle2", "shout", "hurt"]]),
         os.path.join(SPRITES, "director.png"))
    save(strip([finale_frame(p) for p in ["idle", "idle2", "angry", "open", "open2", "hurt"]]),
         os.path.join(SPRITES, "finale.png"))


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
    gen_mascot()
    gen_ui()
    for theme in THEMES:
        gen_tiles(theme)
    gen_guard()
    gen_mannequin()
    gen_drones()
    gen_bosses()
    gen_font()
    print("art generated")
