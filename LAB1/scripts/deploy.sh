#!/usr/bin/env bash
# Provision (or update) the whole stack: AWS resources, then server config.
# Safe to run again at any time.
set -euo pipefail
cd "$(dirname "$0")/../ansible"

# Only this laptop's current public IP may SSH in.
admin_cidr="$(curl -fsS https://checkip.amazonaws.com)/32"
echo "SSH allowed from ${admin_cidr}"

ansible-playbook infra.yml -e "admin_cidr=${admin_cidr}"
ansible-playbook site.yml
