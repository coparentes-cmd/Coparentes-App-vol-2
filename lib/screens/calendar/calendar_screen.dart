import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/google_style_month_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLiveRefresh());
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
    final isReadOnly = user?.role == UserRole.observer;
    final roleColor = user?.role == UserRole.parentA
        ? AppTheme.parentAColor
        : AppTheme.parentBColor;

    final selectedSlots = calendar.getSlotsForDay(_selectedDay);
    final selectedEvents = calendar.getEventsForDay(_selectedDay);
    final pendingSwaps = calendar.swapRequests
        .where((s) => s.status == SwapStatus.pending)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Kalendarz opieki'),
        actions: [
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addEvent(context),
            ),
        ],
        bottom: TabBar(
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
                  const Text('Zamiany'),
                  if (pendingSwaps.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pendingSwaps.length}',
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
            const Tab(text: 'Zdarzenia'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Calendar
          _buildCalendarTab(
            context,
            calendar,
            selectedSlots,
            selectedEvents,
            roleColor,
          ),
          // Tab 2: Swap requests
          _buildSwapsTab(context, calendar),
          // Tab 3: Events list
          _buildEventsTab(context, calendar),
        ],
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _requestSwap(context),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Zamiana'),
            ),
    );
  }

  Widget _buildCalendarTab(
    BuildContext context,
    CalendarProvider calendar,
    List<CustodySlot> selectedSlots,
    List<CalendarEvent> selectedEvents,
    Color roleColor,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: AiContextualTip(
            tips: AiTips.calendar,
            intervalSeconds: 8,
          ),
        ),
        Expanded(
          child: GoogleStyleMonthCalendar(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            accentColor: roleColor,
            getSlotsForDay: calendar.getSlotsForDay,
            getEventsForDay: calendar.getEventsForDay,
            onDaySelected: (day) {
              setState(() {
                _selectedDay = day;
                _focusedDay = day;
              });
            },
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
        if (selectedSlots.isNotEmpty || selectedEvents.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.28,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SelectedDayCard(
                day: _selectedDay,
                slot: selectedSlots.isNotEmpty ? selectedSlots.first : null,
                events: selectedEvents,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSwapsTab(BuildContext context, CalendarProvider calendar) {
    final swaps = calendar.swapRequests;
    final user = context.watch<AppProvider>().currentUser;

    if (swaps.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_horiz,
        title: 'Brak wniosków o zamianę',
        subtitle: 'Wnioski o zamianę dni opieki pojawią się tutaj',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: swaps.length,
      itemBuilder: (ctx, i) {
        final swap = swaps[i];
        final isMyRequest = swap.requesterId == user?.id;
        return _SwapCard(
          swap: swap,
          isMyRequest: isMyRequest,
          onAccept: () async {
            try {
              await calendar.respondToSwap(
                swap.id,
                SwapStatus.accepted,
                note: 'Akceptuję',
              );
              await _refreshSwapMessaging(context);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nie udało się zaakceptować wymiany.'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          onReject: () => _showSwapRejectSheet(context, swap),
        );
      },
    );
  }

  Widget _buildEventsTab(BuildContext context, CalendarProvider calendar) {
    final events = calendar.events;
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note,
        title: 'Brak zdarzeń',
        subtitle: 'Dodaj zdarzenia szkolne, medyczne i inne',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (ctx, i) {
        final event = events[i];
        return _EventCard(event: event);
      },
    );
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

  void _requestSwap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SwapRequestSheet(
        selectedDay: _selectedDay,
        onSubmitted: () => _refreshSwapMessaging(context),
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

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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

  const _SelectedDayCard({
    required this.day,
    required this.slot,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final isParentA = slot?.custodian == UserRole.parentA;
    final color = slot == null
        ? AppTheme.textSecondary
        : (isParentA ? AppTheme.parentAColor : AppTheme.parentBColor);
    final label = slot == null
        ? null
        : (isParentA ? 'U Mamy' : 'U Taty');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
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
              if (events.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...events.map(
                  (e) => Padding(
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
                                e.title,
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
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SwapCard({
    required this.swap,
    required this.isMyRequest,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = swap.status == SwapStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isMyRequest ? 'Twój wniosek' : 'Wniosek od ${swap.requesterName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
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
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
            if (isPending && !isMyRequest) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Odrzuć'),
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Akceptuj'),
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
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

class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: event.typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(event.typeIcon, color: event.typeColor, size: 20),
        ),
        title: Text(
          event.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${event.startDate.day}.${event.startDate.month}.${event.startDate.year}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (event.location != null)
              Text(
                event.location!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textHint, size: 18),
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final DateTime selectedDay;

  const _AddEventSheet({required this.selectedDay});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleController = TextEditingController();
  EventType _selectedType = EventType.school;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final startDate = DateTime(
        widget.selectedDay.year,
        widget.selectedDay.month,
        widget.selectedDay.day,
        12,
      );
      await context.read<CalendarProvider>().addEvent(
            title: title,
            startDate: startDate,
            type: _selectedType,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zdarzenie zostało dodane'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się dodać zdarzenia.'),
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
            'Nowe zdarzenie',
            style: TextStyle(
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
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Tytuł zdarzenia',
              hintText: 'np. Angielski – Zosia',
            ),
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
                  : const Text('Dodaj zdarzenie'),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się wysłać wniosku o zamianę.'),
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się odrzucić wymiany.'),
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
