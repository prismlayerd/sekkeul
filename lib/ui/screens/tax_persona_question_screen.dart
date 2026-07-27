import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 절세 유형 진단 — 4문항 순차 예/아니오 질문으로 N잡러 여부를 재판정.
/// 온보딩(표제란 메타포)과 짝을 이루는 화면이라 같은 배너 글리프 어휘를 재사용한다.
class TaxPersonaQuestionScreen extends StatefulWidget {
  final String initialUserType;

  const TaxPersonaQuestionScreen({super.key, required this.initialUserType});

  @override
  State<TaxPersonaQuestionScreen> createState() => _TaxPersonaQuestionScreenState();
}

class _Question {
  final String glyph;
  final String label;
  final String title;
  const _Question({required this.glyph, required this.label, required this.title});
}

const _questions = [
  _Question(
    glyph: '기',
    label: '기타소득',
    title: '회사 월급 외에 강연료, 상금 등으로\n받은 기타소득이 연 300만 원을 넘나요?',
  ),
  _Question(
    glyph: '금',
    label: '금융소득',
    title: '주식 배당금이나 예적금 이자로 받은\n금융소득이 연 2,000만 원을 넘나요?',
  ),
  _Question(
    glyph: '합',
    label: '소득 합산',
    title: '이직하셨거나 두 군데 이상에서 일하시면서\n연말정산 때 소득을 합치지 않으셨나요?',
  ),
  _Question(
    glyph: '사',
    label: '사업소득',
    title: '금액에 상관없이 작년에 배달, 외주 등\n본인 명의로 사업/프리랜서 소득이 발생했나요?',
  ),
];

class _TaxPersonaQuestionScreenState extends State<TaxPersonaQuestionScreen> {
  int _currentStep = 0;
  bool _hasExtraIncome = false;

  void _nextStep(bool hasIncome) {
    if (hasIncome) _hasExtraIncome = true;

    if (_currentStep < _questions.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _finish() {
    String newUserType = widget.initialUserType;
    if (widget.initialUserType == '직장인' && _hasExtraIncome) {
      newUserType = 'N잡러';
    } else if (widget.initialUserType == '프리랜서' && _hasExtraIncome) {
      // 프리랜서인데 다른 소득(직장 등)이 있으면 N잡러일 수 있음
      newUserType = 'N잡러';
    }
    Navigator.pop(context, newUserType);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    final q = _questions[_currentStep];

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('절세 유형 진단'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 16),
              _progressTicks(),
              const SizedBox(height: 8),
              Text('질문 ${_currentStep + 1} · 전체 ${_questions.length}'.keepWords,
                  style: AppTheme.sans(12, AppTheme.inkTertiary(context), weight: FontWeight.w600)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduce ? 0 : 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_currentStep),
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.accentColor(context), width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(q.glyph, style: AppTheme.serif(22, AppTheme.accentColor(context))),
                      ),
                      const SizedBox(height: 8),
                      Text(q.label.toUpperCase(), style: AppTheme.label(context)),
                      const SizedBox(height: 14),
                      Text(q.title, style: AppTheme.serif(24, ink, spacing: -0.4, height: 1.35)),
                    ],
                  ),
                ),
              ),
              _answerButton(label: '아니오', onTap: () => _nextStep(false)),
              const SizedBox(height: 10),
              _answerButton(label: '예', onTap: () => _nextStep(true), filled: true),
            ],
          ),
        ),
      ),
    );
  }

  /// 배너 로테이션과 동일한 눈금 틱 — 답한 문항은 굵은 막대, 남은 문항은 헤어라인.
  Widget _progressTicks() {
    final ink = AppTheme.ink(context);
    return Row(
      children: List.generate(_questions.length, (i) {
        final done = i <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == _questions.length - 1 ? 0 : 6),
            height: 2,
            color: done ? ink : AppTheme.line(context),
          ),
        );
      }),
    );
  }

  Widget _answerButton({required String label, required VoidCallback onTap, bool filled = false}) {
    final ink = AppTheme.ink(context);
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ink : null,
          border: Border.all(color: ink, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: AppTheme.sans(15, filled ? bg : ink, weight: FontWeight.w700)),
      ),
    );
  }
}
