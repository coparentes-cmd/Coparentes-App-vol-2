import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// iPhone-style expandable settings group (harmonijka).
class IosSettingsAccordion extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final bool isDark;
  final Color accent;
  final VoidCallback onToggle;
  final List<Widget> children;

  const IosSettingsAccordion({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.isDark,
    required this.accent,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final chevronColor = isDark ? Colors.white54 : const Color(0xFFC7C7CC);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.chevron_right,
                            color: chevronColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 56,
                      color: isDark
                          ? Colors.white12
                          : AppTheme.dividerColor,
                    ),
                    ...children,
                  ],
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
