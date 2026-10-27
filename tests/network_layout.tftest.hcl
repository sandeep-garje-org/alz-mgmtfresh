mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "azurerm" {
  alias = "management"
}

mock_provider "azurerm" {
  alias = "identity"
}

mock_provider "azurerm" {
  alias = "connectivity"
}

mock_provider "azapi" {
  alias = "connectivity"
}

run "network_configuration" {
  command = plan

  module {
    source = "./modules/config-templating"
  }

  override_module {
    target = module.regions
    outputs = {
      regions_by_name = {
        centralus = { geo_code = "cus", short_name = "cus" }
      }
    }
  }

  variables {
    starter_locations               = var.starter_locations
    starter_locations_short         = var.starter_locations_short
    subscription_id_connectivity    = var.subscription_ids["connectivity"]
    subscription_id_management      = var.subscription_ids["management"]
    subscription_id_identity        = var.subscription_ids["identity"]
    subscription_id_security        = var.subscription_ids["security"]
    root_parent_management_group_id = var.root_parent_management_group_id
    custom_replacements             = var.custom_replacements
    enable_telemetry                = false
    inputs = {
      management_group_settings   = var.management_group_settings
      hub_virtual_networks        = var.hub_virtual_networks
      management_virtual_networks = var.management_virtual_networks
      identity_virtual_networks   = var.identity_virtual_networks
      management_resource_groups  = var.management_resource_groups
    }
  }

  assert {
    condition = (
      output.outputs.management_group_settings.parent_resource_id == "FactoryALZManagementGroup" &&
      contains(keys(output.outputs.management_group_settings.policy_assignments_to_modify), "FactoryALZManagementGroup") &&
      !contains(keys(output.outputs.management_group_settings.policy_assignments_to_modify), "alz") &&
      alltrue([
        for group in yamldecode(file("./lib/architecture_definitions/alz_custom.alz_architecture_definition.yaml")).management_groups :
        group.id != "alz" && group.parent_id != "alz" &&
        (group.parent_id != null || (group.id == "FactoryALZManagementGroup" && group.exists)) &&
        (!contains(["mg-puckett-platform", "mg-puckett-landingzones", "mg-puckett-sandbox", "mg-puckett-decommissioned"], group.id) || group.parent_id == "FactoryALZManagementGroup")
      ])
    )
    error_message = "Management-group configuration and root policy overrides must target the existing Factory group."
  }

  assert {
    condition = (
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.name == "vnet-conn-prod-cus-01" &&
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.address_space[0] == "10.152.104.0/23" &&
      output.outputs.hub_virtual_networks.primary.enabled_resources.firewall &&
      output.outputs.hub_virtual_networks.primary.firewall.sku_tier == "Premium" &&
      output.outputs.hub_virtual_networks.primary.firewall.management_ip_enabled &&
      output.outputs.hub_virtual_networks.primary.firewall.subnet_address_prefix == "10.152.104.0/26" &&
      output.outputs.hub_virtual_networks.primary.firewall.management_subnet_address_prefix == "10.152.104.64/26" &&
      output.outputs.hub_virtual_networks.primary.virtual_network_gateways.subnet_address_prefix == "10.152.104.128/26"
    )
    error_message = "Hub naming, firewall configuration, and reserved subnet prefixes must match the approved layout."
  }

  assert {
    condition = (
      output.outputs.hub_virtual_networks.primary.firewall.default_ip_configuration.public_ip_config.ip_tags["FirstPartyUsage"] == "/Unprivileged" &&
      output.outputs.hub_virtual_networks.primary.firewall.management_ip_configuration.public_ip_config.ip_tags["FirstPartyUsage"] == "/Unprivileged" &&
      output.outputs.hub_virtual_networks.primary.virtual_network_gateways.vpn.ip_configurations.active_active_1.public_ip.ip_tags["FirstPartyUsage"] == "/Unprivileged" &&
      output.outputs.hub_virtual_networks.primary.virtual_network_gateways.vpn.ip_configurations.active_active_2.public_ip.ip_tags["FirstPartyUsage"] == "/Unprivileged" &&
      output.outputs.hub_virtual_networks.primary.firewall_policy.intrusion_detection.mode == "Alert"
    )
    error_message = "Firewall and VPN public IPs must retain platform IP tags, and the firewall policy must retain IDPS Alert mode."
  }

  assert {
    condition = (
      output.outputs.hub_virtual_networks.primary.private_dns_resolver.resource_group_name == "rg-conn-dns-prod-cus-01" &&
      output.outputs.hub_virtual_networks.primary.private_dns_resolver.subnet_name == "snet-conn-dnsin-01" &&
      output.outputs.hub_virtual_networks.primary.private_dns_resolver.subnet_address_prefix == "10.152.104.192/28" &&
      output.outputs.hub_virtual_networks.primary.private_dns_resolver.default_inbound_endpoint_enabled &&
      cidrhost(output.outputs.hub_virtual_networks.primary.private_dns_resolver.subnet_address_prefix, 4) == "10.152.104.196" &&
      output.outputs.hub_virtual_networks.primary.private_dns_resolver.outbound_endpoints.primary.subnet_name == "snet-conn-dnsout-01"
    )
    error_message = "The resolver must use the DNS group and the approved inbound and outbound subnets."
  }

  assert {
    condition = (
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.dns_resolver_outbound.name == "snet-conn-dnsout-01" &&
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.dns_resolver_outbound.address_prefixes[0] == "10.152.104.208/28" &&
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.dns_resolver_outbound.delegations[0].service_delegation.name == "Microsoft.Network/dnsResolvers" &&
      !output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.dns_resolver_outbound.route_table.assign_generated_route_table &&
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.shared.name == "snet-conn-shared-01" &&
      output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.shared.address_prefixes[0] == "10.152.105.0/25" &&
      !output.outputs.hub_virtual_networks.primary.hub_virtual_network.subnets.shared.route_table.assign_generated_route_table
    )
    error_message = "Outbound DNS delegation and the hub shared subnet must match the screenshot without generated route associations."
  }

  assert {
    condition     = !contains(keys(output.outputs.management_resource_groups), "bootstrap")
    error_message = "The platform must not also own the bootstrap resource group."
  }

  assert {
    condition = (
      alltrue([for network in values(output.outputs.management_virtual_networks) : network.name != "vnet-mgmt-prod-cus-02"]) &&
      alltrue([for network in values(output.outputs.identity_virtual_networks) : network.name != "vnet-mgmt-prod-cus-02"]) &&
      alltrue([for network in values(output.outputs.hub_virtual_networks) : network.hub_virtual_network.name != "vnet-mgmt-prod-cus-02"])
    )
    error_message = "The isolated bootstrap VNet must not be managed as a platform hub, management, or identity VNet."
  }
}

