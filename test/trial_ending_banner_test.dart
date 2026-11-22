import 'package:coparentes/models/models.dart';
import 'package:coparentes/widgets/trial_ending_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daysRemaining uses whole-day difference', () {
    final user = AppUser(
      id: 'p1',
      name: 'Parent',
      email: 'p@example.com',
      role: UserRole.parentA,
      billingStatus: BillingStatus.trialing,
      trialEndsAt: DateTime.now().add(const Duration(days: 2, hours: 3)),
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(TrialEndingBanner.daysRemaining(user), 2);
  });
}
