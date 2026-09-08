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

final _numbered = RegExp(r'^\d+\.\s');

BenefitLine _lineOf(String raw) {
  final s = raw.trim();
  if (s.startsWith('·')) return BenefitLine(BenefitLineKind.item, s.substring(1).trim());
  if (s.startsWith('※')) return BenefitLine(BenefitLineKind.note, s.substring(1).trim());
  if (s.startsWith('→')) return BenefitLine(BenefitLineKind.sub, s.substring(1).trim());
  if (_numbered.hasMatch(s)) return BenefitLine(BenefitLineKind.item, s);
  return BenefitLine(BenefitLineKind.prose, s);
}

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
        parsed.skip(1).any((l) => l.kind != BenefitLineKind.prose);

    out.add(BenefitSection(
      title: headed ? parsed.first.text : null,
      lines: headed ? parsed.sublist(1) : parsed,
    ));
  }
  return out;
}
