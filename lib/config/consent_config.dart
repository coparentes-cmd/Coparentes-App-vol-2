import '../config/legal_config.dart';
import '../data/models/user_consent.dart';

class ConsentDefinition {
  final ConsentType type;
  final String title;
  final String description;
  final List<ConsentExpandBlock> expandBlocks;

  const ConsentDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.expandBlocks,
  });
}

class ConsentExpandBlock {
  final String? text;
  final String? linkLabel;
  final String? linkUrl;

  const ConsentExpandBlock.text(this.text)
      : linkLabel = null,
        linkUrl = null;

  const ConsentExpandBlock.link({
    required this.linkLabel,
    required this.linkUrl,
  }) : text = null;
}

class ConsentConfig {
  static const version = '1.0.0';

  static List<ConsentDefinition> get registrationConsents => [
    ConsentDefinition(
      type: ConsentType.terms,
      title: 'Regulamin i polityka prywatności',
      description:
          'Akceptujesz regulamin korzystania z serwisu Coparentes oraz politykę '
          'prywatności określającą sposób przetwarzania Twoich danych.',
      expandBlocks: [
        ConsentExpandBlock.link(
          linkLabel: 'Regulamin',
          linkUrl: LegalConfig.termsUrl,
        ),
        ConsentExpandBlock.link(
          linkLabel: 'Polityka prywatności',
          linkUrl: LegalConfig.privacyUrl,
        ),
        ConsentExpandBlock.text(
          'Zbieramy imię, adres e-mail, dane konta oraz informacje wprowadzane do '
          'aplikacji (kalendarz, wiadomości, finanse) wyłącznie w celu świadczenia '
          'usług Coparentes i zapewnienia bezpieczeństwa Twojej rodziny.',
        ),
      ],
    ),
    ConsentDefinition(
      type: ConsentType.dataProcessing,
      title: 'Przetwarzanie danych osobowych',
      description:
          'Wyrażasz zgodę na przetwarzanie Twoich danych osobowych (imię, e-mail, '
          'dane konta) przez ${LegalConfig.companyName} z siedzibą w Łodzi, '
          'w celu świadczenia usług aplikacji.',
      expandBlocks: [
        ConsentExpandBlock.text(
          'Podstawa prawna: art. 6 ust. 1 lit. b RODO (wykonanie umowy). '
          'Dane przechowujemy przez czas trwania konta oraz do 30 dni po jego '
          'usunięciu, chyba że przepisy wymagają dłuższego okresu. '
          'Administrator: ${LegalConfig.companyName}, ${LegalConfig.companyAddress}. '
          'Kontakt: ${LegalConfig.supportEmail}.',
        ),
      ],
    ),
    ConsentDefinition(
      type: ConsentType.childData,
      title: 'Przetwarzanie danych dotyczących dziecka',
      description:
          'Wyrażasz zgodę na przetwarzanie danych dziecka wprowadzonych do '
          'aplikacji (imię, kalendarz opieki, zdrowie, szkoła) wyłącznie w celu '
          'świadczenia usług Coparentes.',
      expandBlocks: [
        ConsentExpandBlock.text(
          'Podstawa prawna: art. 9 ust. 2 lit. a RODO (wyraźna zgoda na dane '
          'szczególnej kategorii). Dane zdrowotne są szyfrowane osobno i nigdy '
          'nie są udostępniane podmiotom trzecim.',
        ),
      ],
    ),
    ConsentDefinition(
      type: ConsentType.emailNotifications,
      title: 'Powiadomienia e-mail',
      description:
          'Zgadzasz się na otrzymywanie powiadomień e-mail dotyczących '
          'aktywności w aplikacji (nowe wiadomości, zmiany w kalendarzu, przypomnienia).',
      expandBlocks: [
        ConsentExpandBlock.text(
          'Wysyłamy e-maile o: nowych wiadomościach, zmianach w kalendarzu opieki, '
          'wnioskach o zamianę terminów, przypomnieniach o wydarzeniach oraz '
          'ważnych alertach bezpieczeństwa konta. Zgodę możesz wycofać w '
          'Ustawieniach → Prywatność w dowolnym momencie.',
        ),
      ],
    ),
    ConsentDefinition(
      type: ConsentType.marketing,
      title: 'Komunikacja marketingowa',
      description:
          'Zgadzasz się na otrzymywanie informacji o nowościach, '
          'aktualizacjach i ofertach Coparentes na podany adres e-mail.',
      expandBlocks: [
        ConsentExpandBlock.text(
          'E-maile marketingowe wysyłamy maksymalnie raz w miesiącu. '
          'W każdej wiadomości znajdziesz link do wypisania się. '
          'Ta zgoda jest niezależna od powiadomień związanych z działaniem aplikacji.',
        ),
      ],
    ),
    ConsentDefinition(
      type: ConsentType.analytics,
      title: 'Analityka i ulepszanie aplikacji',
      description:
          'Pozwalasz na zbieranie anonimowych danych o sposobie korzystania '
          'z aplikacji w celu jej ulepszania. Dane nie są powiązane z Twoim kontem.',
      expandBlocks: [
        ConsentExpandBlock.text(
          'Korzystamy z anonimowej analityki produktowej (np. PostHog w trybie '
          'prywatności). Zbieramy wyłącznie: wyświetlenia ekranów i zdarzenia '
          'interfejsu — bez danych osobowych i bez treści wiadomości. '
          'Wyłączenie możliwe w Ustawieniach → Prywatność.',
        ),
      ],
    ),
  ];
}