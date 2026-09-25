import 'package:flutter/material.dart';

enum AppColorScheme {
  teal,
  blue,
  purple,
  rose,
  amber,
  green,
}

extension AppColorSchemeExt on AppColorScheme {
  String get label {
    switch (this) {
      case AppColorScheme.teal:
        return 'Coparentes Green';
      case AppColorScheme.blue:
        return 'Electric Blue';
      case AppColorScheme.purple:
        return 'Lavender';
      case AppColorScheme.rose:
        return 'Coral';
      case AppColorScheme.amber:
        return 'Sun Yellow';
      case AppColorScheme.green:
        return 'Mint';
    }
  }

  Color get primary {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF00C896);
      case AppColorScheme.blue:
        return const Color(0xFF0080FF);
      case AppColorScheme.purple:
        return const Color(0xFF9C27B0);
      case AppColorScheme.rose:
        return const Color(0xFFFF6B68);
      case AppColorScheme.amber:
        return const Color(0xFFF4B400);
      case AppColorScheme.green:
        return const Color(0xFF63E0BC);
    }
  }

  Color get light {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF63E0BC);
      case AppColorScheme.blue:
        return const Color(0xFF5EA8FF);
      case AppColorScheme.purple:
        return const Color(0xFFC77DFF);
      case AppColorScheme.rose:
        return const Color(0xFFFF9D9B);
      case AppColorScheme.amber:
        return const Color(0xFFFDE47A);
      case AppColorScheme.green:
        return const Color(0xFFA8F0D3);
    }
  }

  Color get swatch {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF00C896);
      case AppColorScheme.blue:
        return const Color(0xFF0080FF);
      case AppColorScheme.purple:
        return const Color(0xFF9C27B0);
      case AppColorScheme.rose:
        return const Color(0xFFFF6B68);
      case AppColorScheme.amber:
        return const Color(0xFFF4B400);
      case AppColorScheme.green:
        return const Color(0xFF63E0BC);
    }
  }
}
