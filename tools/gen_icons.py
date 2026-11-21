"""Generate 32x32 item icons for MUTANT LAB (stdlib only: zlib + struct).

Writes assets/sprites/icons/<name>.png and a 4x contact sheet at
production/qa/evidence/icons_sheet.png. Run from the repo root:
    python tools/gen_icons.py
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "icons")
SHEET = os.path.join(ROOT, "production", "qa", "evidence", "icons_sheet.png")
S = 32

CLEAR = (0, 0, 0, 0)
OUTLINE = (22, 12, 30, 255)
WHITE = (248, 250, 236, 255)
GLASS = (176, 206, 214, 255)
GLASS_D = (104, 132, 146, 255)
TOXIC = (196, 240, 80, 255)
TOXIC_L = (236, 255, 170, 255)
GREEN = (72, 164, 98, 255)
GREEN_D = (34, 92, 62, 255)
GOLD = (236, 184, 56, 255)
GOLD_L = (255, 230, 130, 255)
GOLD_D = (166, 104, 30, 255)
AMBER = (240, 150, 40, 255)
PURPLE = (132, 52, 156, 255)
PURPLE_L = (190, 110, 214, 255)
PURPLE_D = (78, 28, 96, 255)
SKIN = (222, 172, 136, 255)
SKIN_L = (244, 204, 170, 255)
SKIN_D = (170, 116, 90, 255)
CYAN = (70, 200, 236, 255)
CYAN_L = (180, 240, 255, 255)
CYAN_D = (30, 110, 180, 255)
STEEL = (150, 164, 186, 255)
STEEL_L = (206, 216, 230, 255)
STEEL_D = (84, 96, 122, 255)
BLUE = (60, 100, 196, 255)
BLUE_D = (34, 56, 128, 255)
RED = (214, 64, 70, 255)
GREY = (120, 120, 132, 255)
GREY_D = (70, 70, 84, 255)


def write_png(path, rows):
    h = len(rows)
    w = len(rows[0])
    raw = bytearray()
    for r in rows:
        raw.append(0)
        for c in r:
            raw.extend(c)

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


class C:
    def __init__(self):
        self.px = [[CLEAR] * S for _ in range(S)]

    def put(self, x, y, c):
        if 0 <= x < S and 0 <= y < S:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(S):
            for x in range(S):
                if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0:
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for dy in range(width):
                for dx in range(width):
                    self.put(x + dx - width // 2, y + dy - width // 2, c)

    def poly(self, pts, c):
        for y in range(S):
            for x in range(S):
                px, py = x + 0.5, y + 0.5
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self.put(x, y, c)

    def outline(self):
        src = [row[:] for row in self.px]
        for y in range(S):
            for x in range(S):
                if src[y][x][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and src[ny][nx][3] and src[ny][nx] != OUTLINE:
                        self.px[y][x] = OUTLINE
                        break


def sparkle(c, x, y, col=WHITE, r=2):
    c.line(x - r, y, x + r, y, col)
    c.line(x, y - r, x, y + r, col)


def stabilizer():
    c = C()
    # diagonal syringe: barrel from (8,23) to (21,10)
    c.line(9, 22, 20, 11, GLASS_D, 7)
    c.line(9, 22, 20, 11, GLASS, 5)
    c.line(10, 21, 19, 12, TOXIC, 3)
    c.line(11, 20, 15, 16, TOXIC_L, 1)
    # plunger + handle
    c.line(21, 10, 26, 5, GREY, 2)
    c.line(23, 3, 28, 8, GREY_D, 2)
    c.line(19, 9, 22, 12, STEEL_D, 2)
    # needle
    c.line(7, 24, 3, 28, STEEL_L, 1)
    c.line(6, 23, 8, 25, STEEL, 2)
    c.outline()
    sparkle(c, 6, 13, TOXIC_L)
    c.put(26, 18, TOXIC_L)
    return c


def gold():
    c = C()
    for i, y in enumerate((24, 20, 16, 12)):
        x = 15 + (1 if i % 2 else 0)
        c.ellipse(x, y + 1, 9, 3, GOLD_D)
        c.ellipse(x, y, 9, 3, GOLD)
        c.ellipse(x, y, 6, 1, GOLD_L)
        c.rect(x - 2, y, x + 2, y, GOLD_D)
    c.ellipse(25, 26, 4, 3, GOLD_D)
    c.ellipse(25, 25, 4, 3, GOLD)
    c.put(25, 25, GOLD_L)
    c.outline()
    sparkle(c, 25, 6, GOLD_L)
    return c


def volunteer():
    c = C()
    # shoulders
    c.ellipse(13, 29, 10, 4, GREEN_D)
    c.ellipse(13, 29, 8, 3, GREEN)
    # neck
    c.rect(10, 21, 15, 25, SKIN_D)
    # head
    c.ellipse(13, 13, 8, 9, SKIN)
    c.ellipse(11, 10, 4, 4, SKIN_L)
    c.ellipse(21, 14, 1, 2, SKIN_D)
    c.ellipse(5, 14, 1, 2, SKIN_D)
    # eyes, mouth
    c.rect(9, 14, 10, 15, OUTLINE)
    c.rect(16, 14, 17, 15, OUTLINE)
    c.rect(11, 19, 15, 19, SKIN_D)
    # subject stitch mark
    c.line(9, 6, 13, 6, SKIN_D)
    c.outline()
    # plus sign
    c.rect(25, 2, 27, 10, OUTLINE)
    c.rect(22, 5, 30, 7, OUTLINE)
    c.rect(26, 3, 26, 9, TOXIC)
    c.rect(23, 6, 29, 6, TOXIC)
    return c


def cleanse():
    c = C()
    c.poly([(14, 2), (16, 2), (25, 17), (24, 24), (19, 29), (11, 29), (6, 24), (5, 17)], CYAN_D)
    c.poly([(15, 4), (23, 17), (22, 23), (18, 27), (12, 27), (8, 23), (7, 17)], CYAN)
    c.ellipse(11, 19, 2, 4, CYAN_L)
    c.put(12, 13, CYAN_L)
    c.put(13, 11, CYAN_L)
    c.outline()
    sparkle(c, 25, 7, WHITE, 3)
    c.put(28, 26, CYAN_L)
    return c


def lucky_gene():
    c = C()
    import math
    pts_a, pts_b = [], []
    for y in range(4, 29):
        t = (y - 4) / 24 * 2 * math.pi * 1.25
        pts_a.append((round(14 + 6 * math.sin(t)), y, math.cos(t)))
        pts_b.append((round(14 - 6 * math.sin(t)), y, -math.cos(t)))
    # rungs
    for i in range(1, len(pts_a), 3):
        xa, y, _ = pts_a[i]
        xb, _, _ = pts_b[i]
        c.line(min(xa, xb) + 1, y, max(xa, xb) - 1, y, GREEN if i % 2 else TOXIC)
    # back strands first, then front
    for front in (False, True):
        for (x, y, za), (xb, _, zb) in zip(pts_a, pts_b):
            if (za > 0) == front:
                c.rect(x - 1, y, x + 1, y, GOLD if front else GOLD_D)
            if (zb > 0) == front:
                c.rect(xb - 1, y, xb + 1, y, TOXIC if front else GREEN_D)
    c.outline()
    # star
    star = [(26, 1), (27, 4), (30, 4), (28, 6), (29, 9), (26, 7), (23, 9), (24, 6), (22, 4), (25, 4)]
    c.poly(star, GOLD_L)
    c.put(26, 5, WHITE)
    return c


def insurance():
    c = C()
    shape = [(4, 5), (16, 2), (28, 5), (27, 17), (22, 25), (16, 30), (10, 25), (5, 17)]
    c.poly(shape, STEEL_D)
    c.poly([(6, 7), (16, 4), (26, 7), (25, 17), (21, 23), (16, 28), (11, 23), (7, 17)], STEEL)
    c.poly([(8, 9), (16, 7), (24, 9), (23, 17), (20, 22), (16, 25), (12, 22), (9, 17)], BLUE)
    c.poly([(8, 9), (16, 7), (16, 25), (12, 22), (9, 17)], BLUE_D)
    c.line(7, 7, 15, 4, STEEL_L)
    # check mark
    c.line(11, 15, 14, 19, OUTLINE, 3)
    c.line(14, 19, 21, 11, OUTLINE, 3)
    c.line(11, 15, 14, 18, TOXIC, 1)
    c.line(14, 18, 20, 11, TOXIC, 1)
    c.line(12, 15, 14, 17, TOXIC, 1)
    c.outline()
    return c


def catalyst():
    c = C()
    # erlenmeyer flask
    c.rect(12, 3, 18, 4, GLASS_D)
    c.rect(13, 5, 17, 11, GLASS)
    c.poly([(12, 11), (19, 11), (27, 27), (25, 29), (6, 29), (4, 27)], GLASS)
    c.poly([(9, 18), (22, 18), (26, 27), (24, 28), (7, 28), (5, 27)], PURPLE)
    c.poly([(9, 18), (22, 18), (23, 20), (8, 20)], PURPLE_L)
    c.rect(14, 6, 14, 10, WHITE)
    c.ellipse(9, 25, 1, 1, PURPLE_L)
    c.ellipse(20, 23, 1, 1, PURPLE_D)
    c.outline()
    # lightning bolt, amber, overlapping the flask
    bolt = [(20, 8), (14, 19), (18, 19), (13, 29), (24, 16), (19, 16), (23, 8)]
    big = [(x + (1 if x > 18 else -1), y) for x, y in bolt]
    c.poly([(19, 7), (12, 20), (17, 20), (11, 31), (26, 15), (21, 15), (25, 7)], OUTLINE)
    c.poly(bolt, AMBER)
    c.line(20, 9, 16, 17, GOLD_L)
    _ = big
    return c


ICONS = {
    "stabilizer": stabilizer,
    "gold": gold,
    "volunteer": volunteer,
    "cleanse": cleanse,
    "lucky_gene": lucky_gene,
    "insurance": insurance,
    "catalyst": catalyst,
}


def main():
    imgs = []
    for name, fn in ICONS.items():
        c = fn()
        write_png(os.path.join(OUT, name + ".png"), c.px)
        imgs.append(c.px)
    # contact sheet: 4x and 1x row, dark lab background
    k, pad = 4, 8
    bg = (24, 20, 34, 255)
    w = pad + len(imgs) * (S * k + pad)
    h = pad + S * k + pad + S + pad + 2 * S + pad
    sheet = [[bg] * w for _ in range(h)]
    for i, img in enumerate(imgs):
        ox = pad + i * (S * k + pad)
        for y in range(S):
            for x in range(S):
                col = img[y][x]
                if col[3]:
                    for dy in range(k):
                        for dx in range(k):
                            sheet[pad + y * k + dy][ox + x * k + dx] = col
                    sheet[pad + S * k + pad + y][ox + x] = col
                    for dy in range(2):
                        for dx in range(2):
                            sheet[pad + S * k + pad + S + pad + y * 2 + dy][ox + S + 8 + x * 2 + dx] = col
    write_png(SHEET, sheet)
    print("wrote", len(imgs), "icons and", SHEET)


if __name__ == "__main__":
    main()
