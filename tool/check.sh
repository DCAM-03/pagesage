#!/usr/bin/env bash
# PageSage local quality gate (M4)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== dart format (check) =="
dart format --output=none --set-exit-if-changed .

echo "== flutter analyze =="
flutter analyze

echo "== flutter test =="
flutter test

echo "OK: format + analyze + test passed"
