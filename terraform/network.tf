# A private cluster on Azure CNI Overlay needs a bring-your-own subnet, so we
# create a VNet + subnet ONLY when private_cluster_enabled = true. For a public
# cluster, AKS manages its own VNet and these are not created.
resource "azurerm_virtual_network" "aks" {
  count               = var.private_cluster_enabled ? 1 : 0
  name                = "vnet-${local.cluster_name}"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  count                = var.private_cluster_enabled ? 1 : 0
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.aks[0].name
  address_prefixes     = [var.aks_subnet_address_prefix]
}
