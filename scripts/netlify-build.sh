#!/usr/bin/env bash
set -euo pipefail

if [ -z "${COPARENTES_API_BASE_URL:-}" ]; then
  echo "ERROR: Missing COPARENTES_API_BASE_URL environment variable."
  echo "Set it in Netlify Site configuration -> Environment variables."
  exit 1
fi

case "$COPARENTES_API_BASE_URL" in
  https://*) ;;
  *)
    echo "ERROR: COPARENTES_API_BASE_URL must use HTTPS in production."
    echo "Current value: $COPARENTES_API_BASE_URL"
    exit 1
    ;;
esac

case "$COPARENTES_API_BASE_URL" in
  */api) ;;
  *)
    echo "ERROR: COPARENTES_API_BASE_URL must end with /api"
    echo "Example: https://coparentes-backend-production.up.railway.app/api"
    echo "Current value: $COPARENTES_API_BASE_URL"
    exit 1
    ;;
esac

export FLUTTER_HOME="$HOME/flutter-sdk"
export PATH="$FLUTTER_HOME/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK (stable)..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

flutter --version
flutter config --enable-web

# PWA icons (web/icons, favicon, assets/icon)
if command -v node >/dev/null 2>&1; then
  node scripts/generate_pwa_icons.mjs
else
  echo "WARN: node not found; ensure web/icons exist before deploy"
fi

flutter pub get

PUBLIC_URL="${COPARENTES_PUBLIC_URL:-https://getcoparentes.app}"

flutter build web \
  --release \
  --dart-define=COPARENTES_API_BASE_URL="$COPARENTES_API_BASE_URL" \
  --dart-define=COPARENTES_PUBLIC_URL="$PUBLIC_URL"

if [ ! -f build/web/index.html ]; then
  echo "ERROR: Flutter web build failed - build/web/index.html not found."
  exit 1
fi

BUILD_ID="$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "{\"buildId\":\"$BUILD_ID\"}" > build/web/version.json
BUILD_ID="$BUILD_ID" python3 - <<'PY'
import os
import re
from pathlib import Path

build_id = os.environ["BUILD_ID"]
index = Path("build/web/index.html")
html = index.read_text()
meta = f'  <meta name="coparentes-build" content="{build_id}">\n'
if 'coparentes-build' not in html:
    html = html.replace('<meta charset="UTF-8">', '<meta charset="UTF-8">\n' + meta)
else:
    html = re.sub(
        r'<meta name="coparentes-build" content="[^"]*">',
        meta.strip(),
        html,
    )
index.write_text(html)
PY

echo "Flutter web build completed successfully (buildId=$BUILD_ID)."
