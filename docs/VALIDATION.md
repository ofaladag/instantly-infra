# Validation record

Validated locally on 2026-09-29 with Terraform 1.14.3, hcloud 1.69.0 and
Cloudflare 5.26.0. Provider checksums are tracked in each root/module lock file.

The source of truth is /Users/faruk/dev/workspace/instantly-infra.

- Recursive formatting and validate for shared module, stg and prod roots.
- Four mocked baseline module runs: architecture/security invariants, world-open SSH
  rejection, separate production names/DNS/address ranges, invalid environment
  rejection.
- One mocked integration run for each environment root: module wiring, fixed
  environment, resource namespace and distinct VPN DNS endpoint.
- Cloud-init templates resolve from their relocated module path in both roots.
- An additional isolated root-disk module test verifies no volume/attachment and
  no volume wait/mount dependency in staging bootstrap (seven total test runs).
- Both DATA bootstrap modes rendered and passed bash syntax checks; environment
  tests also verify CX23/root disk for stg and CX33/separate volume for prod.
- State, plans, tfvars, credentials, provider caches and IDE metadata are ignored.

These tests use mock providers; no live API calls, real plan or apply occurred.
Production has only been validated, not deployed. Actual Linux bootstrap,
NAT/firewall behavior, mounting, Coolify, VPN and restores still require the
post-deployment checks in OPERATIONS.md. Run scripts/check.sh to reproduce
configuration checks without cloud credentials.
