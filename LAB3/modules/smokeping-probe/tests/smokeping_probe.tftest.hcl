# Unit tests for the smokeping-probe module.
#
# Every run uses `command = plan` against a mocked AWS provider, so the tests
# need no AWS credentials and create nothing. Run from the module directory:
#
#   terraform init -backend=false
#   terraform test

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  # key_name is optional + computed, so a plain plan leaves it unknown. Filling
  # computed values during plan with key_name = null means the planned value is
  # null unless the module configures a key, which is what the test checks.
  mock_resource "aws_instance" {
    override_during = plan
    defaults = {
      key_name = null
    }
  }
}

variables {
  name              = "karool-lab3-test"
  allowed_web_cidrs = ["203.0.113.10/32"]
  targets = [
    { name = "cloudflare", host = "1.1.1.1" },
    { name = "google_dns", host = "8.8.8.8" },
    { name = "dns_cloudflare", host = "1.1.1.1", probe = "DNS", lookup = "taltech.ee" },
  ]
}

# --- rendering ---------------------------------------------------------------

run "renders_targets" {
  command = plan

  assert {
    condition     = strcontains(output.targets_config, "++ cloudflare")
    error_message = "targets_config must contain a \"++ cloudflare\" section for the cloudflare target."
  }

  assert {
    condition     = strcontains(output.targets_config, "host = 1.1.1.1")
    error_message = "targets_config must contain \"host = 1.1.1.1\"."
  }

  assert {
    condition     = strcontains(output.targets_config, "++ dns_cloudflare")
    error_message = "targets_config must contain a \"++ dns_cloudflare\" section for the DNS target."
  }

  assert {
    condition     = strcontains(output.targets_config, "probe = DNS")
    error_message = "targets_config must set \"probe = DNS\" for the DNS target."
  }

  assert {
    condition     = strcontains(output.targets_config, "lookup = taltech.ee")
    error_message = "targets_config must set \"lookup = taltech.ee\" for the DNS target."
  }

  assert {
    condition     = strcontains(output.targets_config, "title = Latency from karool-lab3-test")
    error_message = "targets_config must have the title \"Latency from karool-lab3-test\" derived from var.name."
  }

  # Only the DNS target has a lookup, so exactly one lookup line is rendered.
  assert {
    condition     = length(regexall("(?m)^lookup = ", output.targets_config)) == 1
    error_message = "targets_config must render a lookup line only for targets that set lookup (expected exactly one)."
  }

  # With a mocked provider the planned user_data is the raw rendered script.
  assert {
    condition     = strcontains(aws_instance.probe.user_data, output.targets_config)
    error_message = "aws_instance.probe.user_data must embed the rendered Targets file."
  }

  assert {
    condition     = strcontains(aws_instance.probe.user_data, "+ DNS\nbinary = /usr/bin/dig")
    error_message = "aws_instance.probe.user_data must embed the rendered Probes file with the DNS probe."
  }

  assert {
    condition     = strcontains(aws_instance.probe.user_data, "-e TZ='Europe/Tallinn'")
    error_message = "aws_instance.probe.user_data must pass var.timezone (default Europe/Tallinn) to the container."
  }

  assert {
    condition     = aws_instance.probe.user_data_replace_on_change == true
    error_message = "user_data_replace_on_change must be true so a config change replaces the instance."
  }
}

# --- instance hardening --------------------------------------------------------

run "security_defaults" {
  command = plan

  assert {
    condition     = aws_instance.probe.metadata_options[0].http_tokens == "required"
    error_message = "The instance must require IMDSv2 (metadata_options.http_tokens = \"required\")."
  }

  assert {
    condition     = aws_instance.probe.root_block_device[0].encrypted == true
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = aws_instance.probe.key_name == null
    error_message = "The instance must not have an SSH key pair (access is through SSM only)."
  }

  assert {
    condition     = aws_instance.probe.ebs_optimized == true
    error_message = "The instance must be EBS optimized."
  }

  assert {
    condition     = aws_instance.probe.iam_instance_profile == "karool-lab3-test-profile"
    error_message = "The instance must use the module's instance profile \"karool-lab3-test-profile\"."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The role must have AmazonSSMManagedInstanceCore attached so SSM Session Manager works."
  }
}

# --- security group ------------------------------------------------------------

run "web_ui_only_from_allowed_cidrs" {
  command = plan

  variables {
    allowed_web_cidrs = ["203.0.113.10/32", "198.51.100.0/24"]
  }

  assert {
    condition     = length(aws_security_group.probe.ingress) == 1
    error_message = "The security group must have exactly one ingress rule (the web UI)."
  }

  assert {
    condition     = one(aws_security_group.probe.ingress).from_port == 80 && one(aws_security_group.probe.ingress).to_port == 80
    error_message = "The only ingress rule must be for port 80."
  }

  assert {
    condition     = one(aws_security_group.probe.ingress).protocol == "tcp"
    error_message = "The only ingress rule must be TCP."
  }

  assert {
    condition     = one(aws_security_group.probe.ingress).cidr_blocks == var.allowed_web_cidrs
    error_message = "The web UI ingress must allow exactly var.allowed_web_cidrs."
  }

  assert {
    condition     = !contains(one(aws_security_group.probe.ingress).cidr_blocks, "0.0.0.0/0")
    error_message = "The web UI must not be open to 0.0.0.0/0."
  }

  assert {
    condition = alltrue([
      for rule in aws_security_group.probe.ingress :
      !(rule.from_port <= 22 && rule.to_port >= 22) && rule.protocol != "-1"
    ])
    error_message = "No ingress rule may open port 22 (or all ports); shell access is through SSM only."
  }
}

