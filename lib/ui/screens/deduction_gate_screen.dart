import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tax_simulator_screen.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/deduction_options.dart';
import '../theme/text_wrap.dart';

/// 공제 고르기 — 계산기에 들어가기 전, 해당되는 항목만 남기는 관문.
///
/// 세법 용어로 묻지 않는다. "월세 살아요"처럼 자기 생활로 알아볼 수 있게 쓰고,
/// 오른쪽에 **그 사람의 총급여로 계산한 금액**을 붙인다. 체크리스트가 아니라
/// 가격표다 — 고를 이유가 숫자에 있어야 한다.
///
/// 측정 근거(2026-07-27): 공제 항목 중 가장 작은 것도 환급 7.5만원이라
/// "금액이 작으니 접자"는 성립하지 않았다. 접을 축은 금액이 아니라 **해당자 비율**이다.
class DeductionGateScreen extends StatefulWidget {
  final String userType;

  const DeductionGateScreen({super.key, required this.userType});

  @override
  State<DeductionGateScreen> createState() => _DeductionGateScreenState();
}

class _DeductionGateScreenState extends State<DeductionGateScreen> {
  final Set<String> _picked = {};
  double _gross = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await dbService.getProfile();
    if (!mounted) return;
    final saved = (p?['deduction_picks'] as String?) ?? '';
    setState(() {
      _gross = (p?['gross_income'] as num?)?.toDouble() ?? 0;
      // 지난번에 고른 것을 미리 체크해 둔다 — 매번 처음부터 고르게 하지 않는다.
      _picked.addAll(saved.split(',').where((e) => e.isNotEmpty));
      _loaded = true;
    });
  }

  List<DeductionOption> get _all =>
      deductionOptions(userType: widget.userType, grossIncome: _gross);
  List<DeductionOption> get _spending => _all.where((e) => e.isSpending).toList();
  List<DeductionOption> get _situation => _all.where((e) => !e.isSpending).toList();

  double get _total => _all
      .where((e) => _picked.contains(e.id))
      .fold(0.0, (s, e) => s + e.maxCredit);


  Future<void> _goToCalculator() async {
    final profile = await dbService.getProfile() ?? {};
    profile['deduction_picks'] = _picked.join(',');
    await dbService.saveProfile(profile);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TaxSimulatorScreen(userType: widget.userType, preOpened: Set.of(_picked))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    if (!_loaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  Text('공제 고르기'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 12),
                  Text('해당되는 것만\n골라주세요', style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
                  const SizedBox(height: 10),
                  Text(
                    _gross > 0
                        ? '고른 것만 입력창이 열려요. 금액은 총급여 ${won(_gross)} 기준이에요.'
                        : '고른 것만 입력창이 열려요. 금액은 총급여 4,500만원 기준 예시예요.',
                    style: AppTheme.sans(14, sub, height: 1.55),
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle('돈을 쓴 곳', '고르면 금액을 물어봐요'),
                  ..._spending.map(_row),
                  const SizedBox(height: 28),
                  _sectionTitle('나와 가족', '고르면 사람 수만 세면 돼요'),
                  ..._situation.map(_row),
                  const SizedBox(height: 24),
                  Text(
                    '고르지 않아도 나중에 계산기에서 직접 열 수 있어요.'.keepWords,
                    style: AppTheme.sans(12, AppTheme.inkTertiary(context), height: 1.5),
                  ),
                ],
              ),
            ),
            _summaryBar(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title, style: AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
            const SizedBox(width: 8),
            Expanded(child: Text(hint, style: AppTheme.sans(12, AppTheme.inkTertiary(context)))),
          ],
        ),
      );

  /// 선택 상태는 **선 두께**로 말한다 — Blueprint는 그림자를 쓰지 않는다.
  Widget _row(DeductionOption item) {
    final on = _picked.contains(item.id);
    final accent = AppTheme.accentColor(context);
    return Semantics(
      button: true,
      selected: on,
      label: '${item.label}, 최대 ${won(item.maxCredit)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => on ? _picked.remove(item.id) : _picked.add(item.id)),
        child: Container(
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.05) : Colors.transparent,
            border: Border(bottom: BorderSide(color: AppTheme.line(context), width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(2, 15, 4, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 누를 수 있다는 표식. 그림자를 못 쓰는 체계라 표식이 없으면 행이 정적으로 보인다.
              Container(
                width: 17,
                height: 17,
                margin: const EdgeInsets.only(top: 1, right: 12),
                decoration: BoxDecoration(
                  color: on ? accent : Colors.transparent,
                  border: Border.all(
                      color: on ? accent : AppTheme.lineStrong(context), width: 1.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: on
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label.keepWords,
                        style: AppTheme.sans(14.5, AppTheme.ink(context),
                            weight: FontWeight.w700, spacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(item.basis.keepWords,
                        style: AppTheme.sans(12, AppTheme.inkTertiary(context), height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('최대 ',
                        style: AppTheme.sans(11, AppTheme.inkTertiary(context))),
                    Text(won(item.maxCredit),
                        style: AppTheme.sans(13,
                            on ? accent : AppTheme.inkSecondary(context),
                            weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBar() {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final n = _picked.length;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.lineStrong(context), width: 1.4)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(n == 0 ? '아직 고른 항목이 없어요' : '고른 $n개를 한도까지 채우면',
                    style: AppTheme.sans(12, AppTheme.inkSecondary(context))),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: _total, end: _total),
                duration: Duration(milliseconds: reduceMotion ? 0 : 260),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(won(v),
                    style: AppTheme.serif(34, n == 0 ? AppTheme.inkTertiary(context) : ink,
                        spacing: -1)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goToCalculator,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: n == 0 ? Colors.transparent : accent,
                border: Border.all(color: n == 0 ? AppTheme.lineStrong(context) : accent, width: 1.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Text(n == 0 ? '건너뛰고 계산기 열기' : '$n개 입력하러 가기',
                    style: AppTheme.sans(15, n == 0 ? ink : Colors.white,
                        weight: FontWeight.w700, spacing: -0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
