# One Smokeping probe: a single EC2 instance running the linuxserver/smokeping
# container, measuring latency to var.targets. The web UI is open only to
# var.allowed_web_cidrs and the only shell access is SSM Session Manager.

locals {
  tags = merge(var.tags, { Module = "smokeping-probe" })

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id

  # The URL the image's README documents. Kept in one place so the url output
  # follows if the image's path changes.
  web_path = "/smokeping/smokeping.cgi"

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
  iam_instance_profile   = aws_iam_instance_profile.probe.name
  vpc_security_group_ids = [aws_security_group.probe.id]
  ebs_optimized          = true
  monitoring             = false

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
}
