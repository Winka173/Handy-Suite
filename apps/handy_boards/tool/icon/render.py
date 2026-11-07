"""Render the original SVG and mirror its geometry into Android vectors.

Requires Pillow and Playwright with Chromium installed. From the repo root:
    python apps/handy_boards/tool/icon/render.py
    python tooling/app-icons.py boards
    python apps/handy_boards/tool/icon/render.py --finish --previews <directory>

The last step restores the rounded 256px in-app tile and Boards' web
background after the shared generator, and optionally saves previews.
"""
import argparse
import copy
import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw


APP = Path(__file__).resolve().parents[2]
ART = APP / 'tool/icon'
SVG = 'http://www.w3.org/2000/svg'
ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('', SVG)
ET.register_namespace('android', ANDROID)


def android_attributes(**values):
    return {f'{{{ANDROID}}}{key}': str(value) for key, value in values.items()}


def vector_element(source, monochrome=False):
    if source.tag == f'{{{SVG}}}path':
        return ET.Element('path', android_attributes(
            fillColor='#FF000000' if monochrome else '#FF' + source.attrib['fill'][1:],
            pathData=source.attrib['d']))
    result = ET.Element('group')
    transform = source.get('transform')
    if transform:
        # The only source transform is the lifted card's rotation.
        angle, x, y = transform.removeprefix('rotate(').removesuffix(')').split()
        result.attrib.update(android_attributes(rotation=angle, pivotX=x, pivotY=y))
    result.extend(vector_element(child, monochrome) for child in source)
    return result


def write_android(source):
    res = APP / 'android/app/src/main/res'
    for suffix, monochrome in [('foreground', False), ('monochrome', True)]:
        vector = ET.Element('vector', android_attributes(
            width='108dp', height='108dp', viewportWidth=108, viewportHeight=108))
        vector.append(vector_element(source.find(f'{{{SVG}}}g'), monochrome))
        ET.indent(vector, space='    ')
        path = res / f'drawable/ic_launcher_{suffix}.xml'
        path.parent.mkdir(parents=True, exist_ok=True)
        ET.ElementTree(vector).write(path, encoding='utf-8', xml_declaration=True)
    adaptive = res / 'mipmap-anydpi-v26/ic_launcher.xml'
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
''', encoding='utf-8')
    (res / 'values/ic_launcher_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#A61C8E</color>
</resources>
''', encoding='utf-8')


def render_svg(page, source, viewbox):
    svg = copy.deepcopy(source)
    svg.set('viewBox', viewbox)
    svg.set('width', '4096')
    svg.set('height', '4096')
    page.set_content('<style>html,body{margin:0;width:4096px;height:4096px}svg{display:block}</style>'
                     + ET.tostring(svg, encoding='unicode'))
    data = page.screenshot()
    return Image.open(io.BytesIO(data)).convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)


def tile(art, size):
    image = art.convert('RGBA').resize((size * 4, size * 4), Image.Resampling.LANCZOS)
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius=int(image.width * .22), fill=255)
    image.putalpha(mask)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finish', action='store_true', help='Only write the in-app tile and previews')
    parser.add_argument('--previews', type=Path)
    args = parser.parse_args()
    if not args.finish:
        from playwright.sync_api import sync_playwright
        source = ET.parse(APP / 'assets/icon.svg').getroot()
        write_android(source)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch()
            page = browser.new_page(viewport={'width': 4096, 'height': 4096}, device_scale_factor=1)
            for name, box in [('art', '18 18 72 72'), ('maskable', '0 0 108 108')]:
                render_svg(page, source, box).save(ART / f'{name}.png')
            browser.close()
    with Image.open(ART / 'art.png') as art:
        tile(art, 256).save(APP / 'assets/icon.png')
        if args.previews:
            args.previews.mkdir(parents=True, exist_ok=True)
            for size in (28, 48, 96, 512):
                tile(art, size).save(args.previews / f'boards-{size}.png')
    manifest = APP / 'web/manifest.json'
    data = json.loads(manifest.read_text(encoding='utf-8'))
    data['theme_color'] = '#A61C8E'
    data['background_color'] = '#F3EFEE'
    manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('Boards source renders, vectors and/or final in-app tile written.')


if __name__ == '__main__':
    main()
