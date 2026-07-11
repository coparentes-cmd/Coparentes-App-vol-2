import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/api/app_api_client.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/calendar_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../../widgets/google_style_month_calendar.dart';
import '../../../../widgets/custody_schedule_wizard.dart';

import 'legend_item.dart';
import 'selected_day_card.dart';
import 'swap_date_row.dart';
import 'add_event_sheet.dart';
import 'swap_request_sheet.dart';
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class SwapCard extends StatelessWidget {
  final SwapRequest swap;
  final bool isMyRequest;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const SwapCard({
    required this.swap,
    required this.isMyRequest,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMyRequest
                              ? 'Twój wniosek'
                              : 'Wniosek od ${swap.requesterName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: swap.statusLabel,
                        color: swap.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwapDateRow(
                    label: 'Oryginalny dzień',
                    date: swap.originalDate,
                    icon: Icons.event,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 6),
                  SwapDateRow(
                    label: 'Proponowany dzień',
                    date: swap.proposedDate,
                    icon: Icons.event_available,
                    color: AppTheme.successColor,
                  ),
                  if (swap.reason != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Powód: ${swap.reason}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (swap.responseNote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Odpowiedź: ${swap.responseNote}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (isMyRequest && swap.status == SwapStatus.pending) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Oczekuje na decyzję drugiego rodzica.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canRespond) ...[
              const SizedBox(width: 12),
              EnterAcceptScope(
                onAccept: onAccept,
                autofocus: keyboardAcceptAutofocus,
                child: SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Akceptuj',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Odrzuć',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
