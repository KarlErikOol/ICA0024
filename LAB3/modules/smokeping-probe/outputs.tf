output "instance_id" {
  description = "ID of the probe instance, e.g. for aws ssm start-session."
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

output "iam_role_name" {
  description = "Name of the probe's IAM role."
  value       = aws_iam_role.probe.name
}
