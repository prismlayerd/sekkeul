import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../../core/tax_engine/tax_year.dart';
import '../../../core/tax_engine/employee_tax.dart';
import '../../../core/tax_engine/reserve_estimator.dart';
import '../../theme/text_wrap.dart';

/// 홈 "이번 달 현황" 패널 — 수입 + 지출 통합(에디토리얼: 카드 없이 선과 여백).
///
/// 예상 연봉은 "내 정보"(프로필)에서만 입력·수정한다 — 프로필 발견성 문제로
/// 홈 인라인 입력은 제거됨(2026-07-24). 지출 목표는 자주 바뀌는 이달 값이라
/// 계속 홈 인라인 입력(부모 HomeScreen이 컨트롤러 소유)을 유지한다.
/// "세전/세후 보기 토글"(_showGrossIncome류)은 이 패널 안에서만 쓰여
/// 위젯 내부 상태로 둔다.
class HomeStatusSection extends StatefulWidget {
  final String userType;
  final bool isEmployee;
  final double monthlyIncome; // 활성 소득 컨트롤러(급여/프리랜서 수입)에서 파싱된 값
  final double grossIncome;
  final int dependentCount;

  /// 자녀등 수 — 카드공제 기본한도 상향(조특법 §126의2⑩, 2025 개정).
  final int childrenCount;
  final double laborIncome;
  final double otherIncome;
  final double otherIncomeGrossEstimate;
  final double expenseTarget;
  final double creditCardTotal;
  final double debitCashTotal;

  /// 결제수단이 '기타'이거나 비어 있는 이번 달 지출. 카드공제 대상은 아니지만
  /// **쓴 돈은 쓴 돈이다** — 합계에 넣고 줄로도 보여준다.
  final double otherPayTotal;
  /// 가계부가 올 한 해를 덮는가. 안 덮으면 연간 누적 숫자를 내놓지 않는다.
  final bool yearCovered;
  final VoidCallback onFillPreviousMonths;

  final double creditCardYtdTotal;
  final double debitCashYtdTotal;

  /// 올해 지출 중 카드 공제 문턱에 **안 들어간** 금액.
  /// 결제수단이 '기타'이거나 비어 있는 기록이다(현금영수증 없는 지출로 본다).
  /// 이게 크면 사용자는 "지출은 쌓이는데 문턱이 안 줄어든다"고 느낀다 — 이유를 말해준다.
  final double excludedFromThresholdYtd;

  /// 프리랜서 '올해 쌓인 예상 환급'. null이면 계산 근거가 없어 노출하지 않는다.
  final RefundProgress? refundProgress;

  /// N잡러 카드공제 절세액 — 종합 과세표준 기준(합산 엔진 산출).
  /// null이면 근로소득만 보는 estimateCreditCardRefund 값을 그대로 쓴다.
  final double? cardSavingCombined;

  final VoidCallback onOpenLedger;
  final VoidCallback onOpenMyInfo;

  /// 지출 목표를 정하러 간다 — 가계부 분석 탭.
  ///
  /// 예전엔 홈에서 바로 적을 수 있었다. 그런데 가계부 분석 탭에도 같은 입력이
  /// 있어서 두 곳이 서로를 모르는 채로 같은 값을 고쳤다. 연봉이 「내 정보」
  /// 한 곳으로 간 것과 같은 이유로(2026-07-24) 여기도 한 곳으로 모은다 —
  /// 홈은 **얼마나 썼는지 보여주는 자리**지 설정하는 자리가 아니다.
  final VoidCallback onSetExpenseTarget;

  const HomeStatusSection({
    super.key,
    required this.userType,
    required this.isEmployee,
    required this.monthlyIncome,
    required this.grossIncome,
    required this.dependentCount,
    this.childrenCount = 0,
    required this.laborIncome,
    required this.otherIncome,
    required this.otherIncomeGrossEstimate,
    required this.expenseTarget,
    required this.creditCardTotal,
    required this.debitCashTotal,
    this.otherPayTotal = 0,
    required this.yearCovered,
    required this.onFillPreviousMonths,
    required this.creditCardYtdTotal,
    required this.debitCashYtdTotal,
    this.excludedFromThresholdYtd = 0.0,
    this.refundProgress,
    this.cardSavingCombined,
    required this.onOpenLedger,
    required this.onOpenMyInfo,
    required this.onSetExpenseTarget,
  });

