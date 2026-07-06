# In Azure Cloud Shell (or after `az login`) both providers authenticate against
# your current Azure CLI context, so no explicit credentials are needed here.
provider "azurerm" {
  features {}
}

provider "azuread" {}
