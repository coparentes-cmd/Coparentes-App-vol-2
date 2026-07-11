# Smoke checklist — refaktoryzacja Coparentes

Uruchom po każdym PR dotykającym czatu, providerów messaging lub repository.

## Rodzic (parentA lub parentB)

- [ ] Logowanie bez błędu
- [ ] **Wszystkie** — ogólny czat (bez wyboru wątku): wysyłka wiadomości
- [ ] **Wszystkie** — utworzenie własnego wątku i wysyłka w nim
- [ ] **Wszystkie** — dodanie/usunięcie etykiety na wiadomości
- [ ] **Wszystkie** — wyszukiwanie `tag:paragon`
- [ ] **Rodzina** — wysyłka wiadomości
- [ ] **Zmiana grafiku** — wysyłka wiadomości
- [ ] Załącznik do wiadomości (max 256 KB)

## Dziecko

- [ ] Logowanie kodem rodziny + PIN/datę urodzenia
- [ ] **Rodzina** — wysyłka wiadomości tekstowej
- [ ] **Rodzina** — szybka odpowiedź (chip)
- [ ] Brak paska AI Coach na **Dzisiaj** i w czacie

## Observer

- [ ] Logowanie
- [ ] Brak pola do pisania wiadomości
- [ ] Podgląd wątków / kalendarza

## Offline / synchronizacja (gdy PR dotyka repository)

- [ ] Wysłanie wiadomości offline → odświeżenie → synchronizacja
- [ ] Brak duplikatów wiadomości po sync

## Automatyczne (przed merge)

- [ ] `flutter analyze` — bez błędów
- [ ] `flutter test` — wszystkie testy zielone
- [ ] Backend `npm test` — jeśli PR dotyka API
