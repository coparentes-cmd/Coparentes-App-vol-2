import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/locale_policy.dart';

/// Persists a language only after the user picks it. A missing key stays Polish.
class LocaleStore {
  static const storageKey = 'app_locale_explicit';

  final SharedPreferences _preferences;

  LocaleStore({required SharedPreferences preferences})
      : _preferences = preferences;

  Locale read() => localeFromStoredCode(_preferences.getString(storageKey));

  Future<void> writeExplicit(Locale locale) async {
    final code = locale.languageCode == 'en' ? 'en' : 'pl';
    await _preferences.setString(storageKey, code);
  }
}
