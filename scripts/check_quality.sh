#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter analyze"
flutter analyze --fatal-infos --fatal-warnings

echo "==> English-only check"
dart tool/check_english.dart "$@"
