# Who is running Terraform (your user via az login). Used for the data-plane role assignment.
data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "state" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  access_tier              = "Hot"

  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = var.shared_access_key_enabled
  default_to_oauth_authentication  = true
  local_user_enabled               = false
  cross_tenant_replication_enabled = false

  # Must stay reachable from your PC (and GitHub-hosted runners in Project 9).
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_days
    }
  }

  tags = local.common_tags

  lifecycle {
    # Lifecycle arguments must be literal values; variables are not allowed here.
    prevent_destroy = true

    precondition {
      condition     = can(regex("^[a-z0-9]{3,18}$", local.storage_account_prefix))
      error_message = "Storage account prefix must be 3-18 lowercase letters/digits so that prefix + 6-char suffix fits in 24 characters."
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = local.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Versioning keeps every old state file; expire old versions so they don't pile up.
resource "azurerm_storage_management_policy" "state" {
  storage_account_id = azurerm_storage_account.state.id

  rule {
    name    = "expire-old-state-versions"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${local.container_name}/"]
    }

    actions {
      version {
        delete_after_days_since_creation = var.version_retention_days
      }
    }
  }
}

# Data-plane access for the azurerm backend (use_azuread_auth = true).
# Owner is a management-plane role and does NOT grant blob read/write.
resource "azurerm_role_assignment" "state_blob_data_contributor" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
  description          = "Terraform state read/write for the signed-in engineer (azurerm backend, Entra auth)."
}

resource "azurerm_management_lock" "state" {
  name       = local.lock_name
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Protects Terraform remote state. Remove only through Terraform during planned teardown."

  # Hidden dependency: the lock blocks deletion of these child items.
  # Create the lock last, so that on destroy it is removed first.
  depends_on = [
    azurerm_storage_container.tfstate,
    azurerm_storage_management_policy.state,
    azurerm_role_assignment.state_blob_data_contributor,
  ]
}
