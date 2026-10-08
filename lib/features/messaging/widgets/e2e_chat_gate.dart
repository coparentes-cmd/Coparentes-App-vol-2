import 'package:flutter/material.dart';

/// Chat no longer requires client E2E unlock (server KEY_MESSAGES only).
///
/// Kept as a no-op so call sites stay stable; always allows messaging.
Future<bool> ensureE2eUnlockedForChat(BuildContext context) async {
  return true;
}
