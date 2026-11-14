import 'package:flutter/foundation.dart';

/// Value for `X-Client-Platform` (backend entitlement / trial).
///
/// Web and desktop → `web` (no mobile paywall). iOS/Android → mobile.
String clientPlatformHeader() {
  if (kIsWeb) {
    return 'web';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'web';
  }
}

bool get isMobileClientPlatform {
  final platform = clientPlatformHeader();
  return platform == 'ios' || platform == 'android';
}
