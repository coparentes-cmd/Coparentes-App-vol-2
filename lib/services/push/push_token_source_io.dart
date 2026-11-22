import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_source.dart';

/// Mobile FCM token source. On iOS Simulator APNs may be unavailable —
/// then we fall back to a deterministic stub so API registration is still testable.
class IoPushTokenSource implements PushTokenSource {
  bool _initialized = false;

  @override
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      // Simulator / missing GoogleService-Info / Android without google-services:
      // keep going with stub token from getToken().
      debugPrint('[push] Firebase init failed (will use stub token): $error');
    }
    _initialized = true;
  }

  @override
  Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (error) {
      debugPrint('[push] FCM getToken failed, using simulator stub: $error');
    }
    // Simulator / missing APNs: still exercise backend upsert.
    return 'sim-stub-${defaultTargetPlatform.name.toLowerCase()}';
  }
}

PushTokenSource createPushTokenSource() => IoPushTokenSource();
