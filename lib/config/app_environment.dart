import 'package:flutter/foundation.dart';

class AppEnvironment {
  /// Public web app URL (no trailing slash).
  ///
  /// Priority:
  /// 1. `--dart-define=COPARENTES_PUBLIC_URL=...` (Netlify / CI)
  /// 2. Production default → custom domain
  static String get publicSiteUrl {
    const configured = String.fromEnvironment('COPARENTES_PUBLIC_URL');
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }

    return 'https://getcoparentes.app';
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
