# Staging Agents backend

- Source: `git@github.com:ofaladag/instantly-agents-be.git`, branch `main`.
- Coolify application: `instantly-agents-be-stg`, UUID `2x1n7e7cswioh1tbgggi6pjc`.
- Project/environment: `instantly` / `stg`; destination: APP-01, `coolify` network.
- Build pack: Dockerfile, base directory `/`, Dockerfile `/Dockerfile`.
- Container port: `8080`; no host port mappings; memory limit: `768M`.
- Health check: `/actuator/health`, startup grace 60 seconds, 20 retries.
- Java runtime: `MaxRAMPercentage=65.0`, IPv4 transport as on the existing backend.

## Private API and service authentication

The frontend calls relative `/api/v1/*` URLs on
`https://agents.internal.stg.instantlyhere.com`. `traefik-labels.txt` contains
the complete custom labels saved in Coolify: hostname plus `/api` path matching,
priority 200, `internal-https` only, port 8080. The frontend catch-all continues
to serve the UI. Docker service discovery follows deployments automatically;
there is no separate static API router. Existing WireGuard, DNS and proxy port
bindings remain unchanged. The stable private network alias is
`instantly-agents-be-stg`.

Instantly's registration, status and photo-activation routes validate
`X-Agents-Key` against `AGENTS_SERVICE_KEY`. Both backends use the same
runtime-only value. Ordinary member JWTs do not authorize those routes. There is no
second ingress credential. Agents accepts only the configured browser Origin;
tools without Origin may call it over the trusted VPN/private infrastructure.

`INSTANTLY_BASE_URL=https://api.stg.instantlyhere.com` protects service credentials
with HTTPS. `AGENT_REGISTRATION_ENABLED=true` and `AGENT_LOGIN_ENABLED=true`
enable the workflow in instantly-be. Its independent test-only
`PASSWORD_LOGIN_ENABLED` remains false.

## Runtime resources

DATA hosts a separate `instantly_agents` database owned by its dedicated login
of the same name. The role has no superuser, create-database, create-role or
replication privileges. PUBLIC access was revoked on this new database only;
the existing Instantly database was preserved. Liquibase owns schema creation.
The generated database password is stored in Coolify; its local recovery file
is ignored `work/credentials/agents-backend.json`, mode 0600. The shared service
credential's recovery file is `work/credentials/agents-service-key.json`, also
mode 0600 and ignored.

Terraform manages `anonly-instantly-stg-agents`, a private draft-image bucket at
`https://nbg1.your-objectstorage.com`, region `nbg1`. It is separate from
published member media and has `prevent_destroy` / `force_destroy=false` guards.
Draft previews stream through the private agents API. Staging reuses the
existing project's S3 credential already configured in instantly-be; this key
is project-scoped, not restricted to the agents bucket.

The dedicated GitHub deploy key is read-only and limited to the agents-backend
repository. Its encrypted copy is in Coolify; the ignored local recovery file
is `work/credentials/instantly-stg-agents-backend-deploy`.

## NVIDIA runtime environment

All variables are runtime-only in Coolify. No credentials are build arguments
or frontend variables, and no `.env` or private key is tracked in Git.
The deployed application uses NVIDIA for text, vision review and portrait
generation. The same server-only key authenticates both provider endpoints.

| Variable | Configuration |
|---|---|
| `SERVER_ADDRESS`, `SERVER_PORT` | `0.0.0.0`, `8080` |
| `DATABASE_URL` | `jdbc:postgresql://10.20.0.30:5432/instantly_agents` |
| `DATABASE_USERNAME`, `DATABASE_PASSWORD` | Dedicated agents database login |
| `AGENTS_ALLOWED_ORIGINS` | `https://agents.internal.stg.instantlyhere.com` |
| `INSTANTLY_BASE_URL` | `https://api.stg.instantlyhere.com` |
| `AGENTS_SERVICE_KEY` | Same runtime value as instantly-be |
| `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET` | Private agents draft bucket above |
| `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_PATH_STYLE` | Staging S3 credential, path style `true` |
| `NVIDIA_API_KEY` | Owner-provided NVIDIA credential; runtime-only, with Coolify's build-time option disabled |
| `NVIDIA_BASE_URL` | `https://integrate.api.nvidia.com/v1` |
| `NVIDIA_PERSONA_MODEL` | `meta/muse-glimmer-30b`; default for jobs that omit model settings |
| `NVIDIA_MAX_TOKENS` | `8192` |
| `NVIDIA_IMAGE_ENDPOINT` | `https://ai.api.nvidia.com/v1/genai/black-forest-labs/flux.2-klein-4b` |
| `NVIDIA_IMAGE_MAX_BYTES` | `10485760` (10 MiB) |
| `WORKER_CONCURRENCY`, `WORKER_MAX_FAILURES` | `2`, `5` |

