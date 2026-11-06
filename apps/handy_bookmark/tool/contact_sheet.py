"""Joins review screenshots into one contact sheet.

python tool/contact_sheet.py <out.jpg> <height> <shot.png>...
Each shot is scaled to <height> px tall and labelled with its file name.
"""
import os
import sys

from PIL import Image, ImageDraw


def main() -> None:
    out, height, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    shots = []
    for f in files:
        im = Image.open(f).convert('RGB')
        w = int(im.width * height / im.height)
        shots.append((os.path.basename(f), im.resize((w, height), Image.LANCZOS)))
    gap, label = 12, 22
    width = sum(s.width for _, s in shots) + gap * (len(shots) + 1)
    sheet = Image.new('RGB', (width, height + label + gap * 2), 'white')
    draw = ImageDraw.Draw(sheet)
    x = gap
    for name, s in shots:
        draw.text((x, gap // 2), name, fill=(60, 60, 60))
        sheet.paste(s, (x, label + gap // 2))
        x += s.width + gap
    sheet.save(out, quality=88)


if __name__ == '__main__':
    main()
