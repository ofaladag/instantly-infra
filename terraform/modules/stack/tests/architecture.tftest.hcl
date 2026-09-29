mock_provider "hcloud" {
  mock_resource "hcloud_network" { defaults = { id = "100" } }
  mock_resource "hcloud_firewall" { defaults = { id = "200" } }
  mock_resource "hcloud_ssh_key" { defaults = { id = "300" } }
  mock_resource "hcloud_server" {
    defaults = { id = "400", ipv4_address = "203.0.113.20" }
  }
  mock_resource "hcloud_volume" {
    defaults = { id = "12345" }
  }
}
mock_provider "cloudflare" {}
variables {
  environment            = "stg"
  domain                 = "example.com"
  cloudflare_zone_id     = "0123456789abcdef0123456789abcdef"
  ssh_public_keys        = { test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixtureOnly" }
  coolify_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixtureOnly"
  admin_ipv4_cidrs       = ["203.0.113.10/32"]
}
run "architecture" {
  command = apply
  assert {
    condition     = !one(hcloud_server.data.public_net).ipv4_enabled && !one(hcloud_server.data.public_net).ipv6_enabled
    error_message = "DATA must remain private-only."
  }
  assert {
    condition     = one(hcloud_server.app.public_net).ipv4_enabled && !one(hcloud_server.app.public_net).ipv6_enabled
    error_message = "APP uses public IPv4 only."
  }
  assert {
    condition     = !cloudflare_dns_record.vpn.proxied && cloudflare_dns_record.vpn.type == "A"
    error_message = "WireGuard requires a DNS-only A record."
  }
  assert {
    condition     = output.vpn.client_allowed_ips == ["10.20.0.0/24", "10.8.0.0/24"]
    error_message = "VPN must stay split-tunnel."
  }
  assert {
    condition     = hcloud_network_route.egress.gateway == "10.20.0.20" && hcloud_network_route.egress.destination == "0.0.0.0/0"
    error_message = "Private DATA needs an APP egress route."
  }
  assert {
    condition     = hcloud_volume.data.delete_protection && hcloud_server.data.delete_protection && hcloud_server.app.delete_protection
    error_message = "Persistent infrastructure must retain API deletion protection."
  }
  assert {
    condition     = alltrue([for r in hcloud_firewall.app.rule : r.protocol == "icmp" || contains(["22", "80", "443", "51820"], r.port)])
    error_message = "Management, DNS and database ports must not be publicly opened."
  }
  assert {
    condition     = !yamldecode(hcloud_server.data.user_data).ssh_pwauth && length(yamldecode(hcloud_server.data.user_data).write_files) == 2
    error_message = "DATA needs key-only SSH and rendered bootstrap/firewall scripts."
  }
}
run "reject_world_open_ssh" {
  command = plan
  variables { admin_ipv4_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.admin_ipv4_cidrs]
}

run "production_isolation" {
  command = apply
  variables { environment = "prod" }
  assert {
    condition     = output.deployment.name_prefix == "instantly-prod" && output.deployment.network_cidr == "10.30.0.0/16" && output.vpn.client_allowed_ips == ["10.30.0.0/24", "10.9.0.0/24"]
    error_message = "Production resources and routes must not overlap staging."
  }
  assert {
    condition     = output.vpn.endpoint == "vpn.example.com:51820" && hcloud_server.app.name == "instantly-prod-app-01"
    error_message = "Production names must use the production namespace."
  }
}
run "reject_unknown_environment" {
  command = plan
  variables { environment = "preview" }
  expect_failures = [var.environment]
}
