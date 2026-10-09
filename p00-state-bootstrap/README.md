# p00-state-bootstrap

Creates the hardened Azure Storage backend used by every other project:
resource group, StorageV2 account (Entra-only, TLS 1.2, no public blobs,
versioning, blob and container soft delete, version-expiry rule), a private
`tfstate` container, a Storage Blob Data Contributor assignment for the
signed-in user, and a CanNotDelete lock.

## Requirements
- Terraform >= 1.12, azurerm ~> 5.9, random ~> 3.7
- Azure CLI signed in (`az login`); Owner on the subscription

## Usage
1. `Copy-Item terraform.tfvars.example terraform.tfvars` and edit.
2. `terraform init` -> `fmt` -> `validate` -> `plan -out tfplan` -> `apply tfplan` (local state).
3. Generate `..\backend.hcl` from the `backend_config` output, create `backend.tf`.
4. `terraform init -migrate-state -backend-config="..\backend.hcl" -backend-config="key=p00-state-bootstrap.tfstate"`

## Other projects
    terraform init -backend-config="..\backend.hcl" -backend-config="key=<project>.tfstate"

## Teardown
Only after all other projects are destroyed. Migrate state back to local first,
remove `prevent_destroy`, then destroy.
