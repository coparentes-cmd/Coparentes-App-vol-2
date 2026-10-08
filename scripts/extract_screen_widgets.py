#!/usr/bin/env python3
"""Extract private widget classes from Flutter screen files into feature folders."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Avoid Flutter Material name collisions when stripping leading underscore.
CUSTOM_PUBLIC_NAMES = {
    "_Divider": "SettingsDivider",
}


@dataclass
class ClassBlock:
    name: str
    start: int  # 0-based line index
    end: int  # exclusive
    lines: list[str]


def parse_classes(source: str) -> list[ClassBlock]:
    lines = source.splitlines(keepends=True)
    blocks: list[ClassBlock] = []
    i = 0
    while i < len(lines):
        m = re.match(r"^class (\w+)", lines[i])
        if m:
            name = m.group(1)
            start = i
            brace_depth = 0
            started = False
            while i < len(lines):
                for ch in lines[i]:
                    if ch == "{":
                        brace_depth += 1
                        started = True
                    elif ch == "}":
                        brace_depth -= 1
                i += 1
                if started and brace_depth == 0:
                    break
            blocks.append(ClassBlock(name, start, i, lines[start:i]))
        else:
            i += 1
    return blocks


def parse_top_level_functions(
    source: str, class_blocks: list[ClassBlock]
) -> dict[str, tuple[int, int, list[str]]]:
    lines = source.splitlines(keepends=True)
    occupied: set[int] = set()
    for block in class_blocks:
        occupied.update(range(block.start, block.end))

    functions: dict[str, tuple[int, int, list[str]]] = {}
    i = 0
    while i < len(lines):
        if i in occupied:
            i += 1
            continue
        m = re.match(r"^(?:[\w<>,\s?]+\s+)?(_\w+)\s*\(", lines[i].strip())
        if m and not lines[i].strip().startswith("//"):
            name = m.group(1)
            start = i
            brace_depth = 0
            started = False
            while i < len(lines):
                for ch in lines[i]:
                    if ch == "{":
                        brace_depth += 1
                        started = True
                    elif ch == "}":
                        brace_depth -= 1
                i += 1
                if started and brace_depth == 0:
                    break
            functions[name] = (start, i, lines[start:i])
            continue
        i += 1
    return functions


def public_name(name: str) -> str:
    if name in CUSTOM_PUBLIC_NAMES:
        return CUSTOM_PUBLIC_NAMES[name]
    return name[1:] if name.startswith("_") else name


def apply_renames(text: str, rename_map: dict[str, str]) -> str:
    for old, new in sorted(rename_map.items(), key=lambda item: len(item[0]), reverse=True):
        text = re.sub(rf"\b{re.escape(old)}\b", new, text)
    return text


def extract_imports(source: str) -> str:
    imports: list[str] = []
    for line in source.splitlines(keepends=True):
        if line.startswith("import ") or line.startswith("export "):
            imports.append(line)
        elif line.strip() and not line.strip().startswith("//"):
            break
    return "".join(imports)


def transform_import_line(line: str, depth: str, screen_dir: str) -> str:
    """Transform screen-relative imports to feature-relative imports."""
    m = re.match(r"import '([^']+)';", line.strip())
    if not m:
        return line.rstrip()
    path = m.group(1)
    if path.startswith("package:") or path.startswith("dart:"):
        return line.rstrip()
    rel = re.match(r"^((?:\.\./)+)(.+)$", path)
    if rel:
        prefix, rest = rel.group(1), rel.group(2)
        dot_count = len(prefix) // 3
        if depth == "feature":
            if dot_count == 1:
                return f"import '../../screens/{rest}';"
            if dot_count == 2:
                return f"import '../../../{rest}';"
        elif depth == "widget":
            if dot_count == 1:
                return f"import '../../../screens/{rest}';"
            if dot_count == 2:
                return f"import '../../../../{rest}';"
        return line.rstrip()

    if depth == "feature":
        return f"import '../../screens/{screen_dir}/{path}';"
    return f"import '../../../screens/{screen_dir}/{path}';"


def transform_imports(imports: str, depth: str, screen_dir: str) -> str:
    return "\n".join(
        transform_import_line(line, depth, screen_dir)
        for line in imports.splitlines()
        if line.strip()
    )


def build_widget_file(
    imports: str,
    extra_imports: list[str],
    bodies: list[str],
    trailing_functions: list[str] | None = None,
) -> str:
    parts = [imports.rstrip(), ""]
    seen = set()
    for imp in extra_imports:
        if imp not in seen and imp not in imports:
            parts.append(imp)
            seen.add(imp)
    if extra_imports:
        parts.append("")
    for body in bodies:
        parts.append(body.rstrip())
        parts.append("")
    if trailing_functions:
        for fn in trailing_functions:
            parts.append(fn.rstrip())
            parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def state_class_for(widget_name: str, blocks: list[ClassBlock]) -> ClassBlock | None:
    state_name = f"{widget_name}State"
    for block in blocks:
        if block.name == state_name:
            return block
    return None


def process_screen(
    src_rel: str,
    feature_rel: str,
    export_rel: str,
    extractions: list[dict],
) -> None:
    src_path = ROOT / src_rel
    source = src_path.read_text()
    lines = source.splitlines(keepends=True)
    blocks = parse_classes(source)
    functions = parse_top_level_functions(source, blocks)
    block_by_name = {block.name: block for block in blocks}

    imports = extract_imports(source)
    extracted_line_ranges: set[int] = set()
    rename_map: dict[str, str] = {}

    feature_dir = ROOT / Path(feature_rel).parent
    screen_dir = Path(src_rel).parent.name
    widgets_dir = feature_dir / "widgets"
    widgets_dir.mkdir(parents=True, exist_ok=True)

    for spec in extractions:
        for wname in spec["classes"]:
            if wname not in block_by_name:
                continue
            rename_map[wname] = public_name(wname)
            state = state_class_for(wname, blocks)
            if state:
                rename_map[state.name] = f"{rename_map[wname]}State"

    for spec in extractions:
        widget_names = spec["classes"]
        outfile = widgets_dir / spec["file"]
        bodies: list[str] = []
        fn_names = spec.get("functions", [])

        for wname in widget_names:
            if wname not in block_by_name:
                print(f"WARNING: {wname} not found in {src_rel}", file=sys.stderr)
                continue
            block = block_by_name[wname]
            bodies.append(apply_renames("".join(block.lines), rename_map))
            extracted_line_ranges.update(range(block.start, block.end))

            state = state_class_for(wname, blocks)
            if state:
                bodies.append(apply_renames("".join(state.lines), rename_map))
                extracted_line_ranges.update(range(state.start, state.end))

        trailing = []
        for fn in fn_names:
            if fn in functions:
                start, end, fn_lines = functions[fn]
                trailing.append(apply_renames("".join(fn_lines), rename_map))
                extracted_line_ranges.update(range(start, end))

        sibling_imports = [
            f"import '{other['file']}';"
            for other in extractions
            if other["file"] != spec["file"]
        ]
        extra = sibling_imports + spec.get("imports", [])

        widget_content = build_widget_file(
            transform_imports(imports, "widget", screen_dir),
            extra,
            bodies,
            trailing or None,
        )
        outfile.write_text(widget_content)

    remaining: list[str] = []
    for i, line in enumerate(lines):
        if i in extracted_line_ranges:
            continue
        remaining.append(line)

    main_text = apply_renames("".join(remaining), rename_map)
    main_text = re.sub(r"\n// ───[^\n]*\n\n(?=// ───)", "\n", main_text)

    used_widget_imports: list[str] = []
    for spec in extractions:
        for wname in spec["classes"]:
            pname = rename_map.get(wname, public_name(wname))
            if re.search(rf"\b{pname}\b", main_text):
                used_widget_imports.append(f"import 'widgets/{spec['file']}';")

    main_import_lines = [
        transform_import_line(line, "feature", screen_dir)
        for line in extract_imports(source).splitlines()
        if line.strip()
    ]
    for widget_import in used_widget_imports:
        if widget_import not in main_import_lines:
            main_import_lines.append(widget_import)

    body_start = 0
    for i, line in enumerate(main_text.splitlines(keepends=True)):
        if line.startswith("import ") or line.startswith("export "):
            body_start = i + 1
        elif line.strip() and not line.strip().startswith("//"):
            break

    main_body = "".join(main_text.splitlines(keepends=True)[body_start:])
    feature_main = "\n".join(main_import_lines) + "\n\n" + main_body.lstrip()
    feature_path = ROOT / feature_rel
    feature_path.parent.mkdir(parents=True, exist_ok=True)
    feature_path.write_text(feature_main.rstrip() + "\n")

    export_path = ROOT / export_rel
    export_path.write_text(
        f"export '../../features/{Path(feature_rel).parent.name}/{Path(feature_rel).name}';\n"
    )

    print(f"{feature_rel}: {len(feature_main.splitlines())} lines, widgets: {len(extractions)}")


def main() -> None:
    process_screen(
        "lib/screens/child/child_dashboard.dart",
        "lib/features/child/child_dashboard.dart",
        "lib/screens/child/child_dashboard.dart",
        [
            {
                "file": "child_todo_models.dart",
                "classes": ["_ChildListItem", "_ChildTodoList"],
            },
            {"file": "mood_button.dart", "classes": ["_MoodButton"]},
        ],
    )

    process_screen(
        "lib/screens/dashboard/parent_dashboard.dart",
        "lib/features/parent/parent_dashboard.dart",
        "lib/screens/dashboard/parent_dashboard.dart",
        [
            {
                "file": "dashboard_home.dart",
                "classes": ["_DashboardHome"],
                "functions": [
                    "_formatNetBalanceLabel",
                    "_latestChatActivity",
                    "_latestFinanceActivity",
                    "_resolveLatestFinanceExpense",
                    "_latestFinanceExpenseId",
                    "_latestCalendarActivity",
                    "_formatShortDate",
                ],
            },
            {"file": "today_card.dart", "classes": ["_TodayCard"]},
            {"file": "stat_card.dart", "classes": ["_StatCard"]},
            {
                "file": "message_thread_preview.dart",
                "classes": ["_MessageThreadPreview"],
            },
            {
                "file": "finance_snapshot_card.dart",
                "classes": ["_FinanceSnapshotCard"],
            },
            {"file": "child_chip.dart", "classes": ["_ChildChip"]},
            {"file": "ai_coach_cta.dart", "classes": ["_AiCoachCta"]},
        ],
    )

    process_screen(
        "lib/screens/settings/settings_screen.dart",
        "lib/features/settings/settings_screen.dart",
        "lib/screens/settings/settings_screen.dart",
        [
            {"file": "edit_profile_sheet.dart", "classes": ["_EditProfileSheet"]},
            {
                "file": "change_password_sheet.dart",
                "classes": ["_ChangePasswordSheet"],
            },
            {"file": "email_invite_sheet.dart", "classes": ["_EmailInviteSheet"]},
            {"file": "section_header.dart", "classes": ["_SectionHeader"]},
            {"file": "settings_card.dart", "classes": ["_SettingsCard"]},
            {"file": "settings_divider.dart", "classes": ["_Divider"]},
            {"file": "info_tile.dart", "classes": ["_InfoTile"]},
            {"file": "action_tile.dart", "classes": ["_ActionTile"]},
            {"file": "switch_tile.dart", "classes": ["_SwitchTile"]},
            {"file": "setup_pin_sheet.dart", "classes": ["_SetupPinSheet"]},
            {"file": "change_pin_sheet.dart", "classes": ["_ChangePinSheet"]},
        ],
    )

    process_screen(
        "lib/screens/finance/finance_screen.dart",
        "lib/features/finance/finance_screen.dart",
        "lib/screens/finance/finance_screen.dart",
        [
            {"file": "status_count_chip.dart", "classes": ["_StatusCountChip"]},
            {"file": "period_chip.dart", "classes": ["_PeriodChip"]},
            {"file": "summary_card.dart", "classes": ["_SummaryCard"]},
            {"file": "category_bar.dart", "classes": ["_CategoryBar"]},
            {"file": "split_overview_card.dart", "classes": ["_SplitOverviewCard"]},
            {"file": "expense_card.dart", "classes": ["_ExpenseCard"]},
            {
                "file": "dispute_expense_sheet.dart",
                "classes": ["_DisputeExpenseSheet"],
            },
            {"file": "add_expense_sheet.dart", "classes": ["_AddExpenseSheet"]},
        ],
    )

    process_screen(
        "lib/screens/calendar/calendar_screen.dart",
        "lib/features/calendar/calendar_screen.dart",
        "lib/screens/calendar/calendar_screen.dart",
        [
            {"file": "legend_item.dart", "classes": ["_LegendItem"]},
            {"file": "selected_day_card.dart", "classes": ["_SelectedDayCard"]},
            {"file": "swap_card.dart", "classes": ["_SwapCard"]},
            {"file": "swap_date_row.dart", "classes": ["_SwapDateRow"]},
            {"file": "add_event_sheet.dart", "classes": ["_AddEventSheet"]},
            {"file": "swap_request_sheet.dart", "classes": ["_SwapRequestSheet"]},
            {"file": "swap_reject_sheet.dart", "classes": ["_SwapRejectSheet"]},
            {
                "file": "schedule_setup_banner.dart",
                "classes": ["_ScheduleSetupBanner"],
            },
            {
                "file": "pending_schedule_banner.dart",
                "classes": ["_PendingScheduleBanner"],
            },
            {
                "file": "schedule_request_card.dart",
                "classes": ["_ScheduleRequestCard"],
            },
            {
                "file": "exception_request_card.dart",
                "classes": ["_ExceptionRequestCard"],
            },
            {"file": "day_action_buttons.dart", "classes": ["_DayActionButtons"]},
            {
                "file": "exception_request_sheet.dart",
                "classes": ["_ExceptionRequestSheet"],
            },
        ],
    )


if __name__ == "__main__":
    main()
