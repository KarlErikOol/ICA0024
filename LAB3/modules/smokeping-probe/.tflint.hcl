# TFLint config for the module. `tflint --init` downloads the plugins below;
# run `tflint` from this directory so this file is picked up.

# Built-in Terraform language rules: unused declarations, missing types,
# deprecated syntax, missing version constraints, ...
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules: invalid instance types, AMI ids, regions, ...
# things `terraform validate` cannot know about.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
