/// **혜택 카드의 설명 한 덩어리를 화면이 배치할 수 있는 절로 쪼갠다.**
///
/// 카탈로그는 설명을 `desc` 문자열 하나로 들고 있다. 문자열은 배치가 안 된다 —
/// 제목을 키울 수도, 바뀐 줄만 강조할 수도, 사진을 끼울 수도 없어서 눌러도 글만 나왔다.
///
/// 손으로 53개를 구조화하지 않는 이유: 옮겨 적다가 내용을 잃는다. 형식은 이미
/// 일정하다(715줄 전수 확인) — 빈 줄이 절을 가르고, `·`와 `1.`이 항목, `※`가 각주,
/// `→`가 앞 항목에 딸린 곁줄이다.
///
/// 나중에 원격 데이터가 오면 이 파서 대신 그쪽이 같은 [BenefitSection]을 만든다.
/// 화면은 그대로 둔 채 공급원만 바뀐다.
library;

enum BenefitLineKind {
  /// 산문. 마커 없는 줄.
  prose,

  /// `·` 또는 `1.` 로 시작하는 항목.
  item,

  /// `※` 각주.
  note,

  /// `→` 로 시작하는, 바로 앞 항목의 곁줄.
  sub,
}

class BenefitLine {
  final BenefitLineKind kind;

  /// 마커를 뗀 본문. 번호 항목은 번호를 남긴다 — 순서가 뜻이라서.
  final String text;

  const BenefitLine(this.kind, this.text);

  /// 번호 항목이면 `(번호, 본문)`, 아니면 null.
  ///
  /// **`1.7억원`은 번호가 아니다.** 마침표 뒤에 공백이 있어야 번호로 본다.
  /// 판정을 화면 쪽에서 따로 하다가 재산 요건의 `· 1.7억원 미만`이
  /// `1.` + `7억원 미만`으로 쪼개져 화면에 **7억원**으로 나왔다. 규칙은 여기 하나뿐이다.
  (String, String)? get numbering {
    final m = _numbered.firstMatch(text);
    return m == null ? null : (m.group(1)!, text.substring(m.end));
  }
}

class BenefitSection {
  /// 절 제목. 항목이 따라붙지 않는 산문 덩어리에는 없다.
  final String? title;
  final List<BenefitLine> lines;

  const BenefitSection({this.title, required this.lines});

  /// 제목도 항목도 없는, 맨 앞의 산문 덩어리인가.
  /// 카드가 접혀 있을 때 보여줄 요약으로 쓴다.
  bool get isSummary => title == null && lines.every((l) => l.kind == BenefitLineKind.prose);
}

final _numbered = RegExp(r'^(\d+)\.\s');

BenefitLine _lineOf(String raw) {
  final s = raw.trim();
  if (s.startsWith('·')) return BenefitLine(BenefitLineKind.item, s.substring(1).trim());
  if (s.startsWith('※')) return BenefitLine(BenefitLineKind.note, s.substring(1).trim());
  if (s.startsWith('→')) return BenefitLine(BenefitLineKind.sub, s.substring(1).trim());
  if (_numbered.hasMatch(s)) return BenefitLine(BenefitLineKind.item, s);
  return BenefitLine(BenefitLineKind.prose, s);
}

/// 뒤가 전부 산문이어도 제목인 줄이 있다 — 「신청 방법」·「취급 은행」처럼
/// 항목 없이 설명만 딸린 절이 17개다(카탈로그 전수 확인).
///
/// 가르는 것은 **짧고 문장으로 안 끝난다**는 것뿐이다. 카드 맨 앞의 요약은
/// 길거나 `.`·`요`·`다`로 끝나서 여기 안 걸린다 — 걸리면 요약을 잃는다.
bool _looksLikeTitle(String s) =>
    s.length <= 20 && !s.endsWith('.') && !s.endsWith('요') && !s.endsWith('다');

/// [desc]를 절 목록으로 쪼갠다. 빈 줄 두 개가 절의 경계다.
///
/// 절의 첫 줄은 **뒤에 마커 붙은 줄이 따라올 때만** 제목이다. 그 규칙이 없으면
/// 산문 두 줄짜리 덩어리에서 첫 줄이 혼자 제목이 돼 버린다.
List<BenefitSection> parseBenefitDesc(String desc) {
  final out = <BenefitSection>[];
  for (final block in desc.split('\n\n')) {
    final raw = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (raw.isEmpty) continue;

    final parsed = raw.map(_lineOf).toList();
    final headed = parsed.first.kind == BenefitLineKind.prose &&
        parsed.length > 1 &&
        (parsed.skip(1).any((l) => l.kind != BenefitLineKind.prose) ||
            _looksLikeTitle(parsed.first.text));

    out.add(BenefitSection(
      title: headed ? parsed.first.text : null,
      lines: headed ? parsed.sublist(1) : parsed,
    ));
  }
  return out;
}
