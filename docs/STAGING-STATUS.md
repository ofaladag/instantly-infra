# Staging deployment status — 2026-09-29

- Terraform apply completed: 11 resources; subsequent plan reports no changes.
- APP: 188.245.26.177 / 10.20.0.20; DATA: private-only 10.20.0.30.
- Both CX23 hosts are in nbg1; DATA uses its root disk, no attached volume.
- Private application bucket: anonly-instantly-stg-app, nbg1 endpoint.
- Both hosts completed cloud-init with no errors. Route/firewall/NAT units active.
- DATA outbound HTTPS works through APP before and after Docker installation.
- API and VPN A records resolve to APP on Cloudflare DNS. VPN service is not yet deployed.
- Official Coolify installer run on APP; deployed version 4.3.23.
- APP Docker address pool: 172.20.0.0/16, /24 networks, avoiding private/VPN CIDRs.
- DATA daemon configuration prepared for 172.21.0.0/16, /24 networks and MTU 1450;
  Docker installation remains part of Coolify server validation.
- Coolify HTTP endpoint returns 302 through a local SSH tunnel on 127.0.0.1:8000.

Next: owner creates initial administrator at http://127.0.0.1:8000, then add DATA
using its dedicated SSH key and private IP, deploy CoreDNS/wg-easy, databases and
application resources through Coolify. No application database or VPN is running yet.
The PostgreSQL/Redis containers on APP are Coolify's own internal dependencies.

To reopen the local tunnel if needed:

```sh
ssh -N -L 127.0.0.1:8000:127.0.0.1:8000 root@188.245.26.177
```

Initial root registration must be completed by the owner. No credentials were
created for that account by the agent. The public firewall does not expose port 8000.
