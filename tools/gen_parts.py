"""Generate placeholder mutation part sprites for Mutant Lab.

Standard library only (zlib + struct). Reads the 64x64 base human PNGs and
writes 32x32 RGBA part PNGs, each centred on its socket point, plus composite
previews (1x and 4x) for checking alignment.

Usage (from project root):  python tools/gen_parts.py

All part drawing uses BASE coordinates (pixel coords on the 64x64 body); the
Part canvas converts them so that the socket lands on the 32x32 image centre
(pixel 16,16), which is where a centered Sprite2D places its origin.
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TORSO_DIR = os.path.join(ROOT, "assets", "sprites", "torso")
PARTS_DIR = os.path.join(ROOT, "assets", "sprites", "parts")

# --------------------------------------------------------------------------
# Sockets (base pixel coords). Mirror of tuning in the game; keep in sync.
# --------------------------------------------------------------------------
SOCKETS = {
    "front": {
        "HEAD": (32, 12), "TORSO": (32, 32), "BACK": (32, 28),
        "ARM_L": (18, 34), "ARM_R": (46, 34),
        "LEG_L": (24, 53), "LEG_R": (40, 53), "TAIL": (32, 46),
    },
    "side": {
        "HEAD": (34, 18), "TORSO": (34, 40), "BACK": (29, 38),
        "ARM": (35, 40), "LEG": (34, 56), "TAIL": (28, 48),
    },
}
PART_SIZE = 32

# --------------------------------------------------------------------------
# Palette (complements peach skin 238,195,154)
# --------------------------------------------------------------------------
IVORY = (236, 226, 196, 255)
IVORY_D = (182, 164, 128, 255)
FLESH = (186, 54, 62, 255)
FLESH_L = (222, 96, 96, 255)
FLESH_D = (116, 28, 42, 255)
THROAT = (48, 12, 24, 255)
CHITIN = (72, 164, 98, 255)
CHITIN_L = (146, 218, 140, 255)
CHITIN_D = (34, 92, 62, 255)
SCALE = (112, 118, 58, 255)
SCALE_L = (158, 150, 84, 255)
SCALE_D = (64, 66, 36, 255)
PURPLE = (132, 52, 156, 255)
MAGENTA = (204, 70, 168, 255)
PURPLE_D = (78, 28, 96, 255)
TOXIC = (196, 240, 80, 255)
SPORE = (212, 206, 70, 255)
SPORE_L = (246, 242, 160, 255)
SPORE_D = (146, 136, 38, 255)
CLEAR = (0, 0, 0, 0)


# --------------------------------------------------------------------------
# PNG I/O
# --------------------------------------------------------------------------
def read_png(path):
    """Read an 8-bit RGBA (colour type 6) non-interlaced PNG -> (w, h, rows of tuples)."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    i, idat, w, h = 8, b"", 0, 0
    while i < len(data):
        n, = struct.unpack(">I", data[i:i + 4])
        ctype = data[i + 4:i + 8]
        chunk = data[i + 8:i + 8 + n]
        i += 12 + n
        if ctype == b"IHDR":
            w, h, depth, colour, _c, _f, interlace = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and colour == 6 and interlace == 0, "need 8-bit RGBA"
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(idat)
    bpp, stride = 4, w * 4
    prev = bytearray(stride)
    rows, pos = [], 0
    for _y in range(h):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 255
            elif ftype == 2:
                line[x] = (line[x] + b) & 255
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append([tuple(line[x * 4:x * 4 + 4]) for x in range(w)])
        prev = line
    return w, h, rows


def write_png(path, rows):
    """Write rows of RGBA tuples as an 8-bit RGBA PNG (filter 0)."""
    h, w = len(rows), len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


