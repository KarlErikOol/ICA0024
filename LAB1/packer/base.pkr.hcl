# Base image: latest Ubuntu 24.04 from Canonical + the Ansible roles common and nginx.
# Packer launches a temporary instance, runs ../ansible/bake.yml on it,
# snapshots it as karool-lab1-base-<timestamp> and terminates it.

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "base" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"
  ami_name      = "${var.project}-base-${local.timestamp}"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  # The temporary build SG only allows SSH from this laptop's public IP.
  temporary_security_group_source_public_ip = true

  tags = {
    Name      = "${var.project}-base"
    Project   = var.project
    BaseAMI   = "{{ .SourceAMI }}"
    ManagedBy = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.base"]

  # cloud-init runs apt on first boot; wait so Ansible doesn't hit the apt lock.
  provisioner "shell" {
    inline = ["cloud-init status --wait || true"]
  }

  provisioner "ansible" {
    playbook_file = "${path.root}/../ansible/bake.yml"
    user          = "ubuntu"
    use_proxy     = false
    # Packer doesn't read ansible/ansible.cfg, so repeat what bake.yml needs.
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_PYTHON_INTERPRETER=auto_silent",
    ]
  }
}
