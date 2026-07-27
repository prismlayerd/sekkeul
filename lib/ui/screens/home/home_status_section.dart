import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../../core/tax_engine/employee_tax.dart';
import '../../../core/tax_engine/reserve_estimator.dart';
import '../../components/amount_field.dart';
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
  final double creditCardYtdTotal;
  final double debitCashYtdTotal;

  /// 프리랜서 '올해 쌓인 예상 환급'. null이면 계산 근거가 없어 노출하지 않는다.
  final RefundProgress? refundProgress;

  /// N잡러 카드공제 절세액 — 종합 과세표준 기준(합산 엔진 산출).
  /// null이면 근로소득만 보는 estimateCreditCardRefund 값을 그대로 쓴다.
  final double? cardSavingCombined;

  final VoidCallback onOpenLedger;
  final VoidCallback onOpenMyInfo;

  final bool showExpenseInput;
  final TextEditingController expenseTargetInlineCtrl;
  final VoidCallback onRequestExpenseInput;
  final Future<void> Function(double value) onApplyExpenseInput;
  final VoidCallback onCancelExpenseInput;

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
    required this.creditCardYtdTotal,
    required this.debitCashYtdTotal,
    this.refundProgress,
    this.cardSavingCombined,
    required this.onOpenLedger,
    required this.onOpenMyInfo,
    required this.showExpenseInput,
    required this.expenseTargetInlineCtrl,
    required this.onRequestExpenseInput,
    required this.onApplyExpenseInput,
    required this.onCancelExpenseInput,
  });

  @override
  State<HomeStatusSection> createState() => _HomeStatusSectionState();
}

class _HomeStatusSectionState extends State<HomeStatusSection> {
  final _numberFormat = NumberFormat('#,###');

  // 프리랜서 헤드라인 탭-세전 보기 토글 / N잡러 "기타 수익" 칩 탭-세전 보기 토글 —
  // 이 패널 밖에서는 아무도 참조하지 않아 위젯 내부 상태로 둔다.
  bool _showGrossIncome = false;
  bool _showOtherIncomeGross = false;

  /// 원 단위 표기 ("36,000,000원")
  String _toWon(double won) {
    if (won <= 0) return '0원';
    return '${_numberFormat.format(won.toInt())}원';
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final now = DateTime.now();

    final monthlyIncome = widget.monthlyIncome;
    final grossIncome = widget.grossIncome;
    final isEmployee = widget.isEmployee;
    final userType = widget.userType;

    final budget = widget.expenseTarget;
    final totalSpent = widget.creditCardTotal + widget.debitCashTotal;
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
    final allSet = !needsSalary && !needsBudget && !widget.showExpenseInput;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더: 라벨 + 기록하기 ──
        Row(children: [
          _sectionLabel('${now.month}월 현황'),
          const Spacer(),
          GestureDetector(
            onTap: widget.onOpenLedger,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_right_rounded, size: 16, color: accent),
              Text('가계부', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // ── 수입 — 금액 위, 라벨 아래 (우측 정렬) ──
        // 프리랜서는 금액을 탭하면 세전 환산으로 페이드 전환(원천징수 역산 — 근로소득과 달리
        // 사업/기타소득은 고정 비율이라 정확히 역산 가능).
        // N잡러는 헤드라인이 근로소득만 반영해야 하므로(라벨과 실제 값이 어긋나면 안 됨),
        // income_entries 합산인 monthlyIncome 대신 laborIncome을 쓴다.
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: !isEmployee && monthlyIncome > 0
                    ? () => setState(() => _showGrossIncome = !_showGrossIncome)
                    : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: (userType == 'N잡러' ? widget.laborIncome : monthlyIncome) > 0
                      ? Text(
                          _toWon(!isEmployee && _showGrossIncome
                              ? widget.otherIncomeGrossEstimate
                              : (userType == 'N잡러' ? widget.laborIncome : monthlyIncome)),
                          key: ValueKey(_showGrossIncome),
                          style: AppTheme.serif(44, ink, spacing: -1.5, height: 1.0),
                        )
                      : Text('기록 없음',
                          key: const ValueKey('empty'),
                          style: AppTheme.serif(28, tert, spacing: -0.5, height: 1.0)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userType == 'N잡러'
                    ? '이번 달 근로소득 (세전)'
                    : isEmployee
                        ? '이번 달 수령액 (세전)'
                        : (_showGrossIncome ? '이번 달 수입 (세전 환산 · 탭해서 되돌리기)' : '이번 달 수입 (세후 · 탭해서 세전 보기)'),
                style: AppTheme.sans(12, tert),
              ),
            ],
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
                child: Text('내 정보에서 연봉을 설정하면 예상 환급을 계산해드려요'.keepWords,
                    style: AppTheme.sans(12, accent, weight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward, size: 14, color: accent),
            ]),
          ),
        ],

