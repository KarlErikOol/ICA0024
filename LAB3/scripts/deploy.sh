#!/usr/bin/env bash
# Create or update both Smokeping probes (Estonia + global) in eu-north-1.
# Safe to run again at any time, e.g. after your public IP changes.
# Usage: ./scripts/deploy.sh [extra terraform apply args, e.g. -auto-approve]
set -euo pipefail
cd "$(dirname "$0")/../infra"

# Only this laptop's current public IP may open the web UIs.
admin_cidr="$(curl -fsS https://checkip.amazonaws.com)/32"
echo "Deploying probes, web UIs allowed from ${admin_cidr}"

terraform init -input=false >/dev/null
terraform apply -var "admin_cidr=${admin_cidr}" "$@"

cat <<EOF

Estonia probe: $(terraform output -raw estonia_url)
Global probe:  $(terraform output -raw global_url)

Boot log (no shell on the probes):
  aws ec2 get-console-output --instance-id $(terraform output -raw estonia_instance_id) --latest --region eu-north-1 --output text
  aws ec2 get-console-output --instance-id $(terraform output -raw global_instance_id) --latest --region eu-north-1 --output text

Smokeping measures every 5 minutes; give it a few rounds before graphs appear.
If your IP changes, run this script again: it updates the security group in place.
EOF
