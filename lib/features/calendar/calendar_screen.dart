import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/api/app_api_client.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/calendar_date_utils.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/parent_tab_scaffold.dart';
import '../../../widgets/google_style_month_calendar.dart';
import '../../../widgets/custody_schedule_wizard.dart';
import 'calendar_helpers.dart';
import 'widgets/legend_item.dart';
import 'widgets/selected_day_card.dart';
import 'widgets/swap_card.dart';
import 'widgets/add_event_sheet.dart';
import 'widgets/swap_request_sheet.dart';
import 'widgets/swap_reject_sheet.dart';
import 'widgets/schedule_setup_banner.dart';
import 'widgets/pending_schedule_banner.dart';
import 'widgets/schedule_request_card.dart';
import 'widgets/exception_request_card.dart';
import 'widgets/day_action_buttons.dart';
import 'widgets/exception_request_sheet.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime? focusDay;
  final int focusRequestId;
  final VoidCallback? onScheduleRejected;

  const CalendarScreen({
    super.key,
    this.focusDay,
    this.focusRequestId = 0,
    this.onScheduleRejected,
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
        if (calendar.error != null &&
            calendar.isEmpty &&
            !calendar.loadedFromApi)
          MaterialBanner(
            content: const Text(
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
          ScheduleSetupBanner(onPressed: () => _openScheduleWizard(context)),
        if (!isReadOnly && calendar.hasPendingScheduleApproval)
          PendingScheduleBanner(
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
              LegendItem(
                color: AppTheme.parentAColor,
                label: 'U Mamy',
              ),
              const SizedBox(width: 20),
              LegendItem(
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
      if (!approve) {
        widget.onScheduleRejected?.call();
      }
      if (!context.mounted) return;
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
          content: Text(calendarActionError(error, 'odpowiedzi na grafik')),
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
                          SelectedDayCard(
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
                              DayActionButtons(
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
      builder: (_) => ExceptionRequestSheet(
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
      builder: (_) => SwapRequestSheet(
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
              return ScheduleRequestCard(
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
            return ExceptionRequestCard(
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
            return SwapCard(
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
                        calendarActionError(error, 'akceptacji zamiany'),
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
          content: Text(calendarActionError(error, 'odpowiedzi na wyjątek')),
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
      builder: (_) => AddEventSheet(selectedDay: _selectedDay),
    );
  }

  void _showEditEventSheet(BuildContext context, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddEventSheet(
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
      builder: (_) => SwapRejectSheet(
        swap: swap,
        onSubmitted: () => _refreshSwapMessaging(context),
      ),
    );
  }
}
