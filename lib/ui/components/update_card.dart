import 'package:flutter/material.dart';

import '../../core/data_vintage.dart';
import '../../core/update_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// **업데이트가 있다는 걸 우리 말로 알린다.**
///
/// Google 대화상자는 "업데이트 사용 가능"이라고만 한다. 세법이 바뀌어 지금 보는
/// 금액이 낡았다는 건 우리만 아는 사실이라, 이유는 이 카드가 말하고 설치는
/// Play에 넘긴다.
///
/// 업데이트가 없으면 아무것도 그리지 않는다 — 홈에 빈 자리를 남기지 않는다.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: updateService,
      builder: (context, _) {
        if (!updateService.hasUpdate) return const SizedBox.shrink();

        final ink = AppTheme.ink(context);
        final sub = AppTheme.inkSecondary(context);
        final accent = AppTheme.accentColor(context);
        final ready = updateService.state == UpdateState.readyToInstall;
        final busy = updateService.state == UpdateState.downloading;

        // 여백을 카드 안에 둔다 — 안 보일 때 홈에 빈 자리가 남지 않는다.
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppTheme.panel(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? '새 버전을 받았어요' : '세법·복지 기준이 바뀐 버전이 있어요',
                  style: AppTheme.sans(14, ink, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? '다시 시작하면 새 기준으로 계산해요.'
                      : '지금 보시는 값은 ${DataVintage.label} 기준이에요.'.keepWords,
                  style: AppTheme.sans(12, sub, height: 1.5),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy
                      ? null
                      : () => ready
                          ? updateService.install()
                          : updateService.download(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: accent),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        busy
                            ? '내려받는 중…'
                            : ready
                                ? '다시 시작하기 →'
                                : '지금 받기 →',
                        style:
                            AppTheme.sans(12, accent, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
