import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../security/crypto_helper.dart';
import '../security/db_key_manager.dart';
import 'expense_item.dart';
import 'income_entry.dart';
import 'ledger_profile.dart';
import 'recurring_template.dart';
import 'quick_entry_preset.dart';
import 'legacy_migration.dart';

/// 가계부 유형 이동(가져오기) 미리보기 — 몇 건이 옮겨지고 몇 건이 원본에 남는지.
class LedgerMoveSummary {
  final int expenseCount;       // 옮겨질 지출 건수(지출은 유형 무관하게 전부 이동)
  final int movableIncomeCount; // 대상 유형이 지원하는 소득이라 옮겨질 수입 건수
  final int orphanIncomeCount;  // 대상 유형에 맞지 않아 원본에 남는 수입 건수
  const LedgerMoveSummary({
    required this.expenseCount,
    required this.movableIncomeCount,
    required this.orphanIncomeCount,
  });
  int get totalMovable => expenseCount + movableIncomeCount;
}

/// 대상 유형으로 옮길 수 있는 소득(income_type) 집합.
/// 지출은 개인 소비라 유형과 무관하게 전부 이동하지만, 수입은 소득 성격이 있어
/// 대상 유형이 실제로 기록하는 소득 유형만 옮긴다(예: 급여는 프리랜서로 못 감).
Set<String> movableIncomeTypesTo(String target) {
  final valid = {...LedgerProfile.of(target).incomeTypes};
  if (valid.contains('기타소득')) valid.add('기타'); // 레거시 '기타' 기록 호환
  return valid;
}

/// 온디바이스 데이터베이스 보안 인터페이스 정의
abstract class DatabaseService {
  Future<void> initDatabase();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> getProfile();
  // 유형별(직장인/N잡러/프리랜서) 독립 저장 — 예상연봉·지출목표는 유형 전환 시 서로 섞이면 안 됨.
  Future<void> setProfileTypeValues(String userType, {double? grossIncome, double? expenseTarget});
  Future<Map<String, double>> getProfileTypeValues(String userType);
  Future<void> insertExpense(ExpenseItem item);
  Future<List<ExpenseItem>> getExpenses({String? userType});
  Future<void> deleteExpense(String id);
  Future<void> updateExpense(ExpenseItem item);
  // 유형 전환 확인 다이얼로그용 — 해당 유형으로 "전용" 태깅된 기록이 하나라도 있는지.
  Future<bool> hasOwnLedgerHistory(String userType);
  // 가계부 유형 이동(가져오기) — from→to로 user_type 재태깅. 미리보기와 실제 이동.
  Future<LedgerMoveSummary> previewLedgerMove({required String from, required String to});
  Future<void> moveLedgerRecords({required String from, required String to});
  Future<void> insertTaxRecord(Map<String, dynamic> record);
  Future<List<Map<String, dynamic>>> getTaxRecords();
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch);
  Future<int?> getBannerHideTime(String bannerId);
  Future<Map<String, int>> getAllBannerHideTimes();
  // 일별 수입 기록 (v14)
  Future<void> insertIncomeEntry(IncomeEntry entry);
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month, {String? userType});
  Future<void> updateIncomeEntry(IncomeEntry entry);
  Future<void> deleteIncomeEntry(String id, int year, int month);
  // ②진단 결과(가상 신고서 draft) 영속화 → ③에서 자동기입
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund});
  Future<Map<String, dynamic>?> getReportDraft(String userType);
  // 연말정산 기록 원시 입력값(수기/PDF) — user_type별 1건, 진단 자동기입용
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values);
  Future<Map<String, dynamic>?> getAnnualRecord(String userType);
  // 사용자 맞춤 리마인더 (v20) — 항목·기한·알림시각, 시스템 알림 예약 연동
  Future<int> insertReminder(Map<String, dynamic> reminder); // 생성된 id 반환
  Future<List<Map<String, dynamic>>> getReminders();
  Future<void> updateReminder(Map<String, dynamic> reminder);
  Future<void> deleteReminder(int id);
  // 시스템 알림 토글 상태 (v22) — key별 on/off, 값 없으면 ON으로 간주
  Future<Map<String, bool>> getReminderSettings();
  Future<void> setReminderSetting(String key, bool enabled);
  // 발화 알림 로그 (v23) — 즉시형 알림 기록 (홈 알림함)
  // firedAt 생략 시 호출 시각(now)으로 기록 — 예약 알림 역산 백필(v27)은 실제 발화 시각을 넘긴다.
  Future<void> insertNotificationLog({required String title, required String body, String? category, DateTime? firedAt});
  Future<List<Map<String, dynamic>>> getNotificationLogs();
  Future<void> markAllNotificationsRead();
  Future<int> unreadNotificationCount();
  Future<void> clearNotificationLogs();
  // 잡다한 단일 키-값 앱 상태 (v27) — 알림 히스토리 역산 체크포인트 등
  Future<String?> getAppState(String key);
  Future<void> setAppState(String key, String value);
  // 전역 에러 로그 (v36, T-1) — 개인정보 없이 메시지·스택트레이스만, 최근 100건 순환
  Future<void> insertErrorLog(String message, String stackTrace);
  Future<List<Map<String, dynamic>>> getErrorLogs();
  // 이벤트 트리거형 기본 제공 알림 설정 (v28) — 예산 알림·미기록 넛지처럼 날짜가 아니라
  // 조건 충족 시 발화하는 알림의 on/off + 발화 시각. 행 없으면 코드 기본값 사용.
  Future<Map<String, Map<String, dynamic>>> getEventReminderPrefs();
  Future<void> setEventReminderPref(String key,
      {required bool enabled, required int hour, required int minute});
  // 고정 지출 템플릿 (v25)
  Future<int> insertRecurringTemplate(RecurringTemplate t);
  Future<List<RecurringTemplate>> getRecurringTemplates();
  Future<void> updateRecurringTemplate(RecurringTemplate t);
  Future<void> deleteRecurringTemplate(int id);
  Future<int> getPendingRecurringCount(int year, int month);
  Future<List<Map<String, dynamic>>> getRecurringConfirmations(int year, int month);
  Future<void> confirmRecurring(int templateId, int year, int month, {required int amount, required String expenseId});
  // 즐겨찾기 빠른 입력 프리셋 (v33)
  Future<int> insertQuickEntryPreset(QuickEntryPreset p);
  Future<List<QuickEntryPreset>> getQuickEntryPresets();
  Future<void> deleteQuickEntryPreset(int id);
  Future<void> skipRecurring(int templateId, int year, int month);
  // 카드 결제일 목록 (v26)
  Future<List<Map<String, dynamic>>> getCardPaymentDates();
  Future<int> addCardPaymentDate(String name, int day);
  Future<void> deleteCardPaymentDate(int id);
  // 백업/복원 — 전 테이블을 JSON 직렬화 가능한 맵으로 내보내고/되돌린다(오프라인 파일 백업)
  Future<Map<String, dynamic>> exportAllData();
  Future<void> importAllData(Map<String, dynamic> data);
  Future<void> destroyAllData(); // 복구 불가능 영구 파기
  Future<void> close();
}

/// 백업 대상 테이블(사용자 데이터). 스키마에 없을 수 있어 조회 시 개별 try.
const List<String> kBackupTables = [
  'user_profile',
  'expenses',
  'income_entries',
  'monthly_card_usage',
  'tax_records',
  'report_drafts',
  'annual_records',
  'reminders',
  'reminder_settings',
  'banner_states',
  'recurring_templates',
  'card_payment_dates',
];

/// 1. 실제 모바일 기기 구동용 Sqflite 데이터베이스 서비스 구현
class SqfliteDatabaseHelper implements DatabaseService {
  Database? _db;
  final String dbName = 'secul.db';

  /// 사용자 맞춤 리마인더 테이블 정의 (v21)
  /// repeat_monthly(구버전)는 호환용으로 남기고, 반복 주기는 frequency로 표현.
  static const String _remindersTableSql = '''
    CREATE TABLE IF NOT EXISTS reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      kind TEXT,
      due_date TEXT,
      notify_date TEXT,
      notify_hour INTEGER,
      notify_minute INTEGER,
      repeat_monthly INTEGER DEFAULT 0,
      frequency TEXT DEFAULT 'once',
      weekday INTEGER,
      weekdays TEXT,
      enabled INTEGER DEFAULT 1,
      notif_id INTEGER
    )
  ''';

  /// 시스템 알림 토글 상태 테이블 (v22). 행이 없으면 ON으로 간주.
  static const String _reminderSettingsTableSql = '''
    CREATE TABLE IF NOT EXISTS reminder_settings (
      key TEXT PRIMARY KEY,
      enabled INTEGER DEFAULT 1
    )
  ''';

  /// 발화 알림 로그 테이블 (v23). 즉시형 알림 기록용.
  static const String _notificationLogTableSql = '''
    CREATE TABLE IF NOT EXISTS notification_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      fired_at TEXT NOT NULL,
      is_read INTEGER DEFAULT 0,
      category TEXT
    )
  ''';

