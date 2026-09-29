# WireGuard / wg-easy (Coolify owned)
This is the deployment contract, not an untested auto-deployed Compose service.
Use the current wg-easy template in Coolify, verify its version-specific settings,
and pin the tested image digest. Keep generated keys, peer configs, passwords and
wg-easy state out of this repository and Terraform state.

- Endpoint: `vpn.stg.<domain>:51820`, Cloudflare **DNS-only**.
- Public port: UDP 51820. Admin UI: loopback/private binding only. Do not publish
  its UI via a public Coolify proxy route without a VPN source restriction.
- Tunnel subnet: `10.8.0.0/24`; client AllowedIPs:
  `10.20.0.0/24,10.8.0.0/24`. Never use `0.0.0.0/0` or `::/0`.
- DNS: `10.20.0.20`. This can send all DNS queries to CoreDNS while application
  traffic stays split-tunnel. For per-domain DNS, configure the client OS resolver.
- Masquerade peer traffic toward the private network as APP-01 `10.20.0.20`.
  DATA-01 deliberately accepts SSH and database traffic only from that address.
  Confirm this source translation on the host when selecting bridge/host mode.
- Persist `/etc/wireguard` using a Coolify-managed persistent volume. Back it up
  securely; it contains private keys. Keep peer access limited to trusted admins.
- All peers sharing APP's source IP can reach the permitted database ports;
  per-user database credentials still apply. This is not per-peer segmentation.
- Confirm forwarding in the wg-easy container and host, and configure a tunnel
  MTU appropriate to the path (start at 1380, verify on real clients).

VPN does not provide high availability: APP-01 is also the VPN/NAT/control-plane
host. A failure there removes management access and DATA outbound connectivity.

These examples target stg. For prod use the environment outputs and address/DNS
map in the repository README; do not reuse staging peer configs or persistent state.
