import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'forms_screen.dart';

import 'document_checklist_screen.dart';
import 'tax_record_import_screen.dart';
import 'correction_request_screen.dart';
import 'tax_simulator_screen.dart';
import 'missed_deduction_diagnosis_screen.dart';
import 'tax_annual_report_screen.dart';
import 'tax_report_form_screen.dart';
import 'pension_calculator_screen.dart';
import 'dependent_deduction_screen.dart';
import 'insurance_premium_screen.dart';
import 'financial_income_screen.dart';
import 'bookkeeping_guide_screen.dart';

/// 세무 도구 — 상단 4단계 신고 파이프라인(기록→진단→신고서→경정청구) +
/// 하단 빠르게 계산(단발 계산기). 구 "5월에 챙길 항목" 나열을 대체.
class TaxToolsScreen extends StatelessWidget {
  final String userType;

  /// 하단 탭에 끼워질 때(true)는 뒤로가기 leading을 숨긴다. push 진입 시 false.
  final bool embedded;
  const TaxToolsScreen({super.key, required this.userType, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text('세무 도구', style: AppTheme.serif(28, ink, spacing: -0.5)),
            const SizedBox(height: 10),
            Text(_pipelineIntroFor(userType), style: AppTheme.sans(14, sub, height: 1.55)),
            const SizedBox(height: 28),
            TaxToolsMenu(userType: userType),
          ],
        ),
      ),
    );
  }
}

/// 세무 도구 메뉴 본문 — 홈(리마인더 아래)과 '세무' 탭이 함께 쓰는 단일 위젯.
/// 기록 -> 종합소득세 신고 준비(3단계) -> 경정청구 -> 빠르게 계산(서랍).
class TaxToolsMenu extends StatefulWidget {
  final String userType;
  const TaxToolsMenu({super.key, required this.userType});

  @override
  State<TaxToolsMenu> createState() => _TaxToolsMenuState();
}

class _TaxToolsMenuState extends State<TaxToolsMenu> {
  String get userType => widget.userType;

