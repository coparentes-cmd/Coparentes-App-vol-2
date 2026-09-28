import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../child/child_dashboard.dart';
import '../dashboard/parent_dashboard.dart';
import '../observer/observer_dashboard.dart';
import 'must_change_password_screen.dart';

/// Resolves the post-auth home widget (forced password gate, then role dashboard).
///
/// Extracted from `_AppGate` so widget/logic tests can cover the gate without
/// pumping the full `MaterialApp` bootstrap.
Widget resolveAuthenticatedHome(AppUser user) {
  if (user.mustChangePassword) {
    return const MustChangePasswordScreen();
  }

  switch (user.role) {
    case UserRole.child:
      return const ChildDashboard();
    case UserRole.observer:
      return const ObserverDashboard();
    case UserRole.parentA:
    case UserRole.parentB:
      return const ParentDashboard();
  }
}
