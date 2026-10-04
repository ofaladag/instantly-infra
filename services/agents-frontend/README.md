# Staging Agents frontend

- URL: https://agents.internal.stg.instantlyhere.com (staging VPN required).
- Source: `git@github.com:ofaladag/instantly-agents-fe.git`, branch `main`.
- Coolify application: `instantly-agents-fe-stg`, UUID `r2b4zvgoxvrsdm9stva8ylfh`.
- Project/environment: `instantly` / `stg`; destination: APP-01, `coolify` network.
- Build pack: Dockerfile, base directory `/`, Dockerfile `/Dockerfile`.
- Nginx container port: `80`; no host port mapping; memory limit: `128M`.
- Dockerfile health check: `GET /healthz`; the frontend has no application
  secrets. The management UI uses same-origin `/api/v1/*` requests.

CoreDNS maps the hostname to `10.20.0.20` in `services/coredns/internal.hosts`.
The live hosts file is `/data/instantly/coredns/internal.hosts` on APP and reloads
automatically. There is no public A/AAAA record for the Agents hostname.

`traefik-labels.txt` is the complete custom label configuration saved in Coolify.
It exposes this application only through the `internal-https` entrypoint and
uses the existing `internal` DNS-01 certificate resolver. Private HTTP redirects
to HTTPS through the existing proxy entrypoint. Do not replace these labels with
Coolify's generated public-entrypoint labels. Preview deployments are disabled.

The agents-be application's private Docker labels provide the higher-priority
`/api` router on this same hostname; Nginx continues to serve the UI. See
`services/agents-backend/README.md` for resource/env setup and verification.

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

Historical verification of the initial static UI on 2026-10-04 (before the
persona management feature): both deployments finished and the application reports
`running:healthy`. VPN DNS resolves to `10.20.0.20`; trusted HTTPS returns 200 for
the page, JS/CSS assets, `/healthz`, and an SPA deep link. HTTP redirects to HTTPS
with 308. The certificate is issued by Let's Encrypt YR2 and expires 2027-01-02.
Requests to the public IP with the Agents Host/SNI return 503 over HTTPS and 404
over HTTP. Existing backend health remains UP and the private Coolify login
returns 200 after the proxy configuration update.

## Persona workspace release

On 2026-10-04, `main` commit `14ddd9b2d4074886afa382f28c5e024b3b0adb4a`
triggered webhook deployment `9oz0qdqpnv4wu4xbqezl7e7l`, which finished
successfully. The healthy running container uses that exact commit. VPN requests
to the page, JS/CSS assets, `/healthz` and an SPA route returned 200; asset hashes
matched the verified frontend build. The route remains on `internal-https`
without host port mappings; public HTTPS/HTTP probes returned 503/404.

At the time of the frontend-only release, agents-be was not deployed, so `/api`
returned the HTML fallback and the workspace displayed an API connection error.
The subsequent agents backend deployment is recorded in its service README.

The diversity-review update on 2026-10-04 runs main commit
`0619e37e0d065f3906cf568bb1c1e4bbb2957e3c`, webhook deployment
`pigoshzejc3fqic91t7kcfpg` (finished, healthy). It displays rejected portrait
candidates for private review while keeping approval disabled until an image
passes the backend diversity check. All 17 frontend tests, lint and the production
build passed; the deployed page returned HTTP 200.

Feedback iteration UI release `7ec0a18778a870d10d21f71b4421c9f621dbf08b`
deployed healthy via `oznynn5vqv9v8bdnypuslyfy`. The detail panel sends 1–2000
characters of feedback with the expected persona version. Unsaved edits, stale
versions, registered accounts and in-flight work disable submission. Feedback
survives version conflicts; regeneration results return to the normal polling
and approval flow. Its 22 tests, lint, production build and local mocked UI
smoke passed without calling live providers.

Generation-progress release `5f433b7345ce9c5a1e29b821a3f104d94190ed26`
deployed healthy via `qlbgcn5nxswmavqjmvrckmmc` at 21:08:40 UTC (2026-10-05
locally). Cards and details distinguish queued from running work for planning,
text, image generation and image review. Polling accepts progress updates at the
same persona version while preserving content and ignoring older responses.
All 27 tests, including rendered component checks, lint and production build passed.
