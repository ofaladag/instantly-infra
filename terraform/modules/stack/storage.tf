resource "hcloud_volume" "data" {
  name              = "${local.name_prefix}-data-01"
  location          = var.location
  size              = var.data_volume_size_gb
  format            = "ext4"
  labels            = local.labels
  delete_protection = true
  lifecycle { prevent_destroy = true }
}
resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.data.id
  automount = false
}