# --------------------------------------------------------------------------
# Drawing helpers
# --------------------------------------------------------------------------
class Part:
    """32x32 canvas addressed in base (64x64) coordinates around a socket."""

    def __init__(self, socket):
        self.sx, self.sy = socket
        self.px = [[CLEAR] * PART_SIZE for _ in range(PART_SIZE)]

    def _local(self, x, y):
        return x - self.sx + PART_SIZE // 2, y - self.sy + PART_SIZE // 2

    def put(self, x, y, c):
        lx, ly = self._local(x, y)
        if 0 <= lx < PART_SIZE and 0 <= ly < PART_SIZE:
            self.px[ly][lx] = c

    def get(self, x, y):
        lx, ly = self._local(x, y)
        if 0 <= lx < PART_SIZE and 0 <= ly < PART_SIZE:
            return self.px[ly][lx]
        return CLEAR

    def rect(self, x0, y0, x1, y1, c):
        """Filled rect, inclusive corners."""
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, ring=None):
        """Filled ellipse (pixel centres). ring=k draws only the outer k px."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                d = ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2
                if d <= 1.0:
                    if ring is not None:
                        irx, iry = rx - ring, ry - ring
                        if irx >= 0 and iry >= 0:
                            di = ((x - cx) / (irx + 0.5)) ** 2 + ((y - cy) / (iry + 0.5)) ** 2
                            if di <= 1.0:
                                continue
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        """Bresenham line; width>1 stamps a square brush."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        lo = -(width // 2)
        hi = lo + width
        while True:
            for oy in range(lo, hi):
                for ox in range(lo, hi):
                    self.put(x0 + ox, y0 + oy, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def mirror_x(self, axis2):
        """Copy the left half onto the right, mirrored about base x = axis2/2."""
        for ly in range(PART_SIZE):
            for lx in range(PART_SIZE):
                x = lx + self.sx - PART_SIZE // 2
                y = ly + self.sy - PART_SIZE // 2
                c = self.px[ly][lx]
                if c[3] and x * 2 < axis2:
                    self.put(axis2 - x, y, c)

    def outline(self, shade=0.62, skip=()):
        """Inner outline: darken opaque pixels that touch transparency."""
        src = [row[:] for row in self.px]
        for y in range(PART_SIZE):
            for x in range(PART_SIZE):
                c = src[y][x]
                if not c[3] or c in skip:
                    continue
                edge = False
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < PART_SIZE and 0 <= ny < PART_SIZE) or not src[ny][nx][3]:
                        edge = True
                        break
                if edge:
                    self.px[y][x] = (int(c[0] * shade), int(c[1] * shade), int(c[2] * shade), 255)


def blank(w, h):
    return [[CLEAR] * w for _ in range(h)]


def blit(dst, src, x0, y0, flip=False):
    """Alpha-test blit (pixel art: alpha is 0 or 255)."""
    sh, sw = len(src), len(src[0])
    for y in range(sh):
        for x in range(sw):
            c = src[y][sw - 1 - x] if flip else src[y][x]
            if c[3]:
                dx, dy = x0 + x, y0 + y
                if 0 <= dy < len(dst) and 0 <= dx < len(dst[0]):
                    dst[dy][dx] = c


def scale(rows, k):
    out = []
    for row in rows:
        big = [c for c in row for _ in range(k)]
        out.extend([big[:] for _ in range(k)])
    return out


# --------------------------------------------------------------------------
# Parts -- FRONT view (facing viewer)
# --------------------------------------------------------------------------
def leech_maw_front():
    p = Part(SOCKETS["front"]["HEAD"])
    cx, cy = 31.5, 19.5
    p.ellipse(cx, cy, 7, 4.5, FLESH_D)
    p.ellipse(cx, cy, 6, 3.5, FLESH)
    p.ellipse(cx, cy - 0.5, 5, 2.5, FLESH_L, ring=1)
    p.ellipse(cx, cy, 3.5, 2, THROAT)
    # radial ring of ivory teeth pointing into the throat
    for x, y in ((29, 17), (31, 17), (32, 17), (34, 17), (27, 19), (36, 19),
                 (27, 20), (36, 20), (29, 22), (31, 22), (32, 22), (34, 22)):
        p.put(x, y, IVORY)
    for x, y in ((30, 18), (33, 18), (28, 19), (35, 19), (30, 21), (33, 21)):
        p.put(x, y, IVORY_D)
    return p


