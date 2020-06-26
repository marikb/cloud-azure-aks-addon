resource "azurerm_resource_group" "aks-rg" {
  name     = "aks-rg"
  location = "West Europe"
  
  tags = {
    Environment = "Dev",
	Application = "AKS App RG <Name>"
  }
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "cluster-aks1"
  location            = azurerm_resource_group.aks-rg.location
  resource_group_name = azurerm_resource_group.aks-rg.name
  dns_prefix          = "exampleaks1"
  
  addon_profile {
	azure_policy = "enabled"
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Dev",
	Application = "AKS App Cluster <Name>"
  }
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.cluster.kube_config_raw
}