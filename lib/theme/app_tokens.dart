import 'package:flutter/material.dart';

/// Visual tokens for Wariant A (dp @ 390 width). Brand colors stay in [AppTheme].
class AppRadius {
  static const cell = 12.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x0A16202B),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x2416202B),
      blurRadius: 30,
      offset: Offset(0, 11),
      spreadRadius: -14,
    ),
  ];

  static const nav = [
    BoxShadow(
      color: Color(0x4716202B),
      blurRadius: 36,
      offset: Offset(0, 14),
      spreadRadius: -14,
    ),
  ];

  /// Soft colored glow under a filled button.
  static List<BoxShadow> glow(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.9),
          blurRadius: 28,
          offset: const Offset(0, 14),
          spreadRadius: -14,
        ),
      ];

  static List<BoxShadow> headerGlow(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.5),
          blurRadius: 30,
          offset: const Offset(0, 12),
          spreadRadius: -16,
        ),
      ];
}

class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const screenHorizontal = 20.0;
  static const cardGap = 12.0;
  static const cardPaddingV = 16.0;
  static const cardPaddingH = 20.0;
  static const touchTarget = 48.0;
  static const navMargin = 14.0;
}

/// Light tint backgrounds + darker text for contrast (WCAG 2.2 table 2.2).
class AppTints {
  static const tealBg = Color(0xFFE6FAF4);
  static const tealFg = Color(0xFF00785A);
  static const blueBg = Color(0xFFE8F2FB);
  static const blueFg = Color(0xFF005A96);
  static const amberBg = Color(0xFFFFF1DC);
  static const amberFg = Color(0xFF8A5A00);
  static const redBg = Color(0xFFFDECEC);
  static const redFg = Color(0xFFB71C1C);
  static const purpleBg = Color(0xFFF3E5F7);
  static const purpleFg = Color(0xFF6A1B7A);
  static const grayBg = Color(0xFFF1F3F6);
  static const grayFg = Color(0xFF5D6673);
  static const coralBg = Color(0xFFFFEDEA);

  /// Field fill / soft surfaces from the instruction.
  static const fieldFill = Color(0xFFF6F7F9);
  static const chipIdle = Color(0xFFF3F4F7);
  static const timelineLine = Color(0xFFEEF0F4);
  static const threadDivider = Color(0xFFF1F2F5);
  static const pendingBar = Color(0xFFFFF6E5);
  static const childFeelIdle = Color(0xFFF6F3EF);
  static const childFeelSelected = Color(0xFFFFF0EE);
  static const childPlanBar = Color(0xFFEAF5FE);
  static const tealBorder = Color(0xFFC9F1E5);
  static const purpleBorder = Color(0xFFEBD3F2);
  static const secondaryOutline = Color(0xFFBFEFDF);
  static const listDashed = Color(0xFFFFB3B1);

  /// Dark text on brand teal / coral (section 7 decisions).
  static const onTeal = Color(0xFF08352A);
  static const onCoral = Color(0xFF16202B);

  static const ink = Color(0xFF16202B);
  static const inkMuted = Color(0xFF5D6673);
}
