import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/calendar_date_utils.dart';
import '../../widgets/common_widgets.dart';
import '../calendar/calendar_screen.dart';
import '../messaging/messaging_screen.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}

class _ChildListItem {
  final String id;
  String text;
  bool checked;

  _ChildListItem({
    required this.id,
    required this.text,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
      };

  factory _ChildListItem.fromJson(Map<String, dynamic> json) {
    return _ChildListItem(
      id: json['id'] as String,
      text: json['text'] as String,
      checked: json['checked'] as bool? ?? false,
    );
  }
}

class _ChildDashboardState extends State<ChildDashboard> {
  int _selectedIndex = 0;
  int _mood = 3;
  final List<_ChildListItem> _listItems = [];
  final TextEditingController _listItemController = TextEditingController();
  final FocusNode _listItemFocus = FocusNode();
  String? _loadedListUserId;

  @override
  void dispose() {
    _listItemController.dispose();
    _listItemFocus.dispose();
    super.dispose();
  }

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
            _buildListTab(),
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
            icon: Icon(Icons.checklist_outlined),
            activeIcon: Icon(Icons.checklist),
            label: 'Lista',
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

            _buildTodayPlanSection(
              slot: slot,
              events: events,
              custodianLabel: custodianLabel,
              handoverHint: handoverHint,
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

  Widget _buildTodayPlanSection({
    required CustodySlot? slot,
    required List<CalendarEvent> events,
    required String custodianLabel,
    required String? handoverHint,
  }) {
    final isParentA = slot?.custodian == UserRole.parentA;
    final planColor = slot == null
        ? AppTheme.textSecondary
        : (isParentA ? AppTheme.parentAColor : AppTheme.parentBColor);
    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    final hasPlan = slot != null || sortedEvents.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slot != null
            ? planColor.withValues(alpha: 0.16)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: slot != null
            ? Border.all(color: planColor.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: (slot != null ? planColor : AppTheme.childColor)
                .withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: planColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Plan na dziś',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: slot != null ? planColor : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (!hasPlan) ...[
            const SizedBox(height: 12),
            const Text(
              'Brak planu na dziś — rodzice mogą dodać coś w kalendarzu.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else ...[
            if (slot != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.home, color: planColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      custodianLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: planColor,
                      ),
                    ),
                  ),
                  if (slot.handoverTime != null)
                    Text(
                      'Przekazanie: ${slot.handoverTime}',
                      style: TextStyle(
                        fontSize: 12,
                        color: planColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (slot.handoverLocation != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: planColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slot.handoverLocation!,
                        style: TextStyle(
                          fontSize: 12,
                          color: planColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (handoverHint != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: planColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        handoverHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: planColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (sortedEvents.isNotEmpty) ...[
              if (slot != null) ...[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: planColor.withValues(alpha: 0.25),
                ),
              ],
              const SizedBox(height: 12),
              ...sortedEvents.map(
                (event) {
                  final timeLabel = formatEventTimeLabel(event.startDate);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: event.typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            event.typeIcon,
                            size: 16,
                            color: event.typeColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeLabel == null
                                    ? event.title
                                    : '$timeLabel  ${event.title}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (event.location != null &&
                                  event.location!.isNotEmpty)
                                Text(
                                  event.location!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildListTab() {
    final userId = context.watch<AppProvider>().currentUser?.id;
    if (userId != null && userId != _loadedListUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadList(userId));
    }

    final checkedCount = _listItems.where((item) => item.checked).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: AppTheme.childColor,
        title: const Row(
          children: [
            Text('📝', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Lista', style: TextStyle(color: Colors.white)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Material(
              elevation: 1,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.add,
                      color: AppTheme.childColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _listItemController,
                        focusNode: _listItemFocus,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Dodaj element listy…',
                          border: InputBorder.none,
                        ),
                        onSubmitted: _addListItem,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dodaj',
                      icon: const Icon(Icons.arrow_upward_rounded),
                      color: AppTheme.childColor,
                      onPressed: () => _addListItem(_listItemController.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_listItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$checkedCount / ${_listItems.length} gotowych',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _listItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.checklist_rtl,
                            size: 56,
                            color: AppTheme.childColor.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Twoja lista jest pusta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Wpisz coś powyżej — jak w Google Keep.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _listItems.length,
                    itemBuilder: (context, index) {
                      final item = _listItems[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeListItem(index),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.8)),
                          ),
                          child: CheckboxListTile(
                            value: item.checked,
                            activeColor: AppTheme.childColor,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: item.checked
                                    ? AppTheme.textHint
                                    : AppTheme.textPrimary,
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            onChanged: (value) => _toggleListItem(index, value ?? false),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadList(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('child_list_$userId');
    if (!mounted) {
      return;
    }

    setState(() {
      _listItems.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _listItems.addAll(
          decoded.map(
            (entry) => _ChildListItem.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          ),
        );
      }
      _loadedListUserId = userId;
    });
  }

  Future<void> _persistList() async {
    final userId = context.read<AppProvider>().currentUser?.id;
    if (userId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'child_list_$userId',
      jsonEncode(_listItems.map((item) => item.toJson()).toList()),
    );
  }

  void _addListItem(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _listItems.insert(
        0,
        _ChildListItem(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}',
          text: text,
        ),
      );
      _listItemController.clear();
    });
    _persistList();
    _listItemFocus.requestFocus();
  }

  void _toggleListItem(int index, bool checked) {
    setState(() => _listItems[index].checked = checked);
    _persistList();
  }

  void _removeListItem(int index) {
    setState(() => _listItems.removeAt(index));
    _persistList();
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
