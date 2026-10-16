locals {
  region_codes = {
    uksouth    = "uks"
    ukwest     = "ukw"
    westeurope = "weu"
  }

  region_code = local.region_codes[var.location]

  # Shared name ending: <env>-<region>-<nn>, e.g. lab-uks-01
  suffix              = "${var.environment}-${local.region_code}-${var.instance}"
  resource_group_name = "rg-network-${local.suffix}"

  # The single hub key (validation guarantees exactly one), and a map of spokes only.
  hub_key = one([for k, v in var.vnets : k if v.role == "hub"])
  spokes  = { for k, v in var.vnets : k => v if v.role == "spoke" }

  # Azure requires these exact names; they get no "snet-" prefix and no NSG.
  special_subnets = ["GatewaySubnet", "AzureBastionSubnet", "AzureFirewallSubnet"]

  # Step 1: nested maps (vnet -> subnets) flattened into ONE list of subnet objects.
  subnet_list = flatten([
    for vnet_key, vnet in var.vnets : [
      for subnet_key, subnet in vnet.subnets : {
        key            = "${vnet_key}.${subnet_key}"
        vnet_key       = vnet_key
        role           = vnet.role
        is_special     = contains(local.special_subnets, subnet_key)
        name           = contains(local.special_subnets, subnet_key) ? subnet_key : "snet-${subnet_key}"
        address_prefix = cidrsubnet(vnet.cidr, subnet.newbits, subnet.netnum)
      }
    ]
  ])

  # Step 2: list -> map with stable keys like "spoke1.workload" (for_each needs a map or set).
  subnets = { for s in local.subnet_list : s.key => s }

  # Filtered views used by the association resources.
  nsg_subnets = { for k, s in local.subnets : k => s if !s.is_special }
  rt_subnets  = { for k, s in local.subnets : k => s if s.role == "spoke" && !s.is_special && length(var.spoke_routes) > 0 }

  common_tags = merge(var.extra_tags, {
    environment = var.environment
    owner       = var.owner
    project     = var.project
    workload    = "network"
    managed_by  = "terraform"
    expiry_date = var.expiry_date
  })
}
