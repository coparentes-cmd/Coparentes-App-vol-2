#!/usr/bin/env bash
# Restore Coparentes launcher icons from branding (blocks Flutter defaults).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="assets/branding/coparentes-app-icon-1024.png"
if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC" >&2
  exit 1
fi

dart run flutter_launcher_icons
flutter test test/app_icon_guard_test.dart
echo "OK: Coparentes app icons regenerated and guarded."
