import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 목록 검색칸 — 항목이 50개를 넘는 화면(혜택·계산기)에서 카테고리 훑기를 대신한다.
///
/// 박스형 검색바 대신 헤어라인 밑줄 하나로 둔다. 마법사 입력칸(_buildInputPage)과
/// 같은 계열이라 화면이 도면 시트처럼 계속 읽힌다.
class SearchField extends StatelessWidget {
  final TextEditingController controller;

  /// 안에 뭐가 있는지 예시로 보여준다 — "검색어를 입력하세요"보다 정보량이 크다.
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  /// AppBar 타이틀 자리에 넣을 땐 titleSpacing이 이미 여백을 주므로 0으로 둔다.
  final EdgeInsetsGeometry padding;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final hasText = controller.text.isNotEmpty;

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.lineStrong(context), width: 1.4),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: hasText ? ink : sub),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                autofocus: autofocus,
                cursorColor: AppTheme.accentColor(context),
                textInputAction: TextInputAction.search,
                style: AppTheme.sans(15, ink, weight: FontWeight.w600),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: hint,
                  hintStyle: AppTheme.sans(15, tert),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (hasText)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded, size: 18, color: sub),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 검색 결과 없음 — 빈 화면을 다음 행동으로 연결한다.
/// 혜택·계산기는 의도적으로 분리된 두 진입점이라, 서로를 가리키는 게 실제로 도움이 된다.
class SearchEmptyState extends StatelessWidget {
  final String query;

  /// 여기 없으면 어디로 가면 되는지 (예: '혜택 탭에서 찾아보세요').
  final String suggestion;

  const SearchEmptyState({
    super.key,
    required this.query,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      child: Column(
        children: [
          Text('‘$query’',
              style: AppTheme.serif(22, AppTheme.ink(context), spacing: -0.5)),
          const SizedBox(height: 10),
          Text(suggestion,
              textAlign: TextAlign.center,
              style: AppTheme.sans(13, AppTheme.inkSecondary(context), height: 1.6)),
        ],
      ),
    );
  }
}
