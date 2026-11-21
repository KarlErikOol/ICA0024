output "estonia_url" {
  description = "Smokeping UI of the Estonia probe (reachable only from admin_cidr)."
  value       = module.probe_estonia.url
}

output "global_url" {
  description = "Smokeping UI of the global probe (reachable only from admin_cidr)."
  value       = module.probe_global.url
}

output "estonia_instance_id" {
  description = "Instance ID; boot log: aws ec2 get-console-output --instance-id <id> --latest --region eu-north-1"
  value       = module.probe_estonia.instance_id
}

output "global_instance_id" {
  description = "Instance ID; boot log: aws ec2 get-console-output --instance-id <id> --latest --region eu-north-1"
  value       = module.probe_global.instance_id
}
