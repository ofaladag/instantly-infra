resource "cloudflare_dns_record" "vpn" {
  zone_id = var.cloudflare_zone_id
  name    = "vpn.${local.dns_domain}"
  type    = "A"
  content = hcloud_server.app.ipv4_address
  ttl     = 300
  proxied = false
  comment = "Instantly WireGuard endpoint; UDP requires DNS-only"
}
resource "cloudflare_dns_record" "app" {
  for_each = var.public_app_subdomains
  zone_id  = var.cloudflare_zone_id
  name     = "${each.value}.${local.dns_domain}"
  type     = "A"
  content  = hcloud_server.app.ipv4_address
  ttl      = 300
  proxied  = false
  comment  = "Instantly application ingress managed by Terraform"
}
# Internal records belong to CoreDNS, never the public zone.
