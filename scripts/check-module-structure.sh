#!/usr/bin/env bash
# Verifies the mandatory module files exist. Used by pre-commit (local hook) so the
# same governance gate that runs in CI blocks the commit before it leaves the laptop.
# Usage: scripts/check-module-structure.sh [module-root]
set -uo pipefail

root="${1:-.}"
failed=0

check() {
  local label="$1"; shift
  local missing=()
  for f in "$@"; do
    [[ -s "${root}/${f}" ]] || missing+=("$f")
  done
  if ((${#missing[@]})); then
    printf '❌ %-34s missing/empty: %s\n' "$label" "${missing[*]}"
    failed=1
  else
    printf '✅ %-34s ok\n' "$label"
  fi
}

check "📘 Root README"                README.md
check "🧪 Examples"                   examples/main.tf examples/variables.tf examples/outputs.tf examples/README.md
check "⚙️  Scanner configs"           .pre-commit-config.yaml .tflint.hcl trivy.yaml

shopt -s nullglob
rules=("${root}"/.amazonq/rules/*.md)
if ((${#rules[@]})); then
  printf '✅ %-34s ok (%d file(s))\n' "🤖 Amazon Q rules" "${#rules[@]}"
else
  printf '❌ %-34s no .amazonq/rules/*.md found\n' "🤖 Amazon Q rules"
  failed=1
fi

exit "$failed"
