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
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';

class ExceptionRequestSheet extends StatefulWidget {
  final DateTime day;
  final UserRole? currentCustodian;

  const ExceptionRequestSheet({
    required this.day,
    this.currentCustodian,
  });

  @override
  State<ExceptionRequestSheet> createState() => ExceptionRequestSheetState();
}

class ExceptionRequestSheetState extends State<ExceptionRequestSheet> {
  late UserRole _custodian;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _custodian = widget.currentCustodian == UserRole.parentA
        ? UserRole.parentB
        : UserRole.parentA;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<CalendarProvider>().requestException(
            fromDate: widget.day,
            custodian: _custodian,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wniosek o wyjątek wysłany do akceptacji.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(calendarActionError(error, 'wniosku o wyjątek')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            'Zaproponuj zmianę opiekuna',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Drugi rodzic musi zaakceptować zmianę, zanim zacznie obowiązywać.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Dzień: ${widget.day.day}.${widget.day.month}.${widget.day.year}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.parentA, label: Text('Mama')),
              ButtonSegment(value: UserRole.parentB, label: Text('Tata')),
            ],
            selected: {_custodian},
            onSelectionChanged: (value) =>
                setState(() => _custodian = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Powód (opcjonalnie)',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Wysyłam...' : 'Wyślij do akceptacji'),
            ),
          ),
        ],
      ),
    );
  }
}
