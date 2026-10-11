import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/finance_provider.dart';
import '../../../../theme/app_theme.dart';

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

    final a = parentA;
    final b = parentB;
    final totals = a != null && b != null
        ? finance.paidTotalsForParents(
            parentAId: a.id,
            parentBId: b.id,
          )
        : (paidByA: 0.0, paidByB: 0.0);
    final totalA = totals.paidByA;
    final totalB = totals.paidByB;
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
