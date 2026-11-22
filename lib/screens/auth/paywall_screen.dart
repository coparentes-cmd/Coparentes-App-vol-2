import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/legal_config.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/open_url.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/mobile_onboarding_chrome.dart';
import 'subscription_screen.dart';

/// Mobile-only gate when trial/subscription is missing (F3) — mockup 11.
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
    final hasStripeCustomer = user?.billingSource == 'stripe';
    final isActive = status == BillingStatus.active;

    if (isActive) {
      return const SubscriptionScreen();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MobileOnboarding.pageBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandLogo(width: 160, height: 44),
                const Spacer(),
                Text(
                  context.tr('Twój okres próbny się skończył!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('29,99 zł miesięcznie, zawiera VAT'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                OnboardingInfoBox(
                  text: context.tr(
                    'Aplikacja webowa Coparentes pozostaje bez płatności. '
                    'Na telefonie subskrypcja odblokowuje pełny dostęp.',
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _busy ? null : _startCheckout,
                  style: MobileOnboarding.primaryButton(enabled: !_busy),
                  child: _checkoutLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('Zamawiam i płacę')),
                ),
                if (hasStripeCustomer) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : _openPortal,
                    style: MobileOnboarding.outlineButton(),
                    child: _portalLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Zarządzaj subskrypcją')),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => openExternalUrl(LegalConfig.websiteUrl),
                  style: TextButton.styleFrom(
                    foregroundColor: MobileOnboarding.blue,
                  ),
                  child: Text(
                    context.tr('Korzystaj dalej w przeglądarce za darmo'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.read<AppProvider>().logout(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  child: Text(context.tr('Wyloguj')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
