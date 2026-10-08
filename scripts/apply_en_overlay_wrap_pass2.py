#!/usr/bin/env python3
"""Second pass: labelText, ternaries, EmptyState, helper snackbars, day names."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
OVERLAY = LIB / "l10n" / "en_overlay.dart"

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

PL_RE = re.compile(r"[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]|"
                   r"\b(Brak|Dodaj|Zapisz|Anuluj|Hasło|Tytuł|Powód|Wyślij|Wybierz|"
                   r"Grafik|Propozycja|Odrzuć|Imię|Szkoła|Data|Kwota|Opis|Notatka|"
                   r"Temat|Kategoria|Dziecko|E-mail|Aktualne|Nowe|Powtórz|Nowy|Godzina|"
                   r"Miejsce|Poniedziałek|Wtorek|Środa|Czwartek|Piątek|Sobota|Niedziela|"
                   r"przed chwilą|Saldo|PDF|Zdarzenie|Wniosek|Twój)\b", re.I)

IMPORT_PKG = "import 'package:coparentes/l10n/app_strings.dart';\n"

EXTRA_KEYS = {
    "Propozycja grafiku do akceptacji": "Schedule proposal awaiting acceptance",
    "Grafik oczekuje na akceptację": "Schedule awaiting acceptance",
    "Imię i nazwisko": "Full name",
    "Adres e-mail (tylko odczyt)": "Email address (read only)",
    "Data urodzenia": "Date of birth",
    "Opis wydatku": "Expense description",
    "Kwota (PLN)": "Amount (PLN)",
    "Data wydatku": "Expense date",
    "Notatka (opcjonalnie)": "Note (optional)",
    "Aktualny PIN": "Current PIN",
    "Nowy PIN": "New PIN",
    "Kategoria": "Category",
    "Dziecko (opcjonalnie)": "Child (optional)",
    "Godzina przekazania": "Handover time",
    "Miejsce przekazania": "Handover place",
    "E-mail": "Email",
    "E-mail partnera": "Partner’s email",
    "Dotyczy dziecka": "About child",
    "wniosku o wyjątek": "exception request",
    "odpowiedzi na wymianę": "swap reply",
    "zdarzenia": "event",
    "zmiany opieki": "care change",
    "odpowiedzi na grafik": "schedule reply",
    "Nieprawidłowe dane wniosku o wyjątek. Sprawdź wybrane daty.": "Invalid exception request data. Check the selected dates.",
    "Nieprawidłowe dane odpowiedzi na wymianę. Sprawdź wybrane daty.": "Invalid swap reply data. Check the selected dates.",
    "Nieprawidłowe dane zdarzenia. Sprawdź wybrane daty.": "Invalid event data. Check the selected dates.",
    "Nieprawidłowe dane zmiany opieki. Sprawdź wybrane daty.": "Invalid care-change data. Check the selected dates.",
    "Nieprawidłowe dane odpowiedzi na grafik. Sprawdź wybrane daty.": "Invalid schedule reply data. Check the selected dates.",
    "Nie udało się wysłać wniosku o wyjątek.": "Could not send the exception request.",
    "Nie udało się wysłać odpowiedzi na wymianę.": "Could not send the swap reply.",
    "Nie udało się wysłać zdarzenia.": "Could not send the event.",
    "Nie udało się wysłać zmiany opieki.": "Could not send the care change.",
    "Nie udało się wysłać odpowiedzi na grafik.": "Could not send the schedule reply.",
    "Zdarzenie zostało zaktualizowane": "Event updated",
    "Zdarzenie zostało dodane": "Event added",
    "Wniosek o zamianę został odrzucony.": "Swap request declined.",
    "Odrzuć i wyślij kontrpropozycję": "Decline and send a counter-proposal",
    "Grafik zaakceptowany — kalendarz został zaktualizowany.": "Schedule accepted — calendar updated.",
    "Propozycja grafiku została odrzucona.": "Schedule proposal declined.",
    "Masz już oczekującą propozycję grafiku. Nowa propozycja zastąpi poprzednią w oczekiwaniu.": "You already have a pending schedule proposal. A new one will replace it.",
    "Twój wniosek": "Your request",
    "Błąd serwera. Spróbuj ponownie za chwilę.": "Server error. Try again in a moment.",
    "Nieprawidłowe dane {action}. Sprawdź wybrane daty.": "Invalid {action} data. Check the selected dates.",
}


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def looks_pl(s: str) -> bool:
    return bool(PL_RE.search(s.replace("\\n", " ")))


def ensure_import(text: str) -> str:
    if "l10n/app_strings.dart" in text:
        return text
    imports = list(re.finditer(r"^import .*;\n", text, re.M))
    if not imports:
        return IMPORT_PKG + text
    last = imports[-1]
    return text[: last.end()] + IMPORT_PKG + text[last.end() :]


def append_overlay(keys: dict[str, str]) -> int:
    text = OVERLAY.read_text()
    existing = set(re.findall(r"'((?:\\'|[^'])*)'\s*:", text))
    existing = {k.replace("\\'", "'") for k in existing}
    additions = []
    for k, v in keys.items():
        if k in existing:
            continue
        additions.append(f"  '{dart_escape(k)}': '{dart_escape(v)}',\n")
    if not additions:
        return 0
    # insert before closing };
    text = text.rstrip()
    if text.endswith("};"):
        text = text[:-2] + "".join(additions) + "};\n"
    OVERLAY.write_text(text)
    return len(additions)


def wrap_label_text(text: str) -> tuple[str, int]:
    count = 0
    pat = re.compile(
        r"""(?P<name>labelText|hintText|helperText|prefixText|suffixText|counterText)"""
        r"""\s*:\s*(?P<q>['"])(?P<body>(?:\\.|(?!\2).)*?)(?P=q)"""
    )
    out = []
    pos = 0
    for m in pat.finditer(text):
        win = text[max(0, m.start() - 40) : m.start()]
        if "context.tr(" in win[-40:]:
            continue
        body = m.group("body").replace("\\'", "'")
        if "$" in m.group("body") or not looks_pl(body):
            continue
        out.append(text[pos : m.start()])
        q = m.group("q")
        out.append(f"{m.group('name')}: context.tr({q}{m.group('body')}{q})")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    # remove const from InputDecoration( that now has context.tr
    result = "".join(out)
    result = re.sub(
        r"const\s+InputDecoration\s*\(",
        "InputDecoration(",
        result,
    )
    return result, count


def wrap_ternary_strings(text: str) -> tuple[str, int]:
    """Wrap ? 'pl' : 'pl' branches (simple non-escaped quotes)."""
    count = 0
    pat = re.compile(
        r"""\?\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"""
    )
    out = []
    pos = 0
    for m in pat.finditer(text):
        chunk_before = text[max(0, m.start() - 20) : m.start()]
        if "context.tr(" in chunk_before:
            continue
        a = m.group(1).replace("\\'", "'")
        b = m.group(2).replace("\\'", "'")
        if "$" in m.group(1) or "$" in m.group(2):
            continue
        if not (looks_pl(a) or looks_pl(b)):
            continue
        out.append(text[pos : m.start()])
        left = f"context.tr('{m.group(1)}')" if looks_pl(a) else f"'{m.group(1)}'"
        right = f"context.tr('{m.group(2)}')" if looks_pl(b) else f"'{m.group(2)}'"
        out.append(f"? {left} : {right}")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def wrap_calendar_action_error(text: str) -> tuple[str, int]:
    count = 0
    pat = re.compile(r"""Text\(\s*calendarActionError\(([^)]*)\)\s*([,)])""")

    def repl(m: re.Match) -> str:
        nonlocal count
        if "context.tr" in m.group(0):
            return m.group(0)
        count += 1
        return f"Text(context.tr(calendarActionError({m.group(1)})){m.group(2)}"

    new_text, _ = pat.subn(repl, text)
    return new_text, count


def wrap_day_name_usage(text: str) -> tuple[str, int]:
    """final dayName = weekdays[...] -> display uses dayName; wrap at Text(dayName)."""
    count = 0
    if "weekdays" not in text or "Poniedziałek" not in text:
        return text, 0
    # Text(dayName) or '$dayName' patterns in child dashboard
    text2, n1 = re.subn(
        r"""Text\(\s*dayName\s*([,)])""",
        lambda m: f"Text(context.tr(dayName){m.group(1)}",
        text,
    )
    count += n1
    # also '${dayName}' 
    text3, n2 = re.subn(
        r"""\$\{dayName\}""",
        r"${context.tr(dayName)}",
        text2,
    )
    # avoid double wrap
    text3 = text3.replace("${context.tr(context.tr(dayName))}", "${context.tr(dayName)}")
    count += n2
    return text3, count


def wrap_return_pl_in_formatters(text: str, path: Path) -> tuple[str, int]:
    """For sync time etc: return 'przed chwilą' used later with tr at call — wrap call sites."""
    count = 0
    # _formatSyncTime(...) displayed? find Text(_formatSyncTime
    pat = re.compile(
        r"""Text\(\s*(_formatSyncTime\([^)]*\)|_formatRelative\([^)]*\)|_custodianLabel\([^)]*\))\s*([,)])"""
    )

    def repl(m: re.Match) -> str:
        nonlocal count
        count += 1
        return f"Text(context.tr({m.group(1)}){m.group(2)}"

    text, n = pat.subn(repl, text)
    # string interp ${ _formatRelative
    def repl2(m: re.Match) -> str:
        nonlocal count
        count += 1
        return f"${{context.tr({m.group(1)})}}"

    out = []
    pos = 0
    for m in re.finditer(
        r"""\$\{(_formatRelative\([^)]*\)|_formatSyncTime\([^)]*\))\}""", text
    ):
        if "context.tr(" in text[max(0, m.start() - 20) : m.start()]:
            continue
        out.append(text[pos : m.start()])
        out.append(f"${{context.tr({m.group(1)})}}")
        pos = m.end()
        count += 1
    out.append(text[pos:])
    return "".join(out), count


def strip_const_blocking(text: str) -> str:
    changed = True
    while changed:
        changed = False
        for m in list(re.finditer(r"context\.tr\(", text)):
            before = text[: m.start()]
            for wm in re.finditer(
                r"\bconst\s+(Row|Column|Expanded|Padding|Container|Center|Flexible|Wrap|ListTile|SizedBox|Card|Padding|InputDecoration|SnackBar|TextField|Decoration)\s*\(",
                before,
            ):
                region = text[wm.end() - 1 : m.start()]
                if ";" in region:
                    continue
                text = text[: wm.start()] + text[wm.start() + 6 :]
                changed = True
                break
            if changed:
                break
    return text


def process(path: Path) -> int:
    original = path.read_text()
    text = original
    total = 0
    text, n = wrap_label_text(text)
    total += n
    text, n = wrap_ternary_strings(text)
    total += n
    text, n = wrap_calendar_action_error(text)
    total += n
    text, n = wrap_day_name_usage(text)
    total += n
    text, n = wrap_return_pl_in_formatters(text, path)
    total += n
    text = strip_const_blocking(text)
    if text != original:
        text = ensure_import(text)
        path.write_text(text)
    return total


def main() -> None:
    added = append_overlay(EXTRA_KEYS)
    print("overlay +", added)
    total = 0
    for path in sorted(LIB.rglob("*.dart")):
        if path.relative_to(LIB).parts[0] in SKIP_DIRS:
            continue
        n = process(path)
        if n:
            print(f"  {n:3d}  {path.relative_to(ROOT)}")
            total += n
    print("total ops", total)


if __name__ == "__main__":
    main()
