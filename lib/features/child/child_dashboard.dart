import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/calendar_date_utils.dart';
import '../../../utils/demo_time.dart';
import '../../../utils/app_browser_back.dart';
import '../../../config/messaging_categories.dart';
import '../../../l10n/locale_policy.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/messaging/messaging_screen.dart';
import 'widgets/child_todo_models.dart';
import 'widgets/mood_button.dart';
import 'package:coparentes/l10n/app_strings.dart';

class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  State<ChildDashboard> createState() => _ChildDashboardState();
}



class _ChildDashboardState extends State<ChildDashboard> {
  int _selectedIndex = 0;
  int _previousTabIndex = 0;
  final GlobalKey<MessagingScreenState> _messagingKey = GlobalKey();
  int _mood = 3;
  final List<ChildTodoList> _lists = [];
  String? _activeListId;
  final TextEditingController _listItemController = TextEditingController();
  final FocusNode _listItemFocus = FocusNode();
  String? _loadedListUserId;

  ChildTodoList? get _activeList {
    if (_activeListId == null) {
      return null;
    }
    for (final list in _lists) {
      if (list.id == _activeListId) {
        return list;
      }
    }
    return null;
  }

  List<ChildListItem> get _listItems => _activeList?.items ?? const [];

  @override
  void initState() {
    super.initState();
    registerBrowserBackHandler(_onBrowserBack);
  }

  @override
  void dispose() {
    unregisterBrowserBackHandler(_onBrowserBack);
    _listItemController.dispose();
    _listItemFocus.dispose();
    super.dispose();
  }