        const SizedBox(height: 14),

        // ── 지출 — 금액 위, 라벨 아래 (우측 정렬) ──
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_toWon(totalSpent),
                  style: AppTheme.serif(34, ink, weight: FontWeight.w700, spacing: -1.0, height: 1.0)),
              const SizedBox(height: 4),
              Text('이번 달 지출', style: AppTheme.sans(12, tert)),
            ],
          ),
        ),

        // ── 지출 목표 진행 + 수정 ──
        if (hasBudget && !widget.showExpenseInput) ...[
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
            onEdit: () {
              widget.expenseTargetInlineCtrl.text = _numberFormat.format(widget.expenseTarget.toInt());
              widget.onRequestExpenseInput();
            },
          ),
        ],
        // ── 2순위 유도: 지출 목표 — 연봉을 채운 뒤에만 뜬다.
        // (showExpenseInput은 기존 목표를 수정하려고 연 상태라 순서와 무관하게 유지)
        if ((!needsSalary && needsBudget) || widget.showExpenseInput) ...[
          const SizedBox(height: 12),
          _buildExpensePromptOrInput(ink, sub, accent),
        ],

        // ── 카드 공제 → 올해 쌓인 예상 환급 (직장인 전용, A/B/C 3단계) ──
        if (hasThreshold) ...[
          const SizedBox(height: 14),
          _buildCardRefundBlock(annualSalary, sub, tert, accent),
        ],

        // ── 올해 쌓인 예상 환급 (프리랜서) ──
        // 같은 자리·같은 말이지만 자라는 기전이 다르다 — 직장인은 신용카드 소득공제,
        // 프리랜서는 그 제도 대상이 아니라 필요경비 → 이미 뗀 3.3% 환급으로 자란다.
        // 자세한 내역(적은 경비·분기점)은 가계부 적립 카드에 있고 여기선 숫자만 보여준다.
        if (widget.refundProgress != null) ...[
          const SizedBox(height: 14),
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
                    style: AppTheme.sans(12, tert)),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: tert),
            ]),
          ),
        ],

      ],
    );
  }

  /// 지출 목표 프롬프트 → 탭 시 인라인 입력 전환 (높이 고정)
  Widget _buildExpensePromptOrInput(Color ink, Color sub, Color accent) {
    return _inlinePrompt(
      expanded: widget.showExpenseInput,
      promptText: widget.isEmployee
          ? '지출 목표를 설정하면 공제 기준을 잡아드려요'
          : '지출 목표를 설정하면 지출 현황을 알려드려요',
      hintText: '이번 달 지출 목표',
      controller: widget.expenseTargetInlineCtrl,
      ink: ink, sub: sub, accent: accent,
      onTapBanner: () {
        widget.expenseTargetInlineCtrl.text =
            widget.expenseTarget > 0 ? _numberFormat.format(widget.expenseTarget.toInt()) : '';
        widget.onRequestExpenseInput();
      },
      onApply: () async {
        final val = double.tryParse(widget.expenseTargetInlineCtrl.text.replaceAll(',', '')) ?? 0.0;
        if (val > 0) {
          await widget.onApplyExpenseInput(val);
        } else {
          widget.onCancelExpenseInput();
        }
      },
    );
  }

  /// 홈 인라인 프롬프트 공통 위젯 — 도면(에디토리얼) 스타일
  /// 안내 배너 ↔ 입력 행 페이드 전환, 양쪽 동일 높이로 스크롤 흔들림 방지
  Widget _inlinePrompt({
    required bool expanded,
    required String promptText,
    required String hintText,
    required TextEditingController controller,
    required VoidCallback onTapBanner,
    required Future<void> Function() onApply,
    required Color ink,
    required Color sub,
    required Color accent,
  }) {
    const h = 48.0;

    // ── 안내 배너: 표면색 + 헤어라인 + 좌측 도면 액센트 바 + 화살표 ──
    final banner = GestureDetector(
      onTap: onTapBanner,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border.all(color: AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Container(width: 3, height: h, color: accent),
          const SizedBox(width: 12),
          Expanded(child: Text(
            promptText,
            style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: accent, size: 15),
          const SizedBox(width: 14),
        ]),
      ),
    );

    // ── 입력 행: 헤어라인 필드 + 잉크 적용 버튼 ──
    final inputRow = SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              textAlign: TextAlign.right,
              autofocus: true,
              expands: true,
              maxLines: null,
              minLines: null,
              style: AppTheme.sans(14, ink, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.sans(14, AppTheme.inkTertiary(context)),
                suffixText: '원',
                suffixStyle: AppTheme.sans(13, sub),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: AppTheme.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: accent, width: 1.5)),
              ),
              onChanged: (v) {
                final n = v.replaceAll(RegExp(r'[^0-9]'), '');
                final f = n.isEmpty ? '' : _numberFormat.format(int.parse(n));
                controller.value = TextEditingValue(
                  text: f, selection: TextSelection.collapsed(offset: f.length));
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onApply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
              child: Text('적용', style: AppTheme.sans(14, AppTheme.backgroundColor(context), weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstCurve: Curves.easeIn,
      secondCurve: Curves.easeOut,
      firstChild: banner,
      secondChild: inputRow,
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
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: hasOther
                ? () => setState(() => _showOtherIncomeGross = !_showOtherIncomeGross)
                : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: hasOther
                  ? Text(
                      _toWon(_showOtherIncomeGross ? widget.otherIncomeGrossEstimate : widget.otherIncome),
                      key: ValueKey(_showOtherIncomeGross),
                      style: AppTheme.serif(44, ink, spacing: -1.5, height: 1.0),
                    )
                  : Text('기록 없음',
                      key: const ValueKey('empty'),
                      style: AppTheme.serif(28, tert, spacing: -0.5, height: 1.0)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            !hasOther
                ? '이번 달 다른소득'
                : _showOtherIncomeGross
                    ? '이번 달 다른소득 (세전 환산 · 탭해서 되돌리기)'
                    : '이번 달 다른소득 (세후 · 탭해서 세전 보기)',
            style: AppTheme.sans(12, tert),
          ),
        ],
      ),
    );
  }

  /// 카드 공제 → "올해 쌓인 예상 환급" 3단계 블록.
  /// A: 문턱 전(진행바) → B: 문턱~한도(환급 카운터 자람) → C: 한도 도달(멈춤 안내).
  /// 복잡한 세법(문턱 순서·공제율·한도)은 엔진(estimateCreditCardRefund)이 삼키고,
  /// 화면엔 숫자 1개 + 안내 1줄만 노출한다.
  Widget _buildCardRefundBlock(double annualSalary, Color sub, Color tert, Color accent) {
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
        '문턱을 넘으면 여기에 올해 예상 환급이 쌓이기 시작해요.',
      );
    }

    // B/C단계 — 환급 카운터(히어로). C는 한도 도달로 멈춤 안내.
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('올해 쌓인 예상 환급', style: AppTheme.sans(12, tert)),
          const SizedBox(height: 4),
          Text(_toWon(taxSaving),
              style: AppTheme.serif(34, accent, weight: FontWeight.w700, spacing: -1.0, height: 1.0)),
          const SizedBox(height: 6),
          Text(
            r.isCapped
                ? '올해 카드 소득공제 한도를 다 채웠어요 · 신용·체크·현금 모두 더 써도 공제는 안 늘어요'
                : '이제 체크카드·현금영수증으로 쓰면 공제율 2배(30%)예요 · 예상',
            style: AppTheme.sans(11, r.isCapped ? sub : tert),
            textAlign: TextAlign.right,
          ),
        ],
      ),
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

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('올해 쌓인 예상 환급', style: AppTheme.sans(12, tert)),
          const SizedBox(height: 4),
          Text(_toWon(p.refundGain),
              style: AppTheme.serif(34, accent,
                  weight: FontWeight.w700, spacing: -1.0, height: 1.0)),
          const SizedBox(height: 6),
          Text(
            p.isCapped
                // 사업 3.3%+기타 8.8% 원천징수를 합쳐 말해야 정확하다 — "3.3%"로 좁히지 않는다.
                ? '올해 원천징수된 세금을 다 돌려받는 상태예요 · 더 적어도 환급은 안 늘어요'
                : '경비를 더 찾을수록 늘어요 · 예상',
            style: AppTheme.sans(11, p.isCapped ? sub : tert),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  /// 진행 막대 블록 (라벨 + 값 + 1px 트랙 + 설명)
  Widget _progressBlock(String label, String value, double progress, Color color, String note, {VoidCallback? onEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w500)),
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
          ]),
          Text(value, style: AppTheme.sans(12, color, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: AppTheme.line(context),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(note, style: AppTheme.sans(12, color, weight: FontWeight.w500, height: 1.4)),
      ],
    );
  }

  /// 도면 주석 라벨 — 극소형 + 자간 극대 (섹션 머리표)
  Widget _sectionLabel(String text) =>
      Text(text.toUpperCase(), style: AppTheme.label(context));
}
