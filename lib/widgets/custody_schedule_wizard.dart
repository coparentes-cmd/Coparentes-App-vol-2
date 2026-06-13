import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/api/app_api_client.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'booking_style_calendar_picker.dart';

class CustodyScheduleWizard extends StatefulWidget {
  const CustodyScheduleWizard({super.key});

  @override
  State<CustodyScheduleWizard> createState() => _CustodyScheduleWizardState();
}

class _CustodyScheduleWizardState extends State<CustodyScheduleWizard> {
  int _step = 0;
  CustodySchedulePattern _pattern = CustodySchedulePattern.weekAlternating;
  DateTime _startDate = DateTime.now();
  late DateTime _endDate;
  late final TextEditingController _handoverTimeController;
  late final TextEditingController _handoverLocationController;
  bool _isSubmitting = false;
  bool _calendarSaved = false;
  bool _calendarInteracted = false;
  int _rangeClickCount = 0;

  late Map<String, UserRole> _weekA;
  late Map<String, UserRole> _weekB;
  DateTime _calendarLeftMonth = DateTime.now();
  final Set<String> _selectedCustomDates = {};

  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
    _calendarLeftMonth = DateTime(_startDate.year, _startDate.month, 1);
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

  bool get _showsCalendar =>
      _step == 0 &&
      (_usesTemplateDateRange ||
          _pattern == CustodySchedulePattern.customWeek);

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
      _calendarInteracted = false;
      _rangeClickCount = 0;
      _selectedCustomDates.clear();
      _applyPatternPreset(pattern, creatorRole);
      if (_usesTemplateDateRange) {
        _startDate = DateTime.now();
        _endDate = DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
      }
      _calendarLeftMonth = DateTime(_startDate.year, _startDate.month, 1);
    });
  }

  void _updateRange(DateTime? start, DateTime? end) {
    setState(() {
      _calendarSaved = false;
      _rangeClickCount++;
      _calendarInteracted = _usesTemplateDateRange
          ? _rangeClickCount >= 2
          : true;
      if (start != null) {
        _startDate = start;
        _endDate = end ?? start;
      } else if (end != null) {
        _endDate = end;
      }
    });
  }

  void _updateSelectedDates(Set<String> dates) {
    setState(() {
      _calendarSaved = false;
      _calendarInteracted = true;
      _selectedCustomDates
        ..clear()
        ..addAll(dates);
    });
  }

  void _saveCalendarSelection() {
    if (!_applyCalendarIfReady()) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _usesTemplateDateRange
              ? 'Okres ${_formatDate(_normalizedStartDate)} – ${_formatDate(_normalizedEndDate)} zapisany. Kliknij „Dalej”.'
              : 'Zaznaczono ${_selectedCustomDates.length} dni. Kliknij „Dalej”.',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _applyCustomDatesToWeekPattern() {
    final creatorRole =
        context.read<AppProvider>().currentUser?.role ?? UserRole.parentA;
    final other = creatorRole == UserRole.parentA
        ? UserRole.parentB
        : UserRole.parentA;

    final sortedKeys = _selectedCustomDates.toList()..sort();
    final firstParts = sortedKeys.first.split('-');
    final start = DateTime(
      int.parse(firstParts[0]),
      int.parse(firstParts[1]),
      int.parse(firstParts[2]),
    );
    _startDate = start;

    _weekA = {for (final key in _dayKeys) key: other};
    _weekB = {for (final key in _dayKeys) key: other};

    for (final key in _selectedCustomDates) {
      final parts = key.split('-');
      if (parts.length != 3) {
        continue;
      }
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final weekIndex = bookingNormalizeDate(date).difference(start).inDays ~/ 7;
      final dayKey = _dayKeys[date.weekday - 1];
      if (weekIndex.isEven) {
        _weekA[dayKey] = creatorRole;
      } else {
        _weekB[dayKey] = creatorRole;
      }
    }
  }

  bool _isCalendarReady() {
    if (!_showsCalendar) {
      return true;
    }
    if (!_calendarInteracted) {
      return false;
    }
    if (_usesTemplateDateRange) {
      return !_normalizedEndDate.isBefore(_normalizedStartDate);
    }
    if (_pattern == CustodySchedulePattern.customWeek) {
      return _selectedCustomDates.isNotEmpty;
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
              'Wybierz datę początkową i końcową w kalendarzu (dwa kliknięcia).',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zaznacz co najmniej jeden dzień w kalendarzu.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }

    if (_pattern == CustodySchedulePattern.customWeek) {
      _applyCustomDatesToWeekPattern();
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

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Krok 1: Szablon, kalendarz i przekazanie';
      default:
        return 'Krok 2: Wyślij do akceptacji';
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
                _stepTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    0 => _buildPatternStep(
                        creatorColor: creatorColor,
                        creatorLabel: creatorLabel,
                      ),
                    _ => _buildSummaryStep(creatorLabel: creatorLabel),
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _isSubmitting ? null : () => setState(() => _step--),
                      child: const Text('Wstecz'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _onPrimaryAction,
                    child: Text(
                      _step == 0
                          ? 'Dalej — podsumowanie'
                          : (_isSubmitting
                              ? 'Wysyłam...'
                              : 'Wyślij do akceptacji'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleEnterKey() {
    if (_step == 0) {
      if (_applyCalendarIfReady()) {
        setState(() => _step = 1);
      }
      return;
    }
    _onPrimaryAction();
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
          subtitle: 'Zaznacz dni w kalendarzu — każdy dzień osobno',
          value: CustodySchedulePattern.customWeek,
          groupValue: _pattern,
          accentColor: creatorColor,
          onChanged: _selectPattern,
        ),
        if (_showsCalendar) ...[
          const SizedBox(height: 16),
          BookingStyleCalendarPicker(
            mode: _usesTemplateDateRange
                ? BookingCalendarMode.range
                : BookingCalendarMode.multiSelect,
            accentColor: AppTheme.accentColor,
            creatorLabel: creatorLabel,
            leftMonth: _calendarLeftMonth,
            rangeStart: _usesTemplateDateRange ? _normalizedStartDate : null,
            rangeEnd: _usesTemplateDateRange ? _normalizedEndDate : null,
            selectedDates: _selectedCustomDates,
            onLeftMonthChanged: (month) =>
                setState(() => _calendarLeftMonth = month),
            onRangeChanged: _updateRange,
            onSelectedDatesChanged: _updateSelectedDates,
            onConfirm: _saveCalendarSelection,
            colorForDay: _pattern == CustodySchedulePattern.customWeek
                ? (day) {
                    if (!_selectedCustomDates.contains(bookingDateKey(day))) {
                      return null;
                    }
                    final creatorRole = context
                            .read<AppProvider>()
                            .currentUser
                            ?.role ??
                        UserRole.parentA;
                    return creatorRole == UserRole.parentA
                        ? AppTheme.parentAColor
                        : AppTheme.parentBColor;
                  }
                : null,
          ),
          if (_calendarSaved) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: creatorColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  _usesTemplateDateRange
                      ? 'Okres zapisany'
                      : 'Zaznaczono ${_selectedCustomDates.length} dni',
                  style: TextStyle(
                    color: creatorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildSummaryStep({required String creatorLabel}) {
    final label = switch (_pattern) {
      CustodySchedulePattern.weekAlternating => 'Co tydzień na zmianę',
      CustodySchedulePattern.everyOtherWeekend => 'Co drugi weekend',
      CustodySchedulePattern.customWeek => 'Własny tydzień',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(label: 'Szablon', value: label),
        _SummaryRow(
          label: 'Start',
          value: _formatDate(_normalizedStartDate),
        ),
        if (_usesTemplateDateRange)
          _SummaryRow(
            label: 'Koniec',
            value: _formatDate(_normalizedEndDate),
          ),
        if (_pattern == CustodySchedulePattern.customWeek)
          _SummaryRow(
            label: 'Twoje dni',
            value: '${_selectedCustomDates.length}',
          ),
        _SummaryRow(
          label: 'Twórca',
          value: creatorLabel,
        ),
        _SummaryRow(
          label: 'Przekazanie',
          value: _handoverTimeController.text.trim().isEmpty
              ? '—'
              : _handoverTimeController.text.trim(),
        ),
        _SummaryRow(
          label: 'Miejsce',
          value: _handoverLocationController.text.trim().isEmpty
              ? '—'
              : _handoverLocationController.text.trim(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Drugi rodzic musi zaakceptować grafik, zanim zacznie obowiązywać. '
          'Po zatwierdzeniu każda kolejna zmiana wymaga ponownej akceptacji.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Future<void> _onPrimaryAction() async {
    if (_step == 0) {
      if (!_validateStep0()) {
        return;
      }
      setState(() => _step = 1);
      return;
    }

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
      final endDate = _usesTemplateDateRange ? _normalizedEndDate : null;

      if (app.isDemoMode) {
        final schedule = calendar.proposeScheduleDemo(
          proposedById: app.currentUser?.id ?? 'demo_user',
          patternType: _pattern,
          startDate: _normalizedStartDate,
          endDate: endDate,
          weekA: weekA,
          weekB: weekB,
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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
