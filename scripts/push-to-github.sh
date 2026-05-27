#!/usr/bin/env bash
# Push Coparentes Flutter app to GitHub (run from Terminal.app on your Mac).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v git >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
  echo "Install Xcode Command Line Tools first: xcode-select --install"
  exit 1
fi

if [[ ! -d .git ]]; then
  git init
  git branch -M main
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Set your GitHub repo URL, e.g.:"
  echo "  git remote add origin https://github.com/coparentes-cmd/Coparentes-App-vol-2.git"
  exit 1
fi

git add -A
git status -sb

if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  git commit -m "$(cat <<'EOF'
Wire child onboarding after register and align API config.

AuthRepository calls POST /workspace/children and refreshes session.
New onboarding sheet prompts parentA to add children after signup.
EOF
)"
fi

git push -u origin main

echo "Push complete — Netlify should rebuild automatically."
