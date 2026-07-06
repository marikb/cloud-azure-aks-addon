resource "azurerm_log_analytics_workspace" "insights" {
  name                = "logs-${random_pet.suffix.id}"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}
