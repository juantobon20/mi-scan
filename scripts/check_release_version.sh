#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tag="${1:?usage: check_release_version.sh <tag, e.g. v1.1.0>}"
expected="${tag#v}"

pubspec_version=$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*([^+[:space:]]+).*/\1/')

if [ "$pubspec_version" != "$expected" ]; then
  echo "Tag ${tag} does not match pubspec.yaml: version is ${pubspec_version}, expected ${expected}."
  echo "Make sure the tag points to the release commit (git pull on main before tagging) or bump the version first."
  exit 1
fi

if ! grep -qF "## [${expected}]" CHANGELOG.md; then
  echo "CHANGELOG.md has no section [${expected}]. Close [Sin publicar] under that version before tagging."
  exit 1
fi

echo "Tag ${tag} matches pubspec.yaml (${pubspec_version}) and CHANGELOG.md."
