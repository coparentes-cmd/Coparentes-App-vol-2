import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import 'e2e_unlock_sheet.dart';

/// Ensures E2E private key is unlocked for this process before showing chat.
///
/// Returns `true` if messaging can proceed, `false` if the user cancelled.
Future<bool> ensureE2eUnlockedForChat(BuildContext context) async {
  final app = context.read<AppProvider>();
  if (app.isDemoMode) {
    return true;
  }
  if (!app.hasE2eSession) {
    return true;
  }
  if (await app.isE2eUnlocked()) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  return showE2eUnlockSheet(context);
}
