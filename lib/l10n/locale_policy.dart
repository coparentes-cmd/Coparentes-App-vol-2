import 'package:flutter/material.dart';

/// Supported UI languages. Anything else falls back to Polish.
const supportedUiLanguages = ['pl', 'en'];

const Locale defaultUiLocale = Locale('pl');

/// `en` stays English. Every other stored value, including `de` and `fr`, is Polish.
Locale localeFromStoredCode(String? code) {
  if (code == 'en') {
    return const Locale('en');
  }
  return defaultUiLocale;
}

/// Date formatting locale. English uses Great Britain so the week starts on Monday.
String dateFormattingLocale(Locale locale) {
  if (locale.languageCode == 'en') {
    return 'en_GB';
  }
  return 'pl_PL';
}
