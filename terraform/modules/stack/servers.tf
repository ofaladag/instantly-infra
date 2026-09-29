resource "hcloud_ssh_key" "admin" {
  for_each   = var.ssh_public_keys
  name       = "${local.name_prefix}-${each.key}"
  public_key = each.value
  labels     = local.labels
}
resource "hcloud_server" "app" {
  name               = "${local.name_prefix}-app-01"
  location           = var.location
  server_type        = var.app_server_type
  image              = "ubuntu-24.04"
  ssh_keys           = [for key in hcloud_ssh_key.admin : key.id]
  firewall_ids       = [hcloud_firewall.app.id]
  labels             = merge(local.labels, { role = "app" })
  backups            = var.server_backups
  delete_protection  = true
  rebuild_protection = true
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.private.id
    ip         = local.app_private_ip
  }
  user_data = "#cloud-config\n${yamlencode({
    disable_root = false
    ssh_pwauth   = false
    write_files = [
      { path = "/usr/local/sbin/instantly-bootstrap", permissions = "0700", content = templatefile("${path.module}/../../../cloud-init/app.sh.tftpl", { data_ip = local.data_private_ip, install_coolify = var.install_coolify }) },
      { path = "/usr/local/sbin/instantly-nat", permissions = "0700", content = templatefile("${path.module}/../../../cloud-init/nat.sh.tftpl", { data_ip = local.data_private_ip }) }
    ]
    runcmd = [["/usr/local/sbin/instantly-bootstrap"]]
  })}"
  depends_on = [hcloud_network_subnet.private]
  lifecycle { prevent_destroy = true }
}
resource "hcloud_server" "data" {
  name               = "${local.name_prefix}-data-01"
  location           = var.location
  server_type        = var.data_server_type
  image              = "ubuntu-24.04"
  ssh_keys           = [for key in hcloud_ssh_key.admin : key.id]
  firewall_ids       = [hcloud_firewall.data.id]
  labels             = merge(local.labels, { role = "data" })
  backups            = var.server_backups
  delete_protection  = true
  rebuild_protection = true
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.private.id
    ip         = local.data_private_ip
  }
  user_data = "#cloud-config\n${yamlencode({
    disable_root        = false
    ssh_pwauth          = false
    ssh_authorized_keys = [var.coolify_ssh_public_key]
    write_files = [
      { path = "/usr/local/sbin/instantly-bootstrap", permissions = "0700", content = templatefile("${path.module}/../../../cloud-init/data.sh.tftpl", { gateway = local.network_gateway, app_ip = local.app_private_ip, volume_id = try(hcloud_volume.data[0].id, ""), use_data_volume = var.use_data_volume }) },
      { path = "/usr/local/sbin/instantly-data-firewall", permissions = "0700", content = templatefile("${path.module}/../../../cloud-init/data-firewall.sh.tftpl", { app_ip = local.app_private_ip }) }
    ]
    runcmd = [["/usr/local/sbin/instantly-bootstrap"]]
  })}"
  depends_on = [hcloud_network_subnet.private, hcloud_network_route.egress]
  lifecycle { prevent_destroy = true }
}
