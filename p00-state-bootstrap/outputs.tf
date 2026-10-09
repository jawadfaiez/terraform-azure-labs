output "resource_group_name" {
  description = "Resource group holding the state storage account."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "State storage account name (globally unique)."
  value       = azurerm_storage_account.state.name
}

output "storage_account_id" {
  description = "State storage account resource ID."
  value       = azurerm_storage_account.state.id
}

output "container_name" {
  description = "Blob container that holds all project state files."
  value       = azurerm_storage_container.tfstate.name
}

output "container_id" {
  description = "Container resource ID (scope for pipeline identity role assignments in Project 9)."
  value       = azurerm_storage_container.tfstate.id
}

output "backend_config" {
  description = "Values for the shared partial backend config (backend.hcl). Each project adds its own key."
  value = {
    subscription_id      = var.subscription_id
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.tfstate.name
  }
}
