import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class JeonseInsuranceScreen extends StatefulWidget {
  const JeonseInsuranceScreen({super.key});

  @override
  State<JeonseInsuranceScreen> createState() => _JeonseInsuranceScreenState();
}

class _JeonseInsuranceScreenState extends State<JeonseInsuranceScreen> {
  final _depositCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController(text: '24');
  int _ltvIdx = 0;

  /// HUG 전세보증금반환보증 요율은 보증금·주택유형·부채비율에 따라
  /// 0.115~0.154%로 갈린다(khug.or.kr). 계산기는 중간값을 쓴다 —
  /// 정확한 요율은 신청 시 산출되므로 예상액으로만 본다.
  static const _hugRate = 0.128;

  /// HF 「일반전세지킴보증」 요율 — LTV 구간 → (표기, 연 %).
  ///
  /// 2025.3.1 신규 신청분부터 LTV로 갈린다(hf.go.kr 공지 597995).
  /// 종전에는 0.04% 한 줄에 "청년 0.02%" 토글이 달려 있었다. 0.04%는
  /// LTV 70% 이하일 때뿐이고, 80~90%면 0.18%로 네 배 반이다.
  /// 청년 0.02%라는 요율은 안내에 없다 — 우대가구는 0.01~0.03%p 인하다.
  static const _hfBands = <(String, double)>[
    ('LTV 70% 이하', 0.04),
    ('70% 초과 80% 이하', 0.11),
    ('80% 초과 90% 이하', 0.18),
  ];

