import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../settings/generate_recovery_code_flow.dart';
import '../../settings/settings_screen.dart';

/// Host for the post-registration tour dialogs (steps 1–3).
///
/// Renders nothing in the scroll tree; presents a centered [showDialog] when
/// the dashboard route is current and a step is stored for a parent.
class OnboardingTourCard extends StatefulWidget {
  const OnboardingTourCard({super.key});

  @override
  State<OnboardingTourCard> createState() => _OnboardingTourCardState();
}

class _OnboardingTourCardState extends State<OnboardingTourCard> {
  bool _dialogOpen = false;
  int? _scheduledForStep;

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

  Future<void> _presentIfNeeded() async {
    if (!mounted || _dialogOpen) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final ap = context.read<AppProvider>();
    if (!_eligible(ap)) return;

    final step = ap.onboardingTourStep!;
    _dialogOpen = true;

    final result = await showDialog<_TourDialogResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        // PopScope must be the dialog route root so system/browser back is blocked.
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

    // Present the next step only when dashboard is the top route again.
    if (ModalRoute.of(context)?.isCurrent == true &&
        _eligible(context.read<AppProvider>())) {
      _queuePresent(context.read<AppProvider>().onboardingTourStep!);
    }
  }

  Future<void> _handleResult(_TourDialogResult? result, int step) async {
    if (result == null || !mounted) return;
    final ap = context.read<AppProvider>();
    final roleColor = ap.currentUser?.role == UserRole.parentA
        ? AppTheme.parentAColor
        : AppTheme.parentBColor;

    if (result == _TourDialogResult.next) {
      if (step == 1) {
        await ap.setOnboardingTourStep(2);
      } else if (step == 2) {
        await ap.setOnboardingTourStep(3);
      } else {
        await ap.setOnboardingTourStep(null);
      }
      return;
    }

    if (step == 1) {
      final shown = await runGenerateRecoveryCodeFlow(
        context,
        color: roleColor,
      );
      if (!mounted) return;
      if (shown) {
        await ap.setOnboardingTourStep(2);
      }
      return;
    }

    if (step == 2) {
      await ap.setOnboardingTourStep(3);
      if (!mounted) return;
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(
            focus: SettingsFocus.addChild,
          ),
        ),
      );
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
    final title = switch (step) {
      1 => context.tr('Zabezpiecz rozmowy'),
      2 => context.tr('Zaproś drugiego rodzica'),
      _ => context.tr('Dodaj dziecko'),
    };
    final body = switch (step) {
      1 => context.tr(
          'Czat jest szyfrowany end-to-end, więc przy zapomnianym haśle nie odzyskamy go za Ciebie. Kod odzyskiwania to zapasowy klucz. Dotknij, aby go wygenerować.',
        ),
      2 => context.tr(
          'Kod zaproszenia znajdziesz w Ustawieniach. Dotknij, aby tam przejść.',
        ),
      _ => context.tr(
          'Dodaj profil dziecka i wyślij mu kod w Ustawieniach. Dotknij, aby tam przejść.',
        ),
    };
    final cta = switch (step) {
      1 => context.tr('Wygeneruj kod'),
      2 => context.tr('Przejdź do Ustawień'),
      _ => context.tr('Dodaj dziecko'),
    };

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Material(
          color: AppTheme.brandHeaderBlue,
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
                          context.tr('Krok $step z 3'),
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
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('onboarding_tour_action'),
                            onPressed: onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.brandHeaderBlue,
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
