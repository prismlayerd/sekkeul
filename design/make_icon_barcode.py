"""세끌 앱 아이콘 후보 — design/icon_barcode_board.png + 각 후보 1024.

마크는 **절취선 그 자체**다. 종이 안에 갇힌 톱니가 아니라, 화면을 가로질러
끝에서 끝까지 달리는 굵은 물결. 뜯는 **행위**를 그린다.

각진 톱니는 이빨 자국처럼 날카로워 앱 아이콘으로 사납다. 봉우리 수를 줄이고
사인 곡선으로 부드럽게 눕혔다 — 뜯긴 자리는 원래 반듯하지 않고 둥글다.

꽉 채우는 이유가 하나 더 있다: 안드로이드 적응형 아이콘은 바깥을 잘라내는데,
가장자리까지 이어지는 무늬는 어떻게 잘려도 살아남는다.

왜 이미지 생성 모델이 아니라 코드인가:
런처 아이콘은 48dp에서도 막대가 뭉개지면 안 된다. 픽셀 격자에 딱 떨어지는
막대 폭이 필요하고, 앱 팔레트(#1F1F1F 잉크 / #EFEFEF 종이)와 정확히 같아야 한다.
그림을 그리는 게 아니라 **치수를 지키는** 일이라 코드가 맞다.

    python design/make_icon_barcode.py
"""

import math

from PIL import Image, ImageDraw, ImageFont

INK = (31, 31, 31)
PAPER = (239, 239, 239)

# 런처 아이콘의 바탕만 **순백**이다.
#
# 앱 안의 종이는 #EFEFEF(영수증 회색)지만, 런처에서는 그게 회색 타일로 보인다.
# 옆에 놓인 다른 아이콘들이 대개 흰 바탕이라 우리만 때가 탄 것처럼 읽힌다.
# 바탕은 순백으로 두고 물결을 잉크로 찍는다 — 앱을 열면 그때 종이색이 된다.
ICON_BG = (255, 255, 255)
S = 1024

# 안드로이드 적응형 아이콘은 바깥 33%가 잘려 나갈 수 있다.
# 마크는 안쪽 66% 안에 둔다.
SAFE = 0.62

# 막대 패턴 — 폭 단위(굵기), 사이는 1단위씩 띈다.
# 5개로 줄인 이유: 48dp에서 7개는 서로 붙어 회색 덩어리로 보인다.
BARS = [3, 1, 2, 1, 3]
GAP = 1


def bar_geometry(x0: float, w: float):
    """막대 [(왼쪽, 폭)] 목록. 폭 w 안에 BARS를 균등 배치한다."""
    units = sum(BARS) + GAP * (len(BARS) - 1)
    u = w / units
    out, x = [], x0
    for i, b in enumerate(BARS):
        out.append((x, b * u))
        x += (b + GAP) * u
    return out


def base(size=S):
    im = Image.new('RGB', (size, size), PAPER)
    return im, ImageDraw.Draw(im)