Missing NVIDIA configuration does not prevent application startup. Generation
reports a configuration error until the key is set; no build or test requires
a live provider credential. There is no OpenAI fallback. Persona text and the
selected photograph still require human approval before account registration.

Keep `NVIDIA_API_KEY` runtime-only before building an image. The agents
application's old `OPENAI_*` settings are retained for rollback and are unused by
the NVIDIA release. The separate Instantly backend keeps its own provider
configuration. Historical OpenAI deployment checks below describe the earlier
releases; the current code has no automatic fallback to OpenAI.

## Automatic deployments

GitHub webhook `692146140` subscribes to main pushes through the existing
public POST-only Coolify webhook URL. Its app-specific signing secret is
stored encrypted in Coolify with a mode-0600 recovery file at ignored
`work/credentials/agents-backend-webhook.json`. TLS verification is enabled;
preview deployments are disabled. A signed skip-CD delivery passed signature
validation without deploying; an unsigned request was rejected.

## Deployment and verification

Deploy through Coolify using the repository's Dockerfile and the private labels
above. Never regenerate default public labels for this service. Preserve the
database and bucket when rolling back application code.

Verification covers application/container health, migrations, same-origin list
APIs through the VPN, rejection of foreign browser origins, public Host/SNI
isolation, authenticated S3 read/write and unauthenticated image denial, and
registration denial without the shared key. A correct key is checked using a
nonexistent registration ID so deployment checks do not create user accounts.
The first real persona generation and approval is a separate operator action.

The initial deployment on 2026-10-04,
`b63536ba-9d1b-465b-8765-e5344548c70b`, ran commit
`a5c6ac16b7a9d8716e662a64c13c317e828bfcee` healthy. Liquibase applied
`agents:001` and released its lock; all six application tables belong to the
dedicated agents role. Terraform applied exactly one bucket creation with no
updates/deletions; the subsequent staging plan reported no changes.

Authenticated object-storage write/read/delete checks passed, including the
production Java 26 `S3ImageStorage` implementation and AWS SDK configuration.
Anonymous object access returned 403; the temporary probe object was deleted.
OpenAI model-access checks returned 200 for `gpt-5-mini` and `gpt-image-1.5`
using the approved reused key. These were model metadata requests, not persona
or image generation; inference, moderation and registration are not claimed as
verified by this deployment check.

The final automatic main-push deployment, `krzzxl2mdhlaoikjdfmzrpul`, finished
healthy on `2aed645f7c0ebea06e5e41b3a4ffc1b59b6c9e24`. This also corrects
the Origin rejection response to explicitly use UTF-8, verified with a real
embedded-Tomcat regression test and strict decoding of the deployed HTTP body.
The jobs/personas list APIs returned JSON with HTTP 200 through the VPN; foreign
Origin returned 403, and invalid generation input returned 400 before creating
a job. Public-IP Host/SNI probes returned HTTPS 503 and HTTP 404.

The final credential audit confirmed that both running backends use the same
rotated service key and that agents-be uses the approved existing OpenAI key.
All agents credentials are runtime-only and absent from its image metadata and
build history. Instantly's missing/wrong service-key checks returned 403; the
current key reached the expected 404 for a nonexistent registration. See the
backend README for the revoked prior service key's image-history note.

An operator-started generation/approval also completed during the rollout.
Read-only checks at 20:11 UTC observed one completed generation job, its persona
`READY`, one registration attempt `ACTIVE`, and all eight workflow tasks `DONE`,
including photo activation. An earlier transient 403 had cleared after operator
retries; its exact source could not be established from the overwritten task
state. Deployment checks did not generate, approve, retry or register this persona.

## Character diversity release — 2026-10-04

Backend main `0bc6687212f7e2fa891a097cea42d4d60c1c72cd` deployed through
signed webhook deployment `zjzct64yen8u9zn49frjhbgk`. The previous worker was
stopped after verifying there were no queued/running tasks, before starting the
new binary: the old version cannot safely process the new planning/review steps.
The deployment finished healthy; Liquibase `agents:002` created
`persona_generation` and the image diversity marker, with its lock released.

