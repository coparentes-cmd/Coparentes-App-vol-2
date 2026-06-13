import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../calendar/calendar_screen.dart';
import '../messaging/messaging_screen.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  int _selectedIndex = 0;
  int _mood = 3;
  final List<String> _packList = [
    'Tornister szkolny',
    'Etui z kredkami',
    'Strój na WF',
    'Butelka z wodą',
    'Kanapki',
  ];
  final List<bool> _packed = [false, false, false, false, false];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final firstName = user?.name.split(' ').first ?? 'Zosiu';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildTodayTab(context, firstName),
            const CalendarScreen(),
            const MessagingScreen(familyOnly: true),
            _buildPackTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.childColor,
        unselectedItemColor: AppTheme.textHint,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Dzisiaj',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Kalendarz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: 'Rodzina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Plecak',
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zmień profil'),
        content: const Text('Czy chcesz wrócić do ekranu wyboru profilu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nie'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.childColor,
            ),
            child: const Text('Tak, zmień'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, String firstName) {
    final now = DateTime.now();
    final weekdays = [
      'Poniedziałek',
      'Wtorek',
      'Środa',
      'Czwartek',
      'Piątek',
      'Sobota',
      'Niedziela',
    ];
    final dayName = weekdays[now.weekday - 1];
    final calendar = context.watch<CalendarProvider>();
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final slots = calendar.getSlotsForDay(now);
    final events = calendar.getEventsForDay(now);
    final slot = slots.isNotEmpty ? slots.first : null;
    final custodianLabel = _custodianLabel(slot?.custodian, workspace);
    final handoverHint = _handoverHint(slots, now, workspace);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: AppTheme.childColor,
        title: const Row(
          children: [
            Text('👧', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Mój dzień', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: Colors.white),
            tooltip: 'Zmień profil',
            onPressed: () => _showExitDialog(context),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF57C00), Color(0xFFFF9800)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cześć, $firstName! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text('🌟', style: TextStyle(fontSize: 40)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // AI tip for child
            AiContextualTip(
              tips: AiTips.child,
              intervalSeconds: 9,
              dismissible: true,
            ),

            const SizedBox(height: 16),

            // Where am I today
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.childColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🏠', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'Gdzie jestem dziś?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (slot == null)
                    const Text(
                      'Brak zaplanowanej opieki na dziś',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (slot.custodian == UserRole.parentA
                                ? AppTheme.parentAColor
                                : AppTheme.parentBColor)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            slot.custodian == UserRole.parentA ? '👩' : '👨',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            custodianLabel,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: slot.custodian == UserRole.parentA
                                  ? AppTheme.parentAColor
                                  : AppTheme.parentBColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (handoverHint != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('🕓', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            handoverHint,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Today events
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('📅', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'Dzisiaj',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    const Text(
                      'Brak zaplanowanych wydarzeń',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  else
                    ...events.map(
                      (event) => _EventItem(
                        time: _formatEventTime(event.startDate),
                        emoji: _eventEmoji(event.type),
                        title: event.title,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mood
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jak się dzisiaj czujesz? 💭',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'To tylko dla Ciebie – rodzice tego nie widzą 🔒',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MoodButton(
                          emoji: '😢',
                          value: 1,
                          selected: _mood == 1,
                          onTap: () => setState(() => _mood = 1)),
                      _MoodButton(
                          emoji: '😕',
                          value: 2,
                          selected: _mood == 2,
                          onTap: () => setState(() => _mood = 2)),
                      _MoodButton(
                          emoji: '😊',
                          value: 3,
                          selected: _mood == 3,
                          onTap: () => setState(() => _mood = 3)),
                      _MoodButton(
                          emoji: '😄',
                          value: 4,
                          selected: _mood == 4,
                          onTap: () => setState(() => _mood = 4)),
                      _MoodButton(
                          emoji: '🤩',
                          value: 5,
                          selected: _mood == 5,
                          onTap: () => setState(() => _mood = 5)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: AppTheme.childColor,
        title: const Row(
          children: [
            Text('🎒', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Plecak', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: Colors.white),
            tooltip: 'Zmień profil',
            onPressed: () => _showExitDialog(context),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎒 Co spakować?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_packed.where((p) => p).length} / ${_packList.length} spakowanych',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _packed.where((p) => p).length / _packList.length,
              backgroundColor: AppTheme.dividerColor,
              color: AppTheme.childColor,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 20),
            ...List.generate(_packList.length, (i) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Text(
                    _packList[i],
                    style: TextStyle(
                      fontSize: 15,
                      color: _packed[i] ? AppTheme.textHint : AppTheme.textPrimary,
                      decoration: _packed[i] ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: _packed[i],
                  activeColor: AppTheme.childColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onChanged: (v) => setState(() => _packed[i] = v ?? false),
                ),
              );
            }),
            if (_packed.every((p) => p)) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 28)),
                    SizedBox(width: 12),
                    Text(
                      'Wszystko spakowane!\nJesteś gotowa!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatEventTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _eventEmoji(EventType type) {
    switch (type) {
      case EventType.school:
        return '🏫';
      case EventType.medical:
        return '🏥';
      case EventType.activity:
        return '📚';
      case EventType.handover:
        return '🤝';
      case EventType.holiday:
        return '🎉';
      case EventType.other:
        return '📌';
    }
  }

  String _custodianLabel(UserRole? role, Workspace? workspace) {
    if (role == null) {
      return 'Brak informacji';
    }

    AppUser? member;
    for (final user in workspace?.members ?? const <AppUser>[]) {
      if (user.role == role) {
        member = user;
        break;
      }
    }

    if (member != null) {
      final firstName = member.name.split(' ').first;
      return 'U $firstName';
    }

    return role == UserRole.parentA ? 'U rodzica A' : 'U rodzica B';
  }

  String? _handoverHint(
    List<CustodySlot> slots,
    DateTime day,
    Workspace? workspace,
  ) {
    final slot = slots.isNotEmpty ? slots.first : null;
    if (slot?.handoverTime != null && slot!.handoverTime!.isNotEmpty) {
      final location = slot.handoverLocation;
      if (location != null && location.isNotEmpty) {
        return 'Przekazanie o ${slot.handoverTime} — $location';
      }
      return 'Przekazanie o ${slot.handoverTime}';
    }

    final tomorrow = day.add(const Duration(days: 1));
    final tomorrowSlots = context.read<CalendarProvider>().getSlotsForDay(tomorrow);
    if (tomorrowSlots.isEmpty || slot == null) {
      return null;
    }

    final tomorrowSlot = tomorrowSlots.first;
    if (tomorrowSlot.custodian == slot.custodian) {
      return null;
    }

    final nextParent = _custodianLabel(tomorrowSlot.custodian, workspace);
    return 'Jutro: $nextParent';
  }
}

class _EventItem extends StatelessWidget {
  final String time;
  final String emoji;
  final String title;

  const _EventItem({
    required this.time,
    required this.emoji,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  final String emoji;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _MoodButton({
    required this.emoji,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.childColor.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.childColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: selected ? 28 : 24),
          ),
        ),
      ),
    );
  }
}
