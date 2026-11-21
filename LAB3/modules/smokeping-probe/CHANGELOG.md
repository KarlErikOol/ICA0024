# Changelog

All notable changes to the `smokeping-probe` module. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/), and each version is released as the
git tag `lab3-vX.Y.Z`.

## [2.1.0] - 2026-11-21

### Added

- Optional email alerting when the probe instance fails its EC2 status checks,
  turned on with the new `alert_email` input (default `null`, validated as a
  plausible email address). When it is set, the module creates an SNS topic
  `<name>-alerts` (encrypted with the AWS-managed key `alias/aws/sns`), an email
  subscription to `alert_email`, and a CloudWatch alarm `<name>-status-check` on
  `AWS/EC2` `StatusCheckFailed` (maximum over 60 s, 3 periods in a row) that
  notifies the topic on both ALARM and OK.
- Output `alert_topic_arn`: the ARN of the SNS topic, or `null` when alerting is
  off.
- AWS first sends a confirmation email to `alert_email`. Alerts arrive only after
  the link in it is clicked; until then the subscription stays pending.
- Backwards compatible: with the default `alert_email = null` the module creates
  nothing new, so existing callers only need to bump `?ref=` to `lab3-v2.1.0`.

## [2.0.0] - 2026-11-21

### Removed

- The IAM role `<name>-role`, its `AmazonSSMManagedInstanceCore` policy
  attachment, the instance profile `<name>-profile` and the `iam_role_name`
  output. They existed only to give a person a shell through SSM Session
  Manager, and that can't work in the shared TalTech student account: 1.0.0
  failed because `iam:TagInstanceProfile` is denied, and 1.0.1 then failed
  because `iam:GetInstanceProfile` is denied as well, so a role can't be
  attached to a profile there. Smokeping never needed it: user_data writes the
  config and starts the container at first boot, so the probe needs no shell and
  no AWS API access. There is still no key pair and no port 22.
- The tagging exception for the instance profile. Every resource now gets
  `var.tags` merged with `Module = "smokeping-probe"`.

### Migration

- Remove any use of `module.<name>.iam_role_name`. There is no shell on the
  probe anymore; use `aws ec2 get-console-output` to read the boot log. Bump
  `?ref=` to `lab3-v2.0.0`, run `terraform init -upgrade`; the plan destroys the
  role and policy attachment and creates nothing new for IAM.

## [1.0.1] - 2026-11-21

### Fixed

- The instance profile is no longer tagged. Tagging it needs
  `iam:TagInstanceProfile`, which the shared TalTech student account denies, so
  `lab3-v1.0.0` failed to apply there with `AccessDenied`. The profile keeps its
  `<name>-profile` name, and the IAM role it wraps is still tagged.

## [1.0.0] - 2026-11-21

### Added

- One EC2 instance (Canonical Ubuntu 24.04) running the
  `lscr.io/linuxserver/smokeping:2.9.0-r0-ls190` container, with the web UI on
  port 80.
- Inputs `name`, `targets`, `allowed_web_cidrs`, `instance_type`, `ami_id`,
  `timezone` and `tags`. Validation covers the name format, a non-empty target
  list, unique target names that are valid Smokeping section names, the
  allowed probe types, DNS targets having a `lookup`, valid CIDRs and the AMI ID
  format.
- `targets` as the single extension point: adding a target is a list item, not a
  code change.
- FPing (ICMP) and DNS probes, selectable per target.
- Security group that allows port 80 only from `allowed_web_cidrs` (required, no
  default). No SSH.
- Shell access only through SSM Session Manager (instance role with
  `AmazonSSMManagedInstanceCore`, no key pair).
- Secure defaults: IMDSv2 only, encrypted gp3 root volume, `ebs_optimized`.
- Lookup of the latest Canonical Ubuntu 24.04 AMI, with an optional pin through
  `ami_id`. Later AMI changes are ignored, so a new Ubuntu image never replaces
  a running probe.
- Instance replaced automatically when the rendered config changes
  (`user_data_replace_on_change`).
- Outputs `instance_id`, `public_ip`, `url`, `security_group_id`,
  `iam_role_name` and `targets_config`.
- Tests with `terraform test` against a mocked AWS provider (no credentials
  needed).
