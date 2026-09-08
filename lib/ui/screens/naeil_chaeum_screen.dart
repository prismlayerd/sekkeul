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
      appBar: AppBar(
        title: Text('내일채움공제',
            style: AppTheme.serif(AppTheme.tsBase, ink,
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
                  Text('⚠️ ', style: AppTheme.sans(AppTheme.tsMD, ink)),
                  Expanded(
                    child: Text(
                      '청년내일채움공제(2년형)는 2024년 사업 일몰로 끝났지만,\n내일채움공제는 지금도 가입할 수 있습니다.'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, ink, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '납입 구조',
              [
                '최소 3년 공동납입 · 1년 단위 연장 · 최대 10년',
                '근로자 : 사업주 = 1 : 2 이상 (예: 10만원 대 24만원)',
                '만기에 사업주 기여금 + 본인 납입금 + 연복리 이자를 근로자가 전액 수령',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '세금 (조특법 §29의6)',
              [
                '사업주 기여금은 근로소득 — 소득세를 감면한다',
                '청년: 중소기업 90% · 중견기업 50% 감면',
                '청년이 아니면: 중소기업 50% · 중견기업 30% 감면',
                '3년 이상 납입 + 2027.12.31까지 가입한 경우',
                '기여금과 본인 납입금을 뺀 나머지는 이자소득으로 과세',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '끝난 청년내일채움공제(2년형)',
              [
                '2024년 사업 일몰로 신규가입 불가',
                '기존 가입자는 청년 400만 + 기업 400만 + 정부 400만',
                '만기 1,200만원 + 이자',
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
          Text(title, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
                Expanded(
                    child: Text(item,
                        style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
