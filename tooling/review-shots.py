"""Collect every rebuilt app's review screenshots in one place.

Runs `tool/screens_test.dart` of each app that has one, with the real fonts,
into review-shots/<app>/, turns filmed transitions (`*-film-NNN.png`) into
GIFs, and writes review-shots/index.html to flip through all of it.

    python tooling/review-shots.py            # every app with a screens test
    python tooling/review-shots.py keep dev   # some apps
"""
import html
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'review-shots'
NAMES = {
    'tools': 'Handy Tools',
    'dev': 'Handy Dev',
    'keep': 'Handy Keep',
    'recall': 'Handy Recall',
    'bookmark': 'Handy Bookmark',
    'docs': 'Handy Docs',
    'media': 'Handy Media',
    'spend': 'Handy Spend',
    'habit': 'Handy Habit',
    'trip': 'Handy Trip',
}
FILM = re.compile(r'^(?P<name>.+)-film-(?P<n>\d{3})\.png$')


def flutter() -> str:
    exe = shutil.which('flutter') or shutil.which('flutter.bat')
    if not exe:
        sys.exit('flutter is not on PATH')
    return exe


def run(app: str) -> bool:
    folder = ROOT / 'apps' / f'handy_{app}'
    out = OUT / app
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    exe = flutter()
    env = dict(os.environ, SHOTS_DIR=str(out), FLUTTER_ROOT=str(Path(exe).resolve().parent.parent))
    print(f'{app}: rendering…', flush=True)
    result = subprocess.run(
        [exe, 'test', '--no-pub', 'tool/screens_test.dart'],
        cwd=folder, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
    )
    if result.returncode != 0:
        (out / 'FAILED.txt').write_text(result.stdout[-6000:] + result.stderr[-3000:], encoding='utf-8')
        print(f'{app}: screens test failed, see {out / "FAILED.txt"}')
    films: dict[str, list[Path]] = {}
    for p in out.glob('*.png'):
        m = FILM.match(p.name)
        if m:
            films.setdefault(m['name'], []).append(p)
    for name, frames in films.items():
        frames.sort()
        images = [Image.open(f).convert('RGB') for f in frames]
        # Shown at 40 ms per frame, a little slower than filmed, so the
        # motion can be judged; the last frame holds before the loop.
        images[0].save(out / f'{name}.gif', save_all=True, append_images=images[1:],
                       duration=[40] * (len(images) - 1) + [1200], loop=0, optimize=True)
        for f in frames:
            f.unlink()
    print(f'{app}: {len(list(out.glob("*.png")))} screens, {len(films)} films')
    return result.returncode == 0


def page() -> None:
    sections = []
    for app in NAMES:
        out = OUT / app
        if not out.exists():
            continue
        shots = sorted(out.glob('*.png'), key=lambda p: (p.name.split('-')[0] != 'phone', p.name))
        films = sorted(out.glob('*.gif'))
        failed = (out / 'FAILED.txt').exists()

        def figure(p: Path) -> str:
            caption = html.escape(p.stem.replace('-', ' '))
            return (f'<figure><a href="{app}/{p.name}"><img loading="lazy" src="{app}/{p.name}" '
                    f'alt="{caption}"></a><figcaption>{caption}</figcaption></figure>')

        body = ''.join(figure(p) for p in shots)
        motion = ''.join(figure(p) for p in films)
        sections.append(
            f'<section id="{app}"><h2>{NAMES[app]}</h2>'
            + ('<p class="warn">Screens test failed: see FAILED.txt</p>' if failed else '')
            + f'<div class="grid">{body}</div>'
            + (f'<h3>Chuyển động</h3><div class="grid">{motion}</div>' if motion else '')
            + '</section>'
        )
    nav = ' · '.join(f'<a href="#{a}">{NAMES[a]}</a>' for a in NAMES if (OUT / a).exists())
    (OUT / 'index.html').write_text(f'''<!doctype html>
<html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Handy review</title>
<style>
:root {{ --ground:#f4f4f2; --ink:#111; --muted:#5f6368; --card:#fff; --edge:#e6e6e3; }}
@media (prefers-color-scheme: dark) {{ :root {{ --ground:#111; --ink:#f2f2f2; --muted:#a8a8a8; --card:#1b1b1b; --edge:#2c2c2c; }} }}
body {{ margin:0; background:var(--ground); color:var(--ink); font:15px/1.5 system-ui, sans-serif; }}
header, section {{ max-width:1400px; margin:0 auto; padding:24px 16px; }}
h1 {{ margin:0 0 4px; font-size:24px; }} h2 {{ font-size:20px; margin:24px 0 12px; }} h3 {{ font-size:16px; margin:24px 0 8px; }}
nav, .warn {{ color:var(--muted); }} .warn {{ color:#c4242a; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(240px, 1fr)); gap:16px; align-items:start; }}
figure {{ margin:0; background:var(--card); border:1px solid var(--edge); border-radius:12px; overflow:hidden; }}
img {{ display:block; width:100%; height:auto; }}
figcaption {{ padding:8px 12px; color:var(--muted); font-size:13px; }}
</style></head><body>
<header><h1>Handy: ảnh màn hình để review</h1><nav>{nav}</nav></header>
{''.join(sections)}
</body></html>
''', encoding='utf-8')
    print(f'index: {OUT / "index.html"}')


if __name__ == '__main__':
    wanted = sys.argv[1:] or [a for a in NAMES if (ROOT / 'apps' / f'handy_{a}' / 'tool' / 'screens_test.dart').exists()]
    ok = all([run(a) for a in wanted])
    page()
    sys.exit(0 if ok else 1)
