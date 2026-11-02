"""Read actual Boards exports with independent PDF/XLSX libraries."""
from pathlib import Path
import hashlib
import json
import warnings
import pymupdf as fitz
import openpyxl

root = Path(__file__).resolve().parents[1]
outputs = root / 'docs/qa/evidence/exports'
expected = 'B\u00e0i t\u1eadp to\u00e1n'
results = []
for path in sorted(outputs.glob('boards-*.pdf')):
    doc = fitz.open(path)
    text = '\n'.join(page.get_text() for page in doc)
    assert expected in text, (path.name, ascii(text))
    assert doc.embfile_count() == 0
    doc[0].get_pixmap(matrix=fitz.Matrix(1.3, 1.3)).save(
        outputs / (path.stem + '-page1.png'))
    results.append({'file': path.name, 'pages': len(doc),
                    'unicodeTextVerified': True,
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    doc.close()
path = outputs / 'boards-tasks.xlsx'
with warnings.catch_warnings():
    warnings.simplefilter('ignore')
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=False)
    sheet = workbook['Tasks']
    rows = list(sheet.values)
    assert rows[0][0] == 'Task' and rows[1][0] == expected
    assert sheet['A2'].data_type != 'f'
    workbook.close()
results.append({'file': path.name, 'independentReader': 'openpyxl',
                'rows': len(rows), 'textNotFormula': True})
(root / 'docs/qa/evidence/boards-independent-exports.json').write_text(
    json.dumps(results, indent=2), encoding='utf-8')
print(f'Validated {len(results)} actual PDF/XLSX exports')
