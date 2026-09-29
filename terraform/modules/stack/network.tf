locals {
  # Separate address spaces allow concurrent staging/production VPN connections.
  address_plan = {
    stg  = { network = "10.20.0.0/16", subnet = "10.20.0.0/24", vpn = "10.8.0.0/24" }
    prod = { network = "10.30.0.0/16", subnet = "10.30.0.0/24", vpn = "10.9.0.0/24" }
  }
  name_prefix     = "${var.project}-${var.environment}"
  dns_domain      = var.environment == "stg" ? "stg.${var.domain}" : var.domain
  network_cidr    = local.address_plan[var.environment].network
  subnet_cidr     = local.address_plan[var.environment].subnet
  network_gateway = cidrhost(local.subnet_cidr, 1)
  app_private_ip  = cidrhost(local.subnet_cidr, 20)
  data_private_ip = cidrhost(local.subnet_cidr, 30)
  vpn_cidr        = local.address_plan[var.environment].vpn
  labels          = { project = var.project, environment = var.environment, managed_by = "terraform" }
}
resource "hcloud_network" "private" {
  name     = "${local.name_prefix}-private"
  ip_range = local.network_cidr
  labels   = local.labels
}
resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = local.subnet_cidr
}
# Cloud route and guest default route are both required for private-only DATA-01.
resource "hcloud_network_route" "egress" {
  network_id  = hcloud_network.private.id
  destination = "0.0.0.0/0"
  gateway     = local.app_private_ip
  depends_on  = [hcloud_server.app]
}
