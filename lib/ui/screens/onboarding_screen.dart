import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tax_simulator_screen.dart';

/// 소득 유형 점검 — 도면의 표제란(title block) 메타포.
/// 소득 항목을 체크하면 하단 표제란이 근로/사업 인디케이터와 함께
/// 유형(직장인 · N잡러 · 프리랜서)을 실시간 판정한다.
class OnboardingScreen extends StatefulWidget {
  final bool returnResult;
  const OnboardingScreen({super.key, this.returnResult = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 소득 항목 — 텍스트 + 세부 + 분류(근로/사업)
  static const List<_IncomeSource> _sources = [
    _IncomeSource('회사에서 받는 월급', '근로소득 · 2곳 이상이면 5월 합산신고', _Cat.labor),
    _IncomeSource('3.3% 떼는 프리랜서 일', '사업소득 · 금액과 무관하게 5월 신고', _Cat.business),
    _IncomeSource('내 명의 사업장 운영', '사업소득 · 금액과 무관하게 5월 신고', _Cat.business),
    _IncomeSource('배달 · 대리 등 부수입', '사업소득 · 근로 외 2천만원↑ 건보료 추가', _Cat.business),
    _IncomeSource('블로그 · 유튜브 수익', '기타소득 · 연 300만원 초과 시 종합과세', _Cat.business),
  ];

  final List<bool> _selected = List.filled(5, false);

  final ScrollController _scrollCtrl = ScrollController();
  bool _moreBelow = false; // 리스트 아래에 가려진(안 보이는) 항목이 더 있는지

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_updateMoreBelow);
    // 첫 레이아웃 후 overflow 여부를 판정(작은 화면이면 즉시 화살표 노출)
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMoreBelow());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_updateMoreBelow);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _updateMoreBelow() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final more = pos.maxScrollExtent > 0 && pos.pixels < pos.maxScrollExtent - 4;
    if (more != _moreBelow && mounted) setState(() => _moreBelow = more);
  }

  bool get _hasSelection => _selected.contains(true);
  bool get _hasLabor => _selected[0];
  bool get _hasBusiness => _selected[1] || _selected[2] || _selected[3] || _selected[4];

  /// 표제란 판정 결과 — 미선택이면 null.
  String? get _verdict {
    if (_hasLabor && _hasBusiness) return 'N잡러';
    if (_hasLabor) return '직장인';
    if (_hasBusiness) return '프리랜서';
    return null;
  }

  void _toggle(int i) {
    setState(() => _selected[i] = !_selected[i]);
  }

  void _confirm() {
    final type = _verdict ?? '프리랜서';
    if (widget.returnResult) {
      Navigator.pop(context, type);
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a, s) => TaxSimulatorScreen(userType: type),
        transitionsBuilder: (c, a, s, child) {
          final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: a.drive(tween), child: child);
        },
      ),
    );
  }

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('소득 유형 점검'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 14),
                  Text('어떤 소득이\n있으신가요?',
                      style: AppTheme.serif(34, ink, spacing: -0.5, height: 1.2)),
                  const SizedBox(height: 12),
                  Text('해당하는 항목을 모두 골라주세요. 아래 표제란이 유형을 판정해드려요.',
                      style: AppTheme.sans(13, sub, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 소득 항목 점검 리스트 ──
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _sources.length,
                    itemBuilder: (context, i) {
                      return Column(
                        children: [
                          if (i == 0) AppTheme.hairline(context),
                          _sourceRow(i),
                          AppTheme.hairline(context),
                        ],
                      );
                    },
                  ),
                  // 아래에 가려진 항목이 더 있을 때만 페이드 + 아래 화살표로 스크롤 단서를 준다.
                  if (_moreBelow)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 44,
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                            ),
                          ),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 22, color: AppTheme.inkSecondary(context)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── 표제란(판정) + 확정 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titleBlock(),
                  const SizedBox(height: 16),
                  _confirmButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 소득 항목 한 줄 — 사각 체크박스 + 텍스트 + 분류 주석.
  Widget _sourceRow(int i) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final on = _selected[i];
    final src = _sources[i];

    return GestureDetector(
      onTap: () => _toggle(i),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            // 사각 체크박스 — 선택 시 잉크로 채움
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? ink : null,
                border: Border.all(color: on ? ink : AppTheme.lineStrong(context), width: 1.4),
                borderRadius: BorderRadius.circular(3),
              ),
              child: on
                  ? Icon(Icons.check, size: 16, color: AppTheme.backgroundColor(context))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(src.text,
                      style: AppTheme.sans(15, ink,
                          weight: on ? FontWeight.w700 : FontWeight.w500, spacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(src.detail,
                      style: AppTheme.sans(12, tert, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 분류 주석 (근로 / 사업)
            Text(src.cat == _Cat.labor ? '근로' : '사업',
                style: AppTheme.sans(12, on ? sub : tert,
                    weight: FontWeight.w600, spacing: 1.0)),
          ],
        ),
      ),
    );
  }

  /// 도면 표제란 — 근로/사업 인디케이터 + 실시간 유형 판정.
  Widget _titleBlock() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final verdict = _verdict;
    final reduce = MediaQuery.of(context).disableAnimations;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lineStrong(context), width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 좌: 판정 라벨 + 인디케이터
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('판정'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 10),
                  _indicator('근로', _hasLabor),
                  const SizedBox(height: 6),
                  _indicator('사업', _hasBusiness),
                ],
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: AppTheme.line(context)),
            // 우: 유형 결과 (세리프)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduce ? 0 : 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: verdict == null
                      ? Text('항목을 선택하면\n유형이 표시돼요',
                          key: const ValueKey('empty'),
                          style: AppTheme.sans(13, tert, height: 1.45))
                      : Column(
                          key: ValueKey(verdict),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(verdict, style: AppTheme.serif(34, ink, spacing: -0.8, height: 1.0)),
                            const SizedBox(height: 5),
                            Text(_verdictNote(verdict),
                                style: AppTheme.sans(12, AppTheme.inkSecondary(context), height: 1.4)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicator(String label, bool on) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: on ? ink : null,
            shape: BoxShape.circle,
            border: Border.all(color: on ? ink : AppTheme.lineStrong(context), width: 1.2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: AppTheme.sans(13, on ? ink : tert,
                weight: on ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  String _verdictNote(String v) {
    switch (v) {
      case '직장인':
        return '근로소득만 있어요';
      case 'N잡러':
        return '근로 + 사업소득 합산 신고';
      default:
        return '사업소득 5월 종합소득세 신고';
    }
  }

  Widget _confirmButton() {
    final enabled = _hasSelection;
    final ink = AppTheme.ink(context);
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: enabled ? _confirm : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? ink : null,
          border: Border.all(color: enabled ? ink : AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('유형 확정하기',
                style: AppTheme.sans(15, enabled ? bg : AppTheme.inkTertiary(context),
                    weight: FontWeight.w700)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward,
                size: 16, color: enabled ? bg : AppTheme.inkTertiary(context)),
          ],
        ),
      ),
    );
  }
}

enum _Cat { labor, business }

class _IncomeSource {
  final String text;
  final String detail;
  final _Cat cat;
  const _IncomeSource(this.text, this.detail, this.cat);
}
