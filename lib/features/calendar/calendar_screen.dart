import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/layout_utils.dart';
import '../../../widgets/parent_tab_scaffold.dart';
import '../../../widgets/google_style_month_calendar.dart';
import '../../../widgets/custody_schedule_wizard.dart';
import 'calendar_helpers.dart';
import 'widgets/legend_item.dart';
import 'widgets/selected_day_card.dart';
import 'widgets/add_event_sheet.dart';
import 'widgets/swap_request_sheet.dart';
import 'widgets/schedule_setup_banner.dart';
import 'widgets/pending_schedule_banner.dart';
import 'widgets/day_action_buttons.dart';

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

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Timer? _liveRefreshTimer;

  static const _liveRefreshInterval = Duration(seconds: 12);
  static const _pendingLiveRefreshInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
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

  Duration _currentLiveRefreshInterval() {
    final calendar = context.read<CalendarProvider>();
    if (calendar.hasPendingScheduleApproval) {
      return _pendingLiveRefreshInterval;
    }
    return _liveRefreshInterval;
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
    _scheduleNextLiveRefresh();
  }

  void _scheduleNextLiveRefresh() {
    _liveRefreshTimer?.cancel();
    if (!mounted || context.read<AppProvider>().isDemoMode) {
      return;
    }
    _liveRefreshTimer = Timer(_currentLiveRefreshInterval(), () async {
      if (!mounted || context.read<AppProvider>().isDemoMode) {
        return;
      }
      await context.read<CalendarProvider>().load(silent: true);
      if (!mounted) {
        return;
      }
      _scheduleNextLiveRefresh();
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
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

    return ParentTabScaffold(
      title: 'Kalendarz opieki',
      actions: isChild || isReadOnly
          ? null
          : [
              _CalendarHeaderIconButton(
                tooltip: 'Grafik opieki',
                icon: Icons.settings,
                backgroundColor: AppTheme.primaryTeal,
                onPressed: () => _openScheduleWizard(context),
              ),
              _CalendarHeaderIconButton(
                tooltip: 'Nowe zdarzenie',
                icon: Icons.add,
                backgroundColor: AppTheme.purpleColor,
                onPressed: () => _addEvent(context),
              ),
            ],
      body: _buildCalendarTab(
        context,
        calendar,
        roleColor,
        isReadOnly,
        user?.id,
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
    final twoPane = useTwoPaneLayout(context);

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
          child: twoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildMonthCalendar(
                        context,
                        calendar,
                        isReadOnly,
                        openDaySheet: false,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 340,
                      child: _buildDaySidePanel(
                        context,
                        calendar,
                        isReadOnly,
                      ),
                    ),
                  ],
                )
              : _buildMonthCalendar(
                  context,
                  calendar,
                  isReadOnly,
                  openDaySheet: true,
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

  Widget _buildMonthCalendar(
    BuildContext context,
    CalendarProvider calendar,
    bool isReadOnly, {
    required bool openDaySheet,
  }) {
    return GoogleStyleMonthCalendar(
      key: ValueKey(
        'cal-${calendar.custodySlots.length}-'
        '${calendar.events.length}-'
        '${calendar.custodySchedule?.id}-'
        '${calendar.custodySchedule?.status.name}-'
        '${calendar.custodySchedule?.patternType.name}-'
        '${calendar.custodySchedule?.weekInterval}-'
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
      onDayTap: (day) {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
        if (openDaySheet) {
          _showDayDetailSheet(context, calendar, day, isReadOnly);
        }
      },
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
    );
  }

  Widget _buildDaySidePanel(
    BuildContext context,
    CalendarProvider calendar,
    bool isReadOnly,
  ) {
    final day = _selectedDay;
    final slots = calendar.getSlotsForDay(day);
    final events = calendar.getEventsForDay(day);
    final slot = slots.isNotEmpty ? slots.first : null;
    final isPending = calendar.hasPendingExceptionForDay(day);
    final isException = calendar.isExceptionDay(day);

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _buildDayDetailBody(
          context: context,
          calendar: calendar,
          day: day,
          slot: slot,
          events: events,
          isException: isException,
          isPending: isPending,
          isReadOnly: isReadOnly,
          onBeforeAction: null,
        ),
      ),
    );
  }

  Widget _buildDayDetailBody({
    required BuildContext context,
    required CalendarProvider calendar,
    required DateTime day,
    required CustodySlot? slot,
    required List<CalendarEvent> events,
    required bool isException,
    required bool isPending,
    required bool isReadOnly,
    required VoidCallback? onBeforeAction,
  }) {
    return Column(
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
                  onBeforeAction?.call();
                  _showEditEventSheet(context, event);
                },
        ),
        if (!isReadOnly) ...[
          const SizedBox(height: 12),
          if (calendar.hasActiveSchedule && !isPending)
            DayActionButtons(
              onRequestSwap: () {
                onBeforeAction?.call();
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
              'Ten dzień ma już oczekującą prośbę o zmianę opieki.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
        ],
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
            'Grafik wysłany do akceptacji. Drugi rodzic zobaczy go w banerze kalendarza i w czacie.',
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
                      child: _buildDayDetailBody(
                        context: context,
                        calendar: calendar,
                        day: day,
                        slot: slot,
                        events: events,
                        isException: isException,
                        isPending: isPending,
                        isReadOnly: isReadOnly,
                        onBeforeAction: () => Navigator.pop(ctx),
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
}

class _CalendarHeaderIconButton extends StatelessWidget {
  static const double _size = 40;

  final String tooltip;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _CalendarHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: _size,
                height: _size,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
