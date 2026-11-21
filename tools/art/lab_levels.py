"""Builds lab_level_01..05.png: the polished lab with LEVEL 0N and damage that grows each level.

Usage: python tools/art/lab_levels.py <flat lab.png exported from lab.aseprite> <out dir>
Damage is painted into the flat art first (so the lab polish grades it), then danger overlays
(puddles, window cracks, red tint, scorch, shards) go on top.
"""
import math
import os
import random
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab_polish  # noqa: E402

SRC, OUT = sys.argv[1], sys.argv[2]
FLAT = Image.open(SRC).convert("RGBA")
W, H = FLAT.size
FLOOR_BOTTOM = H - 1

CREAM, CREAM_EDGE = (212, 211, 189, 255), (51, 49, 0, 255)
RED_FILL, RED_EDGE = (214, 64, 52, 255), (64, 8, 4, 255)
WALL = (118, 118, 118, 255)

# ---------------- digits (match the hand-drawn 0 and 1: 4 px strokes, 1 px outline) ----------------
DIGIT_X, DIGIT_Y = 433, 107
SKELETONS = {
    2: [[(1, 8), (1, 6), (2, 4), (3, 2), (5, 1), (7, 0), (9, 0), (11, 1), (13, 2), (14, 4), (15, 6), (15, 8),
         (14, 10), (13, 12), (1, 27)], [(1, 28), (16, 28)]],
    3: [[(1, 6), (2, 3), (4, 1), (7, 0), (10, 0), (13, 1), (15, 3), (15, 6), (14, 9), (12, 11), (9, 13), (7, 13)],
        [(9, 13), (12, 14), (14, 16), (15, 19), (15, 23), (14, 26), (12, 28), (9, 29), (6, 29), (3, 28), (1, 26), (0, 24)]],
    4: [[(12, 0), (0, 20)], [(0, 20), (16, 20)], [(12, 0), (12, 29)]],
    5: [[(15, 0), (2, 0)], [(2, 0), (1, 12)], [(1, 12), (4, 11), (8, 11), (11, 12), (14, 14), (15, 17), (15, 22),
         (14, 25), (12, 28), (9, 29), (6, 29), (3, 28), (1, 26), (0, 24)]],
}


def stamp_line(mask, a, b):
    steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
    for i in range(steps + 1):
        x = round(a[0] + (b[0] - a[0]) * i / steps)
        y = round(a[1] + (b[1] - a[1]) * i / steps)
        for dx in range(4):
            for dy in range(4):
                mask.add((x + dx, y + dy))


def draw_digit(P, n, fill, edge):
    for y in range(DIGIT_Y - 1, DIGIT_Y + 35):  # clear the old "1"
        for x in range(429, 457):
            if P[x, y] in (CREAM, CREAM_EDGE):
                P[x, y] = WALL
    mask = set()
    for path in SKELETONS[n]:
        for a, b in zip(path, path[1:]):
            stamp_line(mask, a, b)
    for (x, y) in mask:
        P[DIGIT_X + x, DIGIT_Y + y] = fill
    for (x, y) in mask:
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if q not in mask:
                P[DIGIT_X + q[0], DIGIT_Y + q[1]] = edge


def recolor_sign(P, fill, edge):
    for y in range(85, 142):
        for x in range(400, 464 if y < 103 else 458):
            if P[x, y] == CREAM:
                P[x, y] = fill
            elif P[x, y] in (CREAM_EDGE, (109, 108, 85, 255)):
                P[x, y] = edge


# ---------------- damage painted into the flat art ----------------
def scuff_stripe(P, rnd):
    for _ in range(28):
        x0, y0 = rnd.randint(140, 500), rnd.randint(190, 198)
        for dx in range(rnd.randint(2, 6)):
            for dy in range(rnd.randint(1, 3)):
                if 190 <= y0 + dy <= 200:
                    P[x0 + dx, y0 + dy] = (88, 86, 86, 255) if rnd.random() < 0.7 else (62, 60, 60, 255)


def claw_marks(P, x0, y0, n=3, length=24):
    for k in range(n):
        for i in range(length):
            x, y = x0 + k * 5 + i // 3, y0 + i
            P[x, y] = (58, 58, 58, 255)
            P[x + 1, y] = (66, 66, 66, 255)
            P[x - 1, y] = (150, 150, 150, 255)


