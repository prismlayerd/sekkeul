import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

/// 모두의카드(옛 K-패스) — 기본형(비율 환급)과 정액형 중 어느 쪽이 싼지 본다.
///
/// 종전에는 K-패스와 서울 기후동행카드를 비교했다. 기후동행카드는 2026.9.1부터
/// 기후동행패스로 바뀌면서 30일권이 끝났고(선불 8.31 충전 마감·최대 9.29 사용,
/// 후불 9.30까지), 서울도 모두의카드 위에 얹는 방식이 되어 비교 대상이 아니다.
/// 지금 갈리는 것은 같은 카드 안의 기본형과 정액형이다.
class KpassClimateCardScreen extends StatefulWidget {
  const KpassClimateCardScreen({super.key});

  @override
  State<KpassClimateCardScreen> createState() => _KpassClimateCardScreenState();
}

class _KpassClimateCardScreenState extends State<KpassClimateCardScreen> {
  final _ridesCtrl = TextEditingController(text: '30');
  final _fareCtrl = TextEditingController(text: '1500');
  int _type = 0;
  int _region = 0;

  // 대광위 「모두의카드」 정률제 환급률표. 유형 순서는 아래 기준금액표의 행 순서와 같다.
  static const _typeLabels = ['일반', '청년·2자녀·어르신', '3자녀', '저소득'];
  static const _typeNotes = [
    '만 35세 이상 65세 미만',
    '청년 19~34세 · 미성년 2자녀 부모 · 어르신 65세 이상',
    '미성년자를 포함한 3자녀 부모',
    '기초생활수급자 또는 차상위계층',
  ];
  static const _rates = [20.0, 30.0, 50.0, 53.3];

  static const _regionLabels = ['수도권', '일반 지방권', '우대지원', '특별지원'];

  /// [유형][지역] → (일반형, 플러스형) 환급 기준금액(원).
  /// 정액형은 이 금액을 넘게 쓰면 초과분을 전액 돌려준다.
  /// 일반형은 환승 포함 1회 요금이 3,000원 미만인 수단에만, 플러스형은 모든 수단에.
  static const _base = [
    [(62000, 100000), (55000, 95000), (50000, 90000), (45000, 85000)],
    [(55000, 90000), (50000, 85000), (45000, 80000), (40000, 75000)],
    [(45000, 80000), (40000, 75000), (35000, 70000), (30000, 65000)],
    [(45000, 80000), (40000, 75000), (35000, 70000), (30000, 65000)],
  ];

  /// 고유가 한시 기준금액(2026.4.1~9.30). 같은 기간 시차 출퇴근 시간대
  /// (5:30~6:30, 9~10, 16~17, 19~20시 승차)의 환급률도 따로 올라간다.
  static const _temp = [
    [(30000, 50000), (27000, 47000), (25000, 45000), (22000, 42000)],
    [(25000, 45000), (23000, 42000), (21000, 40000), (20000, 37000)],
    [(22000, 40000), (20000, 37000), (17000, 35000), (15000, 32000)],
    [(22000, 40000), (20000, 37000), (17000, 35000), (15000, 32000)],
  ];

  static final _tempEnds = DateTime(2026, 10, 1);
  bool get _tempOn => DateTime.now().isBefore(_tempEnds);

  (int, int) get _threshold => (_tempOn ? _temp : _base)[_type][_region];

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  int get _rides => _num(_ridesCtrl).clamp(0, 200).toInt();
  double get _fare => _num(_fareCtrl);

  double get _spend => _rides * _fare;

  /// 기본형은 월 15회 이상 써야 준다 (가입 첫 달만 예외). 상한은 없다.
  bool get _basicQualifies => _rides >= 15;
  double get _basicRefund =>
      _basicQualifies ? _spend * (_rates[_type] / 100) : 0;
  double get _basicCost => _spend - _basicRefund;

  double _flatCost(int threshold) =>
      _spend < threshold ? _spend : threshold.toDouble();

  bool get _hasInput => _rides > 0 && _fare > 0;

  String _pct(double v) => v == v.roundToDouble() ? '${v.round()}%' : '$v%';

