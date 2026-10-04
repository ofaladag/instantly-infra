# Staging deployment status — 2026-09-29

- Terraform apply completed: 11 resources; subsequent plan reports no changes.
- APP: 188.245.26.177 / 10.20.0.20; DATA: private-only 10.20.0.30.
- Both CX23 hosts are in nbg1; DATA uses its root disk, no attached volume.
- Private application bucket: anonly-instantly-stg-app, nbg1 endpoint.
- Both hosts completed cloud-init with no errors. Route/firewall/NAT units active.
- DATA outbound HTTPS works through APP before and after Docker installation.
- API and VPN A records resolve to APP on Cloudflare DNS. VPN service is not yet deployed.
- Official Coolify installer run on APP; deployed version 4.3.23.
- APP Docker address pool: 172.20.0.0/16, /24 networks, avoiding private/VPN CIDRs.
- DATA daemon configuration prepared for 172.21.0.0/16, /24 networks and MTU 1450;
  Docker 29.8.1 is now installed and active; Coolify network is 172.21.1.0/24.
- DATA coolify-proxy and coolify-sentinel containers are healthy. Host firewall
  and route units remain active, and outbound HTTPS still works.
- DATA /data/instantly/postgres and /data/instantly/redis directories exist on
  the root disk; approximately 34 GB free at this check.
- Coolify HTTP endpoint returns 302 through a local SSH tunnel on 127.0.0.1:8000.

Owner created the administrator and added DATA via its private IP and dedicated
SSH key. The instantly project and stg environment are prepared. Next: deploy
CoreDNS/wg-easy, databases and application resources through Coolify. No application database or VPN is running yet.
The PostgreSQL/Redis containers on APP are Coolify's own internal dependencies.

To reopen the local tunnel if needed:

```sh
ssh -N -L 127.0.0.1:8000:127.0.0.1:8000 root@188.245.26.177
```

Initial administrator registration was completed by the owner. No credentials
were created for that account by the agent. The public firewall does not expose port 8000.

## Selected application database images

Owner selected `postgis/postgis:17-3.5-alpine` and `redis:7.2`.
Both are intended as standalone Coolify database resources on DATA-01, in
project `instantly`, environment `stg`. PostGIS is now deployed and healthy; Redis is also deployed and healthy.

Persistent directory mappings before first start:
- PostGIS: /data/instantly/postgres → /var/lib/postgresql/data
- Redis: /data/instantly/redis → /data

Use one mount per container data path; avoid duplicate named-volume and bind
mounts at the same destination. Keep generated credentials inside Coolify.
Cross-server APP connectivity needs explicit private host port mapping/proxy
configuration; container Internal URLs are limited to their Docker network.
Do not enable public Internet access. Verify PostGIS extension availability in
the application's database after startup. Redis persistence/eviction policy
must be selected according to cache versus durable queue/state use.

## PostGIS private access verified

Coolify resource gjskeqvy7nhwmayukgni0oaz on DATA-01 uses
postgis/postgis:17-3.5-alpine, with PostGIS 3.5.7 enabled in the postgres database.
It retains the Coolify named volume postgres-data-gjskeqvy7nhwmayukgni0oaz at
/var/lib/postgresql/data (root-disk storage, no extra Hetzner volume).
The earlier directory-bind mapping was a proposal; the deployed named volume is
retained and should not be replaced with an empty bind directory.

Saved ports_mappings=10.20.0.30:5432:5432 through the Coolify model and redeployed
using Coolify's StartDatabase action. Runtime binding verified on private IP only;
Make it publicly available remains false. APP's container network successfully
ran pg_isready against 10.20.0.30:5432. PostgreSQL reports healthy.

## Private-network PostgreSQL access policy

PostgreSQL TCP 5432 now accepts clients arriving on DATA's private interface
from the entire staging Hetzner network 10.20.0.0/16. Docker DNAT ingress and
host input use matching source-CIDR rules. The database still binds exclusively
to 10.20.0.30:5432. SSH remains APP-only; Redis now uses the same private-network policy. Database authentication is
still required. APP-to-DATA readiness passed after applying the firewall.

The persistent host firewall script and repository template were updated. DATA
cloud-init user_data now has ignore_changes: subsequent first-boot template
edits require explicit application to running hosts, avoiding server replacement.
VPN peers masqueraded as APP share APP access. This rule is network-source control, not an identity boundary.

## Redis queue configuration

Coolify resource pbeoyfkzdf8mzexek4nsleeb runs redis:7.2 on DATA-01.
At the owner's request it is passwordless, with custom requirepass "" and
protected-mode no, behind host private-interface/source-CIDR filtering.
Docker binds only 10.20.0.30:6379; both host input and Docker forwarding admit
5432/6379 from 10.20.0.0/16. The public-proxy option remains disabled.
Connection: redis://10.20.0.30:6379/0 (no username or password).

Configuration is stored in Coolify and mirrored in services/redis/redis.conf:
AOF enabled, appendfsync everysec, RDB snapshots, maxmemory 512mb and noeviction.
At the memory limit, new writes may fail rather than silently evict queue keys.
The existing /data named volume is retained. Runtime configuration, healthy
container state, AOF write status and passwordless PONG from APP were verified.
AOF everysec can lose roughly the last second of writes on a crash; it does not
replace off-host backups. No destructive persistence test was performed.

