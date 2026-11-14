import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

/// Mobile-only gate when trial/subscription is missing (F3).
/// Never shown on web (`resolveAuthenticatedHome` + `kIsWeb` guard).
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final status = user?.billingStatus ?? BillingStatus.none;
    final trialEnded = status == BillingStatus.expired ||
        status == BillingStatus.canceled ||
        (status == BillingStatus.trialing &&
            user?.trialEndsAt != null &&
            !user!.trialEndsAt!.isAfter(DateTime.now()));

    final headline = trialEnded
        ? context.tr('Okres próbny zakończony')
        : context.tr('Wymagana subskrypcja');
    final body = trialEnded
        ? context.tr(
            'Twój 30-dniowy okres próbny na urządzeniach mobilnych dobiegł końca. '
            'Subskrypcja Coparentes (29,99 zł/mies.) będzie dostępna wkrótce. '
            'Aplikacja webowa pozostaje bez zmian.',
          )
        : context.tr(
            'Na telefonie Coparentes wymaga aktywnego okresu próbnego lub subskrypcji. '
            'Web działa bez tej bramki.',
          );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coparentes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    child: Text(context.tr('Subskrypcja wkrótce')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.read<AppProvider>().logout(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                    child: Text(context.tr('Wyloguj')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
