import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../../core/tax_engine/employee_tax.dart';

/// 홈 "이번 달 현황" 패널 — 수입 + 지출 통합(에디토리얼: 카드 없이 선과 여백).
///
/// 예상 연봉·지출 목표 자체(그리고 인라인 입력 컨트롤러)는 홈 화면 다른 곳
/// (배너 카드의 "연봉 설정하기" 유도, 프로필 로드)에서도 참조되는 공유 상태라
/// 그대로 부모(HomeScreen)가 소유하고, 이 위젯은 그 값들을 전달받아 그린다.
/// 반면 "세전/세후 보기 토글"(_showGrossIncome류)은 이 패널 안에서만 쓰여
/// 위젯 내부 상태로 둔다.
class HomeStatusSection extends StatefulWidget {
  final String userType;
  final bool isEmployee;
  final double monthlyIncome; // 활성 소득 컨트롤러(급여/프리랜서 수입)에서 파싱된 값
  final double grossIncome;
  final int dependentCount;
  final double laborIncome;
  final double otherIncome;
  final double otherIncomeGrossEstimate;
  final double expenseTarget;
  final double creditCardTotal;
  final double debitCashTotal;
  final double creditCardYtdTotal;

  final VoidCallback onOpenLedger;

  final bool showSalaryInput;
  final TextEditingController grossIncomeInlineCtrl;
  final VoidCallback onRequestSalaryInput;
  final Future<void> Function(double value) onApplySalaryInput;
  final VoidCallback onCancelSalaryInput;

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
    required this.laborIncome,
    required this.otherIncome,
    required this.otherIncomeGrossEstimate,
    required this.expenseTarget,
    required this.creditCardTotal,
    required this.debitCashTotal,
    required this.creditCardYtdTotal,
    required this.onOpenLedger,
    required this.showSalaryInput,
    required this.grossIncomeInlineCtrl,
    required this.onRequestSalaryInput,
    required this.onApplySalaryInput,
    required this.onCancelSalaryInput,
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

    final double baseMonthly = grossIncome > 0 ? grossIncome / 12 : monthlyIncome;
    InsuranceBreakdown? insurance;
    double monthlyIncomeTax = 0.0;
    if (isEmployee && baseMonthly > 0) {
      insurance = EmployeeTaxCalculator.calculateMonthlyInsurance(baseMonthly);
      // 세후 = 4대보험 + 소득세(간이세액 추정) 차감. 부양가족 수 반영.
      monthlyIncomeTax = EmployeeTaxCalculator.estimateMonthlyIncomeTax(
        grossAnnual: baseMonthly * 12,
        dependentsIncludingSelf: 1 + widget.dependentCount,
      );
    }
    final double? netEstimate =
        insurance != null ? baseMonthly - insurance.total - monthlyIncomeTax : null;

    final budget = widget.expenseTarget;
    final totalSpent = widget.creditCardTotal + widget.debitCashTotal;
    final hasBudget = budget > 0;
    final budgetProgress = hasBudget ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasBudget && totalSpent > budget;
    final underBudget = hasBudget && totalSpent <= budget;

    final annualSalary = grossIncome > 0 ? grossIncome : monthlyIncome * 12;
    final deductionThreshold = annualSalary * 0.25;
    // 신용카드 등 사용금액 소득공제는 근로소득자 전용 — 프리랜서(사업소득만 있는 경우)는 대상 아님.
    final hasThreshold = isEmployee && annualSalary > 0;
    final thresholdProgress = hasThreshold ? (widget.creditCardYtdTotal / deductionThreshold).clamp(0.0, 1.0) : 0.0;
    final overThreshold = hasThreshold && widget.creditCardYtdTotal >= deductionThreshold;
    final monthlyCardPace = deductionThreshold / 12 * now.month;
    final onPace = widget.creditCardYtdTotal >= monthlyCardPace;

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

