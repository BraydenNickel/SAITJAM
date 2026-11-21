"""Parametric mutation part + ULTRA body generator for Mutant Lab (stage 4).

Standard library only. Driven by tools/mutation_table.py; reuses the PNG I/O and
the base-coordinate Part canvas from tools/gen_parts.py.

Regenerate everything (6 hand-made parts, 94 table parts x 2 views, 8 ultra
bodies x 2 views, preview sheets) from the project root with:

    python tools/gen_parts.py

Outputs
  assets/sprites/parts/<id>_front.png, <id>_side.png        32x32, centred on socket
  assets/sprites/torso/body_<id>_front.png, _side.png       64x64, ULTRA bodies
  production/qa/evidence/stage4_parts_front_4x.png, stage4_parts_side_4x.png,
  production/qa/evidence/stage4_ultra_bodies_4x.png         contact sheets (not assets)

One drawer per (socket, motif); each handles both views. A drawer gets the
entry's colours (dark, mid, light, accent), a seed from zlib.crc32(id) and `k`,
the ordinal of the entry inside its (socket, motif) group, so mutations sharing
a motif get a different sub-style as well as different seeded proportions.
Set GEN_PARTS_DEBUG=<dir> to also write one 4x sheet per socket there.
"""
import math
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_parts as g  # noqa: E402
from mutation_table import MUTATIONS  # noqa: E402

