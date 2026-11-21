#!/usr/bin/env bash
# Tear everything down. Add -e purge_amis=true to delete the AMIs as well.
set -euo pipefail
cd "$(dirname "$0")/../ansible"

ansible-playbook destroy.yml "$@"
