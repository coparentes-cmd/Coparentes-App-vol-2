import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cookie_consent_models.dart';

/// Non-web fallback (SharedPreferences). Clarity is web-only anyway.
class CookieConsentStorage {
  Future<CookieConsent?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CookieConsent.storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CookieConsent.storageKey,
      jsonEncode(consent.toJson()),
    );
  }

  void applyDocumentDataset(CookieConsent consent) {
    // No DOM on non-web.
  }

  void dispatchUpdatedEvent(CookieConsent consent) {
    // No window events on non-web.
  }
}
