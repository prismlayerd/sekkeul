"""사용자 제공 아이콘 원본(icon_source.png.png, 572x480)을 앱 아이콘 규격
1024x1024 정사각형으로 변환. 구도(삼각형+오른쪽 글로우)는 그대로 두고
중앙 크롭 후 업스케일만 수행. 색/형태 변형 없음.
"""
from PIL import Image

src = Image.open("design/icon_source.png.png").convert("RGB")
w, h = src.size  # 572 x 480

# 짧은 변(높이) 기준 중앙 정사각형 크롭
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
sq = src.crop((left, top, left + side, top + side))

# 1024로 고품질 업스케일
icon = sq.resize((1024, 1024), Image.LANCZOS)
icon.save("design/icon_final.png")
print("saved design/icon_final.png", icon.size)
