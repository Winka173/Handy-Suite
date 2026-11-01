"""Independent verification; requires local pypdf, never runs in the app."""
import sys
from pypdf import PdfReader

reader = PdfReader(sys.argv[1], strict=True)
assert not reader.is_encrypted
assert len(reader.pages) == 2
for page, (width, height) in zip(reader.pages, [(8, 6), (5, 8)]):
    assert float(page.mediabox.width) == width
    assert float(page.mediabox.height) == height
    images = [item.get_object() for item in page['/Resources']['/XObject'].values()]
    assert len(images) == 1
    bitmap = images[0]
    assert bitmap['/Width'] == width
    assert bitmap['/Height'] == height
    assert str(bitmap['/ColorSpace']) == '/DeviceRGB'
    pixels = bitmap.get_data()
    assert len(pixels) == width * height * 3
    for y in range(height):
        for x in range(width):
            start = (y * width + x) * 3
            expected = [int(x * 255 / (width - 1) + .5), int(y * 255 / (height - 1) + .5), 64]
            assert list(pixels[start:start + 3]) == expected
print('Independent pypdf: 2 pages, dimensions, RGB image streams and every pixel verified')
