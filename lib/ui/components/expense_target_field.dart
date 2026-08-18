import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 이달 지출 목표를 정하는 **인라인** 입력칸.
///
/// **팝업으로 만들지 않는다.** 한때 다이얼로그였다 — 홈에서 목표를 누르면 가계부
/// 분석 탭으로 끌려가던 걸 고치려고 "그 자리에서 연다"는 뜻으로 띄웠는데, 뜻은
/// 맞고 수단이 틀렸다. 이 앱은 종이 명세서라 위에 뜨는 창이 없다. 목표는 지금
/// 보고 있는 그 줄에서 정해져야 한다.
///
/// **부르는 곳이 둘이다** — 홈 02와 가계부 분석 탭. 예전에는 두 화면이 각자
/// 입력칸을 들고 있어서 서로를 모른 채 같은 값을 고쳤다. 입력칸 하나를 두 곳에서
/// 부르면 둘 다 해결된다.
///
/// 저장은 하지 않는다 — 정해진 값을 [onSubmit]으로 넘길 뿐이다. 어디에 쓸지는
/// 부른 쪽이 정한다(유형별 값이라 `setProfileTypeValues`로 간다).
class ExpenseTargetField extends StatefulWidget {
  final int current;
  final ValueChanged<double> onSubmit;
  final VoidCallback onCancel;

  const ExpenseTargetField({
    super.key,
    required this.current,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ExpenseTargetField> createState() => _ExpenseTargetFieldState();
}

class _ExpenseTargetFieldState extends State<ExpenseTargetField> {
  late final _ctrl =
      TextEditingController(text: widget.current > 0 ? comma(widget.current) : '');

  /// 포커스 노드를 **직접 들고** 걷힐 때 풀어 준다.
  ///
  /// `autofocus: true`만 주면 노드를 프레임워크가 들고, 입력칸이 사라질 때
  /// 글자칸이 아직 포커스를 쥔 채로 트리가 해체된다. 그러면 상속 위젯이 딸린
  /// 것들을 둔 채 걷혀 `_dependents.isEmpty` 단언에서 앱이 죽는다. 디버그에서만
  /// 도는 단언이라 스토어 빌드에서는 조용히 넘어갈 뿐, 트리가 어긋나는 건 같다.
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.unfocus();
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() =>
      widget.onSubmit(double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0.0);

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final line = AppTheme.line(context);
    final sub = AppTheme.inkSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('이달 지출 목표', style: AppTheme.label(context)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: AppTheme.sans(AppTheme.tsLG, ink, weight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            hintText: '예: 1,500,000',
            hintStyle: AppTheme.sans(AppTheme.tsBase, AppTheme.inkTertiary(context)),
            suffixText: '원',
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
          ),
          onChanged: (v) {
            final n = v.replaceAll(RegExp(r'[^0-9]'), '');
            final f = n.isEmpty ? '' : comma(int.parse(n));
            _ctrl.value = TextEditingValue(
                text: f, selection: TextSelection.collapsed(offset: f.length));
          },
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('취소', style: AppTheme.sans(AppTheme.tsMD, sub)),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('저장',
                  style: AppTheme.sans(AppTheme.tsMD, accent, weight: FontWeight.w700)),
            ),
          ),
        ]),
      ],
    );
  }
}
