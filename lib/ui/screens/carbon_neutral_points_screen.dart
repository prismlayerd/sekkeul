import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/calc_disclaimer.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

class CarbonNeutralPointsScreen extends StatefulWidget {
  const CarbonNeutralPointsScreen({super.key});

  @override
  State<CarbonNeutralPointsScreen> createState() => _CarbonNeutralPointsScreenState();
}

class _CarbonNeutralPointsScreenState extends State<CarbonNeutralPointsScreen> {
  final _receiptCtrl = TextEditingController();
  final _tumblerCtrl = TextEditingController();
  final _cupReturnCtrl = TextEditingController();
  final _refillCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();
  bool _solar = false;
  bool _greenBuy = false;
  final _fmt = NumberFormat('#,###');

  static const double _annualCap = 70000;

  double _num(TextEditingController c) => saneInput(
      double.tryParse(c.text.replaceAll(',', '')) ?? 0, InputMax.count);

  double _capped(double value, double limit) => value > limit ? limit : value;

  // 단가는 2026.1.1 개편분이다(cpoint.or.kr 인센티브 안내).
  // 전자영수증만 별도 연간한도 7만원이 명시돼 있고, 나머지는 전체 상한 7만원만 걸린다 —
  // 원문에 없는 항목별 한도를 지어내지 않는다.
  double get _receiptPoints => _capped(_num(_receiptCtrl) * 12 * 10, _annualCap);
  double get _tumblerPoints => _num(_tumblerCtrl) * 12 * 300;
  double get _cupReturnPoints => _num(_cupReturnCtrl) * 12 * 100;
  double get _refillPoints => _num(_refillCtrl) * 12 * 500;
  double get _deliveryPoints => _num(_deliveryCtrl) * 12 * 500;
  double get _solarPoints => _solar ? 10000 : 0;
  double get _greenBuyPoints => _greenBuy ? 500 * 12 : 0;

  double get _totalRaw =>
      _receiptPoints +
      _tumblerPoints +
      _cupReturnPoints +
      _refillPoints +
      _deliveryPoints +
      _solarPoints +
      _greenBuyPoints;
  double get _total => _totalRaw > _annualCap ? _annualCap : _totalRaw;
  bool get _isCapped => _totalRaw > _annualCap;

  bool get _hasInput => _totalRaw > 0;

  String _won(double v) => '${_fmt.format(v.round())}원';

  @override
  void dispose() {
    _receiptCtrl.dispose();
    _tumblerCtrl.dispose();
    _cupReturnCtrl.dispose();
    _refillCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('탄소중립포인트',
            style: AppTheme.serif(16, ink, weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('전자영수증 발급(월)', _receiptCtrl, '건', ink, sub, line),
            const SizedBox(height: 12),
            _numField('텀블러·다회용컵 사용(월)', _tumblerCtrl, '회', ink, sub, line),
            const SizedBox(height: 12),
            _numField('일회용컵 보증금 반환(월)', _cupReturnCtrl, '개', ink, sub, line),
            const SizedBox(height: 12),
            _numField('리필스테이션 이용(월)', _refillCtrl, '회', ink, sub, line),
            const SizedBox(height: 12),
            _numField('다회용기 배달주문(월)', _deliveryCtrl, '건', ink, sub, line),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _solar,
                  onChanged: (v) => setState(() => _solar = v ?? false),
                  activeColor: accent,
                ),
                Expanded(
                    child:
                        Text('가정용 베란다 태양광 설치(연 1회)'.keepWords, style: AppTheme.sans(13, ink))),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _greenBuy,
                  onChanged: (v) => setState(() => _greenBuy = v ?? false),
                  activeColor: accent,
                ),
                Expanded(child: Text('친환경제품 구매(매월 1건)', style: AppTheme.sans(13, ink))),
              ],
            ),
            const SizedBox(height: 32),
            if (_hasInput) ...[
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
                    Text('연간 예상 포인트', style: AppTheme.sans(11, sub, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('연간 총 포인트',
                            style: AppTheme.sans(14, ink, weight: FontWeight.w700)),
                        Text(_won(_total),
                            style: AppTheme.sans(16, accent, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('전자영수증(연 상한 10,000원)', _won(_receiptPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('텀블러·다회용컵', _won(_tumblerPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('일회용컵 보증금 반환', _won(_cupReturnPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('리필스테이션', _won(_refillPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('다회용기 배달주문', _won(_deliveryPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('가정용 베란다 태양광', _won(_solarPoints), ink, sub),
                    const SizedBox(height: 8),
                    _row('친환경제품 구매', _won(_greenBuyPoints), ink, sub),
                    if (_isCapped) ...[
                      const SizedBox(height: 12),
                      Text('* 1인당 연간 지급 한도 7만원을 초과하여 상한으로 산정되었습니다.'.keepWords,
                          style: AppTheme.sans(11, sub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('참여 방법', const [
              '탄소중립포인트 녹색생활 실천 포털(cpoint.or.kr)에서 본인인증 후 회원가입',
              '카드 포인트, 계좌이체, 그린카드 상품권 등 지급 방식 선택',
              '제휴 소매점·배달앱·카드사 서비스와 연동하여 실적이 자동 집계됩니다.',
              '만 14세 이상 대한민국 국민이 대상입니다.',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('주요 유의사항', const [
              '1인당 연간 지급 한도는 7만원입니다.',
              '전자영수증은 건당 10원이며 연간 7만원까지 인정됩니다.',
              '적립 포인트는 매월 자동 정산되며, 세부 단가는 환경부 고시에 따라 변동될 수 있습니다.',
            ], line, sub, ink),
            const CalcDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String suffix,
      Color ink, Color sub, Color line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          inputFormatters: [
            if (suffix == '원' || suffix == '만원')
              const ThousandsFormatter()
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          style: AppTheme.sans(14, ink),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: AppTheme.sans(14, sub),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
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

  Widget _infoBox(String title, List<String> items, Color line, Color sub, Color ink) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
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
                Expanded(child: Text(item, style: AppTheme.sans(13, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
