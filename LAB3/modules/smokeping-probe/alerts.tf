# --- alerts ----------------------------------------------------------------

# Optional email alert when the probe fails its EC2 status checks. Every
# resource here is toggled by count on var.alert_email, which defaults to
# null, so a caller that does not set it gets exactly the same plan as before:
# the default interface is unchanged and this is a backwards-compatible minor
# release.

resource "aws_sns_topic" "alerts" {
  count = var.alert_email == null ? 0 : 1

  name = "${var.name}-alerts"
  # Encrypted at rest with the AWS-managed key: no customer key to create or
  # pay for, and CloudWatch can still publish to it.
  kms_master_key_id = "alias/aws/sns"

  tags = merge(local.tags, { Name = "${var.name}-alerts" })
}

# AWS emails a confirmation link first; the subscription stays pending (and
# no alerts arrive) until someone clicks it.
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Basic monitoring publishes the status checks every minute for free, so this
# works with monitoring = false on the instance.
resource "aws_cloudwatch_metric_alarm" "status_check" {
  count = var.alert_email == null ? 0 : 1

  alarm_name        = "${var.name}-status-check"
  alarm_description = "Smokeping probe ${var.name} has failed its EC2 status checks for 3 minutes."

  namespace   = "AWS/EC2"
  metric_name = "StatusCheckFailed"
  dimensions = {
    InstanceId = aws_instance.probe.id
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  # A stopped or terminated instance publishes no data; that is not an outage
  # worth an email.
  treat_missing_data = "missing"

  alarm_actions = [aws_sns_topic.alerts[0].arn]
  ok_actions    = [aws_sns_topic.alerts[0].arn]

  tags = merge(local.tags, { Name = "${var.name}-status-check" })
}
