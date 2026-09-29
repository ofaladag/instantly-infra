# Environment selection

Start in `terraform/environments/stg`. All addresses and example steps below
refer to staging. `domain` is the base Cloudflare zone; staging adds `.stg` to
service names automatically. Production lives in `terraform/environments/prod`
and must be initialized/planned separately. Use the README environment table and
Terraform outputs for its 10.30.x.x addresses, 10.9.x.x VPN and production DNS.
Staging uses CX23 for both hosts and has no attached volume. Its database
directories are on DATA-01 root disk. Prod keeps the separate retained volume.
Each root has a separate local backend/state and provider lock file. Do not use
Terraform workspaces to switch these environments. Do not run apply in the module.
Before using prod, provide its own keys/inputs and plan its separate infrastructure.
There is no deployed state to migrate from the previous starter; do not copy the
old starter state or apply the original generated repository again.

# Apply and finish in Coolify

1. Create/use the Cloudflare zone. At GoDaddy change only nameservers to those
   assigned by Cloudflare. Preserve existing MX/TXT/mail records. Wait for the zone
   to become active. Import existing conflicting A records into Terraform rather
   than creating duplicates. The zone itself is intentionally not managed here.
2. Generate a dedicated Coolify SSH key outside this repository, and supply only
   the public half in tfvars. Store its private half in Coolify later. Supply your
   administrator public key and current public /32 CIDR too.
3. Fill HCLOUD_TOKEN and CLOUDFLARE_API_TOKEN in the selected environment’s
   gitignored .env. Hetzner tokens must come from the corresponding instantly-stg
   or instantly-prod project. Use scripts/tf.sh stg <command> from the repo root
   to load staging tokens; the helper clears inherited tokens first.
   Scope Cloudflare to DNS edit on the chosen zone. Never paste tokens into .tf
   files or command history. Copy terraform.tfvars.example to terraform.tfvars
   and replace every placeholder. Select available machine types and location.
4. With that environment’s credentials loaded, run `terraform init`, `terraform fmt -check`, `terraform validate`, then
   `terraform plan -out=changes.tfplan` inside terraform/environments/stg/. Inspect costs and
   replacements. Only then run `terraform apply changes.tfplan`. Plan and state
   are sensitive and gitignored. `apply` returning does not mean cloud-init ended.
5. On APP and DATA run `cloud-init status --wait --long`, check
   `/var/log/cloud-init-output.log` and `/var/lib/instantly-bootstrap-complete`.
   Reach DATA via the output SSH jump command. Initial DATA apt retries wait for
   APP NAT. A failed bootstrap can be rerun with `/usr/local/sbin/instantly-bootstrap`
   after fixing the cause. Check route/NAT/firewall units (and the mount unit in prod) before continuing.
6. If install_coolify=true was set before initial apply, the official installer
   ran on APP. Otherwise review https://cdn.coollabs.io/coolify/install.sh on APP,
   download it to a file and run it as root with
   `DOCKER_ADDRESS_POOL_BASE=172.20.0.0/16 DOCKER_ADDRESS_POOL_SIZE=24`.
   The installer installs Docker. Its default 10.0.0.0/8 container pool overlaps
   our private/VPN ranges, so preserve this override. Before DATA validation,
   configure its Docker default-address-pools to 172.21.0.0/16 (size 24) and
   MTU 1450 in /etc/docker/daemon.json. This was done on the initial stg DATA host.
   This upstream installer is mutable; record the tested Coolify version. This
   starter does not claim fully pinned OS/package/Coolify reproducibility.
7. Use `terraform output -raw coolify_initial_tunnel`; open localhost:8000 and
   immediately create the first administrator. Ports 8000, 6001, 6002 and 51821
   are not public. If this Coolify release needs realtime UI ports during setup,
   forward 6001/6002 over SSH too. Configure private HTTPS administration before
   general use. Do not accidentally expose Coolify by assigning a public proxy
   hostname; private DNS alone is not access control. Restrict admin proxy routes
   by source address or bind them to the private interface.
