import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/layout_utils.dart';

class ImmutableBadge extends StatelessWidget {
  const ImmutableBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.immutableBadge.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.immutableBadge.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 10, color: AppTheme.immutableBadge),
          SizedBox(width: 3),
          Text(
            'Niezmienialny',
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.immutableBadge,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AiDisclaimerBanner extends StatelessWidget {
  const AiDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.yellowColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, size: 14, color: Color(0xFFF57F17)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'AI może się mylić. Zawsze sprawdź sugestię przed wysłaniem.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF57F17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class HashIntegrityFooter extends StatelessWidget {
  final String hash;

  const HashIntegrityFooter({super.key, required this.hash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint, size: 12, color: AppTheme.textHint),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'SHA-256: ${hash.substring(0, hash.length > 20 ? 20 : hash.length)}...',
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textHint,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contextual AI Tip Banner ─────────────────────────────────────────────────
/// Shows a rotating contextual AI tip for the given [context] (screen).
/// [tips] is a list of maps with keys 'icon' (emoji), 'title', 'body'.
/// Rotates automatically every [intervalSeconds] seconds.
class AiContextualTip extends StatefulWidget {
  final List<Map<String, String>> tips;
  final int intervalSeconds;
  final bool dismissible;

  const AiContextualTip({
    super.key,
    required this.tips,
    this.intervalSeconds = 6,
    this.dismissible = true,
  });

  @override
  State<AiContextualTip> createState() => _AiContextualTipState();
}

class _AiContextualTipState extends State<AiContextualTip>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _dismissed = false;
  Timer? _timer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    if (widget.tips.length > 1) {
      _timer = Timer.periodic(
        Duration(seconds: widget.intervalSeconds),
        (_) => _nextTip(),
      );
    }
  }

  void _nextTip() async {
    if (!mounted) return;
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _index = (_index + 1) % widget.tips.length;
    });
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || widget.tips.isEmpty) return const SizedBox.shrink();
    final tip = widget.tips[_index];
    final compact = isCompactPhoneLayout(context);
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: compact ? 2 : 4),
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 7 : 10,
          compact ? 6 : 8,
          compact ? 7 : 10,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryTeal, AppTheme.accentColor, AppTheme.coralColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withValues(alpha: compact ? 0.16 : 0.22),
              blurRadius: compact ? 6 : 8,
              offset: Offset(0, compact ? 2 : 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tip['icon'] ?? '🤖',
              style: TextStyle(fontSize: compact ? 18 : 22),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white70,
                        size: compact ? 10 : 11,
                      ),
                      SizedBox(width: compact ? 3 : 4),
                      Text(
                        'AI Coach',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (widget.tips.length > 1)
                        Row(
                          children: List.generate(widget.tips.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              width: i == _index ? (compact ? 12 : 14) : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? Colors.white
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 2 : 3),
                  Text(
                    tip['title'] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 1 : 2),
                  Text(
                    tip['body'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: compact ? 10 : 11,
                      height: 1.3,
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.dismissible)
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Padding(
                  padding: EdgeInsets.only(left: compact ? 4 : 6, top: 2),
                  child: Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: compact ? 14 : 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Static contextual tip collections ────────────────────────────────────────

class AiTips {
  // Dashboard tips
  static const List<Map<String, String>> dashboard = [
    {
      'icon': '🧠',
      'title': 'Zacznij dzień z AI Coach',
      'body':
          'Przed każdą wiadomością do drugiego rodzica AI Coach oceni jej ton. Mniej napięcia, więcej współpracy.',
    },
    {
      'icon': '📅',
      'title': 'Zaplanuj zmianę terminu z wyprzedzeniem',
      'body':
          'Złóż wniosek o swap min. 72h przed terminem – drugi rodzic ma czas na decyzję, a zapis zostaje w logach.',
    },
    {
      'icon': '💰',
      'title': 'Dokumentuj każdy wydatek',
      'body':
          'Zdjęcie paragonu + opis wydatku = dowód gotowy do sądu. Używaj kategorii, by ułatwić rozliczenie.',
    },
    {
      'icon': '🛡️',
      'title': 'AI Shield – Twoja tarcza',
      'body':
          'Toksyczne wiadomości są automatycznie filtrowane. Widzisz wersję logistyczną, oryginał jest archiwizowany.',
    },
  ];

  /// Coaching copy shown as rotating placeholders in the message input.
  static List<String> get messagingPlaceholders => messaging
      .map((tip) => tip['body'] ?? '')
      .where((text) => text.isNotEmpty)
      .toList();

  // Messaging tips
  static const List<Map<String, String>> messaging = [
    {
      'icon': '✍️',
      'title': 'Pisz o faktach, nie ocenach',
      'body':
          'Np. „W dn. 12.03 odbiór nastąpił o 17:30" zamiast „Zawsze się spóźniasz". AI Coach zasygnalizuje napięty ton przed wysłaniem.',
    },
    {
      'icon': '🎯',
      'title': 'Centruj komunikat na dziecku',
      'body':
          '„Dla Zosi byłoby lepiej, gdyby..." działa lepiej niż „Chcę, żebyś...". Dziecko, nie konflikt, jest w centrum.',
    },
    {
      'icon': '⏱️',
      'title': 'Odpowiadaj w ciągu 24h',
      'body':
          'Szybka odpowiedź pokazuje dobrą wolę i buduje pozytywną historię komunikacji – widoczną dla sądu.',
    },
    {
      'icon': '📎',
      'title': 'Używaj wątków tematycznych',
      'body':
          'Oddzielne wątki (szkoła, zdrowie, finanse) ułatwiają późniejszy eksport dowodów dla konkretnej sprawy.',
    },
  ];

  // Calendar / custody swap tips
  static List<String> get calendarPlaceholders => calendar
      .map((tip) => tip['body'] ?? '')
      .where((text) => text.isNotEmpty)
      .toList();

  static const List<Map<String, String>> calendar = [
    {
      'icon': '🔄',
      'title': 'Wnioskuj o swap z wyprzedzeniem',
      'body':
          'Im wcześniej złożysz wniosek, tym większa szansa na akceptację. Każda decyzja jest logowana z datą i godziną.',
    },
    {
      'icon': '📋',
      'title': 'Opisz powód zmiany',
      'body':
          'Krótki, neutralny opis powodu (np. „wyjazd służbowy") ułatwia drugiemu rodzicowi podjęcie decyzji.',
    },
    {
      'icon': '🎉',
      'title': 'Pamiętaj o świętach',
      'body':
          'Zaplanuj podział świąt z wyprzedzeniem – plan wakacyjny i świąteczny możesz ustalić jednorazowo na cały rok.',
    },
  ];

  // Finance tips
  static const List<Map<String, String>> finance = [
    {
      'icon': '📸',
      'title': 'Zdjęcie = dowód',
      'body':
          'Dodaj zdjęcie paragonu lub faktury do każdego wydatku. Brak dokumentu = trudniejsze dochodzenie zwrotu.',
    },
    {
      'icon': '📊',
      'title': 'Śledź podział kosztów',
      'body':
          'Ustal procentowy podział (np. 50/50 lub 60/40) i trzymaj się go konsekwentnie. Eksport zestawienia miesięcznego jest jednym kliknięciem.',
    },
    {
      'icon': '⏰',
      'title': 'Zgłaszaj wydatki na bieżąco',
      'body':
          'Wydatki zgłoszone po terminie są trudniejsze do weryfikacji. Dodawaj je maksymalnie w ciągu 7 dni.',
    },
  ];

  // Child tips (age-appropriate)
  static const List<Map<String, String>> child = [
    {
      'icon': '💬',
      'title': 'Możesz poprosić o cokolwiek',
      'body':
          'Napisz prośbę do mamy lub taty – oni ją zobaczą i odpiszą. Możesz prosić o odbiór, zakup albo cokolwiek innego.',
    },
    {
      'icon': '🎒',
      'title': 'Pamiętaj o plecaku!',
      'body':
          'Zaznaczaj rzeczy, które spakujesz. Gdy wszystko jest zaznaczone – jesteś gotowy/-a!',
    },
    {
      'icon': '😊',
      'title': 'Jak się czujesz dziś?',
      'body':
          'Zaznacz nastrój na dole ekranu. Twoi rodzice mogą zobaczyć, czy jesteś szczęśliwy/-a lub potrzebujesz pomocy.',
    },
  ];
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Binds Enter to an accept action when this scope has focus.
class EnterAcceptScope extends StatelessWidget {
  final Widget child;
  final VoidCallback? onAccept;
  final bool enabled;
  final bool autofocus;

  const EnterAcceptScope({
    super.key,
    required this.child,
    this.onAccept,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || onAccept == null) {
      return child;
    }

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter): onAccept!,
      },
      child: Focus(
        autofocus: autofocus,
        child: child,
      ),
    );
  }
}
