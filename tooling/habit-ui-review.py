"""Package actual Flutter render/emulator captures for review; no synthetic UI."""
import hashlib
import html
import json
from pathlib import Path
import pymupdf

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
captures = [('Widget renderer (not OS runtime)', p) for p in sorted((evidence / 'habit-ui').glob('*.png'))]
captures += [('Android API35 emulator (not physical device)', p) for p in sorted((evidence / 'screenshots').glob('habit-native-*.png'))]
if not captures:
    raise SystemExit('No Handy Habit screenshot evidence exists')
doc = pymupdf.open()
intro = doc.new_page(width=595, height=842)
intro.insert_textbox(pymupdf.Rect(36, 42, 559, 780),
    'HANDY HABIT - UI REVIEW\n\n'
    'Real Flutter-rendered screens with bundled fonts.\n'
    'Widget captures use explicit QA fixtures and fixed dates.\n'
    'Native captures come from HandyHabit_QA_API35.\n'
    'Neither source is physical-device, iOS or browser certification.\n\n'
    'Review: legibility, hierarchy, tap areas, long Vietnamese text,\n'
    'empty/dark states, Lite decisions and runner progress.\n'
    'See docs/handy_habit/QA_PLAN.md for test/build limitations.\n\n'
    f'{len(captures)} captures follow. Captions identify provenance.', fontsize=13)
rows = []
for origin, path in captures:
    data = path.read_bytes()
    pix = pymupdf.Pixmap(data)
    wide = pix.width > pix.height
    width, height = (842, 595) if wide else (595, 1000)
    page = doc.new_page(width=width, height=height)
    page.insert_text((18, 24), path.name, fontsize=11)
    page.insert_text((18, 40), origin, fontsize=9)
    page.insert_image(pymupdf.Rect(12, 52, width - 12, height - 12), stream=data, keep_proportion=True)
    rows.append({'path': path.relative_to(root).as_posix(), 'origin': origin,
                 'width': pix.width, 'height': pix.height, 'sha256': hashlib.sha256(data).hexdigest()})
pdf = evidence / 'habit-ui-review.pdf'
doc.save(pdf, garbage=4, deflate=True)
out = evidence / 'habit-ui-review.html'
out.write_text('<!doctype html><meta charset="utf-8"><title>Handy Habit UI review</title>'
    '<style>body{font:16px system-ui;max-width:1100px;margin:32px auto;padding:16px}'
    'img{display:block;max-width:100%;max-height:85vh;border:1px solid #ddd}section{margin:32px 0}</style>'
    '<h1>Handy Habit UI review</h1><p>Widget renders and Android emulator captures; no physical-device claim.</p>'
    '<p><a href="habit-ui-review.pdf">Open complete PDF</a></p>' + ''.join(
        f'<section><h2>{html.escape(Path(row["path"]).name)}</h2><p>{html.escape(row["origin"])}</p>'
        f'<a href="{html.escape(Path(row["path"]).relative_to("docs/qa/evidence").as_posix())}">'
        f'<img loading="lazy" alt="{html.escape(Path(row["path"]).stem)}" '
        f'src="{html.escape(Path(row["path"]).relative_to("docs/qa/evidence").as_posix())}"></a></section>'
        for row in rows), encoding='utf-8')
(evidence / 'habit-ui-review-result.json').write_text(json.dumps({
    'captures': rows, 'pdfPages': len(doc), 'pdfSha256': hashlib.sha256(pdf.read_bytes()).hexdigest(),
    'physicalDevice': False, 'browserRuntime': False}, indent=2) + '\n', encoding='utf-8')
print(f'{len(rows)} actual captures, {len(doc)} PDF pages')
