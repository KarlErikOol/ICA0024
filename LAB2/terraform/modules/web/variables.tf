variable "name" {
  type        = string
  description = "Prefix for every resource name, e.g. karool-lab2-dev."
}

variable "env" {
  type        = string
  description = "Environment name, shown on the page."
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets in different AZs for the load balancer and the servers."
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}
