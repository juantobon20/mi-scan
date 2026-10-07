#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

version="${1:?usage: release_notes.sh <version>}"
max_chars=4000

extract_section() {
  awk -v heading="$1" '
    /^## \[/ {
      if (capture) exit
      if (index($0, "## [" heading "]") == 1) { capture = 1; next }
    }
    capture { print }
  ' CHANGELOG.md | sed -e '/./,$!d'
}

notes=$(extract_section "$version")

if [ -z "${notes//[[:space:]]/}" ]; then
  notes=$(extract_section "Sin publicar")
fi

if [ -z "${notes//[[:space:]]/}" ]; then
  notes="Build ${version}"
fi

printf '%s\n' "$notes" | cut -c1-500 | head -c "$max_chars"
