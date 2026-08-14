"""카드뉴스 PNG 렌더 — mktg-copy가 쓴 문안 md를 1080×1350 장당 한 장으로 뽑는다.

레퍼런스는 Zachary Winterton, "Micrographics Variations".
고정: 종이·잉크·서체·타입 스케일.  변하는 것: 배치뿐.
그래서 **색과 폰트는 이 파일이 쥐고, 좌표는 md가 지시한다.**
매주 배치가 달라져도 색은 못 틀어진다.

폰트는 앱이 번들하는 것을 그대로 쓴다 — 스토어·SNS와 앱이 다른 서체를 쓰면
설치 직후 딴 앱처럼 보인다. 외부 디자인 도구를 안 쓰는 이유가 이것이다.

입력 md:

    # 파일 제목은 안 쓰인다 — 장 구분은 `---` 이다

    @ 0.30 0.44          ← 본문 덩어리 앵커(가로, 세로 비율). 생략하면 0.30 0.44
    나는 환급일까,        ← 첫 문단이 큰 글자 (줄바꿈 그대로 나간다)
    납부일까?
                         ← 빈 줄 하나가 큰 글자와 보조 문장을 가른다
    5월 종합소득세 신고

    % 0.72 0.34          ← 라벨 덩어리 앵커. 우측 정렬, 극소 대문자. 생략 가능
    ON_DEVICE
    NO_NETWORK
    ---
    ...

사용:
    python design/make_card_news.py <문안.md>
    python design/make_card_news.py --demo        # 자체 점검
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

# 윈도우 콘솔 기본이 cp949라 한글 파일명·메시지를 그냥 print하면 터진다.
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

W, H = 1080, 1350          # 인스타 4:5
SS = 2                     # 슈퍼샘플 — 블러 없이 가장자리를 매끈하게

BG = (0xF8, 0xF7, 0xF5)    # lightBackground
INK = (0x16, 0x15, 0x13)   # lightInk
SUB = (0x5E, 0x5C, 0x57)   # lightInkSecondary
ACCENT = (0x1F, 0x5A, 0xE0)  # lightAccent — 마지막 장에만

ROOT = Path(__file__).resolve().parent.parent
SERIF = str(ROOT / "assets/fonts/NotoSerifKR-Variable.ttf")
SANS = str(ROOT / "assets/fonts/DMSans-Variable.ttf")

MAX_CARDS = 7              # 루틴-주간.md §3: 5~7장
HEAD_PX = 46               # 레퍼런스는 작다. 여백이 주인공이고 글자는 손님이다
BODY_PX = 24
MICRO_PX = 15              # 라벨층 — 앱 테마의 11px/자간2.0 주석 라벨과 같은 장치
MICRO_TRACK = 2.6          # 자간(px, 1x 기준)
PAPER = 0.55               # 종이 세기. 눈으로 맞추는 값이니 손대도 된다 (0~1)

ANCHOR_HEAD = (0.30, 0.44)
ANCHOR_MICRO = (0.72, 0.34)


def parse(md: str) -> list[dict]:
    """`---` 로 나누고 각 장에서 앵커·큰 글자·보조·라벨을 뽑는다."""
    cards = []
    for chunk in re.split(r"^\s*---\s*$", md, flags=re.M):
        head_at, micro_at = ANCHOR_HEAD, ANCHOR_MICRO
        text, micro = [], []
        into_micro = False
        for raw in chunk.splitlines():
            ln = raw.strip()
            if re.match(r"^#\s", ln):          # 파일 제목은 장이 아니다
                continue
            m = re.match(r"^([@%])\s+([\d.]+)\s+([\d.]+)\s*$", ln)
            if m:
                at = (float(m.group(2)), float(m.group(3)))
                if m.group(1) == "@":
                    head_at, into_micro = at, False
                else:
                    micro_at, into_micro = at, True
                continue
            if ln == "%":                      # 좌표 없이 라벨층만 열 수도 있다
                into_micro = True
                continue
            (micro if into_micro else text).append(ln)

        # 빈 줄 하나가 큰 글자와 보조 문장을 가른다
        while text and not text[0]:
            text.pop(0)
        head, body = [], []
        for ln in text:
            if not ln and head:
                body = [x for x in text[len(head) + 1:] if x]
                break
            if ln:
                head.append(ln)
        micro = [x for x in micro if x]
        if not head and not micro:
            continue
        cards.append({"head": head, "body": body,
                      "micro": micro, "at": head_at, "micro_at": micro_at})
    return cards


def track(d, xy, text, font, fill, spacing, right=False):
    """자간 — Pillow에 없다. 글자 하나씩 그린다. 라벨층에만 쓴다."""
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths) + spacing * max(len(text) - 1, 0)
    x, y = xy
    if right:
        x -= total
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=fill)
        x += w + spacing
    return total


def _stretch(w, h, div, sigma, vertical):
    """노이즈를 한 축으로만 눌러 만든 뒤 늘리면 '가닥'이 된다.

    등방성 노이즈는 종이가 아니라 압축 아티팩트로 보인다. 종이는 펄프 섬유가
    교차한 것이므로 가로 가닥과 세로 가닥을 겹쳐야 종이가 된다.
    """
    size = (w, max(h // div, 1)) if vertical else (max(w // div, 1), h)
    return Image.effect_noise(size, sigma).resize((w, h), Image.BILINEAR)


def paper(img):
    """종이. Image.effect_noise가 Pillow 내장이라 새 의존성이 없다.

    글자를 다 그린 뒤 마지막에 덮는다 — 그래야 잉크에도 결이 스쳐서
    '인쇄된 것'으로 보인다. 글자를 갉아내지는 않는다(한글 받침이 뭉갠다).
    """
    w, h = img.size

    # 얼룩 — 큰 결부터 잔 결까지 겹친다. 한 겹만 쓰면 뭉게구름이 된다
    mottle = Image.new("L", (w, h), 128)
    for div, amt in ((24, 0.55), (11, 0.4), (5, 0.3)):
        n = Image.effect_noise((max(w // div, 1), max(h // div, 1)), 52)
        mottle = Image.blend(mottle, n.resize((w, h), Image.BICUBIC), amt)

    # 교차 섬유
    fiber = ImageChops.blend(_stretch(w, h, 9, 70, True),
                             _stretch(w, h, 9, 70, False), 0.5)

    # 결 — 흐리게 하지 않는다. 1px 그대로 있어야 '번짐'이 아니라 '거칠기'로 읽힌다
    tooth = Image.effect_noise((w, h), 26)
    # 티끌 — 진짜 종이에는 어두운 점이 드문드문 있다
    fleck = Image.effect_noise((w, h), 110).point(lambda v: 70 if v > 216 else 128)

    tex = ImageChops.blend(mottle, fiber, 0.5)
    tex = ImageChops.blend(tex, tooth, 0.45)
    tex = ImageChops.blend(tex, fleck, 0.3)

    # multiply 다. overlay 를 쓰면 안 된다 — 바탕이 #F8F7F5 라 거의 흰색이고,
    # overlay 는 밝은 바탕에서 screen 으로 동작해 '더 밝게'만 간다. 그래서 아무것도
    # 안 보였다. 섬유는 미세한 그림자이므로 어두워지는 쪽이어야 종이가 된다.
    lut = tex.point(lambda v: max(0, min(255, int(252 + (v - 128) * PAPER))))
    return ImageChops.multiply(img, lut.convert("RGB"))


def render(card: dict, idx: int, total: int) -> Image.Image:
    img = Image.new("RGB", (W * SS, H * SS), BG)
    d = ImageDraw.Draw(img)

    f_head = ImageFont.truetype(SERIF, HEAD_PX * SS)
    # ponytail: 보조도 serif다. 앱은 DM Sans + fontFamilyFallback으로 한글을 시스템
    # CJK에 넘기지만 Pillow에는 대체 장치가 없어 그대로 두부(□)가 된다. 번들 폰트 중
    # 한글이 있는 것은 NotoSerifKR뿐. 한글 sans를 번들하면 그때 SANS로 되돌린다.
    f_body = ImageFont.truetype(SERIF, BODY_PX * SS)
    f_micro = ImageFont.truetype(SANS, MICRO_PX * SS)   # 라틴 대문자·숫자뿐이라 안전

    # 본문 덩어리 — 앵커가 왼쪽 위 모서리다
    x = card["at"][0] * W * SS
    y = card["at"][1] * H * SS
    for ln in card["head"]:
        d.text((x, y), ln, font=f_head, fill=INK)
        y += HEAD_PX * 1.42 * SS
    if card["body"]:
        y += 26 * SS
        for ln in card["body"]:
            d.text((x, y), ln, font=f_body, fill=SUB)
            y += BODY_PX * 1.7 * SS

    # 라벨 덩어리 — 우측 정렬. 본문과 그리드를 공유하지 않는다(레퍼런스가 그렇다)
    mx = card["micro_at"][0] * W * SS
    my = card["micro_at"][1] * H * SS
    for ln in card["micro"]:
        track(d, (mx, my), ln.upper(), f_micro, SUB, MICRO_TRACK * SS, right=True)
        my += MICRO_PX * 1.6 * SS

    # 장 번호 — 레퍼런스의 `01 / 02` 자리. 마지막 장만 강조색
    track(d, (mx, my + 22 * SS), f"{idx:02d} / {total:02d}", f_micro,
          ACCENT if idx == total else SUB, MICRO_TRACK * SS, right=True)

    return paper(img.resize((W, H), Image.LANCZOS))


def build(md_path: Path, out_dir: Path) -> list[Path]:
    cards = parse(md_path.read_text(encoding="utf-8"))
    if not cards:
        raise SystemExit(f"장을 못 찾았다: {md_path} — `---` 로 나눴는지 확인해라")
    if len(cards) > MAX_CARDS:
        raise SystemExit(f"{len(cards)}장이다. 루틴이 정한 상한은 {MAX_CARDS}장이다")

    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for i, c in enumerate(cards, 1):
        p = out_dir / f"{md_path.stem}-{i:02d}.png"
        render(c, i, len(cards)).save(p)
        written.append(p)
    return written


def demo():
    """자체 점검 — 파서와 자간만 본다. 눈으로 볼 것은 눈으로 봐야 한다."""
    md = (
        "# 파일제목\n"
        "@ 0.25 0.40\n한 줄\n두 줄\n\n보조 문장\n"
        "% 0.70 0.30\non_device\n"
        "---\n"
        "그냥 큰 글자만\n"
    )
    cards = parse(md)
    assert len(cards) == 2, cards
    assert cards[0]["head"] == ["한 줄", "두 줄"], cards[0]
    assert cards[0]["body"] == ["보조 문장"], cards[0]
    assert cards[0]["micro"] == ["on_device"], cards[0]
    assert cards[0]["at"] == (0.25, 0.40) and cards[0]["micro_at"] == (0.70, 0.30)
    # 앵커를 안 쓴 장은 기본값을 받는다 — 배치가 비어도 그림은 나와야 한다
    assert cards[1]["at"] == ANCHOR_HEAD, cards[1]
    assert cards[1]["body"] == [] and cards[1]["micro"] == []
    assert parse("") == []

    d = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    f = ImageFont.truetype(SANS, 20)
    plain = d.textlength("ABCD", font=f)
    assert abs(track(d, (0, 0), "ABCD", f, SUB, 5) - (plain + 15)) < 0.01, "자간이 안 먹었다"
    assert track(d, (0, 0), "", f, SUB, 5) == 0, "빈 라벨에서 터지면 안 된다"

    # 종이는 눈으로 볼 것이지만, 세기를 잘못 만지면 바탕이 통째로 회색이 된다.
    # 그건 눈으로 보기 전에 잡는다.
    flat = Image.new("RGB", (240, 300), BG)
    out = paper(flat)
    assert out.size == flat.size
    lo, hi = out.convert("L").getextrema()
    assert hi - lo > 12, f"종이가 안 보인다: {lo}~{hi}"
    assert sum(out.convert("L").getdata()) / (240 * 300) > 210, "바탕이 너무 어두워졌다"

    print("demo ok — 파싱 2장, 앵커 기본값, 자간 3칸, 종이 대비")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] == "--demo":
        demo()
    else:
        src = Path(args[0])
        for p in build(src, src.parent / "카드뉴스"):
            print(f"saved {p}")
