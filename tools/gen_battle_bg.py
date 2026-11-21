"""Generate the 640x360 pixel-art lab arena background for Mutant Lab battles.

Standard library only (zlib + struct).
Usage (from project root):  python tools/gen_battle_bg.py
Writes assets/sprites/battle/arena_bg.png
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "battle", "arena_bg.png")
W, H = 640, 360
WALL_H = 150

WALL = (14, 28, 32)
WALL_L = (20, 38, 42)
SEAM = (8, 17, 20)
PIPE = (34, 58, 62)
PIPE_L = (62, 98, 96)
PIPE_D = (18, 32, 36)
RIVET = (88, 124, 118)
FLOOR_A = (22, 38, 42)
FLOOR_B = (27, 46, 50)
GROUT = (11, 21, 25)
GLASS = (46, 110, 86)
LIQ = (40, 170, 62)
LIQ_L = (110, 230, 96)
LIQ_D = (24, 110, 48)
BUBBLE = (170, 255, 150)
CAP = (52, 64, 68)
CAP_L = (88, 104, 106)
SHADOW = (9, 17, 20)
HAZARD = (170, 150, 40)


def noise(x, y):
    n = (x * 73856093) ^ (y * 19349663)
    n = (n ^ (n >> 13)) * 1274126177
    return (n ^ (n >> 16)) & 0xFF


img = [[WALL] * W for _ in range(H)]


def px(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = c


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            px(x, y, c)


# Wall panels
for y in range(WALL_H):
    for x in range(W):
        c = WALL if noise(x // 2, y // 2) > 20 else WALL_L
        if x % 80 in (0, 1):
            c = SEAM
        elif x % 80 == 2:
            c = WALL_L
        if y % 50 == 49:
            c = SEAM
        img[y][x] = c

# Ceiling pipe with rivets
rect(0, 0, W, 14, PIPE)
rect(0, 0, W, 2, PIPE_L)
rect(0, 12, W, 14, PIPE_D)
for x in range(10, W, 40):
    px(x, 6, RIVET)
    px(x + 1, 6, RIVET)

# Baseboard
rect(0, WALL_H - 6, W, WALL_H, PIPE_D)
rect(0, WALL_H - 6, W, WALL_H - 5, PIPE)
for x in range(0, W, 24):
    rect(x, WALL_H - 4, x + 12, WALL_H - 1, HAZARD if (x // 24) % 2 == 0 else PIPE_D)

# Vats
for cx in (70, 190, 320, 450, 570):
    x0, x1 = cx - 22, cx + 22
    top, bot = 28, WALL_H - 10
    rect(x0 - 3, top - 8, x1 + 3, top, CAP)
    rect(x0 - 3, top - 8, x1 + 3, top - 6, CAP_L)
    rect(x0 - 3, bot, x1 + 3, bot + 6, CAP)
    rect(x0 - 3, bot, x1 + 3, bot + 2, CAP_L)
    rect(x0 - 1, top, x1 + 1, bot, GLASS)
    liq_top = top + 14
    rect(x0 + 1, liq_top, x1 - 1, bot, LIQ)
    rect(x0 + 1, liq_top, x1 - 1, liq_top + 2, LIQ_L)
    rect(x0 + 1, bot - 8, x1 - 1, bot, LIQ_D)
    rect(x0 + 4, top + 2, x0 + 7, bot - 2, (150, 220, 190))
    for i in range(7):
        bx = x0 + 6 + (noise(cx, i) % (x1 - x0 - 12))
        by = liq_top + 6 + (noise(i, cx) % (bot - liq_top - 14))
        px(bx, by, BUBBLE)
        px(bx + 1, by, BUBBLE)
        px(bx, by + 1, BUBBLE)

# Floor
for y in range(WALL_H, H):
    for x in range(W):
        ty = (y - WALL_H) // 20
        tx = (x + (16 if ty % 2 else 0)) // 40
        c = FLOOR_A if (tx + ty) % 2 == 0 else FLOOR_B
        if noise(x, y) > 238:
            c = GROUT
        if (y - WALL_H) % 20 == 0 or (x + (16 if ty % 2 else 0)) % 40 == 0:
            c = GROUT
        img[y][x] = c

# Centre line (dashed) between the two sides
for y in range(WALL_H + 6, H, 14):
    rect(319, y, 321, y + 7, (60, 90, 70))

# Soft ellipse shadows under every spot (player x 80/160/240, enemy 400/480/560; rows y 180/268)
for sx in (80, 160, 240, 400, 480, 560):
    for sy in (180, 268):
        cy = sy + 28
        for dy in range(-4, 5):
            for dx in range(-16, 17):
                if (dx * dx) / 256.0 + (dy * dy) / 16.0 <= 1.0:
                    px(sx + dx, cy + dy, SHADOW)


def write_png(path, rows):
    h, w = len(rows), len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b in row:
            raw.extend((r, g, b, 255))

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


write_png(OUT, img)
print("wrote", OUT)
