import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/offline_sync_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../config/messaging_categories.dart';
import '../../../../utils/messaging_helpers.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../utils/app_browser_back.dart';
import '../../../../widgets/brand_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../screens/messaging/messaging_screen.dart';
import '../../../screens/calendar/calendar_screen.dart';
import '../../../screens/finance/finance_screen.dart';
import '../../../screens/exports/exports_screen.dart';
import '../../../screens/documents/documents_screen.dart';
import '../../../screens/ai_coach/ai_coach_screen.dart';
import '../../../screens/settings/settings_screen.dart';

import 'dashboard_home.dart';
import 'today_card.dart';
import 'stat_card.dart';
import 'message_thread_preview.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class FinanceSnapshotCard extends StatelessWidget {
  final FinanceProvider finance;
  final AppUser? user;
  final AppUser? parentA;
  final AppUser? parentB;

  const FinanceSnapshotCard({
    required this.finance,
    this.user,
    this.parentA,
    this.parentB,
  });

  @override
  Widget build(BuildContext context) {
    final pending = finance.expenses
        .where((e) => e.status == ExpenseStatus.pending)
        .toList();

    final balanceHeadline = user != null && parentA != null && parentB != null
        ? finance.balanceHeadline(
            parentAId: parentA!.id,
            parentBId: parentB!.id,
            parentAName: parentA!.name,
            parentBName: parentB!.name,
          )
        : 'Saldo niedostępne';

    final pendingRefund = user != null
        ? finance.pendingRefundForUser(user!.id)
        : finance.totalPending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wydatki w tym miesiącu',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${finance.totalThisMonth.toStringAsFixed(0)} PLN',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Saldo netto',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      balanceHeadline,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oczekujące: ${pendingRefund.toStringAsFixed(0)} PLN',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...pending.take(2).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(e.categoryIcon, size: 16, color: e.statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${e.amountDue.toStringAsFixed(0)} PLN',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
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
