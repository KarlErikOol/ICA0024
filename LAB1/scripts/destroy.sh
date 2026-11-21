#!/usr/bin/env bash
# Tear down one environment; the other keeps running.
# Usage: ./scripts/destroy.sh dev|prod [-e purge_amis=true]
set -euo pipefail
cd "$(dirname "$0")/../ansible"

env="${1:-}"
if [[ -z "$env" || ! -d "inventories/$env" ]]; then
  echo "usage: $0 <env> [-e purge_amis=true]   (one of: $(ls inventories | xargs))" >&2
  exit 1
fi
shift

ansible-playbook -i "inventories/$env" destroy.yml "$@"