New generation persists a distinct seed and immutable character plan, then runs
text generation/semantic review and image generation/visual review. Only images
that pass review become approvable drafts. The system uses the same configured
OpenAI models and key; no new environment secret is needed. Each stage allows
three diversity rejections, separately from provider transport retry limits.
Planning, text and image reviews add provider calls; see the backend repository
README for bounded reference windows and costs. Generic Retry cannot bypass
exhausted diversity checks; explicit photo regeneration starts a new image budget.

Follow-up commit `2c643ee5c61641725922a4a5fcdc1899847e585e`, deployment
`l04prr6teklsrbbthh3xe7lv`, finished healthy. It uses the existing text model's
`low` reasoning setting by default and prioritizes ready text/image work before
planning the remaining batch. No runtime secret or model change was needed.

Validation: 75 backend tests passed (including PostgreSQL integration, migration,
expired-lease fencing, persistent plans, semantic/visual rejection limits and
mock provider contracts), with no skipped tests. VPN list APIs returned 200,
foreign Origin 403, invalid generation input 400, missing/wrong service key 403,
and public Host/SNI probes 503/404. The current key reached the expected 404 for
a nonexistent registration.

The feedback iteration release is backend main
`4664b734fedd13ac4678323d7f41da5d8f08481a` (including the 100-profile face/hair
pairing fix). It adds migration `agents:003`, durable human feedback with source
revision history, and `POST /api/v1/personas/{id}/regenerate` accepting
`{expectedVersion,feedback}`. Generated prose uses the character's own first-person
Turkish voice; username generation and review require a nickname. New iterations
retain name/date of birth/gender, run all reviews and require fresh approval.
Existing accounts and unresolved registration attempts cannot be regenerated.
Deployment `hhaymwlsypyq4cvtxevpjeba` finished healthy; migration `agents:003`
executed and released its lock. VPN/service-key/public isolation probes passed.

Before this rollout, the operator held PostgreSQL advisory lock `707320026` to
stop new claims while current provider calls drained, without modifying task
rows. The operator released it successfully after deployment finished and old
workers were gone. For future drains, release it after that same condition.
Do not submit feedback iterations during an overlapping
rollout: the previous worker cannot process PLAN tasks that retain source content.

Final backend main `9d47d0f0f8e3c6b768745d66abca7bdae9e2e238` deployed healthy
via `elw7nl6rf4fex5b20cvfpbhl` at 21:06:51 UTC (2026-10-05 locally). No work was
queued or running before this rollout; the old worker was removed. It adds
independent life, personality, leisure and voice directions, more concrete facial
geometry, complete short biographies, and preservation of legacy names during
feedback iterations. Portrait prompts receive visual plan fields rather than the
entire life story. Vision review compares against one concrete closest reference.

Persona responses now include the active generation stage and queued/running
state. Expired leases are shown as queued. These fields may change without a
persona version change, so clients must reconcile progress on equal versions.
The earlier rolling deployment left an old task claimed until its ten-minute
lease expired; it recovered automatically. Serial planning/text and visual-review
lanes, plus retries, can also queue work behind the two active workers.

Final local verification passed all 75 backend tests with PostgreSQL integration
tests enabled. Post-deployment VPN, Origin, service-key and public-isolation
checks passed again. Live generation evaluation remains subject to bounded
semantic and visual review: distinct seeds do not guarantee distinct model output.

## NVIDIA and per-job model settings release — 2026-10-06

Backend main `1903d795dd13f2c05aa8613a1a56225d492531f2`, including the NVIDIA
migration `af3db36`, deployed through signed webhook deployment
`0gfgbj1qxvoaet21sqbgsf2k`. The deployment finished and the container running that
exact commit is healthy. Full local Maven verification passed 148 tests with zero
failures, errors or skipped tests, including Docker/PostgreSQL integration tests.

The owner's existing `NVIDIA_API_KEY` was found on the agents Coolify application.
Its build-time flag was disabled and its runtime flag retained; the credential
value was not printed or persisted by verification. The non-secret NVIDIA
defaults above were added as runtime-only settings, with Muse selected before
deployment. The old agents `OPENAI_*` settings remain available for rollback,
and the separate Instantly backend was not changed.

`GET /api/v1/generation-models` now exposes four supported choices: Muse Glimmer
30B, DeepSeek V4.1 Flash, GLM 5.3 Flash and Kimi K3. The default settings are Muse,
8192 completion tokens, temperature 1, top-p 0.95 and reasoning effort `none`.
Every model has an application token cap of 16384 and a temperature range of 0–1.
Kimi omits top-p and supports `low`, `high` and `max` reasoning effort; DeepSeek
and GLM omit reasoning controls on the documented hosted API. Muse and GLM
vision requests are limited to eight images, with larger reference sets reviewed
in chunks so the diversity reference coverage is preserved.

