# Partial configuration: values come from ..\backend.hcl plus -backend-config="key=p01-hub-spoke.tfstate".
terraform {
  backend "azurerm" {}
}
