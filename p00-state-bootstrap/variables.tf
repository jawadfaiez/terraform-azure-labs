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

variable "workload" {
  description = "Workload short name (2-8 lowercase letters/digits) used in resource names."
  type        = string
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.workload))
    error_message = "workload must be 2-8 characters, lowercase letters and digits only."
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

variable "replication_type" {
  description = "Storage account replication type."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of: LRS, ZRS, GRS, RAGRS, GZRS, RAGZRS."
  }
}

variable "blob_soft_delete_days" {
  description = "Days to retain soft-deleted blobs."
  type        = number
  default     = 14

  validation {
    condition     = var.blob_soft_delete_days >= 1 && var.blob_soft_delete_days <= 365
    error_message = "blob_soft_delete_days must be between 1 and 365."
  }
}

variable "container_soft_delete_days" {
  description = "Days to retain soft-deleted containers."
  type        = number
  default     = 14

  validation {
    condition     = var.container_soft_delete_days >= 1 && var.container_soft_delete_days <= 365
    error_message = "container_soft_delete_days must be between 1 and 365."
  }
}

variable "version_retention_days" {
  description = "Delete previous blob versions (old state files) this many days after creation."
  type        = number
  default     = 30

  validation {
    condition     = var.version_retention_days >= 1
    error_message = "version_retention_days must be at least 1."
  }
}

variable "shared_access_key_enabled" {
  description = "Allow Shared Key (account key) authorisation. Keep false: backend and provider use Entra ID."
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional tags. Cannot override the standard tag keys."
  type        = map(string)
  default     = {}
}
