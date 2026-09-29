output "app_public_ipv4" { value = hcloud_server.app.ipv4_address }
output "private_addresses" {
  value = { app = local.app_private_ip, data = local.data_private_ip }
}
output "vpn" {
  value = {
    endpoint           = "vpn.${local.dns_domain}:51820"
    client_allowed_ips = [local.subnet_cidr, local.vpn_cidr]
    client_dns         = local.app_private_ip
  }
}
output "coolify_initial_tunnel" {
  value = "ssh -N -L 8000:127.0.0.1:8000 root@${hcloud_server.app.ipv4_address}"
}
output "data_ssh" {
  value = "ssh -J root@${hcloud_server.app.ipv4_address} root@${local.data_private_ip}"
}
output "storage" {
  value = { id = hcloud_volume.data.id, device = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.data.id}", mount = "/data/instantly" }
}
output "internal_dns_hosts" {
  value = <<-HOSTS
    ${local.app_private_ip} coolify.internal.${local.dns_domain} wg.internal.${local.dns_domain}
    ${local.data_private_ip} postgres.internal.${local.dns_domain} redis.internal.${local.dns_domain}
  HOSTS
}

output "deployment" {
  value = {
    environment  = var.environment
    name_prefix  = local.name_prefix
    dns_domain   = local.dns_domain
    network_cidr = local.network_cidr
    subnet_cidr  = local.subnet_cidr
    vpn_cidr     = local.vpn_cidr
  }
}
