"""아이콘·스플래시 미리보기 한 장 — design/launch_preview.png.

고르기 전에 눈으로 보려고 만든다. 실제로 나가는 그림은
make_icon_barcode.py(아이콘)와 스플래시 리소스 쪽이 만든다.

    python design/make_launch_preview.py
"""

import math

from PIL import Image, ImageDraw, ImageFont

from make_icon_barcode import FINAL, _wave_band, wave

INK = (31, 31, 31)
PAPER = (239, 239, 239)
DARK_BG = (30, 30, 30)
DARK_INK = (232, 232, 232)
SHEET_BG = (214, 214, 214)


def _font(px):
    try:
        return ImageFont.truetype('assets/fonts/NanumGothicCoding-Regular.ttf', px)
    except OSError:
        return ImageFont.load_default()


def mask(im, kind):
    """기기 마스크 — 안드로이드 런처가 아이콘을 잘라내는 모양."""
    m = Image.new('L', im.size, 0)
    d = ImageDraw.Draw(m)
    w, h = im.size
    if kind == 'circle':
        d.ellipse([0, 0, w - 1, h - 1], fill=255)
    elif kind == 'squircle':
        d.rounded_rectangle([0, 0, w - 1, h - 1], int(w * 0.28), fill=255)
    else:
        d.rectangle([0, 0, w - 1, h - 1], fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im.convert('RGB'), (0, 0), m)
    return out


def wave_mark(w, h, color):
    """앱 안에서 쓰는 가로형 물결(AppTheme.waveMark)과 같은 곡선."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    amp, th, lobes, hitch = h * 0.17, h * 0.40, 3.5, 1
    head = h * 0.5 - th / 2
    k = min(1.6, max(0.25, head / amp - 1))
    up = wave(0, w, h / 2 - th / 2, lobes, amp, hitch, hitch_k=k, steps=200)
    lo = wave(0, w, h / 2 + th / 2, lobes, amp, hitch, hitch_k=k, steps=200)
    d.polygon(up + lo[::-1], fill=color)
    return im


def phone(bg, mark_color=None, w=172, h=352):
    """스플래시가 뜬 화면 한 장."""
    im = Image.new('RGB', (w, h), bg)
    if mark_color is not None:
        mw = int(w * 0.54)
        mh = int(mw * 0.20)
        im.paste(wave_mark(mw, mh, mark_color), ((w - mw) // 2, (h - mh) // 2),
                 wave_mark(mw, mh, mark_color))
    # 기기 모서리
    r = Image.new('L', (w, h), 0)
    ImageDraw.Draw(r).rounded_rectangle([0, 0, w - 1, h - 1], 22, fill=255)
    out = Image.new('RGB', (w, h), SHEET_BG)
    out.paste(im, (0, 0), r)
    return out


def main():
    icon = _wave_band(1024, **FINAL)
    f = _font(15)
    fh = _font(18)

    W, H = 1290, 830
    sheet = Image.new('RGB', (W, H), SHEET_BG)
    d = ImageDraw.Draw(sheet)
    d.text((44, 34), '세끌 · 앱 아이콘과 켜지는 순간', fill=INK, font=fh)

    # ── 아이콘 줄 ──
    d.text((44, 84), '앱 아이콘 — 런처 마스크별', fill=(74, 74, 74), font=f)
    x, y = 44, 112
    for kind, label in [('squircle', '스퀘어클'), ('circle', '원형'), ('square', '정사각')]:
        for sz in (128, 64):
            ic = mask(icon.resize((sz, sz), Image.LANCZOS), kind)
            sheet.paste(ic, (x, y + (128 - sz) // 2), ic)
            x += sz + 16
        d.text((x - 208, y + 134), label, fill=(90, 90, 90), font=f)
        x += 46

    # ── 스플래시 ──
    d.text((44, 300), '켜지는 순간 — (가) 색만 / (나) 색 + 물결', fill=(74, 74, 74), font=f)
    shots = [
        ('지금 · 라이트', phone((255, 255, 255))),
        ('지금 · 다크', phone((0, 0, 0))),
        ('(가) 라이트', phone(PAPER)),
        ('(가) 다크', phone(DARK_BG)),
        ('(나) 라이트', phone(PAPER, INK)),
        ('(나) 다크', phone(DARK_BG, DARK_INK)),
    ]
    x, y = 44, 336
    for label, img in shots:
        sheet.paste(img, (x, y))
        d.text((x, y + 362), label, fill=(90, 90, 90), font=f)
        x += img.size[0] + 22

    sheet.save('design/launch_preview.png')
    print('design/launch_preview.png', sheet.size)


if __name__ == '__main__':
    main()
