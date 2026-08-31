output "portal_public_ip" {
  value = yandex_vpc_address.portal.external_ipv4_address[0].address
}

output "vm_private_ips" {
  value = {
    portal      = yandex_compute_instance.portal.network_interface[0].ip_address
    analytics   = yandex_compute_instance.analytics.network_interface[0].ip_address
    integration = yandex_compute_instance.integration.network_interface[0].ip_address
  }
}

output "network_id" {
  value = yandex_vpc_network.main.id
}

output "subnet_ids" {
  value = {
    platform = yandex_vpc_subnet.platform.id
    clinics  = yandex_vpc_subnet.clinics.id
    fintech  = yandex_vpc_subnet.fintech.id
    ai       = yandex_vpc_subnet.ai.id
  }
}

output "nat_gateway_id" {
  value = yandex_vpc_gateway.nat.id
}

output "data_lake_bucket" {
  value = yandex_storage_bucket.lake.bucket
}

output "clinics_db_host" {
  value = yandex_mdb_postgresql_cluster.clinics.host[0].fqdn
}