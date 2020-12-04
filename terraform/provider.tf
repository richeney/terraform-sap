terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 2.36"
    }
  }
}

provider "azurerm" {
  // Default to Azure CLI token (or env vars) unless managed identity or service principal arguments are specified
  features {}

  use_msi = false
  // tenant_id       = "<GUID>"
  // client_id       = "<GUID>"
  // client_secret   = "<GUID>"
  // subscription_id = "<GUID>"
}