variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "ami_name_pattern" {
  type        = string
  default     = "karool-lab1-base-*"
  description = "Name filter for the Lab 1 AMI; the newest match is used."
}

# No defaults below: every environment sets them in its <env>.tfvars.

variable "instance_type" {
  type = string
}

variable "min_size" {
  type        = number
  description = "Servers the auto-scaling group never goes below (also the starting count)."
}

variable "max_size" {
  type        = number
  description = "Upper limit for scaling out under CPU load."
}
