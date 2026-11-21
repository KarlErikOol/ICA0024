#!/usr/bin/env bash
# Run the same checks as .github/workflows/lab3-ci.yml locally. Needs no AWS
# credentials: nothing is planned or applied, and the module tests use a
# mocked AWS provider.
# Usage: ./scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

module=modules/smokeping-probe

missing=()
for tool in terraform tflint checkov; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
if (( ${#missing[@]} )); then
  echo "missing tools: ${missing[*]} (e.g. brew install terraform tflint checkov)" >&2
  exit 1
fi

step() { echo; echo "== $* =="; }

step "terraform fmt"
terraform fmt -check -recursive

step "validate $module"
terraform -chdir="$module" init -backend=false -input=false >/dev/null
terraform -chdir="$module" validate

step "validate infra"
if [[ -d infra ]]; then
  terraform -chdir=infra init -backend=false -input=false >/dev/null
  terraform -chdir=infra validate
else
  echo "infra/ not added yet"
fi

step "tflint"
(cd "$module" && tflint --init >/dev/null && tflint)

step "checkov"
checkov -d "$module" --framework terraform --quiet --compact

step "terraform test"
terraform -chdir="$module" test

echo
echo "All checks passed"