def wave(x0, x1, y, lobes, amp, hitch=None, hitch_k=0.9, steps=240):
    """부드러운 물결 경로. [hitch]를 주면 그 봉우리만 완만하게 더 솟는다."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = amp
        if hitch is not None:
            # 한 봉우리 둘레에만 걸리는 완만한 봉투 — 각 없이 어긋난다.
            c = (hitch + 0.5) / lobes
            a *= 1 + hitch_k * math.exp(-(((t - c) / (0.55 / lobes)) ** 2))
        pts.append((x0 + (x1 - x0) * t, y - a * math.sin(2 * math.pi * lobes * t)))
    return pts


def _wave_split(size, lobes=2.5, amp_r=0.17, hitch=None, invert=False):
    """타일을 물결로 갈라 위아래를 잉크/종이로 나눈다 — 뜯기는 순간."""
    top_c, bot_c = (PAPER, INK) if invert else (INK, PAPER)
    im = Image.new('RGB', (size, size), top_c)
    d = ImageDraw.Draw(im)
    pts = wave(-size * 0.05, size * 1.05, size * 0.5, lobes, size * amp_r, hitch)
    d.polygon([(-size, size * 2)] + pts + [(size * 2, size * 2)], fill=bot_c)
    return im


def _wave_band(size, lobes=2.5, amp_r=0.15, th_r=0.22, hitch=None,
               hitch_k=None, invert=False):
    """잉크 바탕을 가로지르는 굵은 종이 물결.

    어긋난 봉우리는 진폭이 커질수록 타일 밖으로 나간다. 넘치는 만큼 배율을
    자동으로 낮춰, 진폭을 올려도 봉우리 끝이 항상 안쪽에 남게 한다.
    """
    if hitch is not None and hitch_k is None:
        head = 0.46 - th_r / 2          # 봉우리가 쓸 수 있는 최대 높이
        # 잔잔할수록 배율은 커지지만 1.6에서 멈춘다 — 그 위는 봉우리가 아니라 가시다.
        hitch_k = min(1.6, max(0.25, head / amp_r - 1))
    bg, fg = (PAPER, INK) if invert else (INK, PAPER)
    im = Image.new('RGB', (size, size), bg)
    d = ImageDraw.Draw(im)
    y, amp, th = size * 0.5, size * amp_r, size * th_r
    kw = {} if hitch is None else {'hitch_k': hitch_k}
    up = wave(-size * 0.05, size * 1.05, y - th / 2, lobes, amp, hitch, **kw)
    lo = wave(-size * 0.05, size * 1.05, y + th / 2, lobes, amp, hitch, **kw)
    d.polygon(up + lo[::-1], fill=fg)
    return im


def concept_a(size=S):
    """A · 물결 절취 — 봉우리 둘 반. 잉크와 종이가 부드럽게 갈린다."""
    return _wave_split(size, lobes=2.5)


def concept_b(size=S):
    """B · 물결 띠 — 잉크 위를 가로지르는 종이 띠. 각을 다 눕혔다."""
    return _wave_band(size, lobes=2.5)


def concept_c(size=S):
    """C · 부채꼴 절취 — 봉우리 둘. 제일 크고 느리다. 48px에서 가장 순하다."""
    return _wave_split(size, lobes=1.5, amp_r=0.20)


def concept_d(size=S):
    """D · 어긋난 물결 — 봉우리 하나만 완만하게 더 솟는다. 각 없이 불규칙하다."""
    return _wave_band(size, lobes=2.5, hitch=1)


# B(고른 물결)와 D(어긋난 물결)를 진폭 3단계로 — "좀만 더 크게"의 폭을 눈으로 고른다.
AMPS = [0.15, 0.21, 0.26]

CONCEPTS = [
    ('B06', '고른 6',  lambda z=S: _wave_band(z, amp_r=0.06)),
    ('B09', '고른 9',  lambda z=S: _wave_band(z, amp_r=0.09)),
    ('B12', '고른 12', lambda z=S: _wave_band(z, amp_r=0.12)),
    ('D06', '어긋 6',  lambda z=S: _wave_band(z, amp_r=0.06, hitch=1)),
    ('D09', '어긋 9',  lambda z=S: _wave_band(z, amp_r=0.09, hitch=1)),
    ('D12', '어긋 12', lambda z=S: _wave_band(z, amp_r=0.12, hitch=1)),
]


def _font(px):
    """앱이 번들하는 한글 고정폭을 그대로 쓴다 — 보드도 같은 글꼴이어야 한다."""
    try:
        return ImageFont.truetype('assets/fonts/NanumGothicCoding-Regular.ttf', px)
    except OSError:
        return ImageFont.load_default()


def board():
    """후보 4개 × 크기 4단계 — 48px에서 뭉개지는 안을 눈으로 걸러낸다."""
    sizes = [220, 96, 48]
    pad, gap, label_h = 48, 26, 30
    col_w = max(sizes)
    f = _font(15)
    fh = _font(17)
    rows = [(sz, sz + label_h + gap) for sz in sizes]
    W = pad * 2 + len(CONCEPTS) * col_w + (len(CONCEPTS) - 1) * gap
    H = pad * 2 + 40 + sum(h for _, h in rows)
    im = Image.new('RGB', (W, H), (226, 226, 226))
    d = ImageDraw.Draw(im)
    d.text((pad, pad - 8), '세끌 · 잔잔한 물결 (B 고른 / D 어긋난)', fill=(31, 31, 31), font=fh)
    y = pad + 40
    for sz, rh in rows:
        for c, (key, name, fn) in enumerate(CONCEPTS):
            x = pad + c * (col_w + gap)
            icon = fn(1024).resize((sz, sz), Image.LANCZOS)
            im.paste(icon, (int(x + (col_w - sz) / 2), int(y)))
            d.text((x + (col_w - sz) / 2, y + sz + 7),
                   '%s · %s · %dpx' % (key, name, sz), fill=(74, 74, 74), font=f)
        y += rh
    im.save('design/icon_barcode_board.png')
    print('design/icon_barcode_board.png', im.size)


def foreground(fn, size=S):
    """적응형 아이콘 전경 — 종이색을 투명으로 뺀 막대만. 배경은 pubspec이 칠한다."""
    im = fn(size).convert('RGBA')
    px = im.load()
    for y in range(size):
        for x in range(size):
            r, g, b, _ = px[x, y]
            if (r, g, b) == PAPER:
                px[x, y] = (0, 0, 0, 0)
    return im


# ── 최종안 ────────────────────────────────────────────────────────────
# 잔잔한 물결 + 봉우리 하나만 완만하게. 값 하나로 B(고른)로 되돌릴 수 있다.
FINAL = dict(lobes=2.5, amp_r=0.06, th_r=0.22, hitch=1)


def ship():
    """런처 규격 두 장을 만든다.

    icon.png   — iOS·구형 안드로이드용 1024 정사각. 알파 없음(스토어 규정).
    icon_fg.png— 적응형 아이콘 전경. 안드로이드는 108dp 중 안쪽 72dp만 확실히
                 보인다(바깥 33%는 마스크에 잘린다). 물결 띠의 세로 폭이 그
                 **안전 영역** 안에 들어가야 어떤 기기 마스크에서도 안 잘린다.
                 가로로는 일부러 끝까지 흘려보낸다 — 잘려도 무늬가 이어진다.
    """
    # 잉크 바탕에 흰 물결이었던 것을 **뒤집었다** — 흰 바탕에 잉크 물결.
    icon = _wave_band(S, invert=True, **FINAL)
    # invert는 바탕을 PAPER(#EFEFEF)로 칠한다. 런처에서는 순백이어야 한다.
    px = icon.load()
    for y in range(S):
        for x in range(S):
            if px[x, y] == PAPER:
                px[x, y] = ICON_BG
    icon.save('assets/icon/icon.png')

    # 전경: 잉크 띠만 남기고 흰 바탕을 투명으로.
    fg = icon.convert('RGBA')
    a = fg.load()
    for y in range(S):
        for x in range(S):
            r, g, b, _ = a[x, y]
            a[x, y] = (r, g, b, 255) if (r, g, b) == INK else (0, 0, 0, 0)
    fg.save('assets/icon/icon_fg.png')

    # 안전 영역 검사 — 띠가 안쪽 66%를 벗어나면 마스크에 잘린다.
    top, bot = S, 0
    for y in range(S):
        for x in range(0, S, 8):
            if a[x, y][3]:
                top, bot = min(top, y), max(bot, y)
                break
    safe0, safe1 = S * 0.17, S * 0.83
    ok = top >= safe0 and bot <= safe1
    print('assets/icon/icon.png, icon_fg.png · 띠 세로 %d~%d / 안전 %d~%d · %s'
          % (top, bot, safe0, safe1, 'OK' if ok else '넘침!'))


def main():
    for key, name, fn in CONCEPTS:
        k = key.lower()
        fn(S).save('design/icon_barcode_%s.png' % k)
        foreground(fn).save('design/icon_barcode_%s_fg.png' % k)
        print('design/icon_barcode_%s.png (+_fg)' % k)
    board()
    ship()


if __name__ == '__main__':
    main()
