terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Only for the post-deploy check in checks.tf.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
