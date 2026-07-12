"""세끌 아이콘 — 토스 스타일 탐색. 옅은 배경+작은 포인트가 아니라
블루프린트 블루 풀블리드 배경 + 흰 단순 도형 하나로 뒤집는다."""
from PIL import Image, ImageDraw

S = 1024
BLUE = (0x1F, 0x5A, 0xE0)
WHITE = (0xFF, 0xFF, 0xFF)


def concept_b_dimension_line():
    img = Image.new("RGB", (S, S), BLUE)
    d = ImageDraw.Draw(img)
    w = 56
    x0, x1, y = 272, 752, 512
    tick = 70
    d.line((x0, y, x1, y), fill=WHITE, width=w)
    d.line((x0, y - tick, x0, y + tick), fill=WHITE, width=w)
    d.line((x1, y - tick, x1, y + tick), fill=WHITE, width=w)
    for cx, cy in [(x0, y - tick), (x0, y + tick), (x1, y - tick), (x1, y + tick), (x0, y), (x1, y)]:
        d.ellipse((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), fill=WHITE)
    img.save("design/icon_toss_b_dimension.png")


def concept_c_corner_brackets():
    img = Image.new("RGB", (S, S), BLUE)
    d = ImageDraw.Draw(img)
    w = 56
    d.line((300, 480, 300, 300, 480, 300), fill=WHITE, width=w, joint="curve")
    d.line((724, 544, 724, 724, 544, 724), fill=WHITE, width=w, joint="curve")
    for cx, cy in [(300, 480), (300, 300), (480, 300), (724, 544), (724, 724), (544, 724)]:
        d.ellipse((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), fill=WHITE)
    img.save("design/icon_toss_c_brackets.png")


concept_b_dimension_line()
concept_c_corner_brackets()
print("saved design/icon_toss_b_dimension.png, design/icon_toss_c_brackets.png")
