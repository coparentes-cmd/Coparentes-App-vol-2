# Brief: popup cookies Coparentes → aplikacja

Cel: zaimplementować w aplikacji ten sam mechanizm i wygląd cookie popup, który jest na landing / motywie strony (`coparentes.ai` / repo `coparentes-site`).

**Źródło prawdy (wdrażać TO):**
- markup: `#cookieConsent` w HTML (np. `index.html`)
- logika: `js/main.js` (sekcja cookie)
- style: `css/style.css` (klasy `.cookie-consent*`) + drobne reguły w `css/mobile.css`

**Uwaga o live WP:** na `coparentes.ai` działa też plugin **Complianz**. Do aplikacji **nie kopiować Complianz** — brać własny banner z tematu / HTML landingu.

---

## Jak wygląda

- Fixed na dole ekranu (`bottom` + `safe-area-inset-bottom`), `z-index: 1400`, marginesy ~18px (na ≤920px: 12px).
- Biała karta: `border-radius: 24px`, lekki blur, cień.
- Pasek u góry karty — gradient: emerald `#00c896` → electric `#0080ff` → coral `#ff6b68`.

### Widok startowy (zwinięty)
- Tytuł: **Szanujemy Twoją prywatność**
- Tekst o cookies niezbędnych + opcjonalnych (funkcjonalne, analityczne, marketingowe)
- Linki: Polityka prywatności, Regulamin
- 3 przyciski:
  1. **Akceptuję wszystkie** (primary)
  2. **Odrzuć opcjonalne** (outline)
  3. **Ustawienia** (ghost)

### Widok rozwinięty (po „Ustawienia”)
- **Niezbędne** — badge „Zawsze aktywne” (bez switcha)
- **Funkcjonalne** / **Analityczne** / **Marketingowe** — toggle
- Przycisk **Zapisz wybór** (widoczny w trybie ustawień; wtedy chowa się „Ustawienia”)

---

## Jak działa

### Storage
- Klucz: `localStorage['coparentes_cookie_consent_v1']`
- Shape JSON:

```json
{
  "necessary": true,
  "functional": false,
  "analytics": false,
  "marketing": false,
  "version": "1.0",
  "savedAt": "<ISO datetime>"
}
```

### Flow
1. Brak zapisu → pokaż banner zwinięty.
2. Jest zapis → zastosuj zgodę, banner ukryty.
3. **Akceptuję wszystkie** → wszystkie kategorie `true` → zapis → ukryj.
4. **Odrzuć opcjonalne** → tylko `necessary: true` → zapis → ukryj.
5. **Ustawienia** → rozwiń szczegóły + synchronizacja checkboxów.
6. **Zapisz wybór** → odczyt checkboxów → zapis → ukryj.
7. Elementy `[data-open-cookie-settings]` (np. „Ustawienia cookies” w stopce) → ponowne otwarcie w trybie ustawień.

### Po zapisie
- `document.documentElement.dataset.cookieNecessary = 'granted'`
- `dataset.cookieFunctional|Analytics|Marketing` = `'granted'` | `'denied'`
- Event: `window.dispatchEvent(new CustomEvent('cookieConsentUpdated', { detail: consent }))`
- Odroczone skrypty:
  `<script type="text/plain" data-cookie-category="analytics|marketing|functional">`
  aktywowane dopiero przy zgodzie na daną kategorię.

---

## Wymagania wdrożenia w aplikacji

- Ten sam UX (teksty PL, 4 kategorie, przyciski jak wyżej).
- Ten sam shape JSON zgody.
- Wspólny klucz `coparentes_cookie_consent_v1` **tylko** jeśli app i landing są na tej samej domenie. Na `getcoparentes.app` (inna domena) — osobny klucz OK, ten sam format.
- Blokuj analytics / marketing do momentu zgody.
- Przycisk ponownego otwarcia ustawień cookies (stopka / ustawienia konta).
- Linki: polityka + regulamin (app lub `https://coparentes.ai/polityka-prywatnosci/` i `https://coparentes.ai/regulamin/`).
- A11y: `role="dialog"`, `aria-labelledby`, `hidden` / `aria-hidden`.

---

## Definition of done

- [ ] Pierwsze wejście → banner na dole
- [ ] Accept / Reject / Save zapisuje localStorage i chowa banner
- [ ] Reload bez ponownego pokazywania (gdy jest zapis)
- [ ] „Ustawienia cookies” otwiera rozwinięty widok
- [ ] Skrypty analityczne/marketingowe startują tylko po zgodzie
- [ ] Mobile + desktop: przyciski bannera zawsze klikalne

## Uwaga wdrożeniowa (Flutter)

Na `getcoparentes.app` UI jest Flutter canvas — banner jest widgetem Flutter (nie DOM z landingu), ale storage i shape JSON są zgodne z briefem. Clarity ładuje się przez istniejący `ClarityBridge` dopiero po `analytics: true` w cookies (oraz po zgodzie konta ANALYTICS dla zalogowanych rodziców).