  /// 고정 지출 템플릿 (v25)
  static const String _recurringTemplatesTableSql = '''
    CREATE TABLE IF NOT EXISTS recurring_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount_hint INTEGER DEFAULT 0,
      category TEXT NOT NULL DEFAULT '기타',
      payment_method TEXT NOT NULL DEFAULT '기타',
      day_of_month INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER DEFAULT 0,
      is_business INTEGER DEFAULT 0
    )
  ''';

  /// 즐겨찾기 빠른 입력 프리셋 (v33)
  /// 전역 에러 로그 (v36, T-1) — FlutterError.onError·runZonedGuarded가 여기 적재.
  /// 개인정보 없이 에러 메시지·스택트레이스만 저장, 최근 100건 순환.
  static const String _errorLogTableSql = '''
    CREATE TABLE IF NOT EXISTS error_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      occurred_at TEXT,
      message TEXT,
      stack_trace TEXT
    )
  ''';

  static const String _quickEntryPresetsTableSql = '''
    CREATE TABLE IF NOT EXISTS quick_entry_presets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount INTEGER NOT NULL DEFAULT 0,
      category TEXT NOT NULL DEFAULT '기타',
      payment_method TEXT NOT NULL DEFAULT '기타',
      is_business INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0
    )
  ''';

  /// 고정 지출 월별 확인 기록 (v25)
  static const String _recurringConfirmationsTableSql = '''
    CREATE TABLE IF NOT EXISTS recurring_confirmations (
      template_id INTEGER NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      status INTEGER DEFAULT 0,
      actual_amount INTEGER DEFAULT 0,
      expense_id TEXT,
      PRIMARY KEY (template_id, year, month)
    )
  ''';

  /// 카드 결제일 목록 (v26)
  static const String _cardPaymentDatesTableSql = '''
    CREATE TABLE IF NOT EXISTS card_payment_dates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      day INTEGER NOT NULL
    )
  ''';

  /// 잡다한 단일 키-값 앱 상태 (v27). 알림 히스토리 역산 체크포인트 등.
  static const String _appStateTableSql = '''
    CREATE TABLE IF NOT EXISTS app_state (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''';

  /// 이벤트 트리거형 기본 제공 알림 설정 (v28). 예산 알림·미기록 넛지.
  static const String _eventReminderPrefsTableSql = '''
    CREATE TABLE IF NOT EXISTS event_reminder_prefs (
      key TEXT PRIMARY KEY,
      enabled INTEGER DEFAULT 1,
      hour INTEGER,
      minute INTEGER
    )
  ''';

  static const String _profileTypeValuesTableSql = '''
    CREATE TABLE IF NOT EXISTS profile_type_values (
      user_type TEXT PRIMARY KEY,
      gross_income REAL DEFAULT 0,
      expense_target REAL DEFAULT 0
    )
  ''';

  @override
  Future<void> initDatabase() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    final key = await DbKeyManager.getOrCreateKey();

    // 기존 평문 DB가 있고 아직 암호화 전이면: 먼저 평문 상태로 최신 스키마까지 정규화한 뒤
    // SQLCipher 암호화 DB로 1회 이전한다(S-2). 신규 설치는 곧장 암호화 DB로 생성된다.
    if (await File(path).exists() && !await _isAlreadyEncrypted(path, key)) {
      final normalizeDb = await openDatabase(path, version: 42, onCreate: _onCreate, onUpgrade: _onUpgrade);
      await normalizeDb.close();
      await _encryptExistingPlaintextDb(path, key);
    }

