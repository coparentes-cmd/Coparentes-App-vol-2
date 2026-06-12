import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/api/app_api_client.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

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

  late Map<String, UserRole> _weekA;
  late Map<String, UserRole> _weekB;
  DateTime _calendarFocusedDay = DateTime.now();

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
    _handoverTimeController = TextEditingController(text: '17:00');
    _handoverLocationController = TextEditingController(text: 'Szkoła');
    _applyPatternPreset(_pattern);
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

  DateTime get _normalizedStartDate =>
      DateTime(_startDate.year, _startDate.month, _startDate.day);

  DateTime get _normalizedEndDate =>
      DateTime(_endDate.year, _endDate.month, _endDate.day);

  String _formatDate(DateTime date) =>
      '${date.day}.${date.month}.${date.year}';

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _selectPattern(CustodySchedulePattern pattern) {
    setState(() {
      _pattern = pattern;
      _applyPatternPreset(pattern);
    });
  }

  void _updateStartDate(DateTime value) {
    setState(() {
      _startDate = value;
      if (_normalizedEndDate.isBefore(_normalizedStartDate)) {
        _endDate = DateTime(value.year + 1, value.month, value.day);
      }
    });
  }

  void _updateEndDate(DateTime value) {
    setState(() => _endDate = value);
  }

  bool _validateTemplateDateRange() {
    if (!_usesTemplateDateRange) {
      return true;
    }
    if (_normalizedEndDate.isBefore(_normalizedStartDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data końca musi być taka sama lub późniejsza niż start.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return false;
    }
    return true;
  }

  void _applyPatternPreset(CustodySchedulePattern pattern) {
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
        _weekA = {for (final key in _dayKeys) key: UserRole.parentA};
        _weekB = {for (final key in _dayKeys) key: UserRole.parentB};
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Krok 1: Wybierz szablon';
      case 1:
        return 'Krok 2: Start i przekazanie';
      default:
        return 'Krok 3: Podsumowanie';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                0 => _buildPatternStep(),
                1 => _buildDetailsStep(),
                _ => _buildSummaryStep(),
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
                  _step < 2
                      ? 'Dalej'
                      : (_isSubmitting ? 'Wysyłam...' : 'Wyślij do akceptacji'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PatternOption(
          title: 'Co tydzień na zmianę',
          subtitle: 'Cały tydzień u jednego rodzica, potem u drugiego',
          value: CustodySchedulePattern.weekAlternating,
          groupValue: _pattern,
          onChanged: _selectPattern,
        ),
        _PatternOption(
          title: 'Co drugi weekend',
          subtitle: 'Tygodnie robocze i weekendy na zmianę',
          value: CustodySchedulePattern.everyOtherWeekend,
          groupValue: _pattern,
          onChanged: _selectPattern,
        ),
        _PatternOption(
          title: 'Własny tydzień',
          subtitle: 'Zaznacz dni w kalendarzu — tapnięcie zmienia opiekuna',
          value: CustodySchedulePattern.customWeek,
          groupValue: _pattern,
          onChanged: _selectPattern,
        ),
        if (_pattern == CustodySchedulePattern.customWeek) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data startu grafiku'),
            subtitle: Text(_formatDate(_normalizedStartDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _normalizedStartDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              onSelected: _updateStartDate,
            ),
          ),
          const SizedBox(height: 8),
          _CustomWeekCalendarPicker(
            startDate: _normalizedStartDate,
            focusedDay: _calendarFocusedDay,
            weekA: _weekA,
            weekB: _weekB,
            onFocusedDayChanged: (day) =>
                setState(() => _calendarFocusedDay = day),
            onChanged: (weekA, weekB) => setState(() {
              _weekA = weekA;
              _weekB = weekB;
            }),
          ),
        ],
        if (_usesTemplateDateRange) ...[
          const SizedBox(height: 8),
          const Text(
            'Okres obowiązywania szablonu',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data początkowa'),
            subtitle: Text(_formatDate(_normalizedStartDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _normalizedStartDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              onSelected: _updateStartDate,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data końcowa'),
            subtitle: Text(_formatDate(_normalizedEndDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _normalizedEndDate,
              firstDate: _normalizedStartDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              onSelected: _updateEndDate,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildSummaryStep() {
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
    if (_step < 2) {
      if (_step == 0 && !_validateTemplateDateRange()) {
        return;
      }
      setState(() => _step++);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final app = context.read<AppProvider>();
      final calendar = context.read<CalendarProvider>();
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
        calendar.proposeScheduleDemo(
          proposedById: app.currentUser?.id ?? 'demo_user',
          patternType: _pattern,
          startDate: _normalizedStartDate,
          endDate: endDate,
          weekA: weekA,
          weekB: weekB,
          handoverTime: handoverTime,
          handoverLocation: handoverLocation,
        );
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
  final ValueChanged<CustodySchedulePattern> onChanged;

  const _PatternOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.accentColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.accentColor : AppTheme.dividerColor,
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
              activeColor: AppTheme.accentColor,
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

class _CustomWeekCalendarPicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime focusedDay;
  final Map<String, UserRole> weekA;
  final Map<String, UserRole> weekB;
  final ValueChanged<DateTime> onFocusedDayChanged;
  final void Function(Map<String, UserRole> weekA, Map<String, UserRole> weekB)
      onChanged;

  const _CustomWeekCalendarPicker({
    required this.startDate,
    required this.focusedDay,
    required this.weekA,
    required this.weekB,
    required this.onFocusedDayChanged,
    required this.onChanged,
  });

  static const _keys = _CustodyScheduleWizardState._dayKeys;

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static int _weekIndex(DateTime start, DateTime day) {
    return _normalize(day).difference(_normalize(start)).inDays ~/ 7;
  }

  static String _dayKey(DateTime day) => _keys[day.weekday - 1];

  UserRole _custodianForDay(DateTime day) {
    final map = _weekIndex(startDate, day).isEven ? weekA : weekB;
    return map[_dayKey(day)] ?? UserRole.parentA;
  }

  void _toggleDay(DateTime day) {
    final key = _dayKey(day);
    final isWeekA = _weekIndex(startDate, day).isEven;
    if (isWeekA) {
      final nextA = Map<String, UserRole>.from(weekA);
      final current = nextA[key] ?? UserRole.parentA;
      nextA[key] = current == UserRole.parentA
          ? UserRole.parentB
          : UserRole.parentA;
      onChanged(nextA, weekB);
    } else {
      final nextB = Map<String, UserRole>.from(weekB);
      final current = nextB[key] ?? UserRole.parentB;
      nextB[key] = current == UserRole.parentA
          ? UserRole.parentB
          : UserRole.parentA;
      onChanged(weekA, nextB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kliknij dzień, aby przełączyć opiekuna (Mama / Tata). '
          'Kolory pokazują tygodnie A i B na przemian od daty startu.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendChip(
              color: AppTheme.parentAColor,
              label: 'Mama',
            ),
            const SizedBox(width: 12),
            _LegendChip(
              color: AppTheme.parentBColor,
              label: 'Tata',
            ),
          ],
        ),
        const SizedBox(height: 12),
        TableCalendar<void>(
          firstDay: DateTime.now().subtract(const Duration(days: 30)),
          lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
          focusedDay: focusedDay,
          locale: 'pl_PL',
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
          ),
          onPageChanged: onFocusedDayChanged,
          onDaySelected: (selected, focused) {
            onFocusedDayChanged(focused);
            _toggleDay(selected);
          },
          calendarBuilders: CalendarBuilders<void>(
            defaultBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, role: _custodianForDay(day)),
            todayBuilder: (context, day, _) => _CalendarDayCell(
              day: day,
              role: _custodianForDay(day),
              isToday: true,
            ),
            outsideBuilder: (context, day, _) => _CalendarDayCell(
              day: day,
              role: _custodianForDay(day),
              isOutside: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final UserRole role;
  final bool isToday;
  final bool isOutside;

  const _CalendarDayCell({
    required this.day,
    required this.role,
    this.isToday = false,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    final isA = role == UserRole.parentA;
    final color = isA ? AppTheme.parentAColor : AppTheme.parentBColor;
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isOutside ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: AppTheme.accentColor, width: 2)
            : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isOutside ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            isA ? 'Mama' : 'Tata',
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
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
