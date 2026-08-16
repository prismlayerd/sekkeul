import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'amount_field.dart';

/// 이달 지출 목표를 정하는 입력칸.
///
/// **부르는 곳이 둘이다** — 홈 02와 가계부 분석 탭. 예전에는 두 화면이 각자
/// 입력칸을 들고 있어서 서로를 모른 채 같은 값을 고쳤다. 그렇다고 한쪽을
/// 없애면 홈에서 목표를 정하려던 사람이 낯선 화면으로 끌려간다.
/// 입력칸 하나를 두 곳에서 부르면 둘 다 해결된다.
///
/// 저장은 하지 않는다 — 정해진 값을 돌려줄 뿐이다. 어디에 쓸지는 부른 쪽이
/// 정한다(유형별 값이라 [setProfileTypeValues]로 간다).
/// 취소하면 null.
Future<double?> showExpenseTargetDialog(BuildContext context, int current) async {
  final ctrl = TextEditingController(text: current > 0 ? comma(current) : '');
  // 포커스 노드를 **직접 들고** 닫을 때 풀어 준다.
  //
  // `autofocus: true`만 주면 노드를 프레임워크가 들고, 바깥을 눌러 다이얼로그가
  // 걷힐 때 글자칸이 아직 포커스를 쥔 채로 트리가 해체된다. 그러면 상속 위젯이
  // 딸린 것들을 둔 채 걷혀 `_dependents.isEmpty` 단언에서 앱이 죽는다.
  // 디버그에서만 도는 단언이라 스토어 빌드에서는 조용히 넘어갔을 뿐,
  // 트리가 어긋나는 건 릴리스에서도 같다.
  final focus = FocusNode();

  final ink = AppTheme.ink(context);
  final accent = AppTheme.accentColor(context);
  final bg = AppTheme.backgroundColor(context);
  final line = AppTheme.line(context);
  final sub = AppTheme.inkSecondary(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: line),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      title: Text('이달 지출 목표', style: AppTheme.serif(AppTheme.tsLG, ink)),
      content: TextField(
        controller: ctrl,
        focusNode: focus,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: const [ThousandsFormatter()],
        textAlign: TextAlign.right,
        style: AppTheme.sans(AppTheme.tsBase, ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: '예: 1,500,000',
          hintStyle: AppTheme.sans(AppTheme.tsBase, AppTheme.inkTertiary(ctx)),
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
          ctrl.value = TextEditingValue(
              text: f, selection: TextSelection.collapsed(offset: f.length));
        },
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
            child: Text('취소', style: AppTheme.sans(AppTheme.tsMD, sub)),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(ctx, true),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
            child: Text('저장',
                style: AppTheme.sans(AppTheme.tsMD, accent, weight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );

  final val = double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0.0;
  focus.unfocus();
  focus.dispose();
  ctrl.dispose();
  return confirmed == true ? val : null;
}
