# Instantly infrastructure

Canonical repository: `/Users/faruk/dev/workspace/instantly-infra`.
Start with **stg**. Production is scaffolded for later; no cloud resources have
been created for either environment.

## Environments

| | stg (first deployment) | prod (later) |
|---|---|---|
| Terraform root | `terraform/environments/stg` | `terraform/environments/prod` |
| Resource prefix | `instantly-stg` | `instantly-prod` |
| Private network | `10.20.0.0/16` | `10.30.0.0/16` |
| APP / DATA IP | `10.20.0.20` / `10.20.0.30` | `10.30.0.20` / `10.30.0.30` |
| VPN peers | `10.8.0.0/24` | `10.9.0.0/24` |
| Application DNS | `api.stg.<domain>` | `api.<domain>` |
| VPN endpoint | `vpn.stg.<domain>` | `vpn.<domain>` |
| Internal zone | `internal.stg.<domain>` | `internal.<domain>` |
| Local state | stg root's `terraform.tfstate` | prod root's `terraform.tfstate` |

Each environment gets its own two servers, network, volume, keys and firewalls.
The shared module avoids infrastructure drift. The environment is fixed in each
root, not selected by tfvars or Terraform workspaces. Run commands in the intended
root; never copy state between them. Backend paths resolve relative to that root.
Use separate Hetzner projects/tokens if stronger account-level isolation is needed.
Cloudflare can use the same existing authoritative zone; GoDaddy stays registrar.

APP has public + private networking and hosts Coolify/apps/wg-easy/CoreDNS. DATA
has private networking only and hosts PostgreSQL/Redis. APP supplies outbound NAT
for DATA. VPN clients use split-tunnel routes. Runtime services stay under Coolify.

## Start staging

```sh
cd /Users/faruk/dev/workspace/instantly-infra/terraform/environments/stg
cp terraform.tfvars.example terraform.tfvars
# Replace placeholders; inject tokens with your secret manager.
terraform init
terraform validate
terraform plan -out=changes.tfplan
# Review before running: terraform apply changes.tfplan
```

Required values in gitignored `terraform.tfvars`: `domain` (the base authoritative
zone, not `stg.<domain>`), `cloudflare_zone_id`, administrator `ssh_public_keys`,
`coolify_ssh_public_key`, and `admin_ipv4_cidrs`. Credentials are read only from
`HCLOUD_TOKEN` and `CLOUDFLARE_API_TOKEN`; private keys belong outside this repo.

Defaults: Ubuntu 24.04, fsn1/eu-central, cx33 servers, 50 GB persistent data disk,
server backups enabled. Confirm availability and costs before apply. Set
`install_coolify = true` before the initial apply for automatic installation;
otherwise follow the manual installer step in the runbook. No secrets, real
keys, account identifiers or domain choices have been invented.

## Layout and validation

- `terraform/modules/stack`: shared infrastructure and architecture tests.
- `terraform/environments/stg`, `prod`: independent roots, inputs, backend, lock
  files, example tfvars and mocked root-wiring tests.
- `cloud-init`: generated host bootstrap scripts, shared by both environments.
- `services`: staging CoreDNS examples and wg-easy deployment guidance.
- `docs/OPERATIONS.md`: deployment, runtime setup, backups and acceptance checks.
- `scripts/check.sh`: formatting, validation and mocked tests for both roots and
  the module. It does not call live cloud APIs or deploy production.

Local state is a starter backend. Migrate each root to its own encrypted remote
state with locking before collaborative production changes. Git ignores state,
plans, credentials and provider caches. Provider lock files are tracked.

See [validation](docs/VALIDATION.md) for actual checks performed. Static/mock
checks do not replace the live bootstrap, network and restore checks in the
[runbook](docs/OPERATIONS.md). Each environment has single APP/DATA hosts, not HA.
