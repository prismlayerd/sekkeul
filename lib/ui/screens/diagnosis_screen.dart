import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

class DiagnosisScreen extends StatelessWidget {
  final String userType;
  const DiagnosisScreen({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('진단',
            style: AppTheme.serif(17, AppTheme.ink(context),
                weight: FontWeight.w400, spacing: -0.5)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 48, color: AppTheme.inkTertiary(context)),
            const SizedBox(height: 16),
            Text('준비 중',
                style: AppTheme.sans(15, AppTheme.inkSecondary(context))),
            const SizedBox(height: 8),
            Text('소득·지출·세금 종합 진단이 곧 열립니다.'.keepWords,
                style: AppTheme.sans(13, AppTheme.inkTertiary(context))),
          ],
        ),
      ),
    );
  }
}
