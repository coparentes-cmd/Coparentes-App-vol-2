import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/calendar_provider.dart';
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
  late final TextEditingController _handoverTimeController;
  late final TextEditingController _handoverLocationController;
  bool _isSubmitting = false;

  late Map<String, UserRole> _weekA;
  late Map<String, UserRole> _weekB;

  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const _dayLabels = [
    'Pon',
    'Wt',
    'Śr',
    'Czw',
    'Pt',
    'Sob',
    'Nd',
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _step == 0
                ? 'Krok 1: Wybierz szablon'
                : _step == 1
                    ? 'Krok 2: Start i przekazanie'
                    : 'Krok 3: Podsumowanie',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_step == 0) _buildPatternStep(),
          if (_step == 1) _buildDetailsStep(),
          if (_step == 2) _buildSummaryStep(),
          const SizedBox(height: 20),
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
      children: [
        _PatternTile(
          title: 'Co tydzień na zmianę',
          subtitle: 'Cały tydzień u jednego rodzica, potem u drugiego',
          selected: _pattern == CustodySchedulePattern.weekAlternating,
          onTap: () => setState(() {
            _pattern = CustodySchedulePattern.weekAlternating;
            _applyPatternPreset(_pattern);
          }),
        ),
        _PatternTile(
          title: 'Co drugi weekend',
          subtitle: 'Tygodnie robocze i weekendy na zmianę',
          selected: _pattern == CustodySchedulePattern.everyOtherWeekend,
          onTap: () => setState(() {
            _pattern = CustodySchedulePattern.everyOtherWeekend;
            _applyPatternPreset(_pattern);
          }),
        ),
        _PatternTile(
          title: 'Własny tydzień',
          subtitle: 'Ustaw każdy dzień tygodnia A i B ręcznie',
          selected: _pattern == CustodySchedulePattern.customWeek,
          onTap: () => setState(() {
            _pattern = CustodySchedulePattern.customWeek;
            _applyPatternPreset(_pattern);
          }),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data startu grafiku'),
          subtitle: Text(
            '${_startDate.day}.${_startDate.month}.${_startDate.year}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _startDate = picked);
            }
          },
        ),
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
        if (_pattern == CustodySchedulePattern.customWeek) ...[
          const SizedBox(height: 16),
          const Text(
            'Tydzień A / Tydzień B',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _WeekGrid(
            weekA: _weekA,
            weekB: _weekB,
            onChanged: (weekA, weekB) => setState(() {
              _weekA = weekA;
              _weekB = weekB;
            }),
          ),
        ],
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
          value: '${_startDate.day}.${_startDate.month}.${_startDate.year}',
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
          'Drugi rodzic musi zaakceptować grafik, zanim zacznie obowiązywać.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Future<void> _onPrimaryAction() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<CalendarProvider>().proposeSchedule(
            patternType: _pattern,
            startDate: _startDate,
            weekA: CustodyWeekPattern(_weekA),
            weekB: CustodyWeekPattern(_weekB),
            handoverTime: _handoverTimeController.text.trim().isEmpty
                ? null
                : _handoverTimeController.text.trim(),
            handoverLocation: _handoverLocationController.text.trim().isEmpty
                ? null
                : _handoverLocationController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wysłać grafiku: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _PatternTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PatternTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppTheme.accentColor : AppTheme.dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppTheme.accentColor)
            : null,
        onTap: onTap,
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

class _WeekGrid extends StatelessWidget {
  final Map<String, UserRole> weekA;
  final Map<String, UserRole> weekB;
  final void Function(Map<String, UserRole> weekA, Map<String, UserRole> weekB)
      onChanged;

  const _WeekGrid({
    required this.weekA,
    required this.weekB,
    required this.onChanged,
  });

  static const _keys = _CustodyScheduleWizardState._dayKeys;
  static const _labels = _CustodyScheduleWizardState._dayLabels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_keys.length, (index) {
        final key = _keys[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(_labels[index]),
              ),
              Expanded(
                child: _RoleToggle(
                  label: 'Tydz. A',
                  role: weekA[key] ?? UserRole.parentA,
                  onChanged: (role) {
                    final nextA = Map<String, UserRole>.from(weekA);
                    nextA[key] = role;
                    onChanged(nextA, weekB);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleToggle(
                  label: 'Tydz. B',
                  role: weekB[key] ?? UserRole.parentB,
                  onChanged: (role) {
                    final nextB = Map<String, UserRole>.from(weekB);
                    nextB[key] = role;
                    onChanged(weekA, nextB);
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final String label;
  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  const _RoleToggle({
    required this.label,
    required this.role,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isA = role == UserRole.parentA;
    return OutlinedButton(
      onPressed: () => onChanged(isA ? UserRole.parentB : UserRole.parentA),
      style: OutlinedButton.styleFrom(
        foregroundColor: isA ? AppTheme.parentAColor : AppTheme.parentBColor,
        side: BorderSide(
          color: isA ? AppTheme.parentAColor : AppTheme.parentBColor,
        ),
      ),
      child: Text(isA ? 'Mama' : 'Tata'),
    );
  }
}

Future<bool?> showCustodyScheduleWizard(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const CustodyScheduleWizard(),
  );
}
