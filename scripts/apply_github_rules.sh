#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo="${1:?usage: GITHUB_TOKEN=<token> scripts/apply_github_rules.sh <owner/repo>}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN with Administration write permission on the repository}"

api="https://api.github.com/repos/${repo}"
headers=(
  -H "Authorization: Bearer ${GITHUB_TOKEN}"
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

echo "==> repository merge settings"
curl -fsS -X PATCH "${headers[@]}" "${api}" -d '{
  "allow_squash_merge": true,
  "allow_merge_commit": true,
  "allow_rebase_merge": false,
  "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY",
  "delete_branch_on_merge": true
}' > /dev/null

for ruleset in .github/rulesets/*.json; do
  echo "==> ruleset ${ruleset}"
  curl -fsS -X POST "${headers[@]}" "${api}/rulesets" --data @"${ruleset}" > /dev/null
done

echo "Done. Existing rulesets with the same name must be deleted first (HTTP 422 otherwise)."
