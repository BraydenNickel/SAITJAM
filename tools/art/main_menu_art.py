"""Main menu art from Main_menu_screen_template.aseprite layers (dumped as layer_1..4.png).

Usage: python tools/art/main_menu_art.py <dir with layer_1..4.png> <out dir>
Writes into <out dir>:
  menu_bg.png              black backdrop + caution tape (640x360)
  title_sheet.png/.json    slime MUTANT + LAB, 6-frame dripping loop (cropped, with its offset)
  mound_sheet.png/.json    the flesh mound breathing, 6 frames (cropped, bottom-anchored)
  btn_<name>.png / btn_<name>_hover.png   buttons, normal and neon hover (cropped + offsets)
  lamp.png / lamp_cone.png overhead lamp housing and its light cone (640x360)
  drop.png, splat_sheet.png  a falling slime drop and its 5-frame splat
  menu_art.json            positions: title/mound/button rects, drop spawn points with landing y
"""
import json
import math
import os
import random
import sys
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
W, H = 640, 360
L1, L2, L3, L4 = (Image.open(os.path.join(SRC, f"layer_{i}.png")).convert("RGBA") for i in range(1, 5))
meta = {}

# ---------------- classify layer 4: tape, buttons, mound ----------------
TAPE = {(251, 242, 54, 255), (39, 39, 32, 255)}
BTN = {(255, 255, 255, 255), (181, 255, 110, 255)}
BUTTONS = {"new_run": (380, 133, 592, 183), "codex": (382, 189, 592, 239),
           "settings": (382, 244, 592, 289), "quit": (382, 293, 592, 343)}
MOUND_BOX = (168, 276, 368, 360)
P4 = L4.load()

bg = L1.copy()
for y in range(H):
    for x in range(W):
        c = P4[x, y]
        if c[3] and c in TAPE and not any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in BUTTONS.values()):
            bg.putpixel((x, y), c)
bg.save(os.path.join(OUT, "menu_bg.png"))


# ---------------- buttons: normal + neon hover ----------------
NEON, NEON_TEXT, NEON_FILL = (57, 255, 20), (150, 255, 110), (8, 40, 10)
PAD = 4
meta["buttons"] = {}
for name, (x0, y0, x1, y1) in BUTTONS.items():
    w, h = x1 - x0 + 1 + 2 * PAD, y1 - y0 + 1 + 2 * PAD
    normal = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hover = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    N, Hv = normal.load(), hover.load()
    own = {}
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = P4[x, y]
            if c in BTN:
                own[(x - x0 + PAD, y - y0 + PAD)] = c
    xs = [p[0] for p, c in own.items() if c == (181, 255, 110, 255)]
    ys = [p[1] for p, c in own.items() if c == (181, 255, 110, 255)]
    bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
    for (x, y), c in own.items():
        N[x, y] = c
    # hover: glow halo, dark green fill, neon frame and text
    for y in range(h):
        for x in range(w):
            dx = max(bx0 - x, x - bx1, 0)
            dy = max(by0 - y, y - by1, 0)
            d = max(dx, dy)
            if bx0 < x < bx1 and by0 < y < by1:
                Hv[x, y] = (*NEON_FILL, 170)
            elif 0 < d <= PAD:
                a = (110, 60, 30, 14)[d - 1]
                if d <= 2 or (x + y) % 2 == 0:
                    Hv[x, y] = (*NEON, a)
    for (x, y), c in own.items():
        Hv[x, y] = (*NEON, 255) if c == (181, 255, 110, 255) else (*NEON_TEXT, 255)
    for (x, y), c in own.items():   # thin glow around the letters
        if c == (255, 255, 255, 255):
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q not in own and Hv[q][3] < 200:
                    Hv[q] = (*NEON, 120)
    normal.save(os.path.join(OUT, f"btn_{name}.png"))
    hover.save(os.path.join(OUT, f"btn_{name}_hover.png"))
    meta["buttons"][name] = {"pos": [x0 - PAD, y0 - PAD], "size": [w, h]}


