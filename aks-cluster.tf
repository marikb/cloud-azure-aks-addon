resource "azurerm_kubernetes_cluster" "aks" {
  dns_prefix          = local.aks_cluster_name
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  location            = azurerm_resource_group.primary.location
  name                = local.aks_cluster_name
  resource_group_name = azurerm_resource_group.primary.name
  automatic_channel_upgrade = patch
  
  maintance_window {
	allowed {
	day = "thursday"
	hours = [1,6]
	}
  }	
  
  upgrade_settings {
	max_surge = "30"
	} 
  }


  default_node_pool {
    name                 = "system"
    node_count           = 1
    orchestrator_version = data.azurerm_kubernetes_service_versions.current.latest_version
    vm_size              = "Standard_DS2_v2"
  }

  identity { type = "SystemAssigned" }

   tags = {
    Environment = local.Environment_tag
	  Application = var.Application_tag
  }

    
  default_node_pool {
    availability_zones   = [1, 2, 3]
    enable_auto_scaling  = true
    max_count            = 3
    min_count            = 1
    name                 = "system"
    orchestrator_version = data.azurerm_kubernetes_service_versions.current.latest_version
    os_disk_size_gb      = 1024
    vm_size              = "Standard_DS2_v2"
  }

  addon_profile {
    azure_policy { enabled = true }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.insights.id
    }
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      admin_group_object_ids = [azuread_group.aks_administrators.object_id]
    }
  }
}

