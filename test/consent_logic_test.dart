import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/data/models/user_consent.dart';

void main() {
  group('required consent validation', () {
    test('blocks submit until all required consents are granted', () {
      final selections = defaultConsentSelections();

      expect(areRequiredConsentsGranted(selections), isFalse);

      selections[ConsentType.terms] = true;
      selections[ConsentType.dataProcessing] = true;
      expect(areRequiredConsentsGranted(selections), isFalse);

      selections[ConsentType.childData] = true;
      expect(areRequiredConsentsGranted(selections), isTrue);
    });

    test('allows optional consents to stay off', () {
      final selections = defaultConsentSelections()
        ..[ConsentType.terms] = true
        ..[ConsentType.dataProcessing] = true
        ..[ConsentType.childData] = true;

      expect(areRequiredConsentsGranted(selections), isTrue);
      expect(selections[ConsentType.marketing], isFalse);
    });
  });

  group('consent save payload', () {
    test('serializes all six consent types for registration', () {
      final apiPayload = consentSelectionsToApi({
        ConsentType.terms: true,
        ConsentType.dataProcessing: true,
        ConsentType.childData: true,
        ConsentType.emailNotifications: true,
        ConsentType.marketing: false,
        ConsentType.analytics: false,
      });

      expect(apiPayload.keys, hasLength(6));
      expect(apiPayload['TERMS'], isTrue);
      expect(apiPayload['MARKETING'], isFalse);
      expect(apiPayload['ANALYTICS'], isFalse);
    });
  });

  group('revocation flow', () {
    test('parses revoked consent with timestamp', () {
      final record = UserConsentRecord.fromJson({
        'consentType': 'MARKETING',
        'granted': false,
        'grantedAt': '2026-06-24T10:00:00.000Z',
        'revokedAt': '2026-06-24T10:00:00.000Z',
        'consentVersion': '1.0.0',
        'required': false,
      });

      expect(record.granted, isFalse);
      expect(record.revokedAt, isNotNull);
      expect(record.required, isFalse);
    });

    test('parses granted consent audit row', () {
      final record = UserConsentRecord.fromJson({
        'consentType': 'TERMS',
        'granted': true,
        'grantedAt': '2026-06-24T10:00:00.000Z',
        'revokedAt': null,
        'consentVersion': '1.0.0',
        'required': true,
      });

      expect(record.granted, isTrue);
      expect(record.type.isRequired, isTrue);
    });
  });
}
