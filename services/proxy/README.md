# Staging HTTPS proxy

This is APP-01's Coolify-managed Traefik configuration. Save docker-compose.yml
through Coolify's Proxy Configuration (server localhost / id 0); its persisted
copy and disk file must agree. Copy internal-https.yaml to
/data/coolify/proxy/dynamic/instantly-internal-https.yaml, then restart the proxy
through Coolify. Do not regenerate the default proxy configuration, which would
remove the private entrypoints and custom port bindings.

Bindings:
- 188.245.26.177:80/443: public application entrypoints (HTTP challenge retained).
- 10.20.0.20:80: redirects to HTTPS port 443.
- 10.20.0.20:443: separate internal-https entrypoint, container port 8443.

Only the private entrypoint contains Coolify, realtime/terminal WebSocket and
wg-easy routes. Supplying an internal hostname to the public IP must not serve
an admin panel. CoreDNS keeps internal names pointed at 10.20.0.20.

Internal certificates use Let's Encrypt DNS-01 via Cloudflare. Traefik reads
CF_DNS_API_TOKEN_FILE=/traefik/secrets/cloudflare-token. Provision the token on
APP at /data/coolify/proxy/secrets/cloudflare-token with mode 0600; never commit
it. The existing anonly.live-scoped token was used. Rotating it requires updating
this file and restarting the proxy. Public DNS resolvers are specified so the
private DNS zone cannot intercept ACME discovery/validation.

Traefik persists certificates/account keys in acme-internal.json, mode 0600,
and handles renewal automatically while the proxy, token and DNS API work.
Treat this file and proxy backups as secrets. No public A record is needed for
the internal panel names; DNS-01 creates temporary public TXT records. Issued
certificate names are visible in public certificate transparency logs.

Private URLs (no port suffix):
- https://coolify.internal.stg.anonly.live
- https://wg.internal.stg.anonly.live

Coolify routes to coolify:8080 and coolify-realtime:6001/6002 on the shared
Docker network. wg-easy routes to its private HTTP port 10.20.0.20:51821.
Existing direct private/SSH HTTP ports remain available for recovery.
Do not populate public-entrypoint Coolify instance-domain/service-domain routers
for these admin names without also preserving the private routing boundary.

The public API application is configured with https://api.stg.anonly.live in
Coolify. Copy backend-webhook.yaml into the proxy dynamic directory as well. It
adds only the exact POST GitHub webhook path on the public HTTPS entrypoint; the
Coolify handler validates a per-application HMAC secret. Never broaden this route
to expose the Coolify UI or general API.
