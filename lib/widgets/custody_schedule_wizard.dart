import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/api/app_api_client.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/custom_week_recurrence.dart';
import 'booking_style_calendar_picker.dart';
import 'mini_calendar_date_sheet.dart';

enum _CustomEndRule { never, onDate, afterOccurrences }

class CustodyScheduleWizard extends StatefulWidget {
  const CustodyScheduleWizard({super.key});

  @override
  State<CustodyScheduleWizard> createState() => _CustodyScheduleWizardState();
}

class _CustodyScheduleWizardState extends State<CustodyScheduleWizard> {
  CustodySchedulePattern _pattern = CustodySchedulePattern.weekAlternating;
  DateTime _startDate = DateTime.now();
  late DateTime _endDate;
  late final TextEditingController _handoverTimeController;
  late final TextEditingController _handoverLocationController;
  bool _isSubmitting = false;
  bool _calendarSaved = false;

  late Map<String, UserRole> _weekA;
  late Map<String, UserRole> _weekB;

  int _customIntervalWeeks = 2;
  final Set<int> _customWeekdays = {};
  _CustomEndRule _customEndRule = _CustomEndRule.never;
  int _customOccurrenceCount = 13;

  static const _dayKeys = customWeekDayKeys;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
    _handoverTimeController = TextEditingController(text: '17:00');
    _handoverLocationController = TextEditingController(text: 'Szkoła');
    _applyPatternPreset(_pattern, UserRole.parentA);
  }

  @override
  void dispose() {
    _handoverTimeController.dispose();
    _handoverLocationController.dispose();
    super.dispose();
  }

  bool get _usesTemplateDateRange =>
      _pattern == CustodySchedulePattern.weekAlternating ||
      _pattern == CustodySchedulePattern.everyOtherWeekend;

  bool get _usesCustomRecurrence =>
      _pattern == CustodySchedulePattern.customWeek;

  bool get _showsDateSection =>
      _usesTemplateDateRange || _usesCustomRecurrence;

  DateTime get _normalizedStartDate =>
      DateTime(_startDate.year, _startDate.month, _startDate.day);

  DateTime get _normalizedEndDate =>
      DateTime(_endDate.year, _endDate.month, _endDate.day);

  String _formatDate(DateTime date) =>
      '${date.day}.${date.month}.${date.year}';

  void _selectPattern(CustodySchedulePattern pattern) {
    final creatorRole =
        context.read<AppProvider>().currentUser?.role ?? UserRole.parentA;
    setState(() {
      _pattern = pattern;
      _calendarSaved = false;
      _customWeekdays.clear();
      _customIntervalWeeks = 2;
      _customEndRule = _CustomEndRule.never;
      _customOccurrenceCount = 13;
      _applyPatternPreset(pattern, creatorRole);
      _startDate = DateTime.now();
      _endDate =
          DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
    });
  }

  void _updateRange(DateTime? start, DateTime? end) {
    setState(() {
      _calendarSaved = false;
      if (start != null) {
        _startDate = start;
        _endDate = end ?? start;
      } else if (end != null) {
        _endDate = end;
      }
    });
  }

  Future<void> _openRangeMiniCalendar() async {
    final result = await showMiniCalendarSheet(
      context: context,
      mode: BookingCalendarMode.range,
      accentColor: AppTheme.accentColor,
      title: 'Okres obowiązywania',
      subtitle: 'Kliknij datę początkową, potem końcową.',
      initialMonth: _normalizedStartDate,
      rangeStart: _normalizedStartDate,
      rangeEnd: _normalizedEndDate,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.rangeStart == null || result.rangeEnd == null) {
      return;
    }
    _updateRange(result.rangeStart, result.rangeEnd);
    setState(() => _calendarSaved = true);
  }

  Future<void> _openSingleDatePicker({
    required String title,
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final result = await showMiniCalendarSheet(
      context: context,
      mode: BookingCalendarMode.range,
      accentColor: AppTheme.accentColor,
      title: title,
      subtitle: 'Wybierz dzień.',
      initialMonth: initial,
      rangeStart: initial,
      rangeEnd: initial,
    );
    if (result?.rangeStart == null || !mounted) {
      return;
    }
    onPicked(result!.rangeStart!);
  }

  void _toggleCustomWeekday(int weekday) {
    setState(() {
      if (_customWeekdays.contains(weekday)) {
        _customWeekdays.remove(weekday);
      } else {
        _customWeekdays.add(weekday);
      }
      _calendarSaved = false;
    });
  }

  void _applyCustomRecurrencePattern() {
    final creatorRole =
        context.read<AppProvider>().currentUser?.role ?? UserRole.parentA;
    final patterns = buildCustomWeekPatterns(
      creatorRole: creatorRole,
      weekdays: _customWeekdays,
      intervalWeeks: _customIntervalWeeks,
    );
    _weekA = patterns.weekA;
    _weekB = patterns.weekB;
  }

  DateTime? _resolveCustomEndDate() {
    switch (_customEndRule) {
      case _CustomEndRule.never:
        return null;
      case _CustomEndRule.onDate:
        return _normalizedEndDate;
      case _CustomEndRule.afterOccurrences:
        return endDateFromCustomOccurrences(
          startDate: _normalizedStartDate,
          weekdays: _customWeekdays,
          intervalWeeks: _customIntervalWeeks,
          occurrenceCount: _customOccurrenceCount,
        );
    }
  }

  bool _isCalendarReady() {
    if (!_showsDateSection) {
      return true;
    }
    if (_usesTemplateDateRange) {
      // Default start/end are valid — no need to reopen the mini-calendar.
      return !_normalizedEndDate.isBefore(_normalizedStartDate);
    }
    if (_usesCustomRecurrence) {
      if (_customWeekdays.isEmpty) {
        return false;
      }
      if (_customEndRule == _CustomEndRule.onDate &&
          _normalizedEndDate.isBefore(_normalizedStartDate)) {
        return false;
      }
      if (_customEndRule == _CustomEndRule.afterOccurrences &&
          _customOccurrenceCount < 1) {
        return false;
      }
      return true;
    }
    return true;
  }

  bool _applyCalendarIfReady({bool showErrors = true}) {
    if (!_isCalendarReady()) {
      if (!showErrors) {
        return false;
      }
      if (_usesTemplateDateRange) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data końca musi być taka sama lub późniejsza niż data startu.',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } else if (_usesCustomRecurrence) {
        final message = _customWeekdays.isEmpty
            ? 'Wybierz co najmniej jeden dzień tygodnia.'
            : 'Sprawdź datę końca grafiku.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }

    if (_usesCustomRecurrence) {
      _applyCustomRecurrencePattern();
    }
    _calendarSaved = true;
    return true;
  }

  bool _validateStep0() => _applyCalendarIfReady();

  void _applyPatternPreset(
    CustodySchedulePattern pattern,
    UserRole creatorRole,
  ) {
    final other = creatorRole == UserRole.parentA
        ? UserRole.parentB
        : UserRole.parentA;
    switch (pattern) {
      case CustodySchedulePattern.weekAlternating:
        _weekA = {for (final key in _dayKeys) key: UserRole.parentA};
        _weekB = {for (final key in _dayKeys) key: UserRole.parentB};
      case CustodySchedulePattern.everyOtherWeekend:
        _weekA = {
          'monday': UserRole.parentA,
          'tuesday': UserRole.parentA,
          'wednesday': UserRole.parentA,
          'thursday': UserRole.parentA,
          'friday': UserRole.parentA,
          'saturday': UserRole.parentB,
          'sunday': UserRole.parentB,
        };
        _weekB = {
          'monday': UserRole.parentB,
          'tuesday': UserRole.parentB,
          'wednesday': UserRole.parentB,
          'thursday': UserRole.parentB,
          'friday': UserRole.parentB,
          'saturday': UserRole.parentA,
          'sunday': UserRole.parentA,
        };
      case CustodySchedulePattern.customWeek:
        _weekA = {for (final key in _dayKeys) key: other};
        _weekB = {for (final key in _dayKeys) key: other};
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorRole =
        context.watch<AppProvider>().currentUser?.role ?? UserRole.parentA;
    final creatorColor = creatorRole == UserRole.parentA
        ? AppTheme.parentAColor
        : AppTheme.parentBColor;
    final creatorLabel = creatorRole == UserRole.parentA ? 'Mama' : 'Tata';

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter): _handleEnterKey,
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Szablon, kalendarz i przekazanie',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildPatternStep(
                    creatorColor: creatorColor,
                    creatorLabel: creatorLabel,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Po wysłaniu drugi rodzic dostanie wiadomość z prośbą o akceptację. '
                'Po zatwierdzeniu kolory opieki pojawią się automatycznie w obu kalendarzach.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitProposal,
                  style: FilledButton.styleFrom(
                    backgroundColor: creatorColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _isSubmitting ? 'Wysyłam…' : 'Wyślij propozycję',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleEnterKey() {
    if (_isSubmitting) {
      return;
    }
    unawaited(_submitProposal());
  }

  Future<void> _submitProposal() async {
    if (!_validateStep0()) {
      return;
    }
    await _sendProposal();
  }

  Future<void> _sendProposal() async {
    setState(() => _isSubmitting = true);
    try {
      final app = context.read<AppProvider>();
      final calendar = context.read<CalendarProvider>();
      final messaging = context.read<MessagingProvider>();
      final weekA = CustodyWeekPattern(_weekA);
      final weekB = CustodyWeekPattern(_weekB);
      final handoverTime = _handoverTimeController.text.trim().isEmpty
          ? null
          : _handoverTimeController.text.trim();
      final handoverLocation = _handoverLocationController.text.trim().isEmpty
          ? null
          : _handoverLocationController.text.trim();
      final endDate = _usesTemplateDateRange
          ? _normalizedEndDate
          : _resolveCustomEndDate();
      final weekInterval =
          _usesCustomRecurrence ? _customIntervalWeeks : null;

      if (app.isDemoMode) {
        final schedule = calendar.proposeScheduleDemo(
          proposedById: app.currentUser?.id ?? 'demo_user',
          patternType: _pattern,
          startDate: _normalizedStartDate,
          endDate: endDate,
          weekA: weekA,
          weekB: weekB,
          weekInterval: weekInterval,
          handoverTime: handoverTime,
          handoverLocation: handoverLocation,
        );
        final user = app.currentUser;
        if (user != null) {
          messaging.appendDemoScheduleProposal(
            schedule: schedule,
            sender: user,
          );
        }
      } else {
        await calendar.proposeSchedule(
          patternType: _pattern,
          startDate: _normalizedStartDate,
          endDate: endDate,
          weekA: weekA,
          weekB: weekB,
          weekInterval: weekInterval,
          handoverTime: handoverTime,
          handoverLocation: handoverLocation,
        );
        await messaging.loadThreads(
          viewerUserId: app.currentUser?.id,
          notifyEnabled: app.notifyMessages,
          silent: true,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_scheduleErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPatternStep({
    required Color creatorColor,
    required String creatorLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PatternOption(
          title: 'Co tydzień na zmianę',
          subtitle: 'Cały tydzień u jednego rodzica, potem u drugiego',
          value: CustodySchedulePattern.weekAlternating,
          groupValue: _pattern,
          accentColor: creatorColor,
          onChanged: _selectPattern,
        ),
        _PatternOption(
          title: 'Co drugi weekend',
          subtitle: 'Tygodnie robocze i weekendy na zmianę',
          value: CustodySchedulePattern.everyOtherWeekend,
          groupValue: _pattern,
          accentColor: creatorColor,
          onChanged: _selectPattern,
        ),
        _PatternOption(
          title: 'Własny tydzień',
          subtitle: 'Wybierz dni tygodnia, co ile się powtarza i kiedy kończy',
          value: CustodySchedulePattern.customWeek,
          groupValue: _pattern,
          accentColor: creatorColor,
          onChanged: _selectPattern,
        ),
        if (_showsDateSection) ...[
          const SizedBox(height: 16),
          if (_usesTemplateDateRange) ...[
            const Text(
              'Daty',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    IosDateFieldRow(
                      label: 'Początek',
                      value: _formatDate(_normalizedStartDate),
                      onTap: _openRangeMiniCalendar,
                    ),
                    const Divider(height: 1, indent: 16),
                    IosDateFieldRow(
                      label: 'Koniec',
                      value: _formatDate(_normalizedEndDate),
                      onTap: _openRangeMiniCalendar,
                    ),
                  ],
                ),
              ),
            ),
            if (_calendarSaved) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: creatorColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Okres ${_formatDate(_normalizedStartDate)} – ${_formatDate(_normalizedEndDate)}',
                    style: TextStyle(
                      color: creatorColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ] else
            _buildCustomRecurrenceSection(
              creatorColor: creatorColor,
              creatorLabel: creatorLabel,
            ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Przekazanie dziecka',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Godzina przekazania',
            hintText: '17:00',
          ),
          controller: _handoverTimeController,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Miejsce przekazania',
            hintText: 'Szkoła, dom...',
          ),
          controller: _handoverLocationController,
        ),
      ],
    );
  }

  Widget _buildCustomRecurrenceSection({
    required Color creatorColor,
    required String creatorLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Powtarzanie niestandardowe',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                IosDateFieldRow(
                  label: 'Początek',
                  value: _formatDate(_normalizedStartDate),
                  onTap: () => _openSingleDatePicker(
                    title: 'Data rozpoczęcia',
                    initial: _normalizedStartDate,
                    onPicked: (date) => setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(date)) {
                        _endDate = date;
                      }
                    }),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Powtarzaj co',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _StepperChip(
                        value: _customIntervalWeeks,
                        min: 1,
                        max: 12,
                        onChanged: (value) => setState(() {
                          _customIntervalWeeks = value;
                          _calendarSaved = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        child: const Text(
                          'tygodnie',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Powtarzaj w (opieka u $creatorLabel)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 7; i++)
                            _WeekdayChip(
                              label: customWeekDayLabels[i],
                              selected: _customWeekdays.contains(i + 1),
                              color: creatorColor,
                              onTap: () => _toggleCustomWeekday(i + 1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kończy się',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                RadioListTile<_CustomEndRule>(
                  value: _CustomEndRule.never,
                  groupValue: _customEndRule,
                  activeColor: creatorColor,
                  title: const Text('Nigdy'),
                  onChanged: (value) => setState(() {
                    _customEndRule = value!;
                    _calendarSaved = false;
                  }),
                ),
                RadioListTile<_CustomEndRule>(
                  value: _CustomEndRule.onDate,
                  groupValue: _customEndRule,
                  activeColor: creatorColor,
                  title: Row(
                    children: [
                      const Text('W dniu'),
                      const Spacer(),
                      TextButton(
                        onPressed: _customEndRule == _CustomEndRule.onDate
                            ? () => _openSingleDatePicker(
                                  title: 'Data końca',
                                  initial: _normalizedEndDate
                                          .isBefore(_normalizedStartDate)
                                      ? _normalizedStartDate
                                      : _normalizedEndDate,
                                  onPicked: (date) => setState(() {
                                    _endDate = date;
                                    _calendarSaved = false;
                                  }),
                                )
                            : null,
                        child: Text(_formatDate(_normalizedEndDate)),
                      ),
                    ],
                  ),
                  onChanged: (value) => setState(() {
                    _customEndRule = value!;
                    _calendarSaved = false;
                  }),
                ),
                RadioListTile<_CustomEndRule>(
                  value: _CustomEndRule.afterOccurrences,
                  groupValue: _customEndRule,
                  activeColor: creatorColor,
                  title: Row(
                    children: [
                      const Text('Po'),
                      const SizedBox(width: 8),
                      _StepperChip(
                        value: _customOccurrenceCount,
                        min: 1,
                        max: 999,
                        enabled:
                            _customEndRule == _CustomEndRule.afterOccurrences,
                        onChanged: (value) => setState(() {
                          _customOccurrenceCount = value;
                          _calendarSaved = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      const Text('wystąpieniach'),
                    ],
                  ),
                  onChanged: (value) => setState(() {
                    _customEndRule = value!;
                    _calendarSaved = false;
                  }),
                ),
              ],
            ),
          ),
        ),
        if (_customWeekdays.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            customWeekSummary(
              intervalWeeks: _customIntervalWeeks,
              weekdays: _customWeekdays,
              creatorLabel: creatorLabel,
            ),
            style: TextStyle(
              color: creatorColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? color : AppTheme.dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperChip extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _StepperChip({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: !enabled || value <= min
                  ? null
                  : () => onChanged(value - 1),
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: !enabled || value >= max
                  ? null
                  : () => onChanged(value + 1),
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final CustodySchedulePattern value;
  final CustodySchedulePattern groupValue;
  final Color accentColor;
  final ValueChanged<CustodySchedulePattern> onChanged;

  const _PatternOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? accentColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? accentColor : AppTheme.dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: RadioListTile<CustodySchedulePattern>(
              value: value,
              groupValue: groupValue,
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
              activeColor: accentColor,
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _scheduleErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.message) {
      case 'invalid_request':
        return 'Nieprawidłowe dane grafiku. Sprawdź datę startu i szablon.';
      case 'invalid_date_range':
        return 'Data końca musi być taka sama lub późniejsza niż data startu.';
      case 'schedule_not_allowed':
        return 'Nie masz uprawnień do zaproponowania grafiku.';
      case 'invalid_json':
      case 'invalid_response':
        return 'Błąd odpowiedzi serwera. Sprawdź, czy backend jest zaktualizowany.';
      default:
        if (error.statusCode >= 500) {
          return 'Błąd serwera (${error.statusCode}). Backend mógł nie dostać migracji bazy.';
        }
        return 'Nie udało się wysłać grafiku (${error.message}).';
    }
  }
  return 'Nie udało się wysłać grafiku: $error';
}

Future<bool?> showCustodyScheduleWizard(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (context) => const _CustodyScheduleWizardPage(),
    ),
  );
}

class _CustodyScheduleWizardPage extends StatelessWidget {
  const _CustodyScheduleWizardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Grafik opieki'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SafeArea(
        child: CustodyScheduleWizard(),
      ),
    );
  }
}
