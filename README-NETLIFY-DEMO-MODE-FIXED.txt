Frontend Flutter Web/PWA gotowy do wdrozenia na Netlify.
Naprawa po nieudanym buildzie:
- usunieto bledne const z trybu demo
- zachowany tryb demo dla wszystkich rol
- zachowane pokazywanie kodu zaproszenia rodzica

W Netlify ustaw (same-origin API — cookie sesji działa w Safari):
COPARENTES_API_BASE_URL=https://getcoparentes.app/api
COPARENTES_PUBLIC_URL=https://getcoparentes.app

Lokalnie (debug build domyslnie laczy z localhost:3000):
flutter run -d chrome --dart-define=COPARENTES_API_BASE_URL=http://localhost:3000/api

Przyklad env: config/api.env.example
