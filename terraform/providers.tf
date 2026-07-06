# In Azure Cloud Shell (or after `az login`) both providers authenticate against
# your current Azure CLI context. azurerm 4.x requires an explicit subscription:
# set var.subscription_id (or export ARM_SUBSCRIPTION_ID).
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}