EVIDENCE_DIR = os.path.join(g.ROOT, "production", "qa", "evidence")
SOCKET_ORDER = ["HEAD", "TORSO", "BACK", "ARM", "LEG", "TAIL"]
FRONT_SLOT = {"ARM": "ARM_L", "LEG": "LEG_L"}
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def hexc(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def bez(p0, p1, p2, n=10):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return out


def pol(cx, cy, ang, rad):
    """Polar point; 0 deg = right, 90 deg = up (screen y is down)."""
    a = math.radians(ang)
    return (cx + math.cos(a) * rad, cy - math.sin(a) * rad)


def ri(v):
    return int(round(v))


class XPart(g.Part):
    """Part canvas with a palette, a seeded rng and richer primitives."""

    def __init__(self, view, slot, cols, accent, seed, k, mid, base):
        super().__init__(g.SOCKETS[view][slot])
        self.D, self.M, self.L = cols
        self.A = accent
        self.DD = mix(self.D, BLACK, 0.5)
        self.r = random.Random(seed)
        self.seed, self.k, self.id, self.base = seed, k, mid, base

    def put(self, x, y, c):
        super().put(ri(x), ri(y), c)

    def get(self, x, y):
        return super().get(ri(x), ri(y))

    def rect(self, x0, y0, x1, y1, c):
        super().rect(ri(x0), ri(y0), ri(x1), ri(y1), c)

    def ln(self, x0, y0, x1, y1, c, w=1):
        self.line(ri(x0), ri(y0), ri(x1), ri(y1), c, w)

    def path(self, pts, c, w=1):
        for a, b in zip(pts, pts[1:]):
            self.ln(a[0], a[1], b[0], b[1], c, w)

    def thin(self, pts):
        """1 px mid-colour polyline with a dark shadow line on its right."""
        self.path([(x + 1, y) for x, y in pts], self.D)
        self.path(pts, self.M)

    def on_body(self, x, y):
        x, y = ri(x), ri(y)
        return 0 <= x < 64 and 0 <= y < 64 and self.base[y][x][3] > 0

    def fill_body(self, x0, y0, x1, y1, c, test=None):
        for y in range(ri(y0), ri(y1) + 1):
            for x in range(ri(x0), ri(x1) + 1):
                if self.on_body(x, y) and (test is None or test(x, y)):
                    self.put(x, y, c)

    def disc(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c)

    def limb(self, pts, r0, r1, c=None):
        """Thick polyline whose radius tapers from r0 to r1."""
        c = c or self.M
        segs, total = [], 0.0
        for a, b in zip(pts, pts[1:]):
            l = math.hypot(b[0] - a[0], b[1] - a[1])
            segs.append((a, b, l))
            total += l
        total = total or 1.0
        acc = 0.0
        for a, b, l in segs:
            n = max(1, int(l * 2))
            for i in range(n + 1):
                t = i / n
                rr = r0 + (r1 - r0) * ((acc + l * t) / total)
                self.ellipse(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, rr, rr, c)
            acc += l

    def poly(self, pts, c=None):
        c = c or self.M
        ys = [q[1] for q in pts]
        edges = list(zip(pts, pts[1:] + pts[:1]))
        for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
            xs = []
            for (x0, y0), (x1, y1) in edges:
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                for x in range(int(math.ceil(a)), int(math.floor(b)) + 1):
                    self.put(x, y, c)
        for a, b in edges:
            self.ln(a[0], a[1], b[0], b[1], c)

    def spike(self, b, t, w, c=None):
        dx, dy = t[0] - b[0], t[1] - b[1]
        l = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / l * w / 2, dx / l * w / 2
        self.poly([(b[0] + nx, b[1] + ny), t, (b[0] - nx, b[1] - ny)], c)

    def shade(self, extra=()):
        """Dark inner outline on mid (and `extra`) pixels + light rim top-left on mid."""
        S = g.PART_SIZE
        src = [row[:] for row in self.px]

        def op(x, y):
            return 0 <= x < S and 0 <= y < S and src[y][x][3] > 0

        def edge(x, y):
            return op(x, y) and not (op(x - 1, y) and op(x + 1, y) and op(x, y - 1) and op(x, y + 1))

        for y in range(S):
            for x in range(S):
                c = src[y][x]
                if c != self.M and c not in extra:
                    continue
                if edge(x, y):
                    self.px[y][x] = self.D
                elif c == self.M and (not op(x - 1, y - 1) or edge(x - 1, y - 1)):
                    self.px[y][x] = self.L


# ==========================================================================
# HEAD   front: head x21..42 y3..21, eyes (26,13) (35,13)
#        side:  head x21..45 y7..31, eye (43,18), mouth y25, faces right
# ==========================================================================
def h_maw(p, F):
    r = p.r
    w, n, o = r.choice((5, 6)), r.randint(3, 5), r.choice((2, 3))
    if F:
        cx, cy = 31.5, 18
        p.ellipse(cx, cy, w + 1.5, o + 2, p.M)
        for s in (-1, 1):
            p.spike((cx + s * (w + 1), cy + 1), (cx + s * (w - 2), cy + o + 5), 3, p.M)
        p.shade()
        p.ellipse(cx, cy, w - 0.5, o - 0.5, p.DD)
        for i in range(n):
            x = cx - (w - 2) + i * 2 * (w - 2) / (n - 1)
            p.put(x, cy - o + 1, p.A)
            p.put(x, cy + o - 1, p.A)
    else:
        p.ellipse(43, 25, 5, 4.5, p.M)
        p.spike((44, 28), (47, 33), 3, p.M)
        p.shade()
        p.poly([(41, 25), (49, 25 - o), (49, 25 + o)], p.DD)
        for i in range(n):
            x = 43 + i * 5 / (n - 1)
            t = (x - 41) / 8 * o
            p.put(x, 25 - t, p.A)
            p.put(x, 25 + t, p.A)


def h_horns(p, F):
    r = p.r
    style, ln = p.k % 3, r.randint(0, 2)
    if F:
        if style == 0:
            pts = bez((24, 6), (14, 1), (17, 11)) + [(20, 13)]
            r0 = 2.2
        elif style == 1:
            pts = bez((23, 8), (15, 8), (18, -1 - ln))
            r0 = 2.0
        else:
            pts = bez((26, 5), (22, 2), (24 - ln, -3))
            r0 = 1.8
        p.limb(pts, r0, 0.3)
        p.shade()
        p.put(pts[-1][0], pts[-1][1], p.A)
        p.put(pts[-2][0], pts[-2][1], p.A)
        p.mirror_x(63)
    else:
        if style == 0:
            pts = bez((29, 10), (17, 7), (22, 19)) + [(25, 21)]
            r0 = 2.5
        elif style == 1:
            pts = bez((36, 10), (39, 2), (47, 4 - ln * 0.5))
            r0 = 2.0
        else:
            pts = bez((31, 10), (28, 4), (22 - ln, 3))
            r0 = 2.0
        p.limb(pts, r0, 0.3)
        p.shade()
        p.put(pts[-1][0], pts[-1][1], p.A)
        p.put(pts[-2][0], pts[-2][1], p.A)


def _eye(p, cx, cy, rad):
    p.ellipse(cx, cy, rad, rad, p.D)
    if rad >= 2.5:
        p.ellipse(cx, cy, rad - 1, rad - 1, p.L)
        p.ellipse(cx, cy, rad - 2, rad - 2, p.A)
        p.rect(cx - 0.5, cy - 0.5, cx + 0.5, cy + 0.5, p.DD)
        p.put(cx - rad + 1.5, cy - rad + 1.5, WHITE)
    else:
        p.ellipse(cx, cy, rad - 1, rad - 1, p.A)
        p.put(cx, cy, p.DD)


def h_eyes(p, F):
    r = p.r
    n, big, cyc = r.randint(2, 4), r.choice((2.5, 3)), p.k % 2 == 1
    if F:
        extra = [(31.5, 7), (26, 7), (37, 7), (31.5, 18), (24, 18), (39, 18)]
        if cyc:
            _eye(p, 31.5, 12, 4.5)
            extra = extra[3:] + [(24, 7), (39, 7)]
        else:
            _eye(p, 26.5, 13, big)
            _eye(p, 35.5, 13, big)
        for i in range(n):
            x, y = extra[(i + p.seed) % len(extra)] if not cyc else extra[i % len(extra)]
            _eye(p, x, y, 1.5)
    else:
        extra = [(36, 12), (32, 18), (37, 22), (29, 12), (27, 20)]
        if cyc:
            _eye(p, 41, 17, 4)
            extra = extra[1:]
        else:
            _eye(p, 42.5, 18, big)
        for i in range(n):
            x, y = extra[i % len(extra)]
            _eye(p, x, y, 1.5)


def h_crest(p, F):
    r = p.r
    n, h, style = r.randint(3, 5), r.randint(5, 7), p.k % 2
    if F:
        if style == 0:
            p.poly([(26, 6), (29, 5 - h), (31.5, 3 - h), (34, 5 - h), (37, 6)])
            p.shade()
            for x in (29, 31.5, 34):
                p.ln(x, 5, 31.5 + (x - 31.5) * 0.5, 5 - h, p.D)
            p.put(31, 3 - h, p.A)
            p.put(32, 3 - h, p.A)
        else:
            tips = []
            for i in range(n):
                a = 50 + i * 80 / (n - 1)
                tip = pol(31.5, 12, a, 10 + h * (0.6 + 0.4 * math.sin(math.radians(a))))
                p.spike(pol(31.5, 12, a, 8), tip, 4)
                tips.append(tip)
            p.shade()
            for t in tips:
                p.put(t[0], t[1], p.A)
    else:
        hh = min(h, 5)
        if style == 0:
            inner = [pol(33, 19, a, 11) for a in range(60, 156, 8)]
            outer = [pol(33, 19, a, 11 + hh * math.sin(math.pi * (a - 60) / 95) + 0.5)
                     for a in range(60, 156, 8)]
            p.poly(inner + outer[::-1])
            p.shade()
            for i in range(1, len(inner) - 1, 2):
                p.ln(inner[i][0], inner[i][1], outer[i][0], outer[i][1], p.D)
            mid = outer[len(outer) // 2]
            p.put(mid[0], mid[1], p.A)
            p.put(mid[0] + 1, mid[1], p.A)
        else:
            tips = []
            for i in range(n + 1):
                a = 60 + i * 90 / n
                tip = pol(33, 19, a, 12 + hh * (0.6 + 0.4 * ((i + 1) % 2)))
                p.spike(pol(33, 19, a, 11), tip, 4)
                tips.append(tip)
            p.shade()
            for t in tips:
                p.put(t[0], t[1], p.A)


def h_antennae(p, F):
    r = p.r
    style, ln = p.k % 3, r.randint(0, 2)
    crown = "crown" in p.id

    def ant(x0, y0, d, top):
        # d = +1 leans right, -1 leans left; top = highest y allowed
        if style == 0:
            pts = [(x0, y0), (x0 + d * 2, y0 - 3), (x0 + d * (5 + ln), top)]
        elif style == 1:
            pts = [(x0, y0), (x0 + d * 3, y0 - 2), (x0 + d * 1, y0 - 4), (x0 + d * (4 + ln), top)]
        else:
            pts = bez((x0, y0), (x0 + d * 3, top - 2), (x0 + d * (7 + ln), top + 1), 6)
            pts.append((x0 + d * (6 + ln), top + 3))
        p.thin(pts)
        tx, ty = pts[-1]
        p.ellipse(tx, ty, 1, 1, p.A)
        p.put(tx + 1, ty + 1, p.D)

    if F:
        ant(27, 5, -1, -2)
        if crown:
            p.rect(24, 2, 31, 5, p.M)
            for x in (24, 27, 30):
                p.rect(x, 0, x + 1, 1, p.M)
            p.shade()
            p.rect(25, 4, 31, 4, p.L)
            p.put(27, 3, p.A)
            p.put(31, 3, p.A)
        p.mirror_x(63)
    else:
        ant(37, 9, 1, 3)
        ant(33, 9, -1, 3)
        if crown:
            p.rect(26, 7, 40, 10, p.M)
            for x in (26, 30, 34, 38):
                p.rect(x, 5, x + 1, 6, p.M)
            p.shade()
            p.rect(27, 9, 39, 9, p.L)
            for x in (29, 33, 37):
                p.put(x, 8, p.A)


def h_beak(p, F):
    r = p.r
    ln = r.randint(0, 2)
    if F:
        p.poly([(26, 14), (37, 14), (34, 20 + ln), (31.5, 23 + ln), (29, 20 + ln)])
        p.shade()
        p.put(30, 16, p.DD)
        p.put(33, 16, p.DD)
        p.ln(28, 19, 35, 19, p.D)
        p.put(31, 22 + ln, p.A)
        p.put(32, 22 + ln, p.A)
    else:
        p.poly([(40, 15), (45, 16), (49, 21), (48, 25 + ln), (46, 23), (40, 23)])
        p.poly([(40, 24), (46, 24), (44, 27), (40, 27)])
        p.shade()
        p.ln(41, 23, 46, 23, p.DD)
        p.put(43, 18, p.DD)
        p.put(48, 24 + ln, p.A)
        p.put(48, 23 + ln, p.A)


def h_skull(p, F):
    r = p.r
    style, crack = p.k % 2, r.randint(-3, 3)
    if F:
        p.fill_body(21, 3, 42, 21 if style == 0 else 18, p.M)
        if style == 1:
            p.spike((23, 5), (19, 0), 4)
            p.spike((40, 5), (44, 0), 4)
        p.shade()
        for cx in (26.5, 35.5):
            p.ellipse(cx, 13, 2.5, 2.5, p.DD)
            p.rect(cx - 0.5, 13, cx + 0.5, 14, p.A)
        p.rect(31, 16, 32, 17, p.DD)
        ty = 19 if style == 0 else 17
        for x in range(26, 38):
            p.put(x, ty - 1, p.D)
            p.put(x, ty, p.L if x % 2 else p.DD)
            p.put(x, ty + 1, p.L if x % 2 else p.DD)
        p.path([(31 + crack, 4), (30 + crack, 6), (32 + crack, 8), (31 + crack, 10)], p.D)
    else:
        p.fill_body(21, 7, 45, 31 if style == 0 else 27, p.M)
        if style == 1:
            p.spike((30, 9), (25, 3), 4)
        p.shade()
        p.ellipse(42, 18.5, 2.5, 2.5, p.DD)
        p.rect(42, 18, 43, 19, p.A)
        p.put(44, 22, p.DD)
        p.put(45, 22, p.DD)
        p.ln(35, 24, 44, 24, p.D)
        for x in range(37, 45):
            p.put(x, 25, p.L if x % 2 else p.DD)
            p.put(x, 26, p.L if x % 2 else p.DD)
        p.path([(32, 8), (31 + crack, 11), (33, 13), (31, 16)], p.D)


def h_tentacles(p, F):
    r = p.r
    n, ln = r.randint(3, 5), r.randint(0, 2)
    ph = [r.choice((-1, 1)) for _ in range(6)]
    dots = []
    if p.k % 2 == 1:
        if F:
            p.ellipse(31.5, 3.5, 11.5, 3.5, p.M)
            xs, y0 = (19, 22, 41, 44), 5
        else:
            p.ellipse(33, 9, 12, 3.5, p.M)
            xs, y0 = (20, 23, 27, 46), 10
        for i, x0 in enumerate(xs):
            end = y0 + 9 + ln * 2 + (4 if i % 2 else 0)
            pts = [(x0, y0), (x0 + ph[i], y0 + 4), (x0 - ph[i], y0 + 8), (x0, end)]
            p.limb(pts, 1.4, 0.4)
            dots.append(pts[2])
            dots.append(pts[3])
        p.shade()
        for x in ((26, 31, 37) if F else (27, 33, 39)):
            p.put(x, y0 - 3, p.A)
    elif F:
        p.ellipse(31.5, 17, 5.5, 2.5, p.M)
        for i in range(n):
            x0 = 27 + i * 9 / (n - 1)
            s = ph[i] * 1.5
            end = 25 + ln - (0 if i % 2 else 2)
            pts = [(x0, 17), (x0 + s, 20), (x0 - s, 23), (x0 + s * 0.5, min(end, 27))]
            p.limb(pts, 1.4, 0.4)
            dots.append(pts[2])
        p.shade()
    else:
        p.ellipse(42, 24, 3.5, 2.5, p.M)
        for i in range(n):
            x0 = 39 + i * 6 / (n - 1)
            s = ph[i] * 1.5
            end = 31 + ln - (0 if i % 2 else 2)
            pts = [(x0, 24), (x0 + 1 + s, 27), (x0 + 1 - s, 30), (x0 + 2, min(end, 33))]
            p.limb(pts, 1.4, 0.4)
            dots.append(pts[2])
        p.shade()
    for x, y in dots:
        p.put(x, y, p.A)


def h_halo(p, F):
    style = p.k % 2
    cx, cy, rx, ry = (31.5, -0.5, 9, 3) if F else (33, 4.5, 10, 2.5)
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            do = ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2
            di = ((x - cx) / (rx - 1.5)) ** 2 + ((y - cy) / (ry - 1.2)) ** 2
            if do <= 1.0 < di:
                p.put(x, y, p.L if y >= cy else p.M)
    for y in range(int(cy), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if p.get(x, y) == p.L and not p.get(x, y + 1)[3]:
                p.put(x, y + 1, p.D)
    p.put(cx - rx + 1, cy, p.A)
    p.put(cx + 3, cy + ry, p.A)
    p.put(cx - 2, cy + ry, WHITE)
    if style == 1:
        for s in (-1, 1):
            p.ln(cx + s * (rx + 1), cy, cx + s * (rx + 3), cy - 2, p.A)
            p.put(cx + s * 4, cy - ry - 1, p.A)
        p.put(cx, cy - ry - 1, p.A)


# ==========================================================================
# TORSO  front: shoulders y25..32 x16..47, trunk x24..39 y33..46
#        side:  x28..40 y32..50
# ==========================================================================
def t_plates(p, F):
    r = p.r
    h = r.choice((3, 4))
    if F:
        y = 26
        while y < 44:
            for yy in range(y, min(y + h, 46)):
                c = p.L if yy == y else (p.D if yy == y + h - 1 else p.M)
                p.fill_body(24, yy, 39, yy, c, lambda x, _y: 24 <= x <= 39)
            p.put(25, y + 1, p.A)
            p.put(38, y + 1, p.A)
            y += h
        p.rect(31, 26, 32, 44, p.D)
        p.ellipse(19.5, 27.5, 3.5, 2.5, p.M)
        p.ellipse(43.5, 27.5, 3.5, 2.5, p.M)
        p.shade()
    else:
        y = 33
        while y < 48:
            for yy in range(y, y + h):
                c = p.L if yy == y else (p.D if yy == y + h - 1 else p.M)
                p.fill_body(33, yy, 41, yy, c)
            p.put(39, y + 1, p.A)
            y += h
        p.ellipse(33, 34, 4.5, 2.5, p.M)
        p.shade()


def t_ribs(p, F):
    r = p.r
    n, style = r.randint(3, 4), p.k % 3
    if F:
        if style != 1:
            p.ellipse(31.5, 33, 6.5, 2 + n * 1.5, p.DD)
            p.ellipse(31.5 + (1 if style == 2 else -1), 32, 1.5, 1.5, p.A)
        if style == 2:
            p.ellipse(31.5, 32, 2.5, 2.5, p.A)
            p.ellipse(31, 31.5, 1, 1, WHITE)
        for i in range(n):
            y = 28 + i * 3
            if style == 1:
                y = 27 + i * 4
                p.ln(23, y, 28, y + 1, p.L)
                p.ln(23, y + 1, 28, y + 2, p.M)
                p.ln(24, y + 2, 28, y + 3, p.D)
                p.put(29, y + 2, p.A)
                p.put(30, y + 3, p.A)
            elif style == 2 and i >= 2:
                p.ln(25, y + 1, 27, y, p.L)
            else:
                p.ln(25, y + 1, 28, y, p.L)
                p.ln(28, y, 31, y, p.L)
                p.put(25, y + 2, p.M)
        p.mirror_x(63)
        if style != 1:
            p.rect(31, 26, 32, 27 + n * 3, p.M)
            p.rect(31, 26, 31, 27 + n * 3, p.L)
    else:
        if style != 1:
            p.ellipse(37, 40, 3.5, 2 + n * 1.5, p.DD)
            p.ellipse(38, 38, 1, 1, p.A)
        for i in range(n):
            y = 35 + i * 3
            if style == 2 and i >= 2:
                p.ln(33, y, 36, y, p.L)
                continue
            p.ln(33, y, 40, y, p.L)
            p.put(41, y - 1, p.L)
            p.ln(33, y + 1, 39, y + 1, p.M if style == 1 else p.D)
            if style == 1:
                p.ln(34, y + 2, 39, y + 2, p.D)
                p.put(42, y - 1, p.A)
                p.put(43, y - 2, p.A)


def t_core(p, F):
    r = p.r
    shape, s, n = p.k % 5, r.choice((3, 4)), r.randint(2, 4)
    if F:
        cx, cy = 31.5, 32
        targets = [(24, 27), (39, 27), (25, 39), (38, 39), (31, 43), (32, 25)]
        r.shuffle(targets)
        for tx, ty in targets[:n + 1]:
            mx, my = (cx + tx) / 2 + r.choice((-1, 0, 1)), (cy + ty) / 2
            p.path([(cx, cy), (mx, my), (tx, ty)], p.M)
            p.put(tx, ty, p.D)
    else:
        cx, cy, s = 39, 39, s - 1
        for tx, ty in ((33, 34), (33, 44), (35, 39))[:n]:
            p.path([(cx, cy), (tx, ty)], p.M)
            p.put(tx, ty, p.D)
    if shape == 0:
        p.ellipse(cx, cy, s + 1, s + 1, p.D)
        p.ellipse(cx, cy, s, s, p.M)
        p.ellipse(cx, cy, s - 1.5, s - 1.5, p.L)
        p.rect(cx - 0.5, cy - 0.5, cx + 0.5, cy + 0.5, p.A)
        p.put(cx - s + 1.5, cy - s + 1.5, p.A)
    elif shape == 1:
        for k, c in ((s + 2, p.D), (s + 1, p.M), (s - 1, p.L), (s - 3, p.A)):
            if k >= 0:
                p.poly([(cx, cy - k), (cx + k, cy), (cx, cy + k), (cx - k, cy)], c)
        p.rect(cx - 0.5, cy - 0.5, cx + 0.5, cy + 0.5, p.A)
    elif shape == 2:
        p.ellipse(cx, cy, 2.5 if F else 2, s + 2, p.D)
        p.ellipse(cx, cy, 1.5 if F else 1, s + 1, p.M)
        p.rect(cx - 0.5, cy - s, cx + 0.5, cy + s, p.A)
        p.rect(cx - 0.5, cy - 1, cx + 0.5, cy + 1, p.DD)
    elif shape == 3:
        p.rect(cx - s - 1, cy - s - 1, cx + s + 1, cy + s + 1, p.D)
        p.rect(cx - s, cy - s, cx + s, cy + s, p.M)
        p.rect(cx - s + 1.5, cy - s + 1.5, cx + s - 1.5, cy + s - 1.5, p.DD)
        p.rect(cx - s + 1.5, cy - 0.5, cx + s - 1.5, cy + 0.5, p.A)
        p.rect(cx - 0.5, cy - s + 1.5, cx + 0.5, cy + s - 1.5, p.A)
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.put(cx + sx * s, cy + sy * s, p.L)
    else:
        orbs = ((cx, cy - 3.5), (cx - 3.5, cy + 2), (cx + 3.5, cy + 2)) if F else ((cx, cy - 4), (cx, cy), (cx, cy + 4))
        for ox, oy in orbs:
            p.ellipse(ox, oy, 2 if F else 1.5, 2 if F else 1.5, p.D)
            p.ellipse(ox, oy, 1, 1, p.L)
            p.put(ox, oy, p.A)


def _scale_px(p, x, y, y0):
    ry, rowi = (y - y0) % 3, (y - y0) // 3
    xx = (x + (2 if rowi % 2 else 0)) % 4
    if ry == 2:
        return p.D if xx in (1, 2) else p.M
    if xx == 0:
        return p.D
    return p.L if (ry == 0 and xx == 1) else p.M


def t_scales(p, F):
    cover = p.k % 2
    if F:
        def region(x, y):
            if y >= 33 and not (24 <= x <= 39):
                return False
            if cover == 1:
                return abs(x - 31.5) <= 4.5 + (46 - y) * 0.12 or y <= 29
            return True
        for y in range(25, 47):
            for x in range(16, 48):
                if p.on_body(x, y) and region(x, y):
                    if cover == 1 and y > 29:
                        c = p.D if (y - 30) % 3 == 2 else (p.L if (y - 30) % 3 == 0 else p.M)
                        if x in (27, 36):
                            c = p.D
                    else:
                        c = _scale_px(p, x, y, 25)
                    p.put(x, y, c)
        p.put(31, 31, p.A)
        p.put(32, 31, p.A)
    else:
        x0 = 28 if cover == 0 else 34
        for y in range(32, 50):
            for x in range(x0, 41):
                if p.on_body(x, y):
                    if cover == 1:
                        c = p.D if (y - 32) % 3 == 2 else (p.L if (y - 32) % 3 == 0 else p.M)
                        if x == x0:
                            c = p.D
                    else:
                        c = _scale_px(p, x, y, 32)
                    p.put(x, y, c)
        p.put(39, 37, p.A)


def t_fur(p, F):
    style = p.k % 2

    def tex(x, y):
        h = zlib.crc32(b"%d,%d,%d" % (x, y // 2, p.seed)) % 7
        return p.D if h == 0 else (p.L if h == 1 else p.M)

    if F:
        for y in range(24, 47):
            for x in range(16, 48):
                if not p.on_body(x, y):
                    continue
                if style == 0:
                    ok = abs(x - 31.5) <= 15 - (y - 24) * 1.05 + ((x * 3 + p.seed) % 3)
                else:
                    ok = (y < 33 or 24 <= x <= 39) and y <= 44 + (x + p.seed) % 3
                if ok:
                    p.put(x, y, tex(x, y))
        for x in range(18, 46, 3):
            if not p.on_body(x, 24 if 21 <= x <= 42 else 26):
                p.put(x, 24 if 21 <= x <= 42 else 26, p.M)
        for x in (30, 31, 32, 33):
            p.put(x, 27 + (x % 2), p.A)
    else:
        y1 = 42 if style == 0 else 50
        for y in range(32, y1 + 1):
            for x in range(28, 41):
                if p.on_body(x, y) and (style == 1 or x - 28 >= (y - 36) * 1.2):
                    p.put(x, y, tex(x, y))
            if y % 2 == 0 and y < y1 - 1:
                for x in range(40, 44):
                    if not p.on_body(x, y) and p.on_body(x - 1, y):
                        p.put(x, y, p.M)
                        break
                if not p.on_body(27, y):
                    p.put(27, y, p.D)
        p.put(39, 36, p.A)
        p.put(40, 37, p.A)


def _shard(p, base, tip, w):
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    l = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / l * w / 2, dx / l * w / 2
    a, b = (base[0] + nx, base[1] + ny), (base[0] - nx, base[1] - ny)
    left, right = (a, b) if a[0] <= b[0] else (b, a)
    p.poly([left, tip, base], p.L)
    p.poly([base, tip, right], p.M)


def t_crystal(p, F):
    r = p.r
    n = r.randint(3, 5)
    tips = []
    if F:
        for i in range(n):
            a = 90 + (i - (n - 1) / 2) * (90 / n) + r.randint(-6, 6)
            ln = r.randint(8, 12)
            b = (31.5 + (i - (n - 1) / 2) * 2.5, 36)
            t = pol(b[0], b[1], a, ln)
            _shard(p, b, t, 5)
            tips.append(t)
        for b, t in (((19, 28), (17, 21)), ((44, 28), (46, 21))):
            _shard(p, b, t, 4)
            tips.append(t)
    else:
        for i in range(n):
            a = 15 + i * (70 / n) + r.randint(-6, 6)
            ln = r.randint(5, 8)
            b = (38, 37 + i * 2)
            t = pol(b[0], b[1], a, ln)
            _shard(p, b, t, 4)
            tips.append(t)
        for b, t in (((30, 34), (25, 28)), ((30, 38), (24, 36))):
            _shard(p, b, t, 4)
            tips.append(t)
    p.shade(extra=(p.L,))
    for t in tips:
        p.put(t[0], t[1], p.A)


# ==========================================================================
# BACK (behind the body)  front canvas x16..47 y12..43; side x13..44 y22..53
# ==========================================================================
def _pod(p, x, y, rad):
    p.ellipse(x, y, rad, rad, p.D)
    p.ellipse(x, y, rad - 1, rad - 1, p.M)
    if rad >= 3:
        p.put(x - rad + 2, y - rad + 2, p.L)
        p.put(x - rad + 3, y - rad + 2, p.L)
        p.put(x - rad + 2, y - rad + 3, p.L)
        p.put(x + 1, y + 1, p.A)
    else:
        p.put(x - 1, y - 1, p.L)
        p.put(x, y, p.A)


def b_sacs(p, F):
    r = p.r
    j = [r.randint(-1, 1) for _ in range(8)]
    big = r.choice((3, 4))
    ooze = "ooze" in p.id
    if F:
        if ooze:
            p.ellipse(31.5, 24, 15.5, 5, p.M)
            for x in range(16, 30, 2):
                p.rect(x, 24, x, 30 + (x * 5 + p.seed) % 9, p.M)
            p.rect(16, 30, 18, 42, p.M)
            p.shade()
            for x, y in ((18, 21), (24, 20), (17, 36)):
                p.put(x, y, p.A)
            p.mirror_x(63)
            return
        _pod(p, 19 + j[0], 22 + j[1], big)
        if p.k % 2:
            _pod(p, 18, 15 + j[2], 3)
            _pod(p, 17, 39 + j[3], 2)
        else:
            _pod(p, 24 + j[2], 23 + j[3], 3)
            _pod(p, 17, 28, 2)
            _pod(p, 18, 40 + j[4], 3)
        p.mirror_x(63)
    else:
        if ooze:
            p.ellipse(25, 36, 5.5, 6, p.M)
            p.ellipse(24, 44, 4, 5, p.M)
            for x in (20, 23, 26):
                p.rect(x, 44, x, 50 + (x + p.seed) % 4, p.M)
            p.shade()
            for x, y in ((23, 33), (22, 42), (26, 39)):
                p.put(x, y, p.A)
            return
        pods = [(24 + j[0], 35 + j[1], big), (22 + j[2], 43 + j[3], 3), (25, 49, 2), (26, 29 + j[4], 2 + p.k % 2)]
        for x, y, rad in pods:
            _pod(p, x, y, rad)


def b_wings(p, F):
    r = p.r
    kind = 3 if "moth" in p.id else p.k % 4
    j = r.randint(-1, 1)
    if F:
        if kind == 0:      # bat
            p.poly([(27, 28), (19, 12), (16, 13), (16, 22), (18, 24), (16, 27)])
            p.poly([(24, 33), (16, 35), (16, 43), (19, 40), (21, 43), (23, 39)])
            p.shade()
            p.ln(26, 27, 18, 13, p.L)
            p.ln(23, 34, 17, 42, p.L)
            p.put(18, 12, p.A)
        elif kind == 1:    # feather
            p.poly([(27, 28), (21, 13), (18, 12), (16, 15), (16, 28)])
            p.poly([(24, 33), (16, 33), (16, 43), (22, 42)])
            p.shade()
            for y in range(15, 27, 3):
                p.ln(17, y, 19, y + 1, p.L)
            for y in (36, 39):
                p.ln(17, y, 21, y, p.L)
            for x in (17, 19, 21):
                p.put(x, 42, p.A)
        elif kind == 2:    # insect
            p.ellipse(18, 18 + j, 2, 6.5, p.L)
            p.ellipse(18.5, 39, 2.5, 4, p.L)
            p.shade(extra=(p.L,))
            p.ln(18, 13 + j, 18, 23 + j, p.M)
            p.ln(18, 36, 19, 42, p.M)
            p.put(17, 15 + j, p.A)
        else:              # moth
            p.poly([(27, 28), (20, 12), (16, 12), (16, 29)])
            p.poly([(24, 33), (16, 32), (16, 41), (19, 43), (23, 40)])
            p.shade()
            p.ellipse(18, 17, 1.5, 1.5, p.L)
            p.put(18, 17, p.A)
            p.put(18, 38, p.A)
            p.put(17, 22, p.L)
            p.put(17, 25, p.L)
        p.mirror_x(63)
    else:
        if kind == 0:
            p.poly([(28, 34), (22, 24), (14, 22), (13, 30), (16, 35), (14, 42), (19, 42), (18, 50), (24, 45), (28, 43)])
            p.shade()
            for tx, ty in ((14, 23), (14, 41), (18, 49)):
                p.ln(28, 36, tx, ty, p.D)
                p.put(tx, ty, p.A)
            p.ln(27, 34, 22, 25, p.L)
        elif kind == 1:
            p.poly([(28, 33), (21, 23), (15, 23), (13, 33), (15, 43), (18, 52), (24, 47), (28, 43)])
            p.shade()
            for i in range(4):
                y = 28 + i * 6
                p.path([(14 + i, y), (18 + i, y + 2), (25, y)], p.D)
                p.path([(14 + i, y + 1), (18 + i, y + 3), (24, y + 1)], p.L)
            p.put(18, 51, p.A)
            p.put(16, 45, p.A)
        elif kind == 2:
            p.limb([(28, 35), (20, 28), (14, 25 + j)], 1.5, 2.8, p.L)
            p.limb([(28, 38), (20, 42), (15, 46)], 1.2, 2.5, p.L)
            p.shade(extra=(p.L,))
            p.path([(27, 35), (20, 29), (15, 26 + j)], p.M)
            p.path([(27, 38), (20, 42), (16, 45)], p.M)
            p.put(15, 24 + j, p.A)
            p.put(15, 47, p.A)
        else:
            p.ellipse(20.5, 29.5, 7, 6.5, p.M)
            p.ellipse(21, 43, 5.5, 6.5, p.M)
            p.shade()
            for cx, cy in ((19, 29), (20, 44)):
                p.ellipse(cx, cy, 2.5, 2.5, p.D)
                p.ellipse(cx, cy, 1.5, 1.5, p.L)
                p.put(cx, cy, p.A)
            p.ln(27, 34, 16, 34, p.L)
            for x, y in ((15, 27), (16, 24), (17, 47), (24, 25)):
                p.put(x, y, p.A)


def b_spikes(p, F):
    r = p.r
    n, ln = r.randint(3, 5), r.randint(0, 3)
    tips = []
    if F:
        sp = [((19, 29), (16, 18 - ln)), ((23, 27), (19, 12 + (3 - ln))), ((22, 37), (16, 40 + p.k % 2 * 2))]
        if n >= 4:
            sp.append(((26, 26), (23, 22)))
        for b, t in sp:
            p.spike(b, t, 4)
            tips.append(t)
        p.shade()
        for t in tips:
            p.put(t[0], t[1], p.A)
        p.mirror_x(63)
    else:
        for i in range(n + 1):
            y = 33 + i * (15 / n)
            l = 6 + ln + (2 if i % 2 == p.k % 2 else 0)
            t = (29 - l, y - 3 + i * 0.8)
            p.spike((29, y), t, 4.5)
            tips.append(t)
        p.shade()
        for t in tips:
            p.put(t[0], t[1], p.A)


def b_shell(p, F):
    kind = p.k % 2
    if F:
        p.ellipse(31.5, 30, 15.5, 13, p.M)
        if kind == 1:
            for a in range(20, 170, 25):
                p.spike(pol(31.5, 30, a, 12), pol(31.5, 28, a, 17), 4)
        p.shade()
        if kind == 0:
            for a in range(0, 360, 30):
                e, f = pol(31.5, 30, a, 9), pol(31.5, 30, a, 14)
                p.ln(e[0], e[1] * 0.92 + 2, f[0], f[1] * 0.9 + 3, p.D)
            p.ellipse(31.5, 30, 12.5, 10, p.D, ring=1)
        else:
            p.ellipse(31.5, 30, 12, 10, p.L, ring=1)
            p.ellipse(31.5, 30, 9, 7, p.D, ring=1)
        for x, y in ((18, 24), (45, 24), (17, 36), (46, 36)):
            p.put(x, y, p.A)
    else:
        p.ellipse(24.5, 40, 6.5, 10, p.M)
        if kind == 1:
            for y in (33, 38, 43, 48):
                p.spike((20, y), (14, y - 2), 3.5)
        p.shade()
        if kind == 0:
            for y in (35, 40, 45):
                p.ln(19, y, 28, y, p.D)
            p.ln(23, 31, 22, 49, p.D)
            for x, y in ((21, 37), (25, 42)):
                p.put(x, y, p.A)
        else:
            p.ellipse(24, 40, 4, 6.5, p.D, ring=1)
            p.ellipse(24, 40, 1.5, 3, p.L, ring=1)
            p.put(24, 40, p.A)


def b_fins(p, F):
    r = p.r
    n = r.randint(3, 5)
    if F:
        p.poly([(27, 28), (19, 12), (16, 14), (17, 20), (16, 24), (16, 29)])
        p.poly([(24, 33), (16, 35), (17, 39), (16, 43), (22, 41)])
        p.shade()
        for tx, ty in ((19, 13), (17, 18), (17, 26)):
            p.ln(25, 28, tx, ty, p.L)
            p.put(tx, ty, p.A)
        p.ln(23, 35, 17, 42, p.L)
        p.mirror_x(63)
    else:
        edge = []
        for i in range(n + 1):
            t = i / n
            y = 24 + t * 26
            x = 13 + abs(t - 0.45) * 12 + (2 if i % 2 else 0)
            edge.append((x, y))
        p.poly([(28, 33)] + edge + [(28, 48)])
        p.shade()
        for i, (x, y) in enumerate(edge):
            p.ln(28, 34 + i * (13 / n), x + 1, y, p.L)
            p.put(x + 1, y, p.A)


def b_tubes(p, F):
    r = p.r
    kind, t = p.k % 4, r.randint(0, 2)
    if F:
        if kind == 0:
            for x0, top in ((16, 13 + t), (21, 16 - t)):
                p.rect(x0 + 1, top, x0 + 3, 29, p.M)
                p.rect(x0, top, x0 + 4, top + 1, p.M)
            p.shade()
            for x0, top in ((16, 13 + t), (21, 16 - t)):
                p.rect(x0 + 1, top, x0 + 3, top, p.A)
        elif kind == 1:
            p.ellipse(18.5, 20, 2.5, 7.5, p.M)
            p.rect(17, 33, 19, 42, p.M)
            p.shade()
            for y in (17, 23):
                p.ln(16, y, 21, y, p.D)
            p.rect(18, 12, 19, 12, p.A)
            p.put(18, 38, p.A)
        elif kind == 2:
            for i, x in enumerate((16, 18, 20)):
                top = 14 + ((i + t) % 3) * 3
                p.rect(x, top, x, 29, p.M if i % 2 else p.L)
                p.put(x, top, p.A)
                p.put(x, top + 1, p.D)
            p.rect(16, 36, 22, 37, p.D)
            p.rect(16, 39, 21, 40, p.D)
            p.put(16, 36, p.A)
            p.put(16, 39, p.A)
        else:
            p.rect(17, 16, 19, 29, p.M)
            p.shade()
            for y in range(18, 29, 3):
                p.rect(16, y, 20, y, p.L)
            p.ellipse(18, 14, 2, 2, p.D)
            p.ellipse(18, 14, 1, 1, p.A)
            p.rect(16, 36, 22, 38, p.D)
            p.put(17, 37, p.A)
        p.mirror_x(63)
    else:
        if kind == 0:
            ends = [(19, 25 + t), (16, 33 - t)]
            ends = [(19, 23 + t), (15, 36 - t)]
            p.limb([(29, 35), ends[0]], 1.2, 1.2)
            p.limb([(29, 46), ends[1]], 1.2, 1.2)
            p.shade()
            for ex, ey in ends:
                p.rect(ex - 1, ey - 1, ex, ey, p.A)
        elif kind == 1:
            p.ellipse(22.5, 40, 4, 8.5, p.M)
            p.shade()
            for y in (35, 45):
                p.ln(19, y, 26, y, p.D)
            p.path([(23, 31), (25, 28), (28, 30), (29, 34)], p.D)
            p.rect(22, 30, 23, 31, p.A)
            p.rect(21, 39, 22, 41, p.A)
        elif kind == 2:
            for i in range(3):
                y0, e = 35 + i * 5, (17 + (i + t) % 3 * 2, 26 + i * 6)
                p.ln(28, y0, e[0], e[1], p.D, 2)
                p.ln(28, y0 - 1, e[0], e[1] - 1, p.M if i % 2 else p.L)
                p.put(e[0] - 1, e[1] - 1, p.A)
        else:
            p.rect(21, 28, 23, 51, p.M)
            p.shade()
            for y in range(30, 51, 3):
                p.rect(19, y, 25, y, p.L)
                p.put(25, y, p.D)
            p.ellipse(22, 25, 2.5, 2.5, p.D)
            p.ellipse(22, 25, 1.5, 1.5, p.A)
            p.ln(24, 36, 28, 36, p.D)
            p.ln(24, 46, 28, 46, p.D)


# ==========================================================================
# ARM (drawn as LEFT)  front: arm x15..20 y29..38, canvas x2..33 y18..49
#                      side:  upper arm x29..33 y35..44, canvas x19..50 y24..55
# ==========================================================================
def _arm_base(p, F):
    if F:
        p.fill_body(15, 29, 20, 38, p.M)
    else:
        p.rect(29, 35, 33, 44, p.M)
        p.rect(30, 34, 32, 34, p.M)


def a_blade(p, F):
    r = p.r
    ln = r.randint(0, 2)
    kind = 4 if "scythe" in p.id else p.k % 4
    _arm_base(p, F)
    if F:
        if kind == 0:
            pts = bez((16, 38), (8, 41), (11, 47 + ln))
            p.limb(pts, 1.6, 0.3)
            tip = pts[-1]
        elif kind == 1:
            p.poly([(13, 38), (19, 38), (19, 46 + ln), (16, 49), (12, 45)])
            tip = (16, 49)
        elif kind == 2:
            p.poly([(15, 38), (19, 38), (17, 49), (14, 47)])
            tip = (17, 49)
        elif kind == 3:
            p.rect(14, 38, 20, 39, p.M)
            p.ln(17, 40, 14 - ln, 49, p.M, 2)
            tip = (14 - ln, 49)
        else:
            p.ln(17, 38, 15, 46, p.M, 2)
            pts = bez((16, 46), (3, 47), (4, 33))
            p.limb(pts, 1.8, 0.3)
            tip = pts[-1]
        p.shade()
        if kind == 2:
            for y in range(39, 48, 2):
                p.put(13 + (48 - y) // 6, y, p.L)
                p.put(14 + (48 - y) // 6, y + 1, p.D)
        if kind == 4:
            for q in pts[2:-1]:
                p.put(q[0], q[1] + 1, p.A)
        p.put(tip[0], tip[1], p.A)
        p.put(17, 38, p.A)
    else:
        if kind == 0:
            pts = bez((33, 45), (43, 43), (47, 52 + ln))
            p.limb(pts, 2.0, 0.3)
            tip = pts[-1]
        elif kind == 1:
            p.poly([(33, 42), (36, 42), (46, 47), (48, 53), (43, 53), (33, 47)])
            tip = (48, 53)
        elif kind == 2:
            p.poly([(33, 43), (47, 48), (48, 52), (33, 48)])
            tip = (48, 52)
        elif kind == 3:
            p.rect(33, 42, 35, 48, p.M)
            p.ln(35, 45, 49, 50 + ln, p.M, 2)
            tip = (49, 50 + ln)
        else:
            p.ln(32, 44, 43, 50, p.M, 2)
            pts = bez((43, 50), (51, 45), (45, 32))
            p.limb(pts, 1.8, 0.3)
            tip = pts[-1]
        p.shade()
        if kind == 2:
            for x in range(35, 47, 2):
                p.put(x, 49 + (x - 33) // 5, p.L)
                p.put(x + 1, 50 + (x - 33) // 5, p.D)
        if kind == 4:
            for q in pts[2:-1]:
                p.put(q[0] - 1, q[1], p.A)
        p.put(tip[0], tip[1], p.A)
        p.put(33, 45, p.A)


def a_claw(p, F):
    r = p.r
    nt, ln, bulk = 2 + p.k % 3, r.randint(1, 3), p.k // 3 % 2 + r.randint(0, 1) * 0.5
    _arm_base(p, F)
    tips = []
    if F:
        p.ellipse(16.5, 40, 3 + bulk, 2.5, p.M)
        for i in range(nt):
            x0 = 13.5 + i * 6 / (nt - 1)
            tip = (x0 - 1.5 + i * 0.5, 44 + ln + (1 if i == nt // 2 else 0))
            p.spike((x0, 41), tip, 3, p.M)
            tips.append(tip)
    else:
        p.limb([(32, 44), (39, 48)], 2 + bulk * 0.5, 2)
        p.ellipse(41, 49, 2.5 + bulk * 0.5, 2.5, p.M)
        for i in range(nt):
            tip = (45 + ln, 46 + i * 7 / nt)
            p.spike((42, 47.5 + i * 3 / nt), tip, 3, p.M)
            tips.append(tip)
    p.shade()
    for t in tips:
        p.put(t[0], t[1], p.A)
        p.put(t[0] + (0 if F else -1), t[1] - (1 if F else 0), p.A)


def a_tentacle(p, F):
    r = p.r
    kind, w = p.k % 3, r.choice((-1, 1))
    if F:
        if kind == 0:
            paths = [[(17.5, 30), (16, 36), (13 + w, 41), (15, 45), (11, 49)]]
        elif kind == 1:
            paths = [[(17.5, 30), (16, 36), (14, 42), (11, 46), (7, 45), (5, 41)]]
        else:
            paths = [[(17.5, 30), (16, 37), (12, 42), (11, 49)], [(17.5, 30), (17, 37), (19, 43), (17, 49)]]
    else:
        if kind == 0:
            paths = [[(31, 36), (31, 43), (35, 48), (41, 47 + w), (45, 51)]]
        elif kind == 1:
            paths = [[(31, 36), (31, 43), (36, 48), (43, 48), (47, 44), (45, 40)]]
        else:
            paths = [[(31, 36), (31, 43), (37, 46), (46, 44)], [(31, 36), (31, 44), (36, 50), (44, 53)]]
    for pts in paths:
        sm = []
        for a, b, c in zip(pts, pts[1:], pts[2:]):
            sm += bez(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), b, ((b[0] + c[0]) / 2, (b[1] + c[1]) / 2), 5)
        p.limb([pts[0]] + sm + [pts[-1]], 2.4 if kind != 2 else 1.9, 0.5)
    p.shade()
    for pts in paths:
        for a, b in zip(pts[1:], pts[2:]):
            p.put((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, p.A)
            p.put(a[0], a[1], p.A)


def a_pincer(p, F):
    r = p.r
    s, kind = r.choice((0, 1)), p.k % 2
    _arm_base(p, F)
    if F:
        if kind == 0:
            p.ellipse(15.5, 43.5, 4 + s * 0.5, 5, p.M)
            p.shade()
            p.poly([(15.5, 43), (13, 49), (17, 49)], p.DD)
            for y in (45, 47):
                p.put(14, y, p.L)
                p.put(17, y, p.L)
        else:
            p.limb([(16, 39), (11, 43), (13, 49)], 1.8, 0.4)
            p.limb([(17, 39), (20, 44), (16, 49)], 1.6, 0.4)
            p.shade()
            p.put(13, 49, p.A)
            p.put(16, 49, p.A)
        p.rect(16, 38, 17, 39, p.A)
    else:
        p.limb([(32, 44), (37, 47)], 2, 2)
        if kind == 0:
            p.ellipse(42.5, 48, 5 + s * 0.5, 4, p.M)
            p.shade()
            p.poly([(43, 48), (49, 46), (49, 50)], p.DD)
            for x in (45, 47):
                p.put(x, 46, p.L)
                p.put(x, 50, p.L)
        else:
            p.limb([(37, 46), (43, 42), (49, 45)], 1.8, 0.4)
            p.limb([(37, 48), (43, 52), (49, 49)], 1.6, 0.4)
            p.shade()
            p.put(49, 45, p.A)
            p.put(49, 49, p.A)
        p.rect(36, 46, 37, 47, p.A)


def a_club(p, F):
    r = p.r
    kind, s = p.k % 4, r.choice((0, 0.5))
    _arm_base(p, F)
    if F:
        cx, cy = 15.5, 44
        p.rect(15, 38, 18, 41, p.M)
    else:
        cx, cy = 42, 50
        p.limb([(32, 44), (39, 48)], 2, 2)
    if kind == 0:
        p.ellipse(cx, cy, 4.5 + s, 4.5, p.M)
        p.shade()
        p.path([(cx - 1, cy - 2), (cx + 1, cy), (cx, cy + 2)], p.D)
        p.put(cx + 2, cy - 2, p.A)
    elif kind == 1:
        p.ellipse(cx, cy, 3.5, 3.5, p.M)
        tips = [pol(cx, cy, a, 6) for a in range(0, 360, 45)]
        for a, t in zip(range(0, 360, 45), tips):
            p.spike(pol(cx, cy, a, 3), t, 3, p.M)
        p.shade()
        for t in tips:
            p.put(t[0], t[1], p.A)
    elif kind == 2:
        p.rect(cx - 5, cy - 3, cx + 4.5, cy + 4, p.M)
        p.shade()
        p.rect(cx - 4, cy, cx + 3.5, cy, p.D)
        for sx in (-3, 3):
            p.put(cx + sx, cy - 2, p.A)
            p.put(cx + sx, cy + 3, p.A)
    else:
        p.ellipse(cx - 2.5, cy + 1, 2.5, 3, p.M)
        p.ellipse(cx + 2.5, cy + 1, 2.5, 3, p.M)
        p.ellipse(cx, cy - 1.5, 2.5, 2.5, p.M)
        p.shade()
        p.put(cx, cy + 1, p.A)
        p.put(cx, cy + 2, p.D)


def a_cannon(p, F):
    r = p.r
    kind, ln = p.k % 3, r.randint(0, 2)
    _arm_base(p, F)
    if F:
        bot = 45 + ln
        if kind == 1:
            p.rect(13, 37, 16, bot, p.M)
            p.rect(18, 37, 21, bot, p.M)
            p.shade()
            for x in (14, 19):
                p.rect(x, bot + 1, x + 1, bot + 1, p.DD)
                p.rect(x, bot, x + 1, bot, p.A)
            p.rect(13, 40, 21, 40, p.D)
        else:
            p.rect(14, 37, 20, bot, p.M)
            p.rect(13, bot - 1, 21, bot + 1, p.M)
            p.shade()
            p.rect(15, bot, 19, bot + 1, p.DD)
            p.rect(16, bot, 18, bot, p.A)
            for y in range(39, bot - 2, 2 if kind == 2 else 3):
                p.rect(14, y, 20, y, p.L if kind == 2 else p.D)
        p.put(17, 37, p.A)
    else:
        x1 = 44 + ln
        if kind == 1:
            p.rect(31, 42, x1, 44, p.M)
            p.rect(31, 46, x1, 48, p.M)
            p.rect(31, 42, 35, 48, p.M)
            p.shade()
            for y in (43, 47):
                p.put(x1 + 1, y, p.A)
                p.put(x1, y, p.DD)
        else:
            p.rect(31, 43, x1, 48, p.M)
            p.rect(x1 + 1, 42, x1 + 3, 49, p.M)
            p.shade()
            p.rect(x1 + 3, 44, x1 + 3, 47, p.DD)
            p.rect(x1 + 3, 45, x1 + 3, 46, p.A)
            for x in range(36, x1, 2 if kind == 2 else 4):
                p.rect(x, 44, x, 47, p.L if kind == 2 else p.D)
        p.rect(32, 45, 33, 46, p.A)


# ==========================================================================
# LEG (drawn as LEFT)  front: leg x21..27 y47..60, canvas x8..39 y37..63
#                      side:  legs x30..37 y51..63, canvas x18..49 y40..63
# ==========================================================================
def _leg_base(p, F, y1, c=None):
    c = c or p.M
    if F:
        p.fill_body(21, 47, 31, y1, c)
    else:
        p.fill_body(30, 51, 39, y1, c)


def l_raptor(p, F):
    r = p.r
    kind, st = p.k % 2, r.randint(0, 2)
    if F:
        _leg_base(p, F, 59)
        p.rect(20, 52, 28, 54, p.M)
        p.rect(19, 60, 30, 61, p.M)
        p.shade()
        for y in range(48, 58, 2 + st % 2):
            p.rect(22, y, 24 + st, y, p.D)
        p.rect(26, 48, 26, 57, p.L)
        for x in (19, 24, 30):
            p.put(x, 62, p.A)
            p.put(x, 63, p.A)
        if kind:
            for y in (48, 50, 52):
                p.put(20, y, p.L)
                p.put(19, y + 1, p.L)
    else:
        p.rect(31, 55, 36, 61, p.D)
        p.ellipse(34.5, 53, 4.5, 2.5, p.M)
        p.rect(37, 54, 39, 56, p.M)
        p.limb([(38, 56), (33, 59)], 1, 1)
        p.limb([(32, 59), (34, 62)], 1, 1)
        p.rect(34, 62, 39, 63, p.M)
        p.shade()
        for x, y in ((40, 62), (40, 63), (41, 63), (35, 61), (36, 60)):
            p.put(x, y, p.A)
        for x, y in ((33, 52), (36, 53), (37, 55), (35, 57)):
            p.put(x, y, p.L if (x + st) % 2 else p.D)
        if kind:
            for y in (52, 54):
                p.put(29, y, p.L)
                p.put(28, y + 1, p.L)


def l_hoof(p, F):
    kind = p.k % 3

    def tex(x, y):
        h = (x * 5 + y * 11 + p.seed) % 5
        return p.D if h == 0 else (p.L if h == 1 else p.M)

    if F:
        for y in range(47, 58):
            for x in range(20 if kind == 2 and y % 2 else 21, 29):
                if p.on_body(x, y) or (kind == 2 and x in (20, 28) and y % 2):
                    p.put(x, y, tex(x, y))
        p.rect(20, 56, 28, 57, p.L)
        p.put(20, 58, p.L)
        p.put(28, 58, p.L)
        p.rect(21, 58, 27, 61, p.DD)
        p.rect(20, 60, 28, 61, p.DD)
        p.rect(22, 58, 23, 59, p.D)
        if kind == 0:
            p.rect(24, 59, 24, 61, p.A)
        elif kind == 1:
            p.rect(20, 61, 28, 61, p.A)
        else:
            p.put(22, 60, p.A)
            p.put(26, 60, p.A)
    else:
        for y in range(51, 59):
            for x in range(29, 40):
                if p.on_body(x, y) or (x == 29 and y in (54, 55, 56)):
                    p.put(x, y, tex(x, y))
        p.rect(29, 57, 38, 58, p.L)
        if kind == 2:
            for y in (52, 54):
                p.put(38, y, p.M)
        p.rect(30, 59, 38, 63, p.DD)
        p.rect(31, 59, 33, 60, p.D)
        p.rect(39, 62, 39, 63, p.DD)
        if kind == 0:
            p.rect(35, 60, 35, 63, p.A)
        elif kind == 1:
            p.rect(30, 63, 39, 63, p.A)
        else:
            p.put(37, 61, p.A)


def l_spider(p, F):
    r = p.r
    j, kind = r.randint(0, 2), p.k % 2
    _leg_base(p, F, 60, p.D)
    if F:
        p.rect(22, 48, 26, 59, p.M)
        p.rect(23, 48, 23, 58, p.L)
        legs = [[(22, 49), (14, 43 + j), (10, 62)], [(22, 53), (16, 50), (15, 62)]]
        if kind:
            legs.append([(22, 51), (12, 47), (9, 55)])
        p.rect(21, 60, 27, 61, p.D)
    else:
        p.rect(31, 52, 36, 61, p.M)
        p.rect(32, 52, 32, 60, p.L)
        legs = [[(36, 53), (44, 47 + j), (47, 63)], [(31, 53), (23, 47 + j), (20, 63)]]
        if kind:
            legs.append([(36, 55), (41, 53), (42, 63)])
            legs.append([(31, 55), (26, 53), (25, 63)])
    for a, b, c in legs:
        p.ln(a[0], a[1], b[0], b[1], p.D, 2)
        p.ln(b[0], b[1], c[0], c[1], p.D, 2)
        p.ln(a[0], a[1], b[0], b[1], p.M)
        p.ln(b[0], b[1], c[0], c[1], p.M)
        p.rect(b[0], b[1], b[0] + 1, b[1] + 1, p.L)
        p.put(c[0], c[1], p.A)
        p.put(c[0], c[1] - 1, p.A)


def l_spring(p, F):
    kind = p.k % 3
    x0, x1, y0 = (21, 27, 47) if F else (30, 37, 51)
    yf = 59 if F else 61
    _leg_base(p, F, 63, p.DD)
    if kind == 0:
        p.rect(x0, y0, x1, y0 + 2, p.M)
        for y in range(y0 + 3, yf):
            if (y - y0) % 2:
                p.rect(x0, y, x1, y, p.L)
                p.put(x1, y, p.D)
            else:
                p.rect(x0 + 1, y, x1 - 1, y, p.DD)
                p.put(x0 + 1 + (y // 2) % 2 * (x1 - x0 - 2), y, p.M)
        p.rect(x0 - 1, yf, x1 + 1 + (0 if F else 2), yf + 2, p.M)
        p.rect(x0 - 1, yf, x1 + 1 + (0 if F else 2), yf, p.A)
        p.rect(x0, y0, x1, y0, p.L)
    elif kind == 1:
        ym = y0 + (7 if F else 5)
        p.rect(x0, y0, x1, ym, p.M)
        p.rect(x0 + 1, y0, x0 + 1, ym, p.L)
        p.rect(x1, y0, x1, ym, p.D)
        p.rect(x0, ym, x1, ym, p.A)
        mx = (x0 + x1) // 2
        p.rect(mx - 1, ym + 1, mx + 1, yf - 1, p.L)
        p.rect(mx + 1, ym + 1, mx + 1, yf - 1, p.D)
        p.rect(x0 - 1, yf, x1 + 1 + (0 if F else 2), yf + 2, p.M)
        p.rect(x0 - 1, yf + 2, x1 + 1 + (0 if F else 2), yf + 2, p.D)
        p.rect(x0, y0, x1, y0, p.D)
    else:
        if F:
            p.ellipse(24, 50, 4, 3.5, p.M)
            p.limb([(22, 51), (18, 54), (23, 59)], 1.5, 1)
            p.rect(18, 60, 28, 61, p.M)
            p.shade()
            for x in (18, 22, 26):
                p.put(x, 62, p.A)
            p.put(18, 54, p.A)
        else:
            p.ellipse(33, 53.5, 4.5, 3, p.M)
            p.limb([(31, 54), (25, 51), (27, 58), (33, 61)], 1.5, 1)
            p.rect(32, 61, 42, 63, p.M)
            p.shade()
            for x in (38, 40, 42):
                p.put(x, 63, p.A)
            p.put(25, 51, p.A)


def l_paw(p, F):
    kind = p.k % 2

    def tex(x, y):
        h = (x * 3 + y * 7 + p.seed) % 6
        return p.D if h == 0 else (p.L if h == 1 else p.M)

    if F:
        for y in range(47, 59):
            for x in range(20, 29):
                if x <= 31 - max(0, y - 46) * 2 or x <= 28:
                    if y > 47 or p.on_body(x, y):
                        p.put(x, y, tex(x, y))
        p.rect(20, 48, 20, 58, p.D)
        p.ellipse(24, 60, 5, 2, p.M)
        p.shade()
        for x in (22, 26) if kind else (21, 24, 27):
            p.put(x, 60, p.D)
            p.put(x, 61, p.D)
        for x in (20, 24, 28):
            p.put(x, 63, p.A)
        p.put(22, 62, p.A) if kind else None
    else:
        for y in range(51, 60):
            for x in range(29, 39):
                p.put(x, y, tex(x, y))
        p.rect(29, 52, 29, 59, p.D)
        p.rect(38, 52, 38, 59, p.D)
        p.ellipse(35, 61.5, 6, 1.5, p.M)
        p.shade()
        for x in (36, 39):
            p.put(x, 62, p.D)
        for x in (40, 41, 42):
            p.put(x, 63, p.A)
        if kind:
            p.put(29, 55, p.L)
            p.put(28, 56, p.L)


def l_tread(p, F):
    kind = p.k % 3
    _leg_base(p, F, 63, p.D)
    if F:
        p.rect(21, 47, 27, 50, p.M)
        p.rect(21, 47, 27, 47, p.L)
        if kind == 1:
            p.ellipse(24, 56.5, 3, 6.5, p.DD)
            for y in range(51, 63, 2):
                p.rect(22, y, 26, y, p.M)
            p.rect(20, 50, 20, 57, p.L)
            p.rect(28, 50, 28, 57, p.D)
            p.put(24, 49, p.A)
        else:
            p.rect(20, 51, 29, 62, p.DD)
            for y in range(51, 63, 2):
                p.rect(21, y, 28, y, p.M)
                p.put(21, y, p.L)
            p.rect(23, 48, 25, 49, p.A)
            if kind == 2:
                p.rect(20, 63, 29, 63, p.A)
                p.rect(24, 51, 25, 62, p.D)
    else:
        p.rect(31, 51, 37, 54, p.M)
        p.rect(31, 51, 37, 51, p.L)
        if kind == 1:
            p.ellipse(34, 57.5, 5.5, 5.5, p.DD)
            p.ellipse(34, 57.5, 3.5, 3.5, p.M)
            for a in range(0, 360, 60):
                e = pol(34, 57.5, a + p.seed % 30, 3.5)
                p.ln(34, 57, e[0], e[1], p.D)
            p.rect(33, 57, 34, 58, p.A)
            p.ln(34, 52, 34, 55, p.L)
        else:
            if kind == 0:
                p.ellipse(34, 58.5, 9, 4.5, p.DD)
                p.ellipse(34, 58.5, 7.5, 3, p.M)
                hubs = ((28.5, 58.5), (34, 58.5), (39.5, 58.5))
            else:
                p.poly([(29, 54), (39, 54), (44, 63), (24, 63)], p.DD)
                p.poly([(30, 56), (38, 56), (41, 61), (27, 61)], p.M)
                hubs = ((34, 57.5), (29.5, 60), (38.5, 60))
            for hx, hy in hubs:
                p.ellipse(hx, hy, 1.5, 1.5, p.D)
                p.ellipse(hx, hy, 0.5, 0.5, p.L)
                p.put(hx, hy, p.A)
            for x in range(25, 44, 2):
                if p.get(x, 63)[3]:
                    p.put(x, 63, p.M)
                if kind == 0 and p.get(x, 54)[3]:
                    p.put(x, 54, p.M)


# ==========================================================================
# TAIL (behind the body)  front canvas x16..47 y30..61; side x12..43 y32..63
# ==========================================================================
def _tail_path(p, F, style):
    d = 1 if (p.seed >> 3) % 2 else -1
    if F:
        a = bez((31.5, 47), (31.5, 59), (32 + d * 7, 59), 8)
        if style == 0:
            b = bez(a[-1], (32 + d * 15, 59), (32 + d * 13, 47), 10)
        elif style == 1:
            b = bez(a[-1], (32 + d * 11, 60), (32 + d * 13.5, 53), 6)
        else:
            b = bez(a[-1], (32 + d * 15, 57), (32 + d * 12, 49), 8)
            b += bez(b[-1], (32 + d * 10, 43), (32 + d * 13.5, 40), 6)[1:]
    else:
        if style == 0:
            a = bez((29, 49), (18, 57), (15, 46), 10)
            b = bez(a[-1], (13, 38), (19, 35), 8)
        elif style == 1:
            a = bez((29, 49), (24, 50), (21, 57), 8)
            b = bez(a[-1], (19, 62), (14, 60), 6)
        else:
            a = bez((29, 49), (20, 51), (18, 44), 8)
            b = bez(a[-1], (16, 38), (14, 36), 6)
    pts = a + b[1:]
    q = pts[-3]
    dx, dy = pts[-1][0] - q[0], pts[-1][1] - q[1]
    l = math.hypot(dx, dy) or 1.0
    return pts, (dx / l, dy / l)


def tl_stinger(p, F):
    pts, (dx, dy) = _tail_path(p, F, (p.k + 1) % 3)
    n = len(pts)
    for i in range(0, n, 2):
        x, y = pts[i]
        rad = 2.2 - 0.9 * i / n
        p.ellipse(x, y, rad, rad, p.D)
        p.ellipse(x, y, rad - 1, rad - 1, p.L if (i // 2) % 2 else p.M)
    x, y = pts[-1]
    p.ellipse(x, y, 2, 2, p.D)
    p.ellipse(x, y, 1, 1, p.M)
    p.ln(x + dx * 2, y + dy * 2, x + dx * 4, y + dy * 4 - 1, p.A)
    p.put(x + dx * 3, y + dy * 3, p.A)


def tl_whip(p, F):
    kind = p.k % 3
    pts, (dx, dy) = _tail_path(p, F, (p.k * 2 + 2) % 3 if "night" not in p.id else 2)
    p.limb(pts, 1.3, 0.4)
    p.shade()
    x, y = pts[-1]
    if kind == 0:
        p.ellipse(x, y, 1.5, 1.5, p.A)
        p.put(x + 1, y + 1, p.D)
    elif kind == 1:
        p.spike((x, y), (x + dx * 4, y + dy * 4), 5, p.A)
        p.put(x, y, p.D)
    else:
        for i in range(2, len(pts) - 1, 4):
            p.put(pts[i][0], pts[i][1], p.A)
        p.spike((x - dx, y - dy), (x + dx * 3, y + dy * 3), 3, p.A)


def tl_club(p, F):
    kind = p.k % 2
    pts, (dx, dy) = _tail_path(p, F, 1 if kind == 0 else 0)
    p.limb(pts, 2.0, 1.4)
    x, y = pts[-1]
    x, y = min(max(x, p.sx - 12), p.sx + 11), y
    p.ellipse(x, y, 3.5, 3.5, p.M)
    tips = []
    if kind == 0:
        for a in range(0, 360, 60):
            t = pol(x, y, a + 30, 5)
            p.spike(pol(x, y, a + 30, 3), t, 3)
            tips.append(t)
    p.shade()
    for t in tips:
        p.put(t[0], t[1], p.A)
    if kind == 1:
        p.ellipse(x, y, 2.5, 2.5, p.D, ring=1)
        p.put(x, y, p.A)
        p.put(x - 1, y - 1, p.A)
    for i in range(3, len(pts) - 4, 3):
        p.put(pts[i][0], pts[i][1], p.L)


def tl_fan(p, F):
    r = p.r
    kind, n = p.k % 2, r.randint(5, 7)
    if F:
        cx, cy = 31.5, 45
        a0, a1, ln = (178, 362, 15.5) if kind == 0 else (195, 345, 16)
    else:
        cx, cy = 28, 47
        a0, a1, ln = (105, 235, 14) if kind == 0 else (125, 215, 15)
    step = (a1 - a0) / (n * 2)
    edge = []
    for i in range(n * 2 + 1):
        a = a0 + i * step
        rr = ln - (2.5 if (i % 2 == 0 and kind == 1) else 0) - (1 if i % 2 == 0 else 0)
        e = pol(cx, cy, a, rr)
        e = (min(max(e[0], p.sx - 16), p.sx + 15), min(e[1], 61 if F else 63))
        edge.append(e)
    p.poly([(cx, cy)] + edge)
    p.shade()
    for i in range(1, n * 2, 2):
        e = edge[i]
        p.ln(cx, cy, e[0], e[1], p.D if kind == 0 else p.L)
        q = pol(cx, cy, a0 + i * step, ln - 3)
        if kind == 0:
            p.ellipse(q[0], q[1], 1, 1, p.L)
            p.put(q[0], q[1], p.A)
        else:
            p.put(q[0], q[1], p.A)
            m = pol(cx, cy, a0 + i * step, ln - 7)
            p.put(m[0], m[1], p.A)


def tl_rattle(p, F):
    kind = p.k % 2
    pts, (dx, dy) = _tail_path(p, F, 2 if kind == 0 else 0)
    cut = len(pts) - (7 if kind == 0 else 9)
    p.limb(pts[:cut + 1], 1.7, 1.2)
    p.shade()
    for i in range(2, cut, 3):
        p.put(pts[i][0], pts[i][1], p.L)
    for j, i in enumerate(range(cut, len(pts), 2)):
        x, y = pts[i]
        rad = 2.0 - 0.15 * j
        p.ellipse(x, y, rad, rad, p.D)
        p.ellipse(x, y, rad - 1, rad - 1, p.A if j % 2 == 0 else p.L)


def tl_flame(p, F):
    kind = p.k % 2
    pts, (dx, dy) = _tail_path(p, F, 0 if kind == 0 else 1)
    p.limb(pts, 1.4, 0.8)
    p.shade()

    def flame(x, y, s):
        p.ellipse(x, y, 2.5 * s, 2.5 * s, p.M)
        p.spike((x, y - 1), (x + 0.5, y - 7 * s), 4 * s, p.M)
        p.put(x - 2 * s, y - 4 * s, p.M)
        p.ellipse(x, y, 1.5 * s, 1.5 * s, p.L)
        p.ln(x, y - 2, x, y - 4 * s, p.L)
        p.ellipse(x, y + 0.5, 0.5, 0.5, p.A)
        p.put(x, y, p.A)

    x, y = pts[-1]
    flame(min(max(x, p.sx - 13), p.sx + 12), max(y - 1, p.sy - 9), 1.0)
    if kind == 1:
        for i in (len(pts) // 2, len(pts) * 3 // 4):
            fx, fy = pts[i]
            p.put(fx, fy - 2, p.L)
            p.put(fx, fy - 3, p.M)
            p.put(fx, fy - 1, p.A)


DRAWERS = {
    ("HEAD", "maw"): h_maw, ("HEAD", "horns"): h_horns, ("HEAD", "eyes"): h_eyes,
    ("HEAD", "crest"): h_crest, ("HEAD", "antennae"): h_antennae, ("HEAD", "beak"): h_beak,
    ("HEAD", "skull"): h_skull, ("HEAD", "tentacles"): h_tentacles, ("HEAD", "halo"): h_halo,
    ("TORSO", "plates"): t_plates, ("TORSO", "ribs"): t_ribs, ("TORSO", "core"): t_core,
    ("TORSO", "scales"): t_scales, ("TORSO", "fur"): t_fur, ("TORSO", "crystal"): t_crystal,
    ("BACK", "sacs"): b_sacs, ("BACK", "wings"): b_wings, ("BACK", "spikes"): b_spikes,
    ("BACK", "shell"): b_shell, ("BACK", "fins"): b_fins, ("BACK", "tubes"): b_tubes,
    ("ARM", "blade"): a_blade, ("ARM", "claw"): a_claw, ("ARM", "tentacle"): a_tentacle,
    ("ARM", "pincer"): a_pincer, ("ARM", "club"): a_club, ("ARM", "cannon"): a_cannon,
    ("LEG", "raptor"): l_raptor, ("LEG", "hoof"): l_hoof, ("LEG", "spider"): l_spider,
    ("LEG", "spring"): l_spring, ("LEG", "paw"): l_paw, ("LEG", "tread"): l_tread,
    ("TAIL", "stinger"): tl_stinger, ("TAIL", "whip"): tl_whip, ("TAIL", "club"): tl_club,
    ("TAIL", "fan"): tl_fan, ("TAIL", "rattle"): tl_rattle, ("TAIL", "flame"): tl_flame,
}


def seed_of(mid):
    return zlib.crc32(mid.encode("utf-8")) & 0xFFFFFFFF


def draw_part(entry, view, k, base):
    """Return the 32x32 XPart for one table entry and view."""
    art = entry["art"]
    slot = FRONT_SLOT.get(entry["socket"], entry["socket"]) if view == "front" else entry["socket"]
    p = XPart(view, slot, [hexc(c) for c in art["colors"]], hexc(art["accent"]),
              seed_of(entry["id"]), k, entry["id"], base)
    DRAWERS[(entry["socket"], art["motif"])](p, view == "front")
    return slot, p


# ==========================================================================
# ULTRA bodies: recolour the human base through a style ramp + structure
# ==========================================================================
def ultra_body(style, base, seed, accent, view):
    rng = random.Random(seed)
    F = view == "front"
    out = g.blank(64, 64)

    def m(x, y):
        return 0 <= x < 64 and 0 <= y < 64 and base[y][x][3] > 0

    pix = [(x, y) for y in range(64) for x in range(64) if m(x, y)]
    dist = {}
    frontier = [q for q in pix if not (m(q[0] - 1, q[1]) and m(q[0] + 1, q[1]) and m(q[0], q[1] - 1) and m(q[0], q[1] + 1))]
    for q in frontier:
        dist[q] = 1
    while frontier:
        nxt = []
        for x, y in frontier:
            for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if m(*q) and q not in dist:
                    dist[q] = dist[(x, y)] + 1
                    nxt.append(q)
        frontier = nxt
    eyes = {(x, y) for x, y in pix if sum(base[y][x][:3]) < 270}

    def tone(x, y):
        """0 outline, 1 shadow, 2 mid, 3 light (light comes from the top-left)."""
        if dist[(x, y)] == 1:
            return 0
        if not m(x - 2, y) or not m(x, y - 2):
            return 3
        if not m(x + 2, y) or not m(x, y + 2):
            return 1
        return 2

    def setp(x, y, c):
        if 0 <= x < 64 and 0 <= y < 64:
            out[y][x] = c

    def ext(x, y, c):
        if 0 <= x < 64 and 0 <= y < 64 and not m(x, y):
            out[y][x] = c

    def inb(x, y, c):
        if m(x, y):
            out[y][x] = c

    def voronoi(n):
        pts = rng.sample(pix, n)
        cell = {}
        for x, y in pix:
            cell[(x, y)] = min(range(n), key=lambda i: (x - pts[i][0]) ** 2 + (y - pts[i][1]) ** 2)
        border = {q for q in pix
                  if (m(q[0] + 1, q[1]) and cell[(q[0] + 1, q[1])] != cell[q])
                  or (m(q[0], q[1] + 1) and cell[(q[0], q[1] + 1)] != cell[q])}
        return cell, border

    def col(*rgb):
        return tuple(rgb) + (255,)

    if style == "crystal":
        cell, border = voronoi(20 if F else 16)
        ramp = [col(58, 40, 150), col(98, 86, 216), col(84, 170, 236), col(150, 228, 250), col(196, 172, 255)]
        pick = [rng.randrange(5) for _ in range(24)]
        dark = col(36, 24, 100)
        for x, y in pix:
            t = tone(x, y)
            if t == 0:
                c = dark if (m(x - 1, y) and m(x, y - 1)) else col(120, 110, 230)
            elif (x, y) in border:
                c = col(228, 250, 255)
            else:
                c = ramp[pick[cell[(x, y)]]]
                c = mix(c, WHITE, 0.4) if t == 3 else (mix(c, dark, 0.3) if t == 1 else c)
            setp(x, y, c)
        for q in eyes:
            setp(q[0], q[1], WHITE)
        if F:
            sh = [(18, 26, -1, -1, 5), (45, 26, 1, -1, 5), (22, 24, 0, -1, 4), (41, 24, 0, -1, 4),
                  (14, 35, -1, 0, 3), (49, 35, 1, 0, 3), (20, 45, -1, 0, 3), (43, 45, 1, 0, 3)]
        else:
            sh = [(28, 35, -1, -1, 5), (27, 42, -1, 0, 4), (41, 36, 1, -1, 4), (28, 47, -1, 1, 3)]
        for x0, y0, dx, dy, n in sh:
            for i in range(n):
                ext(x0 + dx * i, y0 + dy * i, WHITE if i == n - 1 else col(150, 228, 250))
                if i < n - 2:
                    ext(x0 + dx * i + (1 if dx == 0 else 0), y0 + dy * i + (1 if dx != 0 else 0), col(98, 86, 216))
        for _ in range(6):
            x, y = rng.choice(pix)
            if dist[(x, y)] > 1:
                setp(x, y, WHITE)

    elif style == "shadow":
        for x, y in pix:
            t = tone(x, y)
            c = col(8, 6, 14)
            if t == 0:
                c = col(30, 20, 52) if not (m(x - 1, y) and m(x, y - 1)) else col(16, 11, 28)
            elif t == 3 and (x + y) % 2 == 0:
                c = col(34, 24, 60)
            setp(x, y, c)
        edge = [q for q in pix if dist[q] == 1]
        for x, y in edge:
            if y >= 58 and F or y >= 61:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1)):
                if not m(x + dx, y + dy) and rng.random() < 0.22:
                    ext(x + dx, y + dy, col(22, 15, 40))
                    if rng.random() < 0.5:
                        ext(x + dx * 2, y + dy * 2 - 1, (60, 40, 110, 170))
                    if rng.random() < 0.3:
                        ext(x + dx * 2, y + dy * 2 - 3, (90, 60, 150, 110))
            if rng.random() < 0.07 and dist[(x, y)] == 1:
                setp(x, y, g.CLEAR)
        glow = accent
        for x, y in eyes:
            for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if m(*q) and q not in eyes:
                    setp(q[0], q[1], mix(glow, col(8, 6, 14), 0.55))
        for x, y in eyes:
            setp(x, y, mix(glow, WHITE, 0.35) if not F or y != 14 else glow)

    elif style == "molten":
        cell, border = voronoi(26 if F else 20)
        rocks = [col(40, 28, 32), col(56, 40, 42), col(30, 20, 26), col(70, 48, 46)]
        pick = [rng.randrange(4) for _ in range(30)]
        for x, y in pix:
            t = tone(x, y)
            c = rocks[pick[cell[(x, y)]]]
            if t == 0:
                c = col(18, 10, 14)
            elif t == 3:
                c = mix(c, col(120, 90, 84), 0.5)
            setp(x, y, c)
        for x, y in pix:
            if (x, y) in border:
                continue
            if any(q in border for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))) and dist[(x, y)] > 1:
                setp(x, y, mix(out[y][x], col(200, 60, 16), 0.45))
        for x, y in border:
            setp(x, y, col(255, 236, 140) if rng.random() < 0.3 else col(255, 138, 28))
        for q in eyes:
            setp(q[0], q[1], col(255, 244, 170))
        for _ in range(7):
            x, y = rng.choice(pix)
            if dist[(x, y)] == 1 and y < 40 and not m(x, y - 1):
                ext(x, y - 2 - rng.randint(0, 2), col(255, 150, 40))

    elif style == "slime":
        for x, y in pix:
            d, t = dist[(x, y)], tone(x, y)
            if t == 0:
                c = col(26, 104, 58)
            elif t == 3:
                c = col(196, 255, 176)
            elif d >= 7:
                c = col(24, 104, 70)
            elif d >= 5:
                c = col(38, 140, 82)
            elif t == 1:
                c = col(52, 164, 92)
            else:
                c = col(84, 206, 110)
            setp(x, y, c)
        for _ in range(12 if F else 9):
            x, y = rng.choice(pix)
            if dist[(x, y)] >= 3:
                setp(x, y, col(214, 255, 200))
                inb(x + 1, y, col(150, 240, 150))
                inb(x, y + 1, col(150, 240, 150))
                inb(x + 1, y + 1, col(30, 110, 66))
        for x in range(64):
            for y in range(57 if F else 50):
                if m(x, y) and not m(x, y + 1) and rng.random() < 0.34:
                    n = rng.randint(1, 4)
                    for i in range(1, n + 1):
                        if m(x, y + i) or m(x, y + i + 1):
                            break
                        ext(x, y + i, col(84, 206, 110) if i < n else col(26, 104, 58))
                    if rng.random() < 0.3:
                        ext(x, y + n + 2, col(84, 206, 110))
        for q in eyes:
            setp(q[0], q[1], col(10, 44, 30))
        for x, y in eyes:
            if (x, y - 1) not in eyes and (x - 1, y) not in eyes:
                setp(x, y, col(236, 255, 220))

    elif style == "gold":
        ramp = [col(96, 54, 10), col(170, 108, 20), col(228, 170, 40), col(255, 222, 104), col(255, 252, 214)]
        for x, y in pix:
            t = tone(x, y)
            b = (x + 2 * y) % 37
            if t == 2 and b in (0, 1, 2, 3):
                t = 3
            if t == 3 and (b == 1 or (not m(x - 2, y) and not m(x, y - 3))):
                t = 4
            setp(x, y, ramp[t])
        for x, y in pix:
            if dist[(x, y)] == 2 and not m(x - 2, y - 2) and (x + y) % 3 == 0:
                setp(x, y, WHITE)
        for q in eyes:
            setp(q[0], q[1], col(70, 34, 6))

    elif style == "skeletal":
        gap, gap2 = col(20, 16, 28), col(12, 10, 18)
        B, Bs = col(238, 230, 206), col(168, 158, 140)
        for x, y in pix:
            setp(x, y, gap2 if dist[(x, y)] == 1 else gap)

        def bone(x, y, c=None):
            if m(x, y) and dist[(x, y)] >= 2:
                out[y][x] = c or (Bs if tone(x, y) == 1 else B)

        def brect(x0, y0, x1, y1, c=None):
            for yy in range(y0, y1 + 1):
                for xx in range(x0, x1 + 1):
                    bone(xx, yy, c)

        def hole(cx, cy, r):
            for yy in range(int(cy - r - 1), int(cy + r + 2)):
                for xx in range(int(cx - r - 1), int(cx + r + 2)):
                    if (xx - cx) ** 2 + (yy - cy) ** 2 <= (r + 0.4) ** 2:
                        inb(xx, yy, gap)

        if F:
            brect(21, 3, 42, 21)
            hole(26.5, 13, 2.5)
            hole(35.5, 13, 2.5)
            for xx in (26, 27, 35, 36):
                setp(xx, 13, accent)
            for q in ((31, 16), (32, 16), (31, 17), (32, 17), (23, 17), (40, 17), (23, 18), (40, 18)):
                inb(q[0], q[1], gap)
            for xx in range(25, 39):
                inb(xx, 19, gap)
                if xx % 2 == 0:
                    inb(xx, 20, gap)
            for half in (0, 1):
                def X(v):
                    return 63 - v if half else v
                brect(min(X(31), X(31)), 22, max(X(31), X(31)), 26)
                for xx in range(20, 31):
                    bone(X(xx), 26)
                for i, yy in enumerate((28, 30, 32, 34, 36)):
                    for xx in range(25 + (i // 3), 31):
                        bone(X(xx), yy)
                    bone(X(25 + (i // 3)), yy + 1, Bs)
                for yy in range(27, 43):
                    bone(X(31), yy, B if yy % 2 or yy < 36 else Bs)
                for xx in range(18, 20):
                    for yy in range(27, 29):
                        bone(X(xx), yy)
                for yy in range(29, 38):
                    bone(X(17), yy)
                    if yy != 33:
                        bone(X(18), yy, Bs)
                bone(X(16), 38)
                bone(X(17), 38)
                for xx in range(24, 31):
                    bone(X(xx), 43)
                    bone(X(xx), 44)
                for xx in range(23, 28):
                    bone(X(xx), 45)
                    bone(X(xx), 46)
                inb(X(30), 44, gap)
                inb(X(29), 45, gap)
                for yy in range(47, 53):
                    bone(X(24), yy)
                    bone(X(25), yy, Bs)
                for xx in range(23, 27):
                    bone(X(xx), 53)
                    bone(X(xx), 54)
                for yy in range(55, 60):
                    bone(X(24), yy)
                    bone(X(25), yy, Bs if yy < 59 else B)
                for xx in range(22, 26):
                    bone(X(xx), 59)
            inb(31, 23, gap)
            inb(32, 23, gap)
        else:
            brect(21, 7, 45, 31)
            hole(42.5, 18.5, 2.5)
            setp(42, 18, accent)
            setp(43, 18, accent)
            setp(42, 19, accent)
            for q in ((44, 22), (44, 23), (43, 23)):
                inb(q[0], q[1], gap)
            for xx in range(36, 45):
                inb(xx, 25, gap)
                if xx % 2 == 0:
                    inb(xx, 26, gap)
                    inb(xx, 27, gap)
            for yy in range(25, 30):
                inb(35, yy, gap)
            for yy in range(32, 50):
                if yy % 3 != 1:
                    bone(30, yy)
                    bone(29, yy, Bs)
            for yy in (34, 36, 38, 40, 42, 44):
                for xx in range(31, 40):
                    bone(xx, yy, Bs if xx >= 38 else B)
            for yy in range(35, 47):
                inb(33, yy, gap)
                inb(36, yy, gap)
                bone(34, yy, B)
                bone(35, yy, Bs)
            brect(34, 47, 35, 48)
            brect(31, 48, 36, 50)
            inb(33, 49, gap)
            inb(34, 49, gap)
            for yy in range(51, 57):
                bone(33, yy)
                bone(34, yy, Bs)
            brect(32, 57, 35, 58)
            for yy in range(59, 62):
                bone(33, yy)
                bone(34, yy, Bs)
            brect(32, 62, 38, 62)

    elif style == "void":
        for x, y in pix:
            d = dist[(x, y)]
            if d == 1:
                c = col(240, 224, 255) if (not m(x - 1, y) or not m(x, y - 1)) else col(160, 96, 250)
            elif d == 2:
                c = col(58, 24, 128)
            elif d == 3:
                c = col(30, 12, 76)
            else:
                c = col(12, 5, 34)
                if math.sin(x * 0.45 + y * 0.3 + seed % 7) > 0.72:
                    c = col(44, 14, 92)
            setp(x, y, c)
        stars = [WHITE, col(160, 224, 255), col(255, 170, 240), col(255, 244, 190)]
        for x, y in pix:
            if dist[(x, y)] >= 2 and rng.random() < 0.055:
                setp(x, y, rng.choice(stars))
        for _ in range(4):
            x, y = rng.choice(pix)
            if dist[(x, y)] >= 3:
                for q in ((x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    inb(q[0], q[1], WHITE if q == (x, y) else col(150, 130, 255))
        for q in eyes:
            setp(q[0], q[1], WHITE)

    elif style == "angelic":
        ramp = [col(226, 184, 92), col(206, 214, 246), col(255, 249, 232), WHITE]
        gold, gold_l = col(232, 186, 72), col(255, 236, 150)
        for x, y in pix:
            setp(x, y, ramp[tone(x, y)])
        if F:
            trim_rows = (25, 41, 42, 58)
            for x, y in pix:
                torso = 24 <= x <= 39
                if (y in (25, 26) and 21 <= x <= 42) or (y in (41, 42) and torso) or y == 57 \
                        or (y == 36 and not torso):
                    setp(x, y, gold_l if (x + y) % 4 == 0 else gold)
            for q in ((31, 29), (32, 29), (30, 30), (33, 30), (31, 31), (32, 31)):
                setp(q[0], q[1], gold)
            setp(31, 30, accent)
            setp(32, 30, accent)
            setp(31, 41, accent)
            setp(32, 41, accent)
            del trim_rows
        else:
            for x, y in pix:
                if y in (32, 33, 46, 58) or (y == 47 and x <= 31):
                    setp(x, y, gold_l if (x + y) % 4 == 0 else gold)
            setp(39, 38, gold)
            setp(39, 39, accent)
            setp(39, 40, gold)
        for x, y in pix:
            if dist[(x, y)] == 1:
                for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not m(*q) and (F and q[1] < 61 or not F):
                        ext(q[0], q[1], (255, 240, 170, 120))
        for q in eyes:
            setp(q[0], q[1], col(84, 150, 232))
    else:
        raise ValueError("unknown ultra body style: %s" % style)
    return out


# ==========================================================================
# Preview sheets
# ==========================================================================
CW, CH, OX, OY = 68, 74, 2, 7
BG_A, BG_B = (74, 80, 94, 255), (64, 70, 84, 255)


def blend(dst, src, x0, y0, flip=False):
    sh, sw = len(src), len(src[0])
    for y in range(sh):
        for x in range(sw):
            c = src[y][sw - 1 - x] if flip else src[y][x]
            if not c[3]:
                continue
            dx, dy = x0 + x, y0 + y
            if not (0 <= dy < len(dst) and 0 <= dx < len(dst[0])):
                continue
            if c[3] == 255 or not dst[dy][dx][3]:
                dst[dy][dx] = c if c[3] == 255 or not dst[dy][dx][3] else c
                if c[3] != 255 and dst[dy][dx][3] == 0:
                    dst[dy][dx] = c
            else:
                dst[dy][dx] = mix(dst[dy][dx], c, c[3] / 255.0)


def cell(view, base, parts, bg):
    """Composite parts [(slot, px)] on a body inside one padded sheet cell."""
    out = [[bg] * CW for _ in range(CH)]
    half = g.PART_SIZE // 2

    def place(slot, px, flip=False, sock=None):
        sx, sy = sock or g.SOCKETS[view][slot]
        blend(out, px, sx - half + OX, sy - half + OY, flip)

    for slot, px in parts:
        if slot in g.BEHIND:
            place(slot, px)
    blend(out, base, OX, OY)
    for slot, px in parts:
        if slot not in g.BEHIND:
            place(slot, px)
            if view == "front" and slot in g.FRONT_MIRRORS:
                place(slot, px, True, g.SOCKETS["front"][g.FRONT_MIRRORS[slot]])
    return out


def sheet(rows_of_cells, k):
    cols = max(len(r) for r in rows_of_cells)
    img = [[BG_A] * (cols * CW) for _ in range(len(rows_of_cells) * CH)]
    for ry, row in enumerate(rows_of_cells):
        for rx, c in enumerate(row):
            if c is not None:
                g.blit(img, c, rx * CW, ry * CH)
    return g.scale(img, k)


def chunk(seq, n):
    return [seq[i:i + n] for i in range(0, len(seq), n)]


def main():
    os.makedirs(g.PARTS_DIR, exist_ok=True)
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    bases = {v: g.read_png(os.path.join(g.TORSO_DIR, "human_%s.png" % v))[2] for v in ("front", "side")}
    debug_dir = os.environ.get("GEN_PARTS_DEBUG")

    counts, n_parts, n_bodies = {}, 0, 0
    drawn = {"front": {}, "side": {}}      # id -> (slot, px)
    for e in MUTATIONS:
        key = (e["socket"], e["art"]["motif"])
        k = counts.get(key, 0)
        counts[key] = k + 1
        if e.get("existing") or e["id"] in g.MUTATIONS:
            continue                       # never overwrite the hand-made parts
        for view in ("front", "side"):
            slot, p = draw_part(e, view, k, bases[view])
            g.write_png(os.path.join(g.PARTS_DIR, "%s_%s.png" % (e["id"], view)), p.px)
            drawn[view][e["id"]] = (slot, p.px)
            n_parts += 1

    bodies = {}
    for e in MUTATIONS:
        if not e.get("body"):
            continue
        for view in ("front", "side"):
            img = ultra_body(e["body"]["style"], bases[view], seed_of(e["id"] + view),
                             hexc(e["art"]["accent"]), view)
            g.write_png(os.path.join(g.TORSO_DIR, "body_%s_%s.png" % (e["id"], view)), img)
            bodies[(e["id"], view)] = img
            n_bodies += 1

    # contact sheets: grouped by socket, same motif adjacent
    new = [e for e in MUTATIONS if e["id"] in drawn["front"]]
    for view in ("front", "side"):
        rows = []
        for sock in SOCKET_ORDER:
            group = sorted((e for e in new if e["socket"] == sock), key=lambda e: e["art"]["motif"])
            cells = [cell(view, bases[view], [drawn[view][e["id"]]], BG_B if i % 2 else BG_A)
                     for i, e in enumerate(group)]
            rows += chunk(cells, 12)
            if view == "front":
                for j, line in enumerate(chunk(group, 12)):
                    print("  %s row %d: %s" % (sock, j, " | ".join(
                        "%s(%s)" % (e["id"], e["art"]["motif"]) for e in line)))
            if debug_dir:
                g.write_png(os.path.join(debug_dir, "dbg_%s_%s.png" % (sock, view)), sheet(chunk(cells, 6), 4))
        g.write_png(os.path.join(EVIDENCE_DIR, "stage4_parts_%s_4x.png" % view), sheet(rows, 3))

    ucells = []
    for i, e in enumerate(e for e in MUTATIONS if e.get("body")):
        for view in ("front", "side"):
            ucells.append(cell(view, bodies[(e["id"], view)], [drawn[view][e["id"]]], BG_B if i % 2 else BG_A))
    g.write_png(os.path.join(EVIDENCE_DIR, "stage4_ultra_bodies_4x.png"), sheet(chunk(ucells, 4), 4))
    print("ext: wrote %d part PNGs (%d mutations x 2 views) to %s" % (n_parts, n_parts // 2, g.PARTS_DIR))
    print("ext: wrote %d ULTRA body PNGs to %s" % (n_bodies, g.TORSO_DIR))
    print("ext: wrote preview sheets to %s" % EVIDENCE_DIR)


if __name__ == "__main__":
    main()
