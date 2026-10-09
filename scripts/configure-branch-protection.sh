#!/usr/bin/env bash
# Creates (or updates) a repository ruleset that makes the CI gate mandatory for
# merges into dev, qa and main. Run once per repository by a repo admin:
#   scripts/configure-branch-protection.sh <owner>/<repo>
# Requires: GitHub CLI (`gh auth login`) with admin rights on the repository.
set -euo pipefail

repo="${1:?usage: $0 <owner>/<repo>}"
ruleset_name="iac-ci-protected-branches"
# Reusable-workflow check names are "<caller job name> / <called job name>".
required_check="IaC CI / CI Gate"

payload=$(cat <<JSON
{
  "name": "${ruleset_name}",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/dev", "refs/heads/qa", "refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [ { "context": "${required_check}" } ]
      }
    }
  ]
}
JSON
)

existing_id=$(gh api "repos/${repo}/rulesets" --jq ".[] | select(.name == \"${ruleset_name}\") | .id" || true)

if [[ -n "${existing_id}" ]]; then
  gh api -X PUT "repos/${repo}/rulesets/${existing_id}" --input - <<<"${payload}" >/dev/null
  echo "✅ Updated ruleset '${ruleset_name}' (id ${existing_id}) on ${repo}"
else
  gh api -X POST "repos/${repo}/rulesets" --input - <<<"${payload}" >/dev/null
  echo "✅ Created ruleset '${ruleset_name}' on ${repo}"
fi
echo "   Required status check: '${required_check}' on dev, qa, main (PRs only, direct pushes blocked)."
