import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static const Color primaryTeal = Color(0xFF00C896);
  static const Color primaryDark = Color(0xFF009C75);
  static const Color primaryLight = Color(0xFF63E0BC);
  static const Color accentColor = Color(0xFF0080FF);
  /// Średnio ciemny niebieski nagłówka Start — ciemniejszy odcień accentColor.
  static const Color brandHeaderBlue = Color(0xFF006BB3);
  static const Color coralColor = Color(0xFFFF6B68);
  static const Color yellowColor = Color(0xFFFDD835);
  static const Color purpleColor = Color(0xFF9C27B0);
  static const Color surfaceColor = Color(0xFFF8F8FB);
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF00A37A);
  /// Wariant A: darker ink for contrast on light surfaces (table 2.2).
  static const Color textPrimary = AppTints.ink;
  static const Color textSecondary = AppTints.inkMuted;
  static const Color textHint = Color(0xFF94A3B8);
  static const Color dividerColor = Color(0xFFE5ECF5);
  static const Color immutableBadge = primaryTeal;
  static const Color highConflictColor = coralColor;

  static const Color parentAColor = primaryTeal;
  static const Color parentBColor = accentColor;
  static const Color childColor = coralColor;
  static const Color observerColor = purpleColor;

  /// Aliases aligned with [AppRadius] (kept for existing call sites).
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.xl;
  static const double radiusXl = 36;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryTeal, accentColor],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static List<BoxShadow> get softShadow => AppShadows.card;

  /// Dark ink on filled brand buttons (section 7).
  static Color onBrandFill(Color fill) {
    if (fill == primaryTeal || fill == primaryDark || fill == successColor) {
      return AppTints.onTeal;
    }
    if (fill == coralColor || fill == highConflictColor) {
      return AppTints.onCoral;
    }
    return Colors.white;
  }

  static ThemeData buildLight(Color primary) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorColor,
    );
    final onPrimary = onBrandFill(primary);
    final fieldRadius = BorderRadius.circular(AppRadius.sm);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DMSans',
      colorScheme: scheme.copyWith(onPrimary: onPrimary),
      scaffoldBackgroundColor: surfaceColor,
      canvasColor: surfaceColor,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xxs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(AppSpace.touchTarget, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTints.tealFg,
          side: const BorderSide(color: AppTints.secondaryOutline, width: 1.5),
          minimumSize: const Size(AppSpace.touchTarget, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          backgroundColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: const TextStyle(
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTints.fieldFill,
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: brandHeaderBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppTints.redFg, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppTints.redFg, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppTints.redFg),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: textPrimary,
        disabledColor: AppTints.grayBg,
        labelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        // Selected tab: white pill on frosted header track (mobile + web).
        labelColor: brandHeaderBlue,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
        labelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A16202B),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: 0,
        ),
        titleSmall: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DMSans',
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontFamily: 'DMSans',
          color: textHint,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
        ),
        labelMedium: TextStyle(
          fontFamily: 'DMSans',
          color: textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontFamily: 'DMSans',
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.8,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.45)
              : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  static ThemeData buildDark(Color primary) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: accentColor,
      surface: const Color(0xFF161C28),
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DMSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F1521),
      canvasColor: const Color(0xFF0F1521),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF161C28),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
          side: BorderSide(color: Color(0xFF243145)),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: primary.withValues(alpha: 0.35), width: 1.2),
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFF161C28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF161C28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFF243145)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFF243145)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: primary,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        labelSmall: TextStyle(
          fontFamily: 'DMSans',
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.8,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF243145),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get lightTheme => buildLight(primaryTeal);
}
