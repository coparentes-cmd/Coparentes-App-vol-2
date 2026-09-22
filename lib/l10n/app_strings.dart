import 'package:flutter/widgets.dart';

import 'en_overlay.dart';

/// Polish source text stays the default. English is an overlay; a missing key stays Polish.
class AppStrings {
  static String translate(String languageCode, String source) {
    if (languageCode != 'en') {
      return source;
    }
    return enOverlay[source] ?? source;
  }

  static String of(BuildContext context, String source) {
    final code = Localizations.localeOf(context).languageCode;
    return translate(code, source);
  }
}

extension AppStringsContext on BuildContext {
  String tr(String source) => AppStrings.of(this, source);
}
