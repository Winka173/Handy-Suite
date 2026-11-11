"""Render Handy Habit's icon: Today's kept/due ring with today's bead.

From the repo root:
    python apps/handy_habit/tool/icon/render.py
    python tooling/app-icons.py habit

Writes tool/icon/art.png (the area launchers show) and
tool/icon/maskable.png (the whole adaptive canvas, the mark kept inside the
centred 66 percent safe circle); tooling/app-icons.py cuts every platform
size from them. Vermilion #B42318 field, cream ring, today's bead checked.

Today's bead sits in the middle of the ring, so the mark is symmetric and
reads at small sizes; it is sized to fill the visible area: [ART_EXTENT]
and [MASK_EXTENT] are its half-width as a share of the canvas.
"""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
VERMILION = (180, 35, 24)
TRACK = (208, 98, 82)
CREAM = (255, 245, 237)
SIZE = 1024
SUPER = 4  # drawn large, then scaled down for smooth edges

# The mark in its own units: ring radius 1.
STROKE = 0.26          # ring width
BEAD = 0.52            # today's bead radius, in the middle
END = 180              # degrees: the kept arc runs from the top to here
ART_EXTENT = 0.38      # launcher area: the ring spans 76% of the icon
MASK_EXTENT = 0.30     # adaptive canvas: inside the 33% safe radius


def check(d, cx, cy, r, color, w):
    pts = [
        (cx - r * 0.45, cy + r * 0.02),
        (cx - r * 0.12, cy + r * 0.34),
        (cx + r * 0.5, cy - r * 0.32),
    ]
    d.line(pts, fill=color, width=w, joint='curve')
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)


def outline():
    """The mark's bounding box in ring units, centre (0, 0)."""
    outer = 1 + STROKE / 2
    return -outer, outer, -outer, outer


def mark(extent: float) -> Image.Image:
    s = SIZE * SUPER
    im = Image.new('RGB', (s, s), VERMILION)
    d = ImageDraw.Draw(im)
    x0, x1, y0, y1 = outline()
    half = max(x1 - x0, y1 - y0) / 2
    unit = s * extent / half                      # px per ring unit
    # Centre the whole outline, not the ring.
    cx = s / 2 - (x0 + x1) / 2 * unit
    cy = s / 2 - (y0 + y1) / 2 * unit
    ring = unit
    width = round(STROKE * unit)
    box = (cx - ring, cy - ring, cx + ring, cy + ring)
    d.arc(box, 0, 360, fill=TRACK, width=width)          # what is still due
    d.arc(box, -90, END, fill=CREAM, width=width)        # what is kept
    x, y = cx, cy
    bead = BEAD * unit                                    # today's bead
    d.ellipse((x - bead, y - bead, x + bead, y + bead), fill=CREAM)
    check(d, x, y, bead, VERMILION, round(bead * 0.30))
    return im.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == '__main__':
    mark(ART_EXTENT).save(HERE / 'art.png')
    mark(MASK_EXTENT).save(HERE / 'maskable.png')
    print('art.png, maskable.png')