        // ── N잡러: 다른소득 — 근로소득 헤드라인과 대등한 크기의 별도 헤드라인으로
        // 보여준다(작은 칩이면 근로소득 숫자만 눈에 띄어 총수입으로 오독할 위험).
        if (userType == 'N잡러' && widget.otherIncome > 0) ...[
          const SizedBox(height: 20),
          _otherIncomeHeadline(),
        ]
        // N잡러인데 분리 기록이 없으면 나눠 기록 동선만 노출.
        else if (userType == 'N잡러' && monthlyIncome > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: widget.onOpenLedger,
              behavior: HitTestBehavior.opaque,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call_split_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Text('근로·기타로 나눠 기록하기', style: AppTheme.sans(12, accent, weight: FontWeight.w600)),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // ── 예상 연봉 / 실수령 정보 or 프롬프트 ──
        if (grossIncome > 0 && netEstimate != null && !widget.showSalaryInput) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('예상 연봉(세전)', style: AppTheme.sans(13, sub)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  widget.grossIncomeInlineCtrl.text = _numberFormat.format(grossIncome.toInt());
                  widget.onRequestSalaryInput();
                },
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.edit_outlined, size: 14, color: sub),
              ),
            ]),
            Text(_toWon(grossIncome), style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 7),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('예상 연봉(세후)', style: AppTheme.sans(13, sub)),
              const SizedBox(width: 6),
              Text('4대보험·소득세 반영', style: AppTheme.sans(11, tert)),
            ]),
            Text('약 ${_toWon(netEstimate * 12)}', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
        ] else if (isEmployee) ...[
          _buildSalaryPromptOrInput(ink, sub, accent),
          const SizedBox(height: 14),
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
        if (totalSpent > 0) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _spendChip('신용카드', widget.creditCardTotal),
            const SizedBox(width: 8),
            _spendChip('체크·현금', widget.debitCashTotal),
          ]),
        ],

        // ── 지출 목표 진행 + 수정 ──
        if (hasBudget && !widget.showExpenseInput) ...[
          const SizedBox(height: 14),
          _progressBlock(
            '지출 목표 ${_toWon(budget)}',
            '${(budgetProgress * 100).toStringAsFixed(0)}%',
            budgetProgress,
            overBudget ? AppTheme.colorDanger : accent,
            overBudget
                ? '이번 달 지출이 목표를 넘었어요. 남은 날 조금만 줄여봐요.'
                : underBudget && totalSpent > 0
                    ? '목표 대비 ${_toWon(budget - totalSpent)} 절약 중이에요.'
                    : '지출을 추가해보세요.',
            onEdit: () {
              widget.expenseTargetInlineCtrl.text = _numberFormat.format(widget.expenseTarget.toInt());
              widget.onRequestExpenseInput();
            },
          ),
        ],
        // ── 지출 목표 설정 프롬프트 (목표 없음) 또는 인라인 수정 ──
        if (!hasBudget || widget.showExpenseInput) ...[
          const SizedBox(height: 12),
          _buildExpensePromptOrInput(ink, sub, accent),
        ],

        // ── 신용카드 공제 문턱 ──
        if (hasThreshold) ...[
          const SizedBox(height: 14),
          _progressBlock(
            '신용카드 공제 문턱 (연봉의 25%)',
            overThreshold ? '돌파' : '${_toWon(deductionThreshold - widget.creditCardYtdTotal)} 남음',
            thresholdProgress,
            overThreshold ? AppTheme.colorSuccess : accent,
            overThreshold
                ? '지금부터는 체크·현금이 공제율 2배(30%)예요.'
                : onPace
                    ? '월 권장 페이스(${_toWon(monthlyCardPace)}) 이상 쓰고 있어요. 연내 문턱 도달 가능.'
                    : '월 ${_toWon(monthlyCardPace)}씩 쓰면 연내 문턱을 넘겨요.',
          ),
        ],

      ],
    );
  }

  /// 예상 연봉 프롬프트 → 탭 시 인라인 입력 전환 (높이 고정)
  Widget _buildSalaryPromptOrInput(Color ink, Color sub, Color accent) {
    return _inlinePrompt(
      expanded: widget.showSalaryInput,
      promptText: '예상 연봉을 설정하면 절세 기준을 잡아드려요',
      hintText: '예상 연봉 입력',
      controller: widget.grossIncomeInlineCtrl,
      ink: ink, sub: sub, accent: accent,
      onTapBanner: () {
        widget.grossIncomeInlineCtrl.text =
            widget.grossIncome > 0 ? _numberFormat.format(widget.grossIncome.toInt()) : '';
        widget.onRequestSalaryInput();
      },
      onApply: () async {
        final val = double.tryParse(widget.grossIncomeInlineCtrl.text.replaceAll(',', '')) ?? 0.0;
        if (val > 0) {
          await widget.onApplySalaryInput(val);
        } else {
          widget.onCancelSalaryInput();
        }
      },
    );
  }

  /// 지출 목표 프롬프트 → 탭 시 인라인 입력 전환 (높이 고정)
  Widget _buildExpensePromptOrInput(Color ink, Color sub, Color accent) {
    return _inlinePrompt(
      expanded: widget.showExpenseInput,
      promptText: widget.isEmployee
          ? '이번 달 지출 목표액을 설정하면 공제 기준을 잡아드려요'
          : '이번 달 지출 목표액을 설정하면 지출 현황을 알려드려요',
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
            maxLines: 1,
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

  Widget _spendChip(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text('$label ${_toWon(amount)}', style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w500)),
    );
  }

  /// N잡러의 "다른소득" 헤드라인 — 근로소득 헤드라인과 대등한 크기로 보여준다(작은 칩이면
  /// 근로소득 숫자만 눈에 띄어 "이게 내 총수입"으로 오독할 위험이 있어 승격, 2026-07-12).
  /// 탭하면 세전 환산으로 페이드 전환(사업/기타소득만 원천징수 역산 가능,
  /// 근로소득은 간이세액표 기반이라 역산 불가라서 이 블록에만 붙인다).
  Widget _otherIncomeHeadline() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showOtherIncomeGross = !_showOtherIncomeGross),
            behavior: HitTestBehavior.opaque,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _toWon(_showOtherIncomeGross ? widget.otherIncomeGrossEstimate : widget.otherIncome),
                key: ValueKey(_showOtherIncomeGross),
                style: AppTheme.serif(44, ink, spacing: -1.5, height: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _showOtherIncomeGross
                ? '이번 달 다른소득 (세전 환산 · 탭해서 되돌리기)'
                : '이번 달 다른소득 (세후 · 탭해서 세전 보기)',
            style: AppTheme.sans(12, tert),
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
