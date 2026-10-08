#!/usr/bin/env python3
"""Append missing enOverlay keys and wrap Polish UI string literals with context.tr()."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
OVERLAY = LIB / "l10n" / "en_overlay.dart"
TRANSLATIONS = ROOT / "scripts" / "_en_translations.json"

QUALITY_FIX = {
    "Analizuję...": "Analysing...",
    "Generuję...": "Generating...",
    "Brak wydatków": "No expenses",
    "Brak wydatków w tym filtrze": "No expenses in this filter",
    "Brak wydatków do podsumowania.": "No expenses to summarise.",
    "Brak wydatków w wybranym okresie.": "No expenses in the selected period.",
    "Odrzuć wniosek": "Decline request",
    "Prośba o zmianę": "Change request",
    "Metoda płatności": "Payment method",
    "no expenditure included": "No expenses",  # if bad value leaked as key - n/a
    "Ciemne tło aktywne": "Dark background on",
    "Jasne tło aktywne": "Light background on",
    "Wyloguj się": "Log out",
    "Dodaj pierwszy profil dziecka": "Add the first child profile",
    "Dodaj kolejny profil dziecka": "Add another child profile",
    "Historia płatności": "Payment history",
    "Anuluj subskrypcję": "Cancel subscription",
    "Wyślij e-mail": "Send email",
    "Wyślij wniosek e-mailem": "Email the request",
    "Wybierz wątek z listy": "Pick a thread from the list",
    "Nowy wątek": "New thread",
    "Brak wątków": "No threads",
    "Brak nieprzeczytanych wiadomości": "No unread messages",
    "Historia eksportów": "Export history",
    "PDF zapisany na urządzeniu.": "PDF saved on device.",
    "Nie udało się zapisać PDF.": "Could not save PDF.",
    "Mój dzień": "My day",
    "Plan na dziś": "Plan for today",
    "Jak się dzisiaj czujesz? 💭": "How are you feeling today? 💭",
    "To tylko dla Ciebie – rodzice tego nie widzą 🔒": "Just for you – parents cannot see this 🔒",
    "Brak planu na dziś — rodzice mogą dodać coś w kalendarzu.": "No plan for today — parents can add something in the calendar.",
    "Wpisz coś powyżej — jak w Google Keep.": "Type something above — like in Google Keep.",
    "Tytuł listy": "List title",
    "Dodaj dokument": "Add document",
    "1 dzień temu": "1 day ago",
    "Saldo niedostępne": "Balance unavailable",
    "Podział po kategoriach": "Breakdown by category",
    "Kto zapłacił (wszystkie wydatki)": "Who paid (all expenses)",
    "Dodaj pierwszy wydatek ręcznie lub z paragonu": "Add the first expense manually or from a receipt",
    "Spróbuj innego filtra statusu": "Try a different status filter",
    "Ostatnie eksporty finansów": "Recent finance exports",
    "Eksport finansów dodany do kolejki.": "Finance export added to the queue.",
    "Raport finansowy dodany do kolejki eksportów.": "Finance report added to the export queue.",
    "Po zaakceptowanych wydatkach oboje jesteście na zero.": "After accepted expenses you are both even.",
    "Drugi rodzic winien Tobie po akceptacji wydatków.": "The other parent owes you after expense acceptance.",
    "Ty winien/winna drugiemu rodzicowi po akceptacji wydatków.": "You owe the other parent after expense acceptance.",
    "Data „Od” nie może być późniejsza niż „Do”.": "The From date cannot be later than To.",
    "Wydatek zaakceptowany. Saldo zostało zaktualizowane.": "Expense accepted. Balance updated.",
    "Oznaczono jako rozliczone poza aplikacją.": "Marked as settled outside the app.",
    "Saldo liczone tylko z zaakceptowanych wydatków w wybranym okresie.": "Balance uses only accepted expenses in the selected period.",
    "Wymagaj PIN-u po przejściu aplikacji w tło": "Require PIN after the app goes to background",
    "Najpierw ustaw PIN w „Zmień PIN logowania”": "Set a PIN first in “Change login PIN”",
    "Zaufane urządzenia": "Trusted devices",
    "Nie udało się zaktualizować 2FA.": "Could not update 2FA.",
    "Zmień 4-cyfrowy PIN": "Change 4-digit PIN",
    "Nie udało się zaktualizować trybu konfliktu.": "Could not update conflict mode.",
    "Aktualne hasło": "Current password",
    "Powtórz nowe hasło": "Repeat new password",
    "Powtórz nowy PIN": "Repeat new PIN",
    "Powód sporu": "Dispute reason",
    "Powód (opcjonalnie)": "Reason (optional)",
    "Powód zmiany (opcjonalnie)": "Reason for change (optional)",
    "Temat wątku": "Thread subject",
    "Imię i nazwisko dziecka": "Child’s full name",
    "Szkoła (opcjonalnie)": "School (optional)",
    "Utwórz własną etykietę": "Create your own label",
    "Sugerowane": "Suggested",
}

SKIP_DIRS = {
    "l10n",
    "providers",
    "data",
    "models",
    "config",
    "services",
    "theme",
    "utils",
    "core",
    "api",
}

PL_RE = re.compile(
    r"[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]|"
    r"\b(Brak|Dodaj|Zapisz|Anuluj|Hasło|Profil|Wydatki|Wiadomości|Kalendarz|Ustawienia|"
    r"Wygląd|Bezpieczeństwo|Prywatność|Powód|Tytuł|Temat|Data|Nowe|Aktualne|Powtórz|"
    r"Wybierz|Utwórz|Wyślij|Alert|Filtrowanie|Imię|Szkoła|Okres|Wątki|Historia|"
    r"Generuję|Analizuję|Załącznik|Medyczne|Umowy|Wspólne|Prywatne|Wszystkie|"
    r"Poniedziałek|Wtorek|Środa|Czwartek|Piątek|Sobota|Niedziela|Zwiń|Wysłana|"
    r"dziś|przed chwilą|Opłacona|Błąd|Logowanie|Rejestracja|Wyloguj|Wiadomość|"
    r"Akceptuj|Odrzuć|Zatwierdź|Odśwież|Kontynuuj|Potwierdź|Zmień|Wysyłam|Niezmienialny|"
    r"Sugerowane|Opłacona|Ogólne|Użytkownik)\b",
    re.I,
)

IMPORT_PKG = "import 'package:coparentes/l10n/app_strings.dart';\n"
IMPORT_REL = None  # resolved per file


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def parse_overlay(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for m in re.finditer(r"'((?:\\'|[^'])*)'\s*:\s*'((?:\\'|[^'])*)'", text):
        out[m.group(1).replace("\\'", "'")] = m.group(2).replace("\\'", "'")
    return out


def write_overlay(existing: dict[str, str], additions: dict[str, str]) -> int:
    merged = dict(existing)
    added = 0
    for k, v in additions.items():
        if k not in merged:
            merged[k] = QUALITY_FIX.get(k, v)
            # also apply quality fix if translation itself is wrong key-wise
            if k in QUALITY_FIX:
                merged[k] = QUALITY_FIX[k]
            added += 1
        elif k in QUALITY_FIX:
            merged[k] = QUALITY_FIX[k]

    # Apply quality fixes on values that match known bad API outputs for our keys
    for k, v in list(merged.items()):
        if k in QUALITY_FIX:
            merged[k] = QUALITY_FIX[k]

    lines = ["/// English overlay. The Polish source string is the key. Missing keys stay Polish.\n"]
    lines.append("const enOverlay = <String, String>{\n")
    # sort by length then alpha for stability
    for k in sorted(merged.keys(), key=lambda x: (len(x), x)):
        lines.append(f"  '{dart_escape(k)}': '{dart_escape(merged[k])}',\n")
    lines.append("};\n")
    OVERLAY.write_text("".join(lines))
    return added


def ensure_import(text: str, path: Path) -> str:
    if "l10n/app_strings.dart" in text:
        return text
    # Prefer package import
    m = re.search(r"^import .*;\n", text, re.M)
    if not m:
        return IMPORT_PKG + text
    # insert after last import
    imports = list(re.finditer(r"^import .*;\n", text, re.M))
    last = imports[-1]
    return text[: last.end()] + IMPORT_PKG + text[last.end() :]


def looks_pl(s: str) -> bool:
    return bool(PL_RE.search(s.replace("\\n", " ")))


def unwrap_body(raw: str) -> str:
    return raw.replace("\\'", "'").replace('\\"', '"')


def merge_adjacent_text_strings(text: str) -> str:
    """Merge Text('a ' 'b') into Text('a b')."""

    pat = re.compile(
        r"(?:const\s+)?Text\s*\(\s*",
    )
    out = []
    pos = 0
    for m in pat.finditer(text):
        i = m.end()
        parts = []
        j = i
        while True:
            while j < len(text) and text[j] in " \t\n\r":
                j += 1
            if j >= len(text) or text[j] not in "'\"":
                break
            q = text[j]
            j += 1
            start_b = j
            while j < len(text):
                if text[j] == "\\" and j + 1 < len(text):
                    j += 2
                    continue
                if text[j] == q:
                    break
                j += 1
            if j >= len(text):
                parts = []
                break
            parts.append(text[start_b:j].replace("\\'", "'"))
            j += 1  # closing quote
        if len(parts) < 2:
            continue
        while j < len(text) and text[j] in " \t\n\r":
            j += 1
        if j >= len(text) or text[j] not in ",)":
            continue
        merged = "".join(parts)
        if not looks_pl(merged):
            continue
        # rewrite from m.start()
        out.append(text[pos : m.start()])
        out.append(f"Text('{dart_escape(merged)}'")
        # keep from j (comma or paren)
        pos = j
    out.append(text[pos:])
    return "".join(out)


def wrap_text_calls(text: str) -> tuple[str, int]:
    count = 0

    # (const )?Text('...') -> Text(context.tr('...'))
    pat_text = re.compile(
        r"""(?:const\s+)?Text\s*\(\s*(?P<q>['"])(?P<body>(?:\\.|(?!\1).)*?)(?P=q)"""
    )

    out: list[str] = []
    pos = 0
    for m in pat_text.finditer(text):
        win = text[max(0, m.start() - 40) : m.start()]
        if re.search(r"context\.tr\s*\(\s*$", win):
            continue
        body = unwrap_body(m.group("body"))
        if "$" in m.group("body") or not looks_pl(body):
            continue
        out.append(text[pos : m.start()])
        q = m.group("q")
        out.append(f"Text(context.tr({q}{m.group('body')}{q})")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def wrap_named_string_params(text: str) -> tuple[str, int]:
    count = 0
    pat = re.compile(
        r"""(?P<name>label|title|subtitle|hintText|tooltip|helperText|semanticLabel|message)"""
        r"""\s*:\s*(?P<q>['"])(?P<body>(?:\\.|(?!\2).)*?)(?P=q)"""
    )
    out = []
    pos = 0
    for m in pat.finditer(text):
        win = text[max(0, m.start() - 40) : m.start()]
        if "context.tr(" in win[-40:]:
            continue
        body = unwrap_body(m.group("body"))
        if "$" in m.group("body") or not looks_pl(body):
            continue
        out.append(text[pos : m.start()])
        q = m.group("q")
        out.append(f"{m.group('name')}: context.tr({q}{m.group('body')}{q})")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def wrap_tip_displays(text: str) -> tuple[str, int]:
    count = 0
    # tip['title'] ?? ''  etc when used as Text child content
    patterns = [
        (
            re.compile(
                r"""Text\(\s*(?P<a>tip\[['\"](?:title|body|desc)['\"]\]\s*\?\?\s*['\"]['\"])\s*\)"""
            ),
            lambda m: f"Text(context.tr({m.group('a')}))",
        ),
        (
            re.compile(
                r"""(?<!tr\()(?P<a>tip\[['\"](?:title|body|desc)['\"]\]\s*\?\?\s*['\"]['\"])"""
            ),
            None,  # handled carefully below only in Text(
        ),
    ]
    # Text( tip['title'] ?? '' )
    pat = re.compile(
        r"""Text\(\s*(tip\[['\"](?:title|body|desc)['\"]\]\s*\?\?\s*(?:['\"]['\"]|\"\"))\s*([,)])"""
    )

    def repl(m: re.Match) -> str:
        nonlocal count
        count += 1
        return f"Text(context.tr({m.group(1)}){m.group(2)}"

    text2, n = pat.subn(repl, text)
    return text2, n


def wrap_document_category_calls(text: str) -> tuple[str, int]:
    count = 0
    # Text(_documentCategoryLabel(...))
    pat = re.compile(r"""Text\(\s*(_documentCategoryLabel\([^)]*\))\s*([,)])""")

    def repl(m: re.Match) -> str:
        nonlocal count
        if "context.tr" in m.group(0):
            return m.group(0)
        count += 1
        return f"Text(context.tr({m.group(1)}){m.group(2)}"

    text, n = pat.subn(repl, text)
    count += n
    # '${_documentCategoryLabel(...)}
    pat2 = re.compile(
        r"""\$\{_documentCategoryLabel\((?P<arg>[^)]*)\)\}"""
    )

    def repl2(m: re.Match) -> str:
        nonlocal count
        count += 1
        return f"${{context.tr(_documentCategoryLabel({m.group('arg')}))}}"

    # only if not already tr
    out = []
    pos = 0
    for m in pat2.finditer(text):
        win = text[max(0, m.start() - 25) : m.start()]
        if "context.tr(" in win:
            continue
        out.append(text[pos : m.start()])
        out.append(f"${{context.tr(_documentCategoryLabel({m.group('arg')}))}}")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def strip_const_when_tr_inside(text: str) -> str:
    """Remove const from widgets that now contain context.tr."""
    # const Row( ... context.tr ... ) is complex; handle common patterns:
    # const Text(context.tr -> already handled
    # child: const Row( with Text(context.tr inside - remove nearest const before Row/Column/etc

    def remove_blocking_const(s: str) -> str:
        # Find context.tr( and walk back for 'const ' that makes it invalid
        changed = True
        while changed:
            changed = False
            for m in list(re.finditer(r"context\.tr\(", s)):
                before = s[: m.start()]
                # if there's const Text( already fixed
                # look for const WidgetName( without closing before this tr
                # simpler: replace 'const Row(' / 'const Column(' / 'const Expanded(' etc
                # that contain context.tr before their closing - hard
                # Heuristic: remove `const ` immediately before common widgets if next 400 chars have context.tr and no ';'
                for wm in re.finditer(
                    r"\bconst\s+(Row|Column|Expanded|Padding|Container|Center|Flexible|Wrap|ListTile|SizedBox|RichText|Text\.rich)\s*\(",
                    before,
                ):
                    # check if this const's paren region includes our tr (no semicolon between)
                    start = wm.start()
                    region = s[wm.end() - 1 : m.start()]
                    if ";" in region:
                        continue
                    # remove this const
                    s = s[: wm.start()] + s[wm.start() + 6 :]  # len('const ')==6
                    changed = True
                    break
                if changed:
                    break
        return s

    return remove_blocking_const(text)


def process_file(path: Path) -> dict:
    original = path.read_text()
    text = original
    stats = {"wraps": 0, "path": str(path.relative_to(ROOT))}

    text = merge_adjacent_text_strings(text)
    text, n1 = wrap_text_calls(text)
    text, n2 = wrap_named_string_params(text)
    text, n3 = wrap_tip_displays(text)
    text, n4 = wrap_document_category_calls(text)
    text = strip_const_when_tr_inside(text)

    wraps = n1 + n2 + n3 + n4
    stats["wraps"] = wraps
    if wraps > 0 or text != original:
        text = ensure_import(text, path)
        if text != original:
            path.write_text(text)
            stats["changed"] = True
        else:
            stats["changed"] = False
    else:
        stats["changed"] = False
    return stats


def main() -> None:
    translations = json.loads(TRANSLATIONS.read_text())
    for k, v in list(translations.items()):
        if k in QUALITY_FIX:
            translations[k] = QUALITY_FIX[k]
        # fix a few API glitches
        if v == "Tracing...":
            translations[k] = "Analysing..."
        if v == "Payment Terms" and "płatności" in k.lower():
            translations[k] = "Payment method"
        if v == "Amendment Requests":
            translations[k] = "Change request"
        if v == "Reject the Application":
            translations[k] = "Decline request"
        if v.lower() == "no expenditure included":
            translations[k] = "No expenses"

    existing = parse_overlay(OVERLAY.read_text())
    added = write_overlay(existing, translations)
    print(f"overlay additions: {added}; total keys: {len(parse_overlay(OVERLAY.read_text()))}")

    changed_files = []
    total_wraps = 0
    for path in sorted(LIB.rglob("*.dart")):
        parts = path.relative_to(LIB).parts
        if parts[0] in SKIP_DIRS:
            continue
        if path.name.endswith(".g.dart"):
            continue
        st = process_file(path)
        if st.get("changed"):
            changed_files.append(st["path"])
            total_wraps += st["wraps"]
            print(f"  {st['wraps']:3d} wraps  {st['path']}")

    print(f"changed files: {len(changed_files)}; wraps: {total_wraps}")


if __name__ == "__main__":
    main()
