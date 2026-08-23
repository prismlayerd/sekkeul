import 'package:flutter/material.dart';

import '../../core/data/year_snapshot.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// **아직 안 넣은 칸을 앱이 먼저 말한다.**
///
/// 반쯤 채운 신고서가 다 채운 것처럼 보이면, 사용자는 그 숫자를 그대로 홈택스에
/// 옮겨 적는다. 틀린 값을 자신 있게 보여주느니 무엇이 비었는지 밝히는 편이 낫다 —
/// 홈 02가 「N월부터의 기록만 반영됐어요」로 이미 지키는 규율과 같다.
///
/// [blocking]이 하나라도 있으면 제목이 「정확하지 않아요」로 바뀐다. 경고만
/// 남았으면 숫자는 쓸 만하다는 뜻이라 재촉하지 않는다.
class MissingInputNotice extends StatelessWidget {
  final List<MissingInput> missing;

  const MissingInputNotice(this.missing, {super.key});

  @override
  Widget build(BuildContext context) {
    if (missing.isEmpty) return const SizedBox.shrink();
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final blocking = missing.where((m) => m.blocking).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              blocking.isNotEmpty
                  ? '이 숫자는 아직 정확하지 않아요'
                  : '더 넣으면 정확해져요',
              style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              blocking.isNotEmpty
                  ? '아래 ${blocking.length}가지가 비어 있어요. 채우고 다시 보세요.'
                      .keepWords
                  : '없어도 계산은 되지만, 넣으면 더 맞아요.'.keepWords,
              style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
          const SizedBox(height: 10),
          for (final m in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.blocking ? '· ' : '· ',
                    style: AppTheme.sans(AppTheme.tsXS, m.blocking ? ink : tert)),
                Expanded(
                  child: Text('${m.label} — ${m.where}'.keepWords,
                      style: AppTheme.sans(AppTheme.tsXS,
                          m.blocking ? ink : tert,
                          weight: m.blocking ? FontWeight.w600 : FontWeight.w400,
                          height: 1.45)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
