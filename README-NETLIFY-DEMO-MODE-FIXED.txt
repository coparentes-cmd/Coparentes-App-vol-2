Frontend Flutter Web/PWA gotowy do wdrozenia na Netlify.
Naprawa po nieudanym buildzie:
- usunieto bledne const z trybu demo
- zachowany tryb demo dla wszystkich rol
- zachowane pokazywanie kodu zaproszenia rodzica

W Netlify ustaw (Railway backend — zweryfikowany /health OK):
COPARENTES_API_BASE_URL=https://coparentes-backend-production.up.railway.app/api

Lokalnie (debug build domyslnie laczy z localhost:3000):
flutter run -d chrome --dart-define=COPARENTES_API_BASE_URL=http://localhost:3000/api

Przyklad env: config/api.env.example
