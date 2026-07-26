import 'simplified_data_parser.dart';

/// 근로소득 원천징수영수증([별지24], PDF 추출 텍스트) → 이미 신고된 값 파싱.
/// 간소화(공제 가능액)와 대조해 "빠진 공제"를 찾는 데 쓴다.
///
/// 구조(2025 귀속 실파일 기준): 번호 매겨진 정산명세.
/// - 총급여(16/21), 75 기납부세액(첫 숫자), 73 결정세액, 77 차감징수세액
/// - 공제대상금액: 62 의료비 · 63 교육비 · 70 월세액 · 61 보장성 · 60 연금저축
class WithholdingReceipt {
  /// 귀속연도(⑪ 근무기간의 시작연도). 못 읽으면 0 — 경정청구는 계산하지 않는다.
  final int accrualYear;
  final int grossSalary; // 총급여
  final int laborDeduction; // 근로소득공제
  final int taxableBase; // 종합소득 과세표준
  final int calculatedTax; // 산출세액
  final int paidTax; // 기납부세액(주현근무지, 소득세)
  final int decidedTax; // 결정세액(소득세)
  final int finalSettlement; // 차감징수세액(음수=환급)
  // 이미 신고된 공제대상금액
  final int claimedMedical;
  final int claimedEducation;
  final int claimedRent;
  final int claimedLifeInsurance;
  final int claimedPensionSavings;
  final int claimedDonation;

  const WithholdingReceipt({
    this.accrualYear = 0,
    this.grossSalary = 0,
    this.laborDeduction = 0,
    this.taxableBase = 0,
    this.calculatedTax = 0,
    this.paidTax = 0,
    this.decidedTax = 0,
    this.finalSettlement = 0,
    this.claimedMedical = 0,
    this.claimedEducation = 0,
    this.claimedRent = 0,
    this.claimedLifeInsurance = 0,
    this.claimedPensionSavings = 0,
    this.claimedDonation = 0,
  });

  bool get isRefund => finalSettlement < 0; // 차감징수 음수 = 환급
  int get settlementAbs => finalSettlement.abs();

  @override
  String toString() => 'WithholdingReceipt($accrualYear귀속, 총급여:$grossSalary, 기납부:$paidTax, 결정:$decidedTax, '
      '차감징수:$finalSettlement, 신고[의료:$claimedMedical, 교육:$claimedEducation, '
      '월세:$claimedRent, 보장성:$claimedLifeInsurance, 연금저축:$claimedPensionSavings])';
}

final _numRe = RegExp(r'-?\d{1,3}(?:,\d{3})+|-?\d+');
final _yearRe = RegExp(r'(19|20)\d{2}');

/// 귀속연도 = ⑪근무기간의 시작연도. 발급일(예: '2026년06월20일')이나 서식 개정
/// 이력 연도를 잘못 집지 않도록 근무기간 라인에서만 찾는다.
int _accrualYear(List<String> lines) {
  for (final ln in lines) {
    if (!_has(ln, '근무기간')) continue;
    final m = _yearRe.firstMatch(_sp(ln));
    if (m == null) continue;
    final y = int.parse(m.group(0)!);
    if (y >= 2000 && y <= 2100) return y;
  }
  return 0;
}

List<int> _nums(String line) =>
    _numRe.allMatches(line).map((m) => int.parse(m.group(0)!.replaceAll(',', ''))).toList();

/// 공백 제거(라벨 매칭용). Syncfusion layout은 '결정세액'처럼 공백이 없고
/// pypdf는 '결 정 세 액'처럼 띄움 — 둘 다 매칭되게 정규화.
String _sp(String s) => s.replaceAll(' ', '');
bool _has(String line, String label) => _sp(line).contains(_sp(label));

/// 라벨 라인의 최댓값(라벨에 필드번호 같은 잡숫자가 섞일 때).
int? _maxNumWith(List<String> lines, String label) {
  for (final ln in lines) {
    if (_has(ln, label)) {
      final n = _nums(ln);
      if (n.isNotEmpty) return n.reduce((a, b) => a > b ? a : b);
    }
  }
  return null;
}

/// 라벨 라인에서 절댓값이 가장 큰 숫자(부호 보존).
/// 세액 라인은 앞에 필드번호(75·73·77)·괄호식(73-74-75-76)이 섞여 실제 금액이 |최대|.
int? _absMaxNumWith(List<String> lines, String label) {
  for (final ln in lines) {
    if (_has(ln, label)) {
      final n = _nums(ln);
      if (n.isEmpty) continue;
      var best = n.first;
      for (final v in n) {
        if (v.abs() > best.abs()) best = v;
      }
      return best;
    }
  }
  return null;
}

/// 신고된 공제대상금액: 키워드 라인을 찾고, 그 라인~다음 2줄에서 '공제대상금액 N'.
/// (Syncfusion layout은 라벨과 '공제대상금액 N'이 다른 줄에 옴)
int? _claimedNear(List<String> lines, String keyword) {
  for (var i = 0; i < lines.length; i++) {
    if (!_has(lines[i], keyword)) continue;
    for (var j = i; j < lines.length && j <= i + 2; j++) {
      if (_has(lines[j], '공제대상금액')) {
        final n = _nums(lines[j]);
        if (n.isNotEmpty) return n.last;
      }
    }
  }
  return null;
}

