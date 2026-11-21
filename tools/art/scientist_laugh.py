"""Polishes the mad scientist's laugh: 3 flat frames -> 6 shaded frames of cackling.

Usage: python tools/art/scientist_laugh.py <mad_scientist sheet.png (3 x 64x64)> <out dir>
Builds each frame from parts of the original (body from frame 0, head from frames 0/1/2), bobs the
head and body, squeezes the eyes shut on the big "HA"s, sweeps a glint over the glasses, then
shades everything in the lab's palette with coloured outlines.
"""
import os
import sys
from collections import Counter
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
FS = 64
sheet = Image.open(SRC).convert("RGBA")

K, W, S = (1, 1, 1, 255), (255, 255, 255, 255), (238, 195, 154, 255)
O, o, r = (215, 97, 16, 255), (155, 66, 6, 255), (167, 75, 12, 255)
P, p, g = (69, 40, 60, 255), (57, 29, 48, 255), (166, 160, 160, 255)
LENS, PUPIL, TONGUE = (247, 242, 242, 255), (48, 41, 41, 255), (130, 42, 42, 255)
GLINT, TEAR = (255, 255, 254, 255), (150, 210, 255, 255)   # marker colours, recoloured later
CLEAR = (0, 0, 0, 0)

HEAD_X = (19, 41)
LENSES = [(21, 27), (33, 39)]    # lens interior x ranges (head-local)
LENS_Y = (29, 34)


def frame(i, shift=0):
    im = sheet.crop((i * FS, 0, i * FS + FS, FS))
    if shift:
        moved = Image.new("RGBA", (FS, FS), CLEAR)
        moved.paste(im, (0, shift))
        im = moved
    return im.load()


SRC_FRAMES = {"grin": (frame(0), 42), "wide": (frame(1, 1), 45), "mid": (frame(2), 42)}
BODY = frame(0)


def is_head(x, y, chin):
    return y <= 32 or (HEAD_X[0] <= x <= HEAD_X[1] and y <= chin)


# (body dy, head dy relative to body, mouth, eyes squeezed, glint step or None, tear step or None)
PLAN = [
    (0, 0, "grin", False, 0, None),
    (-1, -1, "wide", False, 1, None),
    (-1, -1, "wide", True, 2, 0),
    (0, 0, "mid", True, None, 1),
    (-1, -1, "wide", True, None, 2),
    (0, 0, "grin", False, None, None),
]


def compose(body_dy, head_dy, mouth, squeeze, glint, tear):
    src, chin = SRC_FRAMES[mouth]
    px = {}            # (x, y) -> colour
    part = {}          # (x, y) -> ("head"|"body", local x, local y)
    for y in range(FS):
        for x in range(FS):
            c = BODY[x, y]
            if c[3] and not is_head(x, y, 42):
                px[(x, y + body_dy)] = c
                part[(x, y + body_dy)] = ("body", x, y)
    hy = body_dy + head_dy
    head = {}
    for y in range(FS):
        for x in range(FS):
            c = src[x, y]
            if c[3] and is_head(x, y, chin):
                head[(x, y)] = c
    if head_dy < 0:   # stretch the neck: repeat the head's bottom row into the gap
        for (x, y), c in list(head.items()):
            if (x, y + 1) not in head:
                for k in range(1, -head_dy + 1):
                    px[(x, y + hy + k)] = c
                    part[(x, y + hy + k)] = ("head", x, y)
    if squeeze:
        for x0, x1 in LENSES:
            for y in range(LENS_Y[0], LENS_Y[1] + 1):
                for x in range(x0, x1 + 1):
                    if head.get((x, y)) in (LENS, PUPIL):
                        head[(x, y)] = LENS
            mid = (x0 + x1) / 2
            for x in range(x0 + 1, x1):
                yy = 31 if abs(x - mid) < 2 else 32
                head[(x, yy)] = K
                head[(x, yy + 1)] = K if abs(x - mid) >= 2.5 else head[(x, yy + 1)]
    if glint is not None:
        for x0, _ in LENSES:
            gx = x0 + 1 + glint * 2
            for dx, dy in ((0, 0), (1, 0), (-1, 1), (0, 1)):
                if head.get((gx + dx, LENS_Y[0] + dy)) == LENS:
                    head[(gx + dx, LENS_Y[0] + dy)] = GLINT
    if tear is not None:
        for tx, side in ((19, -1), (41, 1)):
            ty = 33 + tear * 2
            head[(tx + side * (tear > 0), ty)] = TEAR
            head[(tx + side * (tear > 0), ty + 1)] = TEAR
    for (x, y), c in head.items():
        px[(x, y + hy)] = c
        part[(x, y + hy)] = ("head", x, y)
    return px, part


