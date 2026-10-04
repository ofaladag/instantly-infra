# Staging CoreDNS (Coolify)

Deploy docker-compose.yml as a Coolify service on APP-01. The image is pinned
by version and digest. Before deployment copy Corefile and internal.hosts to
/data/instantly/coredns/ on APP; this directory is mounted read-only.

DNS listens on 10.20.0.20:53 over UDP and TCP, not the public address.
The local system resolver at 127.0.0.53 is unchanged. Unknown internal names
return NXDOMAIN; other zones forward to 1.1.1.1 and 9.9.9.9.

The internal hosts map Coolify/wg-easy/Agents to APP and PostgreSQL/Redis to DATA.
DNS does not supply ports. The private HTTPS proxy now serves Coolify and
wg-easy on port 443 (see services/proxy). PostgreSQL uses 5432 and Redis 6379.

After editing, copy the files to the same host directory. CoreDNS reloads the
Corefile and hosts plugin data. Keep .example files as environment templates;
these concrete files are staging-specific and must be adapted for production.

Verified UDP/TCP queries from APP, UDP from DATA, plus public-name forwarding.
Bootstrap/package DNS is independent of this runtime service.
