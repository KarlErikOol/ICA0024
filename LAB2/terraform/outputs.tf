output "url" {
  description = "Open this after a deploy."
  value       = "http://${module.web.alb_dns_name}/"
}

output "asg_name" {
  value = module.web.asg_name
}

output "ami_id" {
  description = "Lab 1 AMI the servers launch from."
  value       = data.aws_ami.web.id
}