Each job saves its resolved settings in the existing `generation_job.input`
JSONB. Planning, text generation, semantic review, vision review, retries and
feedback iterations reuse that snapshot. No database migration was required.
The private catalog returned HTTP 200 with the exact defaults, limits and model
capabilities above; persona/job list APIs returned JSON with HTTP 200 and a
foreign browser Origin was rejected with HTTP 403.

A bounded manual provider check generated one fictional adult portrait through
FLUX.2-klein-4b: HTTP 200 in 2.63 seconds, one `SUCCESS` artifact, a valid
1024×1024 JPEG of 135,404 bytes. The successful request used only `prompt`,
`width`, `height`, `steps` and `seed`; additional fields from a different image
API contract had previously returned HTTP 422 without generating an image.
The generated image stayed in memory and was used once for the vision check.

Muse returned a valid Turkish fictional-profile JSON response in 4.50 seconds.
A separate live vision request sent two copies of an official NVIDIA public JPEG
as base64 data URLs, matching the adapter's transport. It returned HTTP 200 in
5.67 seconds of provider time (6.90 seconds including the sample download), valid
JSON, `distinct=false` and a nonempty explanation. These were bounded manual
provider checks, separate from the automated test suite.

Earlier DeepSeek text inference with a JSON schema in the system prompt timed out after
180.04 seconds; DeepSeek vision inference timed out after 180.02 seconds. Neither
returned an HTTP response within the bound. The model catalog returned HTTP 200
and included `deepseek-ai/deepseek-v4.1-flash`, but that read-only catalog check
does not establish text inference access or availability. GLM 5.3 Flash and Kimi
K3 also exceeded a 45-second bounded text probe. These observations do not claim
those endpoints are permanently unavailable; only Muse and FLUX passed the
corresponding live checks in this rollout. Selecting another model preserves its
supported request contract but does not guarantee provider availability.

A read-only agents database check before deployment found no queued/running
tasks, no active leases, no pending generation and six already-active registration
attempts. Live deployment verification did not create application jobs, register
accounts or alter task leases. Historical completed jobs cannot reveal which
provider produced their earlier content merely from the new default settings.

## Local-model profile and photo import release — 2026-10-06

Backend main `5a21c1707dcfc966e6c99c6de8dc712e58637e6a` deployed through signed
webhook deployment `kquoidsohg4fw9zln1lujyey`. The deployment finished and the
container running that exact commit is healthy. Liquibase applied `agents:004`
and released its lock. This additive migration creates the `persona_import`
idempotency ledger; it does not change the worker task protocol or existing
generation tables. No new environment variable, provider credential or runtime
resource was required.

The private `POST /api/v1/persona-imports` endpoint accepts two multipart files:
`metadata` (JSON containing a UUID `requestId`, the external `model` name and
profile `content`) and `photo` (JPEG or PNG). It creates a human-reviewable
`DRAFT` with an `UPLOADED` photo and explicit `importSource` provenance, without
calling NVIDIA or registering an account. `UPLOADED` does not claim automatic
semantic or visual diversity review. Human approval continues through the
existing immutable revision and registration workflow.

Metadata is limited to 64 KiB; photos are limited to 10 MiB, 256–4096 pixels per
edge and 16 million pixels overall. Images are validated before pixel allocation
and normalized to metadata-free JPEG with transparency composited onto white.
Unknown metadata fields cannot set lifecycle, approval or member state. A new
request returns 201; an identical retry returns 200 for the same persona, while
reusing a request ID for different content or image bytes returns 409. See the
backend repository's `docs/LOCAL-MODEL-IMPORT.md`, `examples/local-persona.json`
and `scripts/import-persona.py` for the local-model upload contract.

Full backend verification passed 180 tests with zero failures, errors or skipped
tests, including PostgreSQL and real HTTP multipart tests. The local Python
uploader fixture passed separately. Live verification sent only an invalid
multipart request with no photo: HTTP 400 with JSON `INVALID_REQUEST`. The
private model/persona/job list APIs returned HTTP 200, persona/job responses
exposed `importSource`, and a foreign browser Origin returned HTTP 403. The live
import ledger remained empty; no valid profile, photo or account was created by
deployment checks.

Three operator-started PLAN tasks were still queued/running during the rollout.
They were preserved under the existing retry and lease rules; deployment checks
did not retry, cancel, clear leases or otherwise mutate those tasks. Their
provider retries are separate from the import feature and its test results.