def torn_panel(P, rnd):
    x0, y0, x1, y1 = 318, 122, 356, 168
    edge = {}
    for y in range(y0, y1):
        l, r = x0 + rnd.randint(0, 3), x1 - rnd.randint(0, 3)
        edge[y] = (l, r)
        for x in range(l, r):
            top = y - y0
            P[x, y] = (18, 18, 20, 255) if top < 3 else (34, 34, 36, 255)
        P[l - 1, y] = (168, 168, 168, 255)
        P[r, y] = (70, 70, 70, 255)
    for x in range(x0, x1):
        P[x, y1] = (168, 168, 168, 255)
        P[x, y0 - 1] = (70, 70, 70, 255)
    # bolts left in the frame
    for bx, by in ((x0 - 3, y0 + 2), (x1 + 2, y0 + 2), (x0 - 3, y1 - 2), (x1 + 2, y1 - 2)):
        P[bx, by] = (60, 60, 60, 255)
        P[bx - 1, by - 1] = (170, 170, 170, 255)
    # cables sagging out of the hole
    for (cy, sag, col) in ((130, 14, (170, 40, 40)), (136, 22, (190, 168, 44)), (142, 30, (52, 84, 166))):
        for x in range(x0 + 2, x1 - 2):
            t = (x - x0) / (x1 - x0)
            y = round(cy + sag * 4 * t * (1 - t))
            for dy in (0, 1):
                P[x, y + dy] = (*[max(0, c - 40 * dy) for c in col], 255)


# ---------------- overlays on the polished art ----------------
def new():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def checker(x, y):
    return (x + y) % 2 == 0


def loose_wire(P, x0, length):
    for i in range(length):
        x = x0 + round(3 * math.sin(i / 9))
        P[x, i] = (14, 16, 18, 255)
        P[x + 1, i] = (34, 38, 42, 255)
    x = x0 + round(3 * math.sin((length - 1) / 9))
    for i in range(3):
        P[x, length + i] = (214, 132, 60, 255)
        P[x + 1, length + i] = (150, 82, 36, 255)
    P[x + 2, length + 2] = (214, 132, 60, 255)


