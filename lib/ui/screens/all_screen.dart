import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'expense_calendar_screen.dart';
import 'reminder_list_screen.dart';
import 'tax_tools_screen.dart';
import 'forms_screen.dart';
import 'my_info_screen.dart';
import 'update_notes_screen.dart';

class AllScreen extends StatelessWidget {
  final String userType;
  final VoidCallback onProfileChanged;
  final VoidCallback onOpenSettings;

  const AllScreen({
    super.key,
    required this.userType,
    required this.onProfileChanged,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('전체',
            style: AppTheme.serif(AppTheme.tsLG, AppTheme.ink(context),
                weight: FontWeight.w400, spacing: -0.5)),
      ),
      body: ListView(
        children: [
          _sectionHeader(context, '기록'),
          _menuItem(
            context,
            icon: Icons.event_note_outlined,
            label: '가계부',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen())),
          ),
          _menuItem(
            context,
            icon: Icons.notifications_none_rounded,
            label: '리마인더',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ReminderListScreen(userType: userType, embedded: false))),
          ),
          _divider(context),
          _sectionHeader(context, '세금'),
          _menuItem(
            context,
            icon: Icons.change_history_outlined,
            label: '세무 도구',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TaxToolsScreen(userType: userType, embedded: false))),
          ),
          _menuItem(
            context,
            icon: Icons.description_outlined,
            label: '양식',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FormsScreen(userType: userType))),
          ),
          _divider(context),
          _sectionHeader(context, '내 계정'),
          _menuItem(
            context,
            icon: Icons.person_outline_rounded,
            label: '내 정보',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MyInfoScreen(
                      userType: userType, onProfileChanged: onProfileChanged)),
            ),
          ),
          _menuItem(
            context,
            icon: Icons.settings_outlined,
            label: '설정',
            onTap: onOpenSettings,
          ),
          // 홈 카드는 한 번 보면 사라진다. 지난 소식을 다시 찾을 자리가
          // 있어야 "언제부터 이 기준이었지"를 되짚을 수 있다.
          _menuItem(
            context,
            icon: Icons.history_rounded,
            label: '업데이트 소식',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UpdateNotesScreen())),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(title,
          style: AppTheme.sans(AppTheme.tsXS, AppTheme.inkTertiary(context),
              weight: FontWeight.w500)),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
        height: 1, thickness: 1, color: AppTheme.line(context), indent: 16);
  }

  Widget _menuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.inkSecondary(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTheme.sans(AppTheme.tsBase, AppTheme.ink(context))),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppTheme.inkTertiary(context)),
          ],
        ),
      ),
    );
  }
}
