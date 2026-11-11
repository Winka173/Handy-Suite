"""Contact sheets from real host Flutter renders; never device evidence."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html

root = Path(__file__).resolve().parents[1] / 'build/run15'
out = root / 'sheets'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)


def sheet(name, cases, columns=3, width=360, height=860):
    rows = (len(cases) + columns - 1) // columns
    canvas = Image.new('RGB', (columns * (width + 16) + 16, rows * (height + 50) + 16), '#e6dfd6')
    draw = ImageDraw.Draw(canvas)
    for i, (label, filename) in enumerate(cases):
        x, y = 16 + i % columns * (width + 16), 16 + i // columns * (height + 50)
        draw.text((x, y), label, fill='#54261f', font=font)
        image = Image.open(root / 'final' / filename).convert('RGB')
        image.thumbnail((width, height))
        canvas.paste(image, (x, y + 28))
    canvas.save(out / name)


for name, scenes in [
    ('01-saved-views.png', ['saved-habits', 'saved-progress', 'save-filter']),
    ('02-batch.png', ['batch-select', 'batch-options', 'batch-preview']),
    ('03-rules.png', ['rules', 'rules-history', 'rule-form']),
]:
    cases = [(f'{stem} {scene}', f'{stem}-{scene}.png')
             for stem in ['390-en-light-100', '320-vi-dark-150'] for scene in scenes]
    sheet(name, cases)

sheet('04-wide.png', [(scene, f'1440-en-light-100-{scene}.png')
                       for scene in ['saved-habits', 'saved-progress', 'batch-preview', 'rules']], columns=2, width=720, height=450)
links = ''.join(f'<li><a href="sheets/{p.name}">{html.escape(p.name)}</a></li>' for p in sorted(out.glob('*.png')))
shots = ''.join(f'<li><a href="final/{p.name}">{html.escape(p.name)}</a></li>' for p in sorted((root / 'final').glob('*.png')))
(root / 'index.html').write_text(f'<!doctype html><meta charset="utf-8"><title>Habit run15 host review</title><h1>Habit run15 · host renders</h1><p>EN/VI, light/dark, 320/390/1440, text1/1.5. Synthetic local history and verified-store fixtures; no device/store verification.</p><ul>{links}</ul><h2>Full renders</h2><ul>{shots}</ul>', encoding='utf-8')
print(f'{len(list((root / "final").glob("*.png")))} full renders; {out}')
