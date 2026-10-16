provider "azurerm" {
  subscription_id = var.subscription_id

  # azurerm 5.x registers no Resource Providers by default.
  resource_providers_to_register = [
    "Microsoft.Network",
  ]

  features {
    enhanced_validation {
      locations          = true
      resource_providers = true
    }
  }
}
