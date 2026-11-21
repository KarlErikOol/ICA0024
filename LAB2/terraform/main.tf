# Root module: shared lookups plus one call of the web module.
#
# The environment is the Terraform workspace (dev/prod), so each environment
# has its own state. <env>.tfvars only sets sizes; scripts/deploy.sh picks both.

locals {
  project = "karool-lab2"
  env     = terraform.workspace
  name    = "${local.project}-${local.env}"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = local.project
      Environment = local.env
      ManagedBy   = "terraform"
    }
  }
}

# The default VPC has a public subnet in every AZ, so there's no network code.
data "aws_vpc" "default" {
  default = true

  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = "Select an environment first: terraform workspace select dev (or use scripts/deploy.sh)."
    }
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Newest image built in Lab 1 (Packer + Ansible roles common and nginx).
data "aws_ami" "web" {
  most_recent = true
  owners      = ["self"] # the whole shared student account, hence the tag filter too

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }
  filter {
    name   = "tag:Project"
    values = ["karool-lab1"]
  }
}

module "web" {
  source = "./modules/web"

  name          = local.name
  env           = local.env
  vpc_id        = data.aws_vpc.default.id
  subnet_ids    = data.aws_subnets.default.ids
  ami_id        = data.aws_ami.web.id
  instance_type = var.instance_type
  min_size      = var.min_size
  max_size      = var.max_size
}