# ---------------- shading ----------------
OUTLINE_FOR = {"hair": (88, 30, 8), "skin": (112, 56, 44), "coat": (44, 56, 80), "shirt": (30, 16, 28)}
COAT, COAT_HI, COAT_FOLD, COAT_SHADE, COAT_LOW = (226, 234, 240), (246, 250, 252), (186, 200, 214), (146, 160, 178), (206, 216, 228)


def cls(c, info):
    kind, lx, ly = info
    if c in (O, o, r):
        return "hair"
    if c == S:
        return "skin"
    if c in (W, g):
        return "coat" if kind == "body" else "teeth"
    if c in (P, p):
        return "shirt"
    return None


def shade(px, part):
    out = Image.new("RGBA", (FS, FS), CLEAR)
    O_ = out.load()

    def at(x, y):
        return px.get((x, y), CLEAR)

    for (x, y), c in px.items():
        if not (0 <= x < FS and 0 <= y < FS):
            continue
        kind, lx, ly = part[(x, y)]
        up, down, left, right = at(x, y - 1), at(x, y + 1), at(x - 1, y), at(x + 1, y)
        edge = lambda q: q[3] == 0 or q == K
        col = c[:3]
        if c == K:
            if any(q[3] == 0 for q in (up, down, left, right)):
                votes = Counter()
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        q = at(x + dx, y + dy)
                        if q[3] and q != K:
                            k = cls(q, part[(x + dx, y + dy)])
                            if k in OUTLINE_FOR:
                                votes[k] += 1
                col = OUTLINE_FOR[votes.most_common(1)[0][0]] if votes else (20, 18, 26)
            elif kind == "body" and ly >= 59:
                col = (44, 40, 58)          # trousers
            else:
                col = (24, 14, 20)          # glasses frames, mouth lines
        elif c in (O, o, r):
            brow = kind == "head" and 22 <= lx <= 39 and 23 <= ly <= 28
            if brow:
                col = (150, 58, 12) if c == O else (104, 38, 8)
            elif c == o or edge(left) or edge(up):
                col = (250, 150, 58)       # lit edge (light comes from the top-left)
            elif left == o:
                col = (238, 122, 34)
            elif edge(right):
                col = (178, 70, 12)
            else:
                col = (222, 104, 20)
        elif c == S:
            col = (238, 195, 154)
            if kind == "head":
                if ly in (22, 23) or edge(down):
                    col = (214, 160, 128)
                elif (lx, ly) in ((20, 36), (21, 36), (39, 36), (40, 36)):
                    col = (238, 150, 128)
                elif (lx, ly) in ((29, 26), (30, 26), (29, 27)):
                    col = (250, 216, 182)
            else:
                if edge(down) or edge(right):
                    col = (214, 160, 128)
                elif edge(up) and edge(left):
                    col = (250, 216, 182)
        elif c in (W, g) and kind == "body":
            if c == g:
                col = COAT_SHADE
            elif any(q in (P, p) for q in (left, right, down)):
                col = COAT_FOLD
            elif edge(up):
                col = COAT_HI
            elif ly >= 55:
                col = COAT_LOW
            else:
                col = COAT
        elif c == W:
            col = (246, 244, 232)          # teeth
        elif c == P:
            col = (104, 64, 98) if lx == 29 else (78, 44, 72)
        elif c == p:
            col = (48, 24, 44)
        elif c == LENS:
            col = (214, 228, 232) if ly < 32 else (184, 204, 212)
        elif c == PUPIL:
            col = (40, 34, 44)
        elif c == TONGUE:
            col = (226, 104, 112) if edge(up) else (204, 72, 84)
        elif c == GLINT:
            col = (255, 255, 255)
        elif c == TEAR:
            col = (150, 210, 255)
        O_[x, y] = (*col, 255)
    return out


frames = [shade(*compose(*step)) for step in PLAN]
strip = Image.new("RGBA", (FS * len(frames), FS), CLEAR)
for i, im in enumerate(frames):
    im.save(os.path.join(OUT, f"laugh_{i}.png"))
    strip.alpha_composite(im, (i * FS, 0))
strip.save(os.path.join(OUT, "laugh_strip.png"))
print("frames", len(frames))
