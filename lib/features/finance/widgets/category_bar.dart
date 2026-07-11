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
import 'split_overview_card.dart';
import 'expense_card.dart';
import 'dispute_expense_sheet.dart';
import 'add_expense_sheet.dart';

class CategoryBar extends StatelessWidget {
  final String category;
  final double amount;
  final double maxAmount;
  final String currencyCode;

  const CategoryBar({
    required this.category,
    required this.amount,
    required this.maxAmount,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount > 0 ? amount / maxAmount : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
            Text(
              '${amount.toStringAsFixed(0)} $currencyCode',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: AppTheme.dividerColor,
          color: AppTheme.primaryTeal,
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}
