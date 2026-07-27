import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isYouth = false;
  final _fmt = NumberFormat('#,###');

  static const _hugRate = 0.128;
  static const _hfRateGeneral = 0.04;
  static const _hfRateYouth = 0.02;
  static const _sgiRate = 0.183;

  @override
  void dispose() {
    _depositCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _depositCtrl.clear();
        _monthsCtrl.text = '24';
        _isYouth = false;
      });

  int get _deposit => int.tryParse(_depositCtrl.text.replaceAll(',', '')) ?? 0;
  int get _months => int.tryParse(_monthsCtrl.text.replaceAll(',', '')) ?? 0;

  ({int hug, int hf, int sgi})? get _result {
    if (_deposit <= 0 || _months <= 0 || _months > 120) return null;
    final years = _months / 12;
    final hfRate = _isYouth ? _hfRateYouth : _hfRateGeneral;
    return (
      hug: (_deposit * _hugRate / 100 * years).round(),
      hf: (_deposit * hfRate / 100 * years).round(),
      sgi: (_deposit * _sgiRate / 100 * years).round(),
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
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
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
            Text('전세보증금과 보증기간을 입력하면\nHUG·HF·SGI 3개 기관 보증료를 한눈에 비교해드려요.'.keepWords,
                style: AppTheme.sans(AppTheme.tsLG, ink, height: 1.5)),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: line),
            _amountRow('전세보증금', _depositCtrl),
            Divider(height: 1, thickness: 1, color: line),
            _numRow('보증기간', _monthsCtrl, '개월'),
            Divider(height: 1, thickness: 1, color: line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('청년 할인 (HF)', style: AppTheme.sans(AppTheme.tsBase, ink)),
                      const SizedBox(height: 2),
                      Text('만 34세 이하 · HF 요율 0.02% 적용'.keepWords,
                          style: AppTheme.sans(AppTheme.tsSM, sub)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isYouth = !_isYouth),
                    child: Container(
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _isYouth ? accent : line,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 180),
                        alignment: _isYouth
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
              _institutionCard(
                  'HF (한국주택금융공사)',
                  _isYouth ? _hfRateYouth : _hfRateGeneral,
                  r.hf,
                  false,
                  accent,
                  AppTheme.surface(context),
                  ink,
                  sub,
                  line),
              const SizedBox(height: 8),
              _institutionCard('SGI (서울보증보험)', _sgiRate, r.sgi, false,
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
                    Text('3개 기관 비교',
                        style: AppTheme.sans(AppTheme.tsMD, ink,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _compareRow('HUG', r.hug, r.hug, ink, sub, line),
                    _compareRow(
                        _isYouth ? 'HF (청년)' : 'HF', r.hf, r.hug, ink, sub, line),
                    _compareRow('SGI', r.sgi, r.hug, ink, sub, line, last: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _rateTable(sub, ink, line),
            const SizedBox(height: 16),
            _notice(sub, ink, const [
              'HUG: 아파트 위주, 보증금 수도권 7억·지방 5억 이하.',
              'HF: 아파트·다세대 등, 보증금 수도권 7억·지방 5억 이하.',
              'SGI: 제한 없으나 보증료가 가장 높습니다.',
              '청년 할인은 HF만 해당 (만 34세 이하 단독세대주).',
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
          Text('${_fmt.format(premium)}원',
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
            child: Text('${_fmt.format(premium)}원',
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
      ('HUG', '0.128%', '-'),
      ('HF (일반)', '0.040%', '-'),
      ('HF (청년)', '0.020%', '만 34세 이하'),
      ('SGI', '0.183%', '-'),
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
