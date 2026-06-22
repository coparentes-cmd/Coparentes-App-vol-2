import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/calendar_date_utils.dart';

const _maxVisibleEvents = 3;

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

int _monthIndex(DateTime from, DateTime to) {
  return (to.year - from.year) * 12 + (to.month - from.month);
}

DateTime _monthByIndex(DateTime firstMonth, int index) {
  return DateTime(firstMonth.year, firstMonth.month + index, 1);
}

/// Month grid styled like Google Calendar — day cells show event chips inline.
class GoogleStyleMonthCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Color accentColor;
  final List<CustodySlot> Function(DateTime day) getSlotsForDay;
  final List<CalendarEvent> Function(DateTime day) getEventsForDay;
  final bool Function(DateTime day)? isExceptionDay;
  final bool Function(DateTime day)? hasPendingException;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onTodayPressed;

  const GoogleStyleMonthCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.accentColor,
    required this.getSlotsForDay,
    required this.getEventsForDay,
    this.isExceptionDay,
    this.hasPendingException,
    required this.onDaySelected,
    this.onDayTap,
    this.onEventDoubleTap,
    required this.onMonthChanged,
    required this.onTodayPressed,
  });

  @override
  State<GoogleStyleMonthCalendar> createState() => _GoogleStyleMonthCalendarState();
}

