"""세끌 아이콘 최종안 — 두꺼운 흰 삼각형 링 + 오른쪽에서 비쳐오는
비대칭 방사형 글로우(왼쪽은 검정, 오른쪽으로 갈수록 밝아짐). 잔가지 광선 없이
완전히 깔끔한 형태. 무채색(블루 틴트 없음).
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024

CX, CY = S / 2, S / 2 + 10
APEX = (CX, 190)
BL = (CX - 250, 700)
BR = (CX + 250, 700)
VERTS = [APEX, BR, BL]

# 글로우 광원 위치 — 캔버스 오른쪽 바깥쪽
LIGHT = (S * 0.98, S * 0.46)


def make_background():
    """오른쪽에서 비쳐오는 비대칭 방사형 글로우. 대부분은 어둡게 유지하고
    광원 근처 좁은 영역만 밝아지도록 급격한 커브 + 낮은 최대 밝기."""
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    max_r = int(S * 0.72)
    steps = 90
    for i in range(steps, 0, -1):
        r = max_r * i / steps
        t = 1 - i / steps
        val = int(205 * (t ** 3.2))
        d.ellipse((LIGHT[0] - r, LIGHT[1] - r, LIGHT[0] + r, LIGHT[1] + r), fill=val)
    img = img.filter(ImageFilter.GaussianBlur(10))
    return img.convert("RGB")


def main():
    canvas = make_background()

    # 삼각형 링 — 두꺼운 흰 테두리 + 안쪽 어두운 채움
    ring = ImageDraw.Draw(canvas)
    ring.polygon(VERTS, fill=(255, 255, 255))

    inset = 46
    cx0 = sum(v[0] for v in VERTS) / 3
    cy0 = sum(v[1] for v in VERTS) / 3
    inner_verts = []
    for vx, vy in VERTS:
        dx, dy = vx - cx0, vy - cy0
        dlen = math.hypot(dx, dy)
        inner_verts.append((vx - dx / dlen * inset, vy - dy / dlen * inset))
    ring.polygon(inner_verts, fill=(17, 17, 18))

    canvas.save("design/icon_triangle_light.png")
    print("saved design/icon_triangle_light.png")


main()
