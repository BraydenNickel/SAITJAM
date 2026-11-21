"""Fused-part sprite generator for Mutant Lab (design/fusion-contract.md section 3).

Standard library only. Run from the project root:

    python tools/gen_hybrids.py

Reads   tools/mutation_table.py (never written), tools/signature_table.py (optional),
        assets/sprites/torso/human_front.png / human_side.png (body mask),
        assets/sprites/parts/*.png (only for the parent cells of the preview sheets).
Writes  assets/sprites/hybrids/<socket>_<view>.png   atlases, 32x32 cells, 16 columns
        assets/sprites/hybrids/sig_<a>__<b>_<view>.png bespoke signature sprites
        src/data/fusion_index.json                    pair key -> socket + cell, signatures
        production/qa/evidence/fusion_*_4x.png        preview sheets (not assets)

Cell order per socket: every unordered pair "<a>+<b>" (a < b) in sorted key order,
then every twin "<a>+<a>" in sorted id order. Front and side atlases share indices.

How a sprite is built
  Hybrid  shape parent S (higher rarity; tie -> crc32(pair key)) is drawn with its own
          drawer in the palette of the other parent C; C's motif is then added in S's
          palette. HEAD/TORSO/BACK: C's sprite shrunk in place and laid over (or under,
          whichever is smaller goes on top). ARM/TAIL: C's tip is spliced onto S's limb
          along the geodesic distance from the root. LEG: S's thigh, C's shin and foot.
  Twin    the parent's own sprite with a darker second copy behind it (offset or
          mirrored) and a brightened accent.
  Mark    every fused sprite carries a dashed stitch (dark + bright accent) along the
          seam between its two sources; that is the class marker.
  Signature  the table's motif and colours, an extra graft or doubled copy, one
          flourish overlay, a dark outer outline and a light rim.

Set GEN_HYBRIDS_DEBUG=<dir> to also write 3x per-socket sheets for both views there;
GEN_HYBRIDS_SAMPLE=<n> shifts which pairs the sample sheets show.
"""
import heapq
import importlib
import json
import math
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_parts as g  # noqa: E402
import gen_parts_ext as X  # noqa: E402
from mutation_table import MUTATIONS  # noqa: E402

OUT_DIR = os.path.join(g.ROOT, "assets", "sprites", "hybrids")
INDEX_PATH = os.path.join(g.ROOT, "src", "data", "fusion_index.json")
RES_DIR = "res://assets/sprites/hybrids/"
CELL, COLUMNS = 32, 16
VIEWS = ("front", "side")
SPLICE = ("ARM", "LEG", "TAIL")          # limbs: tip splice instead of overlay
FLOURISHES = ("glow", "spikes", "eyes", "crown", "flames", "runes", "drips", "sparks")
WHITE, BLACK, CLEAR = X.WHITE, X.BLACK, g.CLEAR
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

# Root of each limb in base coordinates (where it leaves the body).
ROOTS = {("ARM", "front"): (17.5, 30), ("ARM", "side"): (31, 35),
         ("TAIL", "front"): (31.5, 47), ("TAIL", "side"): (29, 49)}
LEG_CUT = {"front": 54, "side": 57}      # base y of the thigh / shin splice
SHRINK = {"HEAD": 0.72, "TORSO": 0.7, "BACK": 0.72}
# Twin: where the darker second copy goes; "flip" mirrors the cell. First fit wins.
TWIN_OFF = {
    ("HEAD", "front"): ((0, -3), (0, 3), (0, -2)), ("HEAD", "side"): ((-3, -2), (0, -3), (-3, 0), (2, 3)),
    ("TORSO", "front"): ((0, 4), (0, -3)), ("TORSO", "side"): ((0, 4), (2, 3), (0, -3)),
    ("BACK", "front"): ((0, -4), (0, 4), (0, -3)), ("BACK", "side"): ((0, -4), (2, -4), (0, 4)),
    ("ARM", "front"): ((-3, -2), (-3, 0), (3, -2), (0, -3)), ("ARM", "side"): ((-1, -4), (0, -4), (-3, -3), (2, -4)),
    ("LEG", "front"): ((-4, 0), (-3, 0), (3, 0)), ("LEG", "side"): ((-5, 0), (-4, 0), (4, 0)),
    ("TAIL", "front"): ("flip", (0, -4), (4, -2), (-4, -2)), ("TAIL", "side"): ((0, -5), (2, -5), (0, -4), (0, 4)),
}

BASES = {}
BY_ID = {e["id"]: e for e in MUTATIONS}
K = {}                                   # id -> ordinal inside its (socket, motif) group
_counts = {}
for _e in MUTATIONS:
    _key = (_e["socket"], _e["art"]["motif"])
    K[_e["id"]] = _counts.get(_key, 0)
    _counts[_key] = K[_e["id"]] + 1


