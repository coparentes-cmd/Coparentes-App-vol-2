import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'booking_style_calendar_picker.dart';

/// Result of a mini-calendar sheet (range or multi-select).
class MiniCalendarResult {
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Set<String> selectedDates;

  const MiniCalendarResult({
    this.rangeStart,
    this.rangeEnd,
    this.selectedDates = const {},
  });
}

/// iOS / booking-style row: tap opens [showMiniCalendarSheet].
class IosDateFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;

  const IosDateFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.white70 : AppTheme.textSecondary;
    final valueColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: labelColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a compact single-month calendar bottom sheet.
Future<MiniCalendarResult?> showMiniCalendarSheet({
  required BuildContext context,
  required BookingCalendarMode mode,
  required Color accentColor,
  String title = 'Wybierz daty',
  String? subtitle,
  DateTime? initialMonth,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  Set<String> selectedDates = const {},
  Color? Function(DateTime day)? colorForDay,
}) {
  return showModalBottomSheet<MiniCalendarResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 420),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return _MiniCalendarSheet(
        mode: mode,
        accentColor: accentColor,
        title: title,
        subtitle: subtitle,
        initialMonth: initialMonth ?? rangeStart ?? DateTime.now(),
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        selectedDates: selectedDates,
        colorForDay: colorForDay,
      );
    },
  );
}

class _MiniCalendarSheet extends StatefulWidget {
  final BookingCalendarMode mode;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final DateTime initialMonth;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Set<String> selectedDates;
  final Color? Function(DateTime day)? colorForDay;

  const _MiniCalendarSheet({
    required this.mode,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.initialMonth,
    required this.rangeStart,
    required this.rangeEnd,
    required this.selectedDates,
    this.colorForDay,
  });

  @override
  State<_MiniCalendarSheet> createState() => _MiniCalendarSheetState();
}

class _MiniCalendarSheetState extends State<_MiniCalendarSheet> {
  static const _weekdayLabels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

  late final DateFormat _monthTitleFormat = DateFormat('LLLL yyyy', 'pl_PL');
  late DateTime _month;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late Set<String> _selectedDates;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialMonth;
    _month = DateTime(seed.year, seed.month, 1);
    _rangeStart = widget.rangeStart == null
        ? null
        : bookingNormalizeDate(widget.rangeStart!);
    _rangeEnd = widget.rangeEnd == null
        ? null
        : bookingNormalizeDate(widget.rangeEnd!);
    _selectedDates = Set<String>.from(widget.selectedDates);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  void _handleDayTap(DateTime day) {
    final normalized = bookingNormalizeDate(day);
    if (widget.mode == BookingCalendarMode.range) {
      setState(() {
        if (_rangeStart == null || _rangeEnd != null) {
          _rangeStart = normalized;
          _rangeEnd = null;
        } else if (normalized.isBefore(_rangeStart!)) {
          _rangeEnd = _rangeStart;
          _rangeStart = normalized;
        } else {
          _rangeEnd = normalized;
        }
      });
      return;
    }

    final key = bookingDateKey(normalized);
    setState(() {
      if (_selectedDates.contains(key)) {
        _selectedDates.remove(key);
      } else {
        _selectedDates.add(key);
      }
    });
  }

  bool _canConfirm() {
    if (widget.mode == BookingCalendarMode.range) {
      // Start alone is enough (end defaults to start on confirm).
      return _rangeStart != null;
    }
    return _selectedDates.isNotEmpty;
  }

  void _confirm() {
    if (!_canConfirm()) {
      return;
    }
    final start = _rangeStart;
    final end = _rangeEnd ?? _rangeStart;
    Navigator.pop(
      context,
      MiniCalendarResult(
        rangeStart: start,
        rangeEnd: end,
        selectedDates: Set<String>.from(_selectedDates),
      ),
    );
  }

  bool _isRangeStart(DateTime day) =>
      _rangeStart != null &&
      bookingNormalizeDate(day) == bookingNormalizeDate(_rangeStart!);

  bool _isRangeEnd(DateTime day) =>
      _rangeEnd != null &&
      bookingNormalizeDate(day) == bookingNormalizeDate(_rangeEnd!);

  bool _isInRange(DateTime day) {
    if (_rangeStart == null || _rangeEnd == null) {
      return false;
    }
    final normalized = bookingNormalizeDate(day);
    return !normalized.isBefore(_rangeStart!) &&
        !normalized.isAfter(_rangeEnd!);
  }

  bool _isSelected(DateTime day) {
    if (widget.mode == BookingCalendarMode.multiSelect) {
      return _selectedDates.contains(bookingDateKey(day));
    }
    return _isRangeStart(day) || _isRangeEnd(day);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final title = _capitalize(_monthTitleFormat.format(_month));

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Row(
                children: _weekdayLabels
                    .map(
                      (label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              ..._buildWeekRows(),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Anuluj'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canConfirm() ? _confirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          widget.accentColor.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      minimumSize: const Size(120, 40),
                    ),
                    child: const Text('Zatwierdź'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWeekRows() {
    final cells = _daysInMonthGrid(_month);
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (index) {
              final day = cells[i + index];
              return Expanded(child: _buildDayCell(day));
            }),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildDayCell(DateTime? day) {
    if (day == null || day.month != _month.month) {
      return const SizedBox(height: 40);
    }

    final selected = _isSelected(day);
    final inRange =
        widget.mode == BookingCalendarMode.range && _isInRange(day);
    final isEndpoint = _isRangeStart(day) || _isRangeEnd(day);
    final isToday =
        bookingNormalizeDate(day) == bookingNormalizeDate(DateTime.now());

    Color? background;
    Color textColor = AppTheme.textPrimary;
    BorderRadius radius = BorderRadius.circular(8);

    if (widget.mode == BookingCalendarMode.range && inRange && !isEndpoint) {
      background = widget.accentColor.withValues(alpha: 0.14);
      radius = BorderRadius.zero;
    }

    if (selected || isEndpoint) {
      background = widget.colorForDay?.call(day) ?? widget.accentColor;
      textColor = Colors.white;
      radius = BorderRadius.circular(8);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleDayTap(day),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: isToday && !selected
                ? Border.all(color: widget.accentColor, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  List<DateTime?> _daysInMonthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = <DateTime?>[];

    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
