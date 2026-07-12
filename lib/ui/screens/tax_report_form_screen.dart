import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import 'tax_simulator_screen.dart';
import 'tax_annual_report_screen.dart';
import '../components/tax_pipeline_rail.dart';

/// 가상 신고서 — 세금 계산의 하향식 흐름을 '장부' 형식으로 보여준다.
/// 좌측 연산자 거터(− + × =)가 실제 세금 로직을 담고(structure is information),
/// 과세표준·결정세액 같은 법정 중간합계를 굵은 룰로 강조, 마지막엔 환급/납부 표제란.
///
/// 파이프라인 ③단계로 진입(items 비어 있음)하면 '아직 안 채워진 서식' 빈 상태로,
/// ②진단으로 안내한다.
class TaxReportFormScreen extends StatelessWidget {
  final String reportType;
  final List<Map<String, dynamic>> items;
  final double finalAmount;
  final bool isRefund;
  final String? userType; // 빈 상태에서 ②진단으로 보낼 때 사용

  const TaxReportFormScreen({
    super.key,
    required this.reportType,
    required this.items,
    required this.finalAmount,
    required this.isRefund,
    this.userType,
  });

  static final _fmt = NumberFormat('#,###');

  String get _officialName => reportType == '연말정산'
      ? '근로소득 원천징수영수증'
      : reportType == '경정청구'
          ? '종합소득세 경정청구서'
          : '종합소득세 과세표준확정신고서';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: TaxPipelineRail(current: 2),
            ),
            Expanded(
              child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            // ── 표제 ──
            Text('가상 신고서 · ${reportType.toUpperCase()}', style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text(_officialName, style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 22),

            // ── 열 캡션 ──
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Row(
                children: [
                  Expanded(child: Text('항목'.toUpperCase(), style: AppTheme.label(context))),
                  Text('금액 (원)'.toUpperCase(), style: AppTheme.label(context)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(height: 1.4, color: AppTheme.lineStrong(context)),

            if (items.isEmpty)
              ..._emptyBody(context)
            else ...[
              // ── 계산 행 (연산자 거터 + 장부) ──
              for (int i = 0; i < items.length; i++) _row(context, items[i], isFirst: i == 0),
              const SizedBox(height: 24),
              // ── 결과 표제란 ──
              _resultBlock(context),
              const SizedBox(height: 18),
              Text(
                '※ 세끌 계산 결과로 만든 가상 양식이에요. 실제 신고 시 금액이 달라질 수 있어요.',
                style: AppTheme.sans(12, tert, height: 1.5),
              ),
              // 주 CTA — 파이프라인 ③홈택스 가이드로. 위 숫자를 홈택스 화면 순서대로 안내.
              // (경정청구는 세무 도구 메뉴의 "경정청구 준비하기"로 분리 — 5월 정기 신고
              //  흐름과 성격이 달라 여기 인라인하지 않는다.)
              if (reportType == '종합소득세') ...[
                const SizedBox(height: 24),
                SimulatorTossButton(
                  text: '홈택스 신고 가이드로 넘어가기',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaxAnnualReportScreen(userType: userType ?? '직장인'),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 빈 상태 — 아직 계산 전인 '안 채워진 서식'. 흐린 플레이스홀더 행이
  /// 채워질 자리를 약속하고, 가운데 안내가 ②진단으로 보낸다.
  List<Widget> _emptyBody(BuildContext context) {
    return [
      // 채워질 자리를 약속하는 흐린 행들
      _ghostRow(context, '−'),
      _ghostRow(context, '−'),
      _ghostRow(context, '='),
      const SizedBox(height: 24),
      _emptyPrompt(context),
    ];
  }

  Widget _ghostRow(BuildContext context, String op) {
    final line = AppTheme.line(context);
    final tert = AppTheme.inkTertiary(context);
    final ghost = tert.withOpacity(0.45);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line, width: 1))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 38,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: line, width: 1))),
              alignment: Alignment.center,
              child: Text(op, style: AppTheme.serif(17, ghost, spacing: 0, height: 1.0)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                // 항목명이 들어올 자리 — 흐린 막대
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: 96, height: 9,
                      decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(1))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('—', style: AppTheme.serif(17, ghost, spacing: 0, height: 1.0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPrompt(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg = AppTheme.backgroundColor(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lineStrong(context), width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('아직 계산 전이에요', style: AppTheme.label(context)),
          const SizedBox(height: 10),
          Text('진단을 마치면 이 신고서가\n자동으로 채워져요.',
              style: AppTheme.sans(14, ink, weight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 6),
          Text('②단계에서 소득·공제를 넣으면 위 항목이 숫자로 채워집니다.',
              style: AppTheme.sans(12, sub, height: 1.45)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => TaxSimulatorScreen(userType: userType ?? '직장인'))),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('진단하기', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16, color: bg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 제목 앞의 (−)(+)(×)(=) 연산자를 거터로 분리.
  ({String op, String label}) _parse(String title) {
    final m = RegExp(r'^\(([-+=×])\)\s*').firstMatch(title);
    if (m == null) return (op: '', label: title);
    final raw = m.group(1)!;
    final op = raw == '-' ? '−' : raw; // 하이픈 → 마이너스 기호
    return (op: op, label: title.substring(m.end));
  }

  Widget _row(BuildContext context, Map<String, dynamic> item, {bool isFirst = false}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final line = AppTheme.line(context);
    final lineStrong = AppTheme.lineStrong(context);

    final parsed = _parse(item['title'] as String);
    final amount = (item['amount'] as num).toDouble();
    final milestone = (item['isHeader'] ?? false) == true || (item['highlight'] ?? false) == true;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          // 중간합계(과세표준·결정세액 등)는 위에 굵은 룰을 둬 소계 바처럼.
          // 단, 첫 행은 캡션 룰과 겹치므로 제외.
          top: (milestone && !isFirst) ? BorderSide(color: lineStrong, width: 1.4) : BorderSide.none,
          bottom: BorderSide(color: line, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 연산자 거터 — 우측 1px 룰이 세로로 이어져 계산 마진을 만든다.
            Container(
              width: 38,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: line, width: 1)),
              ),
              alignment: Alignment.center,
              child: Text(parsed.op,
                  style: AppTheme.serif(milestone ? 18 : 16, tert, spacing: 0, height: 1.0)),
            ),
            const SizedBox(width: 14),
            // 항목명
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: milestone ? 15 : 13),
                child: Text(parsed.label,
                    style: milestone
                        ? AppTheme.sans(14, ink, weight: FontWeight.w700, spacing: -0.2)
                        : AppTheme.sans(14, sub, height: 1.3)),
              ),
            ),
            const SizedBox(width: 12),
            // 금액 — 세리프 장부 숫자 + 작은 '원'
            Padding(
              padding: EdgeInsets.symmetric(vertical: milestone ? 13 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fmt.format(amount),
                      style: AppTheme.serif(milestone ? 21 : 16.5, ink, spacing: -0.5, height: 1.0)),
                  const SizedBox(width: 3),
                  Text('원', style: AppTheme.sans(12, tert)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 차감징수세액 — 환급/추가납부 표제란.
  Widget _resultBlock(BuildContext context) {
    final sub = AppTheme.inkSecondary(context);
    final accent = isRefund ? AppTheme.accentColor(context) : AppTheme.colorDanger;
    final abs = finalAmount.abs();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lineStrong(context), width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('차감징수세액', style: AppTheme.label(context)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(isRefund ? '환급' : '추가납부',
                  style: AppTheme.sans(11, accent, weight: FontWeight.w700, spacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_fmt.format(abs), style: AppTheme.serif(36, accent, spacing: -1.2, height: 1.0)),
              const SizedBox(width: 5),
              Text('원', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isRefund ? '원천징수로 낸 세금이 결정세액보다 많아 돌려받아요.' : '결정세액이 기납부세액보다 많아 더 내야 해요.',
            style: AppTheme.sans(12, sub, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// ③ 가상 신고서 진입 래퍼 — 저장된 ②진단 draft를 읽어 자동기입,
/// 없으면 빈 상태로 ②진단을 안내한다.
class ReportFormLoader extends StatefulWidget {
  final String userType;
  const ReportFormLoader({super.key, required this.userType});

  @override
  State<ReportFormLoader> createState() => _ReportFormLoaderState();
}

class _ReportFormLoaderState extends State<ReportFormLoader> {
  Map<String, dynamic>? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await dbService.getReportDraft(widget.userType);
    if (mounted) setState(() { _draft = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SizedBox.shrink(),
      );
    }
    final d = _draft;
    if (d == null) {
      return TaxReportFormScreen(
        reportType: '종합소득세',
        items: const [],
        finalAmount: 0,
        isRefund: true,
        userType: widget.userType,
      );
    }
    return TaxReportFormScreen(
      reportType: d['report_type'] as String? ?? '종합소득세',
      items: (d['items'] as List).cast<Map<String, dynamic>>(),
      finalAmount: (d['final_amount'] as num).toDouble(),
      isRefund: d['is_refund'] == true,
      userType: widget.userType,
    );
  }
}
