# Changelog

All notable changes to the `smokeping-probe` module. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/), and each version is released as the
git tag `lab3-vX.Y.Z`.

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
