import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/open_url.dart';
import '../../widgets/mobile_onboarding_chrome.dart';

/// Mobile subscription status (mockup 12).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = false;

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const months = <String>[
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _openPortal() async {
    setState(() => _loading = true);
    final ap = context.read<AppProvider>();
    final url = await ap.createPortalUrl();
    if (!mounted) return;
    setState(() => _loading = false);
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
    final active = status == BillingStatus.active;
    final nextPay = user?.currentPeriodEnd ?? user?.trialEndsAt;

    return Scaffold(
      backgroundColor: MobileOnboarding.pageBg,
      appBar: AppBar(
        title: Text(context.tr('Subskrypcja')),
        backgroundColor: MobileOnboarding.pageBg,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _Row(
                      label: context.tr('Status'),
                      value: active
                          ? context.tr('Aktywna')
                          : context.tr(status.name),
                      valueColor: active
                          ? MobileOnboarding.greenFg
                          : AppTheme.textPrimary,
                    ),
                    const Divider(height: 24),
                    _Row(
                      label: context.tr('Plan'),
                      value: context.tr('29,99 zł / miesiąc'),
                    ),
                    const Divider(height: 24),
                    _Row(
                      label: context.tr('Następna płatność'),
                      value: _formatDate(nextPay),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr(
                  'Potwierdzenia płatności wysyłamy e-mailem. '
                  'Subskrypcją zarządzasz w Stripe (anulowanie, karta).',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _loading ? null : _openPortal,
                style: MobileOnboarding.outlineButton(),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Zarządzaj subskrypcją')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