8. Put the dedicated SSH private key in Coolify. Add DATA at 10.20.0.30 as root
   with that key and validate it. Coolify installs Docker there. Host rules permit
   root key authentication only from APP; password authentication is disabled.
   If Coolify's bridge traffic does not SNAT to APP's private IP, correct its
   networking instead of opening DATA to the entire subnet.
9. Deploy CoreDNS and wg-easy through Coolify according to services/ contracts.
   Keep their management interfaces private. Use Cloudflare DNS-01 for internal
   TLS certificates; keep a scoped ACME token in Coolify secrets.
10. Create PostgreSQL and Redis on DATA. Bind published ports to 10.20.0.30 only;
    allow 5432/6379. PostgreSQL permits the entire staging private network
    (10.20.0.0/16); Redis and SSH remain restricted to APP. If Coolify uses a port proxy, verify its bindings and reachability.
    Bind-mount database data into /data/instantly/postgres and /data/instantly/redis,
    using the engine/image-specific container data path and ownership. Confirm
    the container uses the configured bind path before writing real data. In prod
    this path is on the attached volume and Docker cannot start without its mount.
    In stg the same path is on the root disk; no volume mount unit is installed. Coolify metadata/Docker image layers
    remain on the root disk; the volume is not automatically used by named volumes.
11. Connect application repositories and add secrets in Coolify. Deploy apps on
    APP using the public API hostname. Enable TLS in Coolify before serving traffic.

# Backup policy to configure in Coolify
PostgreSQL dump every 6 hours (`0 */6 * * *`), local retention 2 days, private
S3-compatible object storage retention 30 days; monthly restore exercise.
Set S3 credentials only in Coolify. Bucket provisioning and schedules are not
implemented by this initial repo. The hcloud provider does not provision this
backup bucket. Confirm local backup paths and disk usage explicitly.
Redis cache can be disposable; critical queues/state require AOF plus RDB and a
separate off-host backup process. Server backups exclude attached volumes.
Back up Coolify's own configuration, SSH keys and encryption key separately.

# Acceptance checks after apply (not yet executed)
- APP cloud-init succeeds; DATA has no public IPv4/IPv6; DATA internet egress
  works through APP. Check downloads and container pulls, not just ping.
- From untrusted internet, only intended public HTTP(S)/WireGuard are reachable;
  SSH works only from admin CIDRs; DNS, DBs and admin ports are closed.
- DATA accepts PostgreSQL 5432 from the private-network CIDR and SSH/Redis
  from APP only, rejecting other sources, including
  Docker-published ports. Inspect `nft list table inet instantly_data`.
- Reboot each server and restart Docker: DATA route/firewall return, APP NAT
  still works. In prod also check the volume mount and missing-volume behavior:
  Docker must fail closed. Staging has no external volume dependency.
- VPN resolves internal names and reaches authorized services; client public
  egress IP is unchanged. Verify a real peer uses split-tunnel AllowedIPs.
- Insert database test data, redeploy its container and verify persistence;
  restore a backup into an isolated database and verify contents.

# State and lifecycle
The initial backend is local. Store state securely and move to an encrypted,
access-controlled remote backend with locking before collaborative production
changes. Never commit state or .terraform/. Commit .terraform.lock.hcl.
User-data is first-boot only. DATA ignores user_data changes in Terraform; apply
updated templates explicitly to running DATA hosts. APP edits can require a protected replacement;
review plans and migrate data before changing protection. No provisioners or
Terraform runtime service resources are used. Both servers and the production data volume
have API deletion protection and Terraform prevent_destroy. Removing resources
from configuration also removes lifecycle guards, so API protection matters.
Switching storage mode is not a data migration. Do not toggle an existing prod
volume off; deletion protection will block it. Staging root-disk data does not
survive server deletion/rebuild; recover it from off-host backups.
Volume shrink is unsupported. Test recovery before removing any protection.

# Boundaries and sources
- Hetzner private routing: https://docs.hetzner.com/networking/networks/technical-concepts/architecture/
- Firewalls do not cover private traffic: https://docs.hetzner.com/cloud/firewalls/faq/
- Provider: https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs
- Cloudflare provider: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
- Coolify installation: https://coolify.io/docs/start-with-self-hosted
- Coolify servers: https://coolify.io/docs/core/infrastructure/servers/add-server