# --- ami -----------------------------------------------------------------------

run "ami_lookup_when_not_pinned" {
  command = plan

  variables {
    ami_id = null
  }

  assert {
    condition     = length(data.aws_ami.ubuntu) == 1
    error_message = "The Ubuntu AMI must be looked up when ami_id is null."
  }

  assert {
    condition     = aws_instance.probe.ami == "ami-0123456789abcdef0"
    error_message = "The instance must use the looked-up AMI when ami_id is null."
  }
}

run "pinned_ami_is_used" {
  command = plan

  variables {
    ami_id = "ami-0fedcba9876543210"
  }

  assert {
    condition     = length(data.aws_ami.ubuntu) == 0
    error_message = "The Ubuntu AMI must not be looked up when ami_id is pinned."
  }

  assert {
    condition     = aws_instance.probe.ami == "ami-0fedcba9876543210"
    error_message = "The instance must use the pinned ami_id."
  }
}

# --- naming and tags -----------------------------------------------------------

run "all_names_derive_from_var_name" {
  command = plan

  variables {
    name = "karool-lab3-naming"
  }

  assert {
    condition     = startswith(aws_security_group.probe.name, var.name)
    error_message = "The security group name must start with var.name."
  }

  assert {
    condition     = startswith(aws_iam_role.probe.name, var.name)
    error_message = "The IAM role name must start with var.name (IAM names are account-wide)."
  }

  assert {
    condition     = startswith(aws_iam_instance_profile.probe.name, var.name)
    error_message = "The instance profile name must start with var.name (IAM names are account-wide)."
  }

  assert {
    condition     = startswith(aws_instance.probe.tags["Name"], var.name)
    error_message = "The instance Name tag must start with var.name."
  }

  assert {
    condition     = output.iam_role_name == aws_iam_role.probe.name
    error_message = "The iam_role_name output must return the role's name."
  }
}

run "module_tags_applied" {
  command = plan

  variables {
    tags = { Owner = "karool" }
  }

  assert {
    condition     = aws_instance.probe.tags["Owner"] == "karool"
    error_message = "The instance must carry the caller's tags (Owner = karool)."
  }

  assert {
    condition     = aws_instance.probe.tags["Module"] == "smokeping-probe"
    error_message = "The instance must carry the Module = smokeping-probe tag."
  }

  assert {
    condition     = aws_security_group.probe.tags["Owner"] == "karool" && aws_iam_role.probe.tags["Owner"] == "karool"
    error_message = "The security group and IAM role must carry the caller's tags."
  }

  # Regression test for 1.0.1: tagging the instance profile needs
  # iam:TagInstanceProfile, which the shared student account denies.
  assert {
    condition     = aws_iam_instance_profile.probe.tags == null
    error_message = "The instance profile must stay untagged (iam:TagInstanceProfile is denied in restricted accounts)."
  }

  assert {
    condition     = aws_instance.probe.root_block_device[0].tags["Owner"] == "karool"
    error_message = "The root volume must carry the caller's tags."
  }
}

# --- input validation ----------------------------------------------------------

run "rejects_empty_targets" {
  command = plan

  variables {
    targets = []
  }

  expect_failures = [var.targets]
}

run "rejects_unknown_probe" {
  command = plan

  variables {
    targets = [{ name = "taltech", host = "www.taltech.ee", probe = "HTTP" }]
  }

  expect_failures = [var.targets]
}

run "rejects_dns_target_without_lookup" {
  command = plan

  variables {
    targets = [{ name = "dns_cloudflare", host = "1.1.1.1", probe = "DNS" }]
  }

  expect_failures = [var.targets]
}

run "rejects_target_name_with_dot" {
  command = plan

  variables {
    targets = [{ name = "www.taltech", host = "www.taltech.ee" }]
  }

  expect_failures = [var.targets]
}

run "rejects_duplicate_target_names" {
  command = plan

  variables {
    targets = [
      { name = "cloudflare", host = "1.1.1.1" },
      { name = "cloudflare", host = "1.0.0.1" },
    ]
  }

  expect_failures = [var.targets]
}

run "rejects_bad_module_name" {
  command = plan

  variables {
    name = "Karool_Lab3"
  }

  expect_failures = [var.name]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    allowed_web_cidrs = ["300.1.1.1/32"]
  }

  expect_failures = [var.allowed_web_cidrs]
}

run "rejects_non_cidr_string" {
  command = plan

  variables {
    allowed_web_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.allowed_web_cidrs]
}

run "rejects_empty_allowed_web_cidrs" {
  command = plan

  variables {
    allowed_web_cidrs = []
  }

  expect_failures = [var.allowed_web_cidrs]
}

run "rejects_malformed_ami_id" {
  command = plan

  variables {
    ami_id = "ami-XYZ"
  }

  expect_failures = [var.ami_id]
}
