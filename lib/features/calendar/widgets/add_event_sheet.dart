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
import 'swap_request_sheet.dart';
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

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

class AddEventSheetState extends State<AddEventSheet>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  late EventType _selectedType;
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;
  int _hintIndex = 0;
  Timer? _hintTimer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

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
      _selectedType = EventType.school;
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
    }
    _titleController.addListener(_onTitleChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _startHintTimer();
  }

  void _startHintTimer() {
    if (AiTips.calendarPlaceholders.length <= 1) {
      return;
    }
    _hintTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_nextHint());
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

  Future<void> _nextHint() async {
    if (!mounted || !_showCyclingPlaceholder) {
      return;
    }
    await _fadeCtrl.reverse();
    if (!mounted) {
      return;
    }
    setState(() {
      _hintIndex = (_hintIndex + 1) % AiTips.calendarPlaceholders.length;
    });
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _fadeCtrl.dispose();
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
        const SnackBar(
          content: Text('Podaj tytuł zdarzenia.'),
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
                ? 'Zdarzenie zostało zaktualizowane'
                : 'Zdarzenie zostało dodane',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(calendarActionError(error, 'zdarzenia')),
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
    final showCyclingPlaceholder = _showCyclingPlaceholder;
    final hintStyle = Theme.of(context).inputDecorationTheme.hintStyle ??
        const TextStyle(color: AppTheme.textHint);
    const fieldPadding = EdgeInsets.fromLTRB(18, 28, 18, 12);

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
            _isEditing ? 'Edytuj zdarzenie' : 'Nowe zdarzenie',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data: ${widget.selectedDay.day}.${widget.selectedDay.month}.${widget.selectedDay.year}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: AppTheme.textSecondary),
            title: const Text('Godzina'),
            subtitle: Text(_formatTime(_selectedTime)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  labelText: 'Tytuł zdarzenia',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: showCyclingPlaceholder
                      ? null
                      : (!_isEditing &&
                              _titleFocusNode.hasFocus &&
                              _titleController.text.isEmpty)
                          ? null
                          : 'np. Angielski – Zosia',
                ),
              ),
              if (showCyclingPlaceholder)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: fieldPadding,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Text(
                            AiTips.calendarPlaceholders[_hintIndex %
                                AiTips.calendarPlaceholders.length],
                            style: hintStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Typ zdarzenia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: EventType.values.map((type) {
              final labels = {
                EventType.school: 'Szkoła',
                EventType.medical: 'Zdrowie',
                EventType.activity: 'Zajęcia',
                EventType.handover: 'Przekazanie',
                EventType.holiday: 'Ferie',
                EventType.other: 'Inne',
              };
              return ChoiceChip(
                label: Text(labels[type]!),
                selected: _selectedType == type,
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primaryTeal,
              );
            }).toList(),
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
                  : Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj zdarzenie'),
            ),
          ),
        ],
      ),
    );
  }
}
