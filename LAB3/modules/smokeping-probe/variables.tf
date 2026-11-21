variable "name" {
  type        = string
  description = "Prefix for every resource name, e.g. karool-lab3-estonia. Make it unique per account and probe: security group names must be unique in the VPC."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.name))
    error_message = "name must be 3-40 characters of lowercase letters, digits and hyphens."
  }
}

variable "targets" {
  # A map keyed by target name: keys are unique by construction, so duplicate
  # names can't happen (in 2.x they needed a validation rule).
  type = map(object({
    host   = string
    probe  = optional(string, "FPing")
    lookup = optional(string)
  }))
  description = "Hosts to measure, keyed by name. The key becomes the Smokeping section name, probe is FPing (ICMP) or DNS, and lookup is the record a DNS probe asks the host for."

  validation {
    condition     = length(var.targets) >= 1
    error_message = "targets must contain at least one target."
  }

  validation {
    condition     = alltrue([for t in values(var.targets) : contains(["FPing", "DNS"], t.probe)])
    error_message = "Every target probe must be \"FPing\" or \"DNS\"."
  }

  # Smokeping section names may not contain dots, spaces or hyphens.
  validation {
    condition     = alltrue([for name in keys(var.targets) : can(regex("^[A-Za-z0-9_]+$", name))])
    error_message = "Every target name may only contain letters, digits and underscores (Smokeping section names)."
  }

  validation {
    condition     = alltrue([for t in values(var.targets) : t.probe != "DNS" || t.lookup != null])
    error_message = "Every target with probe = \"DNS\" needs a lookup (the name to resolve)."
  }
}

variable "allowed_web_cidrs" {
  type        = list(string)
  description = "IPv4 CIDRs allowed to open the Smokeping web UI on port 80. No default, so the UI is never public by accident."

  validation {
    condition     = length(var.allowed_web_cidrs) >= 1
    error_message = "allowed_web_cidrs must contain at least one CIDR."
  }

  # cidrhost() alone also accepts IPv6, which would only fail at apply time
  # (the CIDRs go into the security group's IPv4 cidr_blocks), so also require
  # the IPv4 shape.
  validation {
    condition = alltrue([
      for c in var.allowed_web_cidrs :
      can(cidrhost(c, 0)) && can(regex("^[0-9]+(\\.[0-9]+){3}/[0-9]+$", c))
    ])
    error_message = "Every allowed_web_cidrs item must be a valid IPv4 CIDR, e.g. 203.0.113.10/32."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the probe."
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI for the probe. null means the latest Canonical Ubuntu 24.04 in the provider's region."
  default     = null

  validation {
    condition     = var.ami_id == null ? true : can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be null or look like ami-0123456789abcdef0."
  }
}

variable "timezone" {
  type        = string
  description = "Time zone for the Smokeping container (TZ), used for graph timestamps."
  default     = "Europe/Tallinn"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged into every resource."
  default     = {}
}

variable "alert_email" {
  type        = string
  description = "Email address to notify when the instance fails its EC2 status checks. null (default) disables alerting: no SNS topic, subscription or alarm is created. AWS sends a confirmation email first; alerts only arrive after it is confirmed."
  default     = null

  validation {
    condition     = var.alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be null or an email address like alerts@example.com."
  }
}
