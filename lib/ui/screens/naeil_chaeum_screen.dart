import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class NaeilChaeumScreen extends StatelessWidget {
  const NaeilChaeumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final bg = AppTheme.surface(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('내일채움공제',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ ', style: AppTheme.sans(14, ink)),
                  Expanded(
                    child: Text(
                      '2024년부터 신규 가입이 종료되었습니다.\n기존 가입자만 만기까지 유지 가능합니다.'.keepWords,
                      style: AppTheme.sans(13, ink, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '기존 가입자 정보 (2년형 기준)',
              [
                '청년 적립: 300만원',
                '기업 적립: 400만원',
                '정부 지원 포함 만기 수령: 약 1,200만원 이상',
                '세금: 원금 비과세, 이자·기업기여금에 15.4% 원천징수',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '대체 상품',
              [
                '청년도약계좌 (5년, 월 최대 70만)',
                '청년내일저축계좌 (복지부 소관)',
                '청년일자리도약장려금',
              ],
              line,
              sub,
              ink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(
      String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(13, sub)),
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
