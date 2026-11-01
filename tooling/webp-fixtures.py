"""Freeze independent Pillow/libwebp image fixtures; no Dart encoder involved."""
from pathlib import Path
import hashlib
import json
from PIL import Image, features

root = Path(__file__).resolve().parent.parent
folder = root / 'test-fixtures/webp'
folder.mkdir(parents=True, exist_ok=True)
image = Image.new('RGBA', (24, 16))
for y in range(16):
    for x in range(24):
        image.putpixel((x, y), (x * 10, y * 16, (x+y)*6, (x * 11) if x < 12 else 255))
image.save(folder / 'source.png')
for name, params in [('lossless', {'lossless': True}), ('lossy', {'lossless': False, 'quality': 80})]:
    path = folder / f'{name}.webp'
    image.save(path, format='WEBP', **params)
    decoded = Image.open(path).convert('RGBA')
    (folder / f'{name}.rgba').write_bytes(decoded.tobytes())
image.save(folder / 'animated.webp', format='WEBP', save_all=True,
           append_images=[Image.new('RGBA', (24,16), (255,0,0,255))], duration=100, loop=0)
manifest = {'generator': 'Pillow/libwebp independent of Dart', 'webpVersion': features.version('webp'),
            'width': 24, 'height': 16, 'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                               for p in folder.iterdir() if p.name != 'MANIFEST.json'}}
(folder / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
print('Frozen independent static lossless/lossy/alpha and animation-rejection fixtures')
