import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
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

  String _dateOnlyLabel(BuildContext context) {
    final slot = handover;
    if (slot == null) {
      return context.tr('Brak zaplanowanego przekazania');
    }
    // Date part without time — time is shown separately on the right.
    final full = formatNextHandoverLabel(
      slot,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final time = slot.handoverTime?.trim();
    if (time != null && time.isNotEmpty && full.endsWith(time)) {
      return full.substring(0, full.length - time.length).trimRight();
    }
    return full;
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
    final time = handover?.handoverTime?.trim();
    final theme = Theme.of(context).textTheme;

    return Material(
      color: AppTints.tealBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.cardPaddingH,
            vertical: AppSpace.cardPaddingV,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppTints.tealBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Najbliższe przekazanie opieki').toUpperCase(),
                style: theme.labelSmall?.copyWith(color: AppTints.tealFg),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _dateOnlyLabel(context),
                      style: theme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasHandover
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (time != null && time.isNotEmpty)
                    Text(
                      time,
                      style: theme.titleLarge?.copyWith(
                        color: AppTints.tealFg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (hasHandover) ...[
                const SizedBox(height: 8),
                Text(
                  _placeLabel(context),
                  style: theme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