def bone_plating_front():
    p = Part(SOCKETS["front"]["TORSO"])
    # shoulder pauldrons with a bone spike (left, then mirrored)
    p.rect(18, 27, 23, 29, IVORY)
    p.rect(17, 29, 21, 31, IVORY)
    p.rect(17, 31, 21, 31, IVORY_D)
    p.rect(22, 29, 23, 29, IVORY_D)
    p.line(18, 27, 17, 24, IVORY, 1)
    p.put(18, 26, IVORY)
    # ribs curving down from the sternum
    for y, x_end in ((28, 25), (31, 25), (34, 26), (37, 27)):
        p.line(30, y, x_end + 2, y, IVORY)
        p.line(x_end + 1, y + 1, x_end, y + 2, IVORY)
        p.line(30, y + 1, x_end + 2, y + 1, IVORY_D)
    p.mirror_x(63)
    # sternum keel (centre, drawn after mirroring)
    p.rect(31, 26, 32, 40, IVORY)
    p.rect(31, 41, 32, 41, IVORY_D)
    p.put(31, 26, IVORY_D)
    return p


def spore_sacs_front():
    p = Part(SOCKETS["front"]["BACK"])
    # big shoulder pod, small pod on top, tiny bud low on the flank
    p.ellipse(19, 22, 4, 4, SPORE_D)
    p.ellipse(19, 22, 3, 3, SPORE)
    p.put(17, 20, SPORE_L); p.put(18, 20, SPORE_L); p.put(17, 21, SPORE_L)
    p.put(20, 24, SPORE_D); p.put(18, 25, SPORE_D)
    p.ellipse(23, 14, 3, 3, SPORE_D)
    p.ellipse(23, 14, 2, 2, SPORE)
    p.put(22, 13, SPORE_L)
    p.ellipse(16, 27, 2, 2, SPORE_D)
    p.put(16, 27, SPORE)
    p.put(15, 26, SPORE_L)
    p.mirror_x(63)
    return p


def mantis_arm_front():
    p = Part(SOCKETS["front"]["ARM_L"])
    # chitin shoulder + upper arm over the human arm
    p.rect(16, 31, 20, 33, CHITIN)
    p.rect(15, 34, 19, 37, CHITIN)
    p.rect(16, 31, 20, 31, CHITIN_L)
    p.rect(15, 35, 19, 35, CHITIN_D)
    p.rect(15, 37, 18, 37, CHITIN_D)
    # forearm joint
    p.rect(14, 38, 17, 39, CHITIN_D)
    # scythe blade: sweeps down/outward then hooks inward
    blade = [(13, 40), (12, 41), (11, 42), (10, 43), (10, 44), (9, 45), (9, 46),
             (9, 47), (10, 48), (11, 49)]
    for i, (x, y) in enumerate(blade):
        p.rect(x, y, x + (2 if i < 6 else 1), y, CHITIN)
        p.put(x, y, CHITIN_L)  # bright cutting edge on the outside
    # serrations on the inner edge
    for x, y in ((15, 41), (14, 43), (13, 45), (12, 47)):
        p.put(x, y, CHITIN_D)
    p.put(12, 49, CHITIN_L)
    return p


