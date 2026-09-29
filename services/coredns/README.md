# CoreDNS (Coolify owned)
Deploy on APP-01 through Coolify only after bootstrap. Copy `Corefile.example`
and `internal.hosts.example` to files mounted by your Coolify Compose resource;
replace example.com using `terraform output -raw internal_dns_hosts`.
Choose and pin a tested CoreDNS image digest in Coolify before deployment.
Bind both UDP/TCP 53 to **10.20.0.20**, never 0.0.0.0. The system resolver on
127.0.0.53 remains available. No public DNS record for internal names is needed.

VPN clients use 10.20.0.20 as DNS. APP containers can use it explicitly once
CoreDNS is healthy; do not make initial host bootstrap depend on this container.

These examples target stg. For prod use the environment outputs and address/DNS
map in the repository README; do not reuse staging peer configs or persistent state.
