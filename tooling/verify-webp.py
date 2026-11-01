"""Decode actual Dart WebP outputs with independent Pillow/libwebp."""
from pathlib import Path
import hashlib
import json
from PIL import Image, features

root = Path(__file__).resolve().parent.parent
folder = root / 'docs/qa/evidence/webp'
source = Image.open(root / 'test-fixtures/webp/source.png').convert('RGBA')
results = {}
for quality in [20,85,100]:
    path = folder / f'quality-{quality}.webp'
    data = path.read_bytes()
    output = Image.open(path).convert('RGBA')
    assert output.size == source.size == (24,16)
    weighted_error, weight = 0, 0
    for actual, expected in zip(output.getdata(), source.getdata()):
        assert actual[3] == expected[3], 'Alpha must remain exact'
        weighted_error += sum(abs(actual[c]-expected[c]) for c in range(3)) * expected[3]
        weight += 3 * expected[3]
    error = weighted_error / weight
    assert error < {20:50,85:20,100:15}[quality], (quality,error)
    # Export is flattened image data only, without source metadata or animation.
    types, at = [], 12
    while at < len(data):
        kind = data[at:at+4].decode('ascii')
        length = int.from_bytes(data[at+4:at+8], 'little')
        assert kind in {'VP8X','VP8 ','VP8L','ALPH'}
        types.append(kind)
        at += 8+length+(length & 1)
    assert at == len(data)
    results[str(quality)] = {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
                             'size':list(output.size),'alphaExact':True,
                             'weightedColorError':error,'chunks':types}
assert len({value['sha256'] for value in results.values()}) == 3
report = {'passed':True,'decoder':f'Pillow/libwebp {features.version("webp")}',
          'source':'real Dart encoder artifacts','outputs':results,
          'physicalDeviceVerified':False}
(folder / 'independent-webp-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
