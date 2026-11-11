// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'cookie_consent_models.dart';

/// Uses exact landing key in `localStorage` (no Flutter SharedPreferences prefix).
class CookieConsentStorage {
  Future<CookieConsent?> load() async {
    try {
      final raw = html.window.localStorage[CookieConsent.storageKey];
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CookieConsent.fromJson(decoded);
      }
      if (decoded is Map) {
        return CookieConsent.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> save(CookieConsent consent) async {
    html.window.localStorage[CookieConsent.storageKey] =
        jsonEncode(consent.toJson());
  }

  void applyDocumentDataset(CookieConsent consent) {
    final root = html.document.documentElement;
    if (root == null) {
      return;
    }
    root.dataset['cookieNecessary'] = 'granted';
    root.dataset['cookieFunctional'] =
        consent.functional ? 'granted' : 'denied';
    root.dataset['cookieAnalytics'] =
        consent.analytics ? 'granted' : 'denied';
    root.dataset['cookieMarketing'] =
        consent.marketing ? 'granted' : 'denied';
  }

  void dispatchUpdatedEvent(CookieConsent consent) {
    try {
      final event = html.CustomEvent(
        'cookieConsentUpdated',
        detail: js.JsObject.jsify(consent.toJson()),
      );
      html.window.dispatchEvent(event);
    } catch (_) {
      // Ignore JS interop failures.
    }
  }
}
