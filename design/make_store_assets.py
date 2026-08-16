"""스토어 등록정보에 올릴 두 장 — 앱 아이콘 512와 그래픽 이미지 1024x500.

콘솔에 올라가 있던 것은 블루프린트 시절 유물이다(검은 역삼각형 + 크림 배경에
네모 두른 세리프 「세끌」). 앱은 영수증으로 갈아입었는데 스토어만 옛 옷이라
같은 앱으로 안 보인다.

두 장 모두 **앱이 실제로 쓰는 재료**로만 만든다 — 물결은 make_icon_barcode의
FINAL 그대로, 종이는 assets/textures/paper_1.jpg, 글꼴은 앱이 번들하는
NanumGothicCoding. 스토어에서 본 인상과 열었을 때의 인상이 어긋나면 안 된다.

    python design/make_store_assets.py
"""

from PIL import Image, ImageDraw, ImageFont

from make_icon_barcode import INK, PAPER, wave

SUB = (74, 74, 74)      # inkSecondary
LINE = (182, 182, 182)  # 헤어라인

KR_BOLD = 'assets/fonts/NanumGothicCoding-Bold.ttf'
KR = 'assets/fonts/NanumGothicCoding-Regular.ttf'


def store_icon(path='design/store_icon_512.png'):
    """512 정사각 스토어 아이콘.

    런처에 깔린 것과 **같은 그림**이어야 한다. 사용자가 스토어에서 본 아이콘을
    홈 화면에서 다시 찾을 때 눈이 헤매면 안 되므로 assets/icon/icon.png를
    그대로 줄인다 — 따로 그리면 언젠가 둘이 어긋난다.

    알파는 넣지 않는다(스토어 규정). 물결은 좌우 끝까지 흘려보내되 모서리는
    비어 있어서, Play가 씌우는 둥근 마스크에 잘릴 것이 없다.
    """
    im = Image.open('assets/icon/icon.png').convert('RGB')
    im.resize((512, 512), Image.LANCZOS).save(path)
    print(path, '512x512')


def _mark(w, h, color=INK, ss=4):
    """앱 머리의 물결(AppTheme.waveMark)을 그대로 그린다.

    상수 셋은 `_WaveMarkPainter`에서 가져왔다 — 파장을 고정하고 봉우리 수를
    폭에서 뽑기 때문에, 크기를 바꿔도 물결 모양은 그대로고 양 끝만 잘린다.
    PIL에는 안티에일리어싱이 없어 [ss]배로 그린 뒤 줄인다.
    """
    LOBE_SPAN, AMP_R, TH_R, HITCH = 1.45, 0.17, 0.40, 1
    W, H = w * ss, h * ss
    lobes = (W / H) / LOBE_SPAN
    amp, th = H * AMP_R, H * TH_R
    # 봉우리가 위아래로 넘치지 않을 만큼만 키운다 — 아이콘 쪽과 같은 규칙.
    hitch_k = min(1.6, max(0.25, (H * 0.5 - th / 2) / amp - 1))
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    up = wave(0, W, H / 2 - th / 2, lobes, amp, HITCH, hitch_k=hitch_k)
    lo = wave(0, W, H / 2 + th / 2, lobes, amp, HITCH, hitch_k=hitch_k)
    d.polygon(up + lo[::-1], fill=color + (255,))
    return im.resize((w, h), Image.LANCZOS)


def _tracked(d, xy, text, font, fill, track=0.0, anchor_center=False):
    """자간을 벌려 한 줄 찍고 그 폭을 돌려준다.

    PIL에는 자간이 없다. 절 머리(`01 · 이번 달 수입`)의 넓은 자간이 이 앱
    글자의 인상을 만들기 때문에 한 자씩 놓아 흉내낸다.
    """
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths) + track * (len(text) - 1)
    x, y = xy
    if anchor_center:
        x -= total / 2
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=fill)
        x += w + track
    return total


def feature_graphic(path='design/feature_graphic.png'):
    """1024x500 그래픽 이미지 — 영수증 한 장의 머리.

    Play는 이 그림을 자르거나 위에 재생 버튼을 얹을 수 있으므로 뜻이 있는 것은
    가운데 몰아 둔다. 가장자리에는 종이만 남긴다.
    """
    W, H = 1024, 500

    # ── 바탕: 앱과 같은 종이 사진 ──
    # 앱은 종이색 위에 사진을 82%로 얹는다(AppTheme.paperBackdrop). 같은 셈을
    # 여기서도 한다 — 사진만 쓰면 스토어에서 너무 어둡고 얼룩져 보인다.
    src = Image.open('assets/textures/paper_1.jpg').convert('RGB')
    r = max(W / src.width, H / src.height)
    src = src.resize((round(src.width * r), round(src.height * r)), Image.LANCZOS)
    left, top = (src.width - W) // 2, (src.height - H) // 2
    photo = src.crop((left, top, left + W, top + H))
    im = Image.blend(Image.new('RGB', (W, H), PAPER), photo, 0.82)
    d = ImageDraw.Draw(im)

    # ── 물결 ──
    # 아이콘의 물결이 아니라 **앱 머리의 물결**이다(AppTheme.waveMark).
    # 아이콘 쪽은 타일을 가로지르는 굵은 띠라, 잘라내서 종이 위에 얹으면
    # 위아래 여백을 잃고 검은 덩어리로 읽힌다. 스토어에서 본 마크와 앱을 열어
    # 처음 보는 마크가 같아야 하므로 머리 쪽 규칙(_WaveMarkPainter)을 옮겼다.
    mw, mh = 300, round(300 / (84 / 23))   # 앱 머리와 같은 가로세로비
    im.paste(_mark(mw, mh), (W // 2 - mw // 2, 96), _mark(mw, mh))

    # ── 워드마크와 한 줄 ──
    _tracked(d, (W / 2, 244), '세끌', ImageFont.truetype(KR_BOLD, 84), INK,
             track=14, anchor_center=True)
    _tracked(d, (W / 2, 360), '환급 계산기 · 절세 · 연말정산 · 종소세 · 가계부',
             ImageFont.truetype(KR, 25), SUB, track=1.5, anchor_center=True)

    # ── 절취선 ──
    # 영수증이라고 말하지 않고 영수증으로 보이게 하는 건 결국 이 한 줄이다.
    y = 428
    x = 150
    while x < W - 150:
        d.line([(x, y), (x + 7, y)], fill=LINE, width=2)
        x += 14

    im.save(path)
    print(path, f'{W}x{H}')


if __name__ == '__main__':
    store_icon()
    feature_graphic()
