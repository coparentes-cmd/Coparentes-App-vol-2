import 'package:flutter/foundation.dart';

class AppEnvironment {
  /// Public web app URL (no trailing slash).
  ///
  /// Priority:
  /// 1. `--dart-define=COPARENTES_PUBLIC_URL=...` (Netlify / CI)
  /// 2. Production default → custom domain
  ///
  /// Tolerates a misconfigured dart-define that embeds the real URL inside
  /// helper text (e.g. Netlify UI "Same value for all → https://…").
  static String get publicSiteUrl {
    const configured = String.fromEnvironment('COPARENTES_PUBLIC_URL');
    return resolvePublicSiteUrl(configured);
  }

  /// Visible for tests.
  static String resolvePublicSiteUrl(String configured) {
    const fallback = 'https://getcoparentes.app';
    final trimmed = configured.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    final direct = _asHttpUrl(trimmed);
    if (direct != null) {
      return direct;
    }

    final embedded = RegExp(r'https?://[^\s<>"]+').firstMatch(trimmed);
    if (embedded != null) {
      final extracted = _asHttpUrl(embedded.group(0)!);
      if (extracted != null) {
        return extracted;
      }
    }

    return fallback;
  }

  static String? _asHttpUrl(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'[,.;:]+$'), '');
    final uri = Uri.tryParse(cleaned);
    if (uri == null) {
      return null;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    return cleaned;
  }

  /// GA4 Measurement ID for the app property (empty disables analytics).
  ///
  /// Override: `--dart-define=COPARENTES_GA_MEASUREMENT_ID=G-XXXX`
  static String get gaMeasurementId {
    const configured = String.fromEnvironment(
      'COPARENTES_GA_MEASUREMENT_ID',
      defaultValue: 'G-YL9C69F0ZL',
    );
    return configured.trim();
  }

  /// API base URL (must end with `/api`).
  ///
  /// Priority:
  /// 1. `--dart-define=COPARENTES_API_BASE_URL=...` (Netlify / CI)
  /// 2. Web release → same-origin `/api` (Netlify proxy)
  /// 3. Debug builds → local backend
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('COPARENTES_API_BASE_URL');
    if (configured.isNotEmpty) {
      if (kIsWeb &&
          !kDebugMode &&
          configured.contains('railway.app')) {
        return '/api';
      }
      return configured;
    }

    if (kDebugMode) {
      return 'http://localhost:3000/api';
    }

    if (kIsWeb) {
      return '/api';
    }

    return '$publicSiteUrl/api';
  }
}
