output "instance_id" {
  description = "ID of the probe instance, e.g. for aws ec2 get-console-output (boot log)."
  value       = aws_instance.probe.id
}

output "public_ip" {
  description = "Public IP of the probe instance."
  value       = aws_instance.probe.public_ip
}

output "url" {
  description = "Smokeping web UI, reachable only from allowed_web_cidrs."
  value       = "http://${aws_instance.probe.public_ip}${local.web_path}"
}

output "security_group_id" {
  description = "ID of the probe's security group."
  value       = aws_security_group.probe.id
}

output "targets_config" {
  description = "Rendered Smokeping Targets file."
  value       = local.targets_config
}
