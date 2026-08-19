#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_PYTHON="${BACKEND_PYTHON:-$PROJECT_ROOT/backend/venv/bin/python}"

echo "[1/6] Backend unit, API integration, and RLS tests"
PYTHONPATH="$PROJECT_ROOT/backend" "$BACKEND_PYTHON" -m unittest discover \
  -s "$PROJECT_ROOT/backend/tests" -v

echo "[2/6] ML service contract tests"
"$BACKEND_PYTHON" -m unittest discover \
  -s "$PROJECT_ROOT/services/ml-engine/tests" -v

echo "[3/6] Flutter unit and widget tests with coverage"
(
  cd "$PROJECT_ROOT/apps/mobile-app"
  flutter test --coverage
)

echo "[4/6] Flutter integration/end-to-end flow"
(
  cd "$PROJECT_ROOT/apps/mobile-app"
  env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    flutter test integration_test/app_flow_test.dart -d macos
)

echo "[5/6] Flutter static analysis"
(
  cd "$PROJECT_ROOT/apps/mobile-app"
  flutter analyze --no-fatal-warnings --no-fatal-infos
)

echo "[6/6] Next.js build check"
if [[ -x "$PROJECT_ROOT/apps/web-admin/node_modules/.bin/next" ]]; then
  (
    cd "$PROJECT_ROOT/apps/web-admin"
    npm run build
  )
else
  echo "SKIPPED: install apps/web-admin dependencies to run the Next.js build."
fi

echo "All available Budgcoach test layers completed."