  @override
  State<HomeStatusSection> createState() => _HomeStatusSectionState();
}

class _HomeStatusSectionState extends State<HomeStatusSection> {

  // 프리랜서 헤드라인 탭-세전 보기 토글 / N잡러 "기타 수익" 칩 탭-세전 보기 토글 —
  // 이 패널 밖에서는 아무도 참조하지 않아 위젯 내부 상태로 둔다.
  bool _showGrossIncome = false;
  bool _showOtherIncomeGross = false;

  /// 세전 환산이 세후와 **다른 숫자**가 되는가.
  ///
  /// 원천징수를 뗀 기록이 없으면 역산할 게 없어 두 값이 같다. 그때 "탭해서
  /// 세전 보기"라고 적으면 눌러도 안 바뀌는 것처럼 보인다.
  /// 역산되는 건 급여가 아닌 소득뿐이라, 차이는 그 둘 사이에서만 난다.
  ///
  /// 유형은 따지지 않는다 — 프리랜서의 수입 헤드라인과 N잡러의 다른소득
  /// 헤드라인이 같은 질문을 하고, 부르는 쪽이 이미 유형으로 갈라져 있다.
  /// (N잡러는 isEmployee가 참이라 여기서 유형을 보면 그쪽 탭이 죽는다.)
  bool get _grossDiffers =>
      widget.otherIncome > 0 &&
      (widget.otherIncomeGrossEstimate - widget.otherIncome).abs() >= 1;

  /// 헤드라인에 찍을 금액.
  ///
  /// 세전 환산은 **급여가 아닌 소득만** 역산한 값이다(근로소득은 간이세액표라
  /// 역산이 안 된다). 프리랜서가 '급여'로 적은 기록이 섞여 있으면 그 금액이
  /// 빠진 채로 "세전"이라 찍혀 세후보다 작아졌다 — 빠진 만큼 그대로 더한다.
  double get _headlineIncome {
    if (widget.userType == 'N잡러') return widget.laborIncome;
    if (!_showGrossIncome) return widget.monthlyIncome;
    final notReversible = widget.monthlyIncome - widget.otherIncome;
    return widget.otherIncomeGrossEstimate + notReversible;
  }

  /// 원 단위 표기 ("36,000,000원")
  String _toWon(double won) {
    if (won <= 0) return '0원';
    return '${comma(won.toInt())}원';
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    final monthlyIncome = widget.monthlyIncome;
    final grossIncome = widget.grossIncome;
    final isEmployee = widget.isEmployee;
    final userType = widget.userType;

    final budget = widget.expenseTarget;
    final totalSpent =
        widget.creditCardTotal + widget.debitCashTotal + widget.otherPayTotal;
    final hasBudget = budget > 0;
    final budgetProgress = hasBudget ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    // 표시용 비율은 100% 상한 없이 실제값(초과 시 100% 이상). 막대는 budgetProgress로 상한 유지.
    final budgetPercent = hasBudget ? (totalSpent / budget * 100) : 0.0;
    final overBudget = hasBudget && totalSpent > budget;
    final underBudget = hasBudget && totalSpent <= budget;

    // 카드공제 문턱은 "총급여액의 25%"(조특법 §126의2) — 총급여는 근로소득이다.
    // N잡러의 monthlyIncome은 근로+사업 합계라, 그대로 쓰면 사업소득이 문턱을
    // 밀어올려 카드공제를 과소 계산한다. 연봉 미설정 시엔 근로소득만 연환산한다.
    final annualSalary = grossIncome > 0
        ? grossIncome
        : (userType == 'N잡러' ? widget.laborIncome : monthlyIncome) * 12;
    // 신용카드 등 사용금액 소득공제는 근로소득자 전용 — 프리랜서(사업소득만 있는 경우)는 대상 아님.
    final hasThreshold = isEmployee && annualSalary > 0;

    // ── 유도는 한 번에 하나만 ──────────────────────────────────────
    // 빈 상태에서 유도 문구가 여럿 뜨면 서로 시선을 잡아먹어 아무것도 안 보인다
    // (테스터가 프로필 기능을 못 찾은 원인으로 의심됨, 2026-07-25).
    // 연봉 → 지출 목표 순서. 다 채우면 유도를 걷고 조용한 안내만 남긴다.
    final needsSalary = isEmployee && grossIncome <= 0;
    final needsBudget = !hasBudget;
    final allSet = !needsSalary && !needsBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 절 머리: `01 · INCOME · 이번 달 수입` + 가계부 열기 ──
        // 명세서는 순서가 있는 문서라 절에 번호가 붙는다.
        Row(children: [
          Expanded(child: AppTheme.sectionHead(context, '01', '이번 달 수입')),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onOpenLedger,
            child: Text('가계부 열기',
                style: AppTheme.sans(AppTheme.tsSM, accent,
                    weight: FontWeight.w700, decoration: TextDecoration.underline)),
          ),
        ]),
        const SizedBox(height: 10),

