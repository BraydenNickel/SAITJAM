"""Make assets/sprites/menu/btn_skills(.png|_hover.png) for the main menu.

Standard library only. Takes the CODEX button pair, erases its baked text and
writes "SKILLS" in the same 3 px-cell pixel font (6 cells tall, 1 cell gap).
The glyph bitmaps below were transcribed from the existing buttons' text
(O, E, T, N, I from CODEX / NEW RUN / SETTINGS); P, A, L are drawn to match.
Run from the repo root: python tools/art/make_potential_button.py
"""
import os
import sys

sys.path.insert(0, "C:/Users/brayd/godotgames/money-tree/tools")
from gen_parts import read_png, write_png  # noqa: E402

MENU = "C:/Users/brayd/godotgames/money-tree/assets/sprites/menu/"
CELL = 3
ORIGIN = (9, 10)  # top-left pixel of the first glyph (same as CODEX)
TEXT_NORMAL = (255, 255, 255, 255)
TEXT_HOVER = (150, 255, 110, 255)
OUTLINE_HOVER = (57, 255, 20, 120)
GLYPHS = {
    "S": [".XXX", "X...", ".XX.", "...X", "...X", "XXX."],
    "K": ["X..X", "X.X.", "XX..", "X.X.", "X..X", "X..X"],
    "P": ["XXX.", "X..X", "X..X", "XXX.", "X...", "X..."],
    "O": [".XXX.", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X.."],
    "E": ["XXXX", "X...", "XXX.", "X...", "X...", "XXXX"],
    "N": ["X..X", "XX.X", "X.XX", "X..X", "X..X", "X..X"],
    "I": ["XXX", ".X.", ".X.", ".X.", ".X.", "XXX"],
    "A": [".XX.", "X..X", "X..X", "XXXX", "X..X", "X..X"],
    "L": ["X...", "X...", "X...", "X...", "X...", "XXXX"],
}


def text_mask(word):
    cells = set()
    cx = 0
    for ch in word:
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == "X":
                    cells.add((cx + gx, gy))
        cx += len(g[0]) + 1
    px = set()
    for (gx, gy) in cells:
        for dy in range(CELL):
            for dx in range(CELL):
                px.add((ORIGIN[0] + gx * CELL + dx, ORIGIN[1] + gy * CELL + dy))
    return px


def main():
    mask = text_mask("SKILLS")
    # Normal: white text on a transparent box with a thin frame.
    w, h, rows = read_png(MENU + "btn_codex.png")
    rows = [[(0, 0, 0, 0) if p == TEXT_NORMAL else p for p in r] for r in rows]
    for (x, y) in mask:
        rows[y][x] = TEXT_NORMAL
    write_png(MENU + "btn_skills.png", rows)
    # Hover: green text with a 1 px glow outline on a dark green fill.
    w, h, rows = read_png(MENU + "btn_codex_hover.png")
    fill = rows[20][150]
    rows = [[fill if p in (TEXT_HOVER, OUTLINE_HOVER) else p for p in r] for r in rows]
    for (x, y) in mask:
        for (nx, ny) in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in mask and 0 <= nx < w and 0 <= ny < h:
                rows[ny][nx] = OUTLINE_HOVER
    for (x, y) in mask:
        rows[y][x] = TEXT_HOVER
    write_png(MENU + "btn_skills_hover.png", rows)
    print("wrote btn_skills.png / btn_skills_hover.png")


if __name__ == "__main__":
    main()
