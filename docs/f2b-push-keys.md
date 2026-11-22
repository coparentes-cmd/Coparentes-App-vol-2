# F2b — gdzie wkleić klucze push (Firebase / APNs)

Bez tych plików aplikacja **działa lokalnie** na stubie `sim-stub-ios` / `sim-stub-android`
(rejestracja tokena w API nadal przechodzi). Prawdziwe powiadomienia wymagają kluczy poniżej.

## Front (iOS)

1. Firebase Console → Project settings → Your apps → iOS → pobierz **`GoogleService-Info.plist`**
2. Skopiuj do: `ios/Runner/GoogleService-Info.plist`
3. Plik jest w `.gitignore` — **nie commituj**

## Front (Android, później)

1. Ten sam projekt Firebase → Android app → **`google-services.json`**
2. Skopiuj do: `android/app/google-services.json`
3. Też w `.gitignore`

## Backend (wysyłka FCM)

W `coparentes-backend-f3` lokalne `.env` (nie commitować):

```bash
# wariant A — całość JSON w jednej linii
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

# albo wariant B — ścieżka do pliku
FIREBASE_SERVICE_ACCOUNT_FILE=/absolute/path/to/serviceAccountKey.json
```

Szablon: `.env.example` (sekcja Firebase).

Bez tego backend **nie rzuca** — loguje stub i nie wysyła prawdziwych pushy.

## Apple (APNs → Firebase)

1. Apple Developer → Keys → Key z **Apple Push Notifications service (APNs)**
2. Firebase Console → Project settings → Cloud Messaging → Apple app configuration → wklej Key ID / Team ID / `.p8`
3. W Xcode: Signing & Capabilities → **Push Notifications** (+ Background Modes → Remote notifications już w `Info.plist`)

## Smoke bez kluczy (teraz)

1. Backend lokalnie z API `POST/DELETE /api/user/push-token`
2. `flutter run` na symulatorze iOS
3. Po zalogowaniu (nie demo) w logach / DB powinien pojawić się token `sim-stub-ios`
4. Wylogowanie → `DELETE` tego tokena

## Smoke z kluczami (Ty potem)

1. Wklej `GoogleService-Info.plist` + service account na backendzie + APNs w Firebase
2. Rebuild na **fizycznym iPhonie** (symulator często nie dostaje prawdziwego APNs)
3. Wywołaj wewnętrzny cron D−3 / test send i sprawdź baner na urządzeniu
