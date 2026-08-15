"""켜지는 순간의 그림 — 안드로이드·iOS 스플래시 리소스를 만든다.

**민 종이 한 장.** 물결은 여기서 그리지 않는다 — 앱이 뜨자마자 이 종이가
물결선을 따라 갈라지면서(`lib/ui/components/splash_tear.dart`) 벌어진 틈이
물결이 된다. 정지 그림에 물결을 미리 찍어 두면 애니메이션 첫 프레임과
어긋나 물결이 두 개로 보인다.

**색은 아이콘과 반대로 간다.** 아이콘은 잉크 바탕 + 종이 물결이지만, 스플래시는
바로 뒤에 앱(종이)이 오므로 라이트에서 잉크 바탕을 깔면 켤 때마다 어두운 판이
한 번 지나간다. 지금 순백 스플래시가 번쩍이는 것과 같은 문제라, 스플래시는
앱과 같은 톤으로 둔다 — 라이트는 종이색, 다크는 먹지색.

    python design/make_splash.py
"""

import os

from PIL import Image


PAPER = (239, 239, 239)
DARK_BG = (30, 30, 30)

ANDROID = 'android/app/src/main/res'


def solid(rgb):
    return Image.new('RGB', (1, 1), rgb)


LAYERS = '''<?xml version="1.0" encoding="utf-8"?>
<!-- 켜지는 순간 — 민 종이 한 장. 물결은 앱이 뜨면서 뜯어 만든다. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <bitmap android:gravity="fill" android:src="@drawable/background"/>
    </item>
</layer-list>
'''


def main():
    for d, bg in [
        ('drawable', PAPER),
        ('drawable-v21', PAPER),
        ('drawable-night', DARK_BG),
        ('drawable-night-v21', DARK_BG),
    ]:
        out = os.path.join(ANDROID, d)
        os.makedirs(out, exist_ok=True)
        solid(bg).save(os.path.join(out, 'background.png'))
        stale = os.path.join(out, 'splash_wave.png')
        if os.path.exists(stale):
            os.remove(stale)
        with open(os.path.join(out, 'launch_background.xml'), 'w', encoding='utf-8') as f:
            f.write(LAYERS)
        print(out)

    # iOS — LaunchBackground(색) / LaunchImage(물결). 라이트 한 벌만 쓴다.
    ios_bg = 'ios/Runner/Assets.xcassets/LaunchBackground.imageset'
    ios_im = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    if os.path.isdir(ios_bg):
        for name in ('background.png', 'darkbackground.png'):
            p = os.path.join(ios_bg, name)
            if os.path.exists(p):
                solid(DARK_BG if 'dark' in name else PAPER).save(p)
                print(p)
    # iOS 런치 이미지도 비운다 — 물결은 앱이 그린다.
    if os.path.isdir(ios_im):
        for name in ('LaunchImage.png', 'LaunchImage@2x.png', 'LaunchImage@3x.png'):
            p = os.path.join(ios_im, name)
            if os.path.exists(p):
                Image.new('RGBA', (1, 1), (0, 0, 0, 0)).save(p)
                print(p)


if __name__ == '__main__':
    main()