  @override
  void dispose() {
    _depositCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _depositCtrl.clear();
        _monthsCtrl.text = '24';
        _ltvIdx = 0;
      });

  int get _deposit => int.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
  int get _months => int.tryParse(_monthsCtrl.text.replaceAll(',', '')) ?? 0;

  double get _hfRate => _hfBands[_ltvIdx].$2;

  ({int hug, int hf})? get _result {
    if (_deposit <= 0 || _months <= 0 || _months > 120) return null;
    final years = _months / 12;
    return (
      hug: (_deposit * _hugRate / 100 * years).round(),
      hf: (_deposit * _hfRate / 100 * years).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final accentSoft = AppTheme.accentSoft(context);
    final r = _result;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('전세보증보험료 계산',
            style: AppTheme.serif(AppTheme.serifMD, ink,
                weight: FontWeight.w400, spacing: -0.5)),
        actions: [
          IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20, color: tert),
              onPressed: _reset),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전세보증금과 보증기간을 입력하면\nHUG·HF 보증료를 나란히 볼 수 있어요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('전세보증금', _depositCtrl),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('보증기간', _monthsCtrl, '개월'),
            Divider(height: 1, thickness: 1, color: line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HF 요율 구간 (LTV)', style: AppTheme.sans(AppTheme.tsBase, ink)),
                  const SizedBox(height: 2),
                  Text('LTV = (선순위채권 + 전세보증금) ÷ 주택가격'.keepWords,
                      style: AppTheme.sans(AppTheme.tsSM, sub)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < _hfBands.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _ltvIdx = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _ltvIdx == i ? accentSoft : null,
                                border: Border.all(
                                    color: _ltvIdx == i ? accent : line),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${_hfBands[i].$2}%',
                                  style: AppTheme.sans(AppTheme.tsSM,
                                      _ltvIdx == i ? accent : sub,
                                      weight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_hfBands[_ltvIdx].$1,
                      style: AppTheme.sans(AppTheme.tsSM, sub)),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            const SizedBox(height: 24),
            if (r == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Text('전세보증금·보증기간을 입력하세요.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsMD, sub)),
              )
            else ...[
              _institutionCard('HUG (주택도시보증공사)', _hugRate, r.hug, true,
                  accent, accentSoft, ink, sub, line),
              const SizedBox(height: 8),
              _institutionCard('HF (한국주택금융공사)', _hfRate, r.hf, false,
                  accent, AppTheme.surface(context), ink, sub, line),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('두 기관 비교',
                        style: AppTheme.sans(AppTheme.tsMD, ink,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _compareRow('HUG', r.hug, r.hug, ink, sub, line),
                    _compareRow('HF', r.hf, r.hug, ink, sub, line, last: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _rateTable(sub, ink, line),
            const SizedBox(height: 16),
            _notice(sub, ink, const [
              'HUG 보증한도: 수도권 7억원·그 밖의 지역 5억원.',
              'HF 보증한도: 수도권 7억원·그 밖의 지역 5억원, 그리고 주택가액의 90%에서 선순위채권을 뺀 금액.',
              'HF 요율은 2025.3.1 신규 신청분부터 LTV로 갈립니다. 우대가구는 0.01~0.03%p 더 내려갑니다.',
              'HUG는 모바일 신청 3%, 보증료 일시납 3%를 깎아 줍니다.',
              'SGI서울보증도 같은 보증을 팔지만 요율표를 원문으로 확인하지 못해 뺐습니다.',
              '정확한 요율·가입 조건은 각 기관 홈페이지를 확인하세요.',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _institutionCard(String name, double rate, int premium, bool primary,
      Color accent, Color bg, Color ink, Color sub, Color line) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: primary ? accent : line),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: AppTheme.sans(AppTheme.tsMD, ink,
                      weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  '연 ${rate.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}%',
                  style: AppTheme.sans(AppTheme.tsSM, sub)),
            ],
          ),
          Text('${comma(premium)}원',
              style: AppTheme.serif(AppTheme.serifMD,
                  primary ? accent : ink,
                  weight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _compareRow(String label, int premium, int baseline, Color ink,
      Color sub, Color line, {bool last = false}) {
    final pct = baseline > 0 ? premium / baseline * 100 : 100.0;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 70,
            child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub)),
          ),
          Expanded(
            child: Stack(children: [
              Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: AppTheme.accentColor(context).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3))),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text('${comma(premium)}원',
                textAlign: TextAlign.right,
                style: AppTheme.sans(AppTheme.tsSM, ink,
                    weight: FontWeight.w600)),
          ),
        ]),
      ),
      if (!last) Divider(height: 1, thickness: 1, color: line),
    ]);
  }

  Widget _rateTable(Color sub, Color ink, Color line) {
    final rows = [
      ('HUG', '0.115~0.154%', '보증금·주택유형·부채비율'),
      for (final (label, rate) in _hfBands) ('HF', '$rate%', label),
    ];
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text('기관별 연간 보증료율',
              style: AppTheme.sans(AppTheme.tsSM, sub, weight: FontWeight.w600)),
        ),
        Divider(height: 1, thickness: 1, color: line),
        ...rows.asMap().entries.map((e) => Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  SizedBox(
                    width: 90,
                    child: Text(e.value.$1,
                        style: AppTheme.sans(AppTheme.tsSM, ink,
                            weight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(e.value.$2,
                        style: AppTheme.sans(AppTheme.tsSM, ink)),
                  ),
                  Expanded(
                    child: Text(e.value.$3,
                        style: AppTheme.sans(AppTheme.tsSM, sub)),
                  ),
                ]),
              ),
              if (e.key < rows.length - 1)
                Divider(height: 1, thickness: 1, color: line, indent: 12),
            ])),
      ]),
    );
  }

  Widget _amountRow(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context)))),
          const SizedBox(width: 12),
          AmountField(controller: ctrl, onChanged: (_) => setState(() {})),
        ]),
      );

  Widget _numRow(String label, TextEditingController ctrl, String suffix) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsBase, ink))),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            style: AppTheme.sans(AppTheme.tsBase, ink),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: AppTheme.sans(AppTheme.tsSM, sub),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: accent, width: 1.5)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _notice(Color sub, Color ink, List<String> items) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: sub.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: sub),
              const SizedBox(width: 6),
              Text('알아두기',
                  style: AppTheme.sans(AppTheme.tsMD, ink,
                      weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            ...items.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $s',
                      style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.55)),
                )),
          ],
        ),
      );
}
