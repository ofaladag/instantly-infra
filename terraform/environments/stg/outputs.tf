output "app_public_ipv4" { value = module.infra.app_public_ipv4 }
output "private_addresses" { value = module.infra.private_addresses }
output "vpn" { value = module.infra.vpn }
output "coolify_initial_tunnel" { value = module.infra.coolify_initial_tunnel }
output "data_ssh" { value = module.infra.data_ssh }
output "storage" { value = module.infra.storage }
output "internal_dns_hosts" { value = module.infra.internal_dns_hosts }
output "deployment" { value = module.infra.deployment }
