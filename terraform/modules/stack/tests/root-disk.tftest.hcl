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
run "root_disk_staging" {
  command = apply
  variables {
    environment      = "stg"
    use_data_volume  = false
    app_server_type  = "cx23"
    data_server_type = "cx23"
  }
  assert {
    condition     = length(hcloud_volume.data) == 0 && length(hcloud_volume_attachment.data) == 0 && output.storage.mode == "root_disk" && output.storage.device == null
    error_message = "Root disk mode must create no separate volume or attachment."
  }
  assert {
    condition     = !strcontains(hcloud_server.data.user_data, "data-instantly.mount") && !strcontains(hcloud_server.data.user_data, "scsi-0HC_Volume") && !strcontains(hcloud_server.data.user_data, "RequiresMountsFor") && strcontains(hcloud_server.data.user_data, "/data/instantly/postgres")
    error_message = "Root disk bootstrap must create data directories without waiting for a volume."
  }
}
