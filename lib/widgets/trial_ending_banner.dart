import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/auth/paywall_screen.dart';
import '../theme/app_theme.dart';
import '../utils/client_platform.dart';
import '../utils/open_url.dart';
import 'mobile_onboarding_chrome.dart';

/// In-app D−3 notice when mobile trial ends within 3 days (mockup 10).
class TrialEndingBanner extends StatefulWidget {
  const TrialEndingBanner({super.key});

  static bool shouldShow(AppUser? user) {
    if (kIsWeb || !isMobileClientPlatform) {
      return false;
    }
    if (user == null || user.role == UserRole.child) {
      return false;
    }
    return user.isTrialEndingSoon;
  }

  static int daysRemaining(AppUser user) {
    final ends = user.trialEndsAt;
    if (ends == null) {
      return 0;
    }
    final diff = ends.difference(DateTime.now());
    if (diff.isNegative) {
      return 0;
    }
    return diff.inDays;
  }

  @override
  State<TrialEndingBanner> createState() => _TrialEndingBannerState();
}

class _TrialEndingBannerState extends State<TrialEndingBanner> {
  bool _dismissed = false;
  bool _loading = false;

  String _formatEndDate(DateTime d) {
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

  Future<void> _order() async {
    setState(() => _loading = true);
    final ap = context.read<AppProvider>();
    final url = await ap.createCheckoutUrl();
    if (!mounted) return;
    setState(() => _loading = false);
    if (url != null) {
      openExternalUrl(url);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.currentUser;
    if (_dismissed || app.isDemoMode || !TrialEndingBanner.shouldShow(user)) {
      return const SizedBox.shrink();
    }

    final ends = user!.trialEndsAt!;
    final title = context
        .tr('Okres próbny kończy się {date}')
        .replaceAll('{date}', _formatEndDate(ends));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: MobileOnboarding.amberSoft,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: MobileOnboarding.amberFg,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Zamknij'),
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : _order,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MobileOnboarding.amberFg,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(96, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.tr('Zamów')),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: MobileOnboarding.amberFg,
                    ),
                    child: Text(context.tr('Zobacz szczegóły')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
