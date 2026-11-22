import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/client_platform.dart';

/// In-app D−3 notice when mobile trial ends within 3 days.
/// Hidden on web, demo, child, and outside the D−3 window.
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.currentUser;
    if (_dismissed || app.isDemoMode || !TrialEndingBanner.shouldShow(user)) {
      return const SizedBox.shrink();
    }

    final days = TrialEndingBanner.daysRemaining(user!);
    final message = days <= 0
        ? context.tr(
            'Okres testowy kończy się dziś. Subskrybuj, żeby zachować dostęp na telefonie.',
          )
        : context
            .tr(
              'Okres testowy kończy się za {days} dni. Web pozostaje bez płatności.',
            )
            .replaceAll('{days}', '$days');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppTints.tealBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, color: AppTints.tealFg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}
