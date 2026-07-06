resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  dns_prefix          = local.cluster_name

  kubernetes_version        = local.kubernetes_version
  automatic_channel_upgrade = var.automatic_channel_upgrade

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "system"
    vm_size             = var.system_node_vm_size
    zones               = var.availability_zones
    enable_auto_scaling = true
    min_count           = var.system_node_min_count
    max_count           = var.system_node_max_count
    os_disk_size_gb     = var.system_node_os_disk_size_gb
    # orchestrator_version is intentionally left unset: AKS manages it via the
    # automatic upgrade channel, and pinning it here conflicts with auto-upgrade.

    # Rotate the node pool in place when a ForceNew attribute (vm_size, zones,
    # os_disk_size_gb) changes, instead of destroying and recreating the whole
    # cluster. Must be a valid node pool name (<= 12 chars for a system pool).
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = var.node_max_surge
    }
  }

  # Azure Policy add-on (top-level boolean in azurerm 3.x).
  azure_policy_enabled = true

  # Container Insights / Log Analytics monitoring. msi_auth uses the cluster's
  # managed identity to publish metrics instead of the workspace shared key.
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.insights.id
    msi_auth_for_monitoring_enabled = true
  }

  # Managed Azure AD integration with a dedicated cluster-admin group.
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = [azuread_group.aks_administrators.object_id]
    azure_rbac_enabled     = var.azure_rbac_enabled
  }

  maintenance_window {
    allowed {
      day   = var.maintenance_day
      hours = var.maintenance_hours
    }
  }

  tags = local.common_tags

  lifecycle {
    # The patch upgrade channel bumps the version out-of-band on both the control
    # plane and the node pool; ignore that drift so Terraform does not try to
    # revert AKS's auto-applied patch on the next plan.
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
    ]
  }
}
