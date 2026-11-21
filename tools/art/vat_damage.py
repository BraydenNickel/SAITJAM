"""Damaged brain vats from cylinder_polished.png (4 frames, 74x108 each).

Usage: python tools/art/vat_damage.py <cylinder_polished.png> <out dir>
Writes cylinder_hairline.png, cylinder_leaking.png, cylinder_shattered.png (same 4-frame sheet layout)
and frame PNGs (<name>_<f>.png) for building the .aseprite.
"""
import math
import os
import random
import sys
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
sheet = Image.open(SRC).convert("RGBA")
FW, FH, NF = 74, 108, 4
GL0, GL1 = 13, 61
LIQ0, LIQ1 = 28, 92
CRACK, CRACK_DARK = (226, 255, 240, 235), (6, 30, 16, 170)
SLIME, SLIME_HI, SLIME_LO = (104, 214, 72, 255), (190, 255, 130, 255), (34, 92, 40, 255)
GLASS, GLASS_EDGE = (190, 236, 230, 120), (232, 255, 250, 230)


def frames():
    return [sheet.crop((f * FW, 0, f * FW + FW, FH)) for f in range(NF)]


def is_brain(c):
    return c[3] == 255 and c[0] > c[1] + 30


def crack(P, x, y, rnd, branches=3, length=14, spread=0.9, base_angle=math.pi / 2):
    for b in range(branches):
        ang = base_angle + (b - (branches - 1) / 2) * spread + rnd.uniform(-0.2, 0.2)
        cx, cy = float(x), float(y)
        for _ in range(rnd.randint(length // 2, length)):
            ang += rnd.uniform(-0.35, 0.35)
            cx, cy = cx + math.cos(ang), cy + math.sin(ang)
            ix, iy = round(cx), round(cy)
            if GL0 + 1 <= ix <= GL1 - 1 and LIQ0 + 1 <= iy <= LIQ1 - 1 and not is_brain(P[ix, iy]):
                P[ix, iy] = CRACK
                if not is_brain(P[ix + 1, iy]):
                    P[ix + 1, iy] = CRACK_DARK


def hairline():
    out = []
    for f, im in enumerate(frames()):
        P = im.load()
        crack(P, 54, 40, random.Random(5), branches=2, length=16, spread=1.2, base_angle=2.2)
        out.append(im)
    return out


def leaking():
    out = []
    for f, im in enumerate(frames()):
        P = im.load()
        drop = 10  # slime level has dropped
        for y in range(LIQ0 - 4, LIQ0 + drop):
            for x in range(GL0 + 1, GL1):
                if not is_brain(P[x, y]) and P[x, y][3] > 0 and y >= LIQ0 - 1:
                    P[x, y] = (24, 46, 44, 110)
        for x in range(GL0 + 2, GL1 - 1):
            P[x, LIQ0 + drop] = (226, 255, 196, 255)
            P[x, LIQ0 + drop + 1] = (150, 238, 104, 235)
        rnd = random.Random(9)
        crack(P, 58, 70, rnd, branches=4, length=18, spread=0.8, base_angle=math.pi)
        crack(P, 50, 46, rnd, branches=2, length=12, spread=1.0, base_angle=2.4)
        # hole and leak stream down the outside of the glass
        for dy in range(-1, 2):
            P[GL1 - 1, 70 + dy] = (12, 40, 20, 255)
            P[GL1, 70 + dy] = SLIME
        for y in range(70, FH):
            x = GL1 + 1 + (1 if y > 80 else 0) + (1 if y > 92 else 0)
            P[x, y] = SLIME
            P[x + 1, y] = SLIME_LO
            if (y - 70 + f * 3) % 9 == 0:
                P[x, y] = SLIME_HI
        # a drop falling beside the stream
        dy = 76 + f * 7
        for y in (dy, dy + 1):
            for x in (GL1 + 4, GL1 + 5):
                if y < FH:
                    P[x, y] = SLIME if y == dy else SLIME_LO
        out.append(im)
    return out


def shattered():
    out = []
    rnd = random.Random(21)

    def jagged(valley, peak_lo, peak_hi):
        """Edge heights per column: straight lines between alternating peaks and valleys."""
        pts, x, up = [], GL0, False
        while x <= GL1 + 8:
            pts.append((x, rnd.randint(peak_lo, peak_hi) if up else valley + rnd.randint(-2, 2)))
            x += rnd.randint(4, 9)
            up = not up
        heights = []
        for cx in range(GL0, GL1 + 1):
            for (x0, h0), (x1, h1) in zip(pts, pts[1:]):
                if x0 <= cx <= x1:
                    heights.append(round(h0 + (h1 - h0) * (cx - x0) / (x1 - x0)))
                    break
        return heights

    bottom_teeth = jagged(86, 58, 76)   # shards standing up from the base
    top_teeth = jagged(31, 38, 52)      # shards hanging from the lid
    for f, im in enumerate(frames()):
        P = im.load()
        for x in range(GL0, GL1 + 1):
            i = min(x - GL0, len(bottom_teeth) - 1)
            for y in range(LIQ0 - 1, LIQ1 + 1):
                if top_teeth[i] <= y <= bottom_teeth[i]:
                    P[x, y] = (0, 0, 0, 0)             # glass gone, brain gone
                elif y < top_teeth[i] or y > bottom_teeth[i]:
                    edge = y == top_teeth[i] - 1 or y == bottom_teeth[i] + 1
                    if y > bottom_teeth[i] and y > 84:
                        P[x, y] = SLIME_LO if y > 88 else SLIME   # residue in the bottom
                    else:
                        P[x, y] = GLASS_EDGE if edge else GLASS
        # slime residue surface and a drip falling from the top shards
        for x in range(GL0 + 1, GL1):
            if P[x, 85][3]:
                P[x, 85] = SLIME_HI
        dx = 36
        tip = top_teeth[dx - GL0]
        P[dx, tip] = SLIME
        y = tip + 2 + f * 11
        if y + 1 < 84:
            P[dx, y] = SLIME_HI
            P[dx, y + 1] = SLIME
        out.append(im)
    return out


for name, ims in (("hairline", hairline()), ("leaking", leaking()), ("shattered", shattered())):
    sh = Image.new("RGBA", (FW * NF, FH), (0, 0, 0, 0))
    for f, im in enumerate(ims):
        sh.alpha_composite(im, (f * FW, 0))
        im.save(os.path.join(OUT, f"{name}_{f}.png"))
    sh.save(os.path.join(OUT, f"cylinder_{name}.png"))
    print("wrote", name)
