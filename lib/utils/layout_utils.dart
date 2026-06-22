import 'package:flutter/material.dart';

/// Phone / narrow viewport — desktop and tablet landscape stay unchanged.
bool isCompactPhoneLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < 600;
}

/// Parent tab header side inset — wider margins on phone, unchanged on web/desktop.
double parentTabHeaderHorizontalInset(BuildContext context) {
  return isCompactPhoneLayout(context) ? 28.0 : 16.0;
}

/// Icon-only header pills when the label is too long for narrow phones.
bool useIconOnlyHeaderActions(BuildContext context, {required String label}) {
  return isCompactPhoneLayout(context) &&
      MediaQuery.sizeOf(context).width < 430 &&
      label.length > 11;
}
