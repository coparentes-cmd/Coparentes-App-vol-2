import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/models/models.dart';

AppUser _parent({
  BillingStatus status = BillingStatus.none,
  DateTime? trialEndsAt,
  DateTime? currentPeriodEnd,
}) {
  return AppUser(
    id: 'p1',
    name: 'Parent',
    email: 'p@example.com',
    role: UserRole.parentA,
    billingStatus: status,
    trialEndsAt: trialEndsAt,
    currentPeriodEnd: currentPeriodEnd,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('AppUser.hasMobileEntitlement', () {
    test('child always allowed', () {
      final child = AppUser(
        id: 'c1',
        name: 'Child',
        email: 'c@example.com',
        role: UserRole.child,
        billingStatus: BillingStatus.none,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(child.hasMobileEntitlement, isTrue);
    });

    test('trialing respects trialEndsAt', () {
      expect(
        _parent(
          status: BillingStatus.trialing,
          trialEndsAt: DateTime.now().add(const Duration(days: 1)),
        ).hasMobileEntitlement,
        isTrue,
      );
      expect(
        _parent(
          status: BillingStatus.trialing,
          trialEndsAt: DateTime.now().subtract(const Duration(days: 1)),
        ).hasMobileEntitlement,
        isFalse,
      );
    });

    test('none / expired denied; active allowed', () {
      expect(_parent().hasMobileEntitlement, isFalse);
      expect(
        _parent(status: BillingStatus.expired).hasMobileEntitlement,
        isFalse,
      );
      expect(
        _parent(status: BillingStatus.active).hasMobileEntitlement,
        isTrue,
      );
    });
  });

  group('AppUser.isTrialEndingSoon', () {
    test('true within 3 days of trial end', () {
      expect(
        _parent(
          status: BillingStatus.trialing,
          trialEndsAt: DateTime.now().add(const Duration(days: 2)),
        ).isTrialEndingSoon,
        isTrue,
      );
    });

    test('false when trial far away or not trialing', () {
      expect(
        _parent(
          status: BillingStatus.trialing,
          trialEndsAt: DateTime.now().add(const Duration(days: 10)),
        ).isTrialEndingSoon,
        isFalse,
      );
      expect(
        _parent(
          status: BillingStatus.active,
          trialEndsAt: DateTime.now().add(const Duration(days: 1)),
        ).isTrialEndingSoon,
        isFalse,
      );
    });
  });
}
