"""폰 스크린샷을 스토어 규격 목업으로 감싼다 — 1080x1920 (9:16).

두 가지를 한 번에 해결한다.

**규격.** Play는 휴대전화 스크린샷을 16:9 또는 9:16으로 받는다. 9:16은 정확히
0.5625인데 요즘 폰은 20:9(약 0.45)라 원본 그대로는 안 맞는다.

**대비.** 이 앱 화면은 거의 흰 종이다. 목업 배경까지 종이로 깔면 어디까지가
앱이고 어디부터가 배경인지 안 보인다. 그래서 바탕은 **잉크**다 — 앱 안에서
글자가 종이 위의 잉크라면, 스토어에서는 종이가 잉크 위에 놓인다. 뒤집은 것
자체가 같은 팔레트라 딴 앱처럼 보이지 않는다.

    # design/shots/ 에 01.png, 02.png … 를 넣고
    python design/make_store_screenshots.py

파일 이름 앞 두 자리가 아래 CAPTIONS의 순번이다. 없는 번호는 건너뛴다.
"""

import os

from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
INK = (31, 31, 31)
PAPER_TEXT = (245, 245, 245)   # 잉크 위에 놓는 글자 — 순백은 눈이 아프다
DIM = (150, 150, 150)

KR_BOLD = 'assets/fonts/NanumGothicCoding-Bold.ttf'

SRC = 'design/shots'
OUT = 'design/store_shots'

# 순번 → 두 줄 문구. 세 줄은 안 쓴다 — 목록에서는 썸네일이라 두 줄이 한계다.
CAPTIONS = {
    1: ('이번 달 얼마 벌고 썼는지', '한 장으로 보여요'),
    2: ('미루지 않게', '때맞춰 알려드려요'),
    3: ('혼자서도 신고할 수 있게', '순서대로 짚어드려요'),
    4: ('결제수단까지 나눠 적으면', '카드공제 계산이 따라와요'),
    # 설정 화면을 프라이버시 컷으로 쓴다. 「데이터 수집 · 수동 입력」과
    # 붉은 「개인 세무 데이터 영구 파기」가 등록정보의 첫 절을 그대로 증명한다.
    5: ('계정도 서버도 없어요', '지우면 정말로 사라져요'),
    6: ('연봉 실수령액부터 퇴직금까지', '계산기 56종'),
    7: ('몰라서 못 받는 정부 혜택', '54가지를 모았어요'),
    8: ('직장인 · N잡러 · 프리랜서', '고르면 화면이 바뀌어요'),
}


def _tracked(d, cx, y, text, font, fill, track):
    """자간을 벌려 가운데 정렬로 한 줄 찍는다.

    PIL에는 자간이 없다. 넓은 자간이 이 앱 글자의 인상이라 한 자씩 놓는다.
    """
    widths = [d.textlength(c, font=font) for c in text]
    x = cx - (sum(widths) + track * (len(text) - 1)) / 2
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=fill)
        x += w + track


def frame(shot_path, line1, line2, out_path):
    shot = Image.open(shot_path).convert('RGB')

    im = Image.new('RGB', (W, H), INK)
    d = ImageDraw.Draw(im)

    # ── 문구 ──
    # 화면 **위**에 둔다. Play 목록에서는 썸네일 크기라 화면 안 글자는 안 읽히고
    # 이 두 줄만 읽힌다. 화면 위에 겹쳐 얹으면 둘 다 못 읽는다.
    f = ImageFont.truetype(KR_BOLD, 52)
    _tracked(d, W / 2, 118, line1, f, PAPER_TEXT, 2)
    _tracked(d, W / 2, 196, line2, f, PAPER_TEXT, 2)

    # ── 화면 ──
    # 남은 자리에 비율 그대로 넣는다. 늘이거나 자르지 않는다 — 스토어에서 본
    # 화면과 깔고 나서 보는 화면이 달라 보이면 안 된다.
    top, side, bottom = 320, 84, 84
    box_w, box_h = W - side * 2, H - top - bottom
    r = min(box_w / shot.width, box_h / shot.height)
    sw, sh = round(shot.width * r), round(shot.height * r)
    sx, sy = (W - sw) // 2, top + (box_h - sh) // 2
    im.paste(shot.resize((sw, sh), Image.LANCZOS), (sx, sy))

    # 종이의 가장자리. 흰 화면이 잉크에 닿는 자리를 한 줄로 끊어 준다 —
    # 없으면 밝은 화면이 배경으로 번져 보인다.
    d.rectangle([sx - 1, sy - 1, sx + sw, sy + sh], outline=DIM, width=2)

    im.save(out_path)
    return out_path


def main():
    if not os.path.isdir(SRC):
        raise SystemExit(f'{SRC}/ 폴더에 폰 스크린샷(01.png, 02.png …)을 넣어 주세요.')
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for name in sorted(os.listdir(SRC)):
        if not name.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        try:
            no = int(name[:2])
        except ValueError:
            print(f'  건너뜀 {name} — 이름이 두 자리 숫자로 시작해야 합니다')
            continue
        if no not in CAPTIONS:
            print(f'  건너뜀 {name} — CAPTIONS에 {no}번 문구가 없습니다')
            continue
        out = frame(os.path.join(SRC, name), *CAPTIONS[no],
                    os.path.join(OUT, f'{no:02d}.png'))
        print(f'  {out}  ←  {name}')
        made += 1
    print(f'{made}장 · {W}x{H} (9:16) · {OUT}/')


if __name__ == '__main__':
    main()
