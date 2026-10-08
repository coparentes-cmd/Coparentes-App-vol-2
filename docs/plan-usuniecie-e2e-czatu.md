# Plan: usunięcie E2E czatu → tylko KEY_MESSAGES

**Cel produktu:** niezawodnie działające Coparentes (uprościć szyfrowanie + auth, mniej bugów).

**Decyzja:** akceptujemy utratę czytelności **starych** wiadomości user (ciphertext E2E).  
**Sukces:** użytkownik korzysta z czatu **bez błędów** — otwiera wątek, pisze, czyta nowe wiadomości, bez unlock / recovery / „niedostępne” na nowej treści.

Źródła: Flutter `lib/` + backend `prisma` / `src/services/threads.js` / `serializers.js` / `routes/threads.js` / `user.js` / `authService.js`.

---

## Definicja sukcesu (Definition of Done)

Użytkownik (parentA, parentB, child) może:

1. Zalogować się **bez** generowania / odblokowywania kluczy E2E.
2. Otworzyć dowolny kanał / wątek czatu **bez** sheetu „Odblokuj czat”.
3. Wysłać i odebrać wiadomość tekstową (i załączniki jak dziś).
4. Nie widzieć błędów E2E (unlock failed, decryption failed, brak ThreadKey, family-sync).
5. Zmienić hasło **bez** wymogu `privateKeyEnvelope`.

Stare wiadomości E2E: mogą być ukryte lub oznaczone jako niedostępne historii — **nie** blokują czatu.

---

## Fazy (kolejność obowiązkowa)

### Faza 0 — UX / copy (zanim lub równolegle z F1)

| Zmiana UX | Szczegół |
|-----------|----------|
| Usunąć gate unlock | `ensureE2eUnlockedForChat` nie blokuje wejścia do wątku |
| Usunąć sheet unlock | `e2e_unlock_sheet` — brak hasła do czatu |
| Usunąć recovery E2E z ustawień / onboarding | brak „kod odzyskiwania czatu”, generowanie / odzyskanie klucza |
| Nowe wiadomości = zwykły tekst | bubble pokazuje `content`, bez async decrypt |
| Stara historia (opcjonalny komunikat jednorazowy) | np. pasek/info: „Starsze zaszyfrowane wiadomości nie są już dostępne” — bez błędu czerwonego |
| Stare bubbly E2E | nie pokazywać stacku błędów decrypt; ukryć lub jedna linia „niedostępna (archiwum)” |
| Auth | rejestracja / join / login dziecka — bez ciszy na recovery-key / setup keys (szybsze, mniej awarii) |
| Zmiana hasła | UI bez wzmianki o kluczach czatu |

**Kryterium UX:** zero ekranów E2E na ścieżce „otwórz czat → napisz → wyślij”.

---

### Faza 1 — Backend (kontrakt API)

| Krok | Plik / miejsce | Zmiana |
|------|----------------|--------|
| 1.1 | `POST /threads/:id/messages` | Przyjmować `content` (plaintext); przestać wymagać `ciphertext`+`nonce` |
| 1.2 | `addMessageToThread` | Zapisywać `encryptOptional(content, KEY_MESSAGES)` jak `addSystemMessageToThread` |
| 1.3 | `serializeMessage` | Dla nowych user messages zwracać `content`; stare JSON `{ciphertext,nonce}` → `content: null` + flaga np. `legacyE2e: true` **albo** puste content (klient ukrywa) |
| 1.4 | `POST /threads`, `POST /threads/channel` | `threadKeys` opcjonalne / ignorowane |
| 1.5 | `changeUserPassword` | Nie wymagać `newPrivateKeyEnvelope` gdy nie rewrapujemy E2E |
| 1.6 | Testy API | Nowy send/list bez ThreadKey; stary shape tylko read-tolerant |

**Nie usuwamy jeszcze** tabeli ThreadKey / `/user/keys` (martwy kod OK na ten PR) — cleanup w F3.

**Kryterium:** Postman/curl: create thread bez keys → send `content` → GET zwraca `content`.

---

### Faza 2 — Frontend (czat + auth)

| Krok | Obszar | Zmiana |
|------|--------|--------|
| 2.1 | `MessagingRepository` / remote | Send: body `{ content }` zamiast encrypt |
| 2.2 | `MessagingProvider` | Bez `_requireThreadKeys`, family-sync, decrypt pipeline dla nowych |
| 2.3 | Modele / serializers | Preferuj `content`; `needsDecryption` / `isE2E` → false dla nowego shape; legacy → ukryj/archiwum |
| 2.4 | UI | Usuń gate + unlock sheet z `thread_screen` / `inline_chat_panel` |
| 2.5 | `AppProvider` auth | Nie wołać `setupNewKeys` / unlock / recovery silent |
| 2.6 | Change password | Bez envelope w request |
| 2.7 | Settings / onboarding | Usuń flow recovery code E2E |
| 2.8 | Offline queue | Tylko plaintext content |

**Kryterium:** ręczne: login → Czat → napisz → druga osoba widzi tekst; zero snackbarów E2E.

---

### Faza 3 — Cleanup (po stabilizacji)

- Deprecacja / usunięcie: `POST/GET /user/keys*`, recovery-key, ThreadKey routes, `E2eSessionService` (lub zostawić dead code za flagą — preferencja: usunąć wywołania, potem pliki).
- Dokumentacja: zaktualizować E2E docs → „czat: KEY_MESSAGES at-rest”.
- Testy: skasować / przepisać testy E2E czatu.

---

## Rollout

1. Deploy **backend F1** (akceptuje `content`; opcjonalnie jeszcze stary ciphertext tylko jeśli trzeba — przy akceptacji utraty historii **nie trzeba** wspierać send ciphertext).
2. Deploy **frontend F2** (tylko `content`).
3. F3 po kilku dniach bez incydentów.

Unikać stanu: nowy front + stary backend wymagający ciphertext.

---

## Test plan (sukces = bez błędów)

- [ ] parentA: login → kanał Rodzina / Finanse / custom → send + receive
- [ ] parentB: to samo
- [ ] child: audience family → send + receive
- [ ] Załącznik (jeśli włączony) — bez E2E path
- [ ] Kanał systemowy „Zmiana grafiku” — bez regresji
- [ ] Zmiana hasła — sukces, ponowny login, czat działa
- [ ] Stare wiadomości E2E — brak crashy / czerwonych błędów (ukryte lub archiwum)
- [ ] Web + mobile (przynajmniej web + 1 mobile)
- [ ] Dwa urządzenia naraz — czat OK (bez unlock)

---

## Poza zakresem

- Migracja / odszyfrowanie starej historii E2E  
- Nowe funkcje czatu  
- Zmiana KEY_MESSAGES / modelu threat (świadomie: serwer widzi plaintext czatu)

---

## Ryzyka (zaakceptowane / do pilnowania)

| Ryzyko | Mitygacja |
|--------|-----------|
| Deploy front przed back | Kolejność F1 → F2 |
| Change password + stare envelope w DB | F1.5: nie wymagać envelope |
| Offline queue ze starym ciphertext | Wyczyścić / nie replay ciphertext |
| Użytkownicy pytają o starą historię | Copy UX o archiwum |

---

## Estymata kolejności PR

1. **PR-B1** — backend messages + serialize + threadKeys optional + password  
2. **PR-F1** — Flutter send/receive + UX gate/unlock off + legacy hide  
3. **PR-F2** — auth bez E2E + settings recovery off  
4. **PR-C1** — cleanup dead E2E (opcjonalnie później)
