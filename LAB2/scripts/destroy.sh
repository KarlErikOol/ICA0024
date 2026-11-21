#!/usr/bin/env bash
# Tear down one environment; the other keeps running.
# Usage: ./scripts/destroy.sh dev|prod [extra terraform destroy args, e.g. -auto-approve]
set -euo pipefail
cd "$(dirname "$0")/../terraform"

env="${1:-}"
if [[ -z "$env" || ! -f "$env.tfvars" ]]; then
  echo "usage: $0 <env> [-auto-approve]   (one of: $(ls *.tfvars | sed 's/\.tfvars$//' | xargs))" >&2
  exit 1
fi
shift

terraform init -input=false >/dev/null
terraform workspace select "$env"
terraform destroy -var-file="$env.tfvars" "$@"
