import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Visual tokens for Etap A mobile onboarding (mockups 1–12).
class MobileOnboarding {
  static const Color blue = Color(0xFF2F6FED);
  static const Color blueSoft = Color(0xFFE8F0FE);
  static const Color greenSoft = Color(0xFFE7F7EE);
  static const Color greenFg = Color(0xFF1B7A45);
  static const Color amberSoft = Color(0xFFFFF3E0);
  static const Color amberFg = Color(0xFFB45309);
  static const Color pageBg = Color(0xFFF4F6F9);
  static const Color dashed = Color(0xFF9BB6E8);

  static ButtonStyle primaryButton({bool enabled = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: enabled ? blue : AppTheme.dividerColor,
      foregroundColor: enabled ? Colors.white : AppTheme.textHint,
      disabledBackgroundColor: AppTheme.dividerColor,
      disabledForegroundColor: AppTheme.textHint,
      elevation: 0,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle outlineButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: blue,
      side: const BorderSide(color: blue, width: 1.4),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}

class OnboardingProgressHeader extends StatelessWidget {
  final String stepLabel;
  final double progress;
  final VoidCallback? onBack;

  const OnboardingProgressHeader({
    super.key,
    required this.stepLabel,
    required this.progress,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null)
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(context.tr('Wstecz')),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                ),
              )
            else
              const SizedBox(height: 40),
            const Spacer(),
            Text(
              stepLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppTheme.dividerColor,
            color: MobileOnboarding.blue,
          ),
        ),
      ],
    );
  }
}

class OnboardingInfoBox extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  const OnboardingInfoBox({
    super.key,
    required this.text,
    this.background = MobileOnboarding.blueSoft,
    this.foreground = MobileOnboarding.blue,
    this.icon = Icons.info_outline,
  });

  factory OnboardingInfoBox.trial(BuildContext context) {
    return OnboardingInfoBox(
      text: context.tr(
        'Na telefonie: 30 dni za darmo, potem 29,99 zł / miesiąc. '
        'Wersja webowa Coparentes pozostaje bez płatności.',
      ),
      background: MobileOnboarding.blueSoft,
      foreground: MobileOnboarding.blue,
      icon: Icons.smartphone_outlined,
    );
  }

  factory OnboardingInfoBox.trialGreen(BuildContext context) {
    return OnboardingInfoBox(
      text: context.tr(
        'Pierwsze 30 dni w aplikacji mobilnej są darmowe, potem 29,99 zł / miesiąc. '
        'Web zostaje bez opłat.',
      ),
      background: MobileOnboarding.greenSoft,
      foreground: MobileOnboarding.greenFg,
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingDashedCodeBox extends StatelessWidget {
  final String code;

  const OnboardingDashedCodeBox({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashBorderPainter(
        color: MobileOnboarding.dashed,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        alignment: Alignment.center,
        child: Text(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: MobileOnboarding.blue,
          ),
        ),
      ),
    );
  }
}

class _DashBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 7.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class OnboardingRoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const OnboardingRoleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MobileOnboarding.blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? MobileOnboarding.blue : AppTheme.dividerColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? MobileOnboarding.blue : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