def puddle(P, cx, cy, rx, ry, seed, glow=True):
    rnd = random.Random(seed)
    s1, s2 = rnd.random() * 6, rnd.random() * 6
    inside = set()
    for y in range(int(cy - ry - 3), int(cy + ry + 4)):
        for x in range(int(cx - rx - 6), int(cx + rx + 7)):
            if y > FLOOR_BOTTOM:
                continue
            a = math.atan2((y - cy) / ry, (x - cx) / rx)
            r = 1 + 0.16 * math.sin(3 * a + s1) + 0.09 * math.sin(7 * a + s2)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < r * r:
                inside.add((x, y))
    if glow:
        for y in range(int(cy - ry - 8), int(cy + ry + 9)):
            for x in range(int(cx - rx - 12), int(cx + rx + 13)):
                if (x, y) in inside or not (0 <= x < W and 0 <= y <= FLOOR_BOTTOM):
                    continue
                d = ((x - cx) / (rx + 10)) ** 2 + ((y - cy) / (ry + 6)) ** 2
                if d < 1 and (d < 0.7 or checker(x, y)):
                    P[x, y] = (90, 255, 110, 40)
    for (x, y) in inside:
        rel = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
        c = (66, 168, 62) if rel > 0.55 else (104, 208, 76)
        if (x, y - 1) not in inside:
            c = (176, 248, 128)
        P[x, y] = (*c, 245)
    for (x, y) in inside:
        for q in ((x, y + 1), (x + 1, y), (x - 1, y)):
            if q not in inside and 0 <= q[0] < W and q[1] <= FLOOR_BOTTOM:
                P[q] = (22, 70, 34, 230)
    for k in range(max(1, int(rx // 10))):  # glints
        gx, gy = round(cx - rx * 0.4 + k * 7), round(cy - ry * 0.3)
        if (gx, gy) in inside:
            P[gx, gy] = (240, 255, 226, 255)
            P[gx + 1, gy] = (210, 255, 180, 255)
    return inside


def window_crack(P, base_px, cx, cy, rnd):
    glass = lambda x, y: base_px[x, y][:3] in ((109, 110, 112), (106, 107, 108))
    for k in range(7):
        ang = k * math.tau / 7 + rnd.uniform(-0.3, 0.3)
        length = rnd.randint(16, 34)
        x, y = float(cx), float(cy)
        for _ in range(length):
            ang += rnd.uniform(-0.25, 0.25)
            x += math.cos(ang)
            y += math.sin(ang)
            ix, iy = round(x), round(y)
            if glass(ix, iy):
                P[ix, iy] = (196, 226, 222, 220)
                if glass(ix + 1, iy + 1):
                    P[ix + 1, iy + 1] = (0, 0, 0, 120)
    for rr in (6, 13):  # ring fractures
        for a in range(0, 360, 4):
            if rnd.random() < 0.6:
                ix, iy = round(cx + rr * math.cos(math.radians(a))), round(cy + rr * 0.9 * math.sin(math.radians(a)))
                if glass(ix, iy):
                    P[ix, iy] = (170, 204, 200, 190)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            P[cx + dx, cy + dy] = (230, 250, 246, 240)


def red_tint(P, strength):
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 320) / 330, (y - 130) / 170)
            v = min(1.0, max(0.0, (d - 0.55) / 0.5)) * strength
            a = int(v // 16) * 16
            if (v % 16) / 16 > (bayer[y % 4][x % 4] + 0.5) / 16:
                a += 16
            if a and P[x, y][3] == 0:
                P[x, y] = (150, 12, 16, a)


def scorch(P, cx, cy, rnd, radius=11):
    for y in range(cy - radius, cy + radius * 2):
        for x in range(cx - radius, cx + radius + 1):
            d = math.hypot((x - cx) / radius, (y - cy) / (radius * 1.7))
            if d < 1 and rnd.random() < 1.15 - d:
                P[x, y] = (12, 10, 10, 150 if d < 0.5 else 95)


def shards(P, rnd, x0, x1, y0, y1, n=26):
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        size = rnd.choice((1, 1, 2, 3))
        for i in range(size):
            P[x + i, y - (i if rnd.random() < 0.5 else 0)] = (206, 244, 238, 255)
        P[x, y + 1] = (20, 40, 40, 200)


# ---------------- observation window (a live character stands behind the glass) ----------------
PANE = (109, 110, 112)          # main glass pane in the flat art
SILL = (106, 107, 108)          # darker strip along the bottom of the window


def window_glass(base_px):
    """Overlay drawn OVER whoever is in the window: a cold tint and reflection streaks."""
    im = new()
    P = im.load()
    for y in range(20, 140):
        for x in range(10, 115):
            if base_px[x, y][:3] in (PANE, SILL):
                st = (x + y * 0.6) % 64
                if 0 <= st < 3 or 7 <= st < 8:
                    P[x, y] = (186, 232, 226, 48)
                else:
                    P[x, y] = (12, 26, 30, 64)
    return im


def window_mask():
    """White where the main pane is: clips the character so the sill and frame hide the rest."""
    im = new()
    P = im.load()
    F = FLAT.load()
    for y in range(20, 140):
        for x in range(10, 115):
            if F[x, y][:3] == PANE:
                P[x, y] = (255, 255, 255, 255)
    return im


# ---------------- per-level build ----------------
LEVELS = 5
for level in range(1, LEVELS + 1):
    rnd = random.Random(100 + level)
    flat = FLAT.copy()
    FP = flat.load()
    if level >= 2:
        draw_digit(FP, level, CREAM, CREAM_EDGE)
    if level >= 3:
        scuff_stripe(FP, rnd)
        claw_marks(FP, 382, 154)
    if level >= 4:
        torn_panel(FP, rnd)
    if level == 5:
        recolor_sign(FP, RED_FILL, RED_EDGE)
        if level >= 2:
            draw_digit(FP, level, RED_FILL, RED_EDGE)

    layers = lab_polish.build_layers(flat, watcher=False)
    over = new()
    OP = over.load()
    glass = window_glass(flat.load())
    GP = glass.load()
    if level >= 2:
        loose_wire(OP, 392, 40)
        puddle(OP, 168, 232, 6, 2, seed=1, glow=False)
    if level >= 3:
        puddle(OP, 166, 236, 26 if level == 3 else 40, 5 if level == 3 else 8, seed=2)
    if level >= 4:
        window_crack(GP, flat.load(), 74, 62, rnd)
        puddle(OP, 470, 238, 24 if level == 4 else 44, 5 if level == 4 else 9, seed=3)
        red_tint(OP, 60 if level == 4 else 96)
    if level == 5:
        puddle(OP, 320, 250, 120, 12, seed=4)
        for cx, cy in ((393, 46), (500, 50), (214, 30)):
            scorch(OP, cx, cy, rnd)
        shards(OP, rnd, 112, 206, 226, 256)
    layers.append(("Danger", over))

    comp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for _, im in layers:
        comp.alpha_composite(im)
    comp.save(os.path.join(OUT, f"lab_level_{level:02d}.png"))
    glass.save(os.path.join(OUT, f"window_glass_{level:02d}.png"))
    print("level", level, "done")

window_mask().save(os.path.join(OUT, "window_mask.png"))
