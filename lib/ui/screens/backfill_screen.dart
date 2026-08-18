import 'package:flutter/material.dart';

import '../../core/data/db_helper.dart';
import '../../core/data/year_coverage.dart';
import '../components/amount_field.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// **연중에 깐 사람의 1월~지난달을 채운다.**
///
/// 카드 공제 문턱은 총급여의 25%이고 **1월부터의 누적**으로 판정된다. 8월에 깐
/// 사람의 가계부에는 8월분밖에 없으니, 그대로 계산하면 "아직 한참 남았다"는
/// 틀린 말을 하게 된다. 실제로는 이미 넘겼을 수도 있다.
///
/// **추정하지 않는다.** 이 화면은 사용자가 카드사 앱·명세서에서 **보고 옮겨
/// 적는** 자리다. "기억나는 대로"는 받지 않는다 — 세금 숫자는 기억으로 만들면
/// 안 된다. 그래서 안내도 "카드사 앱의 이용금액을 그대로 옮기세요"다.
///
/// 왜 다섯 갈래인가: 엔진은 이미 전통시장 40% · 대중교통 40% · 도서공연 30% ·
/// 체크현금 30% · 신용카드 15%로 나눠 계산한다(`employee_tax.dart`). 가계부가
/// 결제수단 셋만 받아서 그 정밀도를 못 쓰고 있었다. 여기서 받아 채운다.
///
/// **유형마다 묻는 것이 다르다.** 화면을 셋으로 쪼개는 대신 절을 갈랐다 —
/// 같은 저장소·같은 검증·같은 완료 버튼을 세 번 베껴 쓰면 셋이 서로 어긋난다.
///
///   직장인   카드 다섯 갈래
///   프리랜서 사업 총수입·필요경비 (카드공제는 근로소득자 전용이라 안 묻는다)
///   N잡러   둘 다 — 근로소득이 있어 카드공제 대상이면서 사업소득도 있다
class BackfillScreen extends StatefulWidget {
  final String userType;
  const BackfillScreen({super.key, required this.userType});

  @override
  State<BackfillScreen> createState() => _BackfillScreenState();
}

class _BackfillScreenState extends State<BackfillScreen> {
  /// 달마다 한 줄. `_rows[3]!['credit']`처럼 쓴다.
  ///
  /// 합계 한 칸으로 받으면 사용자가 카드사 앱을 보며 일곱 달치를 손으로 더해야
  /// 한다. 더하다 틀리면 그 값이 그대로 세금 계산에 들어간다 — 더하기는 앱이 한다.
  final Map<int, Map<String, TextEditingController>> _rows = {};
  final _market = TextEditingController();
  final _transport = TextEditingController();
  final _culture = TextEditingController();
  final _bizIncome = TextEditingController();
  final _bizExpense = TextEditingController();

  /// 근로소득이 있는가 — 카드공제는 근로소득자만 받는다(조특법 §126의2).
  bool get _hasCard => widget.userType == '직장인' || widget.userType == 'N잡러';

  /// 사업소득이 있는가 — 총수입·경비를 채워야 종소세 셈이 맞는다.
  bool get _hasBiz => widget.userType == '프리랜서' || widget.userType == 'N잡러';

  /// 가계부에 이미 들어와 있는 올해 신용카드 누계 — 특례 합의 상한이다.
  double _ledgerCredit = 0;
  bool _loading = true;
  String? _error;

  int get _year => DateTime.now().year;
  int get _lastMonth => DateTime.now().month - 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 이 유형이 달마다 채우는 칸 이름.
  List<String> get _cols => [
        if (_hasBiz) 'bizIncome',
        if (_hasBiz) 'bizExpense',
        if (_hasCard) 'credit',
        if (_hasCard) 'debit',
      ];

  static const _colLabel = {
    'bizIncome': '총수입',
    'bizExpense': '경비',
    'credit': '신용카드',
    'debit': '체크·현금',
  };

