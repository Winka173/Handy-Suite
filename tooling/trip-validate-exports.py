"""Independent readers for actual Trip exports; no app serializers."""
import hashlib
import io
import json
from pathlib import Path
import zipfile
import pymupdf as fitz
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/qa/evidence/exports'
results = []
for path in sorted(OUT.glob('trip-*')):
    item = {'file': path.name, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.suffix == '.pdf':
        doc = fitz.open(path)
        text = '\n'.join(page.get_text() for page in doc)
        decoded = b'\n'.join(doc.xref_stream(i) or b'' for i in range(1, doc.xref_length())
                             if doc.xref_is_stream(i))
        for secret in ['PRIVATE-ABC', 'Private photo caption']:
            assert secret not in text, (path, secret)
            assert secret.encode() not in decoded, (path, secret)
        assert doc.embfile_count() == 0, path
        image_count = 0
        for page in doc:
            for ref in page.get_images():
                image = Image.open(io.BytesIO(doc.extract_image(ref[0])['image']))
                assert not image.getexif(), path
                image_count += 1
        item.update(pages=len(doc), imageOccurrences=image_count,
                    bookingCodeAbsent=True, privateCaptionAbsent=True, embeddedFiles=0)
        doc[0].get_pixmap(matrix=fitz.Matrix(1.2, 1.2)).save(
            OUT / (path.stem + '-page1.png'))
        doc.close()
    elif path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None
            names = archive.namelist()
            for name in names:
                assert not name.startswith(('/', '\\')) and '..' not in Path(name).parts
                raw = archive.read(name)
                assert b'PRIVATE-ABC' not in raw
                assert b'Private photo caption' not in raw
                if name.lower().endswith(('.jpg', '.jpeg', '.png')):
                    image = Image.open(io.BytesIO(raw))
                    image.load()
                    assert not image.getexif(), name
            item.update(entries=names, crcValid=True, privateFieldsAbsent=True)
    elif path.suffix == '.png' and '-page1' not in path.stem:
        image = Image.open(path)
        image.load()
        item.update(width=image.width, height=image.height)
    else:
        continue
    results.append(item)
target = ROOT / 'docs/qa/evidence/trip-pdf-validation.json'
target.write_text(json.dumps({'reader': 'PyMuPDF + Pillow + Python zipfile',
                            'outputs': results}, indent=2), encoding='utf-8')
print(f'Validated {len(results)} actual exports; {target.relative_to(ROOT)}')
