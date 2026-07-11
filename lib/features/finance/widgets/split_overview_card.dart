import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../data/api/app_api_client.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/exports_provider.dart';
import '../../../../providers/offline_sync_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/receipt_attachment_service.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';

import 'status_count_chip.dart';
import 'period_chip.dart';
import 'summary_card.dart';
import 'category_bar.dart';
import 'expense_card.dart';
import 'dispute_expense_sheet.dart';
import 'add_expense_sheet.dart';

class SplitOverviewCard extends StatelessWidget {
  final FinanceProvider finance;

  const SplitOverviewCard({required this.finance});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final currencyCode = appProvider.currencyCode;
    final members = appProvider.currentWorkspace?.members ?? [];

    AppUser? parentA;
    AppUser? parentB;
    for (final member in members) {
      if (member.role == UserRole.parentA) {
        parentA = member;
      } else if (member.role == UserRole.parentB) {
        parentB = member;
      }
    }

    final totalA = parentA == null
        ? 0.0
        : finance.expenses
            .where((e) => e.paidBy == parentA!.id)
            .fold(0.0, (sum, e) => sum + e.amount);
    final totalB = parentB == null
        ? 0.0
        : finance.expenses
            .where((e) => e.paidBy == parentB!.id)
            .fold(0.0, (sum, e) => sum + e.amount);
    final total = totalA + totalB;
    final ratioA = total > 0 ? totalA / total : 0.5;
    final nameA = parentA?.name.split(' ').first ?? 'Rodzic A';
    final nameB = parentB?.name.split(' ').first ?? 'Rodzic B';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameA,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${totalA.toStringAsFixed(0)} $currencyCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.parentAColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nameB,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${totalB.toStringAsFixed(0)} $currencyCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.parentBColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratioA,
              backgroundColor: AppTheme.parentBColor.withValues(alpha: 0.3),
              color: AppTheme.parentAColor,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}