    _db = await openDatabase(
      path,
      password: key,
      version: 42,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<bool> _isAlreadyEncrypted(String path, String key) async {
    try {
      final testDb = await openDatabase(path, password: key, readOnly: true);
      await testDb.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 평문 DB(정규화 완료 v35)를 새 SQLCipher 암호화 DB로 1회 이전.
  /// 임시 파일에 전체 이전 완료·행 수 검증 후에만 원본을 교체한다 — 중간 실패 시
  /// 원본 평문 파일은 그대로 남아 다음 실행에서 재시도된다.
  Future<void> _encryptExistingPlaintextDb(String path, String key) async {
    final tempEncPath = '$path.migrating_enc';
    final legacyBackupPath = '$path.legacy_plaintext_backup';

    final tempFile = File(tempEncPath);
    if (await tempFile.exists()) await tempFile.delete();

    final plainDb = await openDatabase(path, readOnly: true);
    final tableRows = await plainDb.query('sqlite_master',
        where: "type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'");
    final dump = <String, List<Map<String, Object?>>>{};
    var totalRows = 0;
    for (final t in tableRows) {
      final name = t['name'] as String;
      try {
        final rows = await plainDb.query(name);
        dump[name] = rows;
        totalRows += rows.length;
      } catch (_) {}
    }
    await plainDb.close();

    final encDb = await openDatabase(tempEncPath, password: key, version: 42, onCreate: _onCreate);
    var insertedRows = 0;
    await encDb.transaction((txn) async {
      for (final entry in dump.entries) {
        for (final row in entry.value) {
          final transformed = decryptLegacyRowForTable(entry.key, row);
          try {
            await txn.insert(entry.key, transformed, conflictAlgorithm: ConflictAlgorithm.replace);
            insertedRows++;
          } catch (_) {}
        }
      }
    });
    await encDb.close();

    if (insertedRows < totalRows) {
      try { await tempFile.delete(); } catch (_) {}
      throw StateError('DB 암호화 마이그레이션 실패: $insertedRows/$totalRows행만 이전됨');
    }

    if (await File(legacyBackupPath).exists()) await File(legacyBackupPath).delete();
    await File(path).rename(legacyBackupPath);
    await tempFile.rename(path);
  }

  Future<void> _onCreate(Database db, int version) async {
        // 프로필 테이블 생성
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_type TEXT,
            gross_income REAL,
            dependents INTEGER,
            age INTEGER,
            military_months INTEGER,
            is_monthly_rent INTEGER,
            monthly_rent REAL,
            decided_tax REAL,
            yellow_umbrella REAL,
            monthly_income REAL,
            is_married INTEGER,
            is_spouse_dependent INTEGER,
            has_spouse_disability INTEGER,
            has_self_disability INTEGER,
            disabled_dependent_count INTEGER,
            data_mode TEXT,
            expense_target REAL,
            has_elderly_70plus INTEGER,
            is_female_head INTEGER,
            is_single_parent INTEGER,
            wedding_year INTEGER,
            children_count_credit INTEGER,
            children_count_total INTEGER,
            newborn_count INTEGER,
            newborn_year INTEGER,
            is_sme_employee INTEGER,
            sme_start_year INTEGER,
            pay_day INTEGER DEFAULT 25,
            type_identified INTEGER DEFAULT 0,
            owns_car INTEGER,
            owns_house INTEGER,
            occupation_code TEXT,
            deduction_picks TEXT,
            property_value REAL,
            pension_enrolled INTEGER DEFAULT 0,
            health_enrolled INTEGER DEFAULT 0,
            employment_enrolled INTEGER DEFAULT 0,
            industrial_accident_enrolled INTEGER DEFAULT 0,
            prior_year_income REAL,
            is_new_business INTEGER DEFAULT 0,
            has_multiple_businesses INTEGER DEFAULT 0,
            freelancer_health_insurance REAL
          )
        ''');
        // 지출 내역 테이블 생성 (민감 정보는 텍스트 암호화 상태로 저장)
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            date TEXT,
            end_date TEXT,
            amount TEXT,
            content TEXT,
            category TEXT,
            payment_method TEXT,
            is_business INTEGER DEFAULT 0,
            user_type TEXT
          )
        ''');
        // 세무 기록부 테이블 생성
        await db.execute('''
          CREATE TABLE tax_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            record_year INTEGER,
            record_type TEXT,
            gross_income REAL,
            refund_amount REAL,
            created_at TEXT
          )
        ''');
        // 배너 숨김 상태 테이블
        await db.execute('''
          CREATE TABLE banner_states (
            banner_id TEXT PRIMARY KEY,
            hide_until_epoch INTEGER
          )
        ''');
        // 당월 카드·현금 누계 테이블
        await db.execute('''
          CREATE TABLE monthly_card_usage (
            year INTEGER,
            month INTEGER,
            credit_card_total REAL DEFAULT 0,
            debit_cash_total REAL DEFAULT 0,
            PRIMARY KEY (year, month)
          )
        ''');
        // 일별 수입 기록 테이블 (v14) — 암호화 저장
        await db.execute('''
          CREATE TABLE income_entries (
            id TEXT PRIMARY KEY,
            date TEXT,
            end_date TEXT,
            amount TEXT,
            memo TEXT,
            income_type TEXT,
            is_withheld INTEGER DEFAULT 0,
            user_type TEXT
          )
        ''');
        // ②진단 결과(가상 신고서 draft) — user_type별 1건
        await db.execute('''
          CREATE TABLE report_drafts (
            user_type TEXT PRIMARY KEY,
            report_type TEXT,
            items TEXT,
            final_amount REAL,
            is_refund INTEGER,
            created_at TEXT
          )
        ''');
        // 연말정산 기록 원시값(암호화 JSON) — user_type별 1건
        await db.execute('''
          CREATE TABLE annual_records (
            user_type TEXT PRIMARY KEY,
            payload TEXT,
            created_at TEXT
          )
        ''');
        // 사용자 맞춤 리마인더 (v20)
        await db.execute(_remindersTableSql);
        // 시스템 알림 토글 (v22)
        await db.execute(_reminderSettingsTableSql);
        // 발화 알림 로그 (v23)
        await db.execute(_notificationLogTableSql);
        // 고정 지출 템플릿 (v25)
        await db.execute(_recurringTemplatesTableSql);
        await db.execute(_recurringConfirmationsTableSql);
        // 카드 결제일 (v26)
        await db.execute(_cardPaymentDatesTableSql);
        // 앱 상태 (v27)
        await db.execute(_appStateTableSql);
        // 이벤트 트리거형 기본 제공 알림 설정 (v28)
        await db.execute(_eventReminderPrefsTableSql);
        // 유형별 독립 프로필 값 (v30)
        await db.execute(_profileTypeValuesTableSql);
        // 즐겨찾기 빠른 입력 프리셋 (v33)
        await db.execute(_quickEntryPresetsTableSql);
        // 전역 에러 로그 (v36) — 최근 100건 순환
        await db.execute(_errorLogTableSql);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN monthly_income REAL');
          } catch (e) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_married INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_spouse_dependent INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_spouse_disability INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_self_disability INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN disabled_dependent_count INTEGER');
          } catch (e) {}
          try {
            await db.execute('''
              CREATE TABLE tax_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_year INTEGER,
                record_type TEXT,
                gross_income REAL,
                refund_amount REAL,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
              CREATE TABLE banner_states (
                banner_id TEXT PRIMARY KEY,
                hide_until_epoch INTEGER
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN data_mode TEXT');
          } catch (e) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN paid_tax REAL');
            await db.execute('ALTER TABLE user_profile ADD COLUMN withholding_text TEXT');
          } catch (e) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
              CREATE TABLE monthly_card_usage (
                year INTEGER,
                month INTEGER,
                credit_card_total REAL DEFAULT 0,
                debit_cash_total REAL DEFAULT 0,
                PRIMARY KEY (year, month)
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN end_date TEXT');
          } catch (e) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE monthly_income_records (
                year INTEGER,
                month INTEGER,
                amount REAL,
                PRIMARY KEY (year, month)
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 10) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN expense_target REAL');
          } catch (e) {}
        }
        if (oldVersion < 11) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_elderly_70plus INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_female_head INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_single_parent INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 12) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN wedding_year INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN children_count_8plus INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN newborn_count INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 13) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_sme_employee INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN sme_start_year INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 14) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS income_entries (
                id TEXT PRIMARY KEY,
                date TEXT,
                amount TEXT,
                memo TEXT,
                income_type TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 15) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN pay_day INTEGER DEFAULT 25');
          } catch (e) {}
        }
        if (oldVersion < 16) {
          try {
            await db.execute('ALTER TABLE income_entries ADD COLUMN end_date TEXT');
          } catch (e) {}
        }
        if (oldVersion < 17) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN type_identified INTEGER DEFAULT 0');
          } catch (e) {}
        }
        if (oldVersion < 18) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS report_drafts (
                user_type TEXT PRIMARY KEY,
                report_type TEXT,
                items TEXT,
                final_amount REAL,
                is_refund INTEGER,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 19) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS annual_records (
                user_type TEXT PRIMARY KEY,
                payload TEXT,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 20) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN military_months INTEGER');
          } catch (e) {}
          try {
            await db.execute(_remindersTableSql);
          } catch (e) {}
        }
        if (oldVersion < 21) {
          try {
            await db.execute("ALTER TABLE reminders ADD COLUMN frequency TEXT DEFAULT 'once'");
            await db.execute('ALTER TABLE reminders ADD COLUMN weekday INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 22) {
          try {
            await db.execute(_reminderSettingsTableSql);
          } catch (e) {}
        }
        if (oldVersion < 23) {
          try {
            await db.execute(_notificationLogTableSql);
          } catch (e) {}
        }
        if (oldVersion < 24) {
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN payment_method TEXT');
            // 기존 category(결제수단) → payment_method로 이관, category는 '기타'(미분류)로 초기화
            final rows = await db.query('expenses');
            for (final row in rows) {
              try {
                final oldCat = row['category'] as String?;
                if (oldCat != null) {
                  final encNewCat = CryptoHelper.encrypt('기타');
                  await db.update('expenses', {
                    'payment_method': oldCat,
                    'category': encNewCat,
                  }, where: 'id = ?', whereArgs: [row['id']]);
                }
              } catch (_) {}
            }
          } catch (e) {}
        }
        if (oldVersion < 25) {
          try {
            await db.execute(_recurringTemplatesTableSql);
            await db.execute(_recurringConfirmationsTableSql);
          } catch (e) {}
        }
        if (oldVersion < 26) {
          try {
            await db.execute(_cardPaymentDatesTableSql);
          } catch (e) {}
        }
        if (oldVersion < 27) {
          try {
            await db.execute(_appStateTableSql);
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE reminders ADD COLUMN weekdays TEXT');
          } catch (e) {}
        }
        if (oldVersion < 28) {
          try {
            await db.execute(_eventReminderPrefsTableSql);
          } catch (e) {}
        }
        if (oldVersion < 29) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN owns_car INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN owns_house INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 30) {
          try {
            await db.execute(_profileTypeValuesTableSql);
          } catch (e) {}
        }
        // 프리랜서·N잡러 사업경비 인정 / 3.3% 원천징수 사업소득 구분 (v31)
        if (oldVersion < 31) {
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN is_business INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE income_entries ADD COLUMN is_withheld INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE recurring_templates ADD COLUMN is_business INTEGER DEFAULT 0');
          } catch (e) {}
        }
        // 프리랜서·N잡러 세금·4대보험 적립 추정용 프로필 필드 (v32)
        if (oldVersion < 32) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN occupation_code TEXT');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN property_value REAL');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN pension_enrolled INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN health_enrolled INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN employment_enrolled INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN industrial_accident_enrolled INTEGER DEFAULT 0');
          } catch (e) {}
        }
        // 즐겨찾기 빠른 입력 프리셋 (v33)
        if (oldVersion < 33) {
          await db.execute(_quickEntryPresetsTableSql);
        }
        // 기장의무 판정용 프로필 필드 — 직전연도 수입·신규사업자·겸업 (v34)
        if (oldVersion < 34) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN prior_year_income REAL');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_new_business INTEGER DEFAULT 0');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_multiple_businesses INTEGER DEFAULT 0');
          } catch (e) {}
        }
        // 가계부 유형별 분리 — 기존 기록은 user_type NULL(공통)로 남고, 앞으로 새로 적는
        // 기록부터 현재 선택된 유형으로 태깅된다 (v35).
        if (oldVersion < 35) {
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN user_type TEXT');
          } catch (e) {}
          try {
            await db.execute('ALTER TABLE income_entries ADD COLUMN user_type TEXT');
          } catch (e) {}
        }
        // 전역 에러 로그 (v36)
        if (oldVersion < 36) {
          try {
            await db.execute(_errorLogTableSql);
          } catch (e) {}
        }
        // monthly_income_records 캐시 제거 (v37) — income_entries를 유형별로 직접
        // 합산하는 방식(T-3/T-4)으로 대체되어 더 이상 쓰지 않음(T-4).
        if (oldVersion < 37) {
          try {
            await db.execute('DROP TABLE IF EXISTS monthly_income_records');
          } catch (e) {}
        }
        // 건강보험 지역가입자 연간 납부액 (v38) — 전액 소득공제 대상인데 그동안
        // 세무 시뮬레이터 화면 안에서만 살아 있어, 적립·환급 계산이 이 공제를
        // 빼놓고 세액을 과대 추정했다.
        if (oldVersion < 38) {
          try {
            await db.execute(
                'ALTER TABLE user_profile ADD COLUMN freelancer_health_insurance REAL');
          } catch (e) {}
        }
        // 자녀 수 (v39) — 카드공제 기본한도가 2025 개정으로 자녀 수에 따라
        // 300→350·400만으로 올라가는데(조특법 §126의2⑩) 그 입력이 없었다.
        // children_count_8plus는 컬럼만 있고 입력 UI가 없어 늘 0이었다.
        if (oldVersion < 39) {
          try {
            await db.execute(
                'ALTER TABLE user_profile ADD COLUMN children_count_total INTEGER');
          } catch (e) {}
        }

        // 자녀세액공제 연령기준 개정 (v40) — 소득세법 §59의2① 개정(법률 제21548호,
        // 2026.4.21.)으로 대상 연령이 8세 이상에서 연도별로 올라간다(2026 귀속 9세).
        // 종전 children_count_8plus는 "8세 이상" 정의로 입력된 값이라 그대로 쓸 수
        // 없다 — 출생연도를 모르면 새 정의로 환산할 수 없으므로 값을 넘기지 않고
        // 새 컬럼에서 다시 받는다.
        if (oldVersion < 40) {
          try {
            await db.execute(
                'ALTER TABLE user_profile ADD COLUMN children_count_credit INTEGER');
          } catch (e) {}
        }

        // 공제 고르기 결과 (v41) — 쉼표로 이은 항목 id.
        // 저장해 두면 계산기에 바로 들어와도 자기와 무관한 입력이 접힌 채로 열리고,
        // 안 고른 항목을 되물을 수 있다. 게이트를 매번 통과시키지 않아도 된다.
        if (oldVersion < 41) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN deduction_picks TEXT');
          } catch (e) {}
        }
        // v42 — 출산·입양 세액공제는 그 해에만 받는다. 수만 저장하면 내년에도
        // 남아 없는 공제를 계속 넣는다. 어느 해 일인지 같이 적는다.
        if (oldVersion < 42) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN newborn_year INTEGER');
          } catch (e) {}
        }
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final db = _db;
    if (db == null) return;

    await db.transaction((txn) async {
      await txn.delete('user_profile'); // 기존 단일 프로필 유지
      await txn.insert('user_profile', {
        'user_type': profile['user_type'],
        'gross_income': profile['gross_income'],
        'dependents': profile['dependents'],
        'age': profile['age'],
        'military_months': profile['military_months'],
        'is_monthly_rent': profile['is_monthly_rent'] == true ? 1 : 0,
        'monthly_rent': profile['monthly_rent'],
        'decided_tax': profile['decided_tax'],
        'yellow_umbrella': profile['yellow_umbrella'],
        'monthly_income': profile['monthly_income'],
        'is_married': profile['is_married'] == true ? 1 : 0,
        'is_spouse_dependent': profile['is_spouse_dependent'] == true ? 1 : 0,
        'has_spouse_disability': profile['has_spouse_disability'] == true ? 1 : 0,
        'has_self_disability': profile['has_self_disability'] == true ? 1 : 0,
        'disabled_dependent_count': profile['disabled_dependent_count'] ?? 0,
        'data_mode': profile['data_mode'] ?? 'manual',
        'paid_tax': profile['paid_tax'],
        'withholding_text': profile['withholding_text'],
        'expense_target': profile['expense_target'],
        'has_elderly_70plus': profile['has_elderly_70plus'] == true ? 1 : 0,
        'is_female_head': profile['is_female_head'] == true ? 1 : 0,
        'is_single_parent': profile['is_single_parent'] == true ? 1 : 0,
        'wedding_year': profile['wedding_year'],
        'deduction_picks': profile['deduction_picks'],
        'children_count_credit': profile['children_count_credit'] ?? 0,
        'children_count_total': profile['children_count_total'] ?? 0,
        'newborn_count': profile['newborn_count'] ?? 0,
        'newborn_year': profile['newborn_year'] ?? 0,
        'is_sme_employee': profile['is_sme_employee'] == true ? 1 : 0,
        'sme_start_year': profile['sme_start_year'],
        'pay_day': profile['pay_day'] ?? 25,
        'type_identified': profile['type_identified'] == true ? 1 : 0,
        'owns_car': profile['owns_car'] == null ? null : (profile['owns_car'] == true ? 1 : 0),
        'owns_house': profile['owns_house'] == null ? null : (profile['owns_house'] == true ? 1 : 0),
        'occupation_code': profile['occupation_code'],
        'property_value': profile['property_value'],
        'pension_enrolled': profile['pension_enrolled'] == true ? 1 : 0,
        'health_enrolled': profile['health_enrolled'] == true ? 1 : 0,
        'employment_enrolled': profile['employment_enrolled'] == true ? 1 : 0,
        'industrial_accident_enrolled': profile['industrial_accident_enrolled'] == true ? 1 : 0,
        'prior_year_income': profile['prior_year_income'],
        'freelancer_health_insurance': profile['freelancer_health_insurance'],
        'is_new_business': profile['is_new_business'] == true ? 1 : 0,
        'has_multiple_businesses': profile['has_multiple_businesses'] == true ? 1 : 0,
      });
    });
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final db = _db;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query('user_profile');
    if (maps.isEmpty) return null;

    final map = maps.first;
    return {
      'user_type': map['user_type'],
      'gross_income': map['gross_income'],
      'dependents': map['dependents'],
      'age': map['age'] as int?,
      'military_months': map['military_months'] as int?,
      'is_monthly_rent': map['is_monthly_rent'] == 1,
      'monthly_rent': map['monthly_rent'],
      'decided_tax': map['decided_tax'],
      'yellow_umbrella': map['yellow_umbrella'],
      'monthly_income': map['monthly_income'],
      'is_married': map['is_married'] == 1,
      'is_spouse_dependent': map['is_spouse_dependent'] == 1,
      'has_spouse_disability': map['has_spouse_disability'] == 1,
      'has_self_disability': map['has_self_disability'] == 1,
      'disabled_dependent_count': map['disabled_dependent_count'] ?? 0,
      'data_mode': map['data_mode'] ?? 'manual',
      'paid_tax': map['paid_tax'],
      'withholding_text': map['withholding_text'],
      'expense_target': map['expense_target'],
      'has_elderly_70plus': map['has_elderly_70plus'] == 1,
      'is_female_head': map['is_female_head'] == 1,
      'is_single_parent': map['is_single_parent'] == 1,
      'wedding_year': map['wedding_year'] as int?,
      'deduction_picks': map['deduction_picks'] as String?,
      'children_count_credit': map['children_count_credit'] as int? ?? 0,
      'children_count_total': map['children_count_total'] as int? ?? 0,
      'newborn_count': map['newborn_count'] as int? ?? 0,
      'newborn_year': map['newborn_year'] as int? ?? 0,
      'is_sme_employee': map['is_sme_employee'] == 1,
      'sme_start_year': map['sme_start_year'] as int?,
      'pay_day': map['pay_day'] as int? ?? 25,
      'type_identified': map['type_identified'] == 1,
      // null(마이그레이션 이전 기존 사용자, 미입력)은 그대로 null 유지 — 알림 필터링 쪽에서 "?? true"로 기본값 처리.
      'owns_car': map['owns_car'] == null ? null : map['owns_car'] == 1,
      'owns_house': map['owns_house'] == null ? null : map['owns_house'] == 1,
      'occupation_code': map['occupation_code'] as String?,
      'property_value': map['property_value'],
      'pension_enrolled': map['pension_enrolled'] == 1,
      'health_enrolled': map['health_enrolled'] == 1,
      'employment_enrolled': map['employment_enrolled'] == 1,
      'industrial_accident_enrolled': map['industrial_accident_enrolled'] == 1,
      'prior_year_income': map['prior_year_income'],
      'freelancer_health_insurance': map['freelancer_health_insurance'],
      'is_new_business': map['is_new_business'] == 1,
      'has_multiple_businesses': map['has_multiple_businesses'] == 1,
    };
  }

  @override
  Future<void> setProfileTypeValues(String userType, {double? grossIncome, double? expenseTarget}) async {
    final db = _db;
    if (db == null) return;
    final existing = await getProfileTypeValues(userType);
    await db.insert(
      'profile_type_values',
      {
        'user_type': userType,
        'gross_income': grossIncome ?? existing['gross_income'],
        'expense_target': expenseTarget ?? existing['expense_target'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, double>> getProfileTypeValues(String userType) async {
    final db = _db;
    if (db == null) return {'gross_income': 0.0, 'expense_target': 0.0};
    final rows = await db.query('profile_type_values', where: 'user_type = ?', whereArgs: [userType]);
    if (rows.isEmpty) return {'gross_income': 0.0, 'expense_target': 0.0};
    return {
      'gross_income': (rows.first['gross_income'] as num?)?.toDouble() ?? 0.0,
      'expense_target': (rows.first['expense_target'] as num?)?.toDouble() ?? 0.0,
    };
  }

  @override
  Future<void> insertTaxRecord(Map<String, dynamic> record) async {
    final db = _db;
    if (db == null) return;
    await db.insert('tax_records', record);
  }

  @override
  Future<List<Map<String, dynamic>>> getTaxRecords() async {
    final db = _db;
    if (db == null) return [];
    return await db.query('tax_records', orderBy: 'created_at DESC');
  }

  @override
  Future<void> insertExpense(ExpenseItem item) async {
    final db = _db;
    if (db == null) return;

    // DB 파일 자체가 SQLCipher로 암호화되어 필드 단위 암호화는 불필요(S-2).
    await db.insert(
      'expenses',
      {
        'id': item.id,
        'date': item.date.toIso8601String(),
        'end_date': item.endDate?.toIso8601String(),
        'amount': item.amount.toString(),
        'content': item.content,
        'category': item.category,
        'payment_method': item.paymentMethod,
        'is_business': item.isBusiness ? 1 : 0,
        'user_type': item.userType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ExpenseItem>> getExpenses({String? userType}) async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = userType == null
        ? await db.query('expenses')
        : await db.query('expenses',
            where: 'user_type = ? OR user_type IS NULL', whereArgs: [userType]);
    final List<ExpenseItem> list = [];

    for (final map in maps) {
      try {
        final String decryptedAmountStr = map['amount'] as String;
        final String decryptedContent = map['content'] as String;
        final String decryptedCategory = map['category'] as String;

        final pmRaw = map['payment_method'] as String?;
        final String paymentMethod = pmRaw ?? '기타';

        final int amount = int.parse(decryptedAmountStr);
        final DateTime date = DateTime.parse(map['date'] as String);
        final endDateStr = map['end_date'] as String?;

        list.add(ExpenseItem(
          id: map['id'] as String,
          date: date,
          endDate: endDateStr != null ? DateTime.parse(endDateStr) : null,
          amount: amount,
          content: decryptedContent,
          category: decryptedCategory,
          paymentMethod: paymentMethod,
          isBusiness: (map['is_business'] as int?) == 1,
          userType: map['user_type'] as String?,
        ));
      } catch (e) {
        // 복호화 실패 등 예외 시 무시
      }
    }
    return list;
  }

  @override
  Future<void> deleteExpense(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateExpense(ExpenseItem item) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'expenses',
      {
        'date': item.date.toIso8601String(),
        'end_date': item.endDate?.toIso8601String(),
        'amount': item.amount.toString(),
        'content': item.content,
        'category': item.category,
        'payment_method': item.paymentMethod,
        'is_business': item.isBusiness ? 1 : 0,
        'user_type': item.userType,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> insertIncomeEntry(IncomeEntry entry) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'income_entries',
      {
        'id': entry.id,
        'date': entry.date.toIso8601String(),
        'end_date': entry.endDate?.toIso8601String(),
        'amount': entry.amount.toString(),
        'memo': entry.memo,
        'income_type': entry.incomeType,
        'is_withheld': entry.isWithheld ? 1 : 0,
        'user_type': entry.userType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month, {String? userType}) async {
    final db = _db;
    if (db == null) return [];
    final rows = userType == null
        ? await db.query('income_entries')
        : await db.query('income_entries',
            where: 'user_type = ? OR user_type IS NULL', whereArgs: [userType]);
    final result = <IncomeEntry>[];
    for (final row in rows) {
      try {
        final date = DateTime.parse(row['date'] as String);
        if (date.year != year || date.month != month) continue;
        final endStr = row['end_date'] as String?;
        result.add(IncomeEntry(
          id: row['id'] as String,
          date: date,
          endDate: endStr != null ? DateTime.parse(endStr) : null,
          amount: int.parse(row['amount'] as String),
          memo: row['memo'] as String,
          incomeType: row['income_type'] as String,
          isWithheld: (row['is_withheld'] as int?) == 1,
          userType: row['user_type'] as String?,
        ));
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<void> updateIncomeEntry(IncomeEntry entry) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'income_entries',
      {
        'date': entry.date.toIso8601String(),
        'end_date': entry.endDate?.toIso8601String(),
        'amount': entry.amount.toString(),
        'memo': entry.memo,
        'income_type': entry.incomeType,
        'is_withheld': entry.isWithheld ? 1 : 0,
        'user_type': entry.userType,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  @override
  Future<void> deleteIncomeEntry(String id, int year, int month) async {
    final db = _db;
    if (db == null) return;
    await db.delete('income_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> hasOwnLedgerHistory(String userType) async {
    final db = _db;
    if (db == null) return false;
    final expenseRows = await db.query('expenses',
        where: 'user_type = ?', whereArgs: [userType], limit: 1);
    if (expenseRows.isNotEmpty) return true;
    final incomeRows = await db.query('income_entries',
        where: 'user_type = ?', whereArgs: [userType], limit: 1);
    return incomeRows.isNotEmpty;
  }

  @override
  Future<LedgerMoveSummary> previewLedgerMove({required String from, required String to}) async {
    final db = _db;
    if (db == null) {
      return const LedgerMoveSummary(expenseCount: 0, movableIncomeCount: 0, orphanIncomeCount: 0);
    }
    final valid = movableIncomeTypesTo(to);
    final expenseRows = await db.query('expenses',
        columns: ['id'], where: 'user_type = ?', whereArgs: [from]);
    final incomeRows = await db.query('income_entries',
        columns: ['income_type'], where: 'user_type = ?', whereArgs: [from]);
    int movable = 0, orphan = 0;
    for (final r in incomeRows) {
      if (valid.contains(r['income_type'] as String?)) { movable++; } else { orphan++; }
    }
    return LedgerMoveSummary(
        expenseCount: expenseRows.length, movableIncomeCount: movable, orphanIncomeCount: orphan);
  }

  @override
  Future<void> moveLedgerRecords({required String from, required String to}) async {
    final db = _db;
    if (db == null) return;
    final valid = movableIncomeTypesTo(to);
    // 지출은 개인 소비라 전부 이동.
    await db.update('expenses', {'user_type': to}, where: 'user_type = ?', whereArgs: [from]);
    // 수입은 대상 유형이 지원하는 소득 유형만 이동(나머지는 원본 유형에 그대로 남는다).
    if (valid.isNotEmpty) {
      final ph = List.filled(valid.length, '?').join(',');
      await db.update('income_entries', {'user_type': to},
          where: 'user_type = ? AND income_type IN ($ph)', whereArgs: [from, ...valid]);
    }
  }

  @override
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch) async {
    final db = _db;
    if (db == null) return;
    await db.insert('banner_states', {
      'banner_id': bannerId,
      'hide_until_epoch': hideUntilEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int?> getBannerHideTime(String bannerId) async {
    final db = _db;
    if (db == null) return null;
    final maps = await db.query('banner_states', where: 'banner_id = ?', whereArgs: [bannerId]);
    if (maps.isEmpty) return null;
    return maps.first['hide_until_epoch'] as int?;
  }

  @override
  Future<Map<String, int>> getAllBannerHideTimes() async {
    final db = _db;
    if (db == null) return {};
    final maps = await db.query('banner_states');
    final Map<String, int> result = {};
    for (var map in maps) {
      result[map['banner_id'] as String] = map['hide_until_epoch'] as int;
    }
    return result;
  }

  @override
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund}) async {
    final db = _db;
    if (db == null) return;
    await db.insert('report_drafts', {
      'user_type': userType,
      'report_type': reportType,
      'items': jsonEncode(items),
      'final_amount': finalAmount,
      'is_refund': isRefund ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getReportDraft(String userType) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('report_drafts', where: 'user_type = ?', whereArgs: [userType]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    List<Map<String, dynamic>> items = [];
    try {
      final decoded = jsonDecode(r['items'] as String? ?? '[]') as List;
      items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return {
      'report_type': r['report_type'],
      'items': items,
      'final_amount': (r['final_amount'] as num?)?.toDouble() ?? 0.0,
      'is_refund': r['is_refund'] == 1,
    };
  }

  @override
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values) async {
    final db = _db;
    if (db == null) return;
    await db.insert('annual_records', {
      'user_type': userType,
      'payload': jsonEncode(values),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getAnnualRecord(String userType) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('annual_records', where: 'user_type = ?', whereArgs: [userType]);
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['payload'] as String) as Map;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = _db;
    if (db == null) return -1;
    return await db.insert('reminders', _reminderToRow(reminder));
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.query('reminders', orderBy: 'notify_date ASC');
    return rows.map(_rowToReminder).toList();
  }

  @override
  Future<void> updateReminder(Map<String, dynamic> reminder) async {
    final db = _db;
    if (db == null) return;
    await db.update('reminders', _reminderToRow(reminder),
        where: 'id = ?', whereArgs: [reminder['id']]);
  }

  @override
  Future<void> deleteReminder(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, bool>> getReminderSettings() async {
    final db = _db;
    if (db == null) return {};
    final rows = await db.query('reminder_settings');
    return {for (final r in rows) r['key'] as String: r['enabled'] == 1};
  }

  @override
  Future<void> setReminderSetting(String key, bool enabled) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'reminder_settings',
      {'key': key, 'enabled': enabled ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertNotificationLog({required String title, required String body, String? category, DateTime? firedAt}) async {
    final db = _db;
    if (db == null) return;
    await db.insert('notification_log', {
      'title': title,
      'body': body,
      'fired_at': (firedAt ?? DateTime.now()).toIso8601String(),
      'is_read': 0,
      'category': category,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getNotificationLogs() async {
    final db = _db;
    if (db == null) return [];
    return await db.query('notification_log', orderBy: 'fired_at DESC', limit: 100);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final db = _db;
    if (db == null) return;
    await db.update('notification_log', {'is_read': 1});
  }

  @override
  Future<int> unreadNotificationCount() async {
    final db = _db;
    if (db == null) return 0;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM notification_log WHERE is_read = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> clearNotificationLogs() async {
    final db = _db;
    if (db == null) return;
    await db.delete('notification_log');
  }

  @override
  Future<String?> getAppState(String key) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('app_state', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setAppState(String key, String value) async {
    final db = _db;
    if (db == null) return;
    await db.insert('app_state', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> insertErrorLog(String message, String stackTrace) async {
    final db = _db;
    if (db == null) return;
    await db.insert('error_log', {
      'occurred_at': DateTime.now().toIso8601String(),
      'message': message,
      'stack_trace': stackTrace,
    });
    await db.delete('error_log',
        where:
            'id NOT IN (SELECT id FROM error_log ORDER BY id DESC LIMIT 100)');
  }

  @override
  Future<List<Map<String, dynamic>>> getErrorLogs() async {
    final db = _db;
    if (db == null) return [];
    return await db.query('error_log', orderBy: 'id DESC', limit: 100);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> getEventReminderPrefs() async {
    final db = _db;
    if (db == null) return {};
    final rows = await db.query('event_reminder_prefs');
    return {
      for (final r in rows)
        r['key'] as String: {
          'enabled': r['enabled'] == 1,
          'hour': r['hour'] as int?,
          'minute': r['minute'] as int?,
        }
    };
  }

  @override
  Future<void> setEventReminderPref(String key,
      {required bool enabled, required int hour, required int minute}) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
        'event_reminder_prefs',
        {'key': key, 'enabled': enabled ? 1 : 0, 'hour': hour, 'minute': minute},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>> exportAllData() async {
    final db = _db;
    if (db == null) return {};
    final tables = <String, dynamic>{};
    for (final t in kBackupTables) {
      try {
        tables[t] = await db.query(t);
      } catch (_) {
        // 해당 버전에 없는 테이블은 건너뜀
      }
    }
    return {
      'app': 'sekkeul',
      'schema': 22,
      // formatVersion 2 = S-2 이후(필드 평문, DB 파일 자체가 SQLCipher로 암호화).
      // 1(또는 누락) = S-2 이전(필드가 CryptoHelper XOR로 암호화된 상태로 export됨).
      'formatVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  @override
  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) return;
    final tables = (data['tables'] as Map?) ?? {};
    final isLegacyFormat = ((data['formatVersion'] as num?)?.toInt() ?? 1) < 2;
    await db.transaction((txn) async {
      for (final entry in tables.entries) {
        final t = entry.key.toString();
        if (!kBackupTables.contains(t)) continue;
        final rows = (entry.value as List?) ?? [];
        try {
          await txn.delete(t);
          for (final r in rows) {
            final row = Map<String, dynamic>.from(r as Map);
            final toInsert = isLegacyFormat ? decryptLegacyRowForTable(t, row) : row;
            await txn.insert(t, toInsert, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } catch (_) {
          // 테이블 누락/스키마 차이는 건너뜀(부분 복원 허용)
        }
      }
    });
  }

  Map<String, dynamic> _reminderToRow(Map<String, dynamic> r) => {
        if (r['id'] != null) 'id': r['id'],
        'title': r['title'],
        'kind': r['kind'],
        'due_date': r['due_date'],
        'notify_date': r['notify_date'],
        'notify_hour': r['notify_hour'],
        'notify_minute': r['notify_minute'],
        // 구버전 호환 유지: monthly면 repeat_monthly=1로도 기록.
        'repeat_monthly': (r['frequency'] == 'monthly' || r['repeat_monthly'] == true) ? 1 : 0,
        'frequency': r['frequency'] ?? 'once',
        'weekday': r['weekday'],
        'weekdays': r['weekdays'],
        'enabled': r['enabled'] == false ? 0 : 1,
        'notif_id': r['notif_id'],
      };

  Map<String, dynamic> _rowToReminder(Map<String, dynamic> row) => {
        'id': row['id'],
        'title': row['title'],
        'kind': row['kind'],
        'due_date': row['due_date'],
        'notify_date': row['notify_date'],
        'notify_hour': row['notify_hour'],
        'notify_minute': row['notify_minute'],
        'repeat_monthly': row['repeat_monthly'] == 1,
        'frequency': row['frequency'],
        'weekday': row['weekday'],
        'weekdays': row['weekdays'],
        'enabled': row['enabled'] == 1,
        'notif_id': row['notif_id'],
      };

  RecurringTemplate _rowToTemplate(Map<String, dynamic> row) => RecurringTemplate(
    id: row['id'] as int,
    name: row['name'] as String,
    amountHint: row['amount_hint'] as int? ?? 0,
    category: row['category'] as String? ?? '기타',
    paymentMethod: row['payment_method'] as String? ?? '기타',
    dayOfMonth: row['day_of_month'] as int? ?? 1,
    sortOrder: row['sort_order'] as int? ?? 0,
    isBusiness: (row['is_business'] as int?) == 1,
  );

  @override
  Future<int> insertRecurringTemplate(RecurringTemplate t) async {
    final db = _db;
    if (db == null) return -1;
    return await db.insert('recurring_templates', {
      'name': t.name,
      'amount_hint': t.amountHint,
      'category': t.category,
      'payment_method': t.paymentMethod,
      'day_of_month': t.dayOfMonth,
      'sort_order': t.sortOrder,
      'is_business': t.isBusiness ? 1 : 0,
    });
  }

  @override
  Future<List<RecurringTemplate>> getRecurringTemplates() async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.query('recurring_templates', orderBy: 'sort_order ASC, id ASC');
    return rows.map(_rowToTemplate).toList();
  }

  @override
  Future<void> updateRecurringTemplate(RecurringTemplate t) async {
    final db = _db;
    if (db == null) return;
    await db.update('recurring_templates', {
      'name': t.name,
      'amount_hint': t.amountHint,
      'category': t.category,
      'payment_method': t.paymentMethod,
      'day_of_month': t.dayOfMonth,
      'sort_order': t.sortOrder,
      'is_business': t.isBusiness ? 1 : 0,
    }, where: 'id = ?', whereArgs: [t.id]);
  }

  @override
  Future<void> deleteRecurringTemplate(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('recurring_templates', where: 'id = ?', whereArgs: [id]);
    await db.delete('recurring_confirmations', where: 'template_id = ?', whereArgs: [id]);
  }

  @override
  Future<int> getPendingRecurringCount(int year, int month) async {
    final db = _db;
    if (db == null) return 0;
    final templates = await db.query('recurring_templates');
    if (templates.isEmpty) return 0;
    int pending = 0;
    for (final t in templates) {
      final id = t['id'] as int;
      final conf = await db.query(
        'recurring_confirmations',
        where: 'template_id = ? AND year = ? AND month = ?',
        whereArgs: [id, year, month],
      );
      if (conf.isEmpty || (conf.first['status'] as int) == 0) pending++;
    }
    return pending;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecurringConfirmations(int year, int month) async {
    final db = _db;
    if (db == null) return [];
    final templates = await db.query('recurring_templates', orderBy: 'sort_order ASC, id ASC');
    final result = <Map<String, dynamic>>[];
    for (final t in templates) {
      final id = t['id'] as int;
      final conf = await db.query(
        'recurring_confirmations',
        where: 'template_id = ? AND year = ? AND month = ?',
        whereArgs: [id, year, month],
      );
      result.add({
        'template': _rowToTemplate(t),
        'status': conf.isEmpty ? 0 : (conf.first['status'] as int? ?? 0),
        'actual_amount': conf.isEmpty ? 0 : (conf.first['actual_amount'] as int? ?? 0),
        'expense_id': conf.isEmpty ? null : conf.first['expense_id'],
      });
    }
    return result;
  }

  @override
  Future<void> confirmRecurring(int templateId, int year, int month, {required int amount, required String expenseId}) async {
    final db = _db;
    if (db == null) return;
    await db.insert('recurring_confirmations', {
      'template_id': templateId,
      'year': year,
      'month': month,
      'status': 1,
      'actual_amount': amount,
      'expense_id': expenseId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> skipRecurring(int templateId, int year, int month) async {
    final db = _db;
    if (db == null) return;
    await db.insert('recurring_confirmations', {
      'template_id': templateId,
      'year': year,
      'month': month,
      'status': 2,
      'actual_amount': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  QuickEntryPreset _rowToQuickEntryPreset(Map<String, dynamic> row) => QuickEntryPreset(
    id: row['id'] as int,
    name: row['name'] as String,
    amount: row['amount'] as int? ?? 0,
    category: row['category'] as String? ?? '기타',
    paymentMethod: row['payment_method'] as String? ?? '기타',
    isBusiness: (row['is_business'] as int?) == 1,
    sortOrder: row['sort_order'] as int? ?? 0,
  );

  @override
  Future<int> insertQuickEntryPreset(QuickEntryPreset p) async {
    final db = _db;
    if (db == null) return -1;
    return await db.insert('quick_entry_presets', {
      'name': p.name,
      'amount': p.amount,
      'category': p.category,
      'payment_method': p.paymentMethod,
      'is_business': p.isBusiness ? 1 : 0,
      'sort_order': p.sortOrder,
    });
  }

  @override
  Future<List<QuickEntryPreset>> getQuickEntryPresets() async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.query('quick_entry_presets', orderBy: 'sort_order ASC, id ASC');
    return rows.map(_rowToQuickEntryPreset).toList();
  }

  @override
  Future<void> deleteQuickEntryPreset(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('quick_entry_presets', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> getCardPaymentDates() async {
    final db = _db;
    if (db == null) return [];
    return await db.query('card_payment_dates', orderBy: 'day ASC');
  }

  @override
  Future<int> addCardPaymentDate(String name, int day) async {
    final db = _db;
    if (db == null) return -1;
    return await db.insert('card_payment_dates', {'name': name, 'day': day});
  }

  @override
  Future<void> deleteCardPaymentDate(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('card_payment_dates', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> destroyAllData() async {
    final db = _db;
    if (db == null) return;

    // 1단계: 난수 및 0 채우기로 플래시 메모리 영역 덮어쓰기 (Shredding)
    try {
      await db.execute("UPDATE user_profile SET user_type='TEMP', gross_income=0, dependents=0, monthly_rent=0, decided_tax=0, yellow_umbrella=0, monthly_income=0");
      await db.execute("UPDATE expenses SET date='0000', amount='ZERO', content='ZERO', category='ZERO'");
      await db.execute("DELETE FROM banner_states");
      await db.execute("DELETE FROM monthly_card_usage");
      await db.execute("DELETE FROM income_entries");
      await db.execute("DELETE FROM report_drafts");
      await db.execute("DELETE FROM annual_records");
      await db.execute("DELETE FROM reminders");
      await db.execute("DELETE FROM reminder_settings");
      await db.execute("DELETE FROM notification_log");
      await db.execute("DELETE FROM recurring_templates");
      await db.execute("DELETE FROM recurring_confirmations");
      await db.execute("DELETE FROM quick_entry_presets");
      await db.execute("DELETE FROM card_payment_dates");
      await db.execute("DELETE FROM app_state");
      await db.execute("DELETE FROM event_reminder_prefs");
    } catch (e) {
      // 무시
    }

    // 2단계: SQLite 프리리스트 영구 소거를 위한 VACUUM 실행
    try {
      await db.execute("VACUUM");
    } catch (e) {
      // 무시
    }

    // 3단계: 커넥션 클로즈 및 물리적 DB 파일 삭제
    await close();
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

/// 2. 데스크톱 테스트(flutter test) 환경용 인메모리 가상 데이터베이스 서비스 구현
class InMemoryDatabaseHelper implements DatabaseService {
  Map<String, dynamic>? _profile;
  final Map<String, Map<String, dynamic>> _expenses = {};
  final List<Map<String, dynamic>> _taxRecords = [];
  bool _isClosed = false;

  @override
  Future<void> initDatabase() async {
    _isClosed = false;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    if (_isClosed) return;
    _profile = Map<String, dynamic>.from(profile);
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    if (_isClosed) return null;
    return _profile;
  }

  final Map<String, Map<String, double>> _profileTypeValues = {};

  @override
  Future<void> setProfileTypeValues(String userType, {double? grossIncome, double? expenseTarget}) async {
    final existing = _profileTypeValues[userType] ?? {'gross_income': 0.0, 'expense_target': 0.0};
    _profileTypeValues[userType] = {
      'gross_income': grossIncome ?? existing['gross_income']!,
      'expense_target': expenseTarget ?? existing['expense_target']!,
    };
  }

  @override
  Future<Map<String, double>> getProfileTypeValues(String userType) async {
    return _profileTypeValues[userType] ?? {'gross_income': 0.0, 'expense_target': 0.0};
  }

  @override
  Future<void> insertTaxRecord(Map<String, dynamic> record) async {
    if (_isClosed) return;
    _taxRecords.add(Map<String, dynamic>.from(record));
  }

  @override
  Future<List<Map<String, dynamic>>> getTaxRecords() async {
    if (_isClosed) return [];
    final records = List<Map<String, dynamic>>.from(_taxRecords);
    records.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return records;
  }

  @override
  Future<void> insertExpense(ExpenseItem item) async {
    if (_isClosed) return;

    final String encryptedAmount = CryptoHelper.encrypt(item.amount.toString());
    final String encryptedContent = CryptoHelper.encrypt(item.content);
    final String encryptedCategory = CryptoHelper.encrypt(item.category);
    final String encryptedPayment = CryptoHelper.encrypt(item.paymentMethod);

    _expenses[item.id] = {
      'id': item.id,
      'date': item.date.toIso8601String(),
      'end_date': item.endDate?.toIso8601String(),
      'amount': encryptedAmount,
      'content': encryptedContent,
      'category': encryptedCategory,
      'payment_method': encryptedPayment,
      'is_business': item.isBusiness,
      'user_type': item.userType,
    };
  }

  @override
  Future<List<ExpenseItem>> getExpenses({String? userType}) async {
    if (_isClosed) return [];

    final List<ExpenseItem> list = [];
    for (final raw in _expenses.values) {
      final rawUserType = raw['user_type'] as String?;
      if (userType != null && rawUserType != null && rawUserType != userType) continue;
      final String decryptedAmountStr = CryptoHelper.decrypt(raw['amount'] as String);
      final String decryptedContent = CryptoHelper.decrypt(raw['content'] as String);
      final String decryptedCategory = CryptoHelper.decrypt(raw['category'] as String);
      final pmRaw = raw['payment_method'] as String?;
      String paymentMethod = '기타';
      if (pmRaw != null) {
        try { paymentMethod = CryptoHelper.decrypt(pmRaw); } catch (_) {}
      }

      final endDateStr = raw['end_date'] as String?;
      list.add(ExpenseItem(
        id: raw['id'] as String,
        date: DateTime.parse(raw['date'] as String),
        endDate: endDateStr != null ? DateTime.parse(endDateStr) : null,
        amount: int.parse(decryptedAmountStr),
        content: decryptedContent,
        category: decryptedCategory,
        paymentMethod: paymentMethod,
        isBusiness: raw['is_business'] as bool? ?? false,
        userType: rawUserType,
      ));
    }
    return list;
  }

  @override
  Future<void> deleteExpense(String id) async {
    if (_isClosed) return;
    _expenses.remove(id);
  }

  final Map<String, int> _bannerHideTimes = {};

  @override
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch) async {
    if (_isClosed) return;
    _bannerHideTimes[bannerId] = hideUntilEpoch;
  }

  @override
  Future<int?> getBannerHideTime(String bannerId) async {
    if (_isClosed) return null;
    return _bannerHideTimes[bannerId];
  }

  @override
  Future<Map<String, int>> getAllBannerHideTimes() async {
    if (_isClosed) return {};
    return Map.from(_bannerHideTimes);
  }

  final List<IncomeEntry> _incomeEntries = [];

  @override
  Future<void> insertIncomeEntry(IncomeEntry entry) async {
    if (_isClosed) return;
    _incomeEntries.removeWhere((e) => e.id == entry.id);
    _incomeEntries.add(entry);
  }

  @override
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month, {String? userType}) async {
    if (_isClosed) return [];
    return _incomeEntries
        .where((e) => e.date.year == year && e.date.month == month)
        .where((e) => userType == null || e.userType == null || e.userType == userType)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> updateIncomeEntry(IncomeEntry entry) async {
    if (_isClosed) return;
    final idx = _incomeEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) _incomeEntries[idx] = entry;
  }

  @override
  Future<void> deleteIncomeEntry(String id, int year, int month) async {
    if (_isClosed) return;
    _incomeEntries.removeWhere((e) => e.id == id);
  }

  @override
  Future<bool> hasOwnLedgerHistory(String userType) async {
    if (_isClosed) return false;
    if (_expenses.values.any((raw) => raw['user_type'] == userType)) return true;
    return _incomeEntries.any((e) => e.userType == userType);
  }

  @override
  Future<LedgerMoveSummary> previewLedgerMove({required String from, required String to}) async {
    if (_isClosed) {
      return const LedgerMoveSummary(expenseCount: 0, movableIncomeCount: 0, orphanIncomeCount: 0);
    }
    final valid = movableIncomeTypesTo(to);
    final expenseCount = _expenses.values.where((r) => r['user_type'] == from).length;
    int movable = 0, orphan = 0;
    for (final e in _incomeEntries.where((e) => e.userType == from)) {
      if (valid.contains(e.incomeType)) { movable++; } else { orphan++; }
    }
    return LedgerMoveSummary(
        expenseCount: expenseCount, movableIncomeCount: movable, orphanIncomeCount: orphan);
  }

  @override
  Future<void> moveLedgerRecords({required String from, required String to}) async {
    if (_isClosed) return;
    final valid = movableIncomeTypesTo(to);
    for (final raw in _expenses.values) {
      if (raw['user_type'] == from) raw['user_type'] = to;
    }
    for (int i = 0; i < _incomeEntries.length; i++) {
      final e = _incomeEntries[i];
      if (e.userType == from && valid.contains(e.incomeType)) {
        _incomeEntries[i] = e.copyWith(userType: to);
      }
    }
  }

  @override
  Future<void> updateExpense(ExpenseItem item) async {
    if (_isClosed) return;
    await insertExpense(item); // replace
  }

  final Map<String, Map<String, dynamic>> _reportDrafts = {};

  @override
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund}) async {
    if (_isClosed) return;
    _reportDrafts[userType] = {
      'report_type': reportType,
      'items': items.map((e) => Map<String, dynamic>.from(e)).toList(),
      'final_amount': finalAmount,
      'is_refund': isRefund,
    };
  }

  @override
  Future<Map<String, dynamic>?> getReportDraft(String userType) async {
    if (_isClosed) return null;
    return _reportDrafts[userType];
  }

  final Map<String, Map<String, dynamic>> _annualRecords = {};

  @override
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values) async {
    if (_isClosed) return;
    // 무결성 증명을 위해 인메모리에서도 암호화 적재
    final enc = CryptoHelper.encrypt(jsonEncode(values));
    _annualRecords[userType] = {'payload': enc};
  }

  @override
  Future<Map<String, dynamic>?> getAnnualRecord(String userType) async {
    if (_isClosed) return null;
    final row = _annualRecords[userType];
    if (row == null) return null;
    try {
      final decoded = jsonDecode(CryptoHelper.decrypt(row['payload'] as String)) as Map;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  final List<Map<String, dynamic>> _reminders = [];
  int _reminderAutoId = 1;

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    if (_isClosed) return -1;
    final id = _reminderAutoId++;
    _reminders.add({...reminder, 'id': id});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders() async {
    if (_isClosed) return [];
    final list = _reminders.map((e) => Map<String, dynamic>.from(e)).toList();
    list.sort((a, b) =>
        (a['notify_date'] as String? ?? '').compareTo(b['notify_date'] as String? ?? ''));
    return list;
  }

  @override
  Future<void> updateReminder(Map<String, dynamic> reminder) async {
    if (_isClosed) return;
    final idx = _reminders.indexWhere((e) => e['id'] == reminder['id']);
    if (idx >= 0) _reminders[idx] = Map<String, dynamic>.from(reminder);
  }

  @override
  Future<void> deleteReminder(int id) async {
    if (_isClosed) return;
    _reminders.removeWhere((e) => e['id'] == id);
  }

  final Map<String, bool> _reminderSettings = {};

  @override
  Future<Map<String, bool>> getReminderSettings() async {
    if (_isClosed) return {};
    return Map<String, bool>.from(_reminderSettings);
  }

  @override
  Future<void> setReminderSetting(String key, bool enabled) async {
    if (_isClosed) return;
    _reminderSettings[key] = enabled;
  }

  final List<Map<String, dynamic>> _notificationLogs = [];

  @override
  Future<void> insertNotificationLog({required String title, required String body, String? category, DateTime? firedAt}) async {
    if (_isClosed) return;
    _notificationLogs.insert(0, {
      'id': _notificationLogs.length + 1,
      'title': title,
      'body': body,
      'fired_at': (firedAt ?? DateTime.now()).toIso8601String(),
      'is_read': 0,
      'category': category,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getNotificationLogs() async {
    if (_isClosed) return [];
    return List<Map<String, dynamic>>.from(_notificationLogs);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    if (_isClosed) return;
    for (var i = 0; i < _notificationLogs.length; i++) {
      _notificationLogs[i] = {..._notificationLogs[i], 'is_read': 1};
    }
  }

  @override
  Future<int> unreadNotificationCount() async {
    if (_isClosed) return 0;
    return _notificationLogs.where((e) => e['is_read'] == 0).length;
  }

  @override
  Future<void> clearNotificationLogs() async {
    if (_isClosed) return;
    _notificationLogs.clear();
  }

  final Map<String, String> _appState = {};

  @override
  Future<String?> getAppState(String key) async {
    if (_isClosed) return null;
    return _appState[key];
  }

  @override
  Future<void> setAppState(String key, String value) async {
    if (_isClosed) return;
    _appState[key] = value;
  }

  final List<Map<String, dynamic>> _errorLogs = [];

  @override
  Future<void> insertErrorLog(String message, String stackTrace) async {
    if (_isClosed) return;
    _errorLogs.insert(0, {
      'id': _errorLogs.length + 1,
      'occurred_at': DateTime.now().toIso8601String(),
      'message': message,
      'stack_trace': stackTrace,
    });
    if (_errorLogs.length > 100) {
      _errorLogs.removeRange(100, _errorLogs.length);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getErrorLogs() async {
    if (_isClosed) return [];
    return List<Map<String, dynamic>>.from(_errorLogs);
  }

  final Map<String, Map<String, dynamic>> _eventReminderPrefs = {};

  @override
  Future<Map<String, Map<String, dynamic>>> getEventReminderPrefs() async {
    if (_isClosed) return {};
    return {for (final e in _eventReminderPrefs.entries) e.key: Map<String, dynamic>.from(e.value)};
  }

  @override
  Future<void> setEventReminderPref(String key,
      {required bool enabled, required int hour, required int minute}) async {
    if (_isClosed) return;
    _eventReminderPrefs[key] = {'enabled': enabled, 'hour': hour, 'minute': minute};
  }

  // 고정 지출 템플릿 (v25) — 웹 인메모리 구현
  final List<RecurringTemplate> _recurringTemplates = [];
  int _recurringTemplateAutoId = 1;
  final Map<String, int> _recurringConfirmations = {}; // '${templateId}_${year}_${month}' → status

  @override
  Future<int> insertRecurringTemplate(RecurringTemplate t) async {
    if (_isClosed) return -1;
    final id = _recurringTemplateAutoId++;
    _recurringTemplates.add(t.copyWith(id: id));
    return id;
  }

  @override
  Future<List<RecurringTemplate>> getRecurringTemplates() async {
    if (_isClosed) return [];
    return List<RecurringTemplate>.from(_recurringTemplates);
  }

  @override
  Future<void> updateRecurringTemplate(RecurringTemplate t) async {
    if (_isClosed) return;
    final idx = _recurringTemplates.indexWhere((e) => e.id == t.id);
    if (idx >= 0) _recurringTemplates[idx] = t;
  }

  @override
  Future<void> deleteRecurringTemplate(int id) async {
    if (_isClosed) return;
    _recurringTemplates.removeWhere((e) => e.id == id);
    _recurringConfirmations.removeWhere((k, _) => k.startsWith('${id}_'));
  }

  @override
  Future<int> getPendingRecurringCount(int year, int month) async {
    if (_isClosed) return 0;
    int pending = 0;
    for (final t in _recurringTemplates) {
      final status = _recurringConfirmations['${t.id}_${year}_$month'] ?? 0;
      if (status == 0) pending++;
    }
    return pending;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecurringConfirmations(int year, int month) async {
    if (_isClosed) return [];
    return _recurringTemplates.map((t) {
      final status = _recurringConfirmations['${t.id}_${year}_$month'] ?? 0;
      return {
        'template': t,
        'status': status,
        'actual_amount': 0,
        'expense_id': null,
      };
    }).toList();
  }

  @override
  Future<void> confirmRecurring(int templateId, int year, int month, {required int amount, required String expenseId}) async {
    if (_isClosed) return;
    _recurringConfirmations['${templateId}_${year}_$month'] = 1;
  }

  @override
  Future<void> skipRecurring(int templateId, int year, int month) async {
    if (_isClosed) return;
    _recurringConfirmations['${templateId}_${year}_$month'] = 2;
  }

  // 즐겨찾기 빠른 입력 프리셋 (v33) — 인메모리 스텁
  final List<QuickEntryPreset> _quickEntryPresets = [];
  int _quickEntryPresetAutoId = 1;

  @override
  Future<int> insertQuickEntryPreset(QuickEntryPreset p) async {
    if (_isClosed) return -1;
    final id = _quickEntryPresetAutoId++;
    _quickEntryPresets.add(QuickEntryPreset(
      id: id,
      name: p.name,
      amount: p.amount,
      category: p.category,
      paymentMethod: p.paymentMethod,
      isBusiness: p.isBusiness,
      sortOrder: p.sortOrder,
    ));
    return id;
  }

  @override
  Future<List<QuickEntryPreset>> getQuickEntryPresets() async =>
      List<QuickEntryPreset>.from(_quickEntryPresets);

  @override
  Future<void> deleteQuickEntryPreset(int id) async {
    if (_isClosed) return;
    _quickEntryPresets.removeWhere((e) => e.id == id);
  }

  // 카드 결제일 (v26) — 인메모리 스텁
  final List<Map<String, dynamic>> _cardPaymentDates = [];
  int _cardDateAutoId = 1;

  @override
  Future<List<Map<String, dynamic>>> getCardPaymentDates() async =>
      List<Map<String, dynamic>>.from(_cardPaymentDates);

  @override
  Future<int> addCardPaymentDate(String name, int day) async {
    final id = _cardDateAutoId++;
    _cardPaymentDates.add({'id': id, 'name': name, 'day': day});
    return id;
  }

  @override
  Future<void> deleteCardPaymentDate(int id) async {
    _cardPaymentDates.removeWhere((e) => e['id'] == id);
  }

  // 웹(인메모리)은 휘발성이라 파일 백업 의미가 약함 — 인터페이스 충족용 최소 구현.
  @override
  Future<Map<String, dynamic>> exportAllData() async =>
      {'app': 'sekkeul', 'schema': 25, 'exportedAt': DateTime.now().toIso8601String(), 'tables': {}};

  @override
  Future<void> importAllData(Map<String, dynamic> data) async {}

  @override
  Future<void> destroyAllData() async {
    // 1단계: 난수 오염 시뮬레이션
    _expenses.forEach((key, value) {
      _expenses[key] = {
        'id': key,
        'date': '0000',
        'amount': 'ZERO',
        'content': 'ZERO',
        'category': 'ZERO',
      };
    });
    _profile = null;

    // 2/3단계: 물리적 소거
    _expenses.clear();
    _incomeEntries.clear();
    _reportDrafts.clear();
    _annualRecords.clear();
    _reminders.clear();
    _reminderSettings.clear();
    _recurringTemplates.clear();
    _recurringConfirmations.clear();
    _quickEntryPresets.clear();
    _appState.clear();
    _eventReminderPrefs.clear();
    await close();
  }

  @override
  Future<void> close() async {
    _isClosed = true;
  }
}

/// 전역적으로 접근 가능한 데이터베이스 서비스 단일 인스턴스
/// 웹에서는 sqflite 미지원이므로 인메모리 구현체를 사용
DatabaseService dbService = kIsWeb ? InMemoryDatabaseHelper() : SqfliteDatabaseHelper();
