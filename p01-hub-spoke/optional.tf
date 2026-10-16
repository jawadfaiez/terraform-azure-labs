# ---------------------------------------------------------------------------
# Bastion Developer: free, no AzureBastionSubnet, no public IP.
# Does NOT reach VMs across peering, so it goes into var.bastion_vnet_key.
# ---------------------------------------------------------------------------
resource "azurerm_bastion_host" "dev" {
  count = var.enable_bastion_developer ? 1 : 0

  name                = "bas-${var.bastion_vnet_key}-${local.suffix}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.this[var.bastion_vnet_key].id
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# VPN gateway (hourly cost!). Off by default.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "vpn" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = "pip-vgw-${local.hub_key}-${local.suffix}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

resource "azurerm_virtual_network_gateway" "hub" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = "vgw-${local.hub_key}-${local.suffix}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  active_active       = false
  bgp_enabled         = false

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vpn[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = try(azurerm_subnet.this["${local.hub_key}.GatewaySubnet"].id, null)
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = contains(keys(local.subnets), "${local.hub_key}.GatewaySubnet")
      error_message = "enable_vpn_gateway = true needs a subnet named GatewaySubnet in the hub VNet."
    }
  }
}
