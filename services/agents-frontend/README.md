# Staging Agents frontend

- URL: https://agents.internal.stg.instantlyhere.com (staging VPN required).
- Source: `git@github.com:ofaladag/instantly-agents-fe.git`, branch `main`.
- Coolify application: `instantly-agents-fe-stg`, UUID `r2b4zvgoxvrsdm9stva8ylfh`.
- Project/environment: `instantly` / `stg`; destination: APP-01, `coolify` network.
- Build pack: Dockerfile, base directory `/`, Dockerfile `/Dockerfile`.
- Nginx container port: `80`; no host port mapping; memory limit: `128M`.
- Dockerfile health check: `GET /healthz`; no application secrets or environment
  variables are needed by this initial UI.

CoreDNS maps the hostname to `10.20.0.20` in `services/coredns/internal.hosts`.
The live hosts file is `/data/instantly/coredns/internal.hosts` on APP and reloads
automatically. There is no public A/AAAA record for the Agents hostname.

`traefik-labels.txt` is the complete custom label configuration saved in Coolify.
It exposes this application only through the `internal-https` entrypoint and
uses the existing `internal` DNS-01 certificate resolver. Private HTTP redirects
to HTTPS through the existing proxy entrypoint. Do not replace these labels with
Coolify's generated public-entrypoint labels. Preview deployments are disabled.

The internal resolver waits 120 seconds before checking DNS challenge propagation;
the first Agents certificate request failed with NXDOMAIN during secondary ACME
validation when no propagation delay was configured. Proxy Compose and Coolify's
saved proxy configuration include this delay. Existing certificates and keys are
retained in the proxy's ACME store.

A dedicated read-only GitHub deploy key is stored encrypted in Coolify. Its
recovery copy is under ignored `work/credentials/instantly-stg-agents-deploy`.
Do not commit private keys or the webhook signing secret.

GitHub webhook `692124166` subscribes to push events; Coolify deploys `main`.
It uses the existing public POST-only webhook route at
`https://api.stg.instantlyhere.com/webhooks/source/github/events/manual` with
an application-specific HMAC secret and TLS verification enabled. This does not
expose the Agents UI or Coolify administrative API on the public entrypoint.

To redeploy manually, open the application in Coolify and select Deploy.
To roll back, use a prior successful deployment while retaining the private labels.

Initial source commit: `6d92d58ded34c24cb51766d24d482549e767e3bc`.
Local lint/build and the Coolify Docker build passed. GitHub ping and test-push
deliveries returned 200; the push queued a deployment marked `is_webhook=true`.

Verified on 2026-10-04: both deployments finished and the application reports
`running:healthy`. VPN DNS resolves to `10.20.0.20`; trusted HTTPS returns 200 for
the page, JS/CSS assets, `/healthz`, and an SPA deep link. HTTP redirects to HTTPS
with 308. The certificate is issued by Let's Encrypt YR2 and expires 2027-01-02.
Requests to the public IP with the Agents Host/SNI return 503 over HTTPS and 404
over HTTP. Existing backend health remains UP and the private Coolify login
returns 200 after the proxy configuration update.
