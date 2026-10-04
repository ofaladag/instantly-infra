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
mock_provider "minio" {}
variables {
  domain                 = "example.com"
  cloudflare_zone_id     = "0123456789abcdef0123456789abcdef"
  ssh_public_keys        = { test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixtureOnly" }
  coolify_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixtureOnly"
  admin_ipv4_cidrs       = ["203.0.113.10/32"]
}

run "root_wiring" {
  command = apply
  assert {
    condition     = output.deployment.environment == "stg" && output.deployment.name_prefix == "instantly-stg" && output.vpn.endpoint == "vpn.stg.example.com:51820"
    error_message = "Root must deploy only its fixed environment and DNS namespace."
  }
  assert {
    condition     = output.storage.mode == "root_disk" && output.deployment.app_server_type == "cx23" && output.deployment.data_server_type == "cx23"
    error_message = "Environment machine size and storage policy must match the intended defaults."
  }
  assert {
    condition     = minio_s3_bucket.application.acl == "private" && !minio_s3_bucket.application.force_destroy && minio_s3_bucket.application.bucket == "anonly-instantly-stg-app" && output.application_object_storage.region == "nbg1"
    error_message = "Staging application bucket must be private, retained and in Nuremberg."
  }
  assert {
    condition     = minio_s3_bucket.agents.acl == "private" && !minio_s3_bucket.agents.force_destroy && minio_s3_bucket.agents.bucket != minio_s3_bucket.application.bucket && output.agents_object_storage.region == "nbg1"
    error_message = "Agents portraits must stay in a separate private retained bucket."
  }
}
