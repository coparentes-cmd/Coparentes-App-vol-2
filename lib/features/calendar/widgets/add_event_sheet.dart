import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/calendar_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../widgets/common_widgets.dart';

import '../calendar_helpers.dart';
import 'package:coparentes/l10n/app_strings.dart';

class AddEventSheet extends StatefulWidget {
  final DateTime selectedDay;
  final CalendarEvent? event;

  const AddEventSheet({
    required this.selectedDay,
    this.event,
  });

  @override
  State<AddEventSheet> createState() => AddEventSheetState();
}

class AddEventSheetState extends State<AddEventSheet> {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  late EventType _selectedType;
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;
  int _hintIndex = 0;
  Timer? _hintTimer;

  bool get _isEditing => widget.event != null;

  bool get _showCyclingPlaceholder =>
      !_isEditing &&
      _titleController.text.isEmpty &&
      !_titleFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event.title;
      _selectedType = event.type;
      final localStart = event.startDate.toLocal();
      _selectedTime = TimeOfDay(
        hour: localStart.hour,
        minute: localStart.minute,
      );
    } else {
      _selectedType = EventType.other;
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
    }
    _titleController.addListener(_onTitleChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _startHintTimer();
  }

  void _startHintTimer() {
    if (AiTips.calendarPlaceholders.length <= 1) {
      return;
    }
    _hintTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_showCyclingPlaceholder) {
        return;
      }
      setState(() {
        _hintIndex = (_hintIndex + 1) % AiTips.calendarPlaceholders.length;
      });
    });
  }

  void _onTitleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTitleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Podaj tytuł zdarzenia.')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final startDate = calendarDateTimeFrom(
        day: widget.selectedDay,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
      final app = context.read<AppProvider>();
      final calendar = context.read<CalendarProvider>();
      if (_isEditing) {
        final existing = widget.event!;
        if (app.isDemoMode || existing.id.startsWith('local_evt_')) {
          calendar.updateLocalEvent(
            id: existing.id,
            title: title,
            startDate: startDate,
            type: _selectedType,
            description: existing.description,
            endDate: existing.endDate,
            childId: existing.childId,
            location: existing.location,
          );
        } else {
          await calendar.updateEvent(
            id: existing.id,
            title: title,
            startDate: startDate,
            type: _selectedType,
            description: existing.description,
            endDate: existing.endDate,
            childId: existing.childId,
            location: existing.location,
          );
        }
      } else if (app.isDemoMode) {
        calendar.addLocalEvent(
          title: title,
          startDate: startDate,
          type: _selectedType,
          createdBy: app.currentUser?.id ?? 'demo',
        );
      } else {
        await calendar.addEvent(
          title: title,
          startDate: startDate,
          type: _selectedType,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? context.tr('Zdarzenie zostało zaktualizowane') : context.tr('Zdarzenie zostało dodane'),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(calendarActionError(error, 'zdarzenia'))),
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
    final hintText = _showCyclingPlaceholder
        ? AiTips.calendarPlaceholders[
            _hintIndex % AiTips.calendarPlaceholders.length]
        : null;

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
          Text(
            _isEditing ? context.tr('Edytuj zdarzenie') : context.tr('Nowe zdarzenie'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Data: ${widget.selectedDay.day}.${widget.selectedDay.month}.${widget.selectedDay.year}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.access_time, color: AppTheme.textSecondary),
            title: Text(context.tr('Godzina')),
            subtitle: Text(_formatTime(_selectedTime)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTime,
          ),
          SizedBox(height: 8),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              labelText: context.tr('Tytuł zdarzenia'),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: hintText,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? context.tr('Zapisz zmiany') : context.tr('Dodaj zdarzenie')),
            ),
          ),
        ],
      ),
    );
  }
}
