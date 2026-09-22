import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/custody_schedule_utils.dart';

/// Readable next custody handover strip — data from [CalendarProvider.getNextHandover].
class NextHandoverBar extends StatelessWidget {
  final CustodySlot? handover;
  final Color accentColor;
  final VoidCallback? onTap;

  const NextHandoverBar({
    super.key,
    required this.handover,
    required this.accentColor,
    this.onTap,
  });

  String _dateLabel(BuildContext context) {
    final slot = handover;
    if (slot == null) {
      return context.tr('Brak zaplanowanego przekazania');
    }
    return formatNextHandoverLabel(
      slot,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  String _placeLabel(BuildContext context) {
    final place = handover?.handoverLocation?.trim();
    if (place == null || place.isEmpty) {
      return context.tr('Miejsce nieustalone');
    }
    return context.tr(place);
  }

  @override
  Widget build(BuildContext context) {
    final hasHandover = handover != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Najbliższe przekazanie opieki'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateLabel(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: hasHandover
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasHandover) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _placeLabel(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: (handover?.handoverLocation?.trim().isEmpty ??
                                  true)
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
