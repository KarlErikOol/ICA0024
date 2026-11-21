# One Smokeping probe: a single EC2 instance running the linuxserver/smokeping
# container, measuring latency to var.targets. The web UI is open only to
# var.allowed_web_cidrs. There is no shell access and no IAM role: user_data
# configures everything at first boot, and the probe never calls AWS APIs.

locals {
  tags = merge(var.tags, { Module = "smokeping-probe" })

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id

  # The URL the image's README documents. Kept in one place so the url output
  # follows if the image's path changes.
  web_path = "/smokeping/smokeping.cgi"

  targets_config = templatefile("${path.module}/templates/Targets.tftpl", {
    title   = "Latency from ${var.name}"
    targets = var.targets
  })

  probes_config = templatefile("${path.module}/templates/Probes.tftpl", {})

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    targets_config = local.targets_config
    probes_config  = local.probes_config
    timezone       = var.timezone
  })
}

# --- ami -------------------------------------------------------------------

# Only looked up when no AMI is pinned.
data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- instance --------------------------------------------------------------

# Runs in the default VPC's default subnet, which hands out a public IP; the
# probe needs outbound internet for apt, docker pulls and the probes.
resource "aws_instance" "probe" {
  #checkov:skip=CKV_AWS_126:detailed monitoring costs extra and is not needed for a lab probe
  ami                    = local.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.probe.id]
  ebs_optimized          = true
  monitoring             = false

  user_data = local.user_data
  # The config is only written at first boot, so a config change must
  # replace the instance to take effect.
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 10
    tags        = merge(local.tags, { Name = var.name })
  }

  tags = merge(local.tags, { Name = var.name })

  # The AMI lookup returns a newer image whenever Canonical publishes one.
  # Without this, the next apply would replace the probe and its graph
  # history. Roll to a new image on purpose with `terraform apply -replace`.
  lifecycle {
    ignore_changes = [ami]
  }
}
