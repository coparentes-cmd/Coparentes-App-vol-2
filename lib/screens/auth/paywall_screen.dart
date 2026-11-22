import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
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
  bool _portalLoading = false;

  bool get _busy => _checkoutLoading || _portalLoading;

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

  Future<void> _openPortal() async {
    setState(() => _portalLoading = true);
    final ap = context.read<AppProvider>();
    final url = await ap.createPortalUrl();
    if (!mounted) {
      return;
    }
    setState(() => _portalLoading = false);

    if (url == null) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            ap.authError ??
                context.tr('Nie udało się otworzyć portalu subskrypcji.'),
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
    // Portal needs a Stripe customer — set when Checkout completed (billingSource).
    final hasStripeCustomer = user?.billingSource == 'stripe';
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
            'Twój 30-dniowy okres próbny na telefonie dobiegł końca. '
            'Subskrypcja Coparentes kosztuje 29,99 zł miesięcznie. '
            'Aplikacja webowa pozostaje bez płatności.',
          )
        : context.tr(
            'Na telefonie Coparentes wymaga aktywnego okresu próbnego lub subskrypcji. '
            'Web działa bez tej bramki.',
          );

    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.brandHeaderBlue.withValues(alpha: 0.12),
                scheme.surface,
                scheme.surface,
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coparentes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandHeaderBlue,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTints.tealBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: AppTints.tealFg,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FeatureLine(
                    icon: Icons.chat_bubble_outline,
                    label: context.tr('Czat, kalendarz i finanse na telefonie'),
                  ),
                  _FeatureLine(
                    icon: Icons.computer_outlined,
                    label: context.tr('Web zawsze bez paywalla'),
                  ),
                  _FeatureLine(
                    icon: Icons.child_care_outlined,
                    label: context.tr('Konta dzieci bez opłat'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _startCheckout,
                      child: _checkoutLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('Subskrybuj 29,99 zł/mies.')),
                    ),
                  ),
                  if (hasStripeCustomer) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _openPortal,
                        child: _portalLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(context.tr('Zarządzaj subskrypcją')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.read<AppProvider>().logout(),
                      style: TextButton.styleFrom(
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
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTints.tealFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.85,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
