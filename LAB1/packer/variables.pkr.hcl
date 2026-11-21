variable "project" {
  type    = string
  default = "iac-lab1"
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Only for the temporary build instance."
}
