import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/recurring_template.dart';
import '../../core/data/expense_category.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import '../components/amount_field.dart';
import '../theme/text_wrap.dart';

const _pmCreditColor = Color(0xFF6B8FD4);
const _pmDebitColor  = Color(0xFFD4A847);
const _pmOtherColor  = Color(0xFF9E9B96);

class RecurringTemplatesScreen extends StatefulWidget {
  const RecurringTemplatesScreen({super.key});

  @override
  State<RecurringTemplatesScreen> createState() => _RecurringTemplatesScreenState();
}

class _RecurringTemplatesScreenState extends State<RecurringTemplatesScreen> {
  List<RecurringTemplate> _templates = [];
  String _userType = '직장인';

  bool get _isBusinessUser => _userType == '프리랜서' || _userType == 'N잡러';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    final list = await dbService.getRecurringTemplates();
    if (mounted) {
      setState(() {
        _userType = (profile?['user_type'] as String?) ?? '직장인';
        _templates = list;
      });
    }
    // initState에서 await 없이 부르는 자리라 여기서 새어 나간 예외는 아무도 못 잡는다.
    // 알림 예약은 부가 기능이니 실패해도 목록은 그대로 보여야 한다.
    if (!kIsWeb) {
      try {
        await ReminderScheduler.scheduleRecurringExpenses(list);
      } catch (e) {
        debugPrint('반복지출 알림 예약 실패: $e');
      }
    }
  }

  Color _pmColor(String pm) {
    switch (pm) {
      case '신용카드':  return _pmCreditColor;
      case '체크+현금': return _pmDebitColor;
      default:        return _pmOtherColor;
    }
  }

  // ── 편집 다이얼로그 ─────────────────────────────────────────────────

  Future<void> _showEditDialog({RecurringTemplate? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
        text: (existing?.amountHint ?? 0) > 0 ? '${existing!.amountHint}' : '');
    final dayCtrl = TextEditingController(
        text: existing != null ? '${existing.dayOfMonth}' : '');
    String category = existing?.category ?? '기타';
    String paymentMethod = existing?.paymentMethod ?? '기타';
    bool isBusiness = existing?.isBusiness ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final ink    = AppTheme.ink(ctx);
          final sub    = AppTheme.inkSecondary(ctx);
          final tert   = AppTheme.inkTertiary(ctx);
          final bg     = AppTheme.backgroundColor(ctx);
          final accent = AppTheme.accentColor(ctx);
          final line   = AppTheme.line(ctx);

          OutlineInputBorder outlineBorder(Color c, {double w = 1.0}) =>
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: c, width: w),
              );

          InputDecoration fieldDeco({
            required String hint,
            String? suffix,
          }) =>
              InputDecoration(
                hintText: hint,
                hintStyle: AppTheme.sans(14, tert),
                suffixText: suffix,
                suffixStyle: AppTheme.sans(13, sub),
                filled: true,
                fillColor: bg,
                enabledBorder: outlineBorder(line),
                focusedBorder: outlineBorder(accent, w: 1.5),
                errorBorder: outlineBorder(AppTheme.colorDanger),
                focusedErrorBorder: outlineBorder(AppTheme.colorDanger, w: 1.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              );

          Widget sectionLabel(String text) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: AppTheme.label(ctx)),
          );

          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: line),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            title: Text(
              existing == null ? '항목 추가' : '항목 편집',
              style: AppTheme.serif(17, ink),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 항목명
                      sectionLabel('항목명'),
                      TextFormField(
                        controller: nameCtrl,
                        style: AppTheme.sans(15, ink),
                        decoration: fieldDeco(hint: '예: 월세, 넷플릭스'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '항목명을 입력하세요' : null,
                      ),
                      const SizedBox(height: 14),

                      // 카테고리 — 탭하면 그리드 선택 (달력 에디터와 동일 패턴)
                      sectionLabel('카테고리'),
                      Builder(builder: (fieldCtx) {
                        final c = expenseCategoryById(category);
                        return GestureDetector(
                          onTap: () async {
                            final picked = await _pickCategory(fieldCtx, category);
                            if (picked != null) setLocal(() => category = picked);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                      color: c.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 9),
                                Text(c.label, style: AppTheme.sans(14, ink)),
                                const Spacer(),
                                Icon(Icons.expand_more_rounded,
                                    size: 18, color: sub),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),

                      // 결제수단
                      sectionLabel('결제수단'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pm in ['신용카드', '체크+현금', '기타'])
                            GestureDetector(
                              onTap: () => setLocal(() => paymentMethod = pm),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: paymentMethod == pm
                                      ? accent.withAlpha(26)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: paymentMethod == pm ? accent : line,
                                  ),
                                ),
                                child: Text(
                                  pm,
                                  style: AppTheme.sans(
                                      13, paymentMethod == pm ? accent : sub),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 빠져나가는 날 (별도 행)
                      sectionLabel('빠져나가는 날'),
                      TextFormField(
                        controller: dayCtrl,
                        style: AppTheme.sans(15, ink),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: fieldDeco(hint: '1~31', suffix: '일 (매월)'),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 31) {
                            return '1~31 사이로 입력하세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 예상 금액 (별도 행)
                      sectionLabel('예상 금액'),
                      TextFormField(
                        controller: amountCtrl,
                        style: AppTheme.sans(15, ink),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        inputFormatters: const [ThousandsFormatter()],
                        decoration: fieldDeco(hint: '미정이면 비워두기', suffix: '원'),
                      ),
                      if (_isBusinessUser) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => setLocal(() => isBusiness = !isBusiness),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Icon(
                                isBusiness
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: isBusiness ? accent : sub,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('사업경비로 인정 (기본값)',
                                    style: AppTheme.sans(14,
                                        isBusiness ? ink : sub,
                                        weight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('취소', style: AppTheme.sans(14, sub)),
              ),
              TextButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final t = RecurringTemplate(
                    id: existing?.id ?? 0,
                    name: nameCtrl.text.trim(),
                    amountHint: int.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0,
                    category: category,
                    paymentMethod: paymentMethod,
                    dayOfMonth: int.parse(dayCtrl.text.replaceAll(',', '')),
                    sortOrder: existing?.sortOrder ?? _templates.length,
                    isBusiness: isBusiness,
                  );
                  if (existing == null) {
                    await dbService.insertRecurringTemplate(t);
                  } else {
                    await dbService.updateRecurringTemplate(t);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _load();
                },
                child: Text(
                  existing == null ? '추가' : '저장',
                  style: AppTheme.sans(14, accent, weight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 카테고리 선택 그리드 (달력 에디터와 동일 패턴) ──────────────────

  Future<String?> _pickCategory(BuildContext ctx, String current) {
    return showDialog<String>(
      context: ctx,
      builder: (dctx) {
        final ink  = AppTheme.ink(dctx);
        final sub  = AppTheme.inkSecondary(dctx);
        final bg   = AppTheme.backgroundColor(dctx);
        final line = AppTheme.line(dctx);
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          title: Text('카테고리', style: AppTheme.serif(17, ink)),
          content: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kExpenseCategories.map((cat) {
              final sel = current == cat.id;
              return GestureDetector(
                onTap: () => Navigator.of(dctx).pop(cat.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? cat.color.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: sel ? cat.color : line,
                      width: sel ? 1.4 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cat.icon, size: 13, color: sel ? cat.color : sub),
                    const SizedBox(width: 4),
                    Text(cat.label,
                        style: AppTheme.sans(12, sel ? ink : sub,
                            weight: sel ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── 삭제 확인 다이얼로그 ─────────────────────────────────────────────

  Future<void> _deleteTemplate(RecurringTemplate t) async {
    final ink  = AppTheme.ink(context);
    final sub  = AppTheme.inkSecondary(context);
    final bg   = AppTheme.backgroundColor(context);
    final line = AppTheme.line(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: line),
        ),
        title: Text('항목 삭제', style: AppTheme.serif(17, ink)),
        content: Text(
          '"${t.name}"을 삭제하면 이번 달 확인 기록도 함께 사라져요.'.keepWords,
          style: AppTheme.sans(14, sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('취소', style: AppTheme.sans(14, sub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('삭제',
                style: AppTheme.sans(14, AppTheme.colorDanger,
                    weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await dbService.deleteRecurringTemplate(t.id);
      await _load();
    }
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ink  = AppTheme.ink(context);
    final bg   = AppTheme.backgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('고정 지출', style: AppTheme.serif(22, ink)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: AppTheme.hairline(context),
        ),
      ),
      body: Stack(
        children: [
          _templates.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => AppTheme.hairline(context),
                  itemBuilder: (_, i) => _buildTemplateRow(_templates[i]),
                ),
          // 우하단 추가 버튼 (항목 있을 때만)
          if (_templates.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () => _showEditDialog(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.lineStrong(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 17, color: bg),
                          const SizedBox(width: 7),
                          Text('항목 추가',
                              style: AppTheme.sans(14, bg,
                                  weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 빈 상태 ──────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final ink    = AppTheme.ink(context);
    final sub    = AppTheme.inkSecondary(context);
    final tert   = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final line   = AppTheme.lineStrong(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.event_repeat_outlined, size: 36, color: tert),
          ),
          const SizedBox(height: 20),
          Text('매월 빠져나가는 돈', style: AppTheme.serif(22, ink)),
          const SizedBox(height: 8),
          Text(
            '월세, 구독료, 보험료 등\n자동으로 챙겨드려요.'.keepWords,
            style: AppTheme.sans(14, sub),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showEditDialog(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text('첫 항목 추가하기',
                      style: AppTheme.sans(14, accent,
                          weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 날짜 스탬프 — 매월 빠져나가는 날 (세리프 숫자) ──────────────────

  Widget _dateStamp(int day) {
    final ink = AppTheme.ink(context);
    return Container(
      width: 46,
      padding: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.line(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$day', style: AppTheme.serif(22, ink, height: 1.0)),
          const SizedBox(height: 1),
          Text('일', style: AppTheme.sans(11, AppTheme.inkTertiary(context),
              weight: FontWeight.w600, spacing: 1)),
        ],
      ),
    );
  }

  // ── 원장 행 — 한 줄 = 매월 한 건의 고정 지출 (탭=편집) ───────────────

  Widget _buildTemplateRow(RecurringTemplate t) {
    final ink     = AppTheme.ink(context);
    final tert    = AppTheme.inkTertiary(context);
    final cat     = expenseCategoryById(t.category);
    final pmColor = _pmColor(t.paymentMethod);

    return GestureDetector(
      onTap: () => _showEditDialog(existing: t),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _dateStamp(t.dayOfMonth),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: AppTheme.sans(14, ink, weight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: cat.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(cat.label, style: AppTheme.sans(12, tert)),
                      Text('  ·  ', style: AppTheme.sans(12, tert)),
                      Text(t.paymentMethod,
                          style: AppTheme.sans(12, pmColor,
                              weight: FontWeight.w600)),
                      if (t.isBusiness) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.line(context)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('사업경비', style: AppTheme.sans(10, tert, weight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 예상 금액 — 세리프 숫자, 미정이면 흐리게
            if (t.amountHint > 0)
              Text('${_fmt(t.amountHint)}원',
                  style: AppTheme.serif(17, ink, height: 1.0))
            else
              Text('미정', style: AppTheme.sans(12, tert)),
            const SizedBox(width: 6),
            // 삭제 (편집은 행 전체 탭)
            GestureDetector(
              onTap: () => _deleteTemplate(t),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                child: Icon(Icons.close_rounded, size: 17, color: tert),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 금액 포매터 ──────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 10000) {
      final man = n ~/ 10000;
      final rem = n % 10000;
      final manStr = man.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+$)'), (m) => '${m[1]},');
      if (rem == 0) return '$manStr만';
      final remStr = rem.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+$)'), (m) => '${m[1]},');
      return '$manStr만 $remStr';
    }
    return n
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+$)'), (m) => '${m[1]},');
  }
}
