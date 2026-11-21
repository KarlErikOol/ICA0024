#!/usr/bin/env bash
# Tear down both Smokeping probes and everything that belongs to them.
# Usage: ./scripts/destroy.sh [extra terraform destroy args, e.g. -auto-approve]
set -euo pipefail
cd "$(dirname "$0")/../infra"

# Required input; its value doesn't matter for destroy.
admin_cidr="$(curl -fsS https://checkip.amazonaws.com)/32"

terraform init -input=false >/dev/null
terraform destroy -var "admin_cidr=${admin_cidr}" "$@"

cat <<'EOF'

To confirm nothing is left (expect an empty list, then NoSuchEntity):
  aws resourcegroupstaggingapi get-resources --tag-filters Key=Owner,Values=karool Key=Project,Values=karool-lab3 --region eu-north-1
  aws iam get-role --role-name karool-lab3-estonia-role
EOF