## VPN and internal DNS

Coolify service instantly-stg-coredns (qtg3t3tarw5uf8pbzwnvv60l) runs
CoreDNS 1.14.7 on APP, bound to 10.20.0.20:53 UDP/TCP.
Coolify service instantly-stg-wireguard (wfmejlbqaould1md0fuczef3) runs
wg-easy 15.4.0, public UDP 51820 and private/loopback admin TCP 51821.
Both images are digest-pinned in services/. WireGuard kernel module loading
is persisted on APP. These are runtime services, not new Terraform resources.

WireGuard interface 10.8.0.1/24 is up. A faruk-macbook peer was created through
the authenticated wg-easy API and exported to ignored local credentials.
Profile endpoint, split routes and DNS were checked without displaying keys.
The initial administrator password was removed from Coolify environment/Compose
after provisioning. Peer state and credentials survive in the named volume.

Verified: DNS internal records over UDP/TCP, forwarding for public names, DATA
DNS access, wg-easy-to-DATA TCP5432/6379 access, UI login and profile export.
Device import and VPN handshake were verified. Mac system DNS, private panel
access, PostgreSQL TCP access and passwordless Redis PONG passed; public internet
routes remain on the normal network interface.
No off-host backup for WireGuard's persistent volume is configured yet.

## Private HTTPS

Coolify and wg-easy now serve valid Let's Encrypt HTTPS on their existing
internal hostnames without port suffixes. Mac TLS trust/hostname verification
and both login pages passed (HTTP 200). Private HTTP redirects to HTTPS.
Public-IP requests using either internal Host/SNI returned 503, not a panel.

The Coolify-managed APP proxy binds public 80/443 to 188.245.26.177 and private
80/443 to 10.20.0.20 with separate internal entrypoints. Realtime and terminal
WebSocket routes are included; interactive authenticated terminal use was not
verified in this check. Existing direct private HTTP ports remain for recovery.

Cloudflare DNS-01 token is stored only on APP in a mode-0600 secret file, not
in the committed proxy configuration. ACME account/certificates persist in
acme-internal.json and Traefik manages renewal. Initial validation hit cached
NXDOMAIN from Quad9; using 1.1.1.1 for ACME resolved issuance. Configuration is
mirrored under services/proxy and saved in Coolify's proxy configuration store.
Public API HTTPS will be configured when its application resource is deployed.

## Backend staging deployment

Coolify application instantly-be-stg (jthngbojcvlwhjhjmnslvy46) deploys the private
ofaladag/instantly-be repository's main branch through its Dockerfile on APP-01.
Public HTTPS: https://api.stg.instantlyhere.com. Read-only deploy key installed.
Dedicated database instantly and non-superuser owner instantly are on DATA;
PostGIS is enabled. Existing postgres DB was preserved. Database, Redis, S3, JWT
and owner-provided integration credentials are configured runtime-only.

Liquibase applied 28 changesets and released its migration lock. Backend commit
1057917 adds curl to the runtime image for Coolify's container health check.
HTTPS /actuator/health returns UP (200) and /api/v1/welcome returns 200.
S3 HeadBucket using the application's configured credentials returned 200.
Real OAuth logins, moderation requests and device push delivery were not tested.

GitHub webhook 688801259 connects main pushes to staging deployments. Both ping
and the Dockerfile-fix push were delivered successfully; the push queued commit
1057917 in Coolify. Only the exact POST webhook path is public; Coolify validates
the signing secret. An unsigned push request was rejected. Admin routes remain
on the private HTTPS entrypoint. Webhook routing is mirrored in services/proxy.

## Unrestricted outbound traffic

