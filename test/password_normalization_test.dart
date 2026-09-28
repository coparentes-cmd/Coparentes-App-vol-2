import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/utils/password_normalization.dart';

void main() {
  group('normalizePassword', () {
    test('strips spaces, hyphens, underscores, and dots', () {
      expect(normalizePassword('abc-def 123'), 'abcdef123');
      expect(normalizePassword('a_b.c-d e'), 'abcde');
      expect(normalizePassword('  pass--word__.'), 'password');
    });

    test('empty string stays empty', () {
      expect(normalizePassword(''), '');
      expect(normalizePassword('   ---'), '');
    });

    test('password without separators is unchanged', () {
      expect(normalizePassword('SecretPass99'), 'SecretPass99');
      expect(normalizePassword('123456789012'), '123456789012');
    });

    test('login and change-password paths normalize identically', () {
      const typed = 'My-Secret_Pass.99';
      final forLogin = normalizePassword(typed);
      final forChangeCurrent = normalizePassword(typed);
      final forChangeNew = normalizePassword(typed);
      expect(forLogin, 'MySecretPass99');
      expect(forLogin, forChangeCurrent);
      expect(forLogin, forChangeNew);
      expect(forLogin.length >= kPasswordMinLength, isTrue);
    });

    test('confirm match uses normalized forms (abc-1234 == abc1234)', () {
      final newPassword = normalizePassword('abc-1234xx');
      final confirmPassword = normalizePassword('abc1234xx');
      expect(newPassword, confirmPassword);
      expect(newPassword, 'abc1234xx');
    });
  });

  group('validateNormalizedPasswordLength', () {
    test('single policy constant is 8', () {
      expect(kPasswordMinLength, 8);
    });

    test('register accepts password that normalizes to 8 chars', () {
      final normalized = normalizePassword('abcd-efg1');
      expect(normalized, 'abcdefg1');
      expect(normalized.length, 8);
      expect(validateNormalizedPasswordLength(normalized), isNull);
    });

    test('register rejects password that normalizes to 7 chars', () {
      final normalized = normalizePassword('abc-def1');
      expect(normalized, 'abcdef1');
      expect(normalized.length, 7);
      final error = validateNormalizedPasswordLength(normalized);
      expect(error, isNotNull);
      expect(
        error,
        'Hasło musi mieć min. 8 znaków (bez spacji, myślników, podkreśleń i kropek)',
      );
    });
  });

  group('validateAndNormalizeNewPassword', () {
    test('accepts matching normalized pair', () {
      final result = validateAndNormalizeNewPassword(
        rawNew: 'abc-1234xx',
        rawConfirm: 'abc1234xx',
      );
      expect(result.errorMessage, isNull);
      expect(result.normalizedNew, 'abc1234xx');
    });

    test('rejects mismatched pair', () {
      final result = validateAndNormalizeNewPassword(
        rawNew: 'Password1',
        rawConfirm: 'Password2',
      );
      expect(result.normalizedNew, isNull);
      expect(result.errorMessage, 'Hasła nie są identyczne.');
    });

    test('rejects too short', () {
      final result = validateAndNormalizeNewPassword(
        rawNew: 'abc',
        rawConfirm: 'abc',
      );
      expect(result.normalizedNew, isNull);
      expect(result.errorMessage, isNotNull);
    });
  });
}
