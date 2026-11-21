#!/usr/bin/env bash
# Provision (or update) one environment: AWS resources, then server config.
# Usage: ./scripts/deploy.sh dev|prod   Safe to run again at any time.
set -euo pipefail
cd "$(dirname "$0")/../ansible"

env="${1:-}"
if [[ -z "$env" || ! -d "inventories/$env" ]]; then
  echo "usage: $0 <env>   (one of: $(ls inventories | xargs))" >&2
  exit 1
fi

# Only this laptop's current public IP may SSH in.
admin_cidr="$(curl -fsS https://checkip.amazonaws.com)/32"
echo "Deploying ${env}, SSH allowed from ${admin_cidr}"

ansible-playbook -i "inventories/$env" infra.yml -e "admin_cidr=${admin_cidr}"
ansible-playbook -i "inventories/$env" site.yml
