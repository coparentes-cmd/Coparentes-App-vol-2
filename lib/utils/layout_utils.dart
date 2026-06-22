import 'package:flutter/material.dart';

/// Phone / narrow viewport — desktop and tablet landscape stay unchanged.
bool isCompactPhoneLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < 600;
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
      MediaQuery.sizeOf(context).width < 430 &&
      label.length > 11;
}
