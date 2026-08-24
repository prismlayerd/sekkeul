import 'package:flutter/material.dart';

import '../../../core/data/other_income.dart';
import '../../../core/data/year_snapshot.dart';
import '../../components/amount_field.dart';
import '../../components/section_accordion.dart';
import '../../theme/app_theme.dart';
import '../../theme/text_wrap.dart';

/// 홈 1장의 `02 · 다른 소득` — **급여 말고 들어온 돈을 한자리에 모은다.**
///
/// 근로소득「만」 있는 사람은 5월 신고를 안 해도 된다(소법 §73①1). 그 「만」이
/// 깨지는 순간을 앱이 알아야 하는데, 지금까지는 알 길이 없었다 — 직장인 가계부는
/// 급여와 기타소득만 받았고 금융·임대는 어느 유형도 안 받았다.
///
/// 두 갈래로 모은다.
/// - **사업소득·기타소득** — 가계부가 날짜별로 갖고 있다. 여기선 합계만 읽는다.
/// - **금융소득·임대소득** — 여기서 직접 받는다. 이자·배당은 자동 재투자라
///   매달 옮겨 적을 거리가 아니고, 임대료는 생활비 흐름이 아니라 자산이 버는
///   돈이라 「이번 달 수입」에 섞이면 안 된다.
class OtherIncomeSection extends StatefulWidget {
  final YearSnapshot? snapshot;

  /// 금액이 바뀌어 다시 읽어야 할 때.
  final VoidCallback onChanged;

  /// N잡러로 옮기러 간다 — 사업소득이 생겼을 때만 쓰인다.
  final VoidCallback? onSwitchType;

  const OtherIncomeSection({
    super.key,
    required this.snapshot,
    required this.onChanged,
    this.onSwitchType,
  });

  @override
  State<OtherIncomeSection> createState() => _OtherIncomeSectionState();
}

class _OtherIncomeSectionState extends State<OtherIncomeSection> {
  final _financial = TextEditingController();
  final _rental = TextEditingController();
  OtherIncome _other = const OtherIncome();
  bool _editing = false;
  bool _loaded = false;

