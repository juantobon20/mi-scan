#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "${1:-}" = "--staged" ]; then
  files=$(git diff --cached --name-only --diff-filter=ACMRD)
  changelog_diff=$(git diff --cached -U0 -- CHANGELOG.md)
else
  range="${1:?usage: check_changelog.sh --staged | <git-diff-range>}"
  files=$(git diff --name-only --diff-filter=ACMRD "$range")
  changelog_diff=$(git diff -U0 "$range" -- CHANGELOG.md)
fi

exempt='^(CHANGELOG\.md|README\.md|CLAUDE\.md|\.gitignore|pubspec\.lock|\.metadata|\.idea/)'
relevant=$(echo "$files" | grep -vE "$exempt" || true)

if [ -z "$relevant" ]; then
  exit 0
fi

if echo "$changelog_diff" | grep -qE '^\+- '; then
  exit 0
fi

echo "CHANGELOG.md was not updated."
echo "Add at least one bullet (- ...) under [Unreleased] describing the change to:"
echo "$relevant" | sed 's/^/  - /'
echo "Policy: every change to files or new resources, human or AI authored, needs a changelog entry."
exit 1
