# Staging backend

Source: git@github.com:ofaladag/instantly-be.git, branch main.
Coolify application: instantly-be-stg, UUID jthngbojcvlwhjhjmnslvy46.
Destination: APP-01, staging environment. Build pack: Dockerfile (Java 26).
Domain: https://api.stg.instantlyhere.com, container port 8080; no host port mapping.
Health check: /actuator/health, startup grace 120s, 20 retries.
Container memory limit 1536M; JVM MaxRAMPercentage=65.0.

Uses existing DATA services rather than repository compose.yml (local development).
PostgreSQL: jdbc:postgresql://10.20.0.30:5432/instantly, dedicated owner/login
instantly, non-superuser. PostGIS installed by postgres in this new database.
Liquibase runs on startup with stg context, excluding local test-member seeds.
Redis: 10.20.0.30:6379, no password per staging network policy.
S3: private anonly-instantly-stg-app bucket, nbg1 endpoint and region.
Secrets are runtime-only in Coolify; no build-time credential injection.

## Agents registration

The registration workflow uses `AGENTS_SERVICE_KEY` shared with agents-be and
`AGENT_REGISTRATION_ENABLED=true`. Missing/wrong service keys and ordinary member
JWTs cannot register accounts. Status and photo activation endpoints use the
same key. `AGENT_LOGIN_ENABLED=true` enables setup/photo member sessions. Keep
the independent test-only `PASSWORD_LOGIN_ENABLED` disabled. See
`services/agents-backend/README.md` for the agents service configuration.

The 2026-10-04 rollout deployed merge commit
`5f8bc0a41701f127cb8265b3236fb154395d0dda` through deployment
`3d509ff0-83a8-4f84-8b85-f51cc5949fc6`. The exact commit is running healthy,
both new Liquibase migrations are recorded, and registration/login are enabled.
Missing/wrong-key requests returned 403; the correct key returned the expected
404 for a nonexistent registration. Verification created no accounts.

A follow-up runtime rollout, `830330d3-fd54-4512-a7a8-507e3af80a21`, finished
healthy on the same commit. Inspection found that the previously configured
service key had its build-time flag enabled and was present in Docker build
history. That key was revoked, a fresh shared key was installed in both backends,
and the build-time flag was disabled. The old key now returns 403, while the new
key reaches the expected nonexistent-registration 404. The new key is absent
from the running image's metadata and history. Coolify reused the prior image,
whose history still contains the revoked value; do not reuse that old credential.
The OpenAI key was preserved.

The repository-specific read-only GitHub deploy key is registered with GitHub
and stored as an encrypted Coolify private key. Its local recovery copy is in
ignored work/credentials/. Generated database/JWT secrets also stay there.

## Runtime variables and deployment

Owner-provided Google/Apple, OpenAI and push configuration is stored in Coolify.
All application variables are runtime-only. Keep build-time flags off for these
credentials. APNS/FCM behavior follows the owner's configured enable flags.

Main pushes trigger Coolify via GitHub webhook 688801259. The only public
Coolify route is POST /webhooks/source/github/events/manual on api.stg.instantlyhere.com;
the handler checks the per-application HMAC secret before queuing deployments.
Admin pages remain on private entrypoints. GitHub ping/push delivery returned 200;
an unsigned push request was rejected. See services/proxy/backend-webhook.yaml.

The October agents rollout found that a merge webhook returned HTTP 200 with
an `Invalid signature` result and had not queued a deployment. The existing
recovery secret was synchronized back to GitHub hook `688801259`. A signed
skip-CD request then passed validation; a wrong signature remained rejected.
Check the webhook response body and resulting deployment, not HTTP status alone.

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
