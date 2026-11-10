"""Contact sheets from actual Flutter host PNGs; no synthetic UI evidence."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html
import json
import re
import sys

root = Path(__file__).resolve().parents[1] / 'build/run11'
out = root / 'sheets'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)

def sheet(name, title, cells, columns=4, width=310, height=770):
    target = out / name
    inputs = [path for _, path in cells if path is not None and path.exists()]
    if ('--force' not in sys.argv and target.exists() and inputs and
        target.stat().st_mtime >= max(path.stat().st_mtime for path in inputs)):
        return
    rows = (len(cells) + columns - 1) // columns
    image = Image.new('RGB', (columns * (width+16)+16, rows*(height+60)+60), '#e5e0d8')
    draw = ImageDraw.Draw(image)
    draw.text((16, 12), title, fill='#251d19', font=font)
    for i, (label, path) in enumerate(cells):
        x, y = 16 + (i % columns)*(width+16), 48 + (i // columns)*(height+60)
        draw.text((x, y), label[:66], fill='#251d19', font=font)
        if path is not None and path.exists():
            im = Image.open(path).convert('RGB')
            im.thumbnail((width, height))
            image.paste(im, (x, y+30))
        else:
            draw.text((x, y+40), 'No matching baseline capture', fill='#7d2018', font=font)
    image.save(target)

top = [
 ('01-shell', 'Add before Settings; row menus; responsive gutters', '390-en-light', 'r3b-390-en-light-x1.0-today', 'shell'),
 ('02-help-index', 'Numbered topics with actual screen-fragment thumbnails', '390-vi-light', '390-vi-light-100-help', 'help'),
 ('03-help-detail', 'Illustrated steps; Previous/Next; local Back', '1440-en-dark', '1440-en-dark-100-help-check-in', 'help'),
 ('04-mood', 'Five labelled faces, expressive without colour', '390-en-light', '390-en-light-100-log', 'help'),
 ('05-sync', 'Explicit Back on Sync, including standalone route', '390-vi-dark', '390-vi-dark-100-off-top', 'settings'),
 ('06-settings', 'Values below labels, singular counts and data controls', '1440-en-light', '1440-en-light-100-settings-data', 'settings'),
]
for name, title, stem, file, reference in top:
    wide = stem.startswith('1440')
    ref_paths = [root/'references'/f'{app}-{stem}-{reference}.png' for app in ['bookmark','boards']]
    if name == '03-help-detail':
        ref_paths = [root/'references'/f'{app}-{stem}-help-detail.png' for app in ['bookmark','boards']]
    elif name == '04-mood':
        ref_paths = [root/'siblings/bookmark/lib-phone-cover-chooser.png',
          root/'siblings/boards/08-cover-picker.png']
    elif name == '06-settings':
        ref_paths = [root/'references'/f'{app}-{stem}-settings-data.png' for app in ['bookmark','boards']]
    sheet(name+'.png', title, [
      ('Bookmark reference', ref_paths[0]),
      ('Boards reference', ref_paths[1]),
      ('Habit BEFORE', root/'before'/(file+'.png')),
      ('Habit AFTER', root/'after'/(file+'.png')),
    ], width=510 if wide else 310, height=400 if wide else 700)

if '--top-only' in sys.argv:
    sys.exit(0)

# The full baseline/after inventory is reviewable by filename, with every matrix
# variant retained. Summary pages cover normal text; enlarged text has its own pages.
before = {p.name: p for p in (root/'before').glob('*.png') if 'film' not in p.name}
after = {p.name: p for p in (root/'after').glob('*.png') if 'film' not in p.name}
manifest = {'before_count': len(before), 'after_count': len(after),
  'matched': sorted(before.keys() & after.keys()),
  'missing_after': sorted(before.keys() - after.keys()),
  'new_after': sorted(after.keys() - before.keys())}
(root/'inventory.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')

for width in ['390', '1440']:
 for locale in ['en', 'vi']:
  for theme in ['light', 'dark']:
   stem = f'{width}-{locale}-{theme}'
   # Triple comparisons for each Habit surface: sibling shells, Settings or Help
   # are structural references, not domain-feature equivalents.
   names = sorted(n for n in after if (
     n.startswith(stem+'-100-') or n.startswith('r3b-'+stem+'-x1.0-') or n.startswith('r4-'+stem+'-100-')))
   for batch in range(0, len(names), 6):
    cells=[]
    for n in names[batch:batch+6]:
     ref = 'help' if '-help' in n else 'settings' if any(k in n for k in ['settings','-sync','-off-','-error-','-pending-','-trash']) else 'shell'
     if '-help-' in n and not any(k in n for k in ['search','no-match']):
       ref = 'help-detail'
     if 'settings-data' in n:
       ref = 'settings-data'
     cells.extend([
       ('Bookmark · '+ref, root/'references'/f'bookmark-{stem}-{ref}.png'),
       ('Boards · '+ref, root/'references'/f'boards-{stem}-{ref}.png'),
       ('Habit · '+n.removesuffix('.png'), after[n]),
     ])
    sheet(f'matrix-{stem}-{batch//6+1:02}.jpg', stem+' · matching mechanics / Habit domain screens', cells,
      columns=3, width=360 if width=='1440' else 234, height=430 if width=='1440' else 560)

# Compact before/after overviews include every matched non-film PNG, including
# large text and less frequent states. Originals remain clickable in the index.
names=manifest['matched']
for batch in range(0, len(names), 12):
 cells=[]
 for n in names[batch:batch+12]:
  cells.extend([('Before '+n, before[n]), ('After '+n, after[n])])
 sheet(f'coverage-{batch//12+1:03}.jpg', 'Before / after · source captures linked in index', cells,
   columns=6, width=210, height=420)

links = ''.join(f'<li><a href="sheets/{p.name}">{html.escape(p.name)}</a></li>' for p in sorted(out.iterdir()) if p.suffix in ['.png','.jpg'])
rows = ''.join(f'<tr><td>{html.escape(n)}</td><td><a href="before/{n}">Before</a></td><td><a href="after/{n}">After</a></td></tr>' for n in names)
(root/'index.html').write_text(f'<!doctype html><meta charset="utf-8"><title>Habit run 11</title><h1>Host-rendered UI audit</h1><p>Sibling fixtures are references for matching mechanics; Habit-specific screens have no domain equivalent.</p><ul>{links}</ul><table>{rows}</table>',encoding='utf-8')
print(json.dumps({k: len(v) if isinstance(v,list) else v for k,v in manifest.items()}))
