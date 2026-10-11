import 'package:coparentes/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.resolvePublicSiteUrl', () {
    test('uses default when empty', () {
      expect(
        AppEnvironment.resolvePublicSiteUrl(''),
        'https://getcoparentes.app',
      );
    });

    test('accepts clean https URL', () {
      expect(
        AppEnvironment.resolvePublicSiteUrl('https://getcoparentes.app/'),
        'https://getcoparentes.app',
      );
    });

    test('extracts URL from Netlify helper text misconfig', () {
      expect(
        AppEnvironment.resolvePublicSiteUrl(
          'Same value for all → https://getcoparentes.app',
        ),
        'https://getcoparentes.app',
      );
    });

    test('falls back when value is not a URL', () {
      expect(
        AppEnvironment.resolvePublicSiteUrl('not-a-url'),
        'https://getcoparentes.app',
      );
    });
  });
}
