locals {
  # Short region codes used in resource names (CAF-style).
  region_codes = {
    uksouth    = "uks"
    ukwest     = "ukw"
    westeurope = "weu"
  }

  region_code = local.region_codes[var.location]

  # Pattern: <type>-<workload>-<env>-<region>-<nn>
  name_suffix = "${var.workload}-${var.environment}-${local.region_code}-${var.instance}"

  resource_group_name = "rg-${local.name_suffix}"
  lock_name           = "lock-st-${local.name_suffix}"
  container_name      = "tfstate"

  # Storage account names: 3-24 chars, lowercase letters and digits, globally unique.
  # The prefix is known at plan time; the 6-char random suffix is not.
  storage_account_prefix = "st${var.workload}${var.environment}${local.region_code}"
  storage_account_name   = "${local.storage_account_prefix}${random_string.suffix.result}"

  # Standard keys come last so extra_tags cannot override them.
  common_tags = merge(var.extra_tags, {
    environment = var.environment
    owner       = var.owner
    project     = var.project
    workload    = var.workload
    managed_by  = "terraform"
    expiry_date = var.expiry_date
  })
}
