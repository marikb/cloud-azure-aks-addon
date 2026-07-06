# Assigning policy and role assignments at management-group scope requires an
# identity with Owner (or Resource Policy Contributor + User Access Administrator)
# at that scope. In Cloud Shell the provider uses your az login context; azurerm
# 4.x also requires a subscription (var.subscription_id or ARM_SUBSCRIPTION_ID).
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
