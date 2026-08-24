import 'package:flutter/material.dart';

import '../../core/data/db_helper.dart';
import '../../core/data/deduction_catalog.dart';
import '../../core/data/residence.dart';
import '../../core/data/year_deductions.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../components/deduction_checklist.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// **올해 받을 공제** — 홈 02에서 들어온다.
///
/// 02의 「올해 쌓인 예상 환급」은 카드공제만 센 숫자다. 카드 말고도 받을 게
/// 있는데, 그건 결제할 때마다 문턱이 움직이는 종류가 아니라 증명서 한 장으로
/// 확인하는 종류라 가계부에 매일 적게 할 수 없다. 여기서 한 번에 받는다.
///
/// 항목은 **이 사람에게 걸리는 것만** 그린다(`deductionsFor`). 자가인 사람에게
/// 월세 세액공제를 권하면 그건 도움이 아니라 사고다.
class YearDeductionScreen extends StatefulWidget {
  const YearDeductionScreen({super.key});

  @override
  State<YearDeductionScreen> createState() => _YearDeductionScreenState();
}

class _YearDeductionScreenState extends State<YearDeductionScreen> {
  final int _year = DateTime.now().year;
  Map<String, dynamic>? _profile;
  Map<String, int> _saved = {};
  // 체크리스트를 둘로 나눴다. 각자 자기 맵만 올리므로 여기서 합친다 —
  // 한쪽이 올린 맵으로 통째로 덮으면 다른 쪽 금액이 지워진다.
  Map<String, int> _notAuto = {};
  Map<String, int> _easyToMiss = {};
  bool _loading = true;

