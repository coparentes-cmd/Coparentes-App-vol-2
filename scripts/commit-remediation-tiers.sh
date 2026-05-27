#!/usr/bin/env bash
# Create four remediation commits (Tier 1–4) for Coparentes Flutter app.
# Each file is staged in exactly one tier. Run: bash scripts/commit-remediation-tiers.sh

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed. Install Xcode Command Line Tools: xcode-select --install"
  exit 1
fi

if [[ ! -d .git ]]; then
  git init
fi

commit_tier() {
  local tier="$1"
  shift
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi
  local staged=0
  for f in "$@"; do
    if [[ -e "$f" ]]; then
      git add "$f"
      staged=1
    fi
  done
  if [[ "$staged" -eq 0 ]]; then
    echo "Tier ${tier}: no files found, skipping."
    return 0
  fi
  if git diff --cached --quiet; then
    echo "Tier ${tier}: nothing new to commit."
    return 0
  fi
  case "$tier" in
    1) git commit -m "$(cat <<'EOF'
fix(tier-1): finance split IDs and resilient offline sync

Resolve parent split totals from workspace members and drop stale 4xx offline
queue items instead of blocking entire synchronization.
EOF
)" ;;
    2) git commit -m "$(cat <<'EOF'
fix(tier-2): auth restore, secure tokens, exports, and offline ID maps

Restore API tokens from cache, secure token storage, real export status UI,
persist high-conflict mode, and persist local-to-server ID remapping.
EOF
)" ;;
    3) git commit -m "$(cat <<'EOF'
fix(tier-3): UX consistency, demo data, and defensive parsing

Password validation, messaging send flow, documents offline queue, demo
sample data, serializers, dead code removal, and API client hardening.
EOF
)" ;;
    4) git commit -m "$(cat <<'EOF'
chore(tier-4): tests, CSP headers, and API client lifecycle

Add serializer unit tests, Netlify Content-Security-Policy headers, and
AppApiClient.dispose for test teardown.
EOF
)" ;;
  esac
  echo "Tier ${tier}: committed."
}

# Tier 1 — FIX-008–010
commit_tier 1 \
  lib/screens/finance/finance_screen.dart \
  lib/data/repositories/calendar_repository.dart \
  lib/data/repositories/messaging_repository.dart \
  lib/data/repositories/finance_repository.dart \
  lib/data/repositories/export_repository.dart

# Tier 2 — FIX-009, FIX-014–016, FIX-021
commit_tier 2 \
  lib/data/repositories/auth_repository.dart \
  pubspec.yaml \
  pubspec.lock \
  lib/data/local/offline_store.dart \
  lib/providers/app_provider.dart \
  lib/providers/offline_sync_provider.dart \
  lib/providers/exports_provider.dart \
  lib/screens/exports/exports_screen.dart \
  lib/screens/settings/settings_screen.dart

# Tier 3 — FIX-022–038
commit_tier 3 \
  lib/screens/auth/role_selection_screen.dart \
  lib/screens/messaging/messaging_screen.dart \
  lib/data/repositories/documents_repository.dart \
  lib/data/api/app_api_client.dart \
  lib/data/serializers/api_serializers.dart \
  lib/providers/finance_provider.dart \
  lib/main.dart \
  lib/models/models.dart

# Tier 4 — FIX-041, FIX-044, FIX-046
commit_tier 4 \
  test/api_serializers_test.dart \
  netlify.toml

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Uncommitted files remain:"
  git status --short
  echo "Review and commit manually if needed."
fi

echo ""
git log --oneline -5 2>/dev/null || true
