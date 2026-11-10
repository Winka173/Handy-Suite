"""Host rasters, real PDF decoding and contact sheets for Habit's run14.
Run from any folder: python apps/handy_habit/tool/run14_contact_sheets.py
No device or store verification is implied by these artifacts.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html
import json
import re
import pymupdf

root = Path(__file__).resolve().parents[1] / 'build/run14'
out = root / 'sheets'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)


def sheet(name, title, cells, columns=3, width=330, height=880):
    rows = (len(cells) + columns - 1) // columns
    canvas = Image.new('RGB', (columns * (width + 16) + 16, rows * (height + 60) + 58), '#e5e0d8')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), title, fill='#291c19', font=font)
    for i, (label, path) in enumerate(cells):
        x, y = 16 + i % columns * (width + 16), 48 + i // columns * (height + 60)
        draw.text((x, y), label, fill='#291c19', font=font)
        image = Image.open(path).convert('RGB')
        image.thumbnail((width, height))
        canvas.paste(image, (x, y + 28))
    canvas.save(out / name)


def shot(scene, stem='390-en-light-100'):
    return root / 'final' / f'{stem}-{scene}.png'


pdf_checks = []
for file in sorted(root.glob('report-*.pdf')):
    doc = pymupdf.open(file)
    text = '\n'.join(page.get_text() for page in doc)
    assert not re.search(r'\d{4}-\d{2}-\d{2}', text), file
    assert 'Asia/Ho_Chi_Minh' not in text and 'Asia/Saigon' not in text, file
    # A finding heading must have a supporting figure on its page.
    for page in doc:
        content = page.get_text()
        if 'Mood alongside your habits.' in content:
            assert 'Read:' in content
        if 'Tâm trạng cùng thói quen.' in content:
            assert 'Đọc sách:' in content
    doc[0].get_pixmap(matrix=pymupdf.Matrix(1.35, 1.35)).save(str(file.with_suffix('.png')))
    pdf_checks.append({'file': file.name, 'pages': len(doc), 'dates': 'localized', 'raw_zone': False})

small = '320-vi-dark-150'
old = root.parent / 'run13/final/390-en-light-100-insights-month.png'
sheet('01-insights.png', 'Insights: run13 before / run14 findings and supporting figures', [
    ('Run13 before', old), ('Run14 overview', shot('insights-top')), ('Groups', shot('insights-groups')),
    ('Weekdays', shot('insights-weekdays')), ('Mood', shot('insights-mood')), ('320 VI dark text150', shot('insights-top', small))])
sheet('02-filters-heatmap.png', 'Compact filters / one aligned calendar per habit / 48px tap targets', [
    ('Time filter', shot('filter-sheet')), ('Weekday filter', shot('weekday-sheet')), ('Focused calendars', shot('insights-heatmap')),
    ('320 VI filter', shot('filter-sheet', small)), ('320 VI weekdays', shot('weekday-sheet', small)), ('320 VI heatmap', shot('insights-heatmap', small))])
sheet('03-pdf.png', 'Actual exported A4 first pages + responsive report preview (same evidence)', [
    ('English PDF', root / 'report-390-en-light-100.png'), ('Vietnamese PDF', root / 'report-390-vi-light-100.png'),
    ('Report preview', shot('report-preview')), ('320 VI report preview', shot('report-preview', small))], columns=2, width=420, height=900)
sheet('04-notifications.png', 'Notifications: real controls / individual rules / enlarged text', [
    ('390 EN light', shot('notifications')), ('Individual rules', shot('notifications-rules')), ('320 VI dark text150', shot('notifications', small)),
    ('320 VI rules', shot('notifications-rules', small)), ('390 EN dark', shot('notifications', '390-en-dark-100')), ('390 VI light', shot('notifications', '390-vi-light-100'))])
sheet('05-diagnostics.png', 'Diagnostics: synthetic OS responses; real delivery still needs supervisor checks', [
    ('Allowed', shot('diagnostics')), ('Test and system links', shot('diagnostics-test')), ('320 VI full wrapping', shot('diagnostics', small)),
    ('320 VI actions', shot('diagnostics-test', small)), ('Denied', root / 'final/extra-denied-diagnostics.png'), ('Unsupported', root / 'final/extra-unsupported-diagnostics.png')])
sheet('06-widgets.png', 'Widget payload previews / compact-large / Pro studio palettes (native not device-tested)', [
    ('Compact', shot('widgets-compact')), ('Large', shot('widgets-large')), ('Habit and routine', shot('widgets-habit')),
    ('320 VI dark', shot('widgets-compact', small)), ('Grove dark', root / 'final/extra-grove-dark-widgets.png'), ('Ochre light', root / 'final/extra-ochre-light-widgets.png')])

scenes = ['insights-top', 'insights-groups', 'insights-collections', 'insights-weekdays', 'insights-mood', 'insights-heatmap',
          'filter-sheet', 'weekday-sheet', 'report-preview', 'notifications', 'notifications-rules', 'diagnostics', 'diagnostics-test',
          'widgets-compact', 'widgets-large', 'widgets-habit', 'widgets-routine']
for width in [320, 390, 1440]:
    for language in ['en', 'vi']:
        for theme in ['light', 'dark']:
            for scale in [100, 150]:
                stem = f'{width}-{language}-{theme}-{scale}'
                sheet(f'matrix-{stem}.png', f'{stem}: Flutter host rasters / real PDF first page',
                      [(scene, shot(scene, stem)) for scene in scenes] + [('Actual PDF page1', root / f'report-{stem}.png')],
                      columns=4, width=520 if width == 1440 else 310, height=420 if width == 1440 else 820)
inventory = {folder: sorted(p.name for p in (root / folder).glob('*.png')) for folder in ['round1', 'final', 'sheets']}
(root / 'inventory.json').write_text(json.dumps({'rasters': inventory, 'pdf_checks': pdf_checks}, indent=2), encoding='utf-8')
links = ['<h1>Handy Habit run14</h1><p>Real Flutter host renders and decoded PDFs. Synthetic history, Pro and OS responses. No devices used.</p>']
for folder, files in inventory.items():
    links.append(f'<h2>{folder}</h2>')
    for name in files:
        links.append(f'<a href="{html.escape(folder + "/" + name)}">{html.escape(name)}</a><br>')
(root / 'index.html').write_text('<!doctype html><meta charset="utf-8">' + '\n'.join(links), encoding='utf-8')
print({folder: len(files) for folder, files in inventory.items()}, 'PDFs verified:', len(pdf_checks))
