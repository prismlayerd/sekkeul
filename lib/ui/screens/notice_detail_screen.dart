import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/remote_notices.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 소식 한 꼭지 — 신문 기사처럼 읽는다.
///
/// 종전 알림 카드는 눌러도 글자 한 덩어리였다. 무엇이 어떻게 바뀌었는지
/// 알려면 문장을 끝까지 읽어야 했다. 여기서는 **전/후 표**를 먼저 보여준다 —
/// 사용자가 알고 싶은 건 "바뀌었다"가 아니라 "얼마가 얼마로"다.
class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('소식',
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(notice.label,
              style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(notice.title.keepWords,
              style: AppTheme.display(AppTheme.serifSM, ink, height: 1.35)),
          const SizedBox(height: 8),
          Text(_ymd(notice.date), style: AppTheme.sans(AppTheme.tsSM, sub)),
          if (notice.imageUrl != null) ...[
            const SizedBox(height: 16),
            _Photo(url: notice.imageUrl!, line: line),
          ],
          if (notice.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: line, width: 3))),
              child: Text(notice.summary.keepWords,
                  style: AppTheme.sans(AppTheme.tsBase, ink, height: 1.6)),
            ),
          ],
          if (notice.changes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('무엇이 바뀌었나',
                style:
                    AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final c in notice.changes) ...[
              _ChangeRow(change: c, ink: ink, sub: sub, line: line),
              const SizedBox(height: 8),
            ],
          ],
          for (final p in notice.body) ...[
            const SizedBox(height: 16),
            Text(p.keepWords,
                style: AppTheme.sans(AppTheme.tsBase, ink, height: 1.7)),
          ],
          if (notice.source != null) ...[
            const SizedBox(height: 28),
            Divider(height: 1, color: line),
            const SizedBox(height: 12),
            Text('출처 · ${notice.source}',
                style: AppTheme.sans(AppTheme.tsSM, sub)),
            if (notice.sourceUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _open(notice.sourceUrl!),
                behavior: HitTestBehavior.opaque,
                child: Row(children: [
                  Text('원문 보기',
                      style: AppTheme.sans(AppTheme.tsSM, ink,
                          weight: FontWeight.w600)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward, size: 13, color: ink),
                ]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일';

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// 사진. **없어도 화면이 깨지지 않는다** — 인터넷이 끊겼거나 주소가 죽었으면
/// 그 자리를 비운다. 로딩 자리를 잡아 두어 글이 아래로 튀지 않게 한다.
class _Photo extends StatelessWidget {
  final String url;
  final Color line;
  const _Photo({required this.url, required this.line});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : Container(color: line.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final NoticeChange change;
  final Color ink, sub, line;
  const _ChangeRow(
      {required this.change,
      required this.ink,
      required this.sub,
      required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(change.what.keepWords,
              style: AppTheme.sans(AppTheme.tsSM, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(change.before.keepWords,
                    style: AppTheme.sans(AppTheme.tsBase, sub,
                        height: 1.5,
                        decoration: TextDecoration.lineThrough)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, size: 14, color: sub),
              ),
              Expanded(
                child: Text(change.after.keepWords,
                    style: AppTheme.sans(AppTheme.tsBase, ink,
                        height: 1.5, weight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
