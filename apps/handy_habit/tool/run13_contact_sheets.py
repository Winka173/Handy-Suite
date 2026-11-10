"""Contact sheets from real host rasters and saved run12 sibling references."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html
import json

root = Path(__file__).resolve().parents[1] / 'build/run13'
references = root.parent / 'run12/references'
out = root / 'sheets'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)


def habit(stem, scene, folder='final'):
    return root / folder / f'{stem}-{scene}.png'


def refs(stem):
    return [(app, references / f'{app}-{stem}-pro.png') for app in ['bookmark', 'boards']]


def sheet(name, title, cells, columns=4, width=310, height=790):
    rows = (len(cells) + columns - 1) // columns
    canvas = Image.new('RGB', (columns * (width + 16) + 16, rows * (height + 62) + 62), '#e5e0d8')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), title, fill='#291c19', font=font)
    for i, (label, path) in enumerate(cells):
        if not path.exists():
            raise FileNotFoundError(path)
        x, y = 16 + (i % columns) * (width + 16), 48 + (i // columns) * (height + 62)
        draw.text((x, y), label, fill='#291c19', font=font)
        picture = Image.open(path).convert('RGB')
        picture.thumbnail((width, height))
        canvas.paste(picture, (x, y + 28))
    canvas.save(out / name)


stem = '390-en-light-100'
sheet('01-pro-structure.png', 'Pro: same structure, each app keeps its own identity (host only)',
      refs(stem) + [('Habit first pass', habit(stem, 'pro-ready', 'round1')), ('Habit final', habit(stem, 'pro-ready'))])
sheet('02-pro-store-states.png', 'Synthetic store states; these are not verified purchases', refs(stem) + [
    (state, habit(stem, f'pro-{state}')) for state in ['ready', 'loading', 'pending', 'owned', 'restore', 'not-found', 'error', 'unavailable', 'offline-owned', 'unsupported', 'canceled']])
sheet('03-pro-live-demos.png', 'Selected top panels and replay: local demo history / studio',
      [(scene, habit(stem, f'pro-demo-{scene}')) for scene in ['comparisons', 'mood', 'studio']]
      + [('320 VI dark text150', habit('320-vi-dark-150', 'pro-ready'))])
sheet('04-smart-insights.png', 'Insights: demo vs local data, counts / groups / patterns / mood / PDF',
      [(scene, habit(stem, f'insights-{scene}')) for scene in ['free', 'month', 'quarter', 'groups', 'collections', 'patterns', 'mood', 'filters']]
      + [('Report preview', habit(stem, 'report'))])
sheet('05-personalization.png', 'Studio: preview / picker / palette / icons; Apply requires current Pro',
      [(scene, habit(stem, f'studio-{scene}')) for scene in ['top', 'picker', 'ochre', 'icons']])
sheet('06-accessibility-and-pdf.png', '320 VI dark text150 / real exported A4 PDFs', [
    ('Insights enlarged', habit('320-vi-dark-150', 'insights-month')),
    ('Studio free preview', habit('320-vi-dark-150', 'studio-free')),
    ('English PDF page 1', root / 'report-en.png'),
    ('Vietnamese PDF page 1', root / 'report-vi.png')])

for width in [320, 390, 1440]:
    for locale in ['en', 'vi']:
        for theme in ['light', 'dark']:
            for scale in [100, 150]:
                stem = f'{width}-{locale}-{theme}-{scale}'
                scenes = ['pro-ready', 'pro-loading', 'pro-pending', 'pro-owned', 'pro-error', 'pro-restore', 'pro-unsupported',
                          'insights-free', 'insights-month', 'insights-groups', 'insights-mood', 'insights-filters',
                          'studio-top', 'studio-picker', 'studio-ochre', 'studio-icons', 'studio-free']
                sheet(f'matrix-{stem}.png', f'{stem}: actual host rasters; billing is a test fake', refs(stem) + [(scene, habit(stem, scene)) for scene in scenes],
                      width=460 if width == 1440 else 310, height=380 if width == 1440 else 790)

inventory = {folder: sorted(p.name for p in (root / folder).glob('*.png')) for folder in ['round1', 'final', 'sheets']}
(root / 'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
links = ['<h1>Handy Habit run13</h1><p>Real Flutter host rasters and exported PDF pages. Synthetic billing; no device or real store verification.</p>',
         '<p>Final insight fixture adds an evening walking habit to demonstrate group comparisons. All counts come from the engine.</p>']
for folder, names in inventory.items():
    links.append(f'<h2>{folder}</h2>')
    for name in names:
        path = html.escape(f'{folder}/{name}')
        links.append(f'<a href="{path}">{html.escape(name)}</a><br>')
(root / 'index.html').write_text('<!doctype html><meta charset="utf-8">' + '\n'.join(links), encoding='utf-8')
print({folder: len(names) for folder, names in inventory.items()})
