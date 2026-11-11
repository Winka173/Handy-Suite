"""Render Handy Habit's icon: Today's kept/due ring with today's bead.

From the repo root:
    python apps/handy_habit/tool/icon/render.py
    python tooling/app-icons.py habit

Writes tool/icon/art.png (the area launchers show) and
tool/icon/maskable.png (the whole adaptive canvas, the mark scaled into the
centred 66 percent safe circle); tooling/app-icons.py cuts every platform
size from them. Vermilion #B42318 field, cream ring, today's bead checked.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
VERMILION = (180, 35, 24)
TRACK = (208, 98, 82)
CREAM = (255, 245, 237)
SIZE = 1024
SUPER = 4  # drawn large, then scaled down for smooth edges


def check(d, cx, cy, r, color, w):
    pts = [
        (cx - r * 0.45, cy + r * 0.02),
        (cx - r * 0.12, cy + r * 0.34),
        (cx + r * 0.5, cy - r * 0.32),
    ]
    d.line(pts, fill=color, width=w, joint='curve')
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)


def mark(scale: float) -> Image.Image:
    s = SIZE * SUPER
    im = Image.new('RGB', (s, s), VERMILION)
    d = ImageDraw.Draw(im)
    c = s / 2
    ring = s * 0.30 * scale
    width = round(s * 0.068 * scale)
    box = (c - ring, c - ring, c + ring, c + ring)
    d.arc(box, 0, 360, fill=TRACK, width=width)       # what is still due
    d.arc(box, -90, 200, fill=CREAM, width=width)      # what is kept
    a = math.radians(200)
    x, y = c + ring * math.cos(a), c + ring * math.sin(a)
    bead = s * 0.076 * scale                           # today's bead
    d.ellipse((x - bead, y - bead, x + bead, y + bead), fill=CREAM)
    check(d, x, y, bead, VERMILION, round(s * 0.0235 * scale))
    return im.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == '__main__':
    mark(1.0).save(HERE / 'art.png')
    mark(0.85).save(HERE / 'maskable.png')
    print('art.png, maskable.png')
