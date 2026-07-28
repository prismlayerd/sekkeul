"""세끌 아이콘 — 라이트모드 색감, 가운데 삼각형만, 글로우 없음.

종전 아이콘(icon_final.png)은 무광 블랙 바탕에 오른쪽 방사형 글로우 + 노이즈가
있었다. 앱 라이트 테마(콘크리트 #F8F7F5 / 도면 블루 #1F5AE0)와 따로 놀고,
Blueprint 디자인 시스템의 "그림자 0" 원칙과도 어긋난다. 전부 걷어내고 평면으로.

안티에일리어싱은 4배 슈퍼샘플 후 축소로 얻는다 — 블러를 쓰면 그게 곧 빛번짐이다.

출력:
  icon_light_solid.png / icon_light_ring.png        전체 1024 (iOS·레거시용)
  icon_light_*_fg.png                                투명 배경 (안드로이드 어댑티브 전경)
"""
import math
from PIL import Image, ImageDraw

S = 1024
SS = 4  # 슈퍼샘플 배수

BG = (0xF8, 0xF7, 0xF5)      # lightBackground 콘크리트 오프화이트
FG = (0x1F, 0x5A, 0xE0)      # lightAccent 도면 블루

# 어댑티브 아이콘은 108dp 중 72dp만 보인다(중앙 약 66%). 어떤 마스크(원·스퀘어클)로
# 잘려도 살아남도록 중심 반지름 338px 안에 전부 넣는다.
HALF_W = 230.0                      # 밑변 절반
HEIGHT = HALF_W * math.sqrt(3)      # 정삼각형 높이 ≈ 398
CX = CY = S / 2

# 무게중심을 캔버스 중심에 맞춘다 — 삼각형은 기하 중심보다 무게중심이 시각 중심에 가깝다.
BASE_Y = CY + HEIGHT / 3
APEX_Y = BASE_Y - HEIGHT
VERTS = [(CX, APEX_Y), (CX + HALF_W, BASE_Y), (CX - HALF_W, BASE_Y)]

STROKE = 48.0  # 링 두께(변에 수직인 실제 폭)


def _scaled(verts, k):
    """무게중심 기준 k배 축소. 변에 수직인 간격 = (1-k) × 내접원 반지름."""
    gx = sum(v[0] for v in verts) / 3
    gy = sum(v[1] for v in verts) / 3
    return [(gx + (x - gx) * k, gy + (y - gy) * k) for x, y in verts]


def render(ring: bool, transparent: bool) -> Image.Image:
    base = (0, 0, 0, 0) if transparent else BG + (255,)
    img = Image.new("RGBA", (S * SS, S * SS), base)
    d = ImageDraw.Draw(img)
    d.polygon([(x * SS, y * SS) for x, y in VERTS], fill=FG + (255,))
    if ring:
        # 안쪽을 배경색으로 도려낸다. 투명 전경일 땐 알파까지 지워야 마스크 위에서
        # 바탕이 비친다 — 배경색으로 칠하면 어댑티브 배경과 겹쳐 테가 생긴다.
        inner = _scaled(VERTS, 1 - STROKE / (HEIGHT / 3))
        hole = (0, 0, 0, 0) if transparent else BG + (255,)
        d.polygon([(x * SS, y * SS) for x, y in inner], fill=hole)
    return img.resize((S, S), Image.LANCZOS)


for name, ring in (("solid", False), ("ring", True)):
    render(ring, False).convert("RGB").save(f"design/icon_light_{name}.png")
    render(ring, True).save(f"design/icon_light_{name}_fg.png")
    print(f"saved design/icon_light_{name}.png (+_fg)")
