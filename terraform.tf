terraform {
  required_version = "~> 1.12"
  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.21"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  backend "azurerm" {}
}

provider "alz" {
  library_overwrite_enabled = true
  library_references = [
    # Load policy fixes first: the current ALZ library loader retains the first definition.
    {
      custom_url = "${path.root}/lib/policy_set_definitions"
    },
    {
      path = "platform/amba"
      ref  = "2026.06.2"
    },
    {
      custom_url = "${path.root}/lib"
    }
  ]
}

provider "azapi" {
  skip_provider_registration = true
  subscription_id            = var.subscription_ids["management"]
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  alias                           = "management"
  subscription_id                 = var.subscription_ids["management"]
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  alias                           = "connectivity"
  subscription_id                 = var.subscription_ids["connectivity"]
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  alias                           = "identity"
  subscription_id                 = try(var.subscription_ids["identity"], null)
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
  alias                      = "connectivity"
  skip_provider_registration = true
  subscription_id            = var.subscription_ids["connectivity"]
}
