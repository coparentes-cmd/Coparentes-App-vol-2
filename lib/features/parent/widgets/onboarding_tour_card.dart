import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../settings/generate_recovery_code_flow.dart';
import '../../settings/settings_screen.dart';

/// Floating post-registration tour card (steps 1–3) under the dashboard header.
class OnboardingTourCard extends StatefulWidget {
  const OnboardingTourCard({super.key});

  @override
  State<OnboardingTourCard> createState() => _OnboardingTourCardState();
}

class _OnboardingTourCardState extends State<OnboardingTourCard>
    with WidgetsBindingObserver {
  static const _autoAdvance = Duration(seconds: 3);
  static const _tick = Duration(milliseconds: 50);

  Timer? _timer;
  int? _timerStep;
  Duration _elapsed = Duration.zero;
  Duration _total = _autoAdvance;
  bool _paused = false;
  double _progress = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _resumeTimerIfNeeded();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _paused = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _timerStep = null;
    _elapsed = Duration.zero;
    _total = _autoAdvance;
  }

  void _resumeTimerIfNeeded() {
    if (!mounted) return;
    final step = context.read<AppProvider>().onboardingTourStep;
    if (step == null || step < 2) return;
    if (_elapsed >= _total) {
      unawaited(_onTimerFinished(step));
      return;
    }
    _startTicker(step);
  }

  void _syncTimer(int step) {
    if (step < 2 || step > 3) {
      _cancelTimer();
      _paused = false;
      if (_progress != 1 && mounted) {
        setState(() => _progress = 1);
      }
      return;
    }
    if (_timer != null && _timerStep == step) {
      return;
    }
    if (_paused) {
      return;
    }
    _elapsed = Duration.zero;
    _total = _autoAdvance;
    _startTicker(step);
  }

  void _startTicker(int step) {
    _timer?.cancel();
    _timerStep = step;
    if (mounted) {
      setState(() {
        _progress = 1 - (_elapsed.inMilliseconds / _total.inMilliseconds);
      });
    }
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || _paused) return;
      // Freeze while Settings / dialogs / sheets cover the dashboard route.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _elapsed += _tick;
      if (_elapsed >= _total) {
        final finishedStep = step;
        _cancelTimer();
        setState(() => _progress = 0);
        unawaited(_onTimerFinished(finishedStep));
        return;
      }
      setState(() {
        _progress = 1 - (_elapsed.inMilliseconds / _total.inMilliseconds);
      });
    });
  }

  Future<void> _onTimerFinished(int step) async {
    if (!mounted) return;
    final ap = context.read<AppProvider>();
    if (ap.onboardingTourStep != step) return;
    if (step == 2) {
      await ap.setOnboardingTourStep(3);
    } else if (step == 3) {
      await ap.setOnboardingTourStep(null);
    }
  }

  Future<void> _dismissAll() async {
    _cancelTimer();
    _paused = false;
    await context.read<AppProvider>().setOnboardingTourStep(null);
  }

  Future<void> _onTapStep(int step, Color roleColor) async {
    final ap = context.read<AppProvider>();
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
      _cancelTimer();
      await ap.setOnboardingTourStep(3);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(
            focus: SettingsFocus.parentInvite,
          ),
        ),
      );
      return;
    }
    if (step == 3) {
      _cancelTimer();
      await ap.setOnboardingTourStep(null);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
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
    final step = ap.onboardingTourStep;
    final user = ap.currentUser;
    if (step == null ||
        step < 1 ||
        step > 3 ||
        user == null ||
        (user.role != UserRole.parentA && user.role != UserRole.parentB)) {
      if (_timer != null) {
        _cancelTimer();
      }
      return const SizedBox.shrink();
    }

    if (_timerStep != step && !_paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (context.read<AppProvider>().onboardingTourStep == step) {
          _syncTimer(step);
        }
      });
    }

    final roleColor = user.role == UserRole.parentA
        ? AppTheme.parentAColor
        : AppTheme.parentBColor;

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

    final showTimer = step >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTapStep(step, roleColor),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Krok $step z 3'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: _dismissAll,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: context.tr('Zamknij'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (showTimer) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      color: roleColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
