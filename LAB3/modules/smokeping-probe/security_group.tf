# --- security groups -------------------------------------------------------

resource "aws_security_group" "probe" {
  #checkov:skip=CKV_AWS_382:probes need ICMP/DNS to arbitrary targets and docker pulls images
  name        = "${var.name}-sg"
  description = "Smokeping web UI for ${var.name} from allowed CIDRs only"

  # No SSH: shell access is through SSM Session Manager.
  ingress {
    description = "Smokeping web UI"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
  }

  egress {
    description = "Probes to any target, apt and docker image pulls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.name}-sg" })
}
