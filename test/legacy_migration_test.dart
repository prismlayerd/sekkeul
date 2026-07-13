import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/legacy_migration.dart';
import 'package:secul/core/security/crypto_helper.dart';

void main() {
  group('decryptLegacyRowForTable (S-2 평문 DB → SQLCipher 이전)', () {
    test('expenses — amount/content/category/payment_method 복호화', () {
      final legacyRow = {
        'id': 'e1',
        'date': '2026-07-01T00:00:00.000',
        'end_date': null,
        'amount': CryptoHelper.encrypt('15000'),
        'content': CryptoHelper.encrypt('점심값'),
        'category': CryptoHelper.encrypt('식비'),
        'payment_method': CryptoHelper.encrypt('신용카드'),
        'is_business': 0,
        'user_type': '프리랜서',
      };

      final result = decryptLegacyRowForTable('expenses', legacyRow);

      expect(result['amount'], '15000');
      expect(result['content'], '점심값');
      expect(result['category'], '식비');
      expect(result['payment_method'], '신용카드');
      // 암호화되지 않는 컬럼은 그대로 보존
      expect(result['id'], 'e1');
      expect(result['is_business'], 0);
      expect(result['user_type'], '프리랜서');
    });

    test('income_entries — amount/memo/income_type 복호화', () {
      final legacyRow = {
        'id': 'i1',
        'date': '2026-07-01T00:00:00.000',
        'amount': CryptoHelper.encrypt('3000000'),
        'memo': CryptoHelper.encrypt('7월 강연료'),
        'income_type': CryptoHelper.encrypt('기타소득'),
        'is_withheld': 1,
        'user_type': null,
      };

      final result = decryptLegacyRowForTable('income_entries', legacyRow);

      expect(result['amount'], '3000000');
      expect(result['memo'], '7월 강연료');
      expect(result['income_type'], '기타소득');
      expect(result['user_type'], null);
    });

    test('annual_records — payload(JSON 문자열) 복호화', () {
      final legacyRow = {
        'user_type': '직장인',
        'payload': CryptoHelper.encrypt('{"grossIncome":50000000}'),
        'created_at': '2026-01-01T00:00:00.000',
      };

      final result = decryptLegacyRowForTable('annual_records', legacyRow);

      expect(result['payload'], '{"grossIncome":50000000}');
    });

    test('암호화 대상이 아닌 테이블은 행을 그대로 통과시킴', () {
      final row = {'banner_id': 'promo1', 'hide_until_epoch': 123456};
      final result = decryptLegacyRowForTable('banner_states', row);
      expect(result, row);
    });

    test('null·빈 문자열 필드는 예외 없이 그대로 보존', () {
      final legacyRow = {
        'id': 'e2',
        'date': '2026-07-02T00:00:00.000',
        'amount': '',
        'content': '',
        'category': '',
        'payment_method': null,
        'is_business': 0,
        'user_type': null,
      };

      final result = decryptLegacyRowForTable('expenses', legacyRow);

      expect(result['amount'], '');
      expect(result['content'], '');
      expect(result['category'], '');
      expect(result['payment_method'], null);
    });
  });
}