# --------------------------------------------------------------------------
# small pixel helpers (all on 32x32 local cells)
# --------------------------------------------------------------------------
def crc(s):
    return zlib.crc32(s.encode("utf-8")) & 0xFFFFFFFF


def blank():
    return [[CLEAR] * CELL for _ in range(CELL)]


def inside(x, y):
    return 0 <= x < CELL and 0 <= y < CELL


def opq(px):
    return {(x, y) for y in range(CELL) for x in range(CELL) if px[y][x][3]}


def dark(c, t=0.5):
    return X.mix(c, BLACK, t)


def centroid(pts):
    n = float(len(pts)) or 1.0
    return sum(q[0] for q in pts) / n, sum(q[1] for q in pts) / n


def comps(pts):
    """8-connected components of a pixel set, in scan order."""
    left, out = set(pts), []
    for start in sorted(pts, key=lambda q: (q[1], q[0])):
        if start not in left:
            continue
        left.discard(start)
        comp, stack = [], [start]
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in left:
                        left.discard(q)
                        stack.append(q)
        out.append(comp)
    return out


def draw(socket, motif, cols, accent, seed, k, mid, view):
    slot = X.FRONT_SLOT.get(socket, socket) if view == "front" else socket
    p = X.XPart(view, slot, list(cols), accent, seed, k, mid, BASES[view])
    X.DRAWERS[(socket, motif)](p, view == "front")
    return slot, p


def art_of(e):
    a = e["art"]
    return a["motif"], [X.hexc(c) for c in a["colors"]], X.hexc(a["accent"])


def overlay(lower, upper, stitch):
    """upper over lower; the lower pixels along the seam become a dashed stitch."""
    out = [row[:] for row in lower]
    up = opq(upper)
    seam = 0
    for (x, y) in sorted(opq(lower) - up):
        if any((x + dx, y + dy) in up for dx, dy in N4):
            out[y][x] = stitch if (x + 2 * y) % 3 == 0 else dark(lower[y][x], 0.6)
            seam += 1
    for (x, y) in up:
        out[y][x] = upper[y][x]
    return out, seam


def fallback_mark(px, stitch):
    """Three stitch dashes through the middle of the sprite (when no seam exists)."""
    pts = opq(px)
    if not pts:
        return
    inner = [q for q in pts if all((q[0] + dx, q[1] + dy) in pts for dx, dy in N4)] or list(pts)
    cx, cy = centroid(pts)
    x, y = min(sorted(inner), key=lambda q: (q[0] - cx) ** 2 + (q[1] - cy) ** 2)
    for i in range(-2, 3):
        if (x + i, y) in pts:
            px[y][x + i] = stitch if i % 2 == 0 else dark(px[y][x + i], 0.6)


def shrink(src, accents, s):
    """Scale every connected component about its own centroid (forward mapping)."""
    out = blank()
    for comp in comps(opq(src)):
        sc = s if len(comp) >= 9 else 1.0
        cx, cy = centroid(comp)
        for last in (False, True):       # accent pixels win
            for (x, y) in comp:
                c = src[y][x]
                if (c in accents) != last:
                    continue
                nx, ny = X.ri(cx + (x - cx) * sc), X.ri(cy + (y - cy) * sc)
                if inside(nx, ny):
                    out[ny][nx] = c
    return out


def graft(P, G, accents, s, stitch):
    """HEAD/TORSO/BACK: shrunk second parent laid over (or under) the first."""
    pa = opq(P)
    for _ in range(3):
        small = shrink(G, accents, s)
        ga = opq(small)
        lower, upper = (P, small) if len(ga) <= len(pa) else (small, P)
        lo, up = opq(lower), opq(upper)
        if len(lo - up) >= 0.3 * len(lo) or s < 0.45:
            break
        s -= 0.14
    out, seam = overlay(lower, upper, stitch)
    if seam < 4:
        fallback_mark(out, stitch)
    return out


def geo(px, root):
    """Distance from the limb root along the sprite (8-connected Dijkstra)."""
    pts = opq(px)
    if not pts:
        return {}
    start = min(sorted(pts), key=lambda q: (q[0] - root[0]) ** 2 + (q[1] - root[1]) ** 2)
    dist, heap = {start: 0.0}, [(0.0, start)]
    while heap:
        d, (x, y) = heapq.heappop(heap)
        if d > dist[(x, y)]:
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q in pts:
                    nd = d + (1.4 if dx and dy else 1.0)
                    if nd < dist.get(q, 1e9):
                        dist[q] = nd
                        heapq.heappush(heap, (nd, q))
    reached = sorted(dist)
    for q in sorted(pts - set(dist)):    # loose bits (accent tips): hang off the nearest pixel
        n = min(reached, key=lambda r: (r[0] - q[0]) ** 2 + (r[1] - q[1]) ** 2)
        dist[q] = dist[n] + math.hypot(n[0] - q[0], n[1] - q[1])
    return dist


