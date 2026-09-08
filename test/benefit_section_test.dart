import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/benefit_section.dart';

/// 실제 카탈로그(benefit_screen.dart)에서 그대로 옮긴 근로·자녀장려금 설명.
/// 다섯 종류 줄이 전부 들어 있어 이 하나로 파서 전체가 걸린다.
const _eitc = '저소득 가구에 지급하는 환급형 세금 지원. 근로장려금과 자녀장려금 중복 수령 가능.\n\n'
    '근로장려금 지급 기준 (2025 귀속)\n'
    '· 단독 가구: 총소득 2,200만원 미만 → 최대 165만원\n'
    '· 맞벌이 가구: 총소득 4,400만원 미만 → 최대 330만원\n'
    '※ 단독=배우자·부양가족·70세 이상 부모 모두 없음\n\n'
    '홈택스 신청 5단계\n'
    '1. 홈택스 로그인 후 장려금 신청 메뉴 접속\n'
    '2. 인증번호 입력 또는 본인인증\n\n'
    '신청 방법\n'
    '홈택스(온라인) · 손택스(앱) · ARS 1544-9944 · 세무서 방문\n'
    '자영업자는 5월 종합소득세 신고와 동시 신청 가능';

void main() {
  test('절 경계는 빈 줄 두 개다', () {
    expect(parseBenefitDesc(_eitc).length, 4);
  });

  test('맨 앞 산문 덩어리는 제목이 없고 요약으로 쓴다', () {
    final first = parseBenefitDesc(_eitc).first;
    expect(first.title, isNull);
    expect(first.isSummary, isTrue);
    expect(first.lines.single.text, startsWith('저소득 가구에'));
  });

  test('마커 붙은 줄이 따라오면 첫 줄이 제목이 된다', () {
    final s = parseBenefitDesc(_eitc)[1];
    expect(s.title, '근로장려금 지급 기준 (2025 귀속)');
    expect(s.lines.length, 3);
    expect(s.lines[0].kind, BenefitLineKind.item);
    expect(s.lines[0].text, startsWith('단독 가구:')); // `·` 는 뗀다
    expect(s.lines[2].kind, BenefitLineKind.note);
    expect(s.lines[2].text, startsWith('단독=')); // `※` 도 뗀다
  });

  test('번호 항목은 번호를 남긴다 — 순서가 뜻이다', () {
    final s = parseBenefitDesc(_eitc)[2];
    expect(s.title, '홈택스 신청 5단계');
    expect(s.lines.first.kind, BenefitLineKind.item);
    expect(s.lines.first.text, '1. 홈택스 로그인 후 장려금 신청 메뉴 접속');
  });

  test('항목이 없어도 짧고 문장으로 안 끝나면 제목이다', () {
    // 「신청 방법」처럼 설명만 딸린 절이 카탈로그에 17개다. 마커가 따라오는지만
    // 보면 이것들이 통째로 산문이 돼 위계가 사라진다.
    final s = parseBenefitDesc(_eitc)[3];
    expect(s.title, '신청 방법');
    expect(s.lines.length, 2);
    expect(s.lines.every((l) => l.kind == BenefitLineKind.prose), isTrue);
  });

  test('요약은 제목으로 뺏기지 않는다 — 뺏기면 접힌 카드가 빈다', () {
    // 가르는 것은 길이와 끝맺음뿐이다. 요약은 길거나 `.`·`요`·`다`로 끝난다.
    for (final lead in [
      '저소득 가구에 지급하는 환급형 세금 지원. 근로장려금과 자녀장려금 중복 수령 가능.',
      '조건에 맞으면 받을 수 있어요',
      '가입 조건과 한도를 한눈에 봅니다',
    ]) {
      final s = parseBenefitDesc('$lead\n두 번째 줄').first;
      expect(s.title, isNull, reason: '요약을 제목으로 가져갔다: $lead');
      expect(s.isSummary, isTrue);
    }
  });


  test('→ 는 앞 항목의 곁줄이다', () {
    final s = parseBenefitDesc('한부모 공제\n· 연 100만원\n  → 부녀자 공제와 중복 불가').single;
    expect(s.title, '한부모 공제');
    expect(s.lines[1].kind, BenefitLineKind.sub);
    expect(s.lines[1].text, '부녀자 공제와 중복 불가');
  });

  test('빈 문자열과 빈 절은 조용히 넘어간다', () {
    expect(parseBenefitDesc(''), isEmpty);
    expect(parseBenefitDesc('\n\n\n\n').length, 0);
  });

  test('소수는 번호가 아니다 — 1.7억원이 1. + 7억원으로 쪼개지면 금액이 틀린다', () {
    final s = parseBenefitDesc(
        '재산 요건\n· 1.7억원 미만: 100% 지급\n· 2.4억원 이상: 지급 제외').single;
    expect(s.title, '재산 요건');
    expect(s.lines[0].numbering, isNull);
    expect(s.lines[0].text, '1.7억원 미만: 100% 지급');
    expect(s.lines[1].numbering, isNull);
  });

  test('번호 뒤에 공백이 있으면 번호로 떼어 낸다', () {
    final s = parseBenefitDesc('홈택스 신청\n1. 로그인\n2. 본인인증').single;
    expect(s.lines[0].numbering, ('1', '로그인'));
    expect(s.lines[1].numbering, ('2', '본인인증'));
  });
}
