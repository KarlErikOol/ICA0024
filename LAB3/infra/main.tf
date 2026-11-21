# Consumer of the smokeping-probe module: the same tested module deployed
# twice with different inputs, to compare latency from Stockholm to Estonian
# services with latency to global services.
#
# The module is pinned to a release tag, never a branch, so module changes
# only arrive here when this file bumps the ref.

provider "aws" {
  region = "eu-north-1" # course region (Stockholm)
}

# The module merges these into every resource, including the root volume.
locals {
  tags = {
    Project   = "karool-lab3"
    Owner     = "karool"
    ManagedBy = "terraform"
  }
}

# A module source must be a literal, so the ref is repeated: bump both together.
module "probe_estonia" {
  source = "git::https://github.com/KarlErikOol/ICA0024.git//LAB3/modules/smokeping-probe?ref=lab3-v2.0.0"

  name              = "karool-lab3-estonia"
  targets           = var.estonia_targets
  allowed_web_cidrs = [var.admin_cidr]
  tags              = local.tags
}

module "probe_global" {
  source = "git::https://github.com/KarlErikOol/ICA0024.git//LAB3/modules/smokeping-probe?ref=lab3-v2.0.0"

  name              = "karool-lab3-global"
  targets           = var.global_targets
  allowed_web_cidrs = [var.admin_cidr]
  tags              = local.tags
}