WithholdingReceipt parseWithholdingText(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  return WithholdingReceipt(
    accrualYear: _accrualYear(lines),
    // ⑯ 계 라인의 최댓값 = 총급여 (라인에 '16' 같은 잡숫자가 섞임).
    grossSalary: _maxNumWith(lines, '16계') ?? 0,
    laborDeduction: _absMaxNumWith(lines, '근로소득공제') ?? 0,
    taxableBase: _absMaxNumWith(lines, '종합소득과세표준') ?? 0,
    calculatedTax: _absMaxNumWith(lines, '산출세액') ?? 0,
    paidTax: _absMaxNumWith(lines, '주(현)근무지') ?? 0,
    decidedTax: _absMaxNumWith(lines, '결정세액') ?? 0,
    finalSettlement: _absMaxNumWith(lines, '차감징수') ?? 0,
    claimedMedical: _claimedNear(lines, '의료비') ?? 0,
    claimedEducation: _claimedNear(lines, '교육비') ?? 0,
    claimedRent: _claimedNear(lines, '월세액') ?? 0,
    claimedLifeInsurance: _claimedNear(lines, '보장성') ?? 0,
    claimedPensionSavings: _claimedNear(lines, '연금저축') ?? 0,
    // 기부금 64 블록: 첫 공제대상금액(서브 합산 미반영 — v1 근사)
    claimedDonation: _claimedNear(lines, '기부금') ?? 0,
  );
}

// ── 빠진 공제 진단 ──────────────────────────────────────────────────

/// 간소화(가능) − 원천징수영수증(신고)을 대조해 찾은 누락 공제 1건.
class MissedDeduction {
  final String category;
  final int available; // 공제 가능액(한도·문턱 반영)
  final int claimed; // 이미 신고된 공제대상
  final int gap; // available - claimed (>0)
  final int estimatedRefund; // 대략 추가 환급 추정(세액공제율 적용)
  final String note;

  const MissedDeduction({
    required this.category,
    required this.available,
    required this.claimed,
    required this.gap,
    required this.estimatedRefund,
    required this.note,
  });
}

/// 두 파싱 결과를 대조해 누락 공제 목록을 만든다.
/// 한도·문턱(의료비 총급여 3%, 보장성 100만, 연금저축 600만)을 반영해
/// 거짓 양성을 줄인다. 정확한 환급액은 ②진단 엔진이 재계산.
List<MissedDeduction> diagnoseMissed(GansoDeductions g, WithholdingReceipt w) {
  final out = <MissedDeduction>[];
  final salary = w.grossSalary;

  // 의료비: 총급여 3% 초과분만 공제 대상
  final medicalThreshold = (salary * 0.03).round();
  final medicalDeductible = (g.medicalNet - medicalThreshold).clamp(0, 1 << 62);
  if (medicalDeductible > w.claimedMedical) {
    final gap = medicalDeductible - w.claimedMedical;
    out.add(MissedDeduction(
      category: '의료비',
      available: medicalDeductible,
      claimed: w.claimedMedical,
      gap: gap,
      estimatedRefund: (gap * 0.15).round(),
      note: '총급여 3%(${_won(medicalThreshold)}) 초과분 기준',
    ));
  }

  // 보장성보험: 한도 100만, 세액공제율 12%
  final lifeCapped = g.lifeInsurance > 1000000 ? 1000000 : g.lifeInsurance;
  if (lifeCapped > w.claimedLifeInsurance) {
    final gap = lifeCapped - w.claimedLifeInsurance;
    out.add(MissedDeduction(
      category: '보장성보험',
      available: lifeCapped,
      claimed: w.claimedLifeInsurance,
      gap: gap,
      estimatedRefund: (gap * 0.12).round(),
      note: '한도 100만원',
    ));
  }

  // 교육비: 세액공제율 15% (한도는 진단에서 정밀 계산)
  if (g.education > w.claimedEducation) {
    final gap = g.education - w.claimedEducation;
    out.add(MissedDeduction(
      category: '교육비',
      available: g.education,
      claimed: w.claimedEducation,
      gap: gap,
      estimatedRefund: (gap * 0.15).round(),
      note: '한도는 진단에서 정밀 계산',
    ));
  }

  // 기부금: 세액공제율 15% (1천만 초과분 30%는 진단에서)
  if (g.donation > w.claimedDonation) {
    final gap = g.donation - w.claimedDonation;
    out.add(MissedDeduction(
      category: '기부금',
      available: g.donation,
      claimed: w.claimedDonation,
      gap: gap,
      estimatedRefund: (gap * 0.15).round(),
      note: '1천만 초과분은 30% (진단에서)',
    ));
  }

  // 연금저축: 한도 600만, 세액공제율 ~15%
  final pensionCapped = g.pensionSavings > 6000000 ? 6000000 : g.pensionSavings;
  if (pensionCapped > w.claimedPensionSavings) {
    final gap = pensionCapped - w.claimedPensionSavings;
    out.add(MissedDeduction(
      category: '연금저축',
      available: pensionCapped,
      claimed: w.claimedPensionSavings,
      gap: gap,
      estimatedRefund: (gap * 0.15).round(),
      note: '한도 600만원',
    ));
  }

  // 월세: 세액공제율 ~15% (요건·한도는 진단에서)
  if (g.rent > w.claimedRent) {
    final gap = g.rent - w.claimedRent;
    out.add(MissedDeduction(
      category: '월세액',
      available: g.rent,
      claimed: w.claimedRent,
      gap: gap,
      estimatedRefund: (gap * 0.15).round(),
      note: '무주택·요건 충족 시 (진단에서 확인)',
    ));
  }

  return out;
}

String _won(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${b}원';
}