  Map<String, int> get _amounts => {..._notAuto, ..._easyToMiss};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await dbService.getProfile();
    final saved = await YearDeductions.load(_year);
    // 월세는 **여기가 정본**이다(연 합계). 예전에 내 정보에 월 금액으로 넣어 둔
    // 사람이 있으므로 한 번은 끌어온다 — 안 그러면 이미 답한 사람에게 다시 묻는다.
    if (!saved.containsKey('rent')) {
      final monthly = (p?['monthly_rent'] as num?)?.toDouble() ?? 0;
      if (monthly > 0) saved['rent'] = (monthly * 12).round();
    }
    if (!mounted) return;
    setState(() {
      _profile = p;
      _saved = saved;
      _notAuto = {
        for (final e in saved.entries)
          if (kNotAutoLoaded.contains(e.key)) e.key: e.value
      };
      _easyToMiss = {
        for (final e in saved.entries)
          if (!kNotAutoLoaded.contains(e.key)) e.key: e.value
      };
      _loading = false;
    });
  }

  double get _gross => (_profile?['gross_income'] as num?)?.toDouble() ?? 0.0;
  int get _children => (_profile?['children_count_total'] as int?) ?? 0;
  int get _dependents => ((_profile?['dependents'] as int?) ?? 0) + 1;

  EmployeeRefundEstimate get _estimate => estimateYearRefund(
        amounts: _amounts,
        grossIncome: _gross,
        dependentsIncludingSelf: _dependents,
        isHouseholdHead: isHouseholdHead(_profile),
        ownsHome: ownsHome(_profile),
        childrenCount: _children,
      );

  Future<void> _save() async {
    await YearDeductions.save(_year, _amounts);
    // 옛 읽는 쪽(적립 카드·종소세 진단·연말정산 진단·홈택스 가이드)은 프로필의
    // 월 금액을 본다. 여기가 정본이 됐으니 그쪽을 **파생값으로 맞춰 준다** —
    // 다섯 군데를 고치는 것보다 짧고, 사용자가 값을 적는 곳은 여전히 하나다.
    final p = await dbService.getProfile();
    if (p != null) {
      await dbService.saveProfile({
        ...p,
        'monthly_rent': (_amounts['rent'] ?? 0) / 12,
      });
    }
    if (!mounted) return;
    setState(() => _saved = Map.of(_amounts));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final residence = residenceOf(_profile);
    final head = isHouseholdHead(_profile);
    // **간소화가 놓치는 것만.** 자동으로 뜨는 금액을 앱에 옮겨 적게 하는 건
    // 순수 손해다 — 홈택스에서 클릭 한 번이면 되는 걸 두 번 하게 만든다.
    final cats = missableFor(
      residence: residence,
      isHouseholdHead: head,
      grossIncome: _gross,
      childrenCount: _children,
    );
    final split = splitMissable(cats);
    final est = _estimate;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            AppTheme.ruleLabel(context, 'DEDUCTIONS $_year'),
            const SizedBox(height: 12),
            Text('공제',
                textAlign: TextAlign.center,
                style: AppTheme.display(AppTheme.serifLG, ink, spacing: 4)),
            const SizedBox(height: 10),
            Text(
                '홈택스 간소화에 안 나오는 것들이에요. 해당하는 것만 골라 적어 두면 '
                        '5월 신고 때 그대로 쓸 수 있어요.'
                    .keepWords,
                style: AppTheme.sans(AppTheme.tsBase, sub, height: 1.55)),

            if (_gross <= 0) ...[
              const SizedBox(height: 18),
              _notice('예상 연봉을 먼저 넣어주세요. 공제율과 한도가 연봉으로 갈려서, '
                  '연봉 없이는 얼마 돌려받는지 계산할 수 없어요.'),
            ],

            const SizedBox(height: 22),
            AppTheme.dashRule(context),
            const SizedBox(height: 16),
            AppTheme.sectionHead(context, '01', '자동으로 안 불러와져요'),
            const SizedBox(height: 6),
            Text(
                '집 관련 공제는 제도상 간소화에 안 실려요. 증명서를 직접 떼야 하는 '
                        '대신 금액이 커요.'
                    .keepWords,
                style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.45)),
            const SizedBox(height: 4),
            Text(_basisLine(residence, head),
                style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.45)),
            const SizedBox(height: 10),
            if (split.notAuto.isEmpty)
              Text('지금 내 정보로는 해당하는 게 없어요.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, tert))
            else
              DeductionChecklist(
                key: ValueKey('notAuto_${residence}_$head'),
                categories: split.notAuto,
                initialAmounts: _saved,
                onChanged: (a) => setState(() => _notAuto = a),
              ),

            const SizedBox(height: 22),
            AppTheme.dashRule(context),
            const SizedBox(height: 16),
            AppTheme.sectionHead(context, '02', '놓치기 쉬워요'),
            const SizedBox(height: 6),
            Text(
                '영수증을 직접 챙겨야 하는 것들이에요. 해당하는 게 없으면 '
                        '그냥 넘어가세요.'
                    .keepWords,
                style: AppTheme.sans(AppTheme.tsSM, tert, height: 1.45)),
            const SizedBox(height: 10),
            if (split.easyToMiss.isEmpty)
              Text('지금 내 정보로는 해당하는 게 없어요.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, tert))
            else
              DeductionChecklist(
                key: ValueKey('easy_$_children'),
                categories: split.easyToMiss,
                initialAmounts: _saved,
                onChanged: (a) => setState(() => _easyToMiss = a),
              ),

            const SizedBox(height: 12),
            Text('의료비·교육비·기부금·보험료처럼 간소화에서 자동으로 나오는 건 '
                    '홈택스가 알아서 해줘요. 여기선 안 나오는 것만 챙기면 돼요.'
                .keepWords,
                style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.45)),

            const SizedBox(height: 22),
            AppTheme.dashRule(context),
            const SizedBox(height: 16),
            AppTheme.sectionHead(context, '03', '예상 환급'),
            const SizedBox(height: 12),
            if (est.lines.isEmpty)
              Text('아직 고른 항목이 없어요.'.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, tert))
            else ...[
              for (final l in est.lines) _row(l.label, l.amount, sub, ink),
              // 의료비는 총급여 3%를 넘은 만큼만이라(§59의4②1) 간소화 자동분을
              // 모르면 확정할 수 없다. **그래도 적게 둔다** — 돌려받을지는
              // 몰라도 신고서를 완성해 두는 게 사용자의 일이고, 앱이 대신
              // 결정할 일이 아니다. 대신 조건을 밝힌다.
              for (final c in cats)
                if (c.conditional != null && (_amounts[c.id] ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                      '${c.name}: ${c.conditional} — '
                              '간소화 의료비가 ${_won(_gross * 0.03)}을 넘었다면 반영돼요.'
                          .keepWords,
                      style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.45)),
                ],
              const SizedBox(height: 6),
              Container(height: 1, color: ink),
              const SizedBox(height: 6),
              _row('합계', est.refund, ink, ink, bold: true),
              if (est.isCapped) ...[
                const SizedBox(height: 10),
                Text(
                    '공제는 낸 세금에서 빼는 것이라 낸 것보다 더 돌려받을 수 없어요. '
                            '${est.capBasis} ${_won(est.cap)}이 상한이에요.'
                        .keepWords,
                    style: AppTheme.sans(AppTheme.tsXS, tert, height: 1.45)),
              ],
            ],

            const SizedBox(height: 28),
            _saveButton(ink),
          ],
        ),
      ),
    );
  }

  /// 왜 이 목록인지 밝힌다. 숨긴 이유를 안 밝히면 "내 항목이 왜 없지"가 된다.
  String _basisLine(String? residence, bool head) {
    if (residence == null) {
      return '내 정보에 거주 형태를 넣으면 집 관련 공제도 같이 봐드려요.';
    }
    if (residence != '자가' && !head) {
      return '$residence · 세대주가 아니라서 집 관련 공제는 뺐어요. '
          '내 정보에서 바꿀 수 있어요.';
    }
    return '$residence 기준이에요. 내 정보를 바꾸면 목록도 바뀌어요.';
  }

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text.keepWords,
            style: AppTheme.sans(AppTheme.tsSM, AppTheme.inkSecondary(context),
                height: 1.5)),
      );

  Widget _row(String label, double amount, Color labelColor, Color valueColor,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label.keepWords,
                  style: AppTheme.sans(AppTheme.tsSM, labelColor,
                      weight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(_won(amount),
              style: AppTheme.serif(AppTheme.serifSM, valueColor, spacing: -0.5)),
        ]),
      );

  Widget _saveButton(Color ink) => Semantics(
        button: true,
        child: GestureDetector(
          onTap: _save,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
            child: Text('저장하기',
                style: AppTheme.sans(AppTheme.tsBase, Theme.of(context).cardColor,
                    weight: FontWeight.w700)),
          ),
        ),
      );

  String _won(double v) {
    final n = v.round();
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b원';
  }
}
