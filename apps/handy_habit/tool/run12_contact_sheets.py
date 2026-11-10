"""Compose actual Flutter rasters; synthetic store states are explicitly labelled."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html
import json

root = Path(__file__).resolve().parents[1] / 'build/run12'
out = root / 'sheets'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)


def sheet(name, title, cells, columns=4, width=310, height=740):
    rows = (len(cells) + columns - 1) // columns
    canvas = Image.new('RGB', (columns * (width + 16) + 16, rows * (height + 60) + 70), '#e5e0d8')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), title, fill='#291c19', font=font)
    for i, (label, path) in enumerate(cells):
        if not path.exists():
            raise FileNotFoundError(path)
        x, y = 16 + (i % columns) * (width + 16), 48 + (i // columns) * (height + 60)
        draw.text((x, y), label, fill='#291c19', font=font)
        picture = Image.open(path).convert('RGB')
        picture.thumbnail((width, height))
        canvas.paste(picture, (x, y + 30))
    canvas.save(out / name)


def ref(app, stem, scene):
    return root / 'references' / f'{app}-{stem}-{scene}.png'


def habit(stem, scene):
    return root / 'final' / f'{stem}-{scene}.png'


for file, stem, scene, title in [
    ('01-help-index.png', '390-vi-light-100', 'help', 'Help: replay card, Topics, icon / title / summary / chevron'),
    ('02-today-top-bar.png', '390-en-light-100', 'today', 'Today: own app mark and labelled creation; sibling mechanics'),
]:
    sibling_scene = 'shell' if scene == 'today' else scene
    sheet(file, title, [(app, ref(app, stem, sibling_scene)) for app in ['bookmark', 'boards']] + [('Habit run12', habit(stem, scene))], columns=3)

for file, title, stem, scenes in [
    ('03-pro-loading-price.png', 'Pro: actual sibling pages / Habit synthetic price states', '390-en-light-100', ['loading', 'price']),
    ('04-pro-purchased-restore.png', 'Pro: synthetic purchased and restoring states (host only)', '390-vi-dark-100', ['owned', 'restore']),
    ('05-pro-error-offline.png', 'Pro: synthetic error / unavailable / cached offline ownership', '320-vi-dark-150', ['error', 'unavailable', 'offline-owned']),
    ('06-pro-unsupported.png', 'Pro: honest unsupported platform / cancelled purchase', '390-en-light-100', ['unsupported', 'canceled']),
]:
    cells = [(app, ref(app, stem, 'pro')) for app in ['bookmark', 'boards']]
    cells += [(f'Habit fake: {s}', habit(stem, f'pro-{s}')) for s in scenes]
    sheet(file, title, cells, columns=len(cells))

for width in [320, 390, 1440]:
    for locale in ['en', 'vi']:
        for theme in ['light', 'dark']:
            for scale in [100, 150]:
                stem = f'{width}-{locale}-{theme}-{scale}'
                cells = []
                for scene in ['today', 'help']:
                    cells += [(f'{app} {scene}', ref(app, stem, 'shell' if scene == 'today' else scene)) for app in ['bookmark', 'boards']]
                    cells.append((f'Habit {scene}', habit(stem, scene)))
                sheet(f'matrix-{stem}-consistency.png', f'{stem}: same locale/theme/width/text scale', cells, columns=3, width=460 if width == 1440 else 310, height=340 if width == 1440 else 740)
                scenes = ['overview', 'loading', 'price', 'pending', 'owned', 'restore', 'not-found', 'error', 'unavailable', 'offline-owned', 'canceled', 'unsupported']
                cells = [(app, ref(app, stem, 'pro')) for app in ['bookmark', 'boards']]
                cells += [(f'Habit fake: {s}', habit(stem, f'pro-{s}')) for s in scenes]
                sheet(f'matrix-{stem}-pro.png', f'{stem}: Pro states; Habit uses a TEST fake, never store evidence', cells, width=460 if width == 1440 else 310, height=340 if width == 1440 else 740)

inventory = {folder: sorted(p.name for p in (root / folder).glob('*.png')) for folder in ['round1', 'final', 'references', 'sheets']}
(root / 'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
links = ['<h1>Handy Habit run12</h1><p>Actual host raster output. Habit billing states use test fakes. No device or store verification.</p>']
for folder, files in inventory.items():
    links.append(f'<h2>{folder}</h2>')
    for name in files:
        safe = html.escape(f'{folder}/{name}')
        links.append(f'<a href="{safe}">{html.escape(name)}</a><br>')
(root / 'index.html').write_text('<!doctype html><meta charset="utf-8">' + '\n'.join(links), encoding='utf-8')
print({folder: len(files) for folder, files in inventory.items()})
