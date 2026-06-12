import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  void _selectPattern(CustodySchedulePattern pattern) {
    setState(() {
      _pattern = pattern;
      _applyPatternPreset(pattern);
    });
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
          subtitle: 'Ustaw każdy dzień tygodnia A i B ręcznie',
          value: CustodySchedulePattern.customWeek,
          groupValue: _pattern,
          onChanged: _selectPattern,
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

      if (app.isDemoMode) {
        calendar.proposeScheduleDemo(
          proposedById: app.currentUser?.id ?? 'demo_user',
          patternType: _pattern,
          startDate: _startDate,
          weekA: weekA,
          weekB: weekB,
          handoverTime: handoverTime,
          handoverLocation: handoverLocation,
        );
      } else {
        await calendar.proposeSchedule(
          patternType: _pattern,
          startDate: _startDate,
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
  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  const _RoleToggle({
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

String _scheduleErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.message) {
      case 'invalid_request':
        return 'Nieprawidłowe dane grafiku. Sprawdź datę startu i szablon.';
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
