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
import 'expense_card.dart';
import 'add_expense_sheet.dart';

class DisputeExpenseSheet extends StatefulWidget {
  final Expense expense;

  const DisputeExpenseSheet({required this.expense});

  @override
  State<DisputeExpenseSheet> createState() => DisputeExpenseSheetState();
}

class DisputeExpenseSheetState extends State<DisputeExpenseSheet> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _noteController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj powód sporu.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<FinanceProvider>().updateExpenseStatus(
        widget.expense.id,
        ExpenseStatus.disputed,
        note: reason,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wydatek oznaczony jako sporny. Drugi rodzic zobaczy zmianę automatycznie.',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się zgłosić sporu.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zgłoś spór',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.expense.title,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Powód sporu',
              hintText: 'Np. kwota przekracza uzgodniony limit',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Zgłoś spór'),
            ),
          ),
        ],
      ),
    );
  }
}