        // ── 수입 — 라벨 위, 금액 아래 (금액은 우측 정렬) ──
        // 항목 이름이 먼저 찍히고 금액이 그 밑 오른쪽 끝에 온다. 02 지출의 소계 줄과
        // 오른쪽 모서리가 맞아야 세 숫자를 세로로 훑어 비교할 수 있다.
        // 프리랜서는 금액을 탭하면 세전 환산으로 페이드 전환(원천징수 역산 — 근로소득과 달리
        // 사업/기타소득은 고정 비율이라 정확히 역산 가능).
        // N잡러는 헤드라인이 근로소득만 반영해야 하므로(라벨과 실제 값이 어긋나면 안 됨),
        // income_entries 합산인 monthlyIncome 대신 laborIncome을 쓴다.
        // 세전 환산은 **원천징수를 뗀 기록이 있을 때만** 뜻이 있다.
        //
        // 예전에는 기록이 하나도 없어도 "탭해서 세전 보기"라고 적어 뒀다.
        // 눌러도 아무 일이 없었고(onTap이 null), 원천징수를 안 뗀 기록만 있으면
        // 세전과 세후가 같은 숫자라 역시 아무 일이 없어 보였다.
        // 실제로 달라질 때만 그렇게 말한다.
        Text(
          userType == 'N잡러'
              ? '이번 달 근로소득 (세전)'
              : isEmployee
                  ? '이번 달 수령액 (세전)'
                  : !_grossDiffers
                      ? '이번 달 수입'
                      : (_showGrossIncome
                          ? '이번 달 수입 (세전 환산 · 탭해서 되돌리기)'
                          : '이번 달 수입 (세후 · 탭해서 세전 보기)'),
          style: AppTheme.sans(AppTheme.tsSM, sub),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _grossDiffers
              ? () => setState(() => _showGrossIncome = !_showGrossIncome)
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: (userType == 'N잡러' ? widget.laborIncome : monthlyIncome) > 0
                ? KeyedSubtree(
                    key: ValueKey(_showGrossIncome),
                    child: _rightAmount(comma(_headlineIncome)),
                  )
                : _rightEmpty(tert, const ValueKey('empty')),
          ),
        ),

        // ── N잡러: 다른소득 헤드라인 — 근로소득 헤드라인과 대등하게 항상 노출.
        // 기록이 없으면 근로소득과 똑같이 '기록 없음'으로 표시(별도 '나눠 기록' 버튼 대신
        // 두 소득 버킷을 대칭으로 보여 어느 쪽이든 기록하도록 유도).
        if (userType == 'N잡러') ...[
          const SizedBox(height: 20),
          _otherIncomeHeadline(),
        ],

        // ── 1순위 유도: 연봉 — 입력은 "내 정보"에서(발견성 문제로 홈 인라인 제거, 2026-07-24) ──
        if (needsSalary) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onOpenMyInfo,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Expanded(
                child: Text('연봉을 넣으면 예상 환급을 계산해드려요'.keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, accent, weight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward, size: 14, color: accent),
            ]),
          ),
        ],

        _rule(),

        // ── 지출 — 명세서의 소계 블록. 결제수단별로 한 줄씩 찍고 실선 위에 합계. ──
        AppTheme.sectionHead(context, '02', '이번 달 지출'),
        const SizedBox(height: 10),
        if (totalSpent > 0) ...[
          if (widget.creditCardTotal > 0)
            _leaderRow('신용카드', _toWon(widget.creditCardTotal), sub, ink),
          if (widget.debitCashTotal > 0)
            _leaderRow('체크·현금', _toWon(widget.debitCashTotal), sub, ink),
          if (widget.otherPayTotal > 0)
            _leaderRow('기타', _toWon(widget.otherPayTotal), sub, ink),
          const SizedBox(height: 6),
          Container(height: 1, color: ink),
          const SizedBox(height: 6),
          _leaderRow('합계', _toWon(totalSpent), ink, ink, emphasize: true),
        ] else
          // 수입 쪽이 '기록 없음'인데 지출만 '0원'이면, 같은 빈 상태를 두 가지 말로
          // 표현하게 된다. 아직 아무것도 안 적은 사람에게 '0원'은 "안 썼다"로 읽힌다.
          // 라벨은 바로 위 절 머리가 이미 '이번 달 지출'이라 했으니 반복하지 않는다.
          _rightEmpty(tert, null),

        // ── 지출 목표 진행 + 수정 ──
        if (hasBudget) ...[
          const SizedBox(height: 14),
          _progressBlock(
            '지출 목표 ${_toWon(budget)}',
            '${budgetPercent.toStringAsFixed(0)}%',
            budgetProgress,
            overBudget ? AppTheme.colorDanger : accent,
            overBudget
                ? '목표보다 ${_toWon(totalSpent - budget)} 더 썼어요. 남은 날 조금만 줄여봐요.'
                : underBudget && totalSpent > 0
                    ? '목표 대비 ${_toWon(budget - totalSpent)} 절약 중이에요.'
                    : '지출을 추가해보세요.',
            onEdit: widget.onSetExpenseTarget,
          ),
        ],
        // ── 지출 목표 유도 — 유형과 상관없이 처음부터 뜬다.
        // 예전엔 직장인·N잡러에게 "연봉을 채운 뒤에만" 보여줬는데, 프리랜서는
        // 연봉 단계가 없어 바로 떴다. 같은 기능이 유형에 따라 있고 없어 보였고,
        // 연봉 저장이 막히면 지출 목표를 영영 못 만드는 잠금이 됐다 (2026-08-10).
        // 대신 빈 상태에서 유도가 둘(연봉·지출 목표) 뜬다 — 그건 감수한다.
        if (needsBudget) ...[
          // 위 연봉 유도와 **같은 간격**. 둘은 같은 종류의 줄이라 하나만
          // 어긋나면 절이 삐뚤어 보인다.
          const SizedBox(height: 14),
          _expensePrompt(accent),
        ],

        // ── 카드 공제 → 올해 쌓인 예상 환급 (직장인 전용, A/B/C 3단계) ──
        if (hasThreshold) ...[
          _rule(),
          _buildCardRefundBlock(annualSalary, sub, tert, accent),
        ],

        // ── 올해 쌓인 예상 환급 (프리랜서) ──
        // 같은 자리·같은 말이지만 자라는 기전이 다르다 — 직장인은 신용카드 소득공제,
        // 프리랜서는 그 제도 대상이 아니라 필요경비 → 이미 뗀 3.3% 환급으로 자란다.
        // 자세한 내역(적은 경비·분기점)은 가계부 적립 카드에 있고 여기선 숫자만 보여준다.
        // 프리랜서의 「올해 쌓인 예상 환급」도 1월부터의 누적이다. 안 덮이면
                  // 카드 쪽과 똑같이 숫자 대신 채우라고 한다.
                  if (!widget.yearCovered)
                    _fillPromptBlock(sub, accent)
                  else if (widget.refundProgress != null) ...[
          _rule(),
          _buildFreelancerRefundBlock(widget.refundProgress!, sub, tert, accent),
        ],

        // ── 다 채운 뒤: 유도 대신 조용한 안내 ──
        // 요청(파란색)이 아니라 참조라서 accent가 아닌 tertiary로 둔다.
        if (allSet) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onOpenMyInfo,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Expanded(
                child: Text('바뀐 내용이 있으면 내 정보에서 수정하세요'.keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, tert)),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: tert),
            ]),
          ),
        ],

      ],
    );
  }

  /// 지출 목표 유도 — 누르면 가계부 분석 탭으로 간다.
  ///
  /// 예전엔 여기서 바로 적을 수 있었다(인라인 입력칸). 가계부 분석 탭에도
  /// 같은 입력이 있어서, 두 곳이 서로를 모르는 채로 같은 값을 고쳤다.
  /// 01의 '내 정보에서 연봉을…'과 같은 꼴 — 문장 한 줄과 화살표로 끝낸다.
  /// 위 연봉 유도와 **똑같이** 생겨야 한다 — 크기 12, 높이는 글자가 정한다.
  /// 인라인 입력칸 시절의 높이 48은 입력 행과 배너의 높이를 맞추려던 것인데,
  /// 입력칸이 사라진 뒤에도 남아서 아래 점선까지의 간격이 연봉 쪽보다 벌어졌다.
  Widget _expensePrompt(Color accent) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: widget.onSetExpenseTarget,
        behavior: HitTestBehavior.opaque,
        child: Row(children: [
          Expanded(
            // 지출 목표는 공제와 아무 상관이 없다 — 카드공제 문턱은 총급여의
            // 25%로 정해져 있다(조특법 §126의2). "공제 기준을 잡아드려요"는
            // 거짓말이었다.
            child: Text('이번 달 지출 목표액을 정하고 관리해봐요.'.keepWords,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(AppTheme.tsXS, accent, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 14, color: accent),
        ]),
      ),
    );
  }

  /// N잡러의 "다른소득" 헤드라인 — 근로소득 헤드라인과 대등한 크기로 보여준다(작은 칩이면
  /// 근로소득 숫자만 눈에 띄어 "이게 내 총수입"으로 오독할 위험이 있어 승격, 2026-07-12).
  /// 탭하면 세전 환산으로 페이드 전환(사업/기타소득만 원천징수 역산 가능,
  /// 근로소득은 간이세액표 기반이라 역산 불가라서 이 블록에만 붙인다).
  Widget _otherIncomeHeadline() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final hasOther = widget.otherIncome > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          !hasOther || !_grossDiffers
              ? '이번 달 다른소득'
              : _showOtherIncomeGross
                  ? '이번 달 다른소득 (세전 환산 · 탭해서 되돌리기)'
                  : '이번 달 다른소득 (세후 · 탭해서 세전 보기)',
          style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context)),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: hasOther && _grossDiffers
              ? () => setState(() => _showOtherIncomeGross = !_showOtherIncomeGross)
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: hasOther
                ? KeyedSubtree(
                    key: ValueKey(_showOtherIncomeGross),
                    // 근로소득보다 한 급 작게 — 대등하되 순서는 있다.
                    child: _rightAmount(
                      comma(_showOtherIncomeGross
                          ? widget.otherIncomeGrossEstimate
                          : widget.otherIncome),
                      size: AppTheme.serifLG,
                      color: ink,
                    ),
                  )
                : _rightEmpty(tert, const ValueKey('empty')),
          ),
        ),
      ],
    );
  }

  /// 1~지난달이 비어 있을 때 숫자 자리에 들어가는 안내.
  Widget _fillPromptBlock(Color sub, Color accent) {
    final last = DateTime.now().month - 1;
    return Semantics(
      button: true,
      label: '이전 달 채우기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onFillPreviousMonths,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isEmployee ? '카드 공제 문턱 (연봉의 25%)' : '올해 쌓인 예상 환급',
                style: AppTheme.sans(AppTheme.tsSM, sub)),
            const SizedBox(height: 8),
            Text('1~$last월 기록이 없어 아직 계산할 수 없어요'.keepWords,
                style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context),
                    weight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 4),
            Text('카드사 앱에서 보고 옮기면 2분이면 끝나요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5)),
            const SizedBox(height: 10),
            Text('1~$last월 채우기 →',
                style: AppTheme.sans(AppTheme.tsXS, accent,
                    weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 카드 공제 → "올해 쌓인 예상 환급" 3단계 블록.
  /// A: 문턱 전(진행바) → B: 문턱~한도(환급 카운터 자람) → C: 한도 도달(멈춤 안내).
  /// 복잡한 세법(문턱 순서·공제율·한도)은 엔진(estimateCreditCardRefund)이 삼키고,
  /// 화면엔 숫자 1개 + 안내 1줄만 노출한다.
  Widget _buildCardRefundBlock(double annualSalary, Color sub, Color tert, Color accent) {
    // **한 해를 안 덮으면 숫자를 내놓지 않는다.**
    //
    // 문턱도 예상 환급도 1월부터의 누적으로 계산된다. 연중에 깐 사람의 가계부에
    // 1~7월이 없으면 "아직 912만원 남았다"고 말하게 되는데, 실제로는 이미
    // 넘겼을 수도 있다. 틀린 숫자를 자신 있게 보여주느니 비워 두고 채우라고
    // 하는 편이 낫다 — 그래야 채울 이유도 생긴다.
    if (!widget.yearCovered) return _fillPromptBlock(sub, accent);

    final r = EmployeeTaxCalculator.estimateCreditCardRefund(
      grossAnnual: annualSalary,
      dependentsIncludingSelf: 1 + widget.dependentCount,
      childrenCount: widget.childrenCount,
      creditCardYtd: widget.creditCardYtdTotal,
      debitCashYtd: widget.debitCashYtdTotal,
    );

    // 문턱·공제액·한도는 총급여 기준이 맞다(조특법 §126의2). 절세액만 종합 과세표준
    // 기준이라, N잡러는 합산 엔진이 낸 값으로 갈아끼운다 — 근로소득만 보면 부업이
    // 세율 구간을 밀어올린 만큼 과소 추정된다.
    final taxSaving = widget.cardSavingCombined ?? r.taxSaving;

    // A단계 — 문턱 미달(또는 아직 세액 감소 없음): 기존 진행바 + 다음 보상 예고.
    if (r.totalEligibleSpend < r.threshold || taxSaving <= 0) {
      final remaining = (r.threshold - r.totalEligibleSpend).clamp(0.0, double.infinity);
      final progress = r.threshold > 0 ? (r.totalEligibleSpend / r.threshold).clamp(0.0, 1.0) : 0.0;
      // 문턱 판정은 신용+체크·현금 합계(조특법 §126의2) — '신용카드'로 좁혀 부르면
      // 체크카드 사용분이 진행바에 반영되는 이유를 설명할 수 없다.
      return _progressBlock(
        '카드 공제 문턱 (연봉의 25%)',
        '${_toWon(remaining)} 남음',
        progress,
        accent,
        widget.excludedFromThresholdYtd > 0
            ? '결제수단이 «기타»인 ${_toWon(widget.excludedFromThresholdYtd)}은 문턱에 안 들어가요 '
                '— 현금영수증 없는 지출은 공제 대상이 아니에요. 가계부에서 결제수단을 바꾸면 반영돼요.'
            : '문턱을 넘으면 여기에 올해 예상 환급이 쌓이기 시작해요.',
      );
    }

    // B/C단계 — 환급 카운터(히어로). C는 한도 도달로 멈춤 안내.
    return _refundBlock(
      taxSaving,
      accent,
      r.isCapped
          ? '올해 카드 소득공제 한도를 다 채웠어요 · 신용·체크·현금 모두 더 써도 공제는 안 늘어요'
          : '이제 체크카드·현금영수증으로 쓰면 공제율 2배(30%)예요 · 예상',
      r.isCapped ? sub : tert,
    );
  }

  /// `03 · ESTIMATED REFUND` 절 — 숫자 왼쪽, 추정 도장 오른쪽.
  /// 직장인·프리랜서 두 경로가 같은 자리에 같은 모양으로 찍혀야 한 문서로 읽힌다.
  Widget _refundBlock(double amount, Color accent, String note, Color noteColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTheme.sectionHead(context, null, '올해 쌓인 예상 환급'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: AppTheme.amount(context, comma(amount), color: accent)),
            const SizedBox(width: 10),
            AppTheme.stamp(context, 'EST.', '${TaxYear.reference}'),
          ],
        ),
        const SizedBox(height: 6),
        Text(note, style: AppTheme.sans(AppTheme.tsSM, noteColor, height: 1.45)),
      ],
    );
  }

  /// 프리랜서 "올해 쌓인 예상 환급" — 홈에선 숫자 1개 + 안내 1줄만.
  ///
  /// A(분기점 전)는 아직 환급이 안 자라는 구간이라 카운터 대신 남은 금액을 알린다.
  /// 과세 문턱 아래(어느 쪽으로 신고해도 세금 0)면 보여줄 환급이 없어 아예 감춘다.
  Widget _buildFreelancerRefundBlock(
      RefundProgress p, Color sub, Color tert, Color accent) {
    // 낼 세금이 없거나(과세 문턱 아래) 다 찾아봐야 실익이 미미하면 홈에선 아예 감춘다 —
    // 홈은 요약 자리라, 실익 없는 유도를 띄우면 다른 유도의 자리를 뺏는다.
    if (p.noTaxEitherWay || (!p.isAhead && !p.worthPursuing)) {
      return const SizedBox.shrink();
    }

    if (!p.isAhead) {
      return _progressBlock(
        '경비 기록',
        '${_toWon(p.shortfall)} 남음',
        p.breakevenExpense > 0
            ? (p.recordedExpense / p.breakevenExpense).clamp(0.0, 1.0)
            : 0.0,
        accent,
        // 상한을 같이 말해야 "그래봐야 얼마"를 사용자가 판단할 수 있다.
        '여기까지 찾아 적으면 예상 환급이 쌓이기 시작해요 (최대 ${_toWon(p.maxGain)}).',
      );
    }

    return _refundBlock(
      p.refundGain,
      accent,
      p.isCapped
          // 사업 3.3%+기타 8.8% 원천징수를 합쳐 말해야 정확하다 — "3.3%"로 좁히지 않는다.
          ? '올해 원천징수된 세금을 다 돌려받는 상태예요 · 더 적어도 환급은 안 늘어요'
          : '경비를 더 찾을수록 늘어요 · 예상',
      p.isCapped ? sub : tert,
    );
  }

  /// 진행 막대 블록 (라벨 + 값 + 1px 트랙 + 설명)
  Widget _progressBlock(String label, String value, double progress, Color color, String note, {VoidCallback? onEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨과 값이 한 줄에 다 안 들어가면 값이 아니라 **라벨**이 줄어야 한다 —
        // 숫자가 잘리면 화면이 거짓말을 한다. ('카드 공제 문턱 (연봉의 25%)' +
        // '12,500,000원 남음' 조합이 360~390px에서 60px 넘쳤다.)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkSecondary(context),
                        weight: FontWeight.w500))),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Icon(Icons.edit_outlined, size: 13, color: AppTheme.inkTertiary(context)),
                ),
              ),
            ],
          ])),
          const SizedBox(width: 8),
          Text(value, style: AppTheme.sans(AppTheme.tsXS, color, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        // 진행은 인쇄된 블록으로 찍는다 — 둥근 진행바는 이 종이 위에 없다.
        AppTheme.printedBar(context, progress, color: color),
        const SizedBox(height: 8),
        Text(note, style: AppTheme.sans(AppTheme.tsXS, color, weight: FontWeight.w500, height: 1.4)),
      ],
    );
  }

  /// 도면 주석 라벨 — 극소형 + 자간 극대 (섹션 머리표)
  /// 금액을 오른쪽 끝에 붙인다 — 절마다 숫자의 오른쪽 모서리가 맞아야 훑어 읽힌다.
  Widget _rightAmount(String digits, {double size = AppTheme.serifXL, Color? color}) =>
      Align(
        alignment: Alignment.centerRight,
        child: AppTheme.amount(context, digits, size: size, color: color),
      );

  /// 숫자가 들어올 자리의 빈 상태. 자리는 숫자와 같아야 한다.
  Widget _rightEmpty(Color color, Key? key) => Align(
        key: key,
        alignment: Alignment.centerRight,
        child: Text('기록 없음',
            style: AppTheme.display(AppTheme.serifLG, color, height: 1.0)),
      );

  /// 절을 가르는 점선. 홈 본문(_slipRule)과 같은 리듬이라 위아래 여백이 같다 —
  /// 패널 안팎에서 간격이 달라지면 한 장의 종이로 안 읽힌다.
  Widget _rule() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: AppTheme.dashRule(context),
      );

  /// 항목 … 금액 — 영수증의 기본 줄. 점선이 이름과 숫자를 잇는다.
  Widget _leaderRow(String label, String value, Color labelColor, Color valueColor,
      {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: AppTheme.sans(AppTheme.tsBase, labelColor,
                  weight: emphasize ? FontWeight.w700 : FontWeight.w400)),
          const SizedBox(width: 8),
          Expanded(
            // 점선을 **글자로** 찍는다.
            //
            // 예전에는 CustomPaint로 그렸는데, 기준선 정렬 Row에서 기준선이 없는
            // 자식은 맨 위에 붙는다(RenderFlex는 getDistanceToBaseline이 null이면
            // 0을 쓴다). 그래서 점선만 글자 위로 떠 있었다.
            //
            // 글자로 두면 기준선을 저절로 따라가고, 고정폭이라 점 간격이 라벨의
            // 글자 격자와도 맞는다. 넘치는 만큼은 잘라 낸다.
            child: ClipRect(
              child: Text(
                '·' * 120,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: AppTheme.sans(AppTheme.tsBase, AppTheme.lineStrong(context)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: AppTheme.sans(emphasize ? AppTheme.tsLG : AppTheme.tsBase, valueColor,
                  weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

