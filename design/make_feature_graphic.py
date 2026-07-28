"""Play 스토어 피처그래픽 1024×500 — 박스형 '세끌' 워드마크 + 새 제목 키워드.

Blueprint 규칙 그대로: 콘크리트 바탕, 헤어라인 테두리, 그림자 0, 라운드 최소.
글자는 앱이 번들하는 폰트를 그대로 쓴다(Noto Serif KR) — 스토어와 앱이 다른
서체를 쓰면 설치 직후 딴 앱처럼 보인다.

가장자리는 일부 노출면에서 잘리므로 내용을 중앙 600px 안에 둔다.
"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 500
SS = 3  # 슈퍼샘플 — 블러 없이 가장자리를 매끈하게

BG      = (0xF8, 0xF7, 0xF5)  # lightBackground
INK     = (0x16, 0x15, 0x13)  # lightInk
SUB     = (0x5E, 0x5C, 0x57)  # lightInkSecondary
LINE    = (0xC7, 0xC2, 0xB8)  # lightLineStrong

SERIF = "assets/fonts/NotoSerifKR-Variable.ttf"

WORDMARK = "세끌"
KEYWORDS = "환급 계산기 · 절세 · 연말정산 · 종소세"


def main():
    img = Image.new("RGB", (W * SS, H * SS), BG)
    d = ImageDraw.Draw(img)

    f_mark = ImageFont.truetype(SERIF, 104 * SS)
    f_key = ImageFont.truetype(SERIF, 34 * SS)

    # 워드마크 박스 — 글자 실제 bbox에 균등 여백을 둘러 만든다.
    # 폰트 메트릭(ascent/descent)으로 잡으면 한글은 위아래 여백이 비대칭으로 남는다.
    bx0, by0, bx1, by1 = d.textbbox((0, 0), WORDMARK, font=f_mark)
    tw, th = bx1 - bx0, by1 - by0
    pad_x, pad_y = 52 * SS, 34 * SS
    box_w, box_h = tw + pad_x * 2, th + pad_y * 2

    gap = 42 * SS
    key_h = d.textbbox((0, 0), KEYWORDS, font=f_key)[3] - d.textbbox((0, 0), KEYWORDS, font=f_key)[1]
    total_h = box_h + gap + key_h

    cx = W * SS / 2
    top = (H * SS - total_h) / 2

    # 테두리 좌표를 **최종 해상도의 정수**에 맞춘다. 어긋나면 축소할 때 한 선이
    # 두 픽셀에 나뉘어 반투명하게 번진다 — 그게 '흐릿함'의 정체다.
    def snap(v):
        return round(v / SS) * SS

    x0, x1 = snap(cx - box_w / 2), snap(cx + box_w / 2)
    y0, y1 = snap(top), snap(top + box_h)

    d.rounded_rectangle(
        (x0, y0, x1 - 1, y1 - 1),
        radius=10 * SS, outline=INK, width=4 * SS,
    )
    # bbox 오프셋을 빼야 글자가 박스 정중앙에 온다.
    d.text(((x0 + x1) / 2 - tw / 2 - bx0, (y0 + y1) / 2 - th / 2 - by0),
           WORDMARK, font=f_mark, fill=INK)
    d.text((cx, y1 + gap), KEYWORDS, font=f_key, fill=SUB, anchor="ma")

    img.resize((W, H), Image.LANCZOS).save("design/feature_graphic.png")
    print("saved design/feature_graphic.png 1024x500")


main()
