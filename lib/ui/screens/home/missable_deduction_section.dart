import 'package:flutter/material.dart';

import '../../../core/data/db_helper.dart';
import '../../../core/data/deduction_catalog.dart';
import '../../../core/data/residence.dart';
import '../../../core/data/year_deductions.dart';
import '../../components/section_accordion.dart';
import '../../theme/app_theme.dart';
import '../../theme/text_wrap.dart';
import '../bookkeeping_guide_screen.dart';
import '../year_deduction_screen.dart';

/// 홈 1장의 `04` — 유형에 따라 다른 것이 들어온다.
///
/// - 직장인·N잡러 → **공제**
/// - 프리랜서 → **장부 만들기** (세무 도구에도 그대로 남는다. 04는 지름길이고
///   05는 색인이다)
///
/// 왜 홈에 있어야 하나: 예전엔 이 목록이 04 세무 도구 안 「빠진 공제 항목 찾기」
/// 뒤에만 있었다. 연말정산 전에나 한 번 열어 볼 이름이라 아무도 미리 안 열었다.
/// 「미리 돌려받을 금액이 보여야 앱을 더 쓴다」는 게 이 절을 홈으로 올린 이유고,
/// 그래서 **접힌 상태에서 숫자가 보인다.**
///
/// **펼쳐도 목록을 늘어놓지 않는다.** 예전엔 후보 전부를 폈는데, 안경·산후조리원
/// 처럼 해당하는 사람이 드문 이름이 첫 화면에 박혔다. 홈은 **적어 둔 것만**
/// 보여주고, 고르는 일은 화면 안에서 한다.
class MissableDeductionSection extends StatefulWidget {
  final String userType;
  const MissableDeductionSection({super.key, required this.userType});

  @override
  State<MissableDeductionSection> createState() => _MissableDeductionSectionState();
}

class _MissableDeductionSectionState extends State<MissableDeductionSection> {
  Map<String, dynamic>? _profile;
  Map<String, int> _amounts = {};
  bool _loaded = false;

  bool get _isFreelancer => widget.userType == '프리랜서';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isFreelancer) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final p = await dbService.getProfile();
    final a = await YearDeductions.load(DateTime.now().year);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _amounts = a;
      _loaded = true;
    });
  }

  double get _gross => (_profile?['gross_income'] as num?)?.toDouble() ?? 0;
  int get _children => (_profile?['children_count_total'] as int?) ?? 0;

  /// 이 사람에게 걸리는 후보 — 개수를 세는 데만 쓴다(접힌 안내 문구).
  List<DeductionCategory> get _items => missableFor(
        residence: residenceOf(_profile),
        isHouseholdHead: isHouseholdHead(_profile),
        grossIncome: _gross,
        childrenCount: _children,
      );

  /// **적어 둔 것만.** 카탈로그 전체에서 찾는다 — 거주 형태를 바꿨다고 이미
  /// 적어 둔 금액이 홈에서 소리 없이 사라지면 안 된다.
  List<DeductionCategory> get _entered =>
      [for (final c in kDeductionCatalog) if ((_amounts[c.id] ?? 0) > 0) c];

  double get _refund => estimateYearRefund(
        amounts: _amounts,
        grossIncome: _gross,
        dependentsIncludingSelf: 1 + ((_profile?['dependents'] as int?) ?? 0),
        isHouseholdHead: isHouseholdHead(_profile),
        ownsHome: ownsHome(_profile),
        childrenCount: _children,
      ).refund;

  Future<void> _open() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const YearDeductionScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFreelancer) return _bookkeepingSection(context);
    if (!_loaded) return const SizedBox.shrink();

    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final filled = _amounts.isNotEmpty;
    final refund = filled ? _refund : 0.0;

    return SectionAccordion(
      no: '04',
      title: '공제',
      // **아무것도 안 넣었으면 안내, 넣었으면 숫자.**
      // 빈 상태에 0원을 찍으면 "받을 게 없다"로 읽힌다 — 아직 안 물어봤을 뿐인데.
      collapsed: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: filled && refund > 0
            ? Row(children: [
                Expanded(
                  child: Text('5월에 더 받을 수 있어요'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, tert)),
                ),
                Text(_won(refund),
                    style: AppTheme.serif(AppTheme.serifSM, accent, spacing: -0.5)),
              ])
            : Text(
                filled
                    ? '적어 두셨어요. 홈택스 신고 때 그대로 쓰시면 돼요.'.keepWords
                    : '홈택스가 자동으로 안 챙겨주는 공제예요. '
                            '${_items.length}가지 해당돼요.'
                        .keepWords,
                style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.5)),
      ),
      expanded: (_) => _expanded(context),
    );
  }

  Widget _expanded(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final entered = _entered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 적어 둔 게 없으면 **아무 이름도 부르지 않는다.** 후보를 늘어놓으면
        // 안 하는 항목이 대부분이라 홈이 남의 얘기로 채워진다.
        if (entered.isEmpty)
          Text(
              _items.isEmpty
                  ? '내 정보를 채우면 해당하는 공제를 골라드려요.'.keepWords
                  : '아직 적어 둔 게 없어요. 들어가서 해당하는 것만 고르시면 돼요.'
                      .keepWords,
              style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.5))
        else
          for (final c in entered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(
                  child: Text(c.name.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, ink,
                          weight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Text(_won((_amounts[c.id] ?? 0).toDouble()),
                    style: AppTheme.serif(AppTheme.serifSM, ink, spacing: -0.5)),
              ]),
            ),
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: AppTheme.dashedBox(
            context,
            child: SizedBox(
              height: 44,
              child: Row(children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Text(_amounts.isEmpty ? '공제 챙기러 가기' : '고치기',
                      style: AppTheme.sans(AppTheme.tsSM, sub)),
                ),
                const SizedBox(width: 8),
                Text('＋', style: AppTheme.sans(AppTheme.tsLG, accent, weight: FontWeight.w600)),
                const SizedBox(width: 14),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  /// 프리랜서의 04 — 장부 만들기.
  ///
  /// 무기장가산세(산출세액 20%)를 피하는 유일한 길이라 연중에 봐야 한다.
  /// 세무 도구 안에만 있으면 5월에야 열어 보게 되는데, 그때는 이미 늦다.
  Widget _bookkeepingSection(BuildContext context) {
    final tert = AppTheme.inkTertiary(context);
    return SectionAccordion(
      no: '04',
      title: '장부 만들기',
      collapsed: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('내 기장의무를 확인하고 가계부로 간편장부를 만들어요.'.keepWords,
            style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.5)),
      ),
      expanded: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookkeepingGuideScreen(userType: widget.userType))),
        child: AppTheme.dashedBox(
          context,
          child: SizedBox(
            height: 44,
            child: Row(children: [
              const SizedBox(width: 14),
              Expanded(
                child: Text('장부 만들러 가기',
                    style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: tert),
              const SizedBox(width: 10),
            ]),
          ),
        ),
      ),
    );
  }

  String _won(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b원';
  }
}
