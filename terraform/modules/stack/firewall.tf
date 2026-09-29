# Egress policy: unrestricted. Intentionally omit all outbound rules on both
# Hetzner firewalls: no outbound rules means all outbound traffic is allowed.
# Keep inbound filtering independent of this policy.
resource "hcloud_firewall" "app" {
  name   = "${local.name_prefix}-app-public"
  labels = local.labels
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.admin_ipv4_cidrs
    description = "Administrator SSH; use a tunnel for initial Coolify access"
  }
  dynamic "rule" {
    for_each = toset(["80", "443"])
    content {
      direction   = "in"
      protocol    = "tcp"
      port        = rule.value
      source_ips  = ["0.0.0.0/0"]
      description = "Public applications"
    }
  }
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0"]
    description = "WireGuard tunnel only; no public admin UI"
  }
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0"]
    description = "Diagnostics and path MTU"
  }
}
# No inbound rules: defense if a public interface is ever added accidentally.
# Hetzner firewalls do NOT filter private networking; DATA uses host rules too.
resource "hcloud_firewall" "data" {
  name   = "${local.name_prefix}-data-public-deny"
  labels = local.labels
}
