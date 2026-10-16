# ---------------------------------------------------------------------------
# Common inputs (same as Project 0)
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uksouth"

  validation {
    condition     = contains(["uksouth", "ukwest", "westeurope"], var.location)
    error_message = "location must be one of: uksouth, ukwest, westeurope."
  }
}

variable "environment" {
  description = "Environment short name used in names and tags."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: lab, dev, test, prod."
  }
}

variable "instance" {
  description = "Two-digit instance number used in resource names."
  type        = string
  default     = "01"

  validation {
    condition     = can(regex("^[0-9]{2}$", var.instance))
    error_message = "instance must be exactly two digits, e.g. 01."
  }
}

variable "owner" {
  description = "Value for the owner tag."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "project" {
  description = "Value for the project tag."
  type        = string
  default     = "terraform"
}

variable "expiry_date" {
  description = "Value for the expiry_date tag, format YYYY-MM-DD."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.expiry_date))
    error_message = "expiry_date must use the format YYYY-MM-DD."
  }

  validation {
    condition     = can(formatdate("YYYY-MM-DD", "${var.expiry_date}T00:00:00Z"))
    error_message = "expiry_date must be a real calendar date."
  }
}

variable "extra_tags" {
  description = "Additional tags. Cannot override the standard tag keys."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network layout: ONE variable describes every VNet and subnet.
# Subnet prefix = cidrsubnet(vnet cidr, newbits, netnum)
#   e.g. cidrsubnet("10.1.0.0/16", 8, 1) = "10.1.1.0/24"
# ---------------------------------------------------------------------------
variable "vnets" {
  description = "Hub-and-spoke layout. Exactly one VNet must have role = \"hub\"."
  type = map(object({
    role = string
    cidr = string
    subnets = map(object({
      newbits = number
      netnum  = number
    }))
  }))

  default = {
    hub = {
      role = "hub"
      cidr = "10.0.0.0/16"
      subnets = {
        GatewaySubnet = { newbits = 11, netnum = 0 } # 10.0.0.0/27 (exact name required by Azure)
        shared        = { newbits = 8, netnum = 1 }  # 10.0.1.0/24
      }
    }
    spoke1 = {
      role = "spoke"
      cidr = "10.1.0.0/16"
      subnets = {
        workload = { newbits = 8, netnum = 1 } # 10.1.1.0/24 (VMs in Project 2)
        pe       = { newbits = 8, netnum = 2 } # 10.1.2.0/24 (private endpoints in Project 6)
      }
    }
    spoke2 = {
      role = "spoke"
      cidr = "10.2.0.0/16"
      subnets = {
        workload = { newbits = 8, netnum = 1 } # 10.2.1.0/24
        pe       = { newbits = 8, netnum = 2 } # 10.2.2.0/24
      }
    }
  }

  validation {
    condition     = length([for k, v in var.vnets : k if v.role == "hub"]) == 1
    error_message = "Exactly one VNet must have role = \"hub\"."
  }

  validation {
    condition     = alltrue([for v in var.vnets : contains(["hub", "spoke"], v.role)])
    error_message = "Each VNet role must be \"hub\" or \"spoke\"."
  }

  validation {
    condition     = alltrue([for k, v in var.vnets : can(regex("^[a-z][a-z0-9]{1,9}$", k))])
    error_message = "VNet keys must be 2-10 lowercase letters/digits and start with a letter."
  }

  validation {
    condition     = alltrue([for v in var.vnets : can(cidrhost(v.cidr, 0))])
    error_message = "Each VNet cidr must be a valid IPv4 CIDR, e.g. 10.1.0.0/16."
  }

  validation {
    condition = alltrue(flatten([
      for v in var.vnets : [
        for s in v.subnets : can(cidrsubnet(v.cidr, s.newbits, s.netnum))
      ]
    ]))
    error_message = "A subnet's newbits/netnum does not fit inside its VNet cidr."
  }
}

# ---------------------------------------------------------------------------
# NSG rules per role. One NSG per VNet; rules are generated with a dynamic block.
# ---------------------------------------------------------------------------
variable "nsg_rules" {
  description = "NSG rules keyed by VNet role (hub, spoke)."
  type = map(list(object({
    name                    = string
    priority                = number
    direction               = string
    access                  = string
    protocol                = string
    source_address_prefix   = string
    destination_port_ranges = list(string)
  })))

  default = {
    hub = [
      {
        name                    = "allow-ssh-rdp-from-vnet"
        priority                = 100
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        source_address_prefix   = "VirtualNetwork"
        destination_port_ranges = ["22", "3389"]
      },
      {
        name                    = "deny-internet-inbound"
        priority                = 4000
        direction               = "Inbound"
        access                  = "Deny"
        protocol                = "*"
        source_address_prefix   = "Internet"
        destination_port_ranges = ["*"]
      },
    ]
    spoke = [
      {
        name                    = "allow-ssh-rdp-from-vnet"
        priority                = 100
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        source_address_prefix   = "VirtualNetwork"
        destination_port_ranges = ["22", "3389"]
      },
      {
        name                    = "deny-internet-inbound"
        priority                = 4000
        direction               = "Inbound"
        access                  = "Deny"
        protocol                = "*"
        source_address_prefix   = "Internet"
        destination_port_ranges = ["*"]
      },
    ]
  }

  validation {
    condition     = alltrue([for role in ["hub", "spoke"] : contains(keys(var.nsg_rules), role)])
    error_message = "nsg_rules must contain both a \"hub\" and a \"spoke\" key."
  }
}

# ---------------------------------------------------------------------------
# User-defined routes applied to every spoke subnet (one route table per spoke).
# No firewall is deployed, so the default is a harmless "blackhole" demo route.
# ---------------------------------------------------------------------------
variable "spoke_routes" {
  description = "Routes for the spoke route tables. Empty map = no route tables."
  type = map(object({
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))

  default = {
    blackhole-test = {
      address_prefix = "10.250.0.0/16"
      next_hop_type  = "None"
    }
  }

  validation {
    condition = alltrue([
      for r in var.spoke_routes :
      contains(["VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"], r.next_hop_type)
    ])
    error_message = "next_hop_type must be VirtualNetworkGateway, VnetLocal, Internet, VirtualAppliance or None."
  }
}

variable "private_dns_zone_name" {
  description = "Private DNS zone linked to every VNet (VM auto-registration enabled)."
  type        = string
  default     = "lab.internal"
}

# ---------------------------------------------------------------------------
# Optional extras (OFF by default)
# ---------------------------------------------------------------------------
variable "enable_bastion_developer" {
  description = "Deploy Azure Bastion Developer (free). It does NOT work across peering, so put it in the VNet your VMs use."
  type        = bool
  default     = false
}

variable "bastion_vnet_key" {
  description = "Which VNet (key in var.vnets) gets Bastion Developer."
  type        = string
  default     = "spoke1"

  validation {
    condition     = contains(keys(var.vnets), var.bastion_vnet_key)
    error_message = "bastion_vnet_key must be one of the keys in var.vnets."
  }
}

variable "enable_vpn_gateway" {
  description = "WARNING: billed hourly (well over USD 1/day) and takes 30-45 min to build. Deploy, test, destroy the same day."
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "VPN gateway SKU (zone-redundant AZ SKUs need a zonal Standard public IP)."
  type        = string
  default     = "VpnGw1AZ"
}
