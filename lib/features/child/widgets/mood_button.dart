import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/app_tokens.dart';

class MoodButton extends StatelessWidget {
  final String emoji;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const MoodButton({
    required this.emoji,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected && !reduceMotion ? 1.06 : 1.0,
        duration: Duration(milliseconds: reduceMotion ? 0 : 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion ? 0 : 200),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppTints.childFeelSelected : AppTints.childFeelIdle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppTheme.childColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: selected ? 26 : 22),
            ),
          ),
        ),
      ),
    );
  }
}
