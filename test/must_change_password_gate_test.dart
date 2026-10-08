import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/models/models.dart';
import 'package:coparentes/screens/auth/auth_home_resolver.dart';
import 'package:coparentes/screens/auth/must_change_password_screen.dart';
import 'package:coparentes/screens/auth/unsupported_role_screen.dart';
import 'package:coparentes/screens/child/child_dashboard.dart';
import 'package:coparentes/screens/dashboard/parent_dashboard.dart';

AppUser _user({
  required UserRole role,
  required bool mustChangePassword,
}) {
  return AppUser(
    id: 'user_${role.name}',
    name: 'Test',
    email: 'test@example.com',
    role: role,
    mustChangePassword: mustChangePassword,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('resolveAuthenticatedHome', () {
    test('mustChangePassword=true shows MustChangePasswordScreen for every role',
        () {
      for (final role in UserRole.values) {
        final home = resolveAuthenticatedHome(
          _user(role: role, mustChangePassword: true),
        );
        expect(
          home,
          isA<MustChangePasswordScreen>(),
          reason: 'role=$role should be gated',
        );
      }
    });

    test('mustChangePassword=false routes by role', () {
      expect(
        resolveAuthenticatedHome(
          _user(role: UserRole.parentA, mustChangePassword: false),
        ),
        isA<ParentDashboard>(),
      );
      expect(
        resolveAuthenticatedHome(
          _user(role: UserRole.parentB, mustChangePassword: false),
        ),
        isA<ParentDashboard>(),
      );
      expect(
        resolveAuthenticatedHome(
          _user(role: UserRole.child, mustChangePassword: false),
        ),
        isA<ChildDashboard>(),
      );
      expect(
        resolveAuthenticatedHome(
          _user(role: UserRole.observer, mustChangePassword: false),
        ),
        isA<UnsupportedRoleScreen>(),
      );
    });
  });

  testWidgets('MustChangePasswordScreen is non-dismissible PopScope',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MustChangePasswordScreen()),
    );
    expect(find.byType(MustChangePasswordScreen), findsOneWidget);
    expect(find.byType(PopScope), findsOneWidget);
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}