resource "azurerm_resource_group" "network" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# One VNet per entry in var.vnets (hub, spoke1, spoke2).
resource "azurerm_virtual_network" "this" {
  for_each = var.vnets

  name                = "vnet-${each.key}-${local.suffix}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [each.value.cidr]
  tags                = merge(local.common_tags, { role = each.value.role })
}

# One subnet per entry in the flattened local.subnets map.
resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet_key].name
  address_prefixes     = [each.value.address_prefix]
}

# One NSG per VNet; its rules are generated from var.nsg_rules[role].
resource "azurerm_network_security_group" "this" {
  for_each = var.vnets

  name                = "nsg-${each.key}-${local.suffix}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  dynamic "security_rule" {
    for_each = var.nsg_rules[each.value.role]

    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"

      # Azure uses the singular argument for one port and the plural one for several.
      destination_port_range  = length(security_rule.value.destination_port_ranges) == 1 ? security_rule.value.destination_port_ranges[0] : null
      destination_port_ranges = length(security_rule.value.destination_port_ranges) > 1 ? security_rule.value.destination_port_ranges : null
    }
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.value.vnet_key].id
}

# One route table per spoke (only if var.spoke_routes is not empty).
resource "azurerm_route_table" "spoke" {
  for_each = { for k, v in local.spokes : k => v if length(var.spoke_routes) > 0 }

  name                          = "rt-${each.key}-${local.suffix}"
  location                      = azurerm_resource_group.network.location
  resource_group_name           = azurerm_resource_group.network.name
  bgp_route_propagation_enabled = true

  dynamic "route" {
    for_each = var.spoke_routes

    content {
      name                   = route.key
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = route.value.next_hop_in_ip_address
    }
  }

  tags = local.common_tags
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = local.rt_subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.spoke[each.value.vnet_key].id
}

# Peering is one-way in Azure, so each hub<->spoke pair needs two resources.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spokes

  name                         = "peer-${local.hub_key}-to-${each.key}"
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = azurerm_virtual_network.this[local.hub_key].name
  remote_virtual_network_id    = azurerm_virtual_network.this[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.enable_vpn_gateway
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.spokes

  name                         = "peer-${each.key}-to-${local.hub_key}"
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = azurerm_virtual_network.this[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.this[local.hub_key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.enable_vpn_gateway

  # use_remote_gateways only works once the hub gateway exists and the hub side
  # allows gateway transit. Nothing in this block references those, so Terraform
  # can't infer the order: we state it explicitly.
  depends_on = [
    azurerm_virtual_network_gateway.hub,
    azurerm_virtual_network_peering.hub_to_spoke,
  ]
}

# Private DNS zone linked to every VNet; VMs auto-register their names.
resource "azurerm_private_dns_zone" "lab" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags
}

# for_each over another resource's instances: each.value is a whole VNet object.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = azurerm_virtual_network.this

  name                 = "link-${each.key}"
  private_dns_zone_id  = azurerm_private_dns_zone.lab.id
  virtual_network_id   = each.value.id
  registration_enabled = true
  tags                 = local.common_tags
}
