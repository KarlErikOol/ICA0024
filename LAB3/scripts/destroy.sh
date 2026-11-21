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

To confirm nothing is left (expect two empty lists):
  aws resourcegroupstaggingapi get-resources --tag-filters Key=Owner,Values=karool Key=Project,Values=karool-lab3 --region eu-north-1
  aws ec2 describe-security-groups --filters 'Name=group-name,Values=karool-lab3-*' --query 'SecurityGroups[].GroupName' --region eu-north-1
EOF
