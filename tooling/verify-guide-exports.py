"""Independently reopen actual Android editor exports with pypdf/Pillow/zipfile."""
from pathlib import Path
import base64
import hashlib
import io
import json
import re
import zipfile
from PIL import Image
from pypdf import PdfReader

root = Path(__file__).resolve().parent.parent
folder = root / 'docs/qa/evidence/guide-native'
names = ['handy-media-guide.html', 'handy-media-guide.pdf', 'handy-media-guide.md',
         'handy-media-guide.zip', 'handy-media-long.png', 'handy-media-change-map.png']
artifacts = {}
for name in names:
    data = (folder / name).read_bytes()
    artifacts[name] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
with zipfile.ZipFile(folder / names[3]) as archive:
    assert sorted(archive.namelist()) == ['README.txt', 'guide.html', 'guide.md',
                                          'report.txt', 'steps/001.png', 'steps/002.png']
    assert archive.testzip() is None
    pngs = [archive.read(f'steps/{i:03}.png') for i in (1, 2)]
    html = archive.read('guide.html').decode('utf-8')
    assert html == (folder / names[0]).read_text(encoding='utf-8')
    assert archive.read('guide.md') == (folder / names[2]).read_bytes()
    assert 'file:///owned' not in html and 'annotations' not in html
    assert "default-src 'none'" in html
    assert [base64.b64decode(s) for s in re.findall(r'data:image/png;base64,([^"]+)', html)] == pngs
pixels = [Image.open(io.BytesIO(png)).convert('RGBA') for png in pngs]
assert all(image.size == (100, 100) for image in pixels)
assert pixels[0].getpixel((40, 40)) == (0, 0, 0, 255)
assert pixels[1].getpixel((40, 40)) == (255, 255, 255, 255)
reader = PdfReader(folder / names[1])
assert 1 <= len(reader.pages) <= 100 and not reader.is_encrypted
text = '\n'.join(page.extract_text() for page in reader.pages)
assert '1. Step' in text and '2. Step' in text and 'file:///owned' not in text
assert not any(page.get('/Annots') for page in reader.pages)
embedded = [image.image.convert('RGBA') for page in reader.pages for image in page.images]
assert len(embedded) == 2
assert [image.tobytes() for image in embedded] == [image.tobytes() for image in pixels]
long = Image.open(folder / names[4]).convert('RGBA')
assert long.size == (1000, 2000)
assert long.getpixel((400, 400)) == (0, 0, 0, 255)
assert long.getpixel((400, 1400)) == (255, 255, 255, 255)
change = Image.open(folder / names[5]).convert('RGBA')
assert change.size == (100, 100)
assert change.getpixel((40, 40)) == (239, 68, 68, 255)
assert change.getpixel((0, 0)) == (226, 232, 240, 255)
report = {'passed': True, 'source': 'actual Android editor exports',
          'pdfPages': len(reader.pages), 'pdfFlattenedImagePixelsMatchExactly': True,
          'zipEntries': 6, 'longImageSize': list(long.size),
          'artifacts': artifacts, 'physicalDeviceVerified': False}
(folder / 'independent-guide-verification.json').write_text(
    json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
