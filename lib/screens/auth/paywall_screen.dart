import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/open_url.dart';

/// Mobile-only gate when trial/subscription is missing (F3).
/// Never shown on web (`resolveAuthenticatedHome` + `kIsWeb` guard).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _checkoutLoading = false;

  Future<void> _startCheckout() async {
    setState(() => _checkoutLoading = true);
    final ap = context.read<AppProvider>();
    final url = await ap.createCheckoutUrl();
    if (!mounted) {
      return;
    }
    setState(() => _checkoutLoading = false);

    if (url == null) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            ap.authError ?? context.tr('Nie udało się otworzyć płatności.'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    openExternalUrl(url);
  }

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
            'Subskrypcja Coparentes kosztuje 29,99 zł miesięcznie (Stripe Test). '
            'Aplikacja webowa pozostaje bez płatności.',
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
                    onPressed: _checkoutLoading ? null : _startCheckout,
                    child: _checkoutLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Subskrybuj 29,99 zł/mies.')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _checkoutLoading
                        ? null
                        : () => context.read<AppProvider>().logout(),
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