  @override
  void dispose() {
    for (final row in _rows.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    for (final c in [_market, _transport, _culture]) {
      c.dispose();
    }
    super.dispose();
  }

  double _sum(String col) => _rows.values
      .fold<double>(0, (t, r) => t + (_v(r[col]!)));

  Future<void> _load() async {
    final saved = await YearCoverage.monthly(_year);
    final s = await YearCoverage.specials(_year);
    for (var m = 1; m <= _lastMonth; m++) {
      _rows[m] = {for (final c in _cols) c: TextEditingController()};
      final v = saved[m];
      if (v == null) continue;
      void put(String col, double n) {
        if (n > 0) _rows[m]![col]?.text = n.toInt().toString();
      }
      put('credit', v.credit);
      put('debit', v.debit);
      put('bizIncome', v.bizIncome);
      put('bizExpense', v.bizExpense);
    }
    final firstOfYear = DateTime(_year, 1, 1);
    final now = DateTime.now();
    var credit = 0.0;
    for (final e in await dbService.getExpenses()) {
      if (e.date.isBefore(firstOfYear) || e.date.isAfter(now)) continue;
      if (e.paymentMethod == '신용카드') credit += e.amount;
    }
    if (!mounted) return;
    setState(() {
      _ledgerCredit = credit;
      if (s.market > 0) _market.text = s.market.toInt().toString();
      if (s.transport > 0) _transport.text = s.transport.toInt().toString();
      if (s.culture > 0) _culture.text = s.culture.toInt().toString();
      _loading = false;
    });
  }

  double _v(TextEditingController? c) =>
      double.tryParse((c?.text ?? '').replaceAll(',', '')) ?? 0;

  /// 특례 셋을 뺄 수 있는 신용카드 총액 — 채워 넣은 것 + 가계부에 있는 것.
  double get _creditPool => _sum('credit') + _ledgerCredit;

  Future<void> _save() async {
    final specials = CardSpecials(
      market: _v(_market),
      transport: _v(_transport),
      culture: _v(_culture),
    );
    // 특례가 신용카드 총액을 넘으면 같은 돈을 두 번 세게 된다.
    if (specials.total > _creditPool) {
      setState(() => _error =
          '전통시장·대중교통·도서 합이 신용카드 총액보다 많아요. '
          '신용카드로 쓴 돈 안에서 나눠 적어주세요.');
      return;
    }
    await YearCoverage.setMonthly(_year, {
      for (final e in _rows.entries)
        e.key: Backfill(
          credit: _v(e.value['credit']),
          debit: _v(e.value['debit']),
          bizIncome: _v(e.value['bizIncome']),
          bizExpense: _v(e.value['bizExpense']),
        ),
    });
    await YearCoverage.setSpecials(_year, specials);
    await YearCoverage.markComplete(_year);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      appBar: AppBar(title: Text('1~$_lastMonth월 채우기')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(height: 64, child: _bottomBar()),
      ),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  Text(
                    '카드사 앱이나 명세서를 열어 **보고 옮겨** 적어주세요. '
                            '기억으로 적으면 세금 계산이 틀어져요.'
                        .replaceAll('**', '')
                        .keepWords,
                    style: AppTheme.sans(AppTheme.tsSM, sub, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  AppTheme.sectionHead(context, '01', '달마다 적어주세요'),
                  const SizedBox(height: 4),
                  Text(
                    _hasBiz && _hasCard
                        ? '지급명세서와 카드사 앱이 달별로 보여줘요. 그대로 옮기시면 돼요.'
                        : _hasBiz
                            ? '지급명세서가 달별로 나와요. 그대로 옮기시면 돼요.'
                            : '카드사 앱이 달별 이용금액을 보여줘요. 그대로 옮기시면 돼요.'
                            .keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  for (var m = 1; m <= _lastMonth; m++) _monthRow(m),
                  const SizedBox(height: 10),
                  _totalsRow(),
                  const SizedBox(height: 26),
                  if (_hasCard) ...[
                  AppTheme.sectionHead(context, '02', '그중 이런 데 쓴 돈'),
                  const SizedBox(height: 6),
                  Text(
                    '공제율이 더 높은 것들이에요. 위 신용카드 금액 안에서 '
                            '얼마인지 적어주세요 — 따로 더하는 게 아니에요. '
                            '이번 달부터는 가계부에 적을 때 「공제 구분」으로 고르면 '
                            '알아서 반영되니, 여기는 1~$_lastMonth월치만 적으시면 돼요.'
                        .keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  _field('전통시장', _market, tag: '40%'),
                  _field('대중교통', _transport, tag: '40%'),
                  _field('도서·공연·영화', _culture, tag: '30%'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!.keepWords,
                        style: AppTheme.sans(AppTheme.tsSM,
                            AppTheme.colorDanger,
                            height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '안 쓴 항목은 비워 두세요. 0으로 칩니다.'.keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.5),
                  ),
                ],
              ),
      ),
    );
  }

  /// 한 달 = 한 줄. 왼쪽에 «3월», 오른쪽에 이 유형이 채울 칸들.
  Widget _monthRow(int m) {
    final row = _rows[m];
    if (row == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('$m월',
                  style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context))),
            ),
          ),
          for (final col in _cols) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름은 **첫 줄에만** 단다. 일곱 줄에 같은 이름이 반복되면
                  // 표가 아니라 목록처럼 읽혀 눈이 세로로 못 흐른다.
                  if (m == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(_colLabel[col]!, style: AppTheme.label(context)),
                    ),
                  AmountField(
                    controller: row[col]!,
                    expand: true,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ],
              ),
            ),
            if (col != _cols.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// 앱이 더한다 — 사용자가 일곱 달치를 손으로 더하다 틀리면 그 값이 세금이 된다.
  Widget _totalsRow() {
    final ink = AppTheme.ink(context);
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.line(context))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('합계', style: AppTheme.sans(AppTheme.tsSM, ink,
                weight: FontWeight.w700)),
          ),
          for (final col in _cols) ...[
            Expanded(
              child: Text(comma(_sum(col).toInt()),
                  textAlign: TextAlign.right,
                  style: AppTheme.sans(AppTheme.tsSM, ink,
                      weight: FontWeight.w700)),
            ),
            if (col != _cols.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, String? tag}) {
    final sub = AppTheme.inkSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: AppTheme.sans(AppTheme.tsMD, AppTheme.ink(context),
                    weight: FontWeight.w600)),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Text(tag, style: AppTheme.label(context)),
            ],
          ]),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint.replaceAll('**', '').keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
          ],
          const SizedBox(height: 6),
          AmountField(controller: c, expand: true, onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          }),
        ],
      ),
    );
  }

  Widget _bottomBar() => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.line(context))),
          color: AppTheme.backgroundColor(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _save,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                color: AppTheme.ink(context),
                // 「저장」이 아니라 「다 넣었어요」다. 무엇을 저장하는지가 아니라
                // **이제 한 해가 다 채워졌다**는 확인을 받는 자리다.
                child: Text('1~$_lastMonth월 다 넣었어요',
                    style: AppTheme.sans(AppTheme.tsMD,
                        AppTheme.backgroundColor(context),
                        weight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      );
}