class _GoogleStyleMonthCalendarState extends State<GoogleStyleMonthCalendar> {
  late final DateTime _firstMonth;
  late final DateTime _lastMonth;
  late final int _monthCount;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _firstMonth = _monthStart(
      DateTime.now().subtract(const Duration(days: 365)),
    );
    _lastMonth = _monthStart(
      DateTime.now().add(const Duration(days: 730)),
    );
    _monthCount = _monthIndex(_firstMonth, _lastMonth) + 1;
    _pageController = PageController(
      initialPage: _monthIndex(_firstMonth, _monthStart(widget.focusedDay)),
    );
  }

  @override
  void didUpdateWidget(GoogleStyleMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMonth = _monthStart(oldWidget.focusedDay);
    final newMonth = _monthStart(widget.focusedDay);
    if (oldMonth == newMonth || !_pageController.hasClients) {
      return;
    }

    final targetPage = _monthIndex(_firstMonth, newMonth);
    final currentPage = _pageController.page?.round();
    if (currentPage != targetPage) {
      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onVerticalPageChanged(int index) {
    final month = _monthByIndex(_firstMonth, index);
    final focusedMonth = _monthStart(widget.focusedDay);
    if (focusedMonth.year != month.year || focusedMonth.month != month.month) {
      widget.onMonthChanged(month);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthHeader(
          focusedDay: widget.focusedDay,
          onPrevious: () => widget.onMonthChanged(
            DateTime(widget.focusedDay.year, widget.focusedDay.month - 1, 1),
          ),
          onNext: () => widget.onMonthChanged(
            DateTime(widget.focusedDay.year, widget.focusedDay.month + 1, 1),
          ),
          onTodayPressed: widget.onTodayPressed,
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTheme.dividerColor),
                bottom: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onVerticalPageChanged,
              itemCount: _monthCount,
              itemBuilder: (context, index) {
                final month = _monthByIndex(_firstMonth, index);
                return _MonthGrid(
                  month: month,
                  selectedDay: widget.selectedDay,
                  accentColor: widget.accentColor,
                  getSlotsForDay: widget.getSlotsForDay,
                  getEventsForDay: widget.getEventsForDay,
                  isExceptionDay: widget.isExceptionDay,
                  hasPendingException: widget.hasPendingException,
                  onDaySelected: widget.onDaySelected,
                  onDayTap: widget.onDayTap,
                  onEventDoubleTap: widget.onEventDoubleTap,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final Color accentColor;
  final List<CustodySlot> Function(DateTime day) getSlotsForDay;
  final List<CalendarEvent> Function(DateTime day) getEventsForDay;
  final bool Function(DateTime day)? isExceptionDay;
  final bool Function(DateTime day)? hasPendingException;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;

  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.accentColor,
    required this.getSlotsForDay,
    required this.getEventsForDay,
    this.isExceptionDay,
    this.hasPendingException,
    required this.onDaySelected,
    this.onDayTap,
    this.onEventDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar<void>(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 730)),
      focusedDay: month,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      locale: 'pl_PL',
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.none,
      pageAnimationEnabled: false,
      sixWeekMonthsEnforced: true,
      daysOfWeekHeight: 30,
      rowHeight: 96,
      onDaySelected: (selected, focused) => onDaySelected(selected),
      headerVisible: false,
      calendarBuilders: CalendarBuilders<void>(
        defaultBuilder: (context, day, focused) => _DayCell(
          day: day,
          isToday: isSameDay(day, DateTime.now()),
          isSelected: isSameDay(day, selectedDay),
          isOutside: day.month != month.month,
          slots: getSlotsForDay(day),
          events: getEventsForDay(day),
          accentColor: accentColor,
          onDaySelected: onDaySelected,
          onDayTap: onDayTap,
          onEventDoubleTap: onEventDoubleTap,
          isException: isExceptionDay?.call(day) ?? false,
          hasPending: hasPendingException?.call(day) ?? false,
        ),
        todayBuilder: (context, day, focused) => _DayCell(
          day: day,
          isToday: true,
          isSelected: isSameDay(day, selectedDay),
          isOutside: day.month != month.month,
          slots: getSlotsForDay(day),
          events: getEventsForDay(day),
          accentColor: accentColor,
          onDaySelected: onDaySelected,
          onDayTap: onDayTap,
          onEventDoubleTap: onEventDoubleTap,
          isException: isExceptionDay?.call(day) ?? false,
          hasPending: hasPendingException?.call(day) ?? false,
        ),
        selectedBuilder: (context, day, focused) => _DayCell(
          day: day,
          isToday: isSameDay(day, DateTime.now()),
          isSelected: true,
          isOutside: day.month != month.month,
          slots: getSlotsForDay(day),
          events: getEventsForDay(day),
          accentColor: accentColor,
          onDaySelected: onDaySelected,
          onDayTap: onDayTap,
          onEventDoubleTap: onEventDoubleTap,
          isException: isExceptionDay?.call(day) ?? false,
          hasPending: hasPendingException?.call(day) ?? false,
        ),
        outsideBuilder: (context, day, focused) => _DayCell(
          day: day,
          isToday: isSameDay(day, DateTime.now()),
          isSelected: isSameDay(day, selectedDay),
          isOutside: true,
          slots: getSlotsForDay(day),
          events: getEventsForDay(day),
          accentColor: accentColor,
          onDaySelected: onDaySelected,
          onDayTap: onDayTap,
          onEventDoubleTap: onEventDoubleTap,
          isException: isExceptionDay?.call(day) ?? false,
          hasPending: hasPendingException?.call(day) ?? false,
        ),
      ),
      calendarStyle: CalendarStyle(
        cellMargin: EdgeInsets.zero,
        cellPadding: EdgeInsets.zero,
        tablePadding: EdgeInsets.zero,
        tableBorder: const TableBorder(
          horizontalInside: BorderSide(color: AppTheme.dividerColor, width: 0.5),
          verticalInside: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
        outsideDaysVisible: true,
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
        weekendStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTodayPressed;

  const _MonthHeader({
    required this.focusedDay,
    required this.onPrevious,
    required this.onNext,
    required this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: 'Poprzedni miesiąc',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              _formatMonthYear(focusedDay),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Następny miesiąc',
            onPressed: onNext,
          ),
          TextButton(
            onPressed: onTodayPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'Dziś',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'styczeń',
      'luty',
      'marzec',
      'kwiecień',
      'maj',
      'czerwiec',
      'lipiec',
      'sierpień',
      'wrzesień',
      'październik',
      'listopad',
      'grudzień',
    ];
    final name = months[date.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final List<CustodySlot> slots;
  final List<CalendarEvent> events;
  final Color accentColor;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;
  final bool isException;
  final bool hasPending;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isOutside,
    required this.slots,
    required this.events,
    required this.accentColor,
    required this.onDaySelected,
    this.onDayTap,
    this.onEventDoubleTap,
    this.isException = false,
    this.hasPending = false,
  });

  void _handleDayTap() {
    onDaySelected(day);
    onDayTap?.call(day);
  }

  @override
  Widget build(BuildContext context) {
    final custodyColor = _custodyColor();
    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    final visibleEvents = sortedEvents.take(_maxVisibleEvents).toList();
    final hiddenCount = sortedEvents.length - visibleEvents.length;

    return GestureDetector(
      onTap: _handleDayTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: _cellBackground(custodyColor),
        border: isSelected
            ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.55), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isException)
                    Padding(
                      padding: const EdgeInsets.only(right: 2, top: 1),
                      child: Icon(
                        Icons.star,
                        size: 10,
                        color: isOutside
                            ? AppTheme.textHint
                            : AppTheme.warningColor,
                      ),
                    ),
                  if (hasPending)
                    Padding(
                      padding: const EdgeInsets.only(right: 2, top: 1),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOutside
                              ? AppTheme.textHint
                              : AppTheme.warningColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  _DayNumber(
                    day: day.day,
                    isToday: isToday,
                    isOutside: isOutside,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...visibleEvents.map(
                    (event) => _EventChip(
                      event: event,
                      onDoubleTap: onEventDoubleTap == null
                          ? null
                          : () => onEventDoubleTap!(event),
                    ),
                  ),
                  if (hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 1),
                      child: Text(
                        '+$hiddenCount więcej',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOutside
                              ? AppTheme.textHint
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Color? _custodyColor() {
    if (slots.isEmpty) {
      return null;
    }
    return slots.first.custodian == UserRole.parentA
        ? AppTheme.parentAColor
        : AppTheme.parentBColor;
  }

  Color _cellBackground(Color? custodyColor) {
    if (custodyColor == null) {
      return Colors.white;
    }

    final isParentA = slots.first.custodian == UserRole.parentA;
    final baseTint = isParentA
        ? AppTheme.parentAColor.withValues(alpha: isOutside ? 0.10 : 0.16)
        : AppTheme.parentBColor.withValues(alpha: isOutside ? 0.10 : 0.16);

    if (isSelected) {
      return Color.alphaBlend(
        AppTheme.accentColor.withValues(alpha: 0.10),
        baseTint,
      );
    }

    return baseTint;
  }
}

class _DayNumber extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isOutside;

  const _DayNumber({
    required this.day,
    required this.isToday,
    required this.isOutside,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isOutside
        ? AppTheme.textHint
        : (isToday ? Colors.white : AppTheme.textPrimary);

    Widget child = Text(
      '$day',
      style: TextStyle(
        fontSize: 12,
        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
        color: textColor,
      ),
    );

    if (isToday) {
      child = Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppTheme.accentColor,
          shape: BoxShape.circle,
        ),
        child: child,
      );
    }

    return child;
  }
}

class _EventChip extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onDoubleTap;

  const _EventChip({
    required this.event,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: event.typeColor,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          _label(event),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _label(CalendarEvent event) {
    final timePrefix = formatEventTimeLabel(event.startDate);
    if (timePrefix == null) {
      return event.title;
    }
    return '$timePrefix ${event.title}';
  }
}
