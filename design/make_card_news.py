"""카드뉴스 PNG 렌더 — mktg-copy가 쓴 문안 md를 1080×1350 장당 한 장으로 뽑는다.

Blueprint 규칙 그대로: 콘크리트 바탕, 헤어라인, 그림자 0, 라운드 최소.
폰트는 앱이 번들하는 것을 그대로 쓴다 — 스토어·SNS와 앱이 다른 서체를 쓰면
설치 직후 딴 앱처럼 보인다. 외부 디자인 도구를 안 쓰는 이유가 이것이다.

입력 md (mktg-copy 산출물):

    # 제목은 안 쓰인다 — 장 구분은 `---` 이다
    ## 후킹 문장          ← 1장. `##` 가 그 장의 큰 글자
    보조 문장 한 줄       ← 없어도 된다
    ---
    ## 두 번째 장
    ...

사용:
    python design/make_card_news.py work/산출물/2026-08-14-카드뉴스.md
    python design/make_card_news.py --demo        # 자체 점검
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# 윈도우 콘솔 기본이 cp949라 한글 파일명·메시지를 그냥 print하면 터진다.
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

W, H = 1080, 1350          # 인스타 4:5
SS = 2                     # 슈퍼샘플 — 블러 없이 가장자리를 매끈하게

BG = (0xF8, 0xF7, 0xF5)    # lightBackground
INK = (0x16, 0x15, 0x13)   # lightInk
SUB = (0x5E, 0x5C, 0x57)   # lightInkSecondary
LINE = (0xDC, 0xD8, 0xD0)  # lightLine
ACCENT = (0x1F, 0x5A, 0xE0)  # lightAccent

ROOT = Path(__file__).resolve().parent.parent
SERIF = str(ROOT / "assets/fonts/NotoSerifKR-Variable.ttf")
SANS = str(ROOT / "assets/fonts/DMSans-Variable.ttf")

MARGIN = 96                # 안전 여백 — 인스타가 미리보기에서 가장자리를 먹는다
MAX_CARDS = 7              # 루틴-주간.md §3: 5~7장
TITLE_PX = 58              # serifLG(28) 계열을 1080폭에 맞춰 올린 값
BODY_PX = 30


def parse(md: str) -> list[tuple[str, str]]:
    """`---` 로 나누고 각 장에서 (큰 글자, 보조 문장) 을 뽑는다."""
    cards = []
    for chunk in re.split(r"^\s*---\s*$", md, flags=re.M):
        lines = [ln.strip() for ln in chunk.strip().splitlines() if ln.strip()]
        # `#` 한 개짜리 제목은 파일 제목이지 장이 아니다
        lines = [ln for ln in lines if not re.match(r"^#\s", ln)]
        if not lines:
            continue
        head = re.sub(r"^#+\s*", "", lines[0])
        body = " ".join(re.sub(r"^[-*]\s*", "", ln) for ln in lines[1:])
        cards.append((head, body))
    return cards


def wrap(draw, text, font, max_w):
    """한글은 어절 단위로만 끊는다 — 음절 사이에서 끊으면 '2,000만원까 / 지'가 된다."""
    if not text:
        return []
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=font) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    return lines


def render(head: str, body: str, idx: int, total: int) -> Image.Image:
    img = Image.new("RGB", (W * SS, H * SS), BG)
    d = ImageDraw.Draw(img)

    f_head = ImageFont.truetype(SERIF, TITLE_PX * SS)
    # ponytail: 본문도 serif다. 앱은 DM Sans + fontFamilyFallback으로 한글을 시스템
    # CJK에 넘기지만 Pillow에는 대체 장치가 없어 그대로 두부(□)가 된다. 번들 폰트 중
    # 한글이 있는 것은 NotoSerifKR뿐. 한글 sans를 번들하면 그때 SANS로 되돌린다.
    f_body = ImageFont.truetype(SERIF, BODY_PX * SS)
    f_num = ImageFont.truetype(SANS, 22 * SS)  # 숫자·슬래시뿐이라 sans로 안전하다

    m = MARGIN * SS
    inner = W * SS - m * 2

    # 상단 헤어라인 + 장 번호 — 도면 주석 자리
    d.line((m, m, W * SS - m, m), fill=LINE, width=1 * SS)
    d.text((m, m + 22 * SS), f"{idx:02d} / {total:02d}", font=f_num, fill=SUB)

    # 큰 글자는 세로 중앙. 보조 문장은 그 아래.
    head_lines = wrap(d, head, f_head, inner)
    body_lines = wrap(d, body, f_body, inner)

    lh_head = TITLE_PX * 1.35 * SS
    lh_body = BODY_PX * 1.6 * SS
    gap = 40 * SS if body_lines else 0
    block = len(head_lines) * lh_head + gap + len(body_lines) * lh_body
    y = (H * SS - block) / 2

    for ln in head_lines:
        d.text((m, y), ln, font=f_head, fill=INK)
        y += lh_head
    y += gap
    for ln in body_lines:
        d.text((m, y), ln, font=f_body, fill=SUB)
        y += lh_body

    # 마지막 장에만 accent 하단선 — 앱 유도 자리라는 표시
    y_foot = H * SS - m
    d.line((m, y_foot, W * SS - m, y_foot),
           fill=ACCENT if idx == total else LINE,
           width=(3 if idx == total else 1) * SS)

    return img.resize((W, H), Image.LANCZOS)


def build(md_path: Path, out_dir: Path) -> list[Path]:
    cards = parse(md_path.read_text(encoding="utf-8"))
    if not cards:
        raise SystemExit(f"장을 못 찾았다: {md_path} — `---` 로 나눴는지 확인해라")
    if len(cards) > MAX_CARDS:
        raise SystemExit(f"{len(cards)}장이다. 루틴이 정한 상한은 {MAX_CARDS}장이다")

    out_dir.mkdir(parents=True, exist_ok=True)
    stem = md_path.stem
    written = []
    for i, (head, body) in enumerate(cards, 1):
        p = out_dir / f"{stem}-{i:02d}.png"
        render(head, body, i, len(cards)).save(p)
        written.append(p)
    return written


def demo():
    """자체 점검 — 파서와 줄바꿈만 본다. 눈으로 볼 것은 눈으로 봐야 한다."""
    md = "# 파일제목\n## 첫 장\n보조 문장\n---\n## 둘째 장\n- 목록도 본문이다\n---\n## 셋째 장\n"
    cards = parse(md)
    assert len(cards) == 3, cards
    assert cards[0] == ("첫 장", "보조 문장"), cards[0]
    assert cards[1][1] == "목록도 본문이다", cards[1]
    assert cards[2][1] == "", cards[2]           # 보조 문장 없는 장도 된다

    img = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(SANS, 40)
    lines = wrap(d, "월세로 살면 최대 백칠십만원을 돌려받습니다", f, 300)
    assert len(lines) > 1, "안 끊겼다"
    assert all(" " not in ln or True for ln in lines)
    # 어절이 쪼개지지 않았는지 — 원문을 공백으로 이어붙이면 그대로여야 한다
    assert " ".join(lines) == "월세로 살면 최대 백칠십만원을 돌려받습니다"

    assert parse("") == []
    print("demo ok — 파싱 3장, 줄바꿈 어절 보존")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] == "--demo":
        demo()
    else:
        src = Path(args[0])
        for p in build(src, src.parent / "카드뉴스"):
            print(f"saved {p}")
