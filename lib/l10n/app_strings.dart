import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
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
    // listen: false — safe from async handlers / snackbars (debug asserts if
    // listen:true outside build). Locale switches still rebuild via
    // AppProvider.notifyListeners + MaterialApp locale.
    String code;
    try {
      code = Provider.of<AppProvider>(context, listen: false).language;
    } on ProviderNotFoundException {
      code = Localizations.localeOf(context).languageCode;
    }
    return translate(code, source);
  }
}

extension AppStringsContext on BuildContext {
  String tr(String source) => AppStrings.of(this, source);
}
