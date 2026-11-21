# State is local (terraform.tfstate in this directory, git-ignored): one
# student, one copy of the lab, so a remote backend would add nothing.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