# ---------------- breathing flesh mound ----------------
mx0, my0, mx1, my1 = MOUND_BOX
mound = {}
for y in range(my0, my1):
    for x in range(mx0, mx1):
        c = P4[x, y]
        if c[3] and c not in TAPE and c not in BTN:
            mound[(x - mx0, y - my0)] = c
MW, MH = mx1 - mx0, my1 - my0
top = min(y for _, y in mound)
bottom = max(y for _, y in mound)
STRETCH_ROWS = [top + (bottom - top) * 2 // 5, top + (bottom - top) * 3 // 5]
BREATH = [0, 0, 1, 2, 2, 1]
breath_sheet = Image.new("RGBA", (MW * len(BREATH), MH), (0, 0, 0, 0))
for f, k in enumerate(BREATH):
    im = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    P = im.load()
    for (x, y), c in mound.items():
        # rows above each stretch row move up one pixel per inserted row (bottom stays planted)
        shift = sum(1 for i, r in enumerate(STRETCH_ROWS) if i < k and y <= r)
        P[x, y - shift] = c
        for i, r in enumerate(STRETCH_ROWS):
            if i < k and y == r:
                P[x, y - shift + 1] = c   # fill the gap with the duplicated row
    breath_sheet.alpha_composite(im, (f * MW, 0))
breath_sheet.save(os.path.join(OUT, "mound_sheet.png"))
meta["mound"] = {"pos": [mx0, my0], "frame_size": [MW, MH], "frames": len(BREATH)}
mound_top = {}
for (x, y) in mound:
    mound_top[x + mx0] = min(mound_top.get(x + mx0, 999), y + my0)


# ---------------- slime title ----------------
P2 = L2.load()
DARK, FILLC, WHITE = (56, 109, 20, 255), (90, 151, 47, 255), (255, 255, 255, 255)
letters = {(x, y) for y in range(H) for x in range(W) if P2[x, y] in (DARK, FILLC)}
lab = {(x, y) for y in range(H) for x in range(W) if P2[x, y] == WHITE}
C_OUT, C_RIM, C_FILL, C_HI = (12, 36, 20, 255), (40, 112, 48, 255), (112, 216, 74, 255), (174, 246, 122, 255)
C_SPEC, C_DEEP, C_SHADE = (240, 255, 226, 255), (52, 138, 54, 255), (70, 170, 62, 255)

random.seed(4)
cands = []
for y in range(H):
    for x in range(2, W - 3):
        if all((x + d, y) in letters for d in (-1, 0, 1, 2)) and all((x + d, y + 1) not in letters for d in (-1, 0, 1, 2)):
            free = 0
            while y + 1 + free < H and all((x + d, y + 1 + free) not in letters and (x + d, y + 1 + free) not in lab
                                            for d in (-2, -1, 0, 1, 2, 3)):
                free += 1
            if free >= 7:
                cands.append((x, y, free))
cands.sort()
drips = []
for x, y, free in cands:
    if all(abs(x - d[0]) > 16 or abs(y - d[1]) > 3 for d in drips) and random.random() < 0.4:
        length = min(free - 4, random.randint(7, 16))
        if length >= 6:
            drips.append((x - 1, y, length))


def title_frame(f):
    body = {}
    for (x, y) in letters:
        c = C_RIM if P2[x, y] == DARK else C_FILL
        if c == C_FILL:
            if (x, y - 1) not in letters or ((x, y - 1) in letters and P2[x, y - 1] == DARK and (x, y - 2) not in letters):
                c = C_HI
            elif (x, y + 1) not in letters:
                c = C_DEEP
        body[(x, y)] = c
    for (x, y) in list(body):   # glints at top-left corners
        if body[(x, y)] == C_HI and (x - 1, y) not in letters and (x, y - 1) not in letters and (x + 1, y) in letters:
            body[(x + 1, y + 1)] = C_SPEC
    wob = (0, 1, 1, 0, -1, 0)[f]

    def row(yy, x0, x1, bottom=False):
        for xx in range(x0, x1 + 1):
            cc = C_HI if xx == x0 else C_SHADE if xx == x1 else C_FILL
            body[(xx, yy)] = C_DEEP if bottom and x0 < xx < x1 else cc

    for i, (x, y, length) in enumerate(drips):
        L = max(3, length + (wob if i % 2 == 0 else -wob))
        row(y + 1, x - 3, x + 5)            # wide neck where it leaves the letter
        row(y + 2, x - 2, x + 4)
        row(y + 3, x - 1, x + 3)
        for j in range(4, L - 1):           # stem tapers from 4 to 3 px
            row(y + j, x - 1 if j < L // 2 + 2 else x, x + 2)
        row(y + L - 1, x - 2, x + 3)        # fat round drop
        row(y + L, x - 2, x + 4)
        row(y + L + 1, x - 1, x + 3)
        row(y + L + 2, x, x + 2, bottom=True)
        body[(x - 1, y + L - 1)] = C_SPEC
        body[(x, y + L)] = C_SPEC
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    P = im.load()
    for (x, y) in lab:   # LAB: clinical white with a cool shade and a dark outline
        P[x, y] = (230, 238, 242, 255) if (x, y + 1) in lab else (170, 186, 196, 255)
    for (x, y) in lab:
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if q not in lab and q not in body:
                P[q] = (18, 22, 30, 255)
    for (x, y), c in body.items():
        P[x, y] = c
    for (x, y) in list(body):
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x, y + 2)):
            if q not in body and 0 <= q[0] < W and 0 <= q[1] < H and q not in lab:
                P[q] = C_OUT
    return im, {(x, y + max(3, length) + 1) for x, y, length in drips}


