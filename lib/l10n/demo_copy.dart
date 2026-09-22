/// English titles for the original demo seed only. Unknown ids are left untouched.
class DemoCopy {
  static const _eventTitles = <String, String>{
    'evt_demo_1': 'Breakfast',
    'evt_demo_2': 'English – Zosia',
    'evt_demo_3': 'Dentist – Tomek',
    'evt_demo_4': 'Football practice',
    'evt_demo_5': 'Family dinner',
  };

  static const _eventTitlesPl = <String, String>{
    'evt_demo_1': 'Śniadanie',
    'evt_demo_2': 'Angielski – Zosia',
    'evt_demo_3': 'Dentysta – Tomek',
    'evt_demo_4': 'Trening piłki',
    'evt_demo_5': 'Kolacja rodzinna',
  };

  static const _eventLocations = <String, String>{
    'evt_demo_1': 'Home',
    'evt_demo_3': 'City clinic',
    'evt_demo_4': 'School pitch',
    'evt_demo_5': 'Home',
  };

  static const _eventLocationsPl = <String, String>{
    'evt_demo_1': 'Dom',
    'evt_demo_3': 'Przychodnia Centrum',
    'evt_demo_4': 'Boisko szkolne',
    'evt_demo_5': 'Dom',
  };

  static const _expenseTitles = <String, String>{
    'exp_001': 'Dentist visit – Zosia',
    'exp_002': 'School textbooks',
    'exp_003': 'Swimming lessons – Tomek (March)',
    'exp_004': 'Winter boots – Zosia',
    'exp_005': 'School trip',
    'exp_006': 'Medicine – Tomek (infection)',
  };

  static const _expenseTitlesPl = <String, String>{
    'exp_001': 'Wizyta u dentysty – Zosia',
    'exp_002': 'Podręczniki szkolne',
    'exp_003': 'Treningi pływania – Tomek (marzec)',
    'exp_004': 'Zimowe buty – Zosia',
    'exp_005': 'Wycieczka szkolna',
    'exp_006': 'Leki – Tomek (infekcja)',
  };

  static const _expenseNotes = <String, String>{
    'exp_001': 'Two fillings',
    'exp_004': 'Dispute: amount above the agreed limit',
  };

  static const _expenseNotesPl = <String, String>{
    'exp_001': 'Plombowanie 2 zębów',
    'exp_004': 'Spór: kwota powyżej limitu uzgodnionego',
  };

  /// Custom thread subjects only. Channel ids (Rodzina, Wszystkie, …) stay Polish.
  static const _threadSubjects = <String, String>{
    'thread_demo_001': 'English – schedule change',
    'thread_demo_002': 'Dentist visit – Zosia',
    'thread_demo_vacations': 'Holidays',
    'thread_demo_school_year': 'Start of the school year',
  };

  static const _threadSubjectsPl = <String, String>{
    'thread_demo_001': 'Angielski – zmiana terminu',
    'thread_demo_002': 'Wizyta u dentysty – Zosia',
    'thread_demo_vacations': 'Wakacje',
    'thread_demo_school_year': 'Początek roku szkolnego',
  };

  static const _messageContents = <String, String>{
    'msg_demo_family_001': 'Remember dinner at 18:30!',
    'msg_demo_001':
        'Can we move English from Tuesday to Wednesday at 17:00?',
    'msg_demo_002':
        'I confirm the appointment on Friday at 10:30. I added the receipt to finances.',
    'msg_demo_vacations_001':
        'I suggest a trip to the seaside in the first week of August. What do you think?',
    'msg_demo_vacations_002':
        '3–10 August works for me. I can take the kids on the road on Saturday morning.',
    'msg_demo_school_year_001':
        'The new year starts in September. Let’s decide who buys school supplies and who goes to the opening day.',
    'msg_demo_school_year_002':
        'I’ll take Zosia’s supplies, you take Tomek’s. I’ll go to the opening with Zosia — OK?',
  };

