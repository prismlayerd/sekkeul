import 'package:flutter/material.dart';

import '../../core/data/changelog.dart';
import '../theme/app_theme.dart';

/// **업데이트 소식** — 이번에 무엇이 바뀌었는지.
///
/// 설치 **전에는** 보여줄 수가 없다. 서버가 없고, Play의 업데이트 API도 출시
/// 노트를 안 준다(우선순위와 버전코드가 전부다). 그래서 방향을 뒤집었다 —
/// 새 버전이 자기 얘기를 품고 와서, 깔린 뒤에 말한다. 자기 얘기라 정확하다.
///
/// 원문은 `assets/changelog.md` 한 곳이고 Play의 「새로운 기능」도 같은 파일을
/// 쓴다(`tool/play_publish.py --from-changelog`).
class UpdateNotesScreen extends StatelessWidget {
  /// 방금 업데이트하고 처음 열었을 때 그 버전을 위에서 짚어 준다.
  final int? highlightBuild;

  const UpdateNotesScreen({super.key, this.highlightBuild});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      appBar: AppBar(title: const Text('업데이트 소식')),
      body: SafeArea(
        child: FutureBuilder<List<ChangeEntry>>(
          future: loadChangelog(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final entries = snap.data!;
            if (entries.isEmpty) {
              return Center(
                child: Text('아직 소식이 없어요.',
                    style: AppTheme.sans(AppTheme.tsMD, sub)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final isNew = e.build == highlightBuild;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i > 0) const SizedBox(height: 26),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(e.label,
                            style: AppTheme.display(AppTheme.serifSM, ink)),
                        const SizedBox(width: 10),
                        Text(e.date,
                            style: AppTheme.sans(AppTheme.tsXS, sub)),
                        const Spacer(),
                        // 세법이 바뀐 릴리스는 표시해 둔다. 나중에 "언제부터
                        // 이 기준이었지"를 되짚을 때 이 표시가 답이 된다.
                        // (붉은색은 달력 전용이라 여기선 안 쓴다 — 이 앱의
                        //  유일한 색을 두 뜻으로 쓰면 둘 다 흐려진다.)
                        if (e.taxUpdate)
                          Text('세법 반영',
                              style: AppTheme.label(context,
                                  color: AppTheme.ink(context))),
                        if (isNew && !e.taxUpdate)
                          Text('방금 받은 버전', style: AppTheme.label(context)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final line in e.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('· ',
                                style: AppTheme.sans(AppTheme.tsMD, sub)),
                            Expanded(
                              child: Text(line,
                                  style: AppTheme.sans(AppTheme.tsMD, ink,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
