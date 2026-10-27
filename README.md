# Azure Landing Zones Accelerator Starter Module for Terraform - Azure Verified Modules Complete Multi-Region

This module is part of the Azure Landing Zones Accelerator solution. It is a complete multi-region implementation of the Azure Landing Zones Platform Landing Zone for Terraform.

It deploys a hub and spoke virtual network or Virtual WAN architecture across multiple regions.

The module deploys the following resources:

- Management group hierarchy
- Azure Policy definitions and assignments
- Role definitions
- Management resources, including Log Analytics workspace and Automation account
- Hub and spoke virtual network or Virtual WAN architecture across multiple regions
- DDOS protection plan
- Private DNS zones

## Usage

The module is intended to be used with the [Azure Landing Zones Accelerator](https://aka.ms/alz/acc). Head over there to get started.

>NOTE: The module can be used independently if needed. Example `tfvars` files can be found in the `examples` directory for that use case.

### Running Directly

#### Custom resource groups

The resource-group and approved network configuration in
`config/platform-landing-zone.tfvars` is also set in
`platform-landing-zone.auto.tfvars` for direct execution. Existing Defender policy
and VPN public-IP tag differences are preserved. Both platform and bootstrap
network configurations select `centralus`; region-derived names also change.

| Subscription | Resource group | Terraform owner |
|---|---|---|
| Connectivity | `rg-conn-hub-prod-cus-01` | `module.resource_groups["vnet_primary"]` |
| Connectivity | `rg-conn-vpn-prod-cus-01` | `module.resource_groups["vpn"]` |
| Connectivity | `rg-conn-dns-prod-cus-01` | `module.resource_groups["dns"]` |
| Connectivity | `rg-conn-kv-prod-cus-01` | `module.resource_groups["key_vault"]` |
| Management | `rg-mgmt-network-prod-cus-01` | `module.management_resource_groups["network"]` |
| Management | `rg-mgmt-logging-prod-cus-01` | `module.management_resources[0]` |
| Management | `rg-mgmt-bootstrap-prod-cus-01` | Separate bootstrap state: `module.azure.azurerm_resource_group.identity` |
| Identity | `rg-idam-network-prod-cus-01` | `module.identity_resource_groups["network"]` |
| Identity | `rg-idam-sync-prod-cus-01` | `module.identity_resource_groups["sync"]` |

The hub includes Premium Firewall with its management IP, gateway, DNS inbound and
outbound subnets, and a shared subnet. The resolver belongs to the DNS group while
its delegated subnets remain in the hub group. Its default inbound IP is
`10.152.104.196`. Management and identity VNets/subnets are created in their network
groups. No peerings, new custom routes, forwarding rules, firewall rules, or TLS
inspection certificates are added. Existing module-generated hub routing remains.
The VPN and Key Vault groups remain empty; no VPN resources are relocated and no
Key Vault or Puckett-owned Entra Connect server is created.

Bootstrap owns its group and unpeered VNet, runners, state storage, private endpoints,
registry, and identities. The optional `bootstrap_resource_group_name` input selects
consolidation; null preserves the original separate-group behavior for other callers.
The existing `identity` resource-group address is retained as the consolidated owner.
Generated backend configuration uses the consolidated state-group name. Consolidated
subnets disable default outbound access; the existing NAT gateway provides runner
egress. Storage shared keys and storage/registry public access remain disabled in
private mode.

These names and ownership changes are for the confirmed new deployment. Existing
deployments require a state/resource migration plan. DNS and logging creation still
follow their existing enablement settings; policy-created groups are unchanged.
This is not a restriction to only nine groups.

The 2026-10-25 audit found existing UK South bootstrap state and confirmed
destructive group replacements in a scoped dry plan. On 2026-10-27, the approved
custom policy library was restored and the parent management group was reconciled
to `FactoryALZManagementGroup`. Local validation does not establish migration
readiness: review a full refreshed plan before applying.

The bootstrap VNet `vnet-mgmt-prod-cus-02` (`10.152.111.0/26`) must remain
unpeered. It is managed by separate bootstrap state, not by the platform network
resources. Its private runners use NAT for outbound access.

The architecture uses existing `FactoryALZManagementGroup` as its root; there is
no intermediate `alz` group. Platform, Landing Zones, Sandbox and Decommissioned
are its direct children. Their descendant `mg-puckett-*` IDs are unchanged.
Bootstrap reuses this group for management-group RBAC and does not create it or
move subscriptions. The platform retains the final subscription placements.

Root policy definitions and assignments, including `root_custom` and `amba_root`,
now target `FactoryALZManagementGroup`. They can affect every subscription below
that existing group, including subscriptions outside this architecture. Review
this broader inheritance scope before deploying.

When publishing platform code, retain the active Azure Storage backend and the
existing-root architecture flag, matching bootstrap repository assembly.
Do not upload bootstrap state, saved plans, dependency caches, or credentials.
Merging to `main` triggers the existing continuous delivery workflow; review the
bootstrap migration and platform plan before merging.

Removing `alz` from the design does not reconcile old Terraform state. A full
refreshed plan may still read or propose deleting old `alz` resources, role
assignments and subscription placements. Do not apply or remove state entries
without an approved migration review.

#### Offline network tests

From this starter directory:

```powershell
terraform init -backend=false
terraform validate
terraform test
terraform test -var-file="..\..\..\..\config\platform-landing-zone.tfvars"
```

From `output\bootstrap\v7.3.2\modules\azure`, run `terraform init -backend=false`
and `terraform test` to check consolidated and legacy group ownership. Tests use
mock providers and plan-only runs; no Azure or GitHub deployment occurs. Platform
tests target the new spoke resources and full connectivity dependency graph and may
emit targeting/deprecation warnings. The bootstrap root also has a mocked
`tests/generation.tftest.hcl` plan test. It exercises the real filtered repository
assembly, including custom policies and the approved parent. Packaging excludes
runtime/cache/state/plan and common credential-file artifacts. Separate packaging
tests also verify that additional-file inputs cannot bypass these exclusions.

#### Run the local examples

Create a `terraform.tfvars` file in the root of the module directory with the following content, replacing the placeholders with the actual values:

```hcl
starter_locations            = ["uksouth", "ukwest"]
subscription_id_connectivity = "00000000-0000-0000-0000-000000000000"
subscription_id_identity     = "00000000-0000-0000-0000-000000000000"
subscription_id_management   = "00000000-0000-0000-0000-000000000000"
```

##### Hub and Spoke Virtual Networks Multi Region

```powershell
terraform init
terraform apply -var-file ./examples/full-multi-region/hub-and-spoke-vnet.tfvars
```

##### Virtual WAN Multi Region

```powershell
terraform init
terraform apply -var-file ./examples/full-multi-region/virtual-wan.tfvars
```