Owner policy: do not restrict server/application egress. Live Hetzner APP and
DATA firewalls have no outbound rules (allow all); host OUTPUT policies accept.
DATA uses APP NAT without destination/port restrictions. Docker's bridge ingress
protection and DATA inbound database/SSH rules remain in place. No firewall
mutation was needed. APP TCP connections to OpenAI 443, APNs 443/2197 and FCM 443
passed; DATA HTTPS to object storage returned 200. Backend-container OpenAI
HTTPS returned 401 without credentials, confirming connectivity. Provider-level
restrictions (such as Hetzner's default SMTP 25/465 blocks) are separate from
these firewall settings and were not changed.

APNs IPv6 routing fix: APP has no public IPv6 default route, although Docker
assigns private IPv6 addresses. An APNs connection selected an AAAA record and
failed with Network is unreachable. Backend JAVA_TOOL_OPTIONS now includes
-Djava.net.preferIPv4Stack=true (runtime-only); existing memory options retained.
IPv4 APNs HTTPS returned 405, confirming transport reachability; IPv6 failed.
This is an application address-family setting, not an outbound firewall block.
Revisit it if routed public IPv6 is introduced. Actual push delivery needs a
valid device notification retry; a transport check does not verify delivery.

## Staging domain migration

Primary staging domain is now instantlyhere.com. See [migration details](DOMAIN-MIGRATION.md)
for current URLs and client profile updates.
Earlier entries above describe the historical deployment.

## Agents frontend — 2026-10-04

Coolify application `instantly-agents-fe-stg` (`r2b4zvgoxvrsdm9stva8ylfh`) serves
https://agents.internal.stg.instantlyhere.com exclusively through the staging VPN.
CoreDNS points it to APP's private `10.20.0.20`; custom Docker labels use only
`internal-https`. No host ports or public DNS records were added for the UI.

The private `ofaladag/instantly-agents-fe` main branch builds with the repository
Dockerfile, using a dedicated read-only deploy key. Nginx serves port 80 with a
128 MB memory limit and a Docker `/healthz` check. Initial commit: `6d92d58`.
GitHub webhook `692124166` uses the existing signed, POST-only public webhook
endpoint; its test push completed an automatic deployment successfully.

Local lint/build, Docker build, container health, trusted HTTPS, JS/CSS assets,
SPA fallback, and private HTTP-to-HTTPS redirect passed. Public-IP requests using
the Agents hostname do not serve the app (HTTPS 503, HTTP 404). Backend health
and private Coolify access remain healthy. Internal ACME DNS validation now
waits 120 seconds before propagation checks after an initial secondary-validator
NXDOMAIN failure. The final Let's Encrypt certificate is valid through 2027-01-02.

See `services/agents-frontend` for the saved labels and operating details.

## Agents backend and persona workspace — 2026-10-04

The persona workspace frontend runs commit
`14ddd9b2d4074886afa382f28c5e024b3b0adb4a`. The new Coolify application
`instantly-agents-be-stg` (`2x1n7e7cswioh1tbgggi6pjc`) serves its same-origin
`/api/v1/*` requests on the existing VPN-only Agents hostname. Its Docker router
uses `internal-https`, priority 200 and container port 8080 with no host binding.
Memory is limited to 768 MB; main pushes use signed GitHub webhook `692146140`.

DATA contains a dedicated `instantly_agents` database and restricted owner/login.
Liquibase created the six application tables and released its lock. Terraform
created the private `anonly-instantly-stg-agents` draft-photo bucket, with no
changes or deletions to existing infrastructure. The subsequent live plan
reported no changes. S3 write/read/delete and anonymous-denial checks passed,
including the backend's actual Java storage implementation.

Instantly-be runs merged PR #75 at commit
`5f8bc0a41701f127cb8265b3236fb154395d0dda`, with agent registration/login enabled
and the separate test password-login flag disabled. Its webhook signature
mismatch was repaired. Both backends use a newly rotated runtime-only
`AGENTS_SERVICE_KEY`; the revoked old key is rejected. The old value remains in
the reused backend image's build history, but the new key is absent from it.

The owner approved reusing instantly-be's OpenAI key as agents-be's runtime-only
`OPENAI_API_KEY`. Model metadata requests for `gpt-5-mini` and `gpt-image-1.5`
returned 200. Deployment verification did not generate personas or images,
approve drafts, or create accounts. A separate operator-started workflow was
observed complete: one persona `READY`, one registration attempt `ACTIVE`, and
all eight tasks `DONE`, including photo activation. The final backend webhook
deployment `krzzxl2mdhlaoikjdfmzrpul` runs commit
`2aed645f7c0ebea06e5e41b3a4ffc1b59b6c9e24` healthy. VPN API responses, UTF-8
Origin rejection, service-key authorization and public isolation passed. See
`services/agents-backend` for runtime variables and operating details.

## Agents feedback and generation progress — 2026-10-05

Backend main `9d47d0f0f8e3c6b768745d66abca7bdae9e2e238` and frontend main
`5f433b7345ce9c5a1e29b821a3f104d94190ed26` are deployed and healthy. Deployment
IDs are `elw7nl6rf4fex5b20cvfpbhl` and `qlbgcn5nxswmavqjmvrckmmc`, respectively.
Feedback starts a new reviewed iteration; profiles are instructed to use Turkish
first-person prose and nicknames. UI progress distinguishes queued/running work
and its current generation stage. Backend 75 tests and frontend 27 tests passed;
frontend lint/build and final private-ingress/service-key probes passed.

Work stopped at the owner's request before final live evaluation completed.
The final three-profile evaluation job is `0d31ac95-b498-48c9-8244-b333b87b6c26`;
feedback evaluation persona is `edef30d9-4dc4-44f5-b0a2-cd757844f320`.
Already queued application work was left running. No approval or registration was
submitted by deployment verification; an externally approved earlier evaluation
profile was observed registered and must be preserved.

Follow-up: new direction fields are persisted and reach planning, but live output
still repeats workshop/community life stories. One semantic rejection correctly
matched an older failed plan. Character references include failed plans; text
retries preserve the accepted plan, so they cannot repair similarity inherent in
that plan. Voice direction has no dedicated field in the character-plan schema.
Review these quality limitations and the final evaluation outcomes before claiming
the diversity problem fully resolved. Private evaluation records/photos remain
ignored under `work/` and are not committed.
