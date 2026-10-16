# p01-hub-spoke

Hub-and-spoke network driven by ONE map variable (`vnets`):
hub + 2 spokes, subnets computed with `cidrsubnet()`, two-way hub<->spoke peering,
one NSG per VNet (rules from a dynamic block), a route table per spoke,
and a private DNS zone (`lab.internal`) linked to every VNet with auto-registration.
Optional (off): Bastion Developer, VPN gateway (hourly cost).

## Run
    terraform init -backend-config="..\backend.hcl" -backend-config="key=p01-hub-spoke.tfstate"
    terraform fmt -recursive
    terraform validate
    terraform plan -out tfplan
    terraform apply tfplan

## Outputs used later
- `subnet_ids["spoke1.workload"]` -> Project 2 VMs
- `subnet_ids["spoke1.pe"]`, `private_dns_zone_id`, `vnet_ids` -> Project 6

## Teardown
    terraform plan -destroy -out tfplan
    terraform apply tfplan
