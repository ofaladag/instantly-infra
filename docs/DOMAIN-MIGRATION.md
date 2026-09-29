# Staging domain — instantlyhere.com

Production is unchanged.

- API: https://api.stg.instantlyhere.com
- VPN endpoint: vpn.stg.instantlyhere.com:51820 (DNS-only)
- Coolify: https://coolify.internal.stg.instantlyhere.com (VPN)
- WireGuard admin: https://wg.internal.stg.instantlyhere.com (VPN)
- PostgreSQL/Redis: postgres.internal.stg.instantlyhere.com and
  redis.internal.stg.instantlyhere.com; private addresses/ports unchanged.

Terraform manages only the current domain's API/VPN records. The former domain's
records were detached from Terraform state without deleting them from Cloudflare;
the owner will delete those records manually. There are no compatibility routes
or private DNS aliases for the former domain.

The DNS-01 token on APP requires Zone Read and DNS Edit access to the current zone.
Coolify's persisted fqdn and custom labels use only the current API hostname.
GitHub webhook 688801259 uses the current API URL with its existing signing secret.

wg-easy's persisted default endpoint and exported faruk-macbook profile use the
current VPN hostname, with unchanged peer keys and split routes. The export is
work/credentials/instantly-stg.conf (0600, gitignored). Update the Endpoint in any
installed VPN profiles to vpn.stg.instantlyhere.com:51820 before deleting the
former domain's DNS records. Installed profiles are not automatically updated.

API consumers must use the current API URL. Real OAuth, push and mobile client
flows are outside the infrastructure checks; provider-specific allowlists may
need updates if they reference the former hostname.

The existing S3 bucket name is independent of DNS and remains unchanged. No
objects, credentials or storage endpoints were migrated.

## Verified after cleanup

The backend restart-only deployment finished successfully. API health reports
UP/200, welcome returns 200, and both VPN-only panel login pages return 200 with
trusted TLS. Former API/panel Host requests do not route to those services.
Public-IP requests for the private panel remain blocked. Obsolete certificates
were removed from Traefik's active ACME stores after removing the old routers.
Terraform reports no changes; formatting, validation and all 7 mocked tests pass.
