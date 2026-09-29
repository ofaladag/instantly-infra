# Staging Redis

Image: redis:7.2. Runtime managed by Coolify on DATA-01. The redis.conf file is
a reference copy of the saved Coolify custom configuration, not automatically
deployed by Terraform. Apply edits through Coolify and redeploy the resource.

Endpoint: redis://10.20.0.30:6379/0. No password, as requested by the owner.
Access is restricted by DATA firewall to the staging private network. All
admitted hosts can read/write/administer Redis; there is no per-client identity.
AOF everysec and RDB use the existing Docker volume mounted at /data.
maxmemory 512mb with noeviction preserves queued keys at the memory limit by
rejecting memory-growing writes; clients should handle and alert on such errors.
This is local durability, not an off-host backup or zero-data-loss guarantee.

Source: https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/
