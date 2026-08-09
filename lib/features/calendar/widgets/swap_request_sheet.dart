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
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class SwapRequestSheet extends StatefulWidget {
  final DateTime selectedDay;
  final VoidCallback? onSubmitted;

  const SwapRequestSheet({
    required this.selectedDay,
    this.onSubmitted,
  });

  @override
  State<SwapRequestSheet> createState() => SwapRequestSheetState();
}

class SwapRequestSheetState extends State<SwapRequestSheet> {
  final _reasonController = TextEditingController();
  late DateTime _originalDate;
  late DateTime _proposedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _originalDate = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    _proposedDate = _originalDate.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<CalendarProvider>().createSwapRequest(
            originalDate: _originalDate,
            proposedDate: _proposedDate,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      widget.onSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wniosek wysłany. Drugi rodzic zobaczy go w wiadomościach → Zmiana grafiku.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(calendarActionError(error, 'zmiany opieki')),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zmiana opieki',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zaproponuj zmianę dnia opieki. Drugi rodzic otrzyma powiadomienie i będzie mógł zaakceptować lub odrzucić.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dzień do zmiany'),
            subtitle: Text(
              '${_originalDate.day}.${_originalDate.month}.${_originalDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _originalDate,
              onSelected: (value) => setState(() => _originalDate = value),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Proponowany dzień'),
            subtitle: Text(
              '${_proposedDate.day}.${_proposedDate.month}.${_proposedDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _proposedDate,
              onSelected: (value) => setState(() => _proposedDate = value),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Powód zmiany (opcjonalnie)',
              hintText: 'np. Wyjazd służbowy, urodziny babci...',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Wyślij propozycję'),
            ),
          ),
        ],
      ),
    );
  }
}
