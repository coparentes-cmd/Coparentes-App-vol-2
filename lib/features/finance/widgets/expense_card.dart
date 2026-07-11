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
import 'split_overview_card.dart';
import 'dispute_expense_sheet.dart';
import 'add_expense_sheet.dart';

class ExpenseCard extends StatefulWidget {
  final Expense expense;
  final bool isReadOnly;
  final String? currentUserId;
  final FinanceProvider finance;
  final List<AppUser> members;
  final List<ChildProfile> children;
  final bool highlightExpanded;
  final VoidCallback onDispute;
  final Future<void> Function() onAccept;
  final VoidCallback onSettled;

  const ExpenseCard({
    required this.expense,
    required this.isReadOnly,
    required this.currentUserId,
    required this.finance,
    required this.members,
    required this.children,
    this.highlightExpanded = false,
    required this.onDispute,
    required this.onAccept,
    required this.onSettled,
  });

  @override
  State<ExpenseCard> createState() => ExpenseCardState();
}

class ExpenseCardState extends State<ExpenseCard> {
  late bool _showDetails;

  @override
  void initState() {
    super.initState();
    _showDetails = widget.highlightExpanded;
  }

  @override
  void didUpdateWidget(ExpenseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightExpanded && !oldWidget.highlightExpanded) {
      _showDetails = true;
    }
  }

  String _memberName(String userId) {
    for (final m in widget.members) {
      if (m.id == userId) return m.name.split(' ').first;
    }
    return 'Rodzic';
  }

  String? _childName(String? childId) {
    if (childId == null) return null;
    for (final c in widget.children) {
      if (c.id == childId) return c.name.split(' ').first;
    }
    return null;
  }

  String _splitLabel(double ratio) {
    final pct = (ratio * 100).round();
    return '$pct/${100 - pct}';
  }

  Future<void> _showReceipt(BuildContext context, String expenseId) async {
    final data = await context.read<FinanceProvider>().getReceipt(expenseId);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się pobrać paragonu.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final contentBase64 = data['contentBase64'] as String?;
    if (contentBase64 == null || contentBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak zapisanego paragonu.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final bytes = decodeReceiptBase64(contentBase64);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Paragon'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _otherParentName(String payerId) {
    for (final m in widget.members) {
      if (m.id != payerId &&
          (m.role == UserRole.parentA || m.role == UserRole.parentB)) {
        return m.name.split(' ').first;
      }
    }
    return 'drugiego rodzica';
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final currencyCode = context.watch<AppProvider>().currencyCode;
    final payerName = _memberName(expense.paidBy);
    final childName = _childName(expense.childId);
    final otherShare = expense.amountDue;
    final userId = widget.currentUserId;
    final canRespond = !widget.isReadOnly &&
        userId != null &&
        widget.finance.canRespondToExpense(expense, userId);
    final awaitingOther = !widget.isReadOnly &&
        userId != null &&
        widget.finance.isAwaitingOtherParent(expense, userId);
    final otherParentName = _otherParentName(expense.paidBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: expense.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    expense.categoryIcon,
                    color: expense.statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${expense.date.day}.${expense.date.month}.${expense.date.year}'
                        ' · ${expense.category}'
                        '${childName != null ? ' · $childName' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${expense.amount.toStringAsFixed(0)} $currencyCode',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Udział: ${otherShare.toStringAsFixed(0)} $currencyCode',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatusChip(
                  label: expense.status == ExpenseStatus.settled
                      ? 'Rozliczone'
                      : expense.statusLabel,
                  color: expense.statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Zapłacił: $payerName · ${_splitLabel(expense.splitRatio)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showDetails ? Icons.expand_less : Icons.info_outline,
                    size: 18,
                    color: AppTheme.textHint,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                ),
              ],
            ),
            if (expense.status == ExpenseStatus.settled) ...[
              const SizedBox(height: 6),
              const Text(
                'Uregulowane poza aplikacją',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (expense.note != null) ...[
              const SizedBox(height: 8),
              Text(
                expense.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Text(
                'Hash integralności: ${expense.hash}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textHint,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (expense.hasReceipt) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReceipt(context, expense.id),
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text(
                    'Zobacz paragon',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (awaitingOther) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Oczekuje na akceptację od $otherParentName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canRespond) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Spór', style: TextStyle(fontSize: 12)),
                      onPressed: widget.onDispute,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text(
                        'Akceptuj',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => widget.onAccept(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!widget.isReadOnly &&
                expense.status == ExpenseStatus.accepted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text(
                    'Oznacz jako rozliczone',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: widget.onSettled,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