  bool _handleDashboardBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return true;
    }

    if (_selectedIndex == 2) {
      if (_messagingKey.currentState?.handleBack() ?? false) {
        return true;
      }
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = _previousTabIndex);
      return true;
    }

    return false;
  }

  bool _onBrowserBack() => _handleDashboardBack();

  void _navigateToTab(int index) {
    if (index != _selectedIndex) {
      _previousTabIndex = _selectedIndex;
      if (index != 0) {
        markBrowserHistoryForward();
      }
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final firstName = user?.name.split(' ').first ?? 'Zosiu';

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDashboardBack();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildTodayTab(context, firstName),
            const CalendarScreen(),
            MessagingScreen(
              key: _messagingKey,
              familyOnly: true,
              isTabActive: _selectedIndex == 2,
            ),
            _buildListTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _navigateToTab,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.childColor,
        unselectedItemColor: AppTheme.textHint,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: context.tr('Dzisiaj'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: context.tr('Kalendarz'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: familyCategoryDisplayLabel,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: context.tr('Lista'),
          ),
        ],
      ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Zmień profil')),
        content: Text(context.tr('Czy chcesz wrócić do ekranu wyboru profilu?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Nie')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.childColor,
            ),
            child: Text(context.tr('Tak, zmień')),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, String firstName) {
    final now = DemoTime.now();
    final locale = dateFormattingLocale(Localizations.localeOf(context));
    final dayLabel =
        '${DateFormat('EEEE', locale).format(now)} · ${DateFormat('d MMMM y', locale).format(now)}';
    final calendar = context.watch<CalendarProvider>();
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final slots = calendar.getSlotsForDay(now);
    final events = calendar.getEventsForDay(now);
    final slot = slots.isNotEmpty ? slots.first : null;
    final custodianLabel = _custodianLabel(slot?.custodian);
    final handoverHint = _handoverHint(slots, now, workspace);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — animated teal/blue/green gradient (CSS-parity)
              _AnimatedGradientHeader(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.tr('Cześć')}, $firstName! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.switch_account, color: Colors.white),
                      tooltip: context.tr('Zmień profil'),
                      onPressed: () => _showExitDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Lottie.asset(
                      'assets/lottie/running_fox.lottie',
                      width: 88,
                      height: 88,
                      repeat: true,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
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
                    Text(context.tr('Jak się dzisiaj czujesz?'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(context.tr('To tylko dla Ciebie – rodzice tego nie widzą 🔒'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        MoodButton(
                            emoji: '😢',
                            value: 1,
                            selected: _mood == 1,
                            onTap: () => setState(() => _mood = 1)),
                        MoodButton(
                            emoji: '😕',
                            value: 2,
                            selected: _mood == 2,
                            onTap: () => setState(() => _mood = 2)),
                        MoodButton(
                            emoji: '😊',
                            value: 3,
                            selected: _mood == 3,
                            onTap: () => setState(() => _mood = 3)),
                        MoodButton(
                            emoji: '😄',
                            value: 4,
                            selected: _mood == 4,
                            onTap: () => setState(() => _mood = 4)),
                        MoodButton(
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
    final baseColor = slot == null
        ? AppTheme.textSecondary
        : (isParentA ? AppTheme.parentAColor : AppTheme.parentBColor);
    // Soften fill for kids; keep accents readable. Does not change AppTheme globals.
    final planFill = Color.lerp(baseColor, Colors.white, 0.92)!;
    final planBorder = Color.lerp(baseColor, Colors.white, 0.72)!;
    const planTextColor = AppTheme.textPrimary;
    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    final hasPlan = slot != null || sortedEvents.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slot != null ? planFill : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: slot != null ? Border.all(color: planBorder) : null,
        boxShadow: [
          BoxShadow(
            color: (slot != null ? baseColor : AppTheme.childColor)
                .withValues(alpha: 0.08),
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
              Icon(Icons.today, color: planTextColor, size: 22),
              SizedBox(width: 8),
              Text(context.tr('Plan na dziś'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: planTextColor,
                ),
              ),
            ],
          ),
          if (!hasPlan) ...[
            SizedBox(height: 12),
            Text(context.tr('Brak planu na dziś — rodzice mogą dodać coś w kalendarzu.'),
              style: const TextStyle(
                fontSize: 14,
                color: planTextColor,
              ),
            ),
          ] else ...[
            if (slot != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.home, color: planTextColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      custodianLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: planTextColor,
                      ),
                    ),
                  ),
                  if (slot.handoverTime != null)
                    Text(
                      'Przekazanie: ${slot.handoverTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: planTextColor,
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
                      color: planTextColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slot.handoverLocation!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: planTextColor,
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
                      color: planTextColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        handoverHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: planTextColor,
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
                  color: AppTheme.dividerColor.withValues(alpha: 0.6),
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
                                  color: planTextColor,
                                ),
                              ),
                              if (event.location != null &&
                                  event.location!.isNotEmpty)
                                Text(
                                  event.location!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: planTextColor,
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLists(userId));
    }

    final activeList = _activeList;
    final checkedCount = _listItems.where((item) => item.checked).length;
    final listTitle = activeList?.title ?? 'Lista';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: AppTheme.childColor,
        title: Row(
          children: [
            const Text('📝', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                listTitle,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: Colors.white),
            tooltip: context.tr('Zmień profil'),
            onPressed: () => _showExitDialog(context),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lists.length > 1)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                itemCount: _lists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final list = _lists[index];
                  final selected = list.id == _activeListId;
                  return ChoiceChip(
                    label: Text(list.title),
                    selected: selected,
                    selectedColor: AppTheme.childColor.withValues(alpha: 0.22),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.childColor : AppTheme.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.childColor
                          : AppTheme.dividerColor.withValues(alpha: 0.9),
                    ),
                    onSelected: (_) => _switchList(list.id),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _showNewListDialog,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Nowa lista')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.childColor,
                side: BorderSide(color: AppTheme.childColor.withValues(alpha: 0.55)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _listItemController,
                        focusNode: _listItemFocus,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: context.tr('Dodaj element listy…'),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _addListItem,
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Dodaj'),
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
                          SizedBox(height: 16),
                          Text(
                            '$listTitle jest pusta',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(context.tr('Wpisz coś powyżej — jak w Google Keep.'),
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
                        key: ValueKey('${activeList?.id}_${item.id}'),
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
                            secondary: IconButton(
                              tooltip: context.tr('Edytuj'),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: AppTheme.childColor.withValues(alpha: 0.9),
                              ),
                              onPressed: () => _editListItem(index),
                            ),
                            onChanged: (value) =>
                                _toggleListItem(index, value ?? false),
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

  Future<void> _showNewListDialog() async {
    final titleController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Nowa lista')),
        content: TextField(
          controller: titleController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr('Tytuł listy'),
            hintText: context.tr('np. Szkoła, Zakupy, Na wakacje'),
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Anuluj')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.childColor,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Utwórz')),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    titleController.dispose();

    if (created != true || !mounted) {
      return;
    }

    _createNewList(title.isEmpty ? 'Lista ${_lists.length + 1}' : title);
  }

  void _createNewList(String title) {
    final list = ChildTodoList(
      id: 'list_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
    );

    setState(() {
      _lists.add(list);
      _activeListId = list.id;
      _listItemController.clear();
    });
    _persistLists();
    _listItemFocus.requestFocus();
  }

  void _switchList(String listId) {
    if (_activeListId == listId) {
      return;
    }

    setState(() {
      _activeListId = listId;
      _listItemController.clear();
    });
  }

  Future<void> _loadLists(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final listsRaw = prefs.getString('child_lists_$userId');
    if (!mounted) {
      return;
    }

    setState(() {
      _lists.clear();
      if (listsRaw != null && listsRaw.isNotEmpty) {
        final decoded = jsonDecode(listsRaw) as List<dynamic>;
        _lists.addAll(
          decoded.map(
            (entry) => ChildTodoList.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          ),
        );
      } else {
        final legacyRaw = prefs.getString('child_list_$userId');
        if (legacyRaw != null && legacyRaw.isNotEmpty) {
          final decoded = jsonDecode(legacyRaw) as List<dynamic>;
          _lists.add(
            ChildTodoList(
              id: 'list_default',
              title: 'Moja lista',
              items: decoded
                  .map(
                    (entry) => ChildListItem.fromJson(
                      Map<String, dynamic>.from(entry as Map),
                    ),
                  )
                  .toList(),
            ),
          );
        } else {
          _lists.add(
            ChildTodoList(
              id: 'list_default',
              title: 'Moja lista',
            ),
          );
        }
      }

      _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
      _loadedListUserId = userId;
    });

    if (listsRaw == null && prefs.getString('child_list_$userId') != null) {
      await _persistLists();
    }
  }

  Future<void> _persistLists() async {
    final userId = context.read<AppProvider>().currentUser?.id;
    if (userId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'child_lists_$userId',
      jsonEncode(_lists.map((list) => list.toJson()).toList()),
    );
  }

  void _addListItem(String value) {
    final activeList = _activeList;
    if (activeList == null) {
      return;
    }

    final text = value.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      activeList.items.insert(
        0,
        ChildListItem(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}',
          text: text,
        ),
      );
      _listItemController.clear();
    });
    _persistLists();
    _listItemFocus.requestFocus();
  }

  void _toggleListItem(int index, bool checked) {
    setState(() => _listItems[index].checked = checked);
    _persistLists();
  }

  Future<void> _editListItem(int index) async {
    if (index < 0 || index >= _listItems.length) {
      return;
    }

    final item = _listItems[index];
    final controller = TextEditingController(text: item.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Edytuj element')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: context.tr('Treść elementu'),
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Anuluj')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.childColor,
            ),
            child: Text(context.tr('Zapisz')),
          ),
        ],
      ),
    );

    final text = controller.text.trim();
    controller.dispose();
    if (saved != true || !mounted) {
      return;
    }
    if (text.isEmpty || text == item.text) {
      return;
    }
    if (index >= _listItems.length || _listItems[index].id != item.id) {
      return;
    }

    setState(() => _listItems[index].text = text);
    await _persistLists();
  }

  void _removeListItem(int index) {
    final activeList = _activeList;
    if (activeList == null) {
      return;
    }

    setState(() => activeList.items.removeAt(index));
    _persistLists();
  }

  /// Same wording as calendar [SelectedDayCard]: Mama = parentA, Tata = parentB.
  String _custodianLabel(UserRole? role) {
    if (role == null) {
      return context.tr('Brak informacji');
    }
    if (role == UserRole.parentA) {
      return context.tr('U Mamy');
    }
    if (role == UserRole.parentB) {
      return context.tr('U Taty');
    }
    return context.tr('Brak informacji');
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
    final tomorrowSlots =
        context.read<CalendarProvider>().getSlotsForDay(tomorrow);
    if (tomorrowSlots.isEmpty || slot == null) {
      return null;
    }

    final tomorrowSlot = tomorrowSlots.first;
    if (tomorrowSlot.custodian == slot.custodian) {
      return null;
    }

    final nextParent = _custodianLabel(tomorrowSlot.custodian);
    return 'Jutro: $nextParent';
  }
}

/// Child greeting card: CSS-like animated gradient
/// (`linear-gradient(45deg, #22c995, #1672d9, #4f9535)`, 8s ease infinite).
class _AnimatedGradientHeader extends StatefulWidget {
  const _AnimatedGradientHeader({required this.child});

  final Widget child;

  @override
  State<_AnimatedGradientHeader> createState() =>
      _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends State<_AnimatedGradientHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _colors = [
    Color(0xFF22C995),
    Color(0xFF1672D9),
    Color(0xFF4F9535),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Mimic background-position: 0% 50% → 100% 50% → 0% 50% with ease.
        final t = _controller.value;
        final progress = t <= 0.5
            ? Curves.easeInOut.transform(t * 2)
            : Curves.easeInOut.transform(2 - t * 2);
        final shift = progress * 2 - 1; // -1 … 1

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              // ~45deg, oversized travel like background-size: 200% 200%
              begin: Alignment(-1.5 + shift, -1.0),
              end: Alignment(1.5 + shift, 1.0),
              colors: _colors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
