import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/calendar_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../utils/app_browser_back.dart';
import '../../../screens/calendar/calendar_screen.dart';
import '../../../screens/messaging/messaging_screen.dart';

import 'child_todo_models.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.childColor.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.childColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: selected ? 28 : 24),
          ),
        ),
      ),
    );
  }
}
