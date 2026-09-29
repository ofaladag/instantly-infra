# Staging backend

Source: git@github.com:ofaladag/instantly-be.git, branch main.
Coolify application: instantly-be-stg, UUID jthngbojcvlwhjhjmnslvy46.
Destination: APP-01, staging environment. Build pack: Dockerfile (Java 26).
Domain: https://api.stg.anonly.live, container port 8080; no host port mapping.
Health check: /actuator/health, startup grace 120s, 20 retries.
Container memory limit 1536M; JVM MaxRAMPercentage=65.0.

Uses existing DATA services rather than repository compose.yml (local development).
PostgreSQL: jdbc:postgresql://10.20.0.30:5432/instantly, dedicated owner/login
instantly, non-superuser. PostGIS installed by postgres in this new database.
Liquibase runs on startup with stg context, excluding local test-member seeds.
Redis: 10.20.0.30:6379, no password per staging network policy.
S3: private anonly-instantly-stg-app bucket, nbg1 endpoint and region.
Secrets are runtime-only in Coolify; no build-time credential injection.

The repository-specific read-only GitHub deploy key is registered with GitHub
and stored as an encrypted Coolify private key. Its local recovery copy is in
ignored work/credentials/. Generated database/JWT secrets also stay there.

## Pending before first deployment

GOOGLE_CLIENT_IDS is mandatory: the application refuses an empty audience list.
Obtain the real Google OAuth client IDs from the application owner. No placeholder
client ID is configured. APPLE_CLIENT_IDS is needed for Apple login.
OPENAI_API_KEY is needed for moderation; without it work remains queued/retried.
APNS_ENABLED and FCM_ENABLED are currently false pending actual push credentials.
Import any provided application secrets through Coolify; never commit them.

Automatic main push deployment has not been connected yet. The Coolify UI is
VPN-only, so a GitHub webhook requires an explicitly limited, authenticated public
webhook route or a runner with VPN access. Do not expose the admin panel to solve it.

Initial inspected commit: e21548b132a7da677844b87fc8bcbee662a8a0cc.

Docker build verification passed on APP-01 for the inspected commit, using the
repository Dockerfile unchanged. Its Maven command skips tests; this was a build
check, not an application startup, migration or integration test.