  @override
  Widget build(BuildContext context) {
    final stages = taxPipelineFor(userType);
    final record = taxRecordEntryFor(userType);
    final amended = taxAmendedEntryFor(userType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record != null) ...[
          Text('기록'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 6),
          AppTheme.hairline(context),
          _menuRow(context, record),
          AppTheme.hairline(context),
          const SizedBox(height: 28),
        ],
        Text('종합소득세 신고 준비'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 14),
        for (int i = 0; i < stages.length; i++)
          _stageRow(context, i + 1, stages[i], isLast: i == stages.length - 1),
        if (amended != null) ...[
          const SizedBox(height: 28),
          Text('경정청구'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 6),
          AppTheme.hairline(context),
          _menuRow(context, amended),
          AppTheme.hairline(context),
        ],
        const SizedBox(height: 28),
        Text('서류 준비'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 6),
        AppTheme.hairline(context),
        _checklistRow(context),
        // 장부는 사업소득이 있는 유형만 — 직장인은 기장의무 자체가 없다.
        if (userType != '직장인') ...[
          AppTheme.hairline(context),
          _bookkeepingRow(context),
        ],
        AppTheme.hairline(context),
        const SizedBox(height: 28),
        Text('양식'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 6),
        AppTheme.hairline(context),
        _formsRow(context),
        AppTheme.hairline(context),
      ],
    );
  }

  Widget _stageRow(BuildContext context, int n, TaxStage stage, {required bool isLast}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.lineStrong(context);
    return IntrinsicHeight(
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => stage.build(userType))),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: line, width: 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('$n', style: AppTheme.serif(17, ink, spacing: 0, height: 1.0)),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: line)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(stage.title,
                          style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2))),
                      if (stage.badge != null) ...[
                        const SizedBox(width: 8),
                        AppTheme.blueprintBadge(context, stage.badge!),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Text(stage.subtitle, style: AppTheme.sans(13, sub, height: 1.45)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(Icons.chevron_right_rounded, color: tert, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, TaxStage stage) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => stage.build(userType))),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(stage.title, style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2))),
                if (stage.badge != null) ...[
                  const SizedBox(width: 8),
                  AppTheme.blueprintBadge(context, stage.badge!),
                ],
              ]),
              const SizedBox(height: 3),
              Text(stage.subtitle, style: AppTheme.sans(12, sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }

  Widget _formsRow(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => FormsScreen(userType: userType))),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('양식 ${allTaxForms.length}종', style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text('연말정산·종소세·경정청구 등 자주 쓰는 양식 모음',
                  style: AppTheme.sans(12, sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }

  Widget _checklistRow(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DocumentChecklistScreen(userType: userType))),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('서류 체크리스트',
                  style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text('홈택스 간소화에 없는 서류만 모아 보여줘요',
                  style: AppTheme.sans(12, sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }

  /// 장부 만들기 — 기장의무 판정 + 가계부 기록으로 간편장부(CSV) 생성.
  /// 무기장가산세(산출세액 20%)를 피하는 유일한 방법이라 서류 준비에 둔다.
  Widget _bookkeepingRow(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BookkeepingGuideScreen(userType: userType))),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('장부 만들기',
                  style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text('내 기장의무 확인 + 가계부 기록으로 간편장부 생성',
                  style: AppTheme.sans(12, sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }
}

// ── 데이터 모델 (홈과 공유) ──────────────────────────────────────────

/// 신고 파이프라인 단계.
class TaxStage {
  final String title;
  final String subtitle;
  final String? badge;
  final Widget Function(String userType) build;
  final String? railKey;    // 상단 파이프라인 레일에서 이 단계를 식별하는 키 (레일 대상 단계만)
  final String? railLabel;  // 레일용 짧은 라벨 (title은 길어서 별도)
  const TaxStage({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.build,
    this.railKey,
    this.railLabel,
  });
}

/// 유형별 파이프라인 레일 라벨 목록 — 메뉴(`taxPipelineFor`)와 단일 출처.
List<String> taxRailLabels(String userType) =>
    taxPipelineFor(userType).map((s) => s.railLabel ?? s.title).toList();

/// [railKey] 단계가 해당 유형 파이프라인에서 몇 번째인지(1-based). 없으면 1.
int taxRailIndex(String userType, String railKey) {
  final stages = taxPipelineFor(userType);
  for (int i = 0; i < stages.length; i++) {
    if (stages[i].railKey == railKey) return i + 1;
  }
  return 1;
}

/// 빠른 계산 항목 (단발 계산기).
class TaxItem {
  final String title;
  final String subtitle;
  final Widget Function(String userType) build;
  const TaxItem({required this.title, required this.subtitle, required this.build});
}

/// 홈 카드 라벨.
String taxToolsLabel() => '세무 도구';

String _pipelineIntroFor(String userType) => userType == '직장인'
    ? '연말정산 기록을 토대로 회사에 안 낸 공제를 5월에 직접 신고해 환급받는 흐름이에요. 진단 → 신고서 → 제출 가이드. 앱은 제출하지 않아요.'
    : userType == 'N잡러'
        ? '기록을 토대로 근로+사업을 합산해 신고를 준비해요. 진단 → 신고서 → 제출 가이드. 앱은 제출하지 않아요.'
        : '기록을 토대로 5월 종합소득세 신고를 준비해요. 진단 → 신고서 → 제출 가이드. 앱은 제출하지 않아요.';

/// 종합소득세 신고 준비 3단계 — 진단 → 신고서 → 가이드. (입력/기록은 별도 메뉴)
/// ②신고서는 아직 진단 전이면 빈 상태로 ①진단으로 안내한다.
List<TaxStage> taxPipelineFor(String userType) {
  if (userType == '직장인') {
    return const [
      TaxStage(title: '빠진 공제 항목 찾기', subtitle: '연말정산에 안 넣은 공제로 추가 환급 진단', build: _missedDiagnosis, railKey: 'missed', railLabel: '빠진공제'),
      TaxStage(title: '종합소득세 신고서', subtitle: '회사 안 거치고 직접 낼 서식 자동 작성', build: _emptyForm, railKey: 'form', railLabel: '신고서'),
      TaxStage(title: '홈택스 제출 가이드', subtitle: '5월 종합소득세를 어디에 어떻게 낼지 안내', badge: '5월 신고', build: _annualReport, railKey: 'annual', railLabel: '홈택스'),
    ];
  } else if (userType == 'N잡러') {
    return const [
      TaxStage(title: '빠진 공제 항목 찾기', subtitle: '연말정산에 안 넣은 공제로 추가 환급 진단', build: _missedDiagnosis, railKey: 'missed', railLabel: '빠진공제'),
      TaxStage(title: '합산 진단', subtitle: '합치면 세율이 얼마나 오르는지 계산', build: _simulator, railKey: 'simulator', railLabel: '합산진단'),
      TaxStage(title: '가상 신고서', subtitle: '합산 결과가 자동 채워진 신고서 미리보기', build: _emptyForm, railKey: 'form', railLabel: '신고서'),
      TaxStage(title: '홈택스 신고 가이드', subtitle: '합산 신고 항목을 1:1 안내', badge: '5월 신고', build: _annualReport, railKey: 'annual', railLabel: '홈택스'),
    ];
  } else {
    return const [
      TaxStage(title: '종소세 진단', subtitle: '경비율·공제를 반영해 세금을 계산', build: _simulator, railKey: 'simulator', railLabel: '진단'),
      TaxStage(title: '가상 신고서', subtitle: '진단 결과가 자동 채워진 신고서 미리보기', build: _emptyForm, railKey: 'form', railLabel: '신고서'),
      TaxStage(title: '홈택스 신고 가이드', subtitle: '어디에 무엇을 입력할지 1:1 안내', badge: '5월 신고', build: _annualReport, railKey: 'annual', railLabel: '홈택스'),
    ];
  }
}

/// 행1 — 연말정산 기록하기 (신고 준비의 입력 토대).
/// 직장인·N잡러는 둘 다 근로소득이 있어 회사에서 원천징수영수증을 받으므로
/// 동일하게 필요하다. 프리랜서는 근로소득이 없어 연말정산 대상이 아니라 제외.
TaxStage? taxRecordEntryFor(String userType) {
  if (userType == '프리랜서') return null;
  return const TaxStage(title: '연말정산 기록하기', subtitle: 'PDF 또는 직접 입력으로 이번 연말정산 결과 기록', build: _record);
}

/// 행3 — 경정청구 준비하기 (직장인·N잡러만; 프리랜서는 5월 신고가 본 신고라 제외).
TaxStage? taxAmendedEntryFor(String userType) {
  if (userType == '프리랜서') return null;
  return const TaxStage(title: '경정청구 준비하기', subtitle: '이전 연도에 놓친 공제를 5년 내 돌려받기', build: _amended);
}

/// 유형별 빠른 계산기 (평면, 무분류). 모두 기존 화면 재사용.
/// 항목은 소득 종류에 맞춰 분기한다:
/// - 간편장부·경비율: 사업소득이 있는 프리랜서·N잡러만 (직장인 제외).
/// - 보험료 세액공제: 보장성보험은 근로소득 특별세액공제라 근로분이 있는
///   직장인·N잡러만 (순수 사업소득자인 프리랜서 제외).
List<TaxItem> taxQuickCalcsFor(String userType) {
  const book = TaxItem(title: '간편장부·경비율', subtitle: '장부를 쓰면 경비 인정 폭이 넓어져요', build: _freelancerBook);
  const pension = TaxItem(title: '연금저축·IRP 세액공제', subtitle: '연금계좌 납입액으로 줄어드는 세금', build: _pension);
  const insurance = TaxItem(title: '보험료 세액공제', subtitle: '보장성보험 납입액 공제 (최대 27만원)', build: _insurance);
  const dependent = TaxItem(title: '부양가족·자녀 공제', subtitle: '기본·추가 인적공제와 자녀세액공제', build: _dependent);
  const financial = TaxItem(title: '금융소득 종합과세', subtitle: '이자·배당 2,000만원 초과 여부 판정', build: _financial);

  if (userType == '프리랜서') {
    // 사업소득만 → 간편장부 추가, 보장성보험 세액공제는 비대상이라 제외.
    return const [book, pension, dependent, financial];
  } else if (userType == 'N잡러') {
    // 근로+사업 → 간편장부(사업분)와 보험료(근로분) 모두 적절.
    return const [book, pension, insurance, dependent, financial];
  }
  // 직장인 — 사업소득 없음.
  return const [pension, insurance, dependent, financial];
}

// const 참조용 top-level 빌더.
// ① 기록(입력): 직장인만. 프리랜서·N잡러는 ①진단에 흡수됨.
Widget _record(String u) => TaxRecordImportScreen(userType: u);
Widget _simulator(String u) => TaxSimulatorScreen(userType: u);
Widget _missedDiagnosis(String u) => MissedDeductionDiagnosisScreen(userType: u);
Widget _amended(String u) => CorrectionRequestScreen(userType: u);
// ③ 가상 신고서: 저장된 ②진단 결과가 있으면 자동기입, 없으면 빈 상태로 안내.
Widget _emptyForm(String u) => ReportFormLoader(userType: u);
Widget _annualReport(String u) => TaxAnnualReportScreen(userType: u);
Widget _pension(String u) => const PensionCalculatorScreen();
Widget _dependent(String u) => const DependentDeductionScreen();
Widget _insurance(String u) => const InsurancePremiumScreen();
Widget _financial(String u) => const FinancialIncomeScreen();
// 과거엔 가계부를 그대로 열었는데, 제목이 약속하는 "간편장부"는 나오지 않았다.
// 기장의무 판정 + 가계부 기록으로 만든 장부(CSV)를 내주는 화면으로 연결한다.
Widget _freelancerBook(String u) => BookkeepingGuideScreen(userType: u);
