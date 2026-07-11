# Checklist — web release (getcoparentes.app)

Uruchom na **produkcji** po deploy backend security + frontend launch PR.

## Infra (przed smoke)

- [ ] Railway: `npm run db:migrate` wykonane po deploy backendu (sesje unieważnione — użytkownicy logują się ponownie)
- [ ] Railway env: `NODE_ENV=production`, `FRONTEND_URL`, `CORS_ORIGINS`, klucze szyfrowania, `INTEGRITY_SECRET`, Resend
- [ ] Netlify: `COPARENTES_API_BASE_URL` + `COPARENTES_PUBLIC_URL=https://getcoparentes.app`
- [ ] `curl https://coparentes-backend-production.up.railway.app/health` → OK

## Rejestracja i auth

- [ ] Rejestracja Parent A + 6 zgód
- [ ] Logowanie z hasłem
- [ ] 2FA OTP (email Resend) — jeśli włączone
- [ ] Odświeżenie strony (F5) → nadal zalogowany (cookie session)
- [ ] Wylogowanie czyści sesję
- [ ] Dołączenie Parent B kodem zaproszenia
- [ ] Dołączenie dziecka (PIN + data urodzenia)

## Core flows

- [ ] Wiadomość w „Wszystkie” (ogólny + własny wątek)
- [ ] Wyszukiwanie `tag:paragon` w „Wszystkie”
- [ ] Wiadomość w „Rodzina” i „Zmiana grafiku”
- [ ] Załącznik do wiadomości
- [ ] Wydarzenie w kalendarzu
- [ ] Wydatek w finansach
- [ ] Eksport PDF + pobranie w Chrome

## Dziecko i observer

- [ ] Dziecko: logowanie, czat Rodzina, szybka odpowiedź
- [ ] Observer: brak pola do pisania, podgląd wątków

## Ustawienia i zgodność

- [ ] Brak sekcji subskrypcji / fałszywego „Ostatnie logowanie”
- [ ] Brak placeholder dialogów regulamin / polityka w ustawieniach
- [ ] „Pobierz dane RODO” → otwiera mailto do supportu
- [ ] „Usuń konto” → otwiera mailto do supportu

## Demo (bez zmian — musi działać)

- [ ] Tryb demo na ekranie logowania — wszystkie 4 role
- [ ] Demo działa bez backendu (lokalne dane)

## CI / deploy

- [ ] `flutter test` zielone
- [ ] `flutter build web --release` zielone (GitHub Actions)
- [ ] Netlify production deploy Published po merge na `main`

## Po smoke

- [ ] Krótka informacja dla beta użytkowników o możliwym ponownym logowaniu (migracja sesji)
- [ ] Zaproszenie pierwszych rodzin pilota