def splice(P, G, socket, view, slot, rng, stitch):
    """ARM/LEG/TAIL: first parent's limb with the second parent's end."""
    sx, sy = g.SOCKETS[view][slot]
    ymax = min(CELL - 1, 63 - sy + CELL // 2)
    base, tip = blank(), blank()
    if socket == "LEG":
        cut = LEG_CUT[view] + rng.choice((-1, 0, 0, 1)) - sy + CELL // 2
        for y in range(CELL):
            for x in range(CELL):
                if y < cut:
                    base[y][x] = P[y][x]
                else:
                    tip[y][x] = G[y][x]
    else:
        rx, ry = ROOTS[(socket, view)]
        root = (rx - sx + CELL // 2, ry - sy + CELL // 2)
        fp, fs = (0.72, 0.6) if socket == "ARM" else (0.6, 0.55)
        fp += rng.choice((-0.04, 0.0, 0.04))
        dp, ds = geo(P, root), geo(G, root)
        if not dp or not ds:
            return [row[:] for row in (P if dp else G)]
        cp, cs = fp * max(dp.values()), fs * max(ds.values())
        keep = [q for q in dp if dp[q] <= cp]
        tips = [q for q in ds if ds[q] > cs]
        bp = [q for q in dp if abs(dp[q] - cp) <= 2] or keep
        bs = [q for q in ds if abs(ds[q] - cs) <= 2] or tips
        (ax, ay), (bx, by) = centroid(bp), centroid(bs)
        ox, oy = X.ri(ax - bx), X.ri(ay - by)
        if tips:
            xs, ys = [q[0] for q in tips], [q[1] for q in tips]
            ox = max(-min(xs), min(ox, CELL - 1 - max(xs)))
            oy = max(-min(ys), min(oy, ymax - max(ys)))
        for (x, y) in keep:
            base[y][x] = P[y][x]
        for (x, y) in tips:
            if inside(x + ox, y + oy):
                tip[y + oy][x + ox] = G[y][x]
    out, seam = overlay(base, tip, stitch)
    prune(out)
    if seam < 3:
        fallback_mark(out, stitch)
    return out


def prune(px):
    """Drop loose pieces that are more than 2 px away from the main mass of a spliced limb."""
    parts = sorted(comps(opq(px)), key=len, reverse=True)
    if len(parts) < 2:
        return
    main, rest, grew = set(parts[0]), parts[1:], True
    while grew:
        grew = False
        for comp in rest[:]:
            if any((x + dx, y + dy) in main for (x, y) in comp for dx in range(-2, 3) for dy in range(-2, 3)):
                main.update(comp)
                rest.remove(comp)
                grew = True
    for comp in rest:
        for (x, y) in comp:
            px[y][x] = CLEAR


def visible(px, view, slot):
    """Opaque pixels the body does not hide (BACK and TAIL are drawn behind it)."""
    pts = opq(px)
    if slot not in g.BEHIND:
        return pts
    sx, sy = g.SOCKETS[view][slot]
    base = BASES[view]
    out = set()
    for (lx, ly) in pts:
        x, y = lx + sx - CELL // 2, ly + sy - CELL // 2
        if not (0 <= x < 64 and 0 <= y < 64 and base[y][x][3] > 0):
            out.add((lx, ly))
    return out


def alt_k(ka, kb, h):
    """Sub-style ordinal that differs from both parents under as many moduli as possible."""
    def score(c):
        return sum(1 for m in (2, 3, 4, 5) if c % m not in (ka % m, kb % m))
    return max(range(12), key=lambda c: (score(c), -((c - h) % 12)))


# --------------------------------------------------------------------------
# hybrid / twin / signature
# --------------------------------------------------------------------------
def shape_parent(a, b, h):
    if a["rarity"] != b["rarity"]:
        return (a, b) if a["rarity"] > b["rarity"] else (b, a)
    return (a, b) if h & 1 else (b, a)


def hybrid(a, b, view):
    key = "%s+%s" % (a["id"], b["id"])
    h = crc(key)
    S, C = shape_parent(a, b, h)
    sock = a["socket"]
    sm, scols, sacc = art_of(S)
    cm, ccols, cacc = art_of(C)
    gcols = scols
    if scols == ccols:                   # same colour family: lift the graft so it still reads
        gcols = [X.mix(c, WHITE, 0.28) for c in scols]
    if sm == cm:
        k, seed, gseed = alt_k(K[S["id"]], K[C["id"]], h), h, h ^ 0x5BD1E995
    else:
        k, seed, gseed = K[S["id"]], X.seed_of(S["id"]), X.seed_of(C["id"])
    slot, P = draw(sock, sm, ccols, sacc, seed, k, S["id"], view)
    _, G = draw(sock, cm, gcols, cacc, gseed, K[C["id"]], C["id"], view)
    stitch = X.mix(sacc, WHITE, 0.5)
    rng = random.Random(h)
    if sock in SPLICE:
        out = splice(P.px, G.px, sock, view, slot, rng, stitch)
        if sock == "LEG":
            return out
        tip_cols = set(gcols) | {cacc}
        seen_px = visible(out, view, slot)
        tip_seen = sum(1 for (x, y) in seen_px if out[y][x] in tip_cols)
        if "fan" not in (sm, cm) and tip_seen >= 6 and len(seen_px) >= 0.6 * len(visible(P.px, view, slot)):
            return out
        # radial shapes, or a splice whose tip got lost behind the body: lay the second tail over the first
        return graft(P.px, G.px, (cacc, WHITE), 0.75, stitch)
    return graft(P.px, G.px, (cacc, WHITE), SHRINK[sock] + rng.choice((-0.04, 0.0, 0.04)), stitch)


def doubled(front, socket, view, slot, keep, stitch, shade=0.32):
    """front + a darker second copy behind it. keep = colours left unshaded."""
    fa = opq(front)
    sx, sy = g.SOCKETS[view][slot]
    base = BASES[view]

    def on_body(lx, ly):
        x, y = lx + sx - CELL // 2, ly + sy - CELL // 2
        return 0 <= x < 64 and 0 <= y < 64 and base[y][x][3] > 0

    best, best_score = None, None
    for off in TWIN_OFF[(socket, view)]:
        back, clipped = blank(), 0
        for (x, y) in fa:
            nx, ny = (CELL - 1 - x, y) if off == "flip" else (x + off[0], y + off[1])
            if not inside(nx, ny) or ny + sy - CELL // 2 > 63:
                clipped += 1
                continue
            if socket == "TORSO" and on_body(x, y) and not on_body(nx, ny):
                continue                 # body-hugging textures stay on the body
            c = front[y][x]
            back[ny][nx] = c if c in keep else dark(c, shade)
        vis = len(opq(back) - fa)
        score = vis - 4 * clipped
        if best is None or score > best_score:
            best, best_score = back, score
        if clipped == 0 and vis >= 0.25 * len(fa):
            best = back
            break
    out, seam = overlay(best, front, stitch)
    if seam < 4:
        fallback_mark(out, stitch)
    return out


def twin(e, view):
    motif, cols, acc = art_of(e)
    bright = X.mix(acc, WHITE, 0.45)
    cols = [cols[0], cols[1], X.mix(cols[2], WHITE, 0.3)]
    slot, p = draw(e["socket"], motif, cols, bright, X.seed_of(e["id"]), K[e["id"]], e["id"], view)
    stitch = X.mix(acc, WHITE, 0.7)
    out = doubled(p.px, e["socket"], view, slot, (bright, WHITE), stitch)
    changed = sum(1 for y in range(CELL) for x in range(CELL) if out[y][x] != p.px[y][x])
    if changed < 45:                     # second copy hidden (body-hugging part): add a bright inner layer
        lit = [[c if (not c[3] or c in (bright, WHITE)) else X.mix(c, WHITE, 0.38) for c in row] for row in p.px]
        out, _seam = overlay(out, shrink(lit, (bright, WHITE), 0.6), stitch)
    return out


def edge_pts(px):
    pts = opq(px)
    return sorted(q for q in pts if any((q[0] + dx, q[1] + dy) not in pts for dx, dy in N4))


def spread(pts, n, rng):
    """n points of pts far apart from each other (greedy farthest point)."""
    pts = sorted(pts)
    if not pts:
        return []
    out = [pts[rng.randrange(len(pts))]]
    while len(out) < min(n, len(pts)):
        out.append(max(pts, key=lambda q: min((q[0] - o[0]) ** 2 + (q[1] - o[1]) ** 2 for o in out)))
    return out


def flourish_pre(px, name, pal, rng):
    """Flourishes that add to or paint on the silhouette (before the outline)."""
    D, M, L, A = pal
    pts = opq(px)
    if not pts:
        return
    cx, cy = centroid(pts)
    edges = edge_pts(px)

    def put(x, y, c, only_on=None):
        x, y = X.ri(x), X.ri(y)
        if inside(x, y) and (only_on is None or ((x, y) in pts) == only_on):
            px[y][x] = c

    if name == "spikes":
        for (x, y) in spread(edges, 7, rng):
            l = math.hypot(x - cx, y - cy) or 1.0
            dx, dy = (x - cx) / l, (y - cy) / l
            n = rng.choice((3, 4))
            for i in range(1, n + 1):
                put(x + dx * i, y + dy * i, A if i == n else (L if i > 1 else M))
                if i == 1:
                    put(x + dx - dy, y + dy + dx, M, False)
    elif name == "flames":
        tops = [q for q in edges if (q[0], q[1] - 1) not in pts]
        for (x, y) in spread(tops, 5, rng):
            hgt, sway = rng.randint(3, 5), rng.choice((-1, 1))
            for i in range(1, hgt + 1):
                c = L if i <= 1 else (A if i < hgt else X.mix(A, WHITE, 0.6))
                put(x + (sway if i >= hgt - 1 else 0), y - i, c)
                if i <= 2:
                    put(x + 1, y - i, M if i == 1 else L, False)
    elif name == "drips":
        bots = [q for q in edges if (q[0], q[1] + 1) not in pts]
        for (x, y) in spread(bots, 4, rng):
            n = rng.randint(2, 4)
            for i in range(1, n + 1):
                put(x, y + i, L if i == n else M)
            put(x, y + n + 2, A, False)
    elif name == "crown":
        top = min(q[1] for q in pts)
        xs = [q[0] for q in pts if q[1] <= top + 2]
        mx = X.ri((min(xs) + max(xs)) / 2.0)
        by = max(top - 1, 4)
        for x in range(mx - 4, mx + 5):
            put(x, by, M)
            put(x, by - 1, L)
            put(x, by + 1, D)
        for i, x in enumerate((mx - 4, mx - 2, mx, mx + 2, mx + 4)):
            hgt = 3 if i % 2 == 0 else 2
            for j in range(2, hgt + 1):
                put(x, by - j, L)
            put(x, by - hgt - 1, A)
        put(mx, by, A)
        put(mx - 3, by, WHITE)
        put(mx + 3, by, WHITE)
    elif name == "eyes":
        inner = [q for q in pts if all((q[0] + dx, q[1] + dy) in pts for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
        for (x, y) in spread(inner or list(pts), 3, rng):
            for dx in (-1, 0, 1):
                put(x + dx, y - 1, dark(D, 0.5), True)
                put(x + dx, y + 1, dark(D, 0.5), True)
            put(x - 1, y, WHITE, True)
            put(x + 1, y, WHITE, True)
            put(x, y, A, True)
    elif name == "runes":
        glyphs = (((0, 0), (0, 1), (0, 2), (1, 0)), ((0, 0), (1, 1), (2, 0)),
                  ((0, 0), (1, 0), (2, 0), (1, 1), (1, 2)), ((0, 0), (0, 2), (1, 1)),
                  ((0, 0), (1, 0), (1, 1), (1, 2), (2, 2)))
        inner = [q for q in pts if all((q[0] + dx, q[1] + dy) in pts for dx, dy in N4)]
        for i, (x, y) in enumerate(spread(inner or list(pts), 4, rng)):
            for dx, dy in glyphs[(i + rng.randrange(5)) % 5]:
                put(x + dx - 1, y + dy - 1, A if (dx + dy) % 2 == 0 else X.mix(A, WHITE, 0.5), True)


def flourish_post(px, name, pal, rng):
    """Flourishes drawn around the finished, outlined sprite."""
    A = pal[3]
    pts = opq(px)
    if not pts:
        return
    cx, cy = centroid(pts)
    if name == "glow":
        ring1 = {(x + dx, y + dy) for (x, y) in pts for dx, dy in N4} - pts
        ring2 = {(x + dx, y + dy) for (x, y) in ring1 for dx, dy in N4} - pts - ring1
        for ring, alpha in ((ring1, 170), (ring2, 80)):
            for (x, y) in ring:
                if inside(x, y):
                    px[y][x] = (A[0], A[1], A[2], alpha)
    elif name == "sparks":
        for i, (x, y) in enumerate(spread(edge_pts(px), 6, rng)):
            l = math.hypot(x - cx, y - cy) or 1.0
            r = 3 if i < 3 else rng.randint(2, 4)
            sx, sy = X.ri(x + (x - cx) / l * r), X.ri(y + (y - cy) / l * r)
            cells = [(sx, sy, WHITE)]
            if i < 3:
                cells += [(sx + dx, sy + dy, A) for dx, dy in N4]
            for qx, qy, c in cells:
                if inside(qx, qy) and (qx, qy) not in pts:
                    px[qy][qx] = c


def rim(px, pal):
    """Dark outer outline + light top-left rim: the 'signature' finish."""
    D, M, L, A = pal
    pts = opq(px)
    out_c, hi = dark(D, 0.6), X.mix(L, WHITE, 0.5)
    ring = {(x + dx, y + dy) for (x, y) in pts for dx, dy in N4} - pts
    for (x, y) in pts:
        if ((x - 1, y) in ring or (x, y - 1) in ring) and px[y][x] not in (A, WHITE):
            px[y][x] = hi
    for (x, y) in ring:
        if inside(x, y):
            px[y][x] = out_c


def signature(sig, view):
    a, b = BY_ID[sig["a"]], BY_ID[sig["b"]]
    key = "%s+%s" % (a["id"], b["id"])
    h = crc("sig:" + key)
    sock = a["socket"]
    art = sig["art"]
    S, C = shape_parent(a, b, h)
    motif = art.get("motif")
    if (sock, motif) not in X.DRAWERS:
        motif = S["art"]["motif"]
    cols = [X.hexc(c) for c in art["colors"]][:3]
    acc = X.hexc(art["accent"])
    pal = (cols[0], cols[1], cols[2], acc)
    rng = random.Random(h)
    slot, p = draw(sock, motif, cols, acc, h, h % 12, key, view)
    stitch = X.mix(acc, WHITE, 0.6)
    if sock in SPLICE:
        px = doubled(p.px, sock, view, slot, (acc, WHITE), stitch, 0.4)
    else:
        other = C if C["art"]["motif"] != motif else (S if S["art"]["motif"] != motif else C)
        gcols = [X.mix(cols[0], acc, 0.25), X.mix(cols[1], acc, 0.4), X.mix(cols[2], WHITE, 0.45)]
        _, G = draw(sock, other["art"]["motif"], gcols, WHITE, X.seed_of(other["id"]),
                    K[other["id"]] + 1, other["id"], view)
        px = graft(p.px, G.px, (WHITE,), 0.62, stitch)
    name = art.get("flourish")
    if name not in FLOURISHES:
        name = "glow"
    flourish_pre(px, name, pal, rng)
    rim(px, pal)
    flourish_post(px, name, pal, rng)
    return px


def load_signatures():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "signature_table.py")
    if not os.path.exists(path):
        print("WARNING: tools/signature_table.py not found - no signature sprites; re-run later.")
        return []
    try:
        table = importlib.import_module("signature_table").SIGNATURES
    except Exception as err:  # noqa: BLE001  (any failure of the other file must not stop us)
        print("WARNING: tools/signature_table.py failed to import (%r) - no signature sprites." % (err,))
        return []
    out, seen = [], set()
    for s in table:
        try:
            a, b = sorted((s["a"], s["b"]))
            ea, eb = BY_ID[a], BY_ID[b]
            art = s["art"]
            ok = a != b and ea["socket"] == eb["socket"] and len(art["colors"]) >= 3
            [X.hexc(c) for c in art["colors"]], X.hexc(art["accent"])
        except Exception as err:  # noqa: BLE001
            print("WARNING: signature skipped, bad entry %r (%r)" % (s, err))
            continue
        if not ok or (a, b) in seen:
            print("WARNING: signature skipped (same id, sockets differ or duplicate): %s + %s" % (a, b))
            continue
        seen.add((a, b))
        if (ea["socket"], art.get("motif")) not in X.DRAWERS:
            print("WARNING: signature %s+%s: motif %r has no %s drawer, using a parent motif"
                  % (a, b, art.get("motif"), ea["socket"]))
        if art.get("flourish") not in FLOURISHES:
            print("WARNING: signature %s+%s: unknown flourish %r, using glow" % (a, b, art.get("flourish")))
        out.append(dict(s, a=a, b=b))
    return sorted(out, key=lambda s: (s["a"], s["b"]))


# --------------------------------------------------------------------------
# previews
# --------------------------------------------------------------------------
WW, WH = 48, 52
BG = ((74, 80, 94, 255), (64, 70, 84, 255))
SEP = (40, 44, 54, 255)
BG_HI = ((98, 104, 120, 255), (88, 94, 110, 255))


def body_cell(view, socket, px, bg):
    """Part on the human body, cropped to a window around its socket."""
    slot = X.FRONT_SLOT.get(socket, socket) if view == "front" else socket
    c = X.cell(view, BASES[view], [(slot, px)], bg)
    sx, sy = g.SOCKETS[view][slot]
    x0 = min(max(sx + X.OX - WW // 2, 0), X.CW - WW)
    y0 = min(max(sy + X.OY - WH // 2, 0), X.CH - WH)
    out = [row[x0:x0 + WW] for row in c[y0:y0 + WH]]
    out[-1] = [SEP] * WW                 # cell border: windows are crops of the body
    for row in out:
        row[-1] = SEP
    return out


def tile(rows_of_cells, k):
    cols = max(len(r) for r in rows_of_cells)
    img = [[BG[0]] * (cols * WW) for _ in range(len(rows_of_cells) * WH)]
    for ry, row in enumerate(rows_of_cells):
        for rx, c in enumerate(row):
            for y in range(WH):
                img[ry * WH + y][rx * WW:(rx + 1) * WW] = c[y]
    return g.scale(img, k)


def base_sprite(e, view):
    path = os.path.join(g.PARTS_DIR, "%s_%s.png" % (e["id"], view))
    try:
        return g.read_png(path)[2]
    except Exception:  # noqa: BLE001  (file may be mid-regeneration)
        motif, cols, acc = art_of(e)
        return draw(e["socket"], motif, cols, acc, X.seed_of(e["id"]), K[e["id"]], e["id"], view)[1].px


def sample(seq, n, shift=0):
    if len(seq) <= n:
        return list(seq)
    return [seq[(i * len(seq) // n + shift * 7 + i * 3) % len(seq)] for i in range(n)]


def hybrid_rows(view, sockets, cells, per_row, n, shift):
    rows = []
    for sock in sockets:
        keys = sample([k for k in cells[sock]["order"] if len(set(k.split("+"))) == 2], n, shift)
        line = []
        for i, key in enumerate(keys):
            a, b = key.split("+")
            line.append(body_cell(view, sock, base_sprite(BY_ID[a], view), BG[i % 2]))
            line.append(body_cell(view, sock, base_sprite(BY_ID[b], view), BG[i % 2]))
            line.append(body_cell(view, sock, cells[sock][view][key], BG_HI[i % 2]))
        rows += X.chunk(line, per_row * 3)
        print("  sample %-5s %s: %s" % (sock, view, " | ".join(keys)))
    return rows


def twin_rows(view, sockets, cells, n, per_row):
    line = []
    for sock in sockets:
        ids = sorted(k.split("+")[0] for k in cells[sock]["order"] if len(set(k.split("+"))) == 1)
        for i, mid in enumerate(sample(ids, n, 1)):
            line.append(body_cell(view, sock, base_sprite(BY_ID[mid], view), BG[i % 2]))
            line.append(body_cell(view, sock, cells[sock][view]["%s+%s" % (mid, mid)], BG_HI[i % 2]))
    return X.chunk(line, per_row * 2)


# --------------------------------------------------------------------------
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(X.EVIDENCE_DIR, exist_ok=True)
    for v in VIEWS:
        BASES[v] = g.read_png(os.path.join(g.TORSO_DIR, "human_%s.png" % v))[2]
    shift = int(os.environ.get("GEN_HYBRIDS_SAMPLE", "0"))
    debug_dir = os.environ.get("GEN_HYBRIDS_DEBUG")

    cells, pairs_index, problems, sizes = {}, [], [], []
    for sock in X.SOCKET_ORDER:
        ids = sorted(e["id"] for e in MUTATIONS if e["socket"] == sock)
        n = len(ids)
        pair_keys = sorted("%s+%s" % (a, b) for i, a in enumerate(ids) for b in ids[i + 1:])
        order = pair_keys + ["%s+%s" % (a, a) for a in ids]
        cells[sock] = {"order": order, "front": {}, "side": {}}
        for view in VIEWS:
            store = cells[sock][view]
            for key in order:
                a, b = key.split("+")
                store[key] = twin(BY_ID[a], view) if a == b else hybrid(BY_ID[a], BY_ID[b], view)
            rows = (len(order) + COLUMNS - 1) // COLUMNS
            atlas = [[CLEAR] * (COLUMNS * CELL) for _ in range(rows * CELL)]
            seen, dups, empty = {}, [], []
            for i, key in enumerate(order):
                px = store[key]
                ox, oy = (i % COLUMNS) * CELL, (i // COLUMNS) * CELL
                for y in range(CELL):
                    atlas[oy + y][ox:ox + CELL] = px[y]
                if not opq(px):
                    empty.append(key)
                sig = hash(tuple(tuple(r) for r in px))
                if sig in seen:
                    dups.append((seen[sig], key))
                seen.setdefault(sig, key)
            path = os.path.join(OUT_DIR, "%s_%s.png" % (sock.lower(), view))
            g.write_png(path, atlas)
            sizes.append((path, os.path.getsize(path)))
            want = n * (n - 1) // 2 + n
            status = "ok" if len(order) == want and not empty else "FAIL"
            if status != "ok":
                problems.append("%s %s: %d cells, want %d, empty %s" % (sock, view, len(order), want, empty))
            print("%-5s %-5s n=%2d cells=%3d (pairs %3d + twins %2d, want %3d) empty=%d identical=%d  %s"
                  % (sock, view, n, len(order), len(pair_keys), n, want, len(empty), len(dups), status))
            for d in dups:
                print("      identical cells: %s == %s" % d)
        for i, key in enumerate(order):
            pairs_index.append((key, sock, i))

    # signatures
    sig_index = []
    for s in load_signatures():
        key = "%s+%s" % (s["a"], s["b"])
        files = {}
        for view in VIEWS:
            px = signature(s, view)
            name = "sig_%s__%s_%s.png" % (s["a"], s["b"], view)
            g.write_png(os.path.join(OUT_DIR, name), px)
            files[view] = (name, px)
            if not opq(px):
                problems.append("signature %s %s is empty" % (key, view))
        sig_index.append((key, s, files))
    print("signatures: %d written" % len(sig_index))

    # index
    lines = ['{', ' "cell": %d,' % CELL, ' "columns": %d,' % COLUMNS, ' "pairs": {']
    lines.append(",\n".join('  %s: {"socket": "%s", "cell": %d}' % (json.dumps(k), s, i) for k, s, i in pairs_index))
    lines += [' },', ' "signatures": {']
    lines.append(",\n".join(
        '  %s: {"name": %s, "desc": %s, "front": %s, "side": %s}'
        % (json.dumps(k), json.dumps(s.get("name", "")), json.dumps(s.get("desc", "")),
           json.dumps(RES_DIR + f["front"][0]), json.dumps(RES_DIR + f["side"][0]))
        for k, s, f in sig_index))
    lines += [' }', '}', '']
    text = "\n".join(l for l in lines if l != "" or l is lines[-1])
    json.loads(text)
    os.makedirs(os.path.dirname(INDEX_PATH), exist_ok=True)
    with open(INDEX_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    if len(set(k for k, _s, _i in pairs_index)) != len(pairs_index):
        problems.append("duplicate pair keys in the index")
    print("index: %d pair keys, %d signatures, %d bytes -> %s"
          % (len(pairs_index), len(sig_index), os.path.getsize(INDEX_PATH), INDEX_PATH))

    # previews
    ev = X.EVIDENCE_DIR
    g.write_png(os.path.join(ev, "fusion_hybrids_sample_4x.png"),
                tile(hybrid_rows("front", X.SOCKET_ORDER, cells, 4, 12, shift), 4))
    g.write_png(os.path.join(ev, "fusion_twins_sample_4x.png"),
                tile(twin_rows("front", X.SOCKET_ORDER, cells, 2, 6), 4))
    if sig_index:
        line = []
        for i, (key, s, files) in enumerate(sig_index):
            sock = BY_ID[s["a"]]["socket"]
            line.append(body_cell("front", sock, files["front"][1], BG[i % 2]))
            line.append(body_cell("side", sock, files["side"][1], BG[i % 2]))
        g.write_png(os.path.join(ev, "fusion_signatures_4x.png"), tile(X.chunk(line, 12), 4))
        print("  signatures sheet order: " + " | ".join(
            "%s(%s)" % (s.get("name", k), s["art"].get("flourish")) for k, s, _f in sig_index))
    if debug_dir:
        os.makedirs(debug_dir, exist_ok=True)
        for view in VIEWS:
            for tag, socks in (("a", X.SOCKET_ORDER[:3]), ("b", X.SOCKET_ORDER[3:])):
                g.write_png(os.path.join(debug_dir, "dbg_hyb_%s_%s.png" % (view, tag)),
                            tile(hybrid_rows(view, socks, cells, 4, 12, shift), 3))
            g.write_png(os.path.join(debug_dir, "dbg_twins_%s.png" % view),
                        tile(twin_rows(view, X.SOCKET_ORDER, cells, 6, 6), 3))

    total = sum(sz for _p, sz in sizes)
    print("atlases: %d files, %d bytes total in %s" % (len(sizes), total, OUT_DIR))
    if problems:
        print("SELF-CHECK FAILED:")
        for p in problems:
            print("  " + p)
        sys.exit(1)
    print("SELF-CHECK OK: %d cells (801 pairs + 100 twins expected: %s)"
          % (len(pairs_index), "yes" if len(pairs_index) == 901 else "NO"))


if __name__ == "__main__":
    main()
