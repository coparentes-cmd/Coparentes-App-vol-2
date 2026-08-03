import 'package:flutter/material.dart';

/// Shared layout tokens — single source of truth for RWD.
abstract final class LayoutTokens {
  /// Width < this → [AppBreakpoint.compact].
  static const double compactMax = 599;

  /// Width <= this (and >= 600) → [AppBreakpoint.medium].
  static const double mediumMax = 1023;

  static const double contentMaxMedium = 840;
  static const double contentMaxExpanded = 1120;

  /// Master–detail / two-pane features (chat, calendar).
  static const double twoPaneMinWidth = 900;

  /// Dual-month calendar picker.
  static const double sideBySideCalendarMin = 520;

  static const double authFormMax = 480;
  static const double authConsentMax = 640;
  static const double authMarketingMax = 1040;

  /// Role-selection two-column split threshold (matches contentMaxMedium).
  static const double authTwoColumnMin = contentMaxMedium;

  static const double chatBubbleMax = 520;
  static const double chatBubbleWidthFraction = 0.72;

  static const double iconOnlyHeaderMax = 430;

  static const double financeBalanceCardMax = 400;

  static const int gridColsCompact = 2;
  static const int gridColsMedium = 3;
  static const int gridColsExpanded = 4;
}

enum AppBreakpoint { compact, medium, expanded }

AppBreakpoint appBreakpointOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width <= LayoutTokens.compactMax) {
    return AppBreakpoint.compact;
  }
  if (width <= LayoutTokens.mediumMax) {
    return AppBreakpoint.medium;
  }
  return AppBreakpoint.expanded;
}

bool isCompactBreakpoint(BuildContext context) =>
    appBreakpointOf(context) == AppBreakpoint.compact;

bool isMediumBreakpoint(BuildContext context) =>
    appBreakpointOf(context) == AppBreakpoint.medium;

bool isExpandedBreakpoint(BuildContext context) =>
    appBreakpointOf(context) == AppBreakpoint.expanded;

/// Phone / narrow viewport (width-based). Kept for existing call sites.
bool isCompactPhoneLayout(BuildContext context) => isCompactBreakpoint(context);

double contentMaxWidthFor(BuildContext context) {
  switch (appBreakpointOf(context)) {
    case AppBreakpoint.compact:
      return double.infinity;
    case AppBreakpoint.medium:
      return LayoutTokens.contentMaxMedium;
    case AppBreakpoint.expanded:
      return LayoutTokens.contentMaxExpanded;
  }
}

bool useTwoPaneLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= LayoutTokens.twoPaneMinWidth;

int gridCrossAxisCountFor(BuildContext context) {
  switch (appBreakpointOf(context)) {
    case AppBreakpoint.compact:
      return LayoutTokens.gridColsCompact;
    case AppBreakpoint.medium:
      return LayoutTokens.gridColsMedium;
    case AppBreakpoint.expanded:
      return LayoutTokens.gridColsExpanded;
  }
}

double chatBubbleMaxWidthFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * LayoutTokens.chatBubbleWidthFraction)
      .clamp(0.0, LayoutTokens.chatBubbleMax);
}

/// Parent tab header side inset — edge-to-edge on phone, inset on web/desktop.
double parentTabHeaderHorizontalInset(BuildContext context) {
  return isCompactPhoneLayout(context) ? 0.0 : 16.0;
}

/// Top gap above header bar (below status bar).
double parentTabHeaderTopInset(BuildContext context) {
  return isCompactPhoneLayout(context) ? 0.0 : 8.0;
}

/// Shorter header row on phone; unchanged on web/desktop.
double parentTabResolvedHeaderHeight(BuildContext context, double height) {
  if (!isCompactPhoneLayout(context)) {
    return height;
  }
  if (height > 80) {
    return 108;
  }
  return 46;
}

/// Shorter tab row under header on phone.
double parentTabResolvedTabBarHeight(BuildContext context) {
  return isCompactPhoneLayout(context) ? 40.0 : 48.0;
}

/// Icon-only header pills when the label is too long for narrow phones.
bool useIconOnlyHeaderActions(BuildContext context, {required String label}) {
  return isCompactPhoneLayout(context) &&
      MediaQuery.sizeOf(context).width < LayoutTokens.iconOnlyHeaderMax &&
      label.length > 11;
}
