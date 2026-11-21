#!/usr/bin/env bash
# Build the base AMI with Packer (runs ansible/bake.yml on a temporary instance).
set -euo pipefail
cd "$(dirname "$0")/../packer"

packer init .
packer validate .
packer build .
