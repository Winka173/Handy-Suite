"""Handy Habit's Play feature graphic (1024 x 500), EN and VI, and the 512 icon.

Run after `flutter test --no-pub tool/store_shots_test.dart` (it reads
build/store/*) and tool/icon/render.py; writes into the gitignored
android/fastlane/metadata/android/<lang>/images/ for `fastlane android images`.
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

APP = Path(__file__).resolve().parents[1].as_posix() + '/'
SHOTS = APP + 'build/store/'
OUT = APP + 'android/fastlane/metadata/android/'
GROUND = (250, 247, 242)
INK = (41, 28, 25)
MUTED = (102, 83, 76)
HUE = (180, 35, 24)


def font(weight, size):
    return ImageFont.truetype(APP + f'fonts/Nunito-{weight}.ttf', size)


def rounded(im, r):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), r, fill=255)
    out = Image.new('RGBA', im.size)
    out.paste(im, (0, 0), mask)
    return out


def phone(shot, width, crop_h):
    im = Image.open(SHOTS + shot).convert('RGB')
    scale = width / im.size[0]
    im = im.resize((width, int(im.size[1] * scale)), Image.LANCZOS).crop((0, 0, width, crop_h))
    rim = 7
    body = rounded(Image.new('RGB', (width + rim * 2, crop_h + rim * 2), (40, 26, 22)), 30)
    body.paste(rounded(im, 24), (rim, rim), rounded(im, 24))
    return body


def shadow(canvas, box, radius=30):
    sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(box, radius, fill=(60, 20, 10, 70))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))


def graphic(lang, line1, line2, body):
    c = Image.new('RGBA', (1024, 500), GROUND + (255,))
    d = ImageDraw.Draw(c)
    icon = Image.open(APP + 'tool/icon/art.png').convert('RGB').resize((84, 84), Image.LANCZOS)
    c.alpha_composite(rounded(icon, 20), (56, 52))
    d.text((158, 94), 'Handy Habit', font=font('SemiBold', 38), fill=INK, anchor='lm')
    d.text((56, 210), line1, font=font('Bold', 46), fill=INK, anchor='ls')
    d.text((56, 280), line2, font=font('Bold', 46), fill=HUE, anchor='ls')
    y = 325
    for row in body:
        d.text((56, y), row, font=font('Regular', 22), fill=MUTED, anchor='lt')
        y += 32
    back = phone(f'{lang}-01-today.png', 210, 420)
    front = phone(f'{lang}-04-year.png', 210, 380)
    shadow(c, (560, 60, 560 + back.size[0], 60 + back.size[1]))
    c.alpha_composite(back, (560, 60))
    shadow(c, (770, 110, 770 + front.size[0], 110 + front.size[1]))
    c.alpha_composite(front, (770, 110))
    folder = 'en-US' if lang == 'en' else 'vi'
    os.makedirs(OUT + f'{folder}/images', exist_ok=True)
    c.convert('RGB').save(OUT + f'{folder}/images/featureGraphic.png')


graphic('en', 'Small things, kept.', 'One bead a day.',
        ['Habits, routines and honest progress.', 'Offline, no account.'])
graphic('vi', 'Việc nhỏ, giữ đều.', 'Mỗi ngày một hạt.',
        ['Thói quen, quy trình và tiến bộ thật.', 'Không cần mạng, không tài khoản.'])

icon = Image.open(APP + 'tool/icon/art.png').convert('RGB').resize((512, 512), Image.LANCZOS)
for folder in ['en-US', 'vi']:
    icon.save(OUT + f'{folder}/images/icon.png')
print('ok')
