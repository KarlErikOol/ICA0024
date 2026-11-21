#!/usr/bin/env bash
# Create or update one environment. Each environment is its own Terraform
# workspace (separate state) with its own <env>.tfvars.
# Usage: ./scripts/deploy.sh dev|prod [extra terraform apply args, e.g. -auto-approve]
set -euo pipefail
cd "$(dirname "$0")/../terraform"

env="${1:-}"
if [[ -z "$env" || ! -f "$env.tfvars" ]]; then
  echo "usage: $0 <env> [-auto-approve]   (one of: $(ls *.tfvars | sed 's/\.tfvars$//' | xargs))" >&2
  exit 1
fi
shift

terraform init -input=false >/dev/null
terraform workspace select -or-create "$env"
terraform apply -var-file="$env.tfvars" "$@"
