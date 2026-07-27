import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/document_checklist.dart';
import '../theme/text_wrap.dart';

class DocumentChecklistScreen extends StatefulWidget {
  final String userType;

  const DocumentChecklistScreen({super.key, required this.userType});

  @override
  State<DocumentChecklistScreen> createState() => _DocumentChecklistScreenState();
}

class _DocumentChecklistScreenState extends State<DocumentChecklistScreen> {
  List<DocItem> _items = [];
  final Set<int> _checked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    if (!mounted) return;
    setState(() {
      _items = buildChecklist(profile ?? {}, widget.userType);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    final manualItems = _items.where((e) => !e.isHometaxAuto).toList();
    final autoItems = _items.where((e) => e.isHometaxAuto).toList();
    final isEmployee = widget.userType == '직장인' || widget.userType == 'N잡러';
    final season = isEmployee ? '연말정산' : '종합소득세';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('서류 체크리스트',
            style: AppTheme.serif(22, ink, weight: FontWeight.w400, spacing: -0.3)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                children: [
                  Text('$season 서류',
                      style: AppTheme.label(context)),
                  const SizedBox(height: 4),
                  Text(
                    '홈택스 간소화에서 자동 수집되지 않아 직접 준비해야 하는 서류만 모았어요.'.keepWords,
                    style: AppTheme.sans(13, sub, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  if (manualItems.isEmpty)
                    _emptyState(tert)
                  else ...[
                    Text('직접 준비할 서류'.toUpperCase(),
                        style: AppTheme.label(context)),
                    const SizedBox(height: 6),
                    AppTheme.hairline(context),
                    for (int i = 0; i < manualItems.length; i++) ...[
                      _checkRow(i, manualItems[i], ink, sub, tert, accent),
                      AppTheme.hairline(context),
                    ],
                  ],
                  if (autoItems.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('홈택스 간소화 자동 수집'.toUpperCase(),
                        style: AppTheme.label(context)),
                    const SizedBox(height: 6),
                    AppTheme.hairline(context),
                    for (final item in autoItems) _autoRow(item, sub, tert),
                    AppTheme.hairline(context),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _checkRow(int index, DocItem item, Color ink, Color sub, Color tert, Color accent) {
    final checked = _checked.contains(index);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (checked) {
          _checked.remove(index);
        } else {
          _checked.add(index);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: checked ? accent : Colors.transparent,
                  border: Border.all(
                    color: checked ? accent : AppTheme.lineStrong(context),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: checked
                    ? Icon(Icons.check_rounded, size: 13, color: Theme.of(context).scaffoldBackgroundColor)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: AppTheme.sans(14, checked ? AppTheme.inkTertiary(context) : ink,
                          weight: FontWeight.w700,
                          spacing: -0.1).copyWith(
                        decoration: checked ? TextDecoration.lineThrough : null,
                      )),
                  const SizedBox(height: 3),
                  Text(item.subtitle,
                      style: AppTheme.sans(12, tert, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoRow(DocItem item, Color sub, Color tert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.cloud_done_outlined, size: 18, color: tert),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.subtitle,
                style: AppTheme.sans(13, sub, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(Color tert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.task_alt_rounded, size: 40, color: tert),
        const SizedBox(height: 12),
        Text('별도로 준비할 서류가 없어요',
            style: AppTheme.sans(15, tert, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('홈택스 간소화 서비스에서 자동으로 수집돼요.'.keepWords,
            style: AppTheme.sans(13, tert, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
