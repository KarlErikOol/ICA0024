# No default: scripts/deploy.sh passes your current public IP as /32.
variable "admin_cidr" {
  type        = string
  description = "IPv4 CIDR allowed to open both Smokeping web UIs, e.g. 203.0.113.10/32."

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("^[0-9.]+/[0-9]+$", var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR, e.g. 203.0.113.10/32."
  }
}

# Same type as the module's targets input. Names are Smokeping section names,
# so only letters, digits and underscores (^[A-Za-z0-9_]+$).

variable "estonia_targets" {
  type = list(object({
    name   = string
    host   = string
    probe  = optional(string, "FPing")
    lookup = optional(string)
  }))
  description = "Estonian services measured by the karool-lab3-estonia probe."
  default = [
    { name = "taltech", host = "www.taltech.ee" },
    { name = "err", host = "www.err.ee" },
    { name = "neti", host = "www.neti.ee" },
    { name = "eesti", host = "www.eesti.ee" },
    { name = "dns_cloudflare_taltech", host = "1.1.1.1", probe = "DNS", lookup = "taltech.ee" },
  ]
}

variable "global_targets" {
  type = list(object({
    name   = string
    host   = string
    probe  = optional(string, "FPing")
    lookup = optional(string)
  }))
  description = "Global services measured by the karool-lab3-global probe."
  default = [
    { name = "cloudflare", host = "1.1.1.1" },
    { name = "google_dns", host = "8.8.8.8" },
    { name = "github", host = "github.com" },
    { name = "wikipedia", host = "www.wikipedia.org" },
    { name = "dns_google_github", host = "8.8.8.8", probe = "DNS", lookup = "github.com" },
  ]
}

# Placeholder on purpose: example.com is reserved for documentation, so nobody
# receives the confirmation email and the subscription stays pending. It still
# shows the alert resources being created. Set null to turn alerts off.
variable "alert_email" {
  type        = string
  default     = "alerts@example.com"
  description = "Where status-check alerts go (passed to both probes); null disables them."
}
