locals {
  management_subnets = merge({}, [
    for network_key, network in module.config.outputs.management_virtual_networks : {
      for subnet_key, subnet in network.subnets : "${network_key}-${subnet_key}" => merge(subnet, { network_key = network_key })
    }
  ]...)
  identity_subnets = merge({}, [
    for network_key, network in module.config.outputs.identity_virtual_networks : {
      for subnet_key, subnet in network.subnets : "${network_key}-${subnet_key}" => merge(subnet, { network_key = network_key })
    }
  ]...)
}

resource "azurerm_virtual_network" "management" {
  provider = azurerm.management
  for_each = module.config.outputs.management_virtual_networks

  name                = each.value.name
  location            = each.value.location
  resource_group_name = module.management_resource_groups[each.value.resource_group_key].name
  address_space       = each.value.address_space
  tags                = each.value.tags == null ? module.config.outputs.tags : each.value.tags
}

resource "azurerm_subnet" "management" {
  provider = azurerm.management
  for_each = local.management_subnets

  name                            = each.value.name
  resource_group_name             = azurerm_virtual_network.management[each.value.network_key].resource_group_name
  virtual_network_name            = azurerm_virtual_network.management[each.value.network_key].name
  address_prefixes                = each.value.address_prefixes
  default_outbound_access_enabled = false
}

resource "azurerm_virtual_network" "identity" {
  provider = azurerm.identity
  for_each = module.config.outputs.identity_virtual_networks

  name                = each.value.name
  location            = each.value.location
  resource_group_name = module.identity_resource_groups[each.value.resource_group_key].name
  address_space       = each.value.address_space
  tags                = each.value.tags == null ? module.config.outputs.tags : each.value.tags
}

resource "azurerm_subnet" "identity" {
  provider = azurerm.identity
  for_each = local.identity_subnets

  name                            = each.value.name
  resource_group_name             = azurerm_virtual_network.identity[each.value.network_key].resource_group_name
  virtual_network_name            = azurerm_virtual_network.identity[each.value.network_key].name
  address_prefixes                = each.value.address_prefixes
  default_outbound_access_enabled = false
}
