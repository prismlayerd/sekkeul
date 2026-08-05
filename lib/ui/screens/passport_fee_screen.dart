import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class PassportFeeScreen extends StatefulWidget {
  const PassportFeeScreen({super.key});

  @override
  State<PassportFeeScreen> createState() => _PassportFeeScreenState();
}

class _PassportFeeScreenState extends State<PassportFeeScreen> {
  int _idx = 0;
  final _fmt = NumberFormat('#,###');

  // 종류, 유효기간, 수수료(원)
  static const _types = [
    // 외교부 여권안내(passport.go.kr) 수수료표. 확인일 2026-08-02.
    // 성인 10년 여권은 발급비 + 국제교류기여금 12,000원 합산액이다.
    ('복수여권(성인) 58면', '10년', 52000),
    ('복수여권(성인) 26면', '10년', 49000),
    ('복수여권(만 8~17세) 58면', '5년', 44000),
    ('복수여권(만 8~17세) 26면', '5년', 41000),
    ('복수여권(만 8세 미만) 58면', '5년', 35000),
    ('복수여권(만 8세 미만) 26면', '5년', 32000),
    ('단수여권', '1년', 17000),
    ('잔여유효기간 재발급', '이전 여권 잔여기간', 27000),
    ('긴급여권', '1년', 50000),
  ];

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);
    final selected = _types[_idx];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('여권 발급 수수료',
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('여권 종류',
                style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _idx,
                  isExpanded: true,
                  style: AppTheme.sans(14, ink),
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: [
                    for (int i = 0; i < _types.length; i++)
                      DropdownMenuItem(
                          value: i,
                          child: Text(_types[i].$1,
                              style: AppTheme.sans(14, ink))),
                  ],
                  onChanged: (v) => setState(() => _idx = v!),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('발급 수수료',
                      style:
                          AppTheme.sans(11, sub, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(_won(selected.$3),
                      style: AppTheme.sans(20, accent, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 12),
                  _row('유효기간', selected.$2, ink, sub),
                  const SizedBox(height: 8),
                  Text('* 2026.3.1부터 재외공관 발급 여권 수수료는 USD 2 인상되었습니다.'.keepWords,
                      style: AppTheme.sans(11, sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoBox(
              '발급 절차',
              [
                '외교부 여권안내·정부24에서 사진·서류 사전 준비',
                '시·군·구청, 출입국·외국인청, 일부 우체국 방문 또는 온라인 신청',
                '지문·얼굴 촬영(본인 방문 필수) + 서류 제출 + 수수료 납부',
                '약 4~6주 후 본인 수령(신분증 지참), 긴급 사유 시 약 1주 가능',
              ],
              line,
              sub,
              ink,
            ),
            const SizedBox(height: 12),
            _infoBox(
              '필요 서류',
              [
                '6개월 이내 촬영 여권사진 1매(35×45mm, 흰색 배경)',
                '신분증(주민등록증·운전면허증 등), 여권발급 신청서',
                '만 18~37세 남성: 국외여행허가서 또는 병적증명서',
                '미성년자: 가족관계증명서·기본증명서·법정대리인 신분증 추가',
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

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(13, sub))),
        Text(value, style: AppTheme.sans(13, ink, weight: FontWeight.w600)),
      ],
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
