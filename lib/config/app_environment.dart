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
  /// 2. Debug builds → local backend
  /// 3. Release builds → Railway production
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('COPARENTES_API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kDebugMode) {
      return 'http://localhost:3000/api';
    }

    return 'https://coparentes-backend-production.up.railway.app/api';
  }
}