  int get _year => widget.snapshot?.year ?? DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _financial.dispose();
    _rental.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final v = await OtherIncomeStore.load(_year);
    if (!mounted) return;
    setState(() {
      _other = v;
      _loaded = true;
      if (v.financial > 0) _financial.text = comma(v.financial.round());
      if (v.rental > 0) _rental.text = comma(v.rental.round());
    });
  }

  Future<void> _save() async {
    double read(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0;
    final v = OtherIncome(financial: read(_financial), rental: read(_rental));
    await OtherIncomeStore.save(_year, v);
    if (!mounted) return;
    setState(() {
      _other = v;
      _editing = false;
    });
    widget.onChanged();
  }

  List<IncomeThreshold> get _thresholds {
    final s = widget.snapshot;
    return incomeThresholds(
      businessIncome: s?.businessIncome ?? 0,
      otherIncomeAmount: s == null ? 0 : s.otherIncome * 0.4,
      other: _other,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final tert = AppTheme.inkTertiary(context);
    final list = _thresholds;
    final must = mustFileReturn(list);

    return SectionAccordion(
      no: '02',
      title: '다른 소득',
      collapsed: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
            list.isEmpty
                ? '급여 말고 들어온 돈이 있으면 여기서 챙겨요.'.keepWords
                : must
                    ? '5월에 종합소득세를 신고해야 해요.'.keepWords
                    : '${list.length}가지가 있어요. 아직은 분리과세로 끝나요.'.keepWords,
            style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.5)),
      ),
      expanded: (_) => _expanded(context, list, must),
    );
  }

  Widget _expanded(BuildContext context, List<IncomeThreshold> list, bool must) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final s = widget.snapshot;
    final hasBusiness = (s?.businessIncome ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 가계부에서 온 것 ──
        if (s != null && (s.businessIncome > 0 || s.otherIncome > 0)) ...[
          Text('가계부에 적은 것'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 8),
          if (s.businessIncome > 0) _row('사업소득', s.businessIncome, ink, sub),
          if (s.otherIncome > 0) _row('기타소득', s.otherIncome, ink, sub),
          const SizedBox(height: 14),
        ],

        // ── 여기서 받는 것 ──
        Text('직접 넣는 것'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 4),
        Text('이자·배당은 증권사·은행이, 임대료는 계약서가 연 합계를 알려줘요.'.keepWords,
            style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.45)),
        const SizedBox(height: 10),
        if (_editing) ...[
          _field('금융소득 (이자·배당)', _financial),
          const SizedBox(height: 10),
          _field('주택임대소득 (총수입)', _rental),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _button('취소', () => setState(() => _editing = false),
                outlined: true)),
            const SizedBox(width: 8),
            Expanded(child: _button('저장', _save)),
          ]),
        ] else ...[
          if (_other.financial > 0) _row('금융소득', _other.financial, ink, sub),
          if (_other.rental > 0) _row('주택임대소득', _other.rental, ink, sub),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _editing = true),
            child: AppTheme.dashedBox(
              context,
              child: SizedBox(
                height: 44,
                child: Row(children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_other.isEmpty ? '금액 적어보기' : '고치기',
                        style: AppTheme.sans(AppTheme.tsSM, sub)),
                  ),
                  const SizedBox(width: 8),
                  Text('＋',
                      style: AppTheme.sans(AppTheme.tsLG, accent,
                          weight: FontWeight.w600)),
                  const SizedBox(width: 14),
                ]),
              ),
            ),
          ),
        ],

        // ── 판정 ──
        if (list.isNotEmpty) ...[
          const SizedBox(height: 18),
          AppTheme.dashRule(context),
          const SizedBox(height: 14),
          Text('신고해야 하나요?'.toUpperCase(), style: AppTheme.label(context)),
          const SizedBox(height: 10),
          for (final t in list) ...[
            Row(children: [
              Expanded(
                child: Text(t.label.keepWords,
                    style: AppTheme.sans(AppTheme.tsSM, ink,
                        weight: FontWeight.w600)),
              ),
              Text(
                  t.limit <= 0
                      ? '문턱 없음'
                      : '${_won(t.amount)} / ${_won(t.limit)}',
                  style: AppTheme.sans(AppTheme.tsXS,
                      t.over ? AppTheme.colorDanger : tert)),
            ]),
            const SizedBox(height: 3),
            Text(t.consequence.keepWords,
                style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
            const SizedBox(height: 10),
          ],
        ],

        // ── 사업소득이 생겼으면 유형이 바뀌어야 한다 ──
        //
        // 직장인 화면에는 사업소득을 계산할 엔진이 없다(CombinedTaxCalculator는
        // N잡러 경로다). 적을 수는 있게 해 두되, 세금을 제대로 보려면 옮겨야 한다.
        if (hasBusiness && widget.onSwitchType != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSwitchType,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 1.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('N잡러로 바꾸면 세금까지 계산해드려요'.keepWords,
                    style: AppTheme.sans(AppTheme.tsSM, ink,
                        weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    '가계부와 내 정보는 그대로 따라가요. 사업경비와 세금 적립도 열려요. '
                            '업종만 새로 골라주시면 돼요.'
                        .keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, sub, height: 1.45)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, double amount, Color ink, Color sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTheme.sans(AppTheme.tsSM, sub))),
          Text(_won(amount),
              style: AppTheme.serif(AppTheme.serifSM, ink, spacing: -0.5)),
        ]),
      );

  Widget _field(String label, TextEditingController c) => Row(children: [
        Expanded(
          child: Text(label.keepWords,
              style: AppTheme.sans(AppTheme.tsSM, AppTheme.ink(context))),
        ),
        AmountField(controller: c, width: 140, onChanged: (_) {}),
      ]);

  Widget _button(String label, VoidCallback onTap, {bool outlined = false}) {
    final ink = AppTheme.ink(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: outlined ? null : ink,
          border: outlined ? Border.all(color: AppTheme.line(context)) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(AppTheme.tsSM,
                outlined ? ink : Theme.of(context).cardColor,
                weight: FontWeight.w700)),
      ),
    );
  }

  String _won(double v) => '${comma(v.round())}원';
}
