import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/data/changelog.dart';
import '../../core/data/db_helper.dart';
import '../screens/update_notes_screen.dart';
import '../theme/app_theme.dart';

/// **방금 업데이트했을 때 한 번만 뜨는 자리.**
///
/// 업데이트 카드는 "받으세요"까지만 말하고 사라진다. 정작 사용자가 궁금한
/// "그래서 뭐가 바뀌었는데"는 아무도 안 알려줬다. 설치 전에는 알 방법이
/// 없지만(서버도 없고 Play도 출시 노트를 안 준다), 깔린 뒤에는 새 버전이
/// 제 변경 내역을 들고 있으므로 그때 말하면 된다.
///
/// **강제로 띄우지 않는다.** 앱을 켠 사람은 세금을 보러 온 것이지 공지를
/// 읽으러 온 게 아니다. 홈에 한 줄로 두고, 눌러야 열리고, 누르면 사라진다.
///
/// 새로 깐 사람에게는 안 뜬다 — 처음 켠 사람에게 "업데이트됐어요"는 거짓말이다.
class JustUpdatedCard extends StatefulWidget {
  const JustUpdatedCard({super.key});

  @override
  State<JustUpdatedCard> createState() => _JustUpdatedCardState();
}

class _JustUpdatedCardState extends State<JustUpdatedCard> {
  static const _key = 'last_seen_build';

  ChangeEntry? _entry;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final build = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
      if (build == null) return;
      final seen = int.tryParse(await dbService.getAppState(_key) ?? '');

      // 처음 켠 사람 — 지금 버전을 기억만 해 두고 아무것도 안 띄운다.
      if (seen == null) {
        await dbService.setAppState(_key, '$build');
        return;
      }
      if (seen >= build) return;

      final entry = (await loadChangelog())
          .where((e) => e.build == build)
          .cast<ChangeEntry?>()
          .firstWhere((_) => true, orElse: () => null);
      // 변경 내역을 안 적고 올린 버전이면 조용히 넘긴다 — 빈 공지를 띄우느니
      // 아무 말도 안 하는 게 낫다. (적었는지는 changelog_test가 본다.)
      if (entry == null) {
        await dbService.setAppState(_key, '$build');
        return;
      }
      if (!mounted) return;
      setState(() => _entry = entry);
    } catch (_) {
      // 버전을 못 읽는 환경(웹·테스트)에서는 그냥 안 뜬다.
    }
  }

  Future<void> _open() async {
    final e = _entry;
    if (e == null) return;
    await dbService.setAppState(_key, '${e.build}');
    if (!mounted) return;
    setState(() => _entry = null);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => UpdateNotesScreen(highlightBuild: e.build)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    if (e == null) return const SizedBox.shrink();
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: true,
        label: '${e.label}으로 업데이트됐어요. 바뀐 내용 보기',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: AppTheme.panel(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.label}으로 업데이트됐어요',
                    style: AppTheme.sans(AppTheme.tsMD, ink,
                        weight: FontWeight.w700)),
                const SizedBox(height: 4),
                // 첫 줄을 미리 보여준다. 무엇이 바뀌었는지 누르기 전에 안다.
                Text(e.lines.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5)),
                const SizedBox(height: 12),
                Text('바뀐 내용 보기 →',
                    style: AppTheme.sans(AppTheme.tsXS,
                        AppTheme.accentColor(context),
                        weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