frames = [title_frame(f)[0] for f in range(6)]
xs = [p[0] for p in letters | lab]
ys = [p[1] for p in letters | lab]
tx0, ty0 = min(xs) - 4, min(ys) - 4
tx1 = max(xs) + 5
ty1 = max(max(ys), max(y + l + 4 for _, y, l in drips)) + 5
TW, TH = tx1 - tx0, ty1 - ty0
title_sheet = Image.new("RGBA", (TW * len(frames), TH), (0, 0, 0, 0))
for f, im in enumerate(frames):
    title_sheet.alpha_composite(im.crop((tx0, ty0, tx1, ty1)), (f * TW, 0))
title_sheet.save(os.path.join(OUT, "title_sheet.png"))
meta["title"] = {"pos": [tx0, ty0], "frame_size": [TW, TH], "frames": len(frames)}

# drops: drip tips above the mound, with where they land
meta["drops"] = []
for x, y, length in drips:
    cx = x + 1
    if cx in mound_top and mound_top[cx] > y + length + 4:
        meta["drops"].append({"from": [cx, y + length + 3], "land_y": mound_top[cx] + 2})

# ---------------- drop + splat ----------------
drop = Image.new("RGBA", (5, 7), (0, 0, 0, 0))
D = drop.load()
for (x, y), c in {(2, 0): C_FILL, (1, 1): C_FILL, (2, 1): C_HI, (3, 1): C_SHADE, (1, 2): C_HI, (2, 2): C_FILL,
                  (3, 2): C_SHADE, (0, 3): C_OUT, (1, 3): C_FILL, (2, 3): C_FILL, (3, 3): C_SHADE, (4, 3): C_OUT,
                  (0, 4): C_OUT, (1, 4): C_DEEP, (2, 4): C_FILL, (3, 4): C_DEEP, (4, 4): C_OUT, (1, 5): C_OUT,
                  (2, 5): C_OUT, (3, 5): C_OUT, (1, 0): C_OUT, (3, 0): C_OUT, (0, 1): C_OUT, (4, 1): C_OUT,
                  (0, 2): C_OUT, (4, 2): C_OUT}.items():
    D[x, y] = c
