provider "azurerm" {
  # Required since azurerm 4.x (or set ARM_SUBSCRIPTION_ID).
  subscription_id = var.subscription_id

  # azurerm 5.x registers no Resource Providers by default.
  # Register only what this configuration needs.
  resource_providers_to_register = [
    "Microsoft.Storage",
  ]

  # Use Entra ID tokens (not account keys) for any storage data-plane calls.
  storage_use_azuread = true

  features {
    # 5.x default is disabled; re-enable so a bad location fails at plan time.
    enhanced_validation {
      locations          = true
      resource_providers = true
    }
  }
}
