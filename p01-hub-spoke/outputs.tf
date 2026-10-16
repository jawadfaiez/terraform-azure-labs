output "resource_group_name" {
  description = "Network resource group."
  value       = azurerm_resource_group.network.name
}

output "location" {
  description = "Region of the network."
  value       = azurerm_resource_group.network.location
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.this[local.hub_key].id
}

output "vnet_ids" {
  description = "Map of VNet key => VNet ID."
  value       = { for k, v in azurerm_virtual_network.this : k => v.id }
}

output "vnet_names" {
  description = "Map of VNet key => VNet name."
  value       = { for k, v in azurerm_virtual_network.this : k => v.name }
}

output "subnet_ids" {
  description = "Map of \"vnet.subnet\" => subnet ID (e.g. \"spoke1.workload\"). Used by Projects 2 and 6."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "subnet_prefixes" {
  description = "Map of \"vnet.subnet\" => address prefix computed by cidrsubnet()."
  value       = { for k, s in local.subnets : k => s.address_prefix }
}

output "private_dns_zone_id" {
  description = "Private DNS zone ID."
  value       = azurerm_private_dns_zone.lab.id
}

output "private_dns_zone_name" {
  description = "Private DNS zone name."
  value       = azurerm_private_dns_zone.lab.name
}

output "bastion_id" {
  description = "Bastion Developer ID, or null when disabled."
  value       = one(azurerm_bastion_host.dev[*].id)
}

output "vpn_gateway_public_ip" {
  description = "VPN gateway public IP, or null when disabled."
  value       = one(azurerm_public_ip.vpn[*].ip_address)
}
