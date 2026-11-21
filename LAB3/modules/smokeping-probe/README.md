# smokeping-probe

A Terraform module that deploys one EC2 instance (Canonical Ubuntu 24.04)
running the [linuxserver/smokeping](https://docs.linuxserver.io/images/docker-smokeping/)
container, pinned to `lscr.io/linuxserver/smokeping:2.9.0-r0-ls190`. The
instance measures latency to a configurable list of targets with the FPing
(ICMP) and DNS probes. The web UI listens on port 80 and accepts traffic only
from the CIDRs you allow. The probe is configured entirely at boot, so it has
no shell access and needs no AWS API access.

## Usage

```hcl
module "probe_estonia" {
  source            = "git::https://github.com/KarlErikOol/ICA0024.git//LAB3/modules/smokeping-probe?ref=lab3-v3.0.0"
  name              = "karool-lab3-estonia"
  allowed_web_cidrs = ["203.0.113.10/32"]
  targets = {
    taltech        = { host = "www.taltech.ee" }
    dns_cloudflare = { host = "1.1.1.1", probe = "DNS", lookup = "taltech.ee" }
  }
  # alert_email = "you@example.com" # optional, see Alerts
}
```

Always pin `?ref=` to a release tag, never to a branch. A branch moves, so the
same code could deploy something different tomorrow.

The module has no `provider` block. The instance is created in the region of
the caller's AWS provider, in that region's default VPC and default subnet.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Prefix for every resource name, e.g. `karool-lab3-estonia`. Must be unique in the AWS account and region. 3–40 characters: lowercase letters, digits and hyphens. |
| `targets` | `map(object)` keyed by name, see below | required | Hosts to measure. At least one. Names are map keys, so they are unique by construction. |
| `allowed_web_cidrs` | `list(string)` | required | IPv4 CIDRs allowed to open the web UI on port 80. At least one, and each must be a valid CIDR (e.g. `203.0.113.10/32`). There is no default, so the UI is never public by accident. |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type for the probe. |
| `ami_id` | `string` | `null` | AMI for the probe. `null` uses the latest Canonical Ubuntu 24.04 (amd64) in the provider's region. If set, it must look like `ami-0123456789abcdef0`. |
| `timezone` | `string` | `"Europe/Tallinn"` | Time zone (`TZ`) of the Smokeping container, used for graph timestamps. |
| `tags` | `map(string)` | `{}` | Extra tags merged into every resource. |
| `alert_email` | `string` | `null` | Email address that gets an alert when the instance fails its EC2 status checks. `null` turns alerting off. If set, it must look like an email address. See [Alerts](#alerts). |

Each `targets` key is the Smokeping section name and menu label: letters,
digits and underscores only (no dots, spaces or hyphens). Fields of each value:

| Field | Type | Default | Description |
|---|---|---|---|
| `host` | `string` | required | Hostname or IP address to measure. |
| `probe` | `string` | `"FPing"` | `"FPing"` (ICMP ping) or `"DNS"` (DNS query sent to `host`). Case-sensitive. |
| `lookup` | `string` | `null` | Name the DNS probe asks `host` to resolve. Required when `probe = "DNS"`, ignored otherwise. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | ID of the probe instance, e.g. for `aws ec2 get-console-output`. |
| `public_ip` | Public IP of the probe instance. |
| `url` | Smokeping web UI (`http://<public_ip>/smokeping/smokeping.cgi`), reachable only from `allowed_web_cidrs`. |
| `security_group_id` | ID of the probe's security group. |
| `targets_config` | The rendered Smokeping `Targets` file. Lets you review the generated config in `terraform plan` and in tests. |
| `alert_topic_arn` | ARN of the alerts SNS topic, or `null` when `alert_email` is not set. |

## Fixed conventions

Consumers can't change these, so they can't get them wrong:

- **IMDSv2 only.** `http_tokens = "required"` on the instance metadata service.
- **Encrypted disk.** The root volume is 10 GB `gp3` with `encrypted = true`, and
  the instance is `ebs_optimized`.
- **No shell access.** No key pair, no port 22, no IAM role; the probe is
  configured entirely at boot.
- **Self-restarting container.** The container runs with `--restart unless-stopped`,
  so it comes back after a reboot or a crash.
- **Names derived from `name`.** The security group is `<name>-sg`, and the
  instance and its volume are tagged `Name = <name>`. In a shared AWS account, a unique `name`
  per student and per probe is all you need to avoid collisions.
- **Tags.** Every resource that supports tags gets `var.tags` merged with
  `Module = "smokeping-probe"` (an SNS subscription can't be tagged).

## Adding a target

Add an entry to the `targets` map. The module code never changes, and new
targets need no new code (open–closed principle):

```hcl
targets = {
  taltech = { host = "www.taltech.ee" }
  github  = { host = "github.com" } # new
}
```

The Smokeping config is written to disk only at first boot (user_data), so the
module sets `user_data_replace_on_change = true`. Any change to `targets` or
`timezone` therefore **replaces the instance**. The new instance gets a new
public IP, and the graph history starts again from zero.

## Access

- **Web UI:** open the `url` output in a browser from an address in
  `allowed_web_cidrs`. The first graphs appear a few minutes after boot.
- **Boot log:** there is no shell on the probe. To see what user_data did at
  first boot (the cloud-init log), read the instance's console output:

  ```sh
  aws ec2 get-console-output --instance-id <instance_id> --latest --region eu-north-1 --output text
  ```

  Use the region your provider deploys to. This needs only the AWS CLI. The
  web UI itself is the proof that the probe works.

## Alerts

Alerting is off by default. Set `alert_email` to get an email when the probe
instance fails its EC2 status checks (the instance or the host it runs on is
unhealthy). The module then creates:

- an SNS topic `<name>-alerts`, encrypted with the AWS-managed key
  `alias/aws/sns`;
- an email subscription to `alert_email`;
- a CloudWatch alarm `<name>-status-check` on `AWS/EC2` `StatusCheckFailed` for
  the probe instance. It goes to ALARM after 3 failed one-minute checks in a row
  and notifies the topic, and notifies again when the instance is OK.

AWS first sends a confirmation email to `alert_email`. Alerts arrive only after
you click the link in it; until then the subscription stays pending and
`terraform apply` still succeeds. Basic monitoring is enough: EC2 reports
status checks every minute at no extra cost, so detailed monitoring stays off.
The `alert_topic_arn` output is `null` when alerting is off.

## Requirements

| | Version |
|---|---|
| Terraform | `>= 1.7.0` |
| AWS provider (`hashicorp/aws`) | `~> 6.0` |

The instance needs outbound internet access for `apt`, the container image pull
and the probes themselves. The default VPC's public subnet provides this: the
instance gets a public IP and the security group allows all egress.

## Design notes

- **One probe per module call.** To measure from several places, call the module
  once per region, each with its own provider alias and a unique `name`.
- **Config from Terraform, not from the image.** user_data writes only the
  `Targets` and `Probes` files into the container's `/config`. The image keeps
  existing files and supplies all other config files with its defaults.
- **AMI lookup.** With `ami_id = null`, the instance launches from the newest
  Ubuntu 24.04 image. Later AMI changes, whether a new Canonical image or a new
  `ami_id`, are ignored (`lifecycle { ignore_changes = [ami] }`), so the probe
  and its graph history are never replaced by surprise. To move to a newer image
  on purpose: `terraform apply -replace='module.<name>.aws_instance.probe'`.
- **Pinned container tag.** The image tag is fixed in
  `templates/user_data.sh.tftpl`, so a new upstream release can't change a probe
  that has already been deployed.
- **Lightweight on purpose.** It uses the default VPC (no network code or NAT
  costs) and plain HTTP (HTTPS would need a domain and a certificate). Detailed
  monitoring is off.

## Testing

```sh
LAB3/scripts/check.sh
```

This runs all checks locally:

| Check | What it catches |
|---|---|
| `terraform fmt -check` | Formatting drift |
| `terraform validate` | Wrong references, argument names, types |
| `tflint` (`.tflint.hcl`, terraform + aws rulesets) | Invalid instance types, unused declarations, deprecated syntax |
| `checkov` | Security findings: open ingress, unencrypted disks, IMDSv1, ... |
| `terraform test` | Module behaviour, tested against a mocked AWS provider |

None of these need AWS credentials, because nothing is planned against or
applied to a real account. The same checks run in GitHub Actions in the
`lab3-ci` workflow on every push and pull request that touches `LAB3/`.

## Releases

Versions are git tags `lab3-vX.Y.Z`. The tags are repo-wide, so they carry a
`lab3-` prefix. The manual `lab3-release` workflow creates them: it re-runs
`lab3-ci`, bumps the version and tags the commit. It then publishes a GitHub
release with the matching section of [CHANGELOG.md](CHANGELOG.md) as release
notes, so add that section before releasing.

Versioning follows [semver](https://semver.org/):

| Bump | When |
|---|---|
| patch | Bug fix, same interface |
| minor | New optional feature (e.g. a new input with a default) |
| major | Breaking interface change (removed or renamed input/output, new required input) |