drop.save(os.path.join(OUT, "drop.png"))
SW, SH = 21, 10
splat = Image.new("RGBA", (SW * 5, SH), (0, 0, 0, 0))
for f in range(5):
    im = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    P = im.load()
    spread = 3 + f * 2
    for x in range(SW // 2 - spread, SW // 2 + spread + 1):   # puddle on the flesh
        if 0 <= x < SW:
            P[x, SH - 1] = C_DEEP if f < 4 else (52, 138, 54, 150)
            if abs(x - SW // 2) < spread - 1:
                P[x, SH - 2] = C_FILL if f < 4 else (112, 216, 74, 120)
    if f < 4:                                                     # flying droplets
        for side in (-1, 1):
            for k in range(2):
                px = SW // 2 + side * (2 + f * 2 + k * 2)
                py = SH - 3 - (3 if f == 1 else 4 if f == 2 else 2 if f == 3 else 1) + k
                if 0 <= px < SW and 0 <= py < SH:
                    P[px, py] = C_HI if k == 0 else C_FILL
    splat.alpha_composite(im, (f * SW, 0))
splat.save(os.path.join(OUT, "splat_sheet.png"))
meta["splat"] = {"frame_size": [SW, SH], "frames": 5}

# ---------------- overhead lamp ----------------
LAMP_X, BAR_Y, BAR_W = 262, 26, 120
lamp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
LP = lamp.load()
for y in range(0, BAR_Y - 8):                     # cord
    LP[LAMP_X, y] = (40, 44, 52, 255)
    LP[LAMP_X + 1, y] = (24, 26, 32, 255)
for y in range(BAR_Y - 8, BAR_Y):                 # shade (trapezoid)
    half = 12 + (y - (BAR_Y - 8)) * 6
    for x in range(LAMP_X - half, LAMP_X + half + 2):
        edge = x in (LAMP_X - half, LAMP_X + half + 1) or y == BAR_Y - 8
        LP[x, y] = (24, 30, 36, 255) if edge else ((96, 110, 116, 255) if x < LAMP_X else (66, 78, 84, 255))
for x in range(LAMP_X - BAR_W // 2, LAMP_X + BAR_W // 2 + 2):   # glowing diffuser
    LP[x, BAR_Y] = (230, 255, 250, 255)
    LP[x, BAR_Y + 1] = (170, 240, 230, 255)
lamp.save(os.path.join(OUT, "lamp.png"))

cone = Image.new("RGBA", (W, H), (0, 0, 0, 0))
CP = cone.load()
FLOOR_Y = 352
for y in range(BAR_Y + 2, H):
    t = (y - BAR_Y) / (FLOOR_Y - BAR_Y)
    half = BAR_W / 2 + 130 * t
    for x in range(int(LAMP_X - half), int(LAMP_X + half) + 1):
        if not 0 <= x < W:
            continue
        u = abs(x - LAMP_X) / half
        i = (1 - 0.55 * t) * (1 - u ** 2)
        a = 46 if i > 0.6 else 30 if i > 0.35 else 16 if i > 0.15 else (16 if i > 0.08 and (x + y) % 2 == 0 else 0)
        if a:
            CP[x, y] = (190, 255, 240, a)
for y in range(FLOOR_Y - 10, H):                  # pool of light on the floor
    for x in range(LAMP_X - 160, LAMP_X + 161):
        e = ((x - LAMP_X) / 150) ** 2 + ((y - FLOOR_Y) / 9) ** 2
        if e < 1 and 0 <= x < W:
            a = 40 if e < 0.4 else 22 if e < 0.8 or (x + y) % 2 == 0 else 0
            if a:
                CP[x, y] = (190, 255, 240, max(CP[x, y][3], a))
cone.save(os.path.join(OUT, "lamp_cone.png"))
meta["lamp"] = {"bar": [LAMP_X, BAR_Y]}

# scientist placement: the template has frame 0 at 3x
P3 = L3.load()
pts = [(x, y) for y in range(H) for x in range(W) if P3[x, y][3]]
meta["scientist_bbox"] = [min(p[0] for p in pts), min(p[1] for p in pts)]

json.dump(meta, open(os.path.join(OUT, "menu_art.json"), "w"), indent=1)
print("drips", len(drips), "drop points", len(meta["drops"]), "title", meta["title"], "mound", meta["mound"])
