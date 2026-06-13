import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

enum BookingCalendarMode { range, multiSelect }

String bookingDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime bookingNormalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class BookingStyleCalendarPicker extends StatefulWidget {
  final BookingCalendarMode mode;
  final Color accentColor;
  final String creatorLabel;
  final DateTime leftMonth;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Set<String> selectedDates;
  final ValueChanged<DateTime> onLeftMonthChanged;
  final void Function(DateTime? start, DateTime? end) onRangeChanged;
  final ValueChanged<Set<String>> onSelectedDatesChanged;
  final VoidCallback? onConfirm;
  final Color? Function(DateTime day)? colorForDay;

  const BookingStyleCalendarPicker({
    super.key,
    required this.mode,
    required this.accentColor,
    required this.creatorLabel,
    required this.leftMonth,
    required this.rangeStart,
    required this.rangeEnd,
    required this.selectedDates,
    required this.onLeftMonthChanged,
    required this.onRangeChanged,
    required this.onSelectedDatesChanged,
    this.onConfirm,
    this.colorForDay,
  });

  @override
  State<BookingStyleCalendarPicker> createState() =>
      _BookingStyleCalendarPickerState();
}

class _BookingStyleCalendarPickerState extends State<BookingStyleCalendarPicker> {
  static const _weekdayLabels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

  late final DateFormat _monthTitleFormat =
      DateFormat('LLLL yyyy', 'pl_PL');

  DateTime get _secondMonth =>
      DateTime(widget.leftMonth.year, widget.leftMonth.month + 1, 1);

  void _shiftMonths(int delta) {
    final next = DateTime(
      widget.leftMonth.year,
      widget.leftMonth.month + delta,
      1,
    );
    widget.onLeftMonthChanged(next);
  }

  void _handleDayTap(DateTime day) {
    if (widget.mode == BookingCalendarMode.range) {
      _handleRangeTap(day);
    } else {
      _handleMultiSelectTap(day);
    }
  }

  void _handleRangeTap(DateTime day) {
    final normalized = bookingNormalizeDate(day);
    final start = widget.rangeStart == null
        ? null
        : bookingNormalizeDate(widget.rangeStart!);
    final end = widget.rangeEnd == null
        ? null
        : bookingNormalizeDate(widget.rangeEnd!);

    if (start == null || end != null) {
      widget.onRangeChanged(normalized, null);
      return;
    }

    if (normalized.isBefore(start)) {
      widget.onRangeChanged(normalized, start);
    } else {
      widget.onRangeChanged(start, normalized);
    }
  }

  void _handleMultiSelectTap(DateTime day) {
    final key = bookingDateKey(day);
    final next = Set<String>.from(widget.selectedDates);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    widget.onSelectedDatesChanged(next);
  }

  bool _isRangeStart(DateTime day) {
    final start = widget.rangeStart;
    return start != null && bookingNormalizeDate(start) == bookingNormalizeDate(day);
  }

  bool _isRangeEnd(DateTime day) {
    final end = widget.rangeEnd;
    return end != null && bookingNormalizeDate(end) == bookingNormalizeDate(day);
  }

  bool _isInRange(DateTime day) {
    final start = widget.rangeStart;
    final end = widget.rangeEnd;
    if (start == null || end == null) {
      return false;
    }
    final normalized = bookingNormalizeDate(day);
    final from = bookingNormalizeDate(start);
    final to = bookingNormalizeDate(end);
    return !normalized.isBefore(from) && !normalized.isAfter(to);
  }

  bool _isSelected(DateTime day) {
    if (widget.mode == BookingCalendarMode.multiSelect) {
      return widget.selectedDates.contains(bookingDateKey(day));
    }
    return _isRangeStart(day) || _isRangeEnd(day);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter): () => widget.onConfirm?.call(),
      },
      child: Focus(
        autofocus: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: widget.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.mode == BookingCalendarMode.range
                          ? 'Wybierz okres obowiązywania'
                          : 'Zaznacz dni opieki (${widget.creatorLabel})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.mode == BookingCalendarMode.range
                    ? 'Kliknij datę początkową i końcową. Enter — zapisz.'
                    : 'Kliknij dni pojedynczo. Enter — zapisz zaznaczenie.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (widget.mode == BookingCalendarMode.multiSelect) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    _LegendChip(color: AppTheme.parentAColor, label: 'Mama'),
                    SizedBox(width: 12),
                    _LegendChip(color: AppTheme.parentBColor, label: 'Tata'),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 520;
                  if (sideBySide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildMonth(
                            widget.leftMonth,
                            showPrev: true,
                            showNext: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMonth(
                            _secondMonth,
                            showPrev: false,
                            showNext: true,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildMonth(widget.leftMonth, showPrev: true, showNext: false),
                      const SizedBox(height: 16),
                      _buildMonth(_secondMonth, showPrev: false, showNext: true),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onConfirm,
                  icon: Icon(Icons.check, size: 18, color: widget.accentColor),
                  label: Text(
                    'Zapisz (Enter)',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w600,
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

  Widget _buildMonth(DateTime month, {required bool showPrev, required bool showNext}) {
    final title = _capitalize(_monthTitleFormat.format(month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showPrev)
              _NavButton(
                icon: Icons.chevron_left,
                onPressed: () => _shiftMonths(-1),
              )
            else
              const SizedBox(width: 36),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (showNext)
              _NavButton(
                icon: Icons.chevron_right,
                onPressed: () => _shiftMonths(1),
              )
            else
              const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 8),
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
        ..._buildWeekRows(month),
      ],
    );
  }

  List<Widget> _buildWeekRows(DateTime month) {
    final cells = _daysInMonthGrid(month);
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (index) {
              final day = cells[i + index];
              return Expanded(child: _buildDayCell(day, month));
            }),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildDayCell(DateTime? day, DateTime month) {
    if (day == null) {
      return const SizedBox(height: 40);
    }

    final isOutside = day.month != month.month;
    if (isOutside) {
      return const SizedBox(height: 40);
    }

    final selected = _isSelected(day);
    final inRange = widget.mode == BookingCalendarMode.range && _isInRange(day);
    final isEndpoint = _isRangeStart(day) || _isRangeEnd(day);
    final isToday = bookingNormalizeDate(day) ==
        bookingNormalizeDate(DateTime.now());

    Color? background;
    Color textColor = AppTheme.textPrimary;
    BorderRadius? radius;

    if (widget.mode == BookingCalendarMode.range && inRange && !isEndpoint) {
      background = widget.accentColor.withValues(alpha: 0.14);
      radius = BorderRadius.zero;
    }

    if (selected || isEndpoint) {
      final fill = widget.colorForDay?.call(day) ??
          (widget.mode == BookingCalendarMode.multiSelect
              ? widget.accentColor
              : widget.accentColor);
      background = fill;
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
            borderRadius: radius ?? BorderRadius.circular(8),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: AppTheme.textPrimary),
      onPressed: onPressed,
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
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