def raptor_leg_front():
    p = Part(SOCKETS["front"]["LEG_L"])
    # heavy scaly thigh, full width of the human leg
    p.rect(21, 47, 30, 51, SCALE)
    p.rect(21, 48, 21, 51, SCALE_D)
    # forward knee bulge
    p.rect(21, 52, 28, 54, SCALE_D)
    p.rect(22, 52, 27, 53, SCALE)
    # narrower shin
    p.rect(22, 55, 27, 58, SCALE)
    p.rect(23, 59, 26, 59, SCALE)
    # belly highlight stripe
    p.rect(26, 48, 27, 57, SCALE_L)
    # scale texture
    for y in range(48, 58, 2):
        for x in range(22 + (y // 2) % 2, 25, 2):
            p.put(x, y, SCALE_D)
    # spread three-toed foot with ivory talons
    p.rect(20, 60, 29, 61, SCALE_D)
    for x in (19, 24, 30):
        p.put(x, 61, IVORY_D)
        p.put(x, 62, IVORY)
        p.put(x, 63, IVORY)
    return p

def scorpion_tail_front():
    p = Part(SOCKETS["front"]["TAIL"])
    # segments run down between the legs, sweep out past the right hip,
    # and curl up beside the body with the stinger hooking inward
    segs = [(31.5, 48, 2), (31.5, 52, 2), (32, 56, 2), (35, 59, 2), (39, 60, 2),
            (43, 58, 2), (45, 54, 2), (46, 50, 2), (46, 46, 2), (45, 43, 1.5)]
    for i, (x, y, r) in enumerate(segs):
        p.ellipse(x, y, r, r, PURPLE_D)
        p.ellipse(x, y, r - 1, r - 1, MAGENTA if i % 2 == 0 else PURPLE)
    # stinger bulb + barb
    p.ellipse(44, 40, 2, 2, PURPLE_D)
    p.ellipse(44, 40, 1, 1, MAGENTA)
    p.put(43, 37, TOXIC); p.put(42, 37, TOXIC); p.put(43, 38, PURPLE_D)
    p.put(41, 38, TOXIC)
    return p


# --------------------------------------------------------------------------
# Parts -- SIDE view (facing right)
# --------------------------------------------------------------------------
def leech_maw_side():
    p = Part(SOCKETS["side"]["HEAD"])
    # fleshy tube jutting from the lower face
    p.rect(40, 21, 46, 28, FLESH)
    p.rect(40, 21, 46, 21, FLESH_L)
    p.rect(40, 28, 46, 28, FLESH_D)
    # flared sucker disc at the front
    p.rect(47, 17, 48, 31, FLESH)
    p.rect(47, 18, 47, 30, FLESH_L)
    p.put(47, 17, FLESH_D); p.put(47, 31, FLESH_D)
    # teeth ringing the rim
    for y in range(18, 31, 2):
        p.put(49, y, IVORY)
    for y in range(19, 31, 2):
        p.put(49, y, FLESH_D)
    p.outline(skip=(IVORY, FLESH_D))
    # dark gullet seam
    p.rect(42, 24, 46, 25, THROAT)
    return p


def bone_plating_side():
    p = Part(SOCKETS["side"]["TORSO"])
    # shoulder plate
    p.rect(30, 32, 39, 34, IVORY)
    p.rect(29, 35, 38, 35, IVORY_D)
    # ribs wrapping the chest, tips jutting forward as spurs
    for y in (37, 40, 43, 46):
        p.rect(35, y, 41, y, IVORY)
        p.put(42, y, IVORY)
        p.put(43, y - 1, IVORY)
        p.rect(35, y + 1, 41, y + 1, IVORY_D)
    # spine knobs along the back edge
    for y in (35, 39, 43, 47):
        p.put(27, y, IVORY)
        p.put(28, y, IVORY_D)
    return p


def spore_sacs_side():
    p = Part(SOCKETS["side"]["BACK"])
    for (x, y, rx, ry) in ((24, 35, 4, 4), (22, 42, 3, 3), (25, 47, 2, 2), (28, 30, 2, 2)):
        p.ellipse(x, y, rx, ry, SPORE)
    for x, y in ((22, 33), (23, 33), (22, 34), (21, 41), (24, 46), (27, 29)):
        p.put(x, y, SPORE_L)
    for x, y in ((25, 37), (23, 44), (26, 48)):
        p.put(x, y, SPORE_D)
    p.outline(skip=(SPORE_L,))
    return p


def mantis_arm_side():
    p = Part(SOCKETS["side"]["ARM"])
    # chitin upper arm over the hanging human arm
    p.rect(31, 36, 34, 43, CHITIN)
    p.rect(32, 36, 32, 43, CHITIN_L)
    # elbow joint
    p.rect(31, 44, 35, 46, CHITIN)
    # scythe: thick back that thins to a hooked point, swept forward/down
    p.line(35, 45, 44, 50, CHITIN, 3)
    p.line(44, 50, 46, 53, CHITIN, 2)
    p.put(45, 54, CHITIN); p.put(44, 55, CHITIN)
    # bright cutting edge underneath
    p.line(35, 47, 43, 52, CHITIN_L)
    # serration teeth on the top edge
    for x, y in ((37, 44), (40, 45), (43, 47)):
        p.put(x, y, CHITIN)
    p.outline(shade=0.6, skip=(CHITIN_L,))
    return p

def raptor_leg_side():
    p = Part(SOCKETS["side"]["LEG"])
    # far leg in shadow, hides the human shin behind the digitigrade bend
    p.rect(31, 55, 36, 61, SCALE_D)
    # muscular thigh covering the hip
    p.ellipse(34.5, 53, 4.5, 2.5, SCALE)
    # high knee jutting forward
    p.rect(37, 54, 39, 56, SCALE)
    # shin raking back to the hock
    p.line(38, 56, 33, 59, SCALE, 3)
    # long raised metatarsal down to the toes
    p.line(32, 59, 34, 62, SCALE, 3)
    # toes forward + talons
    p.rect(34, 62, 39, 63, SCALE)
    p.outline(skip=())
    p.put(40, 62, IVORY); p.put(40, 63, IVORY); p.put(41, 63, IVORY)
    # raised sickle claw on the inner toe
    p.put(35, 61, IVORY); p.put(36, 60, IVORY)
    # scale texture
    for x, y in ((33, 52), (35, 53), (37, 52), (37, 55), (35, 57), (33, 60)):
        p.put(x, y, SCALE_L)
    return p

def scorpion_tail_side():
    p = Part(SOCKETS["side"]["TAIL"])
    # out of the lower back, down-left, then arching up with the stinger
    # pointing forward over the back
    segs = [(28, 49, 2.5), (24, 51, 2.5), (20, 50, 2), (16, 47, 2), (14, 43, 2),
            (14, 39, 2), (16, 35, 1.5)]
    for i, (x, y, r) in enumerate(segs):
        p.ellipse(x, y, r, r, MAGENTA if i % 2 == 0 else PURPLE)
    p.ellipse(19, 34, 2, 1.5, PURPLE)
    p.outline(skip=())
    p.put(22, 34, TOXIC); p.put(23, 35, TOXIC); p.put(22, 35, PURPLE_D)
    return p

MUTATIONS = {
    # id: (front fn, side fn, front slot, side slot)
    "leech_maw": (leech_maw_front, leech_maw_side, "HEAD", "HEAD"),
    "bone_plating": (bone_plating_front, bone_plating_side, "TORSO", "TORSO"),
    "spore_sacs": (spore_sacs_front, spore_sacs_side, "BACK", "BACK"),
    "mantis_arm": (mantis_arm_front, mantis_arm_side, "ARM_L", "ARM"),
    "raptor_leg": (raptor_leg_front, raptor_leg_side, "LEG_L", "LEG"),
    "scorpion_tail": (scorpion_tail_front, scorpion_tail_side, "TAIL", "TAIL"),
}

BEHIND = {"BACK", "TAIL"}
# Mirrored copies for the front view: right side uses flip_h of the left part.
FRONT_MIRRORS = {"ARM_L": "ARM_R", "LEG_L": "LEG_R"}


def composite(view, base, parts):
    """parts: list of (slot, Part). Returns 64x64 rows."""
    out = blank(64, 64)
    half = PART_SIZE // 2

    def place(slot, part, flip=False, socket=None):
        sx, sy = socket or SOCKETS[view][slot]
        blit(out, part.px, sx - half, sy - half, flip)

    for slot, part in parts:
        if slot in BEHIND:
            place(slot, part)
    blit(out, base, 0, 0)
    for slot, part in parts:
        if slot not in BEHIND:
            place(slot, part)
            if view == "front" and slot in FRONT_MIRRORS:
                place(slot, part, flip=True, socket=SOCKETS["front"][FRONT_MIRRORS[slot]])
    return out


def main():
    os.makedirs(PARTS_DIR, exist_ok=True)
    _, _, base_front = read_png(os.path.join(TORSO_DIR, "human_front.png"))
    _, _, base_side = read_png(os.path.join(TORSO_DIR, "human_side.png"))
    front_parts, side_parts = [], []
    for mid, (ffn, sfn, fslot, sslot) in MUTATIONS.items():
        fp, sp = ffn(), sfn()
        write_png(os.path.join(PARTS_DIR, mid + "_front.png"), fp.px)
        write_png(os.path.join(PARTS_DIR, mid + "_side.png"), sp.px)
        front_parts.append((fslot, fp))
        side_parts.append((sslot, sp))
    for view, base, parts in (("front", base_front, front_parts), ("side", base_side, side_parts)):
        img = composite(view, base, parts)
        write_png(os.path.join(PARTS_DIR, "preview_%s.png" % view), img)
        write_png(os.path.join(PARTS_DIR, "preview_%s_4x.png" % view), scale(img, 4))
    print("wrote %d parts + previews to %s" % (len(MUTATIONS) * 2, PARTS_DIR))


if __name__ == "__main__":
    main()
