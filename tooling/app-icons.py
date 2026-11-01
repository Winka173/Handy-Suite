"""Generate every platform icon for the Handy apps from one mark family.

Each app: its hue from the suite palette (docs/UX_REDESIGN.md) as a full
field, its Material Symbols glyph in white. Existing icon files are
overwritten at their current sizes, so platform templates stay valid.

    python tooling/app-icons.py            # all apps
    python tooling/app-icons.py tools dev  # some apps
"""
import json
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
APPS = {
    'spend': ('#7C3AED', 0xE850),  # account_balance_wallet
    'tools': ('#E8590C', 0xE2F2),   # handyman
    'dev': ('#0F8A5F', 0xF0589),    # terminal
    'keep': ('#B7791F', 0xE34A),    # inventory_2
    'recall': ('#4D7C0F', 0xE613),  # style
    'save': ('#0E7490', 0xE0F1),    # bookmark
    'docs': ('#1D5FBF', 0xE1BF),    # description
    'media': ('#C2255C', 0xE4BA),   # photo_library
}


def material_font() -> Path:
    flutter = shutil.which('flutter') or shutil.which('flutter.bat')
    if not flutter:
        sys.exit('flutter not on PATH: needed for the Material icon font')
    sdk = Path(flutter).resolve().parent.parent
    return sdk / 'bin/cache/artifacts/material_fonts/materialicons-regular.otf'


def render(hue: str, glyph: int, size: int, *, radius: float = 0.0, glyph_scale: float = 0.56) -> Image.Image:
    """Full-bleed hue (or a rounded tile when radius > 0) with the glyph centred."""
    big = size * 4
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if radius > 0:
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * radius), fill=hue)
    else:
        draw.rectangle([0, 0, big, big], fill=hue)
    font = ImageFont.truetype(str(FONT), int(big * glyph_scale))
    ch = chr(glyph)
    left, top, right, bottom = draw.textbbox((0, 0), ch, font=font)
    x = (big - (right - left)) / 2 - left
    y = (big - (bottom - top)) / 2 - top
    draw.text((x, y), ch, font=font, fill='white')
    return img.resize((size, size), Image.LANCZOS)


def write_like(path: Path, make) -> None:
    """Overwrite an existing PNG at its own size."""
    with Image.open(path) as old:
        size = old.size[0]
    make(size).save(path)


def app(name: str) -> None:
    hue, glyph = APPS[name]
    base = ROOT / 'apps' / f'handy_{name}'
    if not base.exists():
        print(f'skip {name}: no app folder')
        return
    full = lambda s: render(hue, glyph, s).convert('RGB')  # iOS/stores: opaque square
    tile = lambda s: render(hue, glyph, s, radius=0.22)    # launchers that show the shape
    safe = lambda s: render(hue, glyph, s, glyph_scale=0.42).convert('RGB')  # maskable zone

    icon = base / 'assets/icon.png'
    if icon.exists():
        write_like(icon, full)
    for p in (base / 'android/app/src/main/res').glob('mipmap-*/ic_launcher*.png'):
        write_like(p, tile)
    for p in (base / 'ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'):
        write_like(p, full)
    web = base / 'web'
    for p in (web / 'icons').glob('Icon-maskable-*.png'):
        write_like(p, safe)
    for p in (web / 'icons').glob('Icon-[0-9]*.png'):
        write_like(p, tile)
    if (web / 'favicon.png').exists():
        write_like(web / 'favicon.png', tile)
    manifest = web / 'manifest.json'
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding='utf-8'))
        data['theme_color'] = hue
        data['background_color'] = '#F8F8F8'
        manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    ico = base / 'windows/runner/resources/app_icon.ico'
    if ico.exists():
        tile(256).save(ico, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print(f'{name}: {hue}')


FONT = material_font()
if __name__ == '__main__':
    for n in sys.argv[1:] or list(APPS):
        app(n)
