# Coparentes — aplikacja Flutter (PL)

Aplikacja web/PWA do współrodzicielstwa. Łączy się z backendem REST API.

---

## Wymagania

- Flutter SDK 3.x (`flutter doctor`)
- Działający backend — patrz [README.pl.md w repozytorum backend](../coparentes-backend-main/README.pl.md)

---

## Uruchomienie lokalna (krok po kroku)

### 1. Backend musi działać

```bash
cd ~/Desktop/coparentes-backend-main
npm run dev
```

Sprawdzenie: `curl http://localhost:3000/health` → `{"status":"ok"}`

### 2. Aplikacja Flutter

```bash
cd ~/Desktop/Coparentes-App-vol-2-main
flutter pub get
flutter run -d chrome
```

W trybie **debug** API URL to automatycznie `http://localhost:3000/api` (plik `lib/config/app_environment.dart`).

### 3. Testy

```bash
flutter analyze
flutter test
```

### 4. Tryb demo (bez backendu)

Na ekranie logowania wybierz **„Wypróbuj demo”** — dane przykładowe lokalnie, bez API.

---

## Build produkcyjny (Netlify)

```bash
flutter build web \
  --dart-define=COPARENTES_API_BASE_URL=https://TWOJ-BACKEND.up.railway.app/api
```

Wynik: katalog `build/web` (deploy na Netlify).

---

## Konfiguracja API

| Środowisko | URL API |
|------------|---------|
| Debug (domyślnie) | `http://localhost:3000/api` |
| Netlify / CI | `--dart-define=COPARENTES_API_BASE_URL=...` |
| Release bez dart-define | Railway production (hardcoded fallback) |

---

## Więcej informacji

Pełna instrukcja (backend + frontend + troubleshooting):  
[../coparentes-backend-main/README.pl.md](../coparentes-backend-main/README.pl.md)

---

## Dla użytkowników

**Jak założyć rodzinę, zaprosić drugiego rodzica i dodać dzieci:**  
[instrukcja krok po kroku](docs/instrukcja-nowa-rodzina.md) · **[pobierz PowerPoint](https://getcoparentes.app/downloads/instrukcja-nowa-rodzina.pptx)** · [strona pobierania](https://getcoparentes.app/downloads/)
