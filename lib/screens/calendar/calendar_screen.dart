import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/api/app_api_client.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/calendar_date_utils.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/parent_tab_scaffold.dart';
import '../../widgets/google_style_month_calendar.dart';
import '../../widgets/custody_schedule_wizard.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime? focusDay;
  final int focusRequestId;

  const CalendarScreen({
    super.key,
    this.focusDay,
    this.focusRequestId = 0,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late TabController _tabController;
  Timer? _liveRefreshTimer;

  static const _liveRefreshInterval = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.focusDay != null) {
      _jumpToDay(widget.focusDay!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLiveRefresh());
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusRequestId != oldWidget.focusRequestId &&
        widget.focusDay != null) {
      _jumpToDay(widget.focusDay!);
    }
  }

  void _jumpToDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _focusedDay = normalized;
      _selectedDay = normalized;
    });
  }

  void _startLiveRefresh() {
    if (!mounted) {
      return;
    }

    final isDemo = context.read<AppProvider>().isDemoMode;
    if (isDemo) {
      return;
    }

    unawaited(context.read<CalendarProvider>().load(silent: true));

    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(_liveRefreshInterval, (_) {
      if (!mounted) {
        return;
      }
      if (context.read<AppProvider>().isDemoMode) {
        return;
      }
      context.read<CalendarProvider>().load(silent: true);
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final isChild = user?.role == UserRole.child;
    final isReadOnly =
        user?.role == UserRole.observer || user?.role == UserRole.child;
    final roleColor = switch (user?.role) {
      UserRole.parentA => AppTheme.parentAColor,
      UserRole.parentB => AppTheme.parentBColor,
      UserRole.child => AppTheme.childColor,
      _ => AppTheme.primaryTeal,
    };

    final pendingRequests = calendar.pendingRequestCount;
    final hasActiveSchedule = calendar.hasActiveSchedule;

    if (isChild) {
      return ParentTabScaffold(
        title: 'Kalendarz opieki',
        body: _buildCalendarTab(
          context,
          calendar,
          roleColor,
          isReadOnly,
          user?.id,
        ),
      );
    }

    return ParentTabScaffold(
      title: 'Kalendarz opieki',
      actions: isReadOnly
          ? null
          : [
              ParentHeaderActionButton(
                label: hasActiveSchedule ? 'Zmiana grafiku' : 'Grafik opieki',
                icon: Icons.view_week,
                backgroundColor: AppTheme.primaryTeal,
                prominent: true,
                onPressed: () => _openScheduleWizard(context),
              ),
              ParentHeaderActionButton(
                label: 'Nowe zdarzenie',
                icon: Icons.add,
                backgroundColor: AppTheme.purpleColor,
                prominent: true,
                onPressed: () => _addEvent(context),
              ),
            ],
      tabBar: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          const Tab(text: 'Grafik'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Prośby'),
                if (pendingRequests > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$pendingRequests',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(context, calendar, roleColor, isReadOnly, user?.id),
          _buildRequestsTab(context, calendar, user?.id),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(
    BuildContext context,
    CalendarProvider calendar,
    Color roleColor,
    bool isReadOnly,
    String? userId,
  ) {
    return Column(
      children: [
        if (calendar.isLoading && calendar.isEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (calendar.error != null && calendar.isEmpty)
          MaterialBanner(
            content: Text(
              'Nie udało się załadować kalendarza. Sprawdź połączenie i spróbuj ponownie.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    context.read<CalendarProvider>().load(),
                child: const Text('Odśwież'),
              ),
            ],
          ),
        if (!isReadOnly && calendar.shouldPromptScheduleSetup)
          _ScheduleSetupBanner(onPressed: () => _openScheduleWizard(context)),
        if (!isReadOnly && calendar.hasPendingScheduleApproval)
          _PendingScheduleBanner(
            schedule: calendar.custodySchedule!,
            showsPreview: calendar.showsPendingSchedulePreview,
            canRespond: calendar.canRespondToPendingSchedule(userId),
            keyboardAcceptAutofocus:
                calendar.canRespondToPendingSchedule(userId),
            onAccept: () => _respondToSchedule(context, approve: true),
            onReject: () => _respondToSchedule(context, approve: false),
          ),
        Expanded(
          child: GoogleStyleMonthCalendar(
            key: ValueKey(
              'cal-${calendar.custodySlots.length}-'
              '${calendar.events.length}-'
              '${calendar.custodySchedule?.id}-'
              '${calendar.custodySchedule?.status.name}-'
              '${calendar.showsPendingSchedulePreview}-'
              '${calendar.loadedFromApi}',
            ),
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            accentColor: AppTheme.accentColor,
            getSlotsForDay: calendar.getSlotsForDay,
            getEventsForDay: calendar.getEventsForDay,
            isExceptionDay: calendar.isExceptionDay,
            hasPendingException: calendar.hasPendingExceptionForDay,
            onDaySelected: (day) {
              setState(() {
                _selectedDay = day;
                _focusedDay = day;
              });
            },
            onDayTap: (day) =>
                _showDayDetailSheet(context, calendar, day, isReadOnly),
            onEventDoubleTap: isReadOnly
                ? null
                : (event) => _showEditEventSheet(context, event),
            onMonthChanged: (month) {
              setState(() => _focusedDay = month);
            },
            onTodayPressed: () {
              final today = DateTime.now();
              setState(() {
                _focusedDay = today;
                _selectedDay = today;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: AppTheme.parentAColor,
                label: 'U Mamy',
              ),
              const SizedBox(width: 20),
              _LegendItem(
                color: AppTheme.parentBColor,
                label: 'U Taty',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openScheduleWizard(BuildContext context) async {
    final calendar = context.read<CalendarProvider>();
    if (calendar.hasLockedSchedule) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Zmiana grafiku wymaga akceptacji'),
          content: Text(
            calendar.hasActiveSchedule
                ? 'Obecny grafik pozostaje w mocy do czasu akceptacji nowej propozycji przez drugiego rodzica.'
                : 'Masz już oczekującą propozycję grafiku. Nowa propozycja zastąpi poprzednią w oczekiwaniu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kontynuuj'),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) {
        return;
      }
    }

    final accepted = await showCustodyScheduleWizard(context);
    if (accepted == true && context.mounted) {
      await _refreshSwapMessaging(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grafik wysłany do akceptacji. Drugi rodzic zobaczy go w Prośbach i w czacie.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _respondToSchedule(
    BuildContext context, {
    required bool approve,
  }) async {
    final schedule = context.read<CalendarProvider>().custodySchedule;
    if (schedule == null) {
      return;
    }

    try {
      final app = context.read<AppProvider>();
      if (app.isDemoMode) {
        await context.read<CalendarProvider>().respondToScheduleDemo(
              approve: approve,
              approvedById: app.currentUser?.id,
            );
      } else {
        await context.read<CalendarProvider>().respondToSchedule(
              scheduleId: schedule.id,
              approve: approve,
            );
      }
      if (!context.mounted) return;
      await _refreshSwapMessaging(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Grafik zaakceptowany — kalendarz został zaktualizowany.'
                : 'Propozycja grafiku została odrzucona.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calendarActionError(error, 'odpowiedzi na grafik')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showDayDetailSheet(
    BuildContext context,
    CalendarProvider calendar,
    DateTime day,
    bool isReadOnly,
  ) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });

    final slots = calendar.getSlotsForDay(day);
    final events = calendar.getEventsForDay(day);
    final slot = slots.isNotEmpty ? slots.first : null;
    final isPending = calendar.hasPendingExceptionForDay(day);
    final isException = calendar.isExceptionDay(day);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.65;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SelectedDayCard(
                            day: day,
                            slot: slot,
                            events: events,
                            isException: isException,
                            isPending: isPending,
                            onEventDoubleTap: isReadOnly
                                ? null
                                : (event) {
                                    Navigator.pop(ctx);
                                    _showEditEventSheet(context, event);
                                  },
                          ),
                          if (!isReadOnly) ...[
                            const SizedBox(height: 12),
                            if (calendar.hasActiveSchedule && !isPending)
                              _DayActionButtons(
                                day: day,
                                slot: slot,
                                onChangeCustodian: () {
                                  Navigator.pop(ctx);
                                  _showExceptionSheet(context, day, slot);
                                },
                                onRequestSwap: () {
                                  Navigator.pop(ctx);
                                  _requestSwapForDay(context, day);
                                },
                              )
                            else if (calendar.hasPendingScheduleApproval &&
                                !calendar.hasActiveSchedule)
                              const Text(
                                'Grafik oczekuje na akceptację. Po zatwierdzeniu '
                                'zmiany dni będą możliwe tylko przez prośby.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            else if (isPending)
                              const Text(
                                'Ten dzień ma już oczekującą prośbę o zmianę opiekuna.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExceptionSheet(
    BuildContext context,
    DateTime day,
    CustodySlot? slot,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExceptionRequestSheet(
        day: day,
        currentCustodian: slot?.custodian,
      ),
    );
  }

  void _requestSwapForDay(BuildContext context, DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SwapRequestSheet(
        selectedDay: day,
        onSubmitted: () => _refreshSwapMessaging(context),
      ),
    );
  }

  Widget _buildRequestsTab(
    BuildContext context,
    CalendarProvider calendar,
    String? userId,
  ) {
    final schedule = calendar.custodySchedule;
    final pendingExceptions = calendar.pendingExceptions;
    final swaps = calendar.swapRequests
        .where((item) => item.status == SwapStatus.pending)
        .toList();

    if (schedule?.status != CustodyScheduleStatus.pendingApproval &&
        pendingExceptions.isEmpty &&
        swaps.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Brak oczekujących próśb',
        subtitle:
            'Propozycje grafiku, wyjątki i zamiany dni pojawią się tutaj',
      );
    }

    var assignedKeyboardAccept = false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (schedule?.status == CustodyScheduleStatus.pendingApproval) ...[
          Builder(
            builder: (context) {
              final canRespond = calendar.canRespondToPendingSchedule(userId);
              final autofocus = canRespond && !assignedKeyboardAccept;
              if (autofocus) {
                assignedKeyboardAccept = true;
              }
              return _ScheduleRequestCard(
                schedule: schedule!,
                canRespond: canRespond,
                keyboardAcceptAutofocus: autofocus,
                onAccept: () => _respondToSchedule(context, approve: true),
                onReject: () => _respondToSchedule(context, approve: false),
              );
            },
          ),
        ],
        ...pendingExceptions.map(
          (exception) {
            final canRespond =
                calendar.canRespondToException(exception, userId);
            final autofocus = canRespond && !assignedKeyboardAccept;
            if (autofocus) {
              assignedKeyboardAccept = true;
            }
            return _ExceptionRequestCard(
              exception: exception,
              canRespond: canRespond,
              keyboardAcceptAutofocus: autofocus,
              onAccept: () => _respondToException(context, exception, true),
              onReject: () => _respondToException(context, exception, false),
            );
          },
        ),
        ...swaps.map(
          (swap) {
            final isMyRequest = swap.requesterId == userId;
            final canRespond =
                swap.status == SwapStatus.pending && !isMyRequest;
            final autofocus = canRespond && !assignedKeyboardAccept;
            if (autofocus) {
              assignedKeyboardAccept = true;
            }
            return _SwapCard(
              swap: swap,
              isMyRequest: isMyRequest,
              canRespond: canRespond,
              keyboardAcceptAutofocus: autofocus,
              onAccept: () async {
                try {
                  await calendar.respondToSwap(
                    swap.id,
                    SwapStatus.accepted,
                    note: 'Akceptuję',
                  );
                  if (!context.mounted) return;
                  await _refreshSwapMessaging(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Zamiana zaakceptowana. Grafik opieki został zaktualizowany.',
                      ),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _calendarActionError(error, 'akceptacji zamiany'),
                      ),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              onReject: () => _showSwapRejectSheet(context, swap),
            );
          },
        ),
      ],
    );
  }

  Future<void> _respondToException(
    BuildContext context,
    CustodyException exception,
    bool approve,
  ) async {
    try {
      await context.read<CalendarProvider>().respondToException(
            exceptionId: exception.id,
            approve: approve,
          );
      if (!context.mounted) return;
      await _refreshSwapMessaging(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Wyjątek zaakceptowany — kalendarz zaktualizowany.'
                : 'Wniosek o wyjątek został odrzucony.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calendarActionError(error, 'odpowiedzi na wyjątek')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _addEvent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEventSheet(selectedDay: _selectedDay),
    );
  }

  void _showEditEventSheet(BuildContext context, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEventSheet(
        selectedDay: DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        ),
        event: event,
      ),
    );
  }

  Future<void> _refreshSwapMessaging(BuildContext context) async {
    if (context.read<AppProvider>().isDemoMode) {
      return;
    }

    final viewerUserId = context.read<AppProvider>().currentUser?.id;
    await context.read<MessagingProvider>().loadThreads(
          viewerUserId: viewerUserId,
          notifyEnabled: context.read<AppProvider>().notifyMessages,
          silent: true,
        );
  }

  void _showSwapRejectSheet(BuildContext context, SwapRequest swap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SwapRejectSheet(
        swap: swap,
        onSubmitted: () => _refreshSwapMessaging(context),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool dot;

  const _LegendItem({
    required this.color,
    required this.label,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  final DateTime day;
  final CustodySlot? slot;
  final List<CalendarEvent> events;
  final bool isException;
  final bool isPending;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;

  const _SelectedDayCard({
    required this.day,
    required this.slot,
    required this.events,
    this.isException = false,
    this.isPending = false,
    this.onEventDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    final isParentA = slot?.custodian == UserRole.parentA;
    final color = slot == null
        ? AppTheme.textSecondary
        : (isParentA ? AppTheme.parentAColor : AppTheme.parentBColor);
    final label = slot == null
        ? null
        : (isParentA ? 'U Mamy' : 'U Taty');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDayHeader(day),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isException || isPending) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (isException)
                      const StatusChip(
                        label: 'Wyjątek',
                        color: AppTheme.warningColor,
                      ),
                    if (isPending)
                      const StatusChip(
                        label: 'Oczekuje akceptacji',
                        color: AppTheme.warningColor,
                      ),
                  ],
                ),
              ],
              if (slot != null && label != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.home, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    if (slot!.handoverTime != null)
                      Text(
                        'Przekazanie: ${slot!.handoverTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (slot!.handoverLocation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        slot!.handoverLocation!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (sortedEvents.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...sortedEvents.map(
                  (e) {
                    final timeLabel = formatEventTimeLabel(e.startDate);
                    return GestureDetector(
                      onDoubleTap: onEventDoubleTap == null
                          ? null
                          : () => onEventDoubleTap!(e),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            e.typeIcon,
                            size: 16,
                            color: e.typeColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeLabel == null
                                    ? e.title
                                    : '$timeLabel  ${e.title}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (e.description != null)
                                Text(
                                  e.description!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                    );
                  },
                ),
              ] else if (slot == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Brak zdarzeń tego dnia',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  String _formatDayHeader(DateTime date) {
    const weekdays = [
      'poniedziałek',
      'wtorek',
      'środa',
      'czwartek',
      'piątek',
      'sobota',
      'niedziela',
    ];
    const months = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];
    final weekday = weekdays[date.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${date.day} ${months[date.month - 1]}';
  }
}

class _SwapCard extends StatelessWidget {
  final SwapRequest swap;
  final bool isMyRequest;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SwapCard({
    required this.swap,
    required this.isMyRequest,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMyRequest
                              ? 'Twój wniosek'
                              : 'Wniosek od ${swap.requesterName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: swap.statusLabel,
                        color: swap.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SwapDateRow(
                    label: 'Oryginalny dzień',
                    date: swap.originalDate,
                    icon: Icons.event,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 6),
                  _SwapDateRow(
                    label: 'Proponowany dzień',
                    date: swap.proposedDate,
                    icon: Icons.event_available,
                    color: AppTheme.successColor,
                  ),
                  if (swap.reason != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Powód: ${swap.reason}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (swap.responseNote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Odpowiedź: ${swap.responseNote}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (isMyRequest && swap.status == SwapStatus.pending) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Oczekuje na decyzję drugiego rodzica.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canRespond) ...[
              const SizedBox(width: 12),
              EnterAcceptScope(
                onAccept: onAccept,
                autofocus: keyboardAcceptAutofocus,
                child: SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Akceptuj',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Odrzuć',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwapDateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final IconData icon;
  final Color color;

  const _SwapDateRow({
    required this.label,
    required this.date,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          '${date.day}.${date.month}.${date.year}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final DateTime selectedDay;
  final CalendarEvent? event;

  const _AddEventSheet({
    required this.selectedDay,
    this.event,
  });

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet>
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
      _selectedTime = TimeOfDay(
        hour: event.startDate.hour,
        minute: event.startDate.minute,
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
          content: Text(_calendarActionError(error, 'zdarzenia')),
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

class _SwapRequestSheet extends StatefulWidget {
  final DateTime selectedDay;
  final VoidCallback? onSubmitted;

  const _SwapRequestSheet({
    required this.selectedDay,
    this.onSubmitted,
  });

  @override
  State<_SwapRequestSheet> createState() => _SwapRequestSheetState();
}

class _SwapRequestSheetState extends State<_SwapRequestSheet> {
  final _reasonController = TextEditingController();
  late DateTime _originalDate;
  late DateTime _proposedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _originalDate = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    _proposedDate = _originalDate.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<CalendarProvider>().createSwapRequest(
            originalDate: _originalDate,
            proposedDate: _proposedDate,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      widget.onSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wniosek wysłany. Drugi rodzic zobaczy go w wiadomościach → Zmiana grafiku.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calendarActionError(error, 'wniosku o zamianę')),
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
          const Text(
            'Wniosek o zamianę',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Złóż wniosek o zamianę dnia opieki. Drugi rodzic otrzyma powiadomienie i będzie mógł zaakceptować lub odrzucić.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dzień do zamiany'),
            subtitle: Text(
              '${_originalDate.day}.${_originalDate.month}.${_originalDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _originalDate,
              onSelected: (value) => setState(() => _originalDate = value),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Proponowany dzień'),
            subtitle: Text(
              '${_proposedDate.day}.${_proposedDate.month}.${_proposedDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(
              initial: _proposedDate,
              onSelected: (value) => setState(() => _proposedDate = value),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Powód zamiany (opcjonalnie)',
              hintText: 'np. Wyjazd służbowy, urodziny babci...',
            ),
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
                  : const Text('Wyślij wniosek'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSwapDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

class _SwapRejectSheet extends StatefulWidget {
  final SwapRequest swap;
  final VoidCallback? onSubmitted;

  const _SwapRejectSheet({
    required this.swap,
    this.onSubmitted,
  });

  @override
  State<_SwapRejectSheet> createState() => _SwapRejectSheetState();
}

class _SwapRejectSheetState extends State<_SwapRejectSheet> {
  final _reasonController = TextEditingController();
  late DateTime _counterOriginalDate;
  late DateTime _counterProposedDate;
  bool _proposeAlternativeDates = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _counterOriginalDate = DateTime(
      widget.swap.originalDate.year,
      widget.swap.originalDate.month,
      widget.swap.originalDate.day,
    );
    _counterProposedDate = DateTime(
      widget.swap.proposedDate.year,
      widget.swap.proposedDate.month,
      widget.swap.proposedDate.day,
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _counterDatesChanged {
    final sameOriginal = _counterOriginalDate.year == widget.swap.originalDate.year &&
        _counterOriginalDate.month == widget.swap.originalDate.month &&
        _counterOriginalDate.day == widget.swap.originalDate.day;
    final sameProposed = _counterProposedDate.year == widget.swap.proposedDate.year &&
        _counterProposedDate.month == widget.swap.proposedDate.month &&
        _counterProposedDate.day == widget.swap.proposedDate.day;
    return !sameOriginal || !sameProposed;
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _buildResponseNote({required SwapStatus status}) {
    final reason = _reasonController.text.trim();
    if (status == SwapStatus.counterProposed) {
      final lines = <String>[
        'Kontrpropozycja dat:',
        'Oryginalny dzień: ${_formatSwapDate(_counterOriginalDate)}',
        'Proponowany dzień: ${_formatSwapDate(_counterProposedDate)}',
      ];
      if (reason.isNotEmpty) {
        lines.add('Powód: $reason');
      }
      return lines.join('\n');
    }

    final lines = <String>[
      'Odrzucony wniosek:',
      'Oryginalny dzień: ${_formatSwapDate(widget.swap.originalDate)}',
      'Proponowany dzień: ${_formatSwapDate(widget.swap.proposedDate)}',
    ];
    if (reason.isNotEmpty) {
      lines.add('Powód: $reason');
    }
    return lines.join('\n');
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final useCounter = _proposeAlternativeDates && _counterDatesChanged;
    final status =
        useCounter ? SwapStatus.counterProposed : SwapStatus.rejected;
    final note = _buildResponseNote(status: status);

    try {
      await context.read<CalendarProvider>().respondToSwap(
            widget.swap.id,
            status,
            note: note,
          );
      if (!mounted) {
        return;
      }
      widget.onSubmitted?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            useCounter
                ? 'Wysłano kontrpropozycję dat do ${widget.swap.requesterName}.'
                : 'Wniosek o zamianę został odrzucony.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calendarActionError(error, 'odpowiedzi na wymianę')),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Odrzuć wniosek o zamianę',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wniosek od ${widget.swap.requesterName}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                _SwapDateRow(
                  label: 'Oryginalny dzień we wniosku',
                  date: widget.swap.originalDate,
                  icon: Icons.event,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 8),
                _SwapDateRow(
                  label: 'Proponowany dzień we wniosku',
                  date: widget.swap.proposedDate,
                  icon: Icons.event_available,
                  color: AppTheme.successColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Proponuję inne daty',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: const Text(
              'Wyślij kontrpropozycję zamiast samego odrzucenia',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _proposeAlternativeDates,
            activeThumbColor: AppTheme.primaryTeal,
            onChanged: (value) => setState(() => _proposeAlternativeDates = value),
          ),
          if (_proposeAlternativeDates) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Twój oryginalny dzień'),
              subtitle: Text(_formatSwapDate(_counterOriginalDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _counterOriginalDate,
                onSelected: (value) =>
                    setState(() => _counterOriginalDate = value),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Twój proponowany dzień'),
              subtitle: Text(_formatSwapDate(_counterProposedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                initial: _counterProposedDate,
                onSelected: (value) =>
                    setState(() => _counterProposedDate = value),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Powód (opcjonalnie)',
              hintText: 'np. Mam wtedy wyjazd służbowy…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close, size: 18),
              label: Text(
                _proposeAlternativeDates && _counterDatesChanged
                    ? 'Odrzuć i wyślij kontrpropozycję'
                    : 'Odrzuć wniosek',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatScheduleRange(CustodySchedule schedule) {
  final start =
      '${schedule.startDate.day}.${schedule.startDate.month}.${schedule.startDate.year}';
  final end = schedule.endDate;
  if (end == null) {
    return start;
  }
  return '$start – ${end.day}.${end.month}.${end.year}';
}

String _calendarActionError(Object error, String actionLabel) {
  if (error is StateError && error.message == 'schedule_locked') {
    return 'Grafik jest zablokowany. Zmiany wymagają akceptacji drugiego rodzica.';
  }
  if (error is ApiException) {
    if (error.message == 'invalid_request') {
      return 'Nieprawidłowe dane $actionLabel. Sprawdź wybrane daty.';
    }
    if (error.message == 'swap_not_allowed') {
      return 'Nie możesz odpowiedzieć na własny wniosek o zamianę.';
    }
    if (error.message == 'schedule_not_active') {
      return 'Zmiany dni są możliwe dopiero po zaakceptowaniu grafiku opieki.';
    }
    if (error.message == 'schedule_locked') {
      return 'Grafik jest zablokowany. Zmiany wymagają akceptacji drugiego rodzica.';
    }
    if (error.message == 'schedule_not_allowed' ||
        error.message == 'exception_not_allowed') {
      return 'Nie możesz odpowiedzieć na własną prośbę.';
    }
    if (error.statusCode >= 500) {
      return 'Błąd serwera. Spróbuj ponownie za chwilę.';
    }
  }
  return 'Nie udało się wysłać $actionLabel.';
}

class _ScheduleSetupBanner extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScheduleSetupBanner({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: MaterialBanner(
        backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.08),
        content: const Text(
          'Ustawcie wspólny grafik opieki — drugi rodzic musi go zaakceptować.',
        ),
        leading: const Icon(Icons.view_week, color: AppTheme.primaryTeal),
        actions: [
          TextButton(onPressed: onPressed, child: const Text('Utwórz grafik')),
        ],
      ),
    );
  }
}

class _PendingScheduleBanner extends StatelessWidget {
  final CustodySchedule schedule;
  final bool showsPreview;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingScheduleBanner({
    required this.schedule,
    required this.showsPreview,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canRespond
                    ? 'Propozycja grafiku do akceptacji'
                    : 'Grafik oczekuje na akceptację',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                schedule.endDate != null
                    ? '${schedule.patternLabel} · ${_formatScheduleRange(schedule)}'
                    : '${schedule.patternLabel} · start ${schedule.startDate.day}.${schedule.startDate.month}.${schedule.startDate.year}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (showsPreview) ...[
                const SizedBox(height: 6),
                const Text(
                  'Kalendarz pokazuje podgląd proponowanego grafiku — '
                  'taki sam u obojga rodziców.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (canRespond) ...[
                const SizedBox(height: 12),
                EnterAcceptScope(
                  onAccept: onAccept,
                  autofocus: keyboardAcceptAutofocus,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          child: const Text('Odrzuć'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                          ),
                          child: const Text('Akceptuj'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRequestCard extends StatelessWidget {
  final CustodySchedule schedule;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ScheduleRequestCard({
    required this.schedule,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Propozycja grafiku opieki',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Szablon: ${schedule.patternLabel}'),
                  Text(
                    schedule.endDate != null
                        ? 'Okres: ${_formatScheduleRange(schedule)}'
                        : 'Start: ${schedule.startDate.day}.${schedule.startDate.month}.${schedule.startDate.year}',
                  ),
                  if (schedule.handoverTime != null)
                    Text('Przekazanie: ${schedule.handoverTime}'),
                  if (!canRespond)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Oczekuje na decyzję drugiego rodzica.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canRespond)
              EnterAcceptScope(
                onAccept: onAccept,
                autofocus: keyboardAcceptAutofocus,
                child: SizedBox(
                  width: 108,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Akceptuj', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Odrzuć', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExceptionRequestCard extends StatelessWidget {
  final CustodyException exception;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ExceptionRequestCard({
    required this.exception,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  String get _rangeLabel {
    final from = exception.fromDate;
    final to = exception.toDate;
    if (from.year == to.year &&
        from.month == to.month &&
        from.day == to.day) {
      return '${from.day}.${from.month}.${from.year}';
    }
    return '${from.day}.${from.month}.${from.year} – ${to.day}.${to.month}.${to.year}';
  }

  String get _custodianLabel =>
      exception.custodian == UserRole.parentA ? 'Mama' : 'Tata';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wniosek o zmianę opiekuna',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Okres: $_rangeLabel'),
                  Text('Opiekun: $_custodianLabel'),
                  if (exception.reason != null)
                    Text('Powód: ${exception.reason}'),
                ],
              ),
            ),
            if (canRespond)
              EnterAcceptScope(
                onAccept: onAccept,
                autofocus: keyboardAcceptAutofocus,
                child: SizedBox(
                  width: 108,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Akceptuj', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Odrzuć', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayActionButtons extends StatelessWidget {
  final DateTime day;
  final CustodySlot? slot;
  final VoidCallback onChangeCustodian;
  final VoidCallback onRequestSwap;

  const _DayActionButtons({
    required this.day,
    required this.slot,
    required this.onChangeCustodian,
    required this.onRequestSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Zmiany w zatwierdzonym grafiku wymagają akceptacji drugiego rodzica.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onChangeCustodian,
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('Zaproponuj zmianę opiekuna'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRequestSwap,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Prośba o zamianę'),
        ),
      ],
    );
  }
}

class _ExceptionRequestSheet extends StatefulWidget {
  final DateTime day;
  final UserRole? currentCustodian;

  const _ExceptionRequestSheet({
    required this.day,
    this.currentCustodian,
  });

  @override
  State<_ExceptionRequestSheet> createState() => _ExceptionRequestSheetState();
}

class _ExceptionRequestSheetState extends State<_ExceptionRequestSheet> {
  late UserRole _custodian;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _custodian = widget.currentCustodian == UserRole.parentA
        ? UserRole.parentB
        : UserRole.parentA;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<CalendarProvider>().requestException(
            fromDate: widget.day,
            custodian: _custodian,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wniosek o wyjątek wysłany do akceptacji.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_calendarActionError(error, 'wniosku o wyjątek')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Zaproponuj zmianę opiekuna',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Drugi rodzic musi zaakceptować zmianę, zanim zacznie obowiązywać.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Dzień: ${widget.day.day}.${widget.day.month}.${widget.day.year}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.parentA, label: Text('Mama')),
              ButtonSegment(value: UserRole.parentB, label: Text('Tata')),
            ],
            selected: {_custodian},
            onSelectionChanged: (value) =>
                setState(() => _custodian = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Powód (opcjonalnie)',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Wysyłam...' : 'Wyślij do akceptacji'),
            ),
          ),
        ],
      ),
    );
  }
}
