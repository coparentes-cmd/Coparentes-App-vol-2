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

import '../calendar_helpers.dart';
import 'legend_item.dart';
import 'selected_day_card.dart';
import 'swap_card.dart';
import 'swap_date_row.dart';
import 'add_event_sheet.dart';
import 'swap_request_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class SwapRejectSheet extends StatefulWidget {
  final SwapRequest swap;
  final VoidCallback? onSubmitted;

  const SwapRejectSheet({
    required this.swap,
    this.onSubmitted,
  });

  @override
  State<SwapRejectSheet> createState() => SwapRejectSheetState();
}

class SwapRejectSheetState extends State<SwapRejectSheet> {
  final _reasonController = TextEditingController();
  late DateTime _counterOriginalDate;
  late DateTime _counterProposedDate;
  bool _proposeAlternativeDates = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _counterOriginalDate = DateTime(
      widget.swap.originalDate.year,
      widget.swap.originalDate.month,
      widget.swap.originalDate.day,
    );
    _counterProposedDate = DateTime(
      widget.swap.proposedDate.year,
      widget.swap.proposedDate.month,
      widget.swap.proposedDate.day,
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _counterDatesChanged {
    final sameOriginal = _counterOriginalDate.year == widget.swap.originalDate.year &&
        _counterOriginalDate.month == widget.swap.originalDate.month &&
        _counterOriginalDate.day == widget.swap.originalDate.day;
    final sameProposed = _counterProposedDate.year == widget.swap.proposedDate.year &&
        _counterProposedDate.month == widget.swap.proposedDate.month &&
        _counterProposedDate.day == widget.swap.proposedDate.day;
    return !sameOriginal || !sameProposed;
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _buildResponseNote({required SwapStatus status}) {
    final reason = _reasonController.text.trim();
    if (status == SwapStatus.counterProposed) {
      final lines = <String>[
        'Kontrpropozycja dat:',
        'Oryginalny dzień: ${formatSwapDate(_counterOriginalDate)}',
        'Proponowany dzień: ${formatSwapDate(_counterProposedDate)}',
      ];
      if (reason.isNotEmpty) {
        lines.add('Powód: $reason');
      }
      return lines.join('\n');
    }

    final lines = <String>[
      'Odrzucony wniosek:',
      'Oryginalny dzień: ${formatSwapDate(widget.swap.originalDate)}',
      'Proponowany dzień: ${formatSwapDate(widget.swap.proposedDate)}',
    ];
    if (reason.isNotEmpty) {
      lines.add('Powód: $reason');
    }
    return lines.join('\n');
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final useCounter = _proposeAlternativeDates && _counterDatesChanged;
    final status =
        useCounter ? SwapStatus.counterProposed : SwapStatus.rejected;
    final note = _buildResponseNote(status: status);

    try {
      await context.read<CalendarProvider>().respondToSwap(
            widget.swap.id,
            status,
            note: note,
          );
      if (!mounted) {
        return;
      }
      widget.onSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            useCounter
                ? 'Wysłano kontrpropozycję dat do ${widget.swap.requesterName}.'
                : 'Wniosek o zamianę został odrzucony.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(calendarActionError(error, 'odpowiedzi na wymianę')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Odrzuć wniosek o zamianę',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wniosek od ${widget.swap.requesterName}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                SwapDateRow(
                  label: 'Oryginalny dzień we wniosku',
                  date: widget.swap.originalDate,
                  icon: Icons.event,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 8),
                SwapDateRow(
                  label: 'Proponowany dzień we wniosku',
                  date: widget.swap.proposedDate,
                  icon: Icons.event_available,
                  color: AppTheme.successColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Proponuję inne daty',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: const Text(
              'Wyślij kontrpropozycję zamiast samego odrzucenia',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _proposeAlternativeDates,
            activeThumbColor: AppTheme.primaryTeal,
            onChanged: (value) => setState(() => _proposeAlternativeDates = value),
          ),
          if (_proposeAlternativeDates) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Twój oryginalny dzień'),
              subtitle: Text(formatSwapDate(_counterOriginalDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _counterOriginalDate,
                onSelected: (value) =>
                    setState(() => _counterOriginalDate = value),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Twój proponowany dzień'),
              subtitle: Text(formatSwapDate(_counterProposedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _counterProposedDate,
                onSelected: (value) =>
                    setState(() => _counterProposedDate = value),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Powód (opcjonalnie)',
              hintText: 'np. Mam wtedy wyjazd służbowy…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close, size: 18),
              label: Text(
                _proposeAlternativeDates && _counterDatesChanged
                    ? 'Odrzuć i wyślij kontrpropozycję'
                    : 'Odrzuć wniosek',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
