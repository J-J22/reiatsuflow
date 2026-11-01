"""Draw the ReiatsuFlow logo, a pixel-art hell butterfly (jigokuchō), as SVG.

    python3 tools/make_logo.py   ->  data-files/reiatsuflow.svg            (app icon, on a dark tile)
                                     data-files/reiatsuflow-symbolic.svg   (one colour, for bars and panels)
                                     ui/logo.svg                           (no tile, for the app header)
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# left half of a 16x16 grid; the right half mirrors it.  # edge (ember)  w wing  e spot  b body
HALF = [
    ".....#..",
    "......#.",
    ".......b",
    ".##....b",
    "#ww#...b",
    "#www#..b",
    "#wwew#.b",
    "#wwwww#b",
    ".#wwww#b",
    "..####.b",
    "...#ww#b",
    "..#wew#b",
    "..#www#.",
    "...###..",
]
GRID = [row + row[::-1] for row in HALF]
FULL = {"#": "#ff8a3d", "w": "#1b1024", "e": "#a35ad8", "b": "#0a0610"}


def rects(colors, cell, ox, oy):
    out = []
    for y, row in enumerate(GRID):
        for x, ch in enumerate(row):
            if ch in colors:
                out.append(f'<rect x="{ox + x * cell}" y="{oy + y * cell}" width="{cell}" height="{cell}" fill="{colors[ch]}"/>')
    return "\n  ".join(out)


def svg(size, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" shape-rendering="crispEdges">\n'
            f'  {body}\n</svg>\n')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


tile = ('<defs><radialGradient id="g" cx="50%" cy="45%" r="60%">'
        '<stop offset="0" stop-color="#3a1c22"/><stop offset="1" stop-color="#140c10"/></radialGradient></defs>\n'
        '  <rect width="64" height="64" rx="14" fill="url(#g)"/>\n  ')
write(os.path.join(ROOT, "data-files", "reiatsuflow.svg"), svg(64, tile + rects(FULL, 3, 8, 11)))
# symbolic: a simpler silhouette drawn for 16 px (the detailed one turns to mush that small),
# one colour, recoloured by whoever draws it
SMALL = [
    "##..........##",
    "###...##...###",
    "####..##..####",
    "#####.##.#####",
    "##############",
    ".############.",
    "..###.##.###..",
    ".####.##.####.",
    ".####....####.",
    "..##......##..",
]
small = "\n  ".join(f'<rect x="{1 + x}" y="{3 + y}" width="1" height="1" fill="#ffffff"/>'
                    for y, row in enumerate(SMALL) for x, ch in enumerate(row) if ch == "#")
write(os.path.join(ROOT, "data-files", "reiatsuflow-symbolic.svg"), svg(16, small))
write(os.path.join(ROOT, "ui", "logo.svg"), svg(48, rects(FULL, 3, 0, 3)))
print("logo written")

