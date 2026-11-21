"""Lab polish: turns the flat lab art into graded, lit, spooky layers (pure PIL, no numpy).

build_layers(base) -> [(name, RGBA image)] bottom to top: Graded, Details, Shadow, Light, Glow, Window, Ooze.
"""
import math
import random
from PIL import Image


def build_layers(base, watcher=True):
    """Returns the polish layers for a flat 640x267 lab image, bottom to top.

    watcher=False leaves the observation window as empty dark glass (no silhouette, eyes or
    reflections) so a live character can stand behind it with a glass overlay on top.
    """
    base = base.convert("RGBA")
    W, H = base.size
    B = base.load()


    def new():
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        return im, im.load()


    def lum(c):
        return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


    def checker(x, y):
        return (x + y) % 2 == 0


    # ---------- 1. Graded base: cool, sterile greys ----------
    RAMP = [(0, (8, 12, 16)), (40, (24, 32, 38)), (80, (52, 66, 72)), (120, (90, 108, 112)),
            (160, (146, 164, 164)), (210, (204, 220, 214)), (255, (240, 250, 245))]


    def ramp(l):
        for (l0, c0), (l1, c1) in zip(RAMP, RAMP[1:]):
            if l <= l1:
                t = (l - l0) / (l1 - l0)
                return tuple(round(a + (b - a) * t) for a, b in zip(c0, c1))
        return RAMP[-1][1]


    graded, G = new()
    for y in range(H):
        for x in range(W):
            c = B[x, y]
            if c[3] == 0:
                continue
            r = ramp(lum(c) * 0.94)
            if max(c[:3]) - min(c[:3]) < 20:
                G[x, y] = (*r, c[3])
            else:
                G[x, y] = (*(round(a * 0.8 + b * 0.2) for a, b in zip(c[:3], r)), c[3])

    # ---------- 2. Details: panel seams, rivets, floor tiles ----------
    details, D = new()
    BACKWALL = (118, 118, 118, 255)
    FLOOR = (142, 142, 141, 255)
    SEAM, SHINE = (20, 30, 36, 120), (210, 230, 228, 55)


    def put(px, x, y, c, mask=None):
        if 0 <= x < W and 0 <= y < H and (mask is None or B[x, y] == mask):
            px[x, y] = c


    for sx in (226, 414):
        for y in range(0, 190):
            put(D, sx, y, SEAM, BACKWALL)
            put(D, sx + 1, y, SHINE, BACKWALL)
    for x in range(136, 505):
        put(D, x, 108, SEAM, BACKWALL)
        put(D, x, 109, SHINE, BACKWALL)
    for sx in (226, 414):
        for ry in (104, 113):
            for dx in (-4, 5):
                put(D, sx + dx, ry, (30, 40, 46, 170), BACKWALL)
                put(D, sx + dx, ry - 1, (215, 232, 230, 90), BACKWALL)
    for rx in range(150, 500, 24):
        for ry in (104, 113):
            if abs(rx - 226) > 8 and abs(rx - 414) > 8:
                put(D, rx, ry, (30, 40, 46, 150), BACKWALL)
                put(D, rx, ry - 1, (215, 232, 230, 80), BACKWALL)

    VPX, VPY, BACK_Y = 320, 120, 226
    for y in range(BACK_Y, H):
        s = (y - VPY) / (BACK_Y - VPY)
        for k in range(-6, 17):
            x = round(VPX + (135 + 37 * k - VPX) * s)
            put(D, x, y, (30, 40, 46, 70), FLOOR)
    for t in (0.08, 0.16, 0.24):
        y = round(VPY + (BACK_Y - VPY) / (1 - t))
        for x in range(W):
            put(D, x, y, (30, 40, 46, 75), FLOOR)
            put(D, x, y + 1, (215, 232, 230, 35), FLOOR)

    # ---------- 3. Shadow: vignette, banded with dither ----------
    shadow, S = new()
    BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    STEP = 24
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 320) / 340, (y - 140) / 185)
            v = min(1.0, max(0.0, (d - 0.5) / 0.65)) ** 1.4 * 170
            if y < 18:
                v = min(215, v + (18 - y) * 4)
            a = int(v // STEP) * STEP
            if (v % STEP) / STEP > (BAYER[y % 4][x % 4] + 0.5) / 16:
                a += STEP
            if a:
                S[x, y] = (6, 8, 14, a)

    # ---------- 4. Light: lamp faces, cones, floor pools ----------
    light, L = new()
    COOL = (170, 255, 240)
    for x0, x1 in ((144, 278), (362, 496)):
        cx = (x0 + x1) / 2
        for y in range(64, 81):
            for x in range(x0, x1 + 1):
                if lum(B[x, y]) > 140:
                    L[x, y] = (215, 252, 246, 210)
        for y in range(81, 205):
            t = (y - 80) / 125
            half = (x1 - x0) / 2 + 40 * t
            for x in range(int(cx - half), int(cx + half) + 1):
                i = (1 - t) * math.sqrt(max(0.0, 1 - abs(x - cx) / half))
                a = 70 if i > 0.6 else 45 if i > 0.35 else 22 if i > 0.15 else (22 if i > 0.1 and checker(x, y) else 0)
                if a:
                    L[x, y] = (*COOL, a)
        for y in range(219, H):
            for x in range(int(cx - 100), int(cx + 101)):
                e = ((x - cx) / 95) ** 2 + ((y - 234) / 14) ** 2
                a = 45 if e < 0.45 else 24 if e < 1 else (24 if e < 1.2 and checker(x, y) else 0)
                if a and B[x, y][:3] in ((142, 142, 141), (127, 127, 125)):
                    L[x, y] = (*COOL, a)

    # ---------- 5. Glow: alarm and exit signs ----------
    glow, GL = new()
    for y in range(25, 78):
        for x in range(293, 346):
            r = math.hypot(x - 319, y - 51)
            a = 0 if r < 10.5 else 95 if r < 13 else 50 if r < 17 else (22 if r < 22 and checker(x, y) else 0)
            if a:
                GL[x, y] = (255, 40, 40, a)


    def is_green(c):
        return c[1] > c[0] + 25 and c[1] > c[2] - 10 and c[3] > 0


    for bx0, by0, bx1, by1 in ((50, 132, 90, 164), (548, 138, 588, 170)):
        sign = {(x, y) for y in range(by0, by1) for x in range(bx0, bx1) if is_green(B[x, y]) or (lum(B[x, y]) > 200 and bx0 + 3 < x < bx1 - 3)}
        for y in range(by0 - 8, by1 + 8):
            for x in range(bx0 - 8, bx1 + 8):
                if (x, y) in sign:
                    continue
                d = min(max(abs(x - sx), abs(y - sy)) for sx, sy in sign)
                a = 60 if d <= 2 else 28 if d <= 5 else (28 if d <= 7 and checker(x, y) else 0)
                if a:
                    GL[x, y] = (60, 255, 150, a)

    # ---------- 6. Window: dark glass, watcher, reflections ----------
    window, WN = new()
    glass = [(x, y) for y in range(26, 134) for x in range(16, 110) if B[x, y][:3] in ((109, 110, 112), (106, 107, 108))]
    for x, y in glass:
        t = (y - 30) / 100
        c = (10 + round(10 * t), 20 + round(14 * t), 24 + round(12 * t))
        if watcher:
            head = math.hypot(x - 60, y - 82) < 10
            body = ((x - 60) / 22) ** 2 + ((y - 112) / 16) ** 2 < 1
            if head or body:
                c = (4, 7, 9)
            st = (x + y * 0.6) % 64
            if 0 <= st < 3 or 7 <= st < 8:
                c = tuple(min(255, v + 34) for v in c)
        WN[x, y] = (*c, 255)
    for ex in ((55, 63) if watcher else ()):
        for gx in range(ex - 2, ex + 4):
            for gy in (80, 81, 82):
                WN[gx, gy] = (120, 255, 90, 70)
        WN[ex, 81] = (225, 255, 150, 255)
        WN[ex + 1, 81] = (190, 255, 110, 255)

    # ---------- 7. Ooze: green slime in and under the claw marks ----------
    ooze, OZ = new()
    SLIME, SLIME_HI, SLIME_LO = (104, 214, 72), (190, 255, 130), (34, 92, 40)
    random.seed(7)
    for (rx0, ry0, rx1, ry1), maxlen, n in (((257, 114, 300, 155), 26, 4), ((457, 158, 485, 182), 7, 2)):
        marks = [(x, y) for y in range(ry0, ry1) for x in range(rx0, rx1) if lum(B[x, y]) < 100]
        for x, y in marks:
            OZ[x, y] = (*SLIME_LO, 140)
        xs = sorted({x for x, _ in marks})[3:-3]
        for x in sorted(random.sample(xs, n)):
            top = max(y for mx, y in marks if mx == x)
            end = min(top + random.randint(maxlen // 4, maxlen), 188)
            for y in range(top, end):
                OZ[x, y] = (*SLIME, 230)
                OZ[x + 1, y] = (*SLIME_LO, 210)
            for dx in (-1, 0, 1, 2):
                OZ[x + dx, end] = (*SLIME_LO, 230)
            OZ[x, end] = (*SLIME, 255)
            OZ[x, end - 1] = (*SLIME_HI, 255)
            OZ[x, end + 1] = (*SLIME_LO, 230)
            OZ[x + 1, end + 1] = (*SLIME_LO, 230)

    layers = [("Graded", graded), ("Details", details), ("Shadow", shadow), ("Light", light),
              ("Glow", glow), ("Window", window), ("Ooze", ooze)]
    return layers