  @override
  void dispose() {
    _ridesCtrl.dispose();
    _fareCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accentColor(context);
    final bg = AppTheme.surface(context);

    final (plain, plus) = _threshold;
    final costs = {
      '기본형': _basicCost,
      '정액 일반형': _flatCost(plain),
      '정액 플러스형': _flatCost(plus),
    };
    final cheapest =
        costs.entries.reduce((a, b) => a.value <= b.value ? a : b).key;

    return Scaffold(
      appBar: AppBar(
        title: Text('모두의카드 기본형·정액형 비교'.keepWords,
            style: AppTheme.serif(AppTheme.tsBase, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _numField('월 평균 대중교통 이용 횟수', _ridesCtrl, '회', ink, sub, line),
            const SizedBox(height: 16),
            _numField('1회 평균 요금', _fareCtrl, '원', ink, sub, line),
            const SizedBox(height: 20),
            Text('대상 유형',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _typeLabels.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _type = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          border:
                              Border.all(color: _type == i ? accent : line),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(_typeLabels[i],
                          style: AppTheme.sans(
                              AppTheme.tsXS, _type == i ? accent : ink,
                              weight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_typeNotes[_type],
                style: AppTheme.sans(AppTheme.tsSM, sub)),
            const SizedBox(height: 20),
            Text('지역 구분',
                style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _regionLabels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _segButton(_regionLabels[i], _region == i,
                        () => setState(() => _region = i), ink, line, accent),
                  ),
                ],
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
                    Text('월 실부담 비교',
                        style: AppTheme.sans(AppTheme.tsXS, sub,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('가장 싼 쪽',
                            style: AppTheme.sans(AppTheme.tsMD, ink,
                                weight: FontWeight.w700)),
                        Text(cheapest,
                            style: AppTheme.sans(AppTheme.tsBase, accent,
                                weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: line),
                    const SizedBox(height: 12),
                    _row('월 교통비 지출', won(_spend), ink, sub),
                    const SizedBox(height: 8),
                    _row('기본형 환급액 (${_pct(_rates[_type])})',
                        won(_basicRefund), ink, sub),
                    const SizedBox(height: 8),
                    for (final e in costs.entries) ...[
                      _row('${e.key} 실부담', won(e.value), ink, sub),
                      const SizedBox(height: 8),
                    ],
                    Text(
                        '* 정액형 기준금액 — 일반형 ${comma(plain)}원 · '
                        '플러스형 ${comma(plus)}원'
                        '${_tempOn ? " (2026.4.1~9.30 한시 반값)" : ""}'
                            .keepWords,
                        style: AppTheme.sans(AppTheme.tsXS, sub)),
                    if (!_basicQualifies) ...[
                      const SizedBox(height: 4),
                      Text('* 월 15회 미만이면 기본형 환급이 없습니다.'.keepWords,
                          style: AppTheme.sans(AppTheme.tsXS, sub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _infoBox('두 가지 방식', const [
              '기본형(정률제): 쓴 금액의 일정 비율을 돌려준다',
              '정액형(정액제): 기준금액을 넘게 쓰면 초과분을 전액 돌려준다',
              '둘 중 어느 쪽을 고를 필요는 없다 — 시스템이 매달 더 큰 쪽으로 준다',
              '월 15회 이상 이용한 달에만 환급된다 (가입 첫 달은 15회 미만도 준다)',
              '이용 횟수 상한은 없다',
              '정액 일반형은 시내버스·전철용이고, 플러스형은 광역버스·GTX까지 된다'
                  ' (1회 총이용금액 3,000원 미만이 일반형)',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('환급률', const [
              '일반 20% · 청년(19~34세)·2자녀·어르신(65세 이상) 30%',
              '3자녀 이상 50% · 저소득(수급자·차상위) 53.3%',
              '다자녀·저소득은 앱이나 누리집에서 따로 신청해야 적용된다',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('2026.4.1~9.30 한시', const [
              '시차 시간대(5:30~6:30, 9~10, 16~17, 19~20시 승차)에 타면'
                  ' 기본형 환급률이 30%p 올라간다',
              '일반 50% · 청년·2자녀·어르신 60% · 3자녀 80% · 저소득 83.3%',
              '정액형 기준금액도 같은 기간 절반 수준으로 내려간다',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('기후동행카드는 끝났다', const [
              '2026.9.1부터 서울 기후동행패스로 바뀌었다',
              '선불 30일권은 8.31까지만 충전, 최대 9.29까지 사용',
              '후불카드는 9.30까지, 10.1부터 일반 교통카드가 된다',
              '단기권(1·2·3·5·7일권)은 그대로 운영된다',
              '청년 할인은 만 19~34세에서 19~39세로 넓어졌고,'
                  ' 이용 범위도 서울에서 전국으로 확대됐다',
            ], line, sub, ink),
            const SizedBox(height: 12),
            _infoBox('지급', const [
              '적립월의 익월 7영업일에 카드사로 지급 요청된다',
              '카드사마다 계좌 입금·결제대금 차감·포인트로 방식이 다르다',
              '전용 카드를 발급받고 korea-pass.kr에 회원가입·카드등록까지 해야 적립된다',
            ], line, sub, ink),
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
        Text(label, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
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
          style: AppTheme.sans(AppTheme.tsMD, ink),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: AppTheme.sans(AppTheme.tsMD, sub),
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

  Widget _segButton(
      String label, bool selected, VoidCallback onTap, Color ink, Color line, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: selected ? accent : line),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: AppTheme.sans(AppTheme.tsXS, selected ? accent : ink, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub))),
        Text(value, style: AppTheme.sans(AppTheme.tsSM, ink, weight: FontWeight.w600)),
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
          Text(title, style: AppTheme.sans(AppTheme.tsXS, sub, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTheme.sans(AppTheme.tsSM, sub)),
                Expanded(child: Text(item, style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5))),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
