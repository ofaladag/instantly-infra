# Staging WireGuard (Coolify)

The stack in docker-compose.yml runs on APP-01 through Coolify, with a pinned
wg-easy 15.4.0 image digest. WireGuard is provided by the host kernel; bootstrap
loads `wireguard` and persists it in /etc/modules-load.d/wireguard.conf.
The container needs NET_ADMIN but no SYS_MODULE or host module mount.

Public UDP endpoint: vpn.stg.instantlyhere.com:51820 (Cloudflare DNS-only).
Admin HTTP: 127.0.0.1:51821 via SSH tunnel, or 10.20.0.20:51821 over VPN.
There is no public admin proxy/domain. INSECURE enables HTTP inside these paths;
SSH/WireGuard provides transport encryption. Do not expose this UI publicly.

Client defaults stored in the persistent /etc/wireguard named volume:
- IPv4 tunnel: 10.8.0.0/24; IPv6 disabled.
- AllowedIPs: 10.20.0.0/24,10.8.0.0/24 (split tunnel).
- DNS: 10.20.0.20; endpoint: vpn.stg.instantlyhere.com:51820.
- wg-easy default MTU 1420; lower to 1380 if client connectivity needs it.

wg-easy masquerades VPN traffic onto its Docker network; Docker then
masquerades it to APP's private IP for DATA access. These are trusted admin
peers; DATA admits database traffic from the entire 10.20.0.0/16 network.
Client AllowedIPs controls routing, not a server-side authorization boundary.
Internet traffic stays on the client connection; DNS queries use CoreDNS.

## Initial setup / recovery

The committed Compose is the steady-state configuration. On a new empty volume,
use the wg-easy setup wizard through the SSH tunnel to create an admin and set
the defaults above before creating any clients. Alternatively use the official
INIT_* unattended settings, then remove them from Coolify and redeploy.
Never replace the persistent volume during routine updates.

For this deployment, unattended setup was completed and INIT_* removed.
The local admin credential file is work/credentials/wg-easy-stg.json (0600),
and the faruk-macbook profile is work/credentials/instantly-stg.conf (0600).
Both are ignored by Git. Import the profile into WireGuard on the user's device.
Each additional device should have its own peer/profile. Remove a peer to revoke it.

Open the admin tunnel with:

```sh
ssh -N -L 51821:127.0.0.1:51821 root@188.245.26.177
```

Then visit http://127.0.0.1:51821 for recovery access. Normal VPN access uses
https://wg.internal.stg.instantlyhere.com through the private proxy, without a port
suffix. Coolify likewise uses https://coolify.internal.stg.instantlyhere.com.
See services/proxy for HTTPS configuration and renewal.

Source: https://wg-easy.github.io/wg-easy/latest/advanced/config/unattended-setup/
