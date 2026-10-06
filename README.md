# Instantly infrastructure

Canonical repository: `/Users/faruk/dev/workspace/instantly-infra`.
Staging is deployed; see docs/STAGING-STATUS.md for verified runtime status.
Production is scaffolded for later.

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
| Location | Nürnberg (`nbg1`) | Falkenstein (`fsn1`) |
| Server type (APP / DATA) | CX23 / CX23 | CX33 / CX33 |
| Database storage | DATA root disk | Separate 50 GB volume |
| Local state | stg root's `terraform.tfstate` | prod root's `terraform.tfstate` |

Each environment gets its own two servers, network, keys and firewalls.
Only prod gets a separate retained data volume.
The shared module avoids infrastructure drift. The environment is fixed in each
root, not selected by tfvars or Terraform workspaces. Run commands in the intended
root; never copy state between them. Backend paths resolve relative to that root.
Hetzner projects are separate: `instantly-stg` and `instantly-prod`. Each has its
own project-scoped API token in its environment directory’s gitignored `.env`.
Never put the production Hetzner token in the staging file, or vice versa.
Cloudflare can use the same existing authoritative zone; GoDaddy stays registrar.

APP has public + private networking and hosts Coolify/apps/wg-easy/CoreDNS. DATA
has private networking only and hosts PostgreSQL/Redis. APP supplies outbound NAT
for DATA. VPN clients use split-tunnel routes. Runtime services stay under Coolify.

## Start staging

```sh
cd /Users/faruk/dev/workspace/instantly-infra/terraform/environments/stg
cp terraform.tfvars.example terraform.tfvars
# Replace tfvars placeholders and fill this directory’s .env from .env.example.
cd /Users/faruk/dev/workspace/instantly-infra
./scripts/tf.sh stg init
./scripts/tf.sh stg validate
./scripts/tf.sh stg plan -out=changes.tfplan
# Review before running: ./scripts/tf.sh stg apply changes.tfplan
```

Required values in gitignored `terraform.tfvars`: `domain` (the base authoritative
zone, not `stg.<domain>`), `cloudflare_zone_id`, administrator `ssh_public_keys`,
`coolify_ssh_public_key`, and `admin_ipv4_cidrs`. Credentials are read only from
`HCLOUD_TOKEN` and `CLOUDFLARE_API_TOKEN`; private keys belong outside this repo.

Defaults: Ubuntu 24.04, eu-central network zone; stg uses Nürnberg (nbg1),
CX23 servers and the DATA root
disk, while prod uses Falkenstein (fsn1), CX33 servers and a separate 50 GB data volume;
server backups enabled. Confirm availability and costs before apply. Set
`install_coolify = true` before the initial apply for automatic installation;
otherwise follow the manual installer step in the runbook. Staging data lives under `/data/instantly` on DATA-01 and is lost if that server
is deleted/rebuilt. Off-host
backups still apply. No secrets, real
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

## Credentials per environment

- `terraform/environments/stg/.env`: token from the `instantly-stg` Hetzner project.
- `terraform/environments/prod/.env`: token from the `instantly-prod` Hetzner project.

Both use the variable name `HCLOUD_TOKEN`, but load different values. The helper
`scripts/tf.sh stg|prod ...` clears inherited provider tokens and loads only the
chosen environment's file; it rejects blank tokens. It cannot detect a token
accidentally pasted into the wrong file. Terraform itself does not load `.env`.
The existing root `.env` has been relocated to staging, preserving its contents.
Local credential files are chmod 600, gitignored, and plaintext on disk.

Staging uses the `instantlyhere.com` Cloudflare zone. Production is unchanged.

## Staging application object storage

Terraform also creates the private `anonly-instantly-stg-app` bucket in Nuremberg
through Hetzner's S3 API (MinIO provider). Endpoint:
`https://nbg1.your-objectstorage.com`, region `nbg1`. No extra server volume is needed.
Bucket deletion is guarded by `prevent_destroy` and `force_destroy = false`.
This bucket stores application objects; it is not a backup bucket or state backend.
Production has no application bucket provisioned by this change.

The persona management feature adds a separate private draft-photo bucket,
`anonly-instantly-stg-agents` (`agents_bucket_name`). It has the same deletion
protection and is independent of published member media. Its runtime database,
shared registration secret and existing VPN routing are documented in
[Agents backend deployment](services/agents-backend/README.md). NVIDIA supplies
text, vision review and portrait generation through a backend runtime API key.
Muse Glimmer 30B is the default; supported text/vision models are selectable per job.
Locally prepared profile text and photos can also be submitted together through
the private import API for human review, without provider calls.

In the **instantly-stg** Hetzner project, open **Security → S3 Credentials →
Generate credentials**. Put the Access Key in `MINIO_USER` and Secret Key in
`MINIO_PASSWORD` in `terraform/environments/stg/.env`. These are different from
the Cloud API token. Do not commit them. The helper requires these credentials
for staging and clears inherited S3 credentials when switching environments.

Use the bucket/endpoint/region output in the application's Coolify configuration;
store S3 credentials in Coolify secrets. Never ship them to the browser. Downloads
can go through the application or use signed URLs. Public access and browser
upload CORS have not been enabled. Project S3 keys must not be treated as
bucket-scoped application credentials; review bucket policy access before production.

Both staging buckets are now provisioned. The agents rollout applied a reviewed
plan containing one new private bucket, no updates and no deletions. Run a fresh
plan for later infrastructure changes; do not reuse old saved plans.

Reference: https://docs.hetzner.com/storage/object-storage/getting-started/creating-a-bucket-minio-terraform/
