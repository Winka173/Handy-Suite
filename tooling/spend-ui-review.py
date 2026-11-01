"""Collect actual Android captures into a standalone PDF; never synthesize screens."""
import json
import hashlib
from pathlib import Path
import pymupdf as fitz

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
record = json.loads((evidence / 'spend-android-screenshots-result.json').read_text(encoding='utf-8-sig'))
if record['exitCode'] != 0 or not record['sourceUnchanged']:
    raise SystemExit('A successful unchanged-source capture run is required')
screens = [
    ('home', 'Home'), ('transactions', 'Transactions'), ('reports', 'Reports'),
    ('plan', 'Plan'), ('sandbox', 'Financial Sandbox'),
    ('add-transaction', 'Add transaction'), ('import-map', 'Statement mapping'),
    ('import-review', 'Statement review'), ('import-result', 'Reconciliation / Undo'),
    ('accounts', 'Accounts'), ('settings', 'Settings'),
]
document = fitz.open()
for index, (name, title) in enumerate(screens, 1):
    path = evidence / 'screenshots' / f'spend-{name}.png'
    if not path.is_file():
        raise SystemExit(f'Missing screenshot: {path.name}')
    page = document.new_page(width=420, height=900)
    page.insert_text((16, 22), f'Handy Spend - {title}', fontsize=15)
    page.insert_text((16, 38), f'Android emulator / QA data / {index} of {len(screens)}', fontsize=9)
    page.insert_text((16, 51), f"Source: {record['sourceSha256'][:16]} / {record['finishedAt']}", fontsize=8)
    page.insert_image(fitz.Rect(10, 62, 410, 890), filename=str(path))
output = evidence / 'spend-ui-review.pdf'
document.save(output, garbage=4, deflate=True)
document.close()
(evidence / 'spend-ui-review-result.json').write_text(json.dumps({
    'sourceSha256': record['sourceSha256'],
    'artifact': output.relative_to(root).as_posix(),
    'pages': len(screens),
    'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'actualAndroidEmulatorScreenshots': True,
    'physicalDevice': False,
}, indent=2) + '\n', encoding='utf-8')
print(f'PASS: {len(screens)} actual captured screens -> {output.relative_to(root)}')
