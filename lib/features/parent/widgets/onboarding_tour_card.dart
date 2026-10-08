import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../settings/settings_screen.dart';
import '../../settings/widgets/email_invite_sheet.dart';
import '../../settings/widgets/parent_invite_actions_sheet.dart';
import '../../../screens/auth/child_onboarding_sheet.dart';

Color _tourAccent(UserRole? role) {
  switch (role) {
    case UserRole.parentA:
      return AppTheme.parentAColor;
    case UserRole.parentB:
      return AppTheme.parentBColor;
    default:
      return AppTheme.primaryTeal;
  }
}

/// Opens parent-invite actions (Skopiuj / Wyślij kod e-mailem).
/// Used by tour krok 1 so the sheet appears immediately.
Future<void> presentParentInviteFromTour(
  BuildContext context, {
  required String inviteCode,
  required Color color,
}) async {
  final action = await ParentInviteActionsSheet.show(
    context,
    inviteCode: inviteCode,
    color: color,
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case ParentInviteAction.copy:
      await copyParentInviteCode(
        context,
        inviteCode: inviteCode,
        color: color,
      );
    case ParentInviteAction.sendEmail:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => EmailInviteSheet(
          color: color,
          inviteCode: inviteCode,
        ),
      );
  }
}

/// Host for the post-registration tour dialogs (invite parent → add child).
///
/// Renders nothing in the scroll tree; presents a centered [showDialog] when
/// the dashboard route is current and a step is stored for a parent.
/// Legacy step 1 (E2E recovery) is skipped.
class OnboardingTourCard extends StatefulWidget {
  const OnboardingTourCard({super.key});

  @override
  State<OnboardingTourCard> createState() => _OnboardingTourCardState();
}

class _OnboardingTourCardState extends State<OnboardingTourCard> {
  bool _dialogOpen = false;
  int? _scheduledForStep;
  bool _skippingLegacy = false;

  bool _eligible(AppProvider ap) {
    final step = ap.onboardingTourStep;
    final user = ap.currentUser;
    if (step == null || step < 1 || step > 3) return false;
    if (user == null) return false;
    return user.role == UserRole.parentA || user.role == UserRole.parentB;
  }

  void _queuePresent(int step) {
    if (_dialogOpen || _scheduledForStep == step) return;
    _scheduledForStep = step;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledForStep = null;
      unawaited(_presentIfNeeded());
    });
  }

  Future<void> _skipLegacyStep1IfNeeded(AppProvider ap) async {
    if (_skippingLegacy) return;
    if (ap.onboardingTourStep != 1) return;
    _skippingLegacy = true;
    await ap.setOnboardingTourStep(2);
    _skippingLegacy = false;
  }

  Future<void> _presentIfNeeded() async {
    if (!mounted || _dialogOpen) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final ap = context.read<AppProvider>();
    if (!_eligible(ap)) return;

    await _skipLegacyStep1IfNeeded(ap);
    if (!mounted) return;
    if (!_eligible(context.read<AppProvider>())) return;

    final step = context.read<AppProvider>().onboardingTourStep!;
    if (step == 1) return;

    _dialogOpen = true;

    final result = await showDialog<_TourDialogResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: _OnboardingTourDialog(
            step: step,
            onDismissToNext: () =>
                Navigator.of(dialogContext).pop(_TourDialogResult.next),
            onAction: () =>
                Navigator.of(dialogContext).pop(_TourDialogResult.action),
          ),
        );
      },
    );

    if (!mounted) {
      _dialogOpen = false;
      return;
    }

    await _handleResult(result, step);
    if (!mounted) {
      _dialogOpen = false;
      return;
    }
    _dialogOpen = false;

    if (ModalRoute.of(context)?.isCurrent == true &&
        _eligible(context.read<AppProvider>())) {
      _queuePresent(context.read<AppProvider>().onboardingTourStep!);
    }
  }

  Future<void> _handleResult(_TourDialogResult? result, int step) async {
    if (result == null || !mounted) return;
    final ap = context.read<AppProvider>();

    if (result == _TourDialogResult.next) {
      if (step == 2) {
        await ap.setOnboardingTourStep(3);
      } else {
        await ap.setOnboardingTourStep(null);
      }
      return;
    }

    if (step == 2) {
      await ap.setOnboardingTourStep(3);
      if (!mounted) return;
      final inviteCode = ap.currentWorkspace?.inviteCode;
      final color = _tourAccent(ap.currentUser?.role);
      if (inviteCode != null && inviteCode.isNotEmpty) {
        // Directly the invite sheet (same UI as tapping the code in Settings).
        await presentParentInviteFromTour(
          context,
          inviteCode: inviteCode,
          color: color,
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(
            focus: SettingsFocus.parentInvite,
          ),
        ),
      );
      return;
    }

    if (step == 3) {
      await ap.setOnboardingTourStep(null);
      if (!mounted) return;
      // Directly the add-child sheet (same UI as Settings → Dodaj dziecko).
      await showChildOnboardingSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    if (_eligible(ap) &&
        !_dialogOpen &&
        ModalRoute.of(context)?.isCurrent == true) {
      _queuePresent(ap.onboardingTourStep!);
    }
    return const SizedBox.shrink();
  }
}

enum _TourDialogResult { next, action }

class _OnboardingTourDialog extends StatelessWidget {
  final int step;
  final VoidCallback onDismissToNext;
  final VoidCallback onAction;

  const _OnboardingTourDialog({
    required this.step,
    required this.onDismissToNext,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final title = step == 2
        ? context.tr('Zaproś drugiego rodzica')
        : context.tr('Dodaj dziecko');
    final body = step == 2
        ? null
        : context.tr(
            'Dodaj profil dziecka i wyślij mu kod w Ustawieniach. Dotknij, aby tam przejść.',
          );
    final cta = step == 2
        ? context.tr('Przejdź do Ustawień')
        : context.tr('Dodaj dziecko');
    // After retiring E2E step 1: invite = krok 1, add child = krok 2.
    final stepLabel = step == 2 ? 'krok 1' : 'krok 2';
    const bannerColor = AppTheme.primaryTeal;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Material(
          color: bannerColor,
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(stepLabel),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        if (body != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('onboarding_tour_action'),
                            onPressed: onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: bannerColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(cta),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    key: const Key('onboarding_tour_close'),
                    customBorder: const CircleBorder(),
                    onTap: onDismissToNext,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