  static const _messageContentsPl = <String, String>{
    'msg_demo_family_001': 'Pamietajcie o kolacji o 18:30!',
    'msg_demo_001':
        'Czy mozemy przeniesc angielski z wtorku na srode o 17:00?',
    'msg_demo_002':
        'Potwierdzam wizyte w piatek o 10:30. Dolozylam paragon do finansow.',
    'msg_demo_vacations_001':
        'Proponuję wyjazd nad morze w pierwszym tygodniu sierpnia. Co myślisz?',
    'msg_demo_vacations_002':
        'Pasuje mi 3–10 sierpnia. Mogę zabrać dzieci na drogę w sobotę rano.',
    'msg_demo_school_year_001':
        'We wrześniu zaczyna się nowy rok. Ustalmy, kto kupuje wyprawkę i kto idzie na rozpoczęcie.',
    'msg_demo_school_year_002':
        'Ja biorę wyprawkę Zosi, Ty Tomka. Na rozpoczęcie idę z Zosią — OK?',
  };

  static const _swapReasons = <String, String>{
    'swap_001': 'Business trip to Krakow',
    'swap_002': 'Grandma’s birthday',
  };

  static const _swapReasonsPl = <String, String>{
    'swap_001': 'Wyjazd służbowy do Krakowa',
    'swap_002': 'Urodziny babci',
  };

  static const _swapResponseNotes = <String, String>{
    'swap_002': 'Of course, no problem.',
  };

  static const _swapResponseNotesPl = <String, String>{
    'swap_002': 'Oczywiście, bez problemu.',
  };

  static const workspaceDemoId = 'workspace_demo_001';
  static const workspaceNamePl = 'Rodzina Kowalskich — demo';
  static const workspaceNameEn = 'Kowalski family — demo';

  static bool isDemoEvent(String id) => _eventTitlesPl.containsKey(id);

  static bool isDemoExpense(String id) => _expenseTitlesPl.containsKey(id);

  static bool isDemoThread(String id) =>
      _threadSubjectsPl.containsKey(id) ||
      id == 'thread_demo_all' ||
      id == 'thread_demo_family' ||
      id == 'thread_demo_schedule';

  static bool isDemoMessage(String id) => _messageContentsPl.containsKey(id);

  static bool isDemoSwap(String id) => _swapReasonsPl.containsKey(id);

  static String eventTitle(String id, String languageCode) {
    if (languageCode == 'en') {
      return _eventTitles[id] ?? _eventTitlesPl[id] ?? '';
    }
    return _eventTitlesPl[id] ?? '';
  }

  static String? eventLocation(String id, String languageCode) {
    if (!_eventLocationsPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _eventLocations[id];
    }
    return _eventLocationsPl[id];
  }

  static String expenseTitle(String id, String languageCode) {
    if (languageCode == 'en') {
      return _expenseTitles[id] ?? _expenseTitlesPl[id] ?? '';
    }
    return _expenseTitlesPl[id] ?? '';
  }

  static String? expenseNote(String id, String languageCode) {
    if (!_expenseNotesPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _expenseNotes[id];
    }
    return _expenseNotesPl[id];
  }

  /// Returns null when the subject is a channel id (must stay Polish).
  static String? threadSubject(String id, String languageCode) {
    if (!_threadSubjectsPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _threadSubjects[id];
    }
    return _threadSubjectsPl[id];
  }

  static String? messageContent(String id, String languageCode) {
    if (!_messageContentsPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _messageContents[id];
    }
    return _messageContentsPl[id];
  }

  static String? swapReason(String id, String languageCode) {
    if (!_swapReasonsPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _swapReasons[id];
    }
    return _swapReasonsPl[id];
  }

  static String? swapResponseNote(String id, String languageCode) {
    if (!_swapResponseNotesPl.containsKey(id)) {
      return null;
    }
    if (languageCode == 'en') {
      return _swapResponseNotes[id];
    }
    return _swapResponseNotesPl[id];
  }

  static String workspaceName(String languageCode) {
    return languageCode == 'en' ? workspaceNameEn : workspaceNamePl;
  }
}
