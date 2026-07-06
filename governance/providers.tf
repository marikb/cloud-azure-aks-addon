# Assigning policy and role assignments at management-group scope requires an
# identity with Owner (or Resource Policy Contributor + User Access Administrator)
# at that scope. In Cloud Shell the provider uses your az login context.
provider "azurerm" {
  features {}
}