run "spoke_resources" {
  command = plan

  plan_options {
    target = [
      azurerm_virtual_network.management,
      azurerm_subnet.management,
      azurerm_virtual_network.identity,
      azurerm_subnet.identity,
    ]
  }

  variables {
    enable_telemetry = false
  }

  override_module {
    target = module.config.module.regions
    outputs = {
      regions_by_name = {
        centralus = { geo_code = "cus", short_name = "cus" }
      }
    }
  }

  assert {
    condition = (
      azurerm_virtual_network.management["platform"].name == "vnet-mgmt-prod-cus-01" &&
      azurerm_virtual_network.management["platform"].location == "centralus" &&
      azurerm_virtual_network.management["platform"].resource_group_name == "rg-mgmt-network-prod-cus-01" &&
      tolist(azurerm_virtual_network.management["platform"].address_space)[0] == "10.152.106.0/24" &&
      azurerm_subnet.management["platform-shared"].name == "snet-mgmt-shared-01" &&
      azurerm_subnet.management["platform-shared"].address_prefixes[0] == "10.152.106.0/25" &&
      !azurerm_subnet.management["platform-shared"].default_outbound_access_enabled
    )
    error_message = "Management VNet and subnet must have the approved names, group, region, and CIDRs."
  }

  assert {
    condition = (
      azurerm_virtual_network.identity["identity"].name == "vnet-idam-prod-cus-01" &&
      azurerm_virtual_network.identity["identity"].location == "centralus" &&
      azurerm_virtual_network.identity["identity"].resource_group_name == "rg-idam-network-prod-cus-01" &&
      tolist(azurerm_virtual_network.identity["identity"].address_space)[0] == "10.152.107.0/24" &&
      azurerm_subnet.identity["identity-sync"].name == "snet-idam-sync-01" &&
      azurerm_subnet.identity["identity-sync"].address_prefixes[0] == "10.152.107.0/27" &&
      !azurerm_subnet.identity["identity-sync"].default_outbound_access_enabled
    )
    error_message = "Identity VNet and subnet must have the approved names, group, region, and CIDRs."
  }
}

run "connectivity_dependency_plan" {
  command = plan

  plan_options {
    target = [module.hub_and_spoke_vnet]
  }

  variables {
    enable_telemetry = false
  }

  override_module {
    target = module.config.module.regions
    outputs = {
      regions_by_name = {
        centralus = { geo_code = "cus", short_name = "cus" }
      }
    }
  }

  override_module {
    target = module.hub_and_spoke_vnet[0].module.regions[0]
    outputs = {
      regions_by_name = {
        centralus = { zones = ["1", "2", "3"] }
      }
    }
  }

  override_module {
    target = module.hub_and_spoke_vnet[0].module.private_dns_zones["primary"].module.regions
    outputs = {
      regions_by_name_or_display_name = {
        centralus = { geo_code = "cus", name = "centralus" }
      }
    }
  }
}
