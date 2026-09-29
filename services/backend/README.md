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

## Runtime variables and deployment

Owner-provided Google/Apple, OpenAI and push configuration is stored in Coolify.
All application variables are runtime-only. Keep build-time flags off for these
credentials. APNS/FCM behavior follows the owner's configured enable flags.

Main pushes trigger Coolify via GitHub webhook 688801259. The only public
Coolify route is POST /webhooks/source/github/events/manual on api.stg.anonly.live;
the handler checks the per-application HMAC secret before queuing deployments.
Admin pages remain on private entrypoints. GitHub ping/push delivery returned 200;
an unsigned push request was rejected. See services/proxy/backend-webhook.yaml.

The initial deployment ran all 28 Liquibase migrations and started Spring Boot,
but the runtime image lacked curl/wget for Coolify's health check. Backend commit
1057917 adds curl to the runtime stage. Its main push automatically queued the
corrected deployment. No health check was disabled to bypass this issue.

Initial inspected commit: e21548b132a7da677844b87fc8bcbee662a8a0cc.

Docker build verification passed on APP-01 for the inspected commit, using the
repository Dockerfile unchanged. Its Maven command skips tests; this was a build
check, not an application startup, migration or integration test.

Runtime verification: HTTPS /actuator/health returned UP (200), welcome returned
200, all 28 migrations applied with no held lock, and S3 HeadBucket returned 200.
OAuth login, real moderation and push delivery still need application-level tests.

APNs IPv6 routing fix: APP has no public IPv6 default route, although Docker
assigns private IPv6 addresses. An APNs connection selected an AAAA record and
failed with Network is unreachable. Backend JAVA_TOOL_OPTIONS now includes
-Djava.net.preferIPv4Stack=true (runtime-only); existing memory options retained.
IPv4 APNs HTTPS returned 405, confirming transport reachability; IPv6 failed.
This is an application address-family setting, not an outbound firewall block.
Revisit it if routed public IPv6 is introduced. Actual push delivery needs a
valid device notification retry; a transport check does not verify delivery.
